using KiteTurbineDynamics, LinearAlgebra, Printf

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

# Custom clean simulation step
function custom_step!(u, sys, p, wind_fn, dt, c_lift)
    du = zeros(Float64, length(u))
    multibody_ode!(du, u, (sys, p, wind_fn), 0.0)

    # Physical lift line force
    sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
    sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]
    
    # Vector to kite (kite is pinned at Y=0 by aerodynamic symmetry)
    line_to_kite = sys.kite_pos .- sa_pos
    line_dist = norm(line_to_kite)
    u_line = line_dist > 1e-6 ? line_to_kite ./ line_dist : [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]
    
    _, T_lift, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    v_line = dot(sa_vel, u_line)
    T_effective = max(0.0, T_lift - c_lift * v_line)
    
    m_sa = sys.nodes[sa_gid].mass
    @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= (T_effective .* u_line) ./ m_sa

    # Update states
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

    # Kite update:
    # In X and Z: lag toward sa_pos + L * lift_dir
    # In Y: pinned to 0.0 (aerodynamic weathercocking in the wind symmetry plane)
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    r_target = lift.line_length .* lift_dir
    α = min(dt / 3.0, 1.0)
    
    # Relative vector update
    r_rel = sys.kite_pos .- sa_pos
    r_rel[1] += α * (r_target[1] - r_rel[1])
    r_rel[3] += α * (r_target[3] - r_rel[3])
    
    # Re-project X-Z to maintain line length
    d_xz = sqrt(r_rel[1]^2 + r_rel[3]^2)
    if d_xz > 1e-6
        r_rel[1] = (r_rel[1] / d_xz) * lift.line_length * cos(θ_lift)
        r_rel[3] = (r_rel[3] / d_xz) * lift.line_length * sin(θ_lift)
    end
    
    sys.kite_pos[1] = sa_pos[1] + r_rel[1]
    sys.kite_pos[2] = 0.0   # strict aerodynamic weathercock alignment
    sys.kite_pos[3] = sa_pos[3] + r_rel[3]
end

u_test = copy(u_settled)
SIM_TOTAL_S = 120.0
CHUNK_S = 10.0
n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
chunk_steps = round(Int, CHUNK_S / dt)

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]
shaft = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

println("-"^80)
@printf("%-6s | %-10s %-10s %-10s %-10s\n",
    "Time", "HubLat(m)", "SALat(m)", "SA Y(m)", "Kite Y(m)")
println("-"^80)

for i in 1:n_chunks
    t_sim = i * CHUNK_S
    for step in 1:chunk_steps
        custom_step!(u_test, sys, pc, wf, dt, 200.0)
    end
    h_lat = lat_of(pos(u_test, hub_gid))
    sa_p = pos(u_test, sa_gid)
    sa_lat = lat_of(sa_p)
    @printf("%5.1f s | %-10.4f %-10.4f %-10.4f %-10.4f\n",
        t_sim, h_lat, sa_lat, sa_p[2], sys.kite_pos[2])
    flush(stdout)
end
println("="^80)
