#!/usr/bin/env julia
# analyze_v65_trajectories.jl
# Load parameter_trace.csv + convergence_history.csv, compute convergence trajectories.
# Output: compact CSV files for TikZ diagram generation.

using CSV
using DataFrames
using Statistics
using Printf

const RESDIR = joinpath(@__DIR__, "results", "v6_5_campaign_50kw")
const OUTDIR = joinpath(RESDIR, "trajectory_analysis")
mkpath(OUTDIR)

# ── Load data ────────────────────────────────────────────────────────────────
println("Loading parameter trace (123 MB)...")
@time trace = CSV.read(joinpath(RESDIR, "parameter_trace.csv"), DataFrame)
println("  $(nrow(trace)) rows, $(ncol(trace)) cols")

println("Loading convergence history (16 MB)...")
@time conv = CSV.read(joinpath(RESDIR, "convergence_history.csv"), DataFrame)
println("  $(nrow(conv)) rows")

# ── Join on (island, iteration) ──────────────────────────────────────────────
println("Joining trace ↔ convergence...")
@time df = innerjoin(trace, conv, on=[:island, :iteration])
println("  $(nrow(df)) joined rows")

# Rename for convenience
rename!(df, :mass_kg => :mass)

# ── Per-island best-so-far trajectories ───────────────────────────────────────
# For each island, track the best-so-far (lowest mass) design at each iteration.
# This shows what the optimizer "believes" is best at that point.

println("Computing best-so-far trajectories per island...")
islands = sort(unique(df.island))
max_iter = maximum(df.iteration)

# We'll build a DataFrame with one row per (island, iteration)
# but only for the "best so far" at each iteration.
best_sofar = DataFrame(
    island = Int[],
    iteration = Int[],
    mass = Float64[],
    n_lines = Float64[],
    blade_scale = Float64[],
    n_expansion = Float64[],
    bank_angle_deg = Float64[],
    r_bottom_m = Float64[],
    target_Lr = Float64[],
    density_profile = Float64[],
    Do_top_m = Float64[],
    t_over_D = Float64[],
    beam_aspect = Float64[],
    Do_scale_exp = Float64[],
    r_hub_m = Float64[],
)

for island in islands
    idf = sort(df[df.island .== island, :], :iteration)
    best_mass = Inf
    for row in eachrow(idf)
        if row.mass < best_mass
            best_mass = row.mass
            push!(best_sofar, [
                island, row.iteration, row.mass,
                row.n_lines, row.blade_scale, row.n_expansion,
                row.bank_angle_deg, row.r_bottom_m, row.target_Lr,
                row.density_profile, row.Do_top_m, row.t_over_D,
                row.beam_aspect, row.Do_scale_exp, row.r_hub_m
            ])
        end
    end
end
println("  $(nrow(best_sofar)) best-so-far records")

# Save best-so-far trajectories
CSV.write(joinpath(OUTDIR, "best_sofar_trajectory.csv"), best_sofar)
println("  → best_sofar_trajectory.csv")

# ── Ensemble statistics per iteration ─────────────────────────────────────────
# For each iteration, compute median and quartiles across islands.
# This shows the "typical" parameter values and dispersion.

println("Computing ensemble statistics per iteration...")

param_names = [:n_lines, :blade_scale, :n_expansion, :bank_angle_deg,
               :r_bottom_m, :target_Lr, :density_profile, :Do_top_m,
               :t_over_D, :beam_aspect, :mass]
param_labels = ["n_lines", "blade_scale", "n_expansion", "bank_angle_deg",
                "r_bottom_m", "target_Lr", "density_profile", "Do_top_m",
                "t_over_D", "beam_aspect", "mass"]

ensemble_rows = Dict{Symbol,Any}[]

# Also need island count per iteration
iter_counts = combine(groupby(df, :iteration), nrow => :n_islands)

for iter in 1:max_iter
    idf = df[df.iteration .== iter, :]
    if nrow(idf) == 0
        continue
    end
    row_data = Dict{Symbol,Any}(:iteration => iter)
    for (pname, plabel) in zip(param_names, param_labels)
        vals = idf[!, pname]
        row_data[Symbol(plabel, "_median")] = median(vals)
        row_data[Symbol(plabel, "_q25")] = quantile(vals, 0.25)
        row_data[Symbol(plabel, "_q75")] = quantile(vals, 0.75)
    end
    push!(ensemble_rows, row_data)
end

# Join island counts
ensemble = DataFrame(ensemble_rows)
ensemble = leftjoin(ensemble, iter_counts, on=:iteration)
CSV.write(joinpath(OUTDIR, "ensemble_per_iteration.csv"), ensemble)
println("  → ensemble_per_iteration.csv ($(nrow(ensemble)) rows)")

# ── Final iteration statistics (parameter distribution at convergence) ───────
println("Computing final-iteration parameter distributions...")
final_iter = maximum(df.iteration)
final_df = df[df.iteration .== final_iter, :]
final_feasible = final_df[final_df.mass .< 1000, :]
println("  Final iteration $final_iter: $(nrow(final_df)) islands, $(nrow(final_feasible)) feasible")

# Per-parameter distribution at final iteration
final_stats = DataFrame(parameter = String[], median = Float64[],
                        q25 = Float64[], q75 = Float64[],
                        min_val = Float64[], max_val = Float64[],
                        mean_val = Float64[], std_val = Float64[])
