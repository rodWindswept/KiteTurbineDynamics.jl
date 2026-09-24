# scratch/probe_winner_window.jl
#
# 2026-09-19.  B6's twist_crossed is NOT a static-demand problem: the winner's
# demand at equilibrium is 0.511 against a 0.9524 target, so the ruled preload
# correction never fires.  This probe runs the evaluator's OWN protocol
# (n_op=150_000 settle -> relax_s=5 + window_s=20, sampled every 1 s) and prints
# the twist ratio time series with the polish ON and OFF, to find when and why it
# crosses.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0;
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
    return p, sys, u0, pc
end

function main()
    for polish in (false, true)
        p, sys, u0, pc = build_winner()
        dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = lift_for(sys, pc)
        u = settle_to_operational_state(
            sys,
            copy(u0),
            pc,
            60.0;
            lift_device=lift,
            wind_fn=wind_fn,
            operational_polish=polish,
        )
        sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
        @printf("\n=== operational_polish=%s  dt=%.3e ===\n", polish, dt)
        @printf(
            "  t=0 ratio=%.4f\n", KiteTurbineDynamics.twist_collapse_check(u, sys).max_ratio
        )
        sample_interval = round(Int, 1.0 / dt)
        rows = NamedTuple[]
        cb = function (uc, tc, s)
            if s % sample_interval == 0
                tr = KiteTurbineDynamics.twist_collapse_check(uc, sys)
                push!(rows, (t=tc, ratio=tr.max_ratio, crossed=tr.crossed))
            end
        end
        total_n = round(Int, 25.0 / dt)
        run_canonical_sim!(
            u,
            sys,
            pc,
            wind_fn,
            total_n,
            dt;
            lift_device=lift,
            lin_damp=0.05,
            callback=cb,
            breaks_enabled=true,
        )
        for r in rows
            @printf("  t=%5.1f  ratio=%6.3f  crossed=%s\n", r.t, r.ratio, r.crossed)
        end
        mx = maximum(r.ratio for r in rows)
        @printf(
            "  MAX ratio=%.3f   any crossed=%s   broken=%s\n",
            mx,
            any(r.crossed for r in rows),
            sys.any_broken[]
        )
    end
    return println("=== done ===")
end

main()
