# scratch/diag_winner_as_seed.jl
#
# Purpose (2026-09-13, DSH session; Rod's proposal): would re-seeding — assigning
# the campaign WINNER's genome values to the seed — be viable?
#
# Layout fact this probe checks: KiteTurbineDynamics.TRPT_V10_DIM_LEGACY = 14 is
# `[Do_top, t_over_D, beam_aspect, Do_scale_exp, <canonical 10>]`, so the
# canonical 10-D seed is the legacy vector's LAST 10 entries.  Verified against
# the tests' own index handling: n_lines is legacy[8] and canonical[4];
# rotor_count is legacy[10] and canonical[6] — i.e. canonical[i] = legacy[i+4].
#
# Prints the DECODED machine for both, so the comparison is measured, not read
# off gene positions.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const WINNER = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

read_vec(p) = [parse(Float64, s) for s in split(strip(read(p, String)), ",")]

x_legacy = read_vec(WINNER)
@assert length(x_legacy) == KiteTurbineDynamics.TRPT_V10_DIM_LEGACY "expected a legacy 14-D winner, got $(length(x_legacy))"
x_seed = seed_genome(5.0)
@assert length(x_seed) == KiteTurbineDynamics.TRPT_V10_DIM

x_winner_canonical = x_legacy[(KiteTurbineDynamics.TRPT_V10_DIM_LEGACY - KiteTurbineDynamics.TRPT_V10_DIM + 1):end]
println("winner legacy 14-D  = ", round.(x_legacy; digits=4))
println("winner canonical 10 = ", round.(x_winner_canonical; digits=4))
println("current seed    10  = ", round.(x_seed; digits=4))
# Canonical indices: 4 = n_lines, 6 = rotor_count (see seed_genome / run_eval).
println("\ncanonical[4] n_lines:      seed=$(round(x_seed[4]))  winner=$(round(x_winner_canonical[4]))")
println("canonical[6] rotor_count:  seed=$(round(x_seed[6]))  winner=$(round(x_winner_canonical[6]))")

# Decode BOTH through the campaign decode so we compare machines, not genes.
function decode10(x10)
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    p = params_5kw_188()
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    return p, dec
end

for (name, x10) in (("SEED  ", x_seed), ("WINNER", x_winner_canonical))
    p, dec = decode10(x10)
    println("\n--- decoded $name")
    println("    n_lines      = ", dec.design.n_lines)
    println("    n_active     = ", dec.n_active, "   n_rings = ", dec.n_rings)
    println("    r_hub        = ", round(dec.design.r_hub; digits=3), " m")
end
println("\n=== done ===")
