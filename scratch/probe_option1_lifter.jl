# scratch/probe_option1_lifter.jl
#
# Probe testing Option 1: Steady Flying Anchor with Elastic-Damped Lift Line
# Compare against Baseline (jumping kite phantom) on the v13 Winner.

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const WINNER_CSV = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)
const WINNER_L = 18.8
const WINNER_KW = 5.0

function build_winner_case()
    p = params_at_length(params_daisy(), WINNER_L, WINNER_KW)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    dec = design_from_vector_v10(
        xv,
        PROFILE_ELLIPTICAL,
        p;
        power_W=WINNER_KW * 1000.0,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=bf,
    )
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=WINNER_KW * 1000.0,
        v_rated=11.0,
        p_floor_kw=WINNER_KW,
        fos_target=2.5,
        fos_hard=2.5,
        min_wall_m=2e-3,
        t_over_D=0.055,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=bf,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, pc)
    wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

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
    callback=nothing,
)
    N = sys.n_total
    Nr = sys.n_ring
    sa_gid = sys.sky_anchor_id
    m_sa = sys.nodes[sa_gid].mass
    du = zeros(Float64, length(u))
    t = 0.0
    # Note: ode_params has lift_device = nothing so ring_forces skips open-loop lift
    ode_params = (sys, p, wind_fn)

    for step in 1:n_steps
        sys.any_broken[] && break
        fill!(du, 0.0)

        # Pre-ODE NaN guard
        omega_pre = @view u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_pre = @view u[(6N + 1):(6N + Nr)]
        for ri in findall(!isfinite, omega_pre)
            omega_pre[ri] = 0.0
        end
        for ri in findall(!isfinite, alpha_pre)
            alpha_pre[ri] = 0.0
        end

        multibody_ode!(du, u, ode_params, t)

        # ── Option 1: Elastic-damped lift line from anchored kite ──
        sa_pos = @view u[(3 * (sa_gid - 1) + 1):(3 * sa_gid)]
        sa_vel = @view u[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)]
        r_line = kite_anchor .- sa_pos
        L_line = norm(r_line)
        u_line = r_line ./ L_line
        L_dot = -dot(sa_vel, u_line)  # positive when moving away from kite
        T_line = max(0.0, EA_lift * (L_line - L0_lift) / L0_lift + c_lift * L_dot)
        F_lift = T_line .* u_line

        # Apply to sky anchor acceleration
        @views du[(3 * N + 3 * (sa_gid - 1) + 1):(3 * N + 3 * sa_gid)] .+= F_lift ./ m_sa

        t += dt

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        # Ring twist derivatives
        omega_gnd_old = u[6N + Nr + 1]
        omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
        unsafe_ri = findall(!isfinite, omega_dot)
        if !isempty(unsafe_ri)
            omega_dot[unsafe_ri] .= 0.0
        end
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
        KiteTurbineDynamics.apply_brake_constraint!(u, sys, N, Nr)

        # Semi-implicit braking
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
        if !isempty(unsafe_omega)
            omega_view[unsafe_omega] .= 0.0
        end

        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]
        alpha_view = @view u[(6N + 1):(6N + Nr)]
        unsafe_alpha = findall(!isfinite, alpha_view)
        if !isempty(unsafe_alpha)
            alpha_view[unsafe_alpha] .= 0.0
        end

        if lin_damp > 0.0
            KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)
        end

        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        # Option 1: sys.kite_pos stays fixed at kite_anchor!
        sys.kite_pos .= kite_anchor

        if callback !== nothing
            callback(u, t, step, T_line, L_line)
        end
    end
    return u
end

println("Smoke test compiling probe...")
sys, u0, p, lift, wf = build_winner_case()
println("Winner case built. Settling...")
t_s = @elapsed u_settled = settle_to_operational_state(
    sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=100_000
)
println("Settle took: ", round(t_s; digits=2), " s")

sa_gid = sys.sky_anchor_id
sa_settled = pos(u_settled, sa_gid)
θ_lift = p.lifter_elevation
lift_dir = [cos(θ_lift), 0.0, sin(θ_lift)]
kite_anchor = sa_settled .+ lift.line_length .* lift_dir
_, T_ref, _ = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
EA_lift = lift.line_EA
L0_lift = lift.line_length / (1.0 + T_ref / EA_lift)

println(
    @sprintf(
        "Sky anchor settled: [%.3f, %.3f, %.3f]",
        sa_settled[1],
        sa_settled[2],
        sa_settled[3]
    )
)
println(
    @sprintf(
        "Kite anchor pos:   [%.3f, %.3f, %.3f]",
        kite_anchor[1],
        kite_anchor[2],
        kite_anchor[3]
    )
)
println(
    @sprintf(
        "T_ref: %.2f N, L_line: %.2f m, L0: %.4f m, ΔL: %.2f mm",
        T_ref,
        lift.line_length,
        L0_lift,
        (lift.line_length - L0_lift)*1000
    )
)

# Quick 5-second test of Option 1
dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
println("dt = ", dt)
u_test = copy(u_settled)
n_5s = round(Int, 5.0 / dt)
println("Running 5 s test of Option 1 (c_line = 100 N*s/m)...")
t_run = @elapsed run_sim_option1!(
    u_test, sys, p, wf, n_5s, dt, kite_anchor, L0_lift, EA_lift, 100.0; lin_damp=0.05
)
sa_end = pos(u_test, sa_gid)
hub_end = pos(u_test, sys.rotor.node_id)
println(
    @sprintf(
        "5 s completed in %.2f s. Hub pos: [%.3f, %.3f, %.3f], SA pos: [%.3f, %.3f, %.3f]",
        t_run,
        hub_end[1],
        hub_end[2],
        hub_end[3],
        sa_end[1],
        sa_end[2],
        sa_end[3]
    )
)
