# scratch/probe_tension_relaxed_kite.jl
#
# Tests the Tension-Relaxed Lifter Kite:
#   1. Initialized at the settled operating equilibrium:
#      P_kite = sa_settled + L_line * lift_dir
#   2. Fast timescale (flutter, 1-10 Hz):
#      Kite acts as a stationary anchor in the air mass.
#      Tether damping c_lift = 200 N*s/m absorbs vibrational energy.
#   3. Slow timescale (catenary bow, 20-60 s):
#      Kite relieves excess tension by floating along the line:
#      d(P_kite)/dt = (L - L_nom) / tau_relax * u_line
#      with tau_relax = 20.0 s.
#      Tension NEVER artificially climbs above T_ref!

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

sa_settled = pos(u_settled, sa_gid)
θ_lift = pc.lifter_elevation
lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
p_kite = sa_settled .+ lift.line_length .* lift_dir

_, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, pc.rho, pc.v_wind_ref, pc)
EA_lift = lift.line_EA
L0_lift = lift.line_length / (1.0 + T_ref / EA_lift)
c_lift = 200.0       # N*s/m
tau_relax = 20.0     # seconds

println(@sprintf("T_ref: %.1f N, L_line: %.2f m, L0: %.4f m, tau_relax: %.1f s",
    T_ref, lift.line_length, L0_lift, tau_relax))

function run_sim_relaxed!(u, sys, p, wind_fn, n_steps, dt, p_kite, L_nom, L0, EA, c_damp, tau)
    du = zeros(Float64, length(u))
    m_sa = sys.nodes[sa_gid].mass
    ode_params = (sys, p, wind_fn)

    for step in 1:n_steps
        sys.any_broken[] && break
        fill!(du, 0.0)

        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre); omega_pre[ri] = 0.0; end
        for ri in findall(!isfinite, alpha_pre); alpha_pre[ri] = 0.0; end

        multibody_ode!(du, u, ode_params, 0.0)

        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]

        r_line = p_kite .- sa_pos
        L_current = norm(r_line)
        u_line = r_line ./ L_current

        # Velocity projection (positive when line is stretching)
        # Kite moves slowly to relieve tension: v_kite = ((L - L_nom) / tau) * (-u_line)
        v_kite_rel = -((L_current - L_nom) / tau) .* u_line
        L_dot = dot(v_kite_rel .- sa_vel, u_line)

        T_line = max(0.0, EA * (L_current - L0) / L0 + c_damp * L_dot)
        F_lift = T_line .* u_line

        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_lift ./ m_sa

        # Update kite position (slow tension relief)
        p_kite .+= dt .* v_kite_rel

        # Update turbine states
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
        sys.kite_pos .= p_kite
    end
    return u
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
    run_sim_relaxed!(u_dyn, sys, pc, wf, chunk_steps, dt, p_kite, lift.line_length, L0_lift, EA_lift, c_lift, tau_relax)

    h_lat = lat_of(pos(u_dyn, hub_gid))
    sa_p = pos(u_dyn, sa_gid)
    sa_lat = lat_of(sa_p)
    L_now = norm(p_kite .- sa_p)
    T_now = max(0.0, EA_lift * (L_now - L0_lift) / L0_lift)

    @printf("%5.1f s | %-10.4f %-10.4f %-10.4f %-10.1f | %-10.3f %-10.3f\n",
        t_sim, h_lat, sa_lat, sa_p[2], T_now, p_kite[1], p_kite[3])
    flush(stdout)
end
println("="^80)
