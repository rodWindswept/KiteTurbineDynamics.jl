# scratch/probe_option1_comparison.jl
#
# Head-to-head comparison:
#   A) Baseline: Jumping Kite Phantom (current canonical model)
#   B) Option 1: Anchored Kite with Elastic-Damped Lift Line (c = 200 N*s/m)
# Tested on the v13 Winner over a 60-second horizon.

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

function cyan_tension(u, sys)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
           (na == sys.bearing_id && nb == sys.sky_anchor_id)
            L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
            total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        end
    end
    return total
end

function back_tension(u, sys, p)
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    r_top = isempty(sys.expansion_rotors) ? (sys.nodes[hub_gid]::RingNode).radius :
            sys.effective_radii[hub_ri]
    bearing_offset = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    cyan_L0 = KiteTurbineDynamics.CYAN_L0_DESIGN
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    sa = pos(u, sys.sky_anchor_id)
    b_dx = sqrt((sa[1] - back_ax)^2 + sa[2]^2)
    b_dz = sa[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    L_axis_design = p.tether_length + bearing_offset + cyan_L0
    d_sa_x = L_axis_design * cos(p.elevation_angle)
    d_sa_z = L_axis_design * sin(p.elevation_angle)
    back_L0_design = sqrt((d_sa_x - back_ax)^2 + d_sa_z^2)
    return KiteTurbineDynamics.back_line_tension(
        b_dist, back_L0_design, p.backline_payout, p.EA_back_line
    )
end

function run_sim_option1!(
    u::Vector{Float64},
    sys::KiteTurbineSystem,
    p::SystemParams,
    wind_fn::Function,
    n_steps::Int,
    dt::Float64,
    kite_anchor::Vector{Float64},
    L0_lift::Float64,
    EA_lift::Float64,
    c_lift::Float64;
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

        # Option 1: Elastic-damped lift line from anchored kite
        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]
        r_line = kite_anchor .- sa_pos
        L_line = norm(r_line)
        u_line = r_line ./ L_line
        L_dot = -dot(sa_vel, u_line)
        T_line = max(0.0, EA_lift * (L_line - L0_lift) / L0_lift + c_lift * L_dot)
        F_lift = T_line .* u_line

        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_lift ./ m_sa

        t += dt

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

        sys.kite_pos .= kite_anchor
    end
    return u
end

function main()
    println("="^70)
    println("PROBE: Baseline (Jumping Kite) vs Option 1 (Anchored Kite + Elastic Line)")
    println("="^70)

    sys_b, u0_b, p, lift, wf = build_winner_case()
    sys_1, u0_1, _, _, _ = build_winner_case()

    println("Settling base case...")
    u_settled = settle_to_operational_state(
        sys_b, copy(u0_b), p, 60.0; lift_device=lift, wind_fn=wf, n_op=200_000
    )
    dt = KiteTurbineDynamics.stable_dt_for_system(sys_b, p)
    println(@sprintf("Settled. dt = %.6e s", dt))

    sa_gid = sys_b.sky_anchor_id
    hub_gid = sys_b.rotor.node_id
    sa_settled = pos(u_settled, sa_gid)
    θ_lift = p.lifter_elevation
    lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
    kite_anchor = sa_settled .+ lift.line_length .* lift_dir
    _, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    EA_lift = lift.line_EA
    L0_lift = lift.line_length / (1.0 + T_ref / EA_lift)
    c_lift = 200.0   # N*s/m

    println(@sprintf("Sky Anchor settled: [%.3f, %.3f, %.3f]", sa_settled[1], sa_settled[2], sa_settled[3]))
    println(@sprintf("Kite Anchor pos:   [%.3f, %.3f, %.3f]", kite_anchor[1], kite_anchor[2], kite_anchor[3]))
    println(@sprintf("T_ref: %.1f N, L_line: %.2f m, L0: %.4f m, c_lift: %.1f N*s/m",
        T_ref, lift.line_length, L0_lift, c_lift))

    u_base = copy(u_settled)
    u_opt1 = copy(u_settled)

    # Lateral displacement helper relative to ideal shaft axis
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    lat_of(v) = norm(v .- dot(v, shaft) .* shaft)

    SIM_TOTAL_S = 120.0
    CHUNK_S = 10.0
    n_chunks = round(Int, SIM_TOTAL_S / CHUNK_S)
    chunk_steps = round(Int, CHUNK_S / dt)

    println("-"^80)
    @printf("%-6s | %-34s | %-34s\n", "Time", "Baseline (Jumping Kite)", "Option 1 (Anchored Kite)")
    @printf("%-6s | %-9s %-9s %-12s | %-9s %-9s %-12s\n", "s", "HubLat(m)", "SALat(m)", "T_cyan(N)", "HubLat(m)", "SALat(m)", "T_lift(N)")
    println("-"^80)

    for i in 1:n_chunks
        t_sim = i * CHUNK_S
        # Run Baseline chunk
        run_canonical_sim!(u_base, sys_b, p, wf, chunk_steps, dt; lift_device=lift, lin_damp=0.05)
        # Run Option 1 chunk
        run_sim_option1!(u_opt1, sys_1, p, wf, chunk_steps, dt, kite_anchor, L0_lift, EA_lift, c_lift; lin_damp=0.05)

        h_lat_b = lat_of(pos(u_base, hub_gid))
        sa_lat_b = lat_of(pos(u_base, sa_gid))
        t_cy_b = cyan_tension(u_base, sys_b)

        h_lat_1 = lat_of(pos(u_opt1, hub_gid))
        sa_lat_1 = lat_of(pos(u_opt1, sa_gid))
        L_1 = norm(kite_anchor .- pos(u_opt1, sa_gid))
        t_lift_1 = max(0.0, EA_lift * (L_1 - L0_lift) / L0_lift)

        @printf("%5.1f s | %-9.4f %-9.4f %-12.1f | %-9.4f %-9.4f %-12.1f\n",
            t_sim, h_lat_b, sa_lat_b, t_cy_b, h_lat_1, sa_lat_1, t_lift_1)
        flush(stdout)
    end
    println("="^80)
end

main()
