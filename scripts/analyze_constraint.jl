#!/usr/bin/env julia --project=.
using CSV, DataFrames, Statistics, LinearAlgebra, Printf

# =============================================================================
# Load convergence history
# =============================================================================
csv_path = "scripts/results/v6_campaign_50kw/convergence_history.csv"
println("Loading ", csv_path, " ...")
df = CSV.read(csv_path, DataFrame)
println("Loaded ", nrow(df), " rows, ", ncol(df), " columns")
println("Columns: ", names(df))
println("Islands: ", length(unique(df.island)))
println("Iterations range: ", minimum(df.iteration), " - ", maximum(df.iteration))

# =============================================================================
# (1) Best mass per island
# =============================================================================
gdf = groupby(df, :island)
best_mass_per_island = combine(gdf, :mass_kg => minimum => :best_mass_kg)
sort!(best_mass_per_island, :best_mass_kg)

global_best = minimum(best_mass_per_island.best_mass_kg)
global_best_island = best_mass_per_island[1, :island]

println("\n" * "="^70)
println("(1) BEST MASS PER ISLAND")
println("="^70)
println("Global best: $(round(global_best, digits=2)) kg at island $(global_best_island)")

# Print top 20 islands
println("\nTop 20 islands by best mass:")
for i in 1:min(20, nrow(best_mass_per_island))
    println("  Island $(best_mass_per_island[i,:island]): $(round(best_mass_per_island[i,:best_mass_kg], digits=2)) kg")
end

# Statistics of best masses
println("\nBest mass statistics across all islands:")
bs = best_mass_per_island.best_mass_kg
println("  Min:    $(round(minimum(bs), digits=2)) kg")
println("  Max:    $(round(maximum(bs), digits=2)) kg")
println("  Mean:   $(round(mean(bs), digits=2)) kg")
println("  Median: $(round(median(bs), digits=2)) kg")
println("  Std:    $(round(std(bs), digits=2)) kg")

# =============================================================================
# (2) Islands within 10% and 20% of global best
# =============================================================================
println("\n" * "="^70)
println("(2) PROXIMITY TO GLOBAL BEST (baseline = $(round(global_best, digits=2)) kg)")
println("="^70)

threshold_10pct = global_best * 1.10
threshold_20pct = global_best * 1.20
threshold_5pct  = global_best * 1.05

n_total = nrow(best_mass_per_island)
n_within_5pct  = count(bs .<= threshold_5pct)
n_within_10pct = count(bs .<= threshold_10pct)
n_within_20pct = count(bs .<= threshold_20pct)

println("Total islands: $n_total")
println("Within  5% (≤ $(round(threshold_5pct, digits=1)) kg):  $n_within_5pct  islands ($(round(100*n_within_5pct/n_total, digits=1))%)")
println("Within 10% (≤ $(round(threshold_10pct, digits=1)) kg): $n_within_10pct islands ($(round(100*n_within_10pct/n_total, digits=1))%)")
println("Within 20% (≤ $(round(threshold_20pct, digits=1)) kg): $n_within_20pct islands ($(round(100*n_within_20pct/n_total, digits=1))%)")

# Show the near-optimal islands
println("\nIslands within 10% of global best:")
near_optimal = filter(row -> row.best_mass_kg <= threshold_10pct, best_mass_per_island)
for row in eachrow(near_optimal)
    pct_off = 100 * (row.best_mass_kg - global_best) / global_best
    println("  Island $(row.island): $(round(row.best_mass_kg, digits=2)) kg (+$(round(pct_off, digits=1))%)")
end

# Histogram view
println("\nBest-mass distribution histogram (binned by 10 kg):")
bin_width = 10.0
bin_start = floor(minimum(bs) / bin_width) * bin_width
bin_end = ceil(maximum(bs) / bin_width) * bin_width
bins = collect(bin_start:bin_width:bin_end)
counts = zeros(Int, length(bins)-1)
for m in bs
    for i in 1:length(bins)-1
        if m >= bins[i] && m < bins[i+1]
            counts[i] += 1
            break
        end
    end
    if m >= bins[end]
        counts[end] += 1
    end
end
for i in 1:length(counts)
    if counts[i] > 0
        bar = repeat("█", max(1, counts[i]))
        println("  $(round(bins[i], digits=0))-$(round(bins[i+1], digits=0)) kg: $bar ($(counts[i]))")
    end
end

