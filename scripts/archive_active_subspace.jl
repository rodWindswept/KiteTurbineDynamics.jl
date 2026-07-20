#!/usr/bin/env julia
# scripts/archive_active_subspace.jl
# Phase 0 — archive mining: extract active subspace from campaign CSVs.
# Uses pre-fix fitness for geometry screening ONLY (not δ̂).
# Output: docs/reports/2026-07-20-active-subspace.md

using CSV, DataFrames, Statistics, Printf

const CAMPAIGN_DIRS = [
    "v10_campaign_50kw_tight",
    "v10_campaign_50kw_cons",
    "v10_campaign_50kw_old",
    "v9_0_campaign_50kw",
    "v9_0_campaign_10kw",
]

# Common genome dimensions shared across V6-V10
const COMMON_COLS = [
    :Do_top_m, :t_over_D, :beam_aspect, :Do_scale_exp,
    :r_hub_m, :r_bottom_m, :target_Lr, :n_lines, :density_profile,
]

function collect_archive(base_dir::String)
    all_rows = DataFrame[]
    for d in CAMPAIGN_DIRS
        path = joinpath(base_dir, d, "island_bests.csv")
        isfile(path) || continue
        df = CSV.read(path, DataFrame)
        # Keep only common columns + mass
        keep = intersect(Symbol.(names(df)), vcat(:mass_kg, COMMON_COLS))
        if length(keep) < 3
            println("  $d: SKIP (no matching columns)")
            continue
        end
        sel = select(df, keep)
        push!(all_rows, sel)
        println("  $d: $(nrow(df)) rows, cols: $(join(keep, ", "))")
    end
    return vcat(all_rows...; cols=:union)
end

function active_subspace(df::DataFrame)
    cols = intersect(Symbol.(names(df)), COMMON_COLS)
    d = length(cols)
    X = Matrix(df[:, cols])
    y = df.mass_kg
    n = size(X, 1)

    # Compute per-dim sensitivity via binned variance
    X_norm = similar(X)
    sensitivities = zeros(d)
    n_bins = min(10, n ÷ 2)
    for j in 1:d
        col = X[:, j]
        mn, mx = extrema(col)
        rng = mx - mn
        X_norm[:, j] = rng > 0 ? (col .- mn) ./ rng : zeros(n)
        
        bin_edges = range(0.0, 1.0; length=n_bins + 1)
        bin_means = zeros(n_bins)
        bin_counts = zeros(Int, n_bins)
        for i in 1:n
            b = clamp(searchsortedlast(bin_edges, X_norm[i, j]), 1, n_bins)
            bin_means[b] += y[i]
            bin_counts[b] += 1
        end
        for b in 1:n_bins
            bin_counts[b] > 0 && (bin_means[b] /= bin_counts[b])
        end
        valid = bin_counts .> 0
        if sum(valid) >= 2
            sensitivities[j] = var(bin_means[valid])
        end
    end

    # Correlations
    correlations = [abs(cor(X[:, j], y)) for j in 1:d]

    return sensitivities, correlations, cols
end

function main()
    base = joinpath(dirname(@__DIR__), "scripts", "results")
    println("Collecting archive...")
    df = collect_archive(base)
    println("Total: $(nrow(df)) rows\n")

    sens, corrs, cols = active_subspace(df)
    ranked = sortperm(sens; rev=true)
    
    println("=== ACTIVE SUBSPACE (Phase 0) ===")
    println("Ranked by binned-fitness sensitivity:\n")
    total = sum(sens)
    cum = 0.0
    active = []
    for (rank, j) in enumerate(ranked)
        nm = string(cols[j])
        cum += sens[j]
        pct = cum / total * 100
        marker = rank <= 6 ? " ← ACTIVE" : ""
        @printf("  %2d. %-18s  sens=%.3e  |corr|=%.3f  cum=%.1f%%%s\n",
                rank, nm, sens[j], corrs[j], pct, marker)
        if rank <= 6
            push!(active, cols[j])
        end
    end
    println()
    
    println("Active dimensions (top 6 + n_lines):")
    for c in active
        println("  - $c")
    end
    println("  - n_lines (categorical — always stratify)")
    println()
    println("Caveat: only $(nrow(df)) rows — small sample. Sensitivity dominated by beam_aspect outliers.")
    println("Phase 1 LHS should stratify over all 9 common dims + n_lines; ranking guides priority.")
    
    # Write report
    report_path = joinpath(dirname(@__DIR__), "docs", "reports", "2026-07-20-active-subspace.md")
    mkpath(dirname(report_path))
    open(report_path, "w") do io
        println(io, "# Active Subspace — Phase 0 Archive Mining\n")
        println(io, "**Date:** 2026-07-20")
        println(io, "**Data:** $(nrow(df)) rows from $(length(CAMPAIGN_DIRS)) campaign directories")
        println(io, "**Pre-fix:** fitness values pre-2026-07-05 — geometry screening only\n")
        println(io, "## Rankings\n")
        println(io, "| Rank | Dimension | Sensitivity | |Corr| |")
        println(io, "|------|-----------|-------------|--------|")
        for (rank, j) in enumerate(ranked)
            @printf(io, "| %d | %s | %.3e | %.3f |\n",
                    rank, cols[j], sens[j], corrs[j])
        end
        println(io)
        println(io, "## Active subspace\n")
        for c in active
            println(io, "- `$c`")
        end
        println(io, "- `n_lines` (categorical — always stratify)")
    end
    println("Report: $report_path")
end

main()
