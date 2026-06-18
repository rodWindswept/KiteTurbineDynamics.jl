#!/usr/bin/env julia
# extract_tikz_data.jl
# Extract downsampled trajectory data for TikZ diagram generation.
# Output: compact CSV files with ~100 data points per series.

using CSV
using DataFrames
using Statistics
using Printf

const RESDIR = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/v6_5_campaign_50kw/trajectory_analysis"
const OUTDIR = joinpath(RESDIR, "tikz_data")
mkpath(OUTDIR)

# ── Load processed data ──────────────────────────────────────────────────────
best = CSV.read(joinpath(RESDIR, "best_sofar_trajectory.csv"), DataFrame)
ensemble = CSV.read(joinpath(RESDIR, "ensemble_per_iteration.csv"), DataFrame)
selected = CSV.read(joinpath(RESDIR, "selected_island_traces.csv"), DataFrame)
phases = CSV.read(joinpath(RESDIR, "phase_transitions.csv"), DataFrame)

max_iter = 10000

# ── 1. Downsample ensemble statistics ────────────────────────────────────────
# For mass, blade_scale, n_lines, n_exp, bank_angle, density_profile
# Take every 50th iteration for the full range, every 10th for first 200
ds_full = ensemble[mod.(ensemble.iteration, 50) .== 1, :]  # ~200 points
ds_early = ensemble[ensemble.iteration .<= 200, :]  # full early resolution
# Combine: early at full resolution, then every 100th after
ds_combined = vcat(
    ensemble[ensemble.iteration .<= 200, :],
    ensemble[ensemble.iteration .> 200 .&& mod.(ensemble.iteration, 100) .== 1, :]
)
sort!(ds_combined, :iteration)
CSV.write(joinpath(OUTDIR, "ensemble_downsampled.csv"), ds_combined)
println("  → ensemble_downsampled.csv ($(nrow(ds_combined)) rows)")

# ── 2. Extract key statistics at landmark iterations ─────────────────────────
landmarks = [1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]
landmark_data = DataFrame(iteration = Int[], param = String[],
                          median = Float64[], q25 = Float64[], q75 = Float64[])
for iter in landmarks
    row = ensemble[ensemble.iteration .== iter, :]
    if nrow(row) == 0
        continue
    end
    r = row[1, :]
    for param in ["mass_median", "n_lines_median", "blade_scale_median",
                  "n_expansion_median", "bank_angle_deg_median", "density_profile_median"]
        push!(landmark_data, [iter, param, r[Symbol(param)],
                              r[Symbol(replace(param, "_median" => "_q25"))],
                              r[Symbol(replace(param, "_median" => "_q75"))]])
    end
end
CSV.write(joinpath(OUTDIR, "landmark_statistics.csv"), landmark_data)
println("  → landmark_statistics.csv ($(nrow(landmark_data)) rows)")

# ── 3. Per-island best-so-far traces (downsampled) ───────────────────────────
# Pick islands: best, median, worst, and the outlier
phases.n_lines_rounded = round.(Int, phases.final_n_lines)
island_order = sort(phases, :best_mass)

# Best island (lowest mass)
best_island = island_order.island[1]
# Median island
median_island = island_order.island[div(nrow(island_order), 2)]
# Worst feasible island
worst_island = island_order.island[nrow(island_order)]

println("  Best island: $best_island  (mass=$(island_order.best_mass[1]) kg)")
println("  Median island: $median_island  (mass=$(island_order.best_mass[div(nrow(island_order),2)]) kg)")
println("  Worst island: $worst_island  (mass=$(island_order.best_mass[end]) kg)")

# Extract best-so-far traces for these islands, downsample
trace_islands = DataFrame()
for isl in [best_island, median_island, worst_island]
    isl_trace = best[best.island .== isl, :]
    sort!(isl_trace, :iteration)
    # Downsample: every 200th after first 100
    sub = vcat(
        isl_trace[isl_trace.iteration .<= 100, :],
        isl_trace[isl_trace.iteration .> 100 .&& mod.(isl_trace.iteration, 200) .== 1, :]
    )
    append!(trace_islands, sub)
end
CSV.write(joinpath(OUTDIR, "island_traces_downsampled.csv"), trace_islands)
println("  → island_traces_downsampled.csv ($(nrow(trace_islands)) rows)")