# =============================================================================
# (3) Convergence speed distribution
# =============================================================================
println("\n" * "="^70)
println("(3) CONVERGENCE SPEED ANALYSIS")
println("="^70)

# For each island, find:
# - Total iterations
# - Iteration to reach within 5%, 10%, 20% of its best mass
# - Relative improvement trajectory

function convergence_metrics(island_df)
    masses = island_df.mass_kg
    best = minimum(masses)
    initial = masses[1]
    total_iters = nrow(island_df)
    
    # Iteration where best is achieved
    best_iter = findfirst(m -> m == best, masses)
    if best_iter === nothing
        best_iter = total_iters
    end
    
    # Iteration to get within X% of best (from the initial value)
    iter_5pct = nothing
    iter_10pct = nothing
    iter_20pct = nothing
    
    for (i, m) in enumerate(masses)
        rel = (m - best) / abs(initial - best + 1e-12)
        if iter_20pct === nothing && rel <= 0.20
            iter_20pct = i
        end
        if iter_10pct === nothing && rel <= 0.10
            iter_10pct = i
        end
        if iter_5pct === nothing && rel <= 0.05
            iter_5pct = i
        end
    end
    
    # Improvement ratio
    improvement = initial / best
    
    return (island=island_df.island[1], total_iters=total_iters, best_iter=best_iter,
            iter_to_5pct=iter_5pct, iter_to_10pct=iter_10pct, iter_to_20pct=iter_20pct,
            initial_mass=initial, best_mass=best, improvement=improvement)
end

conv_metrics = combine(gdf, convergence_metrics)

println("\nIteration statistics:")
println("  Total iterations:  min=$(minimum(conv_metrics.total_iters)), max=$(maximum(conv_metrics.total_iters)), mean=$(round(mean(conv_metrics.total_iters), digits=1)), median=$(median(conv_metrics.total_iters))")
println("  Best found at iter: min=$(minimum(conv_metrics.best_iter)), max=$(maximum(conv_metrics.best_iter)), mean=$(round(mean(conv_metrics.best_iter), digits=1))")

# Count how many converged quickly (within 20 iters to 20% of best)
quick_20pct = count(c -> (c !== nothing && c <= 20), conv_metrics.iter_to_20pct)
quick_10pct = count(c -> (c !== nothing && c <= 20), conv_metrics.iter_to_10pct)
quick_5pct  = count(c -> (c !== nothing && c <= 20), conv_metrics.iter_to_5pct)

println("\nIslands reaching proximity thresholds within 20 iterations:")
println("  Within 20% of best: $quick_20pct / $n_total ($(round(100*quick_20pct/n_total, digits=1))%)")
println("  Within 10% of best: $quick_10pct / $n_total ($(round(100*quick_10pct/n_total, digits=1))%)")
println("  Within  5% of best: $quick_5pct  / $n_total ($(round(100*quick_5pct/n_total, digits=1))%)")

# Distribution of total iterations
println("\nIteration count distribution:")
iter_counts = combine(gdf, nrow => :iterations)
iter_dist = combine(groupby(iter_counts, :iterations), nrow => :count)
sort!(iter_dist, :iterations)
for row in eachrow(iter_dist)
    bar = repeat("█", max(1, row.count))
    println("  $(row.iterations) iters: $bar ($(row.count) islands)")
end

# Improvement ratio distribution
println("\nImprovement ratio (initial / best) distribution:")
imp = conv_metrics.improvement
println("  Min: $(round(minimum(imp), digits=1))x   Max: $(round(maximum(imp), digits=1))x   Mean: $(round(mean(imp), digits=1))x   Median: $(round(median(imp), digits=1))x")

# =============================================================================
# (4) Cluster analysis to detect multiple basins of attraction
# =============================================================================
println("\n" * "="^70)
println("(4) CLUSTER ANALYSIS — BASINS OF ATTRACTION")
println("="^70)

# Strategy: Use the convergence trajectory as a feature vector.
# Islands that follow similar paths through mass-space may be in the same basin.
# We downsample each convergence curve to a fixed-length vector and cluster.

# First, let's look at the distribution of best masses more carefully
# for natural groupings (simple 1D clustering of outcomes)

println("\n--- 4a: 1D clustering of best masses ---")

