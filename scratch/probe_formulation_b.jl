# scratch/probe_formulation_b.jl
#
# Tests Formulation B:
#   1. Sky anchor slow-filter: d(P_sa_filt)/dt = (P_sa - P_sa_filt) / tau_kite
#   2. Kite equilibrium: P_kite = P_sa_filt + L_line * lift_dir
#   3. High-frequency vibrations (> 0.5 Hz) see a stationary kite anchor in space.
#   4. Low-frequency catenary drift (< 0.05 Hz) sees kite follow the turbine, keeping T ~ T_ref.
#   5. Elastic Dyneema lift line with internal damping c_lift = 200 N*s/m.

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

function run_sim_formulation_b!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64,
    p_sa_filt::Vector{Float64},
    L_line_nom::Float64,
    L0_lift::Float64,
    EA_lift::Float64,
    c_lift::Float64,
    tau_kite::Float64,
    lift_dir::Vector{Float64};
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

        # ── Formulation B: Elastic-Damped Lift Line from Low-Pass Kite Position ──
        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]

        # Kite position is defined from the low-pass filtered sky anchor position
        p_kite = p_sa_filt .+ L_line_nom .* lift_dir
        v_kite = (sa_pos .- p_sa_filt) ./ tau_kite

        r_line = p_kite .- sa_pos
        L_line = norm(r_line)
        u_line = r_line ./ L_line

        # Relative velocity along line: positive when stretching
        v_rel = v_kite .- sa_vel
        L_dot = dot(v_rel, u_line)

        # Elastic tension + along-line damping
        T_line = max(0.0, EA_lift * (L_line - L0_lift) / L0_lift + c_lift * L_dot)
        F_lift = T_line .* u_line

        # Apply to sky anchor
        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_lift ./ m_sa

        t += dt

        # Update low-pass filter of sky anchor position
        p_sa_filt .+= dt .* v_kite

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

        sys.kite_pos .= p_kite
    end
    return u
end

function main()
    println("="^80)
    println("PROBE: Formulation B (Low-Pass Filtered Lifter Station-Keeping)")
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
    sa_settled = copy(pos(u_settled, sa_gid))
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    p_sa_filt = copy(sa_settled)

    _, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    EA_lift = lift.line_EA
    L0_lift = lift.line_length / (1.0 + T_ref / EA_lift)
    c_lift = 200.0   # N*s/m
    tau_kite = 10.0  # seconds

    println(@sprintf("Sky Anchor settled: [%.3f, %.3f, %.3f]", sa_settled[1], sa_settled[2], sa_settled[3]))
    println(@sprintf("T_ref: %.1f N, L_line: %.2f m, L0: %.4f m, c_lift: %.1f N*s/m, tau: %.1f s",
        T_ref, lift.line_length, L0_lift, c_lift, tau_kite))

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
        run_sim_formulation_b!(
            u_dyn, sys, p, wf, chunk_steps, dt,
            p_sa_filt, lift.line_length, L0_lift, EA_lift, c_lift, tau_kite, lift_dir;
            lin_damp=0.05
        )

        h_lat = lat_of(pos(u_dyn, hub_gid))
        sa_lat = lat_of(pos(u_dyn, sa_gid))
        p_kite = p_sa_filt .+ lift.line_length .* lift_dir
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
