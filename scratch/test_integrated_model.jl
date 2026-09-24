using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const WINNER_CSV = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

p = params_at_length(params_daisy(), 18.8, 5.0)
bf = BLOCKING_WIND_FACTOR_5KW
xv = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
cfg = KiteTurbineDynamics.ObjectiveConfig(;
    power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
    beam_sizing=sizing)
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
lift = lift_for(sys, pc)
wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]

u_settled = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000)
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
println(@sprintf("Settled. dt = %.6e s", dt))

sa_gid = sys.sky_anchor_id
hub_gid = sys.rotor.node_id
N = sys.n_total
Nr = sys.n_ring

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

# New update_kite_pos!
function new_update_kite_pos!(sys, u, lift_device, p, dt)
    sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    L_nom = KiteTurbineDynamics.lift_line_length(lift_device)

    if dt <= 0.0
        sys.kite_pos .= sa_pos .+ L_nom .* lift_dir
        return nothing
    end

    # Absolute position lag (tau = 5.0 s):
    # High frequencies (>0.5 Hz) see a stationary kite anchor.
    # Low frequencies (<0.05 Hz) see kite track the sky anchor.
    p_eq = sa_pos .+ L_nom .* lift_dir
    α = min(dt / 5.0, 1.0)
    sys.kite_pos .+= α .* (p_eq .- sys.kite_pos)
    return nothing
end

function sim_step_integrated!(u, sys, p, wind_fn, dt)
    du = zeros(Float64, length(u))
    multibody_ode!(du, u, (sys, p, wind_fn), 0.0)

    sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
    sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]

    line_to_kite = sys.kite_pos .- sa_pos
    line_dist = norm(line_to_kite)
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    L_nom = KiteTurbineDynamics.lift_line_length(lift)
    tension_dir = line_dist > 1e-6 ? line_to_kite ./ line_dist : lift_dir

    _, T_lift, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    v_line = dot(sa_vel, tension_dir)
    c_lift = 200.0
    T_dyn = max(0.0, T_lift - c_lift * v_line)

    m_sa = sys.nodes[sa_gid].mass
    if line_dist >= L_nom * 0.99
        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= (T_dyn .* tension_dir) ./ m_sa
    end

    @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
    @views u[1:3N] .+= dt .* u[(3N + 1):6N]

    omega_gnd_old = u[6N + Nr + 1]
    omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
    unsafe_ri = findall(!isfinite, omega_dot)
    if !isempty(unsafe_ri); omega_dot[unsafe_ri] .= 0.0; end
    @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
    KiteTurbineDynamics.apply_brake_constraint!(u, sys, N, Nr)

    k_mppt_now = sys.k_mppt_ref[]
    if k_mppt_now > 0.01 && omega_gnd_old > 0.1
        omega_gnd_new = u[6N + Nr + 1]
        gnd_gid = sys.ring_ids[1]
        I_z = (sys.nodes[gnd_gid]::RingNode).inertia_z
        du_gen = k_mppt_now * omega_gnd_old^2 / I_z
        du_other = (omega_gnd_new - omega_gnd_old) / dt + du_gen
        denom = 1.0 + dt * k_mppt_now * omega_gnd_old / I_z
        u[6N + Nr + 1] = (omega_gnd_old + dt * du_other) / denom
    end

    @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
    KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, 0.05, dt)
    u[1:3] .= 0.0
    u[(3N + 1):(3N + 3)] .= 0.0

    new_update_kite_pos!(sys, u, lift, p, dt)
end

u_dyn = copy(u_settled)
shaft = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

SIM_TOTAL_S = 120.0
CHUNK_S = 10.0
n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
chunk_steps = round(Int, CHUNK_S / dt)

println("-"^80)
@printf("%-6s | %-10s %-10s %-10s %-10s | %-10s %-10s\n",
    "Time", "HubLat(m)", "SALat(m)", "SA Y(m)", "T_line(N)", "Kite X(m)", "Kite Z(m)")
println("-"^80)

for i in 1:n_chunks
    t_sim = i * CHUNK_S
    for step in 1:chunk_steps
        sim_step_integrated!(u_dyn, sys, pc, wf, dt)
    end

    h_lat = lat_of(pos(u_dyn, hub_gid))
    sa_p = pos(u_dyn, sa_gid)
    sa_lat = lat_of(sa_p)
    _, T_lift, _ = KiteTurbineDynamics.lift_force_steady(lift, pc.rho, pc.v_wind_ref, pc)

    @printf("%5.1f s | %-10.4f %-10.4f %-10.4f %-10.1f | %-10.3f %-10.3f\n",
        t_sim, h_lat, sa_lat, sa_p[2], T_lift, sys.kite_pos[1], sys.kite_pos[3])
    flush(stdout)
end
println("="^80)