# ── 4. Co-evolution data (binned by n_lines + iteration phase) ───────────────
# Group by rounded n_lines and iteration phase
sample = CSV.read(joinpath(RESDIR, "coevolution_sample.csv"), DataFrame)
sample.n_lines_r = round.(Int, clamp.(sample.n_lines, 0, 20))
# Manual iteration phase binning
function iter_phase_label(iter)
    if iter <= 10
        "1-10"
    elseif iter <= 100
        "11-100"
    elseif iter <= 1000
        "101-1k"
    elseif iter <= 5000
        "1k-5k"
    else
        "5k-10k"
    end
end

sample.iter_phase = iter_phase_label.(sample.iteration)

# Collapse to per-(n_lines, phase) statistics
coevol = combine(groupby(sample, [:n_lines_r, :iter_phase]),
                 nrow => :count,
                 :blade_scale => median => :blade_scale_median,
                 :blade_scale => (x -> quantile(x, 0.25)) => :blade_scale_q25,
                 :blade_scale => (x -> quantile(x, 0.75)) => :blade_scale_q75,
                 :mass => median => :mass_median)
CSV.write(joinpath(OUTDIR, "coevolution_binned.csv"), coevol)
println("  → coevolution_binned.csv ($(nrow(coevol)) rows)")

# ── 5. Convergence tightness metrics ─────────────────────────────────────────
# How tight is convergence at each landmark?
tightness = DataFrame(iteration = Int[],
                      mass_median = Float64[], mass_IQR = Float64[],
                      mass_cv = Float64[],  # coefficient of variation
                      pct_within_1kg = Float64[],
                      n_islands = Int[])

for iter in landmarks
    idf = selected[selected.iteration .== iter, :]
    if nrow(idf) == 0
        continue
    end
    masses = idf.mass
    med = median(masses)
    iqr_val = quantile(masses, 0.75) - quantile(masses, 0.25)
    cv = std(masses) / mean(masses)
    within_1kg = count(abs.(masses .- med) .< 1.0) / length(masses) * 100
    push!(tightness, [iter, med, iqr_val, cv, within_1kg, length(masses)])
end
CSV.write(joinpath(OUTDIR, "convergence_tightness.csv"), tightness)
println("  → convergence_tightness.csv ($(nrow(tightness)) rows)")

# ── 6. Phase-space trajectory for one representative island ───────────────────
# Track the best island's parameter vector through iterations (2D PCA projection)
# For simplicity, plot blade_scale vs n_lines with iteration color for the best island
best_trace = selected[selected.island .== best_island, :]
sort!(best_trace, :iteration)
# Downsample for plotting
best_trace_plot = vcat(
    best_trace[best_trace.iteration .<= 200, :],
    best_trace[best_trace.iteration .> 200 .&& mod.(best_trace.iteration, 100) .== 1, :]
)
CSV.write(joinpath(OUTDIR, "best_island_phase_trace.csv"),
          best_trace_plot[:, [:iteration, :n_lines, :blade_scale, :n_expansion, :mass, :bank_angle_deg]])
println("  → best_island_phase_trace.csv ($(nrow(best_trace_plot)) rows)")

# ── Print key numbers for annotation ─────────────────────────────────────────
println("\n===== KEY NUMBERS FOR DIAGRAM ANNOTATION =====")
feasible = phases[phases.best_mass .< 1000, :]
println("Islands: $(nrow(feasible))")
println("Final mass: $(round(minimum(feasible.best_mass), digits=2)) kg")
println("n_lines: $(round(Int, median(feasible.final_n_lines))) (100% unanimous)")
println("n_exp: $(round(Int, median(feasible.final_n_exp))) (100% unanimous, at bound)")
println("blade_scale λ: $(round(median(feasible.final_blade_scale), digits=6))")
println("Avg flip iteration: $(round(mean(phases.flip_iter[phases.flip_iter .> 0]), digits=1))")
println("Median flip iteration: $(round(median(phases.flip_iter[phases.flip_iter .> 0]), digits=1))")

# Mass at key iterations
for iter in [1, 2, 5, 10, 50, 100, 500, 1000, 5000, 10000]
    erow = ensemble[ensemble.iteration .== iter, :]
    if nrow(erow) > 0
        println("  Iter $iter: mass=$(round(erow[1, :mass_median], digits=1)) kg  λ=$(round(erow[1, :blade_scale_median], digits=4))  n_lines=$(round(erow[1, :n_lines_median], digits=1))")
    end
end

println("\nDone. TikZ data in: $OUTDIR")