# Simple approach: bin the masses finely and find local maxima
n_bins_fine = 50
bin_edges_fine = range(minimum(bs), stop=maximum(bs), length=n_bins_fine+1)
# Manual histogram
hist_weights = zeros(Int, n_bins_fine)
for m in bs
    for i in 1:n_bins_fine
        if m >= bin_edges_fine[i] && m < bin_edges_fine[i+1]
            hist_weights[i] += 1
            break
        end
    end
    if m >= bin_edges_fine[end]
        hist_weights[end] += 1
    end
end
hist_edges = bin_edges_fine

println("Fine histogram of best masses (50 bins):")
for i in 1:length(hist_weights)
    if hist_weights[i] > 0
        bar_len = max(1, hist_weights[i])
        bar = repeat("█", bar_len)
        println("  $(round(hist_edges[i], digits=1)): $bar ($(hist_weights[i]))")
    end
end

# Find peaks (local maxima in histogram)
function find_peaks(weights, min_prominence=2)
    peaks = Int[]
    for i in 2:length(weights)-1
        if weights[i] > weights[i-1] && weights[i] > weights[i+1] && weights[i] >= min_prominence
            push!(peaks, i)
        end
    end
    return peaks
end

peaks = find_peaks(hist_weights, 2)
println("\nDetected modes (peaks) in best-mass distribution:")
if isempty(peaks)
    println("  No clear multi-modal structure detected (single basin).")
else
    for p in peaks
        center = (hist_edges[p] + hist_edges[p+1]) / 2
        println("  Mode at ~$(round(center, digits=0)) kg with $(hist_weights[p]) islands")
    end
end

# --- 4b: Convergence trajectory clustering ---
println("\n--- 4b: Convergence trajectory clustering ---")

# Build a feature matrix: each island is a row, columns are mass at fixed
# "pseudo-iteration" points (percentiles of convergence progress)
# We'll use interpolation to get mass at 0%, 5%, 10%, ..., 100% of convergence

n_features = 21  # 0%, 5%, 10%, ..., 100%
feature_matrix = zeros(n_total, n_features)

for (idx, island_id) in enumerate(best_mass_per_island.island)
    island_df = df[df.island .== island_id, :]
    masses = island_df.mass_kg
    n = length(masses)
    for j in 0:(n_features-1)
        frac = j / (n_features - 1)
        idx_float = 1.0 + frac * (n - 1)
        idx_lo = floor(Int, idx_float)
        idx_hi = ceil(Int, idx_float)
        if idx_lo == idx_hi
            feature_matrix[idx, j+1] = masses[idx_lo]
        else
            t = idx_float - idx_lo
            feature_matrix[idx, j+1] = (1-t) * masses[idx_lo] + t * masses[idx_hi]
        end
    end
end

# Normalize each row by its initial mass to focus on shape, not scale
feature_norm = feature_matrix ./ feature_matrix[:, 1]

# Simple k-means-like clustering using 2-4 clusters
# Since we may not have Clustering.jl, do a manual k-means
function simple_kmeans(data, k; max_iters=100)
    n, d = size(data)
    # Initialize with k random points
    centroids = data[rand(1:n, k), :]
    assignments = zeros(Int, n)
    
    for iter in 1:max_iters
        # Assign points
        new_assignments = zeros(Int, n)
        for i in 1:n
            best_c = 1
            best_dist = Inf
            for c in 1:k
                dist = norm(data[i,:] - centroids[c,:])
                if dist < best_dist
                    best_dist = dist
                    best_c = c
                end
            end
            new_assignments[i] = best_c
        end
        
        if new_assignments == assignments
            break
        end
        assignments = new_assignments
        
        # Update centroids
        for c in 1:k
            members = data[assignments .== c, :]
            if size(members, 1) > 0
                centroids[c, :] = mean(members, dims=1)[:]
            end
        end
    end
    
    # Compute inertia
    inertia = 0.0
    for i in 1:n
        inertia += norm(data[i,:] - centroids[assignments[i],:])^2
    end
    
    return assignments, centroids, inertia
end

