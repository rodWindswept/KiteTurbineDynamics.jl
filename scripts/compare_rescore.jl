#!/usr/bin/env julia
# scripts/compare_rescore.jl
# ═══════════════════════════════════════════════════════════════════════
# Compare old (garbage) vs new (rescored) Phase A campaign results.
#
# USAGE:
#   julia --project=. scripts/compare_rescore.jl
#
# OUTPUT:
#   scripts/results/recampaign/rescore_comparison.png  — P-vs-FoS scatter
#   stdout                                               — tier migration, Betz check, A1 sweep
#
# PREREQUISITE: scripts/rescore_phase_a.jl must have completed.
# ═══════════════════════════════════════════════════════════════════════

using CSV, DataFrames, CairoMakie, Printf

const DIR  = joinpath(@__DIR__, "results", "recampaign")
const OLD  = joinpath(DIR, "feasibility_phase_a_garbage.csv")
const NEW  = joinpath(DIR, "feasibility_phase_a_rescored.csv")
const OUT  = joinpath(DIR, "rescore_comparison.png")

old = CSV.read(OLD, DataFrame)
new = CSV.read(NEW, DataFrame)

n_old = nrow(old); n_new = nrow(new)
@printf("Old: %d rows  New: %d rows\n\n", n_old, n_new)

# ── Join on genome_hash ─────────────────────────────────────────────
joined = innerjoin(old, new; on=:genome_hash, makeunique=true)
@printf("Matched: %d rows\n\n", nrow(joined))

# ── Tier migration ──────────────────────────────────────────────────
println("═══ Tier migration ═══")
tiers = ["feasible", "feasibility", "stalled", "rejected"]
for old_tier in tiers, new_tier in tiers
    n = count(row -> row.tier == old_tier && row.tier_1 == new_tier, eachrow(joined))
    n > 0 && @printf("  %-12s → %-12s  %3d\n", old_tier, new_tier, n)
end
println()

# ── Betz ceiling check (the 1103 kW row) ────────────────────────────
println("═══ Betz ceiling check (A2) ═══")
betz_rows = filter(r -> r.P_mean_kw > 500, old)
if nrow(betz_rows) > 0
    for r in eachrow(betz_rows)
        new_row = joined[joined.genome_hash .== r.genome_hash, :]
        if nrow(new_row) > 0
            @printf("  Hash %s:  old P=%.0f kW  →  new P=%.1f kW  tier=%s\n",
                    r.genome_hash[1:8], r.P_mean_kw, new_row.P_mean_kw_1[1], new_row.tier_1[1])
        end
    end
else
    println("  No rows with P > 500 kW in old data")
end
println()

# ── A1 identity sweep ───────────────────────────────────────────────
println("═══ A1 identity: util_a + util_b ≈ 1/FoS_min ═══")
violations = 0
for r in eachrow(new)
    ua, ub, fos = r.util_axial, r.util_bending, r.FoS_min
    # Skip sentinels and edges
    ua < 0 && continue; ub < 0 && continue; isinf(fos) && continue
    expected = 1.0 / fos
    actual = ua + ub
    if !isapprox(actual, expected; rtol=0.01)
        violations += 1
    end
end
checked = count(r -> r.util_axial >= 0 && r.util_bending >= 0 && !isinf(r.FoS_min), eachrow(new))
@printf("  %d/%d rows checked, %d violations (>1%% rel tol)\n", checked, n_new, violations)
if violations > 0
    println("  ⚠  These rows have util_a/util_b from independent maxima (pre-fix code).")
    println("     Re-run rescore_phase_a.jl after commit e7bbadf for corrected values.")
end
println()

# ── P-vs-FoS scatter ────────────────────────────────────────────────
println("═══ Plotting P-vs-FoS scatter → $OUT")
tier_colors = Dict(
    "feasible"    => (:seagreen, 0.8),
    "feasibility" => (:dodgerblue, 0.6),
    "stalled"     => (:darkorange, 0.7),
    "rejected"    => (:tomato, 0.5),
)

fig = Figure(size=(1200, 500))
for (i, (label, df)) in enumerate([
    ("Old (garbage)", old),
    ("New (rescored — A1-A5)", new),
])
    ax = Axis(fig[1, i]; title=label, xlabel="P_mean (kW)", ylabel="FoS_min",
              xscale=identity, yscale=identity)
    for tier in ["rejected", "stalled", "feasibility", "feasible"]
        rows = filter(r -> r.tier == tier, df)
        nrow(rows) > 0 || continue
        scatter!(ax, rows.P_mean_kw, rows.FoS_min;
                 color=tier_colors[tier], markersize=7, label=tier)
    end
    # Betz cap marker
    P_cap = 50.0
    vlines!(ax, [P_cap]; color=:gray, linestyle=:dash, linewidth=1)
    # Feasibility region shading
    xlims!(ax, -5, 55)
    ylims!(ax, 0, ceil(maximum(df.FoS_min) + 0.5))
    i == 1 && axislegend(ax; position=:rt)
end

save(OUT, fig)
@printf("  Saved %s\n", OUT)
