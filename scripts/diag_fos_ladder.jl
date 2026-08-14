#!/usr/bin/env julia --project=.
#= diag_fos_ladder.jl — torsional + buckling FoS and tether length across
the graduated ladder (5→50 kW), using each rung's scaled params and seed. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

println("Rung   Tether(m)  r_hub(m)  r_bot(m)  n_lines  rings  tors FoS  buck FoS  verdict")
println("─"^85)
for kw in [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0]
    pw = kw * 1000.0
    p = mass_scale(params_10kw(), 10.0, kw)
    x = seed_genome(kw)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=pw)
    r = evaluate_design_v5(dec.design; power_W=pw)
    ok = r.feasible ? "✓" : "✗"
    @printf("%3.0fkW  %8.1f  %6.2f  %6.2f  %4d     %4d   %6.2f    %5.2f    %s\n",
        kw, p.tether_length, dec.design.r_hub, dec.design.r_bottom,
        dec.design.n_lines, dec.n_rings, r.min_torsional_fos, r.min_fos, ok)
end
println("─"^85)
println("Gate: tors ≥ 1.5, buckling ≥ 1.8. Verdict is static-evaluator feasible (✗ = gate fail).")
