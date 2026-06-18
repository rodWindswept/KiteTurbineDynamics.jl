#!/usr/bin/env julia
# scripts/analyze_v64_results.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using CSV, DataFrames, Printf, Statistics

function main()
    println("═══════════════════════════════════════════════════════")
    println("  V6.4 Campaign — Deep Analysis with Per-Island Data")
    println("═══════════════════════════════════════════════════════")

    # Load per-island best vectors
    ib = CSV.read("scripts/results/v6_4_campaign_50kw/island_bests.csv", DataFrame)
    n = nrow(ib)

    param_names = ["Do_top", "t_over_D", "aspect", "Do_exp", "r_hub", "r_bottom",
                   "target_Lr", "n_lines", "density", "n_exp", "bank_deg", "blade_scale"]

    # Round integer params
    ib.x8 = round.(Int, ib.x8)
    ib.x10 = round.(Int, ib.x10)

    feasible = ib[ib.mass_kg .< 1000, :]
    n_feas = nrow(feasible)
    @printf("Feasible: %d/%d (%.0f%%)\n", n_feas, n, n_feas/n*100)
    @printf("Mass: %.2f–%.2f kg  mean=%.2f  median=%.2f  σ=%.2f\n\n",
            minimum(feasible.mass_kg), maximum(feasible.mass_kg),
            mean(feasible.mass_kg), median(feasible.mass_kg), std(feasible.mass_kg))

    # ═══════════════════════════════════════════════════════════
    # Parameter distributions
    # ═══════════════════════════════════════════════════════════
    println("── Parameter distributions across $(n_feas) feasible islands ──")
    for (j, name) in enumerate(param_names)
        col = Symbol("x$(j)")
        if j == 8 || j == 10  # integer params
            vals = Int.(feasible[!, col])
            counts = sort(combine(groupby(DataFrame(val=vals), :val), nrow => :count), :val)
            parts = ["$(r.val)($(r.count))" for r in eachrow(counts)]
            println("  $(name): $(join(parts, ", "))")
        else
            vals = feasible[!, col]
            @printf("  %-14s  %.4f–%.4f  μ=%.4f  σ=%.4f\n",
                    name, minimum(vals), maximum(vals), mean(vals), std(vals))
        end
    end

    # ═══════════════════════════════════════════════════════════
    # Key counts
    # ═══════════════════════════════════════════════════════════
    println("\n── Strategic choices across islands ──")

    n_lines_vals = Int.(feasible.x8)
    for nl in sort(unique(n_lines_vals))
        cnt = count(n_lines_vals .== nl)
        masses = feasible.mass_kg[n_lines_vals .== nl]
        @printf("  n_lines=%d: %d islands  mass %.1f–%.1f kg (μ=%.1f)\n",
                nl, cnt, minimum(masses), maximum(masses), mean(masses))
    end

    n_exp_vals = Int.(feasible.x10)
    for ne in sort(unique(n_exp_vals))
        cnt = count(n_exp_vals .== ne)
        masses = feasible.mass_kg[n_exp_vals .== ne]
        @printf("  n_exp=%2d: %d islands  mass %.1f–%.1f kg (μ=%.1f)\n",
                ne, cnt, minimum(masses), maximum(masses), mean(masses))
    end

    # ═══════════════════════════════════════════════════════════
    # Outliers — islands that didn't find the 24 kg basin
    # ═══════════════════════════════════════════════════════════
    println("\n── Islands that missed the 24 kg basin ──")
    outliers = feasible[feasible.mass_kg .> 25.0, :]
    if nrow(outliers) > 0
        for row in eachrow(outliers)
            nl = Int(row.x8); ne = Int(row.x10)
            @printf("  Island %2d: %.1f kg  n_lines=%d  n_exp=%d  blade_scale=%.3f  bank=%.1f°\n",
                    row.island, row.mass_kg, nl, ne, row.x12, row.x11)
        end
    else
        println("  NONE — all islands found the same basin")
    end

    # ═══════════════════════════════════════════════════════════
    # Best design detail
    # ═══════════════════════════════════════════════════════════
    best = ib[ib.mass_kg .== minimum(ib.mass_kg), :][1, :]
    println("\n── Global best (Island $(best.island)) ──")
    for (j, name) in enumerate(param_names)
        col = Symbol("x$(j)")
        if j == 8 || j == 10
            @printf("  %-14s  %d\n", name, Int(best[col]))
        else
            @printf("  %-14s  %.6f\n", name, best[col])
        end
    end

    # ═══════════════════════════════════════════════════════════
    # Bounds check
    # ═══════════════════════════════════════════════════════════
    println("\n── Parameters at bounds ──")
    bounds = [
        (0.01, 0.25), (0.01, 0.15), (1.0, 3.0), (0.0, 2.0),
        (1.0, 8.0), (0.1, 5.0), (0.5, 5.0), (3, 12),
        (-0.8, 0.8), (0, 12), (5.0, 35.0), (0.02, 2.0)
    ]
    at_bound = 0
    for (j, name) in enumerate(param_names)
        col = Symbol("x$(j)")
        vals = feasible[!, col]
        lo, hi = bounds[j]
        lo_hit = count(vals .<= lo * 1.01 .+ 1e-9)
        hi_hit = count(vals .>= hi * 0.99 .- 1e-9)
        if lo_hit > 0 || hi_hit > 0
            at_bound += 1
            parts = String[]
            if lo_hit > 0; push!(parts, "$lo_hit at min"); end
            if hi_hit > 0; push!(parts, "$hi_hit at max"); end
            @printf("  %-14s  bound [%.3f, %.1f]  %s\n", name, lo, hi, join(parts, ", "))
        end
    end
    if at_bound == 0
        println("  None — all parameters interior")
    end

    println("\n── Done ──")
end

main()