println("\nK-means clustering on convergence trajectories (normalized):")
for k in 2:4
    best_inertia = Inf
    best_assignments = nothing
    best_centroids = nothing
    
    # Run multiple times with different initializations
    for run in 1:20
        assignments, centroids, inertia = simple_kmeans(feature_norm, k)
        if inertia < best_inertia
            best_inertia = inertia
            best_assignments = assignments
            best_centroids = centroids
        end
    end
    
    # Count cluster sizes
    cluster_sizes = [count(best_assignments .== c) for c in 1:k]
    
    println("\n  k=$k clusters (inertia=$(round(best_inertia, digits=1))):")
    for c in 1:k
        # Get best masses for this cluster
        cluster_best_masses = bs[best_assignments .== c]
        c_min = round(minimum(cluster_best_masses), digits=1)
        c_max = round(maximum(cluster_best_masses), digits=1)
        c_mean = round(mean(cluster_best_masses), digits=1)
        c_global_best_in = minimum(cluster_best_masses) <= threshold_10pct
        
        # Typical trajectory shape: where does the centroid end?
        c_final_norm = best_centroids[c, end]
        
        println("    Cluster $c: $(cluster_sizes[c]) islands, best-mass range [$c_min, $c_max] kg, mean=$c_mean kg (contains near-optimal: $c_global_best_in)")
    end
end

# --- 4c: Gap analysis in best-mass distribution ---
println("\n--- 4c: Gap analysis (natural separation between groups) ---")

sorted_bs = sort(bs)
gaps = diff(sorted_bs)
# Find large gaps (top 10 gaps)
gap_indices = sortperm(gaps, rev=true)
println("Top 10 largest gaps in sorted best masses:")
for rank in 1:min(10, length(gap_indices))
    gi = gap_indices[rank]
    gap = gaps[gi]
    println("  Gap $(rank): $(round(gap, digits=1)) kg between $(round(sorted_bs[gi], digits=1)) and $(round(sorted_bs[gi+1], digits=1)) kg (islands at positions $gi-$(gi+1) of $(length(sorted_bs)))")
end

# =============================================================================
# SUMMARY
# =============================================================================
println("\n" * "="^70)
println("SUMMARY — CONSTRAINT SATISFACTION & SOLUTION ROBUSTNESS")
println("="^70)

println("""
Global best mass: $(round(global_best, digits=2)) kg (island $(global_best_island))
Total islands converged: $n_total

Near-optimal islands:
  Within 5%  (≤ $(round(threshold_5pct, digits=1)) kg): $n_within_5pct / $n_total ($(round(100*n_within_5pct/n_total, digits=1))%)
  Within 10% (≤ $(round(threshold_10pct, digits=1)) kg): $n_within_10pct / $n_total ($(round(100*n_within_10pct/n_total, digits=1))%)
  Within 20% (≤ $(round(threshold_20pct, digits=1)) kg): $n_within_20pct / $n_total ($(round(100*n_within_20pct/n_total, digits=1))%)

Convergence speed:
  Quick to 20% of best (≤20 iters): $quick_20pct / $n_total ($(round(100*quick_20pct/n_total, digits=1))%)
  Quick to 10% of best (≤20 iters): $quick_10pct / $n_total ($(round(100*quick_10pct/n_total, digits=1))%)
  Quick to  5% of best (≤20 iters): $quick_5pct / $n_total ($(round(100*quick_5pct/n_total, digits=1))%)

Design space assessment:
  - Mass range: $(round(minimum(bs), digits=1)) – $(round(maximum(bs), digits=1)) kg (ratio $(round(maximum(bs)/minimum(bs), digits=1))x)
  - Std dev / mean = $(round(std(bs)/mean(bs), digits=3)) → $(round(std(bs)/mean(bs) * 100, digits=1))% CV
""")

# Interpret results
if n_within_10pct >= 20
    println("  INTERPRETATION: MANY near-optimal solutions → FORGIVING design space.")
    println("  Multiple islands converge to similar quality — the constraint set appears")
    println("  well-posed and not over-constrained. Designers have flexibility.")
elseif n_within_10pct >= 5
    println("  INTERPRETATION: MODERATE number of near-optimal solutions.")
    println("  The design space has a reasonably broad basin but shows some constraint tension.")
else
    println("  INTERPRETATION: FEW near-optimal solutions → potentially OVER-CONSTRAINED.")
    println("  Only a narrow region of the design space satisfies all constraints well.")
end

# Check for multi-modality
n_modes = length(peaks)
if n_modes >= 2
    println("  MULTI-MODAL: $(n_modes) distinct basins detected. Different design families exist")
    println("  that satisfy constraints well. This suggests a rich, multi-faceted design space.")
else
    println("  UNI-MODAL: Single basin of attraction. All designs converge toward the same region.")
    println("  This suggests a well-defined global optimum with a single dominant design family.")
end
