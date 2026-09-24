# scratch/probe_eval_flags.jl
#
# 2026-09-19.  Which reject path does the campaign winner take now?
# Reproduces test_evaluator_v13 B6 exactly and prints every ObjectiveResult flag,
# including the two the test does not print (twist_crossed, line_broken).

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0;
const PW = KW * 1000.0;
const V_RATED = 11.0
const BEAM = PROFILE_ELLIPTICAL;
const L18 = 18.8
const WINNER = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

function v13_cfg(window_s, k)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=k,
        power_W=PW,
        v_rated=V_RATED,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        relax_s=5.0,
        window_s=window_s,
        fos_target=2.5,
        fos_hard=2.5,
        power_stat=:tail5,
        penalize_ceiling=false,
        kickstart_s=0.0,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
end

function main()
    p = params_at_length(params_daisy(), L18, KW)
    x = [parse(Float64, s) for s in split(strip(read(WINNER, String)), ",")]
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    r = KiteTurbineDynamics.evaluate_windowed(
        x,
        BEAM,
        p,
        v13_cfg(20.0, K_MPPT_5KW_HONEST);
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    println("=== B6 winner evaluation flags ===")
    for f in fieldnames(typeof(r))
        println("  ", rpad(string(f), 14), " = ", getfield(r, f))
    end
    return println("=== done ===")
end

main()
