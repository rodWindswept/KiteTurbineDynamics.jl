# scratch/probe_eval_trace.jl
#
# 2026-09-19.  Trace the REAL evaluate_windowed path for the B6 winner with its
# trace_callback hook, so the twist ratio can be read exactly where the evaluator
# latches twist_flagged.  NOTE the evaluator builds with cfg.tether_diameter,
# which v13_cfg leaves at its 0.003 default (unscaled), whereas gate_design uses
# the scaled p.tether_diameter = 0.003651 — a different machine.

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0; const PW = KW * 1000.0; const V_RATED = 11.0
const BEAM = PROFILE_ELLIPTICAL; const L18 = 18.8
const WINNER = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

function v13_cfg(window_s, k)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=k, power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0, relax_s=5.0, window_s=window_s,
        fos_target=2.5, fos_hard=2.5, power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0, rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
end

function main()
    p = params_at_length(params_daisy(), L18, KW)
    x = [parse(Float64, s) for s in split(strip(read(WINNER, String)), ",")]
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    @printf("genome: n_lines=%.0f rotorcount=%.0f   cfg.tether_diameter(default)=%.6f  p.tether_diameter=%.6f\n",
        x[8], x[10], v13_cfg(20.0, K_MPPT_5KW_HONEST).tether_diameter, p.tether_diameter)

    rows = NamedTuple[]
    for tether in (v13_cfg(20.0, K_MPPT_5KW_HONEST).tether_diameter, p.tether_diameter)
        empty!(rows)
        cb = function (uc, tc, s, ctx)
            iv = round(Int, 1.0 / KiteTurbineDynamics.stable_dt_for_system(ctx.sys, ctx.pc))
            if s % iv == 0
                tr = KiteTurbineDynamics.twist_collapse_check(uc, ctx.sys)
                push!(rows, (t=tc, ratio=tr.max_ratio, crossed=tr.crossed,
                             worst=tr.worst_seg))
            end
        end
        cfg0 = v13_cfg(20.0, K_MPPT_5KW_HONEST)
        cfg = KiteTurbineDynamics.ObjectiveConfig(cfg0; tether_diameter=tether)
        r = KiteTurbineDynamics.evaluate_windowed(
            x, BEAM, p, cfg;
            start_mode=:cold, lift_device=lift_for, trace_callback=cb,
            fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m))
        @printf("\n=== tether_diameter=%.6f (scaled=%s) ===\n", tether,
            tether == p.tether_diameter)
        @printf("  MAX ratio=%.3f  any crossed=%s  status=%s  P_mean=%.2f\n",
            maximum(r.ratio for r in rows), any(r.crossed for r in rows),
            r.status, r.P_mean)
        for row in rows
            @printf("  t=%6.1f  ratio=%7.3f  worst_seg=%d  crossed=%s\n",
                row.t, row.ratio, row.worst, row.crossed)
        end
    end
    println("=== done ===")
end

main()
