# scratch/probe_dynamic_kite.jl
#
# Tests a true physical 3-DOF Dynamic Lifter Kite:
#   - Kite has mass (m_lifter = 5.0 kg) and aerodynamic lift/drag in the wind.
#   - Position P_kite is governed by Newton's law: m*a = F_aero + m*g - T_line.
#   - Aerodynamic damping: F_aero includes velocity damping against apparent wind.
#   - Line tension: elastic Dyneema tether (EA = 200 kN, c_line = 200 N*s/m).
#   - Equilibrium: On slow timescales, the kite drifts to balance forces (tension stays ~T_ref).
#   - On fast timescales, kite inertia + aero drag hold position, absorbing energy.

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

function run_sim_dynamic_kite!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64,
    p_kite::Vector{Float64},
    v_kite::Vector{Float64},
    L0_lift::Float64,
    EA_lift::Float64,
    c_line::Float64,
    m_kite::Float64,
    F_aero_trim::Vector{Float64},
    c_aero_parallel::Float64,
    c_aero_transverse::Float64;
    lin_damp::Float64=0.05,
)
    N = sys.n_total
    Nr = sys.n_ring
    sa_gid = sys.sky_anchor_id
    m_sa = sys.nodes[sa_gid].mass
    du = zeros(Float64, length(u))
    t = 0.0
    ode_params = (sys, p, wind_fn)
    g_vec = [0.0, 0.0, -9.81]
    wind_dir = [1.0, 0.0, 0.0]

    for step in 1:n_steps
        sys.any_broken[] && break
        fill!(du, 0.0)

        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre); omega_pre[ri] = 0.0; end
        for ri in findall(!isfinite, alpha_pre); alpha_pre[ri] = 0.0; end

        multibody_ode!(du, u, ode_params, t)

        # ── Dynamic Kite Force Balance ──
        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]
        r_line = p_kite .- sa_pos
        L_line = norm(r_line)
        u_line = r_line ./ L_line

        # Line velocity: positive when stretching (moving away from each other)
        v_rel = v_kite .- sa_vel
        L_dot = dot(v_rel, u_line)
        T_line = max(0.0, EA_lift * (L_line - L0_lift) / L0_lift + c_line * L_dot)

        # Tension acts on sky anchor along +u_line, on kite along -u_line
        F_tether_sa = T_line .* u_line
        F_tether_kite = -F_tether_sa

        # Aerodynamic force on kite: trim force + aerodynamic velocity damping
        v_kite_parallel = dot(v_kite, wind_dir) * wind_dir
        v_kite_transverse = v_kite .- v_kite_parallel
        F_aero_damp = -c_aero_parallel .* v_kite_parallel .- c_aero_transverse .* v_kite_transverse
        F_aero_total = F_aero_trim .+ F_aero_damp

        # Acceleration of kite
        a_kite = (F_aero_total .+ m_kite .* g_vec .+ F_tether_kite) ./ m_kite

        # Acceleration of sky anchor
        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_tether_sa ./ m_sa

        t += dt

        # Update kite position & velocity
        v_kite .+= dt .* a_kite
        p_kite .+= dt .* v_kite

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

        sys.kite_pos .= p_kite
    end
    return u
end

function main()
    println("="^80)
    println("PROBE: True 3-DOF Dynamic Lifter Kite (Force Balance + Aero Damping)")
    println("="^80)

    sys, u0, p, lift, wf = build_winner_case()
    println("Settling base case...")
    u_settled = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000
    )
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    println(@sprintf("Settled. dt = %.6e s", dt))

    sa_gid = sys.sky_anchor_id
    hub_gid = sys.rotor.node_id
    sa_settled = pos(u_settled, sa_gid)
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    p_kite = sa_settled .+ lift.line_length .* lift_dir
    v_kite = zeros(3)

    _, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    EA_lift = lift.line_EA
    L0_lift = lift.line_length / (1.0 + T_ref / EA_lift)
    c_line = 200.0   # N*s/m

    m_kite = 5.0     # kg
    g_vec = [0.0, 0.0, -9.81]
    # Trim aerodynamic force balances design line tension + gravity
    F_aero_trim = T_ref .* lift_dir .- m_kite .* g_vec
    c_aero_par = 2.0 * T_ref / p.v_wind_ref   # ~46 N*s/m
    c_aero_perp = 1.0 * T_ref / p.v_wind_ref  # ~23 N*s/m

    println(@sprintf("Kite trim aero force: [%.1f, %.1f, %.1f] N (norm: %.1f N)",
        F_aero_trim[1], F_aero_trim[2], F_aero_trim[3], norm(F_aero_trim)))
    println(@sprintf("Aero damping: c_par = %.1f N*s/m, c_perp = %.1f N*s/m", c_aero_par, c_aero_perp))

    u_dyn = copy(u_settled)
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

    SIM_TOTAL_S = 120.0
    CHUNK_S = 10.0
    n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
    chunk_steps = round(Int, CHUNK_S / dt)

    println("-"^80)
    @printf("%-6s | %-10s %-10s %-10s %-10s | %-10s %-10s\n",
        "Time", "HubLat(m)", "SALat(m)", "KiteLat(m)", "T_line(N)", "Kite X(m)", "Kite Z(m)")
    println("-"^80)

    for i in 1:n_chunks
        t_sim = i * CHUNK_S
        run_sim_dynamic_kite!(
            u_dyn, sys, p, wf, chunk_steps, dt,
            p_kite, v_kite, L0_lift, EA_lift, c_line, m_kite,
            F_aero_trim, c_aero_par, c_aero_perp;
            lin_damp=0.05
        )

        h_lat = lat_of(pos(u_dyn, hub_gid))
        sa_lat = lat_of(pos(u_dyn, sa_gid))
        k_lat = lat_of(p_kite)
        L_current = norm(p_kite .- pos(u_dyn, sa_gid))
        T_now = max(0.0, EA_lift * (L_current - L0_lift) / L0_lift)

        @printf("%5.1f s | %-10.4f %-10.4f %-10.4f %-10.1f | %-10.3f %-10.3f\n",
            t_sim, h_lat, sa_lat, k_lat, T_now, p_kite[1], p_kite[3])
        flush(stdout)
    end
    println("="^80)
end

main()
