# scratch/probe_winner_polish.jl
#
# 2026-09-19.  test_evaluator_v13 B6 now REJECTS the campaign winner with the
# twist-collapse signature (objective_evaluator.jl:792).  This probe compares the
# winner's settled state and its 10 s relax + 5 s window with the operational
# polish ON and OFF, to see whether the full-force equilibrium lowers segment
# tension enough to push the twist ratio over the cliff.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8
const WINNER = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

function build_winner()
    p = params_at_length(params_daisy(), L18, KW)
    xv = [parse(Float64, s) for s in split(strip(read(WINNER, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    bf = BLOCKING_WIND_FACTOR_5KW
    dec = design_from_vector_v10(
        xv,
        PROFILE_ELLIPTICAL,
        p;
        power_W=KW * 1000.0,
        cylinder_cone=true,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=bf,
    )
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=KW * 1000.0,
        v_rated=11.0,
        p_floor_kw=KW,
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
    return p, xv, dec, sys, u0, pc
end

function main()
    for polish in (false, true)
        p, xv, dec, sys, u0, pc = build_winner()
        dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = lift_for(sys, pc)
        N, Nr = sys.n_total, sys.n_ring
        u = settle_to_operational_state(
            sys,
            copy(u0),
            pc,
            60.0;
            lift_device=lift,
            wind_fn=wind_fn,
            n_op=30_000,
            operational_polish=polish,
        )
        sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
        tr0 = KiteTurbineDynamics.twist_collapse_check(u, sys)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wind_fn, lift)
        ω = u[6N + Nr + 1]
        F_ax = design_axial_preload(sys, pc, lift, u0; omega_eq=ω, wind_fn=wind_fn)
        intended = F_ax ./ pc.n_lines
        @printf("\n=== operational_polish=%s  (ω=%.4f, rings=%d) ===\n", polish, ω, Nr)
        @printf("  t=0 twist: crossed=%s max_ratio=%.4f\n", tr0.crossed, tr0.max_ratio)
        println("  seg  intended N   settled N   ratio   twist_deg")
        for s in 1:(Nr - 1)
            @printf(
                "  %3d %11.2f %11.2f %8.4f %10.2f\n",
                s,
                intended[s],
                ef.segment_tension[s],
                ef.segment_tension[s] / intended[s],
                ef.segment_twist_deg[s]
            )
        end
        # 10 s relax then one 5 s window, as the gate/evaluator do
        for _ in 1:2
            run_canonical_sim!(
                u,
                sys,
                pc,
                wind_fn,
                round(Int, 5.0 / dt),
                dt;
                lift_device=lift,
                lin_damp=0.05,
            )
        end
        run_canonical_sim!(
            u,
            sys,
            pc,
            wind_fn,
            round(Int, 5.0 / dt),
            dt;
            lift_device=lift,
            lin_damp=0.05,
            breaks_enabled=true,
        )
        tr1 = twist_report(u, sys, N, Nr)
        w_gnd = u[6N + Nr + 1]
        @printf(
            "  after 15 s: crossed=%s max_ratio=%.4f  w_gnd=%.4f  broken=%s\n",
            tr1.crossed,
            tr1.max_ratio,
            w_gnd,
            sys.any_broken[]
        )
    end
    return println("=== done ===")
end

main()