for (pname, plabel) in zip(param_names, param_labels)
    vals = final_feasible[!, pname]
    push!(final_stats, [plabel, median(vals), quantile(vals, 0.25), quantile(vals, 0.75),
                        minimum(vals), maximum(vals), mean(vals), std(vals)])
end
CSV.write(joinpath(OUTDIR, "final_parameter_distribution.csv"), final_stats)
println("  → final_parameter_distribution.csv")

# ── Selected island traces (for per-island line plots) ────────────────────────
# Pick a few representative islands (good ones, and the outlier)
println("Selecting representative islands for detailed traces...")

# Find the outlier island (n_lines=12 at V6.5)
island_bests_df = combine(groupby(best_sofar, :island), :mass => minimum => :best_mass,
                       :n_lines => (x -> round(Int, x[end])) => :final_n_lines)
feasible_islands = island_bests_df[island_bests_df.best_mass .< 1000, :]
sort!(feasible_islands, :best_mass)

# Pick: best island, median island, worst feasible, and the n=12 outlier if any
selected = Int[]
push!(selected, feasible_islands.island[1])  # best
push!(selected, feasible_islands.island[div(nrow(feasible_islands), 2)])  # median
push!(selected, feasible_islands.island[end])  # worst feasible

# Check for outlier
outlier_islands = setdiff(islands, feasible_islands.island)
if !isempty(outlier_islands)
    push!(selected, outlier_islands[1])
end

println("  Selected islands: $selected")

# Extract full traces for selected islands (not just best-so-far — the raw trace)
selected_traces = df[in.(df.island, Ref(selected)), :]
CSV.write(joinpath(OUTDIR, "selected_island_traces.csv"), selected_traces)
println("  → selected_island_traces.csv ($(nrow(selected_traces)) rows)")

# ── Co-evolution data: blade_scale vs n_lines over time ───────────────────────
# Sample every 100th iteration for scatter density
println("Sampling co-evolution data...")
sample_step = 100
sample_df = df[df.iteration .% sample_step .== 1 .|| df.iteration .== df.iteration, :]
# Actually let's take every 200th to keep it manageable
sample_df = df[mod.(df.iteration, 200) .== 1, :]
feasible_sample = sample_df[sample_df.mass .< 1000, :]
CSV.write(joinpath(OUTDIR, "coevolution_sample.csv"), feasible_sample)
println("  → coevolution_sample.csv ($(nrow(feasible_sample)) rows)")

# ── Phase detection: when does each island flip? ──────────────────────────────
println("Detecting phase transitions per island...")
phases = DataFrame(island = Int[], flip_iter = Int[], flip_from = Float64[], flip_to = Float64[],
                   final_n_lines = Float64[], final_blade_scale = Float64[],
                   final_n_exp = Float64[], best_mass = Float64[])

for island in islands
    ibsf = best_sofar[best_sofar.island .== island, :]
    sort!(ibsf, :iteration)
    if nrow(ibsf) < 2
        continue
    end
    
    nl = ibsf.n_lines
    bs = ibsf.blade_scale
    final_nl = nl[end]
    final_bs = bs[end]
    final_ne = ibsf.n_expansion[end]
    final_mass = ibsf.mass[end]
    
    # Detect n_lines flip (when n_lines changes)
    flip_iter = 0
    flip_from = 0.0
    flip_to = 0.0
    for i in 2:nrow(ibsf)
        if nl[i] != nl[i-1]
            flip_iter = ibsf.iteration[i]
            flip_from = nl[i-1]
            flip_to = nl[i]
            break
        end
    end
    
    push!(phases, [island, flip_iter, flip_from, flip_to, final_nl, final_bs, final_ne, final_mass])
end

CSV.write(joinpath(OUTDIR, "phase_transitions.csv"), phases)
println("  → phase_transitions.csv ($(nrow(phases)) islands)")

# ── Summary ───────────────────────────────────────────────────────────────────
println("\n===== SUMMARY =====")
n_feasible = count(phases.best_mass .< 1000)
println("Total islands: $(nrow(phases))")
println("Feasible: $n_feasible")
println()

# n_lines distribution at convergence
final_nl_dist = combine(groupby(phases[phases.best_mass .< 1000, :], :final_n_lines),
                        nrow => :count, :best_mass => minimum => :best_mass)
sort!(final_nl_dist, :final_n_lines)
println("Final n_lines distribution (feasible):")
for row in eachrow(final_nl_dist)
    pct = round(100 * row.count / n_feasible, digits=1)
    println("  n_lines=$(round(Int, row.final_n_lines)): $(row.count) islands ($pct%)  best mass=$(round(row.best_mass, digits=2)) kg")
end

println()
println("Phase transition stats:")
n_flipped = count(phases.flip_iter .> 0 .&& phases.best_mass .< 1000)
avg_flip = mean(phases.flip_iter[phases.flip_iter .> 0 .&& phases.best_mass .< 1000])
println("  Islands that flipped n_lines: $n_flipped")
println("  Average flip iteration: $(round(avg_flip, digits=0))")

println()
println("All outputs in: $OUTDIR")
for f in readdir(OUTDIR)
    sz = filesize(joinpath(OUTDIR, f))
    println("  $f  ($(round(sz/1024, digits=1)) KB)")
end
