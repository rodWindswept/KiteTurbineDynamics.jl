# scratch/probe_exact_physics.jl
#
# Tests the complete, rigorous physical lifter model:
#   1. Steady-state tension is exactly T_lift (no artificial tension escalation!).
#   2. Along-line damping: c_par * dot(-sa_vel, u_line) represents line viscoelasticity
#      and kite aerodynamic drag absorbing longitudinal line waves.
#   3. Transverse restoring stiffness: k_perp = T_lift / L_line (~10.2 N/m)
#      represents the pendulum restoring geometry of a tether suspended from a kite in the air mass.
#   4. Transverse damping: c_perp represents aerodynamic side-force dissipation.

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const WINNER_CSV = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")
const WINNER_L = 18.8
const WINNER_KW = 5.0

function build_winner_case()
    p = params_at_length(params_daisy(), WINNER_L, WINNER_KW)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=WINNER_KW * 1000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=WINNER_KW * 1000.0, v_rated=11.0, p_floor_kw=WINNER_KW,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, pc)
    wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function run_sim_exact_physics!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64,
    lift_device::LiftDevice,
    lift_dir::Vector{Float64},
    T_ref::Float64,
    c_par::Float64,
    k_perp::Float64,
    c_perp::Float64;
    lin_damp::Float64=0.05,
)
    N = sys.n_total
    Nr = sys.n_ring
    sa_gid = sys.sky_anchor_id
    m_sa = sys.nodes[sa_gid].mass
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = (sys, p, wind_fn)

    for step in 1:n_steps
        sys.any_broken[] && break
        fill!(du, 0.0)

        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre); omega_pre[ri] = 0.0; end
        for ri in findall(!isfinite, alpha_pre); alpha_pre[ri] = 0.0; end

        multibody_ode!(du, u, ode_params, t)

        # ── Physical Tether Damping & Geometric Restoring ──
        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]

        # The lifter line vector from sky anchor to kite
        # Current kite position is tracked with first-order lag toward instantaneous equilibrium:
        r_line = sys.kite_pos .- sa_pos
        d_line = norm(r_line)
        u_line = d_line > 1e-6 ? r_line ./ d_line : lift_dir

        # Longitudinal damping along the line (viscoelastic tether dissipation + kite aero drag)
        v_par = dot(sa_vel, u_line)
        T_dynamic = max(0.0, T_ref - c_par * v_par)

        # Transverse restoring force relative to the vertical wind plane:
        # Crosswind displacement (Y) produces lateral pendulum restoring force
        # F_perp = -k_perp * sa_pos[2] - c_perp * sa_vel[2]
        F_transverse_y = -k_perp * sa_pos[2] - c_perp * sa_vel[2]

        F_lift = T_dynamic .* u_line
        F_lift[2] += F_transverse_y

        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_lift ./ m_sa

        t += dt

        # ── Update Turbine States ──
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

        omega_view = @view u[(6N + Nr + 1):(6N + 2Nr)]
        unsafe_omega = findall(!isfinite, omega_view)
        if !isempty(unsafe_omega); omega_view[unsafe_omega] .= 0.0; end

        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_view = @view u[(6N + 1):(6N + Nr)]
        unsafe_alpha = findall(!isfinite, alpha_view)
        if !isempty(unsafe_alpha); alpha_view[unsafe_alpha] .= 0.0; end

        if lin_damp > 0.0
            KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)
        end

        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        # Update kite position smoothly
        KiteTurbineDynamics.update_kite_pos!(sys, u, lift_device, p, dt)
    end
    return u
end

function main()
    println("="^80)
    println("PROBE: Physical Lifter (Exact T_ref + Line Viscoelastic Damping + Pendulum k_perp)")
    println("="^80)

    sys, u0, pc, lift, wf = build_winner_case()
    println("Settling base case...")
    u_settled = settle_to_operational_state(
        sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000
    )
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    println(@sprintf("Settled. dt = %.6e s", dt))

    sa_gid = sys.sky_anchor_id
    hub_gid = sys.rotor.node_id
    sa_settled = copy(pos(u_settled, sa_gid))
    θ_lift = pc.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]

    _, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, pc.rho, pc.v_wind_ref, pc)
    L_line = lift.line_length

    # Physics-based coefficients:
    # Along-line damping: c_par from viscoelastic line dissipation & kite apparent-wind drag
    c_par = 200.0   # N*s/m
    # Lateral pendulum restoring stiffness: k_perp = T / L
    k_perp = T_ref / L_line   # ~10.2 N/m
    # Lateral aerodynamic damping
    c_perp = 20.0   # N*s/m

    println(@sprintf("T_ref: %.1f N, L_line: %.2f m", T_ref, L_line))
    println(@sprintf("c_par: %.1f N*s/m, k_perp: %.2f N/m, c_perp: %.1f N*s/m", c_par, k_perp, c_perp))

    u_dyn = copy(u_settled)
    shaft = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

    SIM_TOTAL_S = 120.0
    CHUNK_S = 10.0
    n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
    chunk_steps = round(Int, CHUNK_S / dt)

    println("-"^80)
    @printf("%-6s | %-10s %-10s %-10s %-10s\n",
        "Time", "HubLat(m)", "SALat(m)", "KiteLat(m)", "T_line(N)")
    println("-"^80)

    for i in 1:n_chunks
        t_sim = i * CHUNK_S
        run_sim_exact_physics!(
            u_dyn, sys, pc, wf, chunk_steps, dt,
            lift, lift_dir, T_ref, c_par, k_perp, c_perp;
            lin_damp=0.05
        )

        h_lat = lat_of(pos(u_dyn, hub_gid))
        sa_lat = lat_of(pos(u_dyn, sa_gid))
        k_lat = lat_of(sys.kite_pos)

        sa_vel = @view u_dyn[(3 * sys.n_total + 3 * (sa_gid - 1) + 1):(3 * sys.n_total + 3 * sa_gid)]
        r_line = sys.kite_pos .- pos(u_dyn, sa_gid)
        u_line = r_line ./ norm(r_line)
        v_par = dot(sa_vel, u_line)
        T_now = max(0.0, T_ref - c_par * v_par)

        @printf("%5.1f s | %-10.4f %-10.4f %-10.4f %-10.1f\n",
            t_sim, h_lat, sa_lat, k_lat, T_now)
        flush(stdout)
    end
    println("="^80)
end

main()
