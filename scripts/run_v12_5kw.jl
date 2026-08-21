#!/usr/bin/env julia
# scripts/run_v12_5kw.jl
#
# V12 Cold-Start DE Campaign — 5kW rung of the graduated ladder.
# Seeded population, single-eval per genome, progressive CSV saves.
#
# Usage: julia --project=. scripts/run_v12_5kw.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, DataFrames, CSV, Random, Statistics
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const POWER_W = KW * 1000.0
const OUT_DIR = joinpath(@__DIR__, "results", "v12_5kw_coldstart")
mkpath(OUT_DIR)

# ── Setup ──────────────────────────────────────────────────────────────
p_base = mass_scale(params_10kw(), 10.0, KW)
beam_profile = PROFILE_ELLIPTICAL
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
dim = length(lo)

cfg = ObjectiveConfig(;
    power_W = POWER_W,
    v_rated = 11.0,
    p_floor_kw = 2.5,
    p_ceiling_kw = 5.0,
    relax_s = 5.0,
    window_s = 10.0,
    tether_diameter = p_base.tether_diameter,
)

# ── V12 cold-start evaluator (single eval, cached) ─────────────────────
const EVAL_CACHE = Dict{Vector{Float64},Float64}()

function eval_v12_cold(x::Vector{Float64})
    key = round.(x, digits=6)
    if haskey(EVAL_CACHE, key)
        return EVAL_CACHE[key]
    end
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    result = Inf
    try
        r = KiteTurbineDynamics.evaluate_windowed(
            xr, beam_profile, p_base, cfg;
            start_mode = :cold,
            lift_device = rotary_lifter_default(),
            fitness_fn = (P, FoS, c, m) -> KiteTurbineDynamics.v12_fitness(P, FoS, c, m),
        )
        result = r.status === :reject ? 1e9 : r.fitness
    catch e
        result = 1e9
    end
    EVAL_CACHE[key] = result
    GC.gc()
    return result
end

# ── DE settings ────────────────────────────────────────────────────────
popsize = 10
n_islands = 3
max_iter = 30

println("═"^55)
println("  V12 Cold-Start DE — 5kW Rung (v2: seeded, cached)")
println("  $(popsize) pop × $(n_islands) islands × $(max_iter) gen")
println("  Window: 5s relax + 10s measure")
println("  Output: $OUT_DIR")
println("═"^55)
flush(stdout)

# ── Progressive CSV writer ─────────────────────────────────────────────
const ALL_ROWS = Tuple{Int,Int,Float64}[]

function save_progress(force::Bool=false)
    if force || length(ALL_ROWS) % 10 == 0
        df = DataFrame(island=[r[1] for r in ALL_ROWS],
                       iteration=[r[2] for r in ALL_ROWS],
                       fitness=[r[3] for r in ALL_ROWS])
        CSV.write(joinpath(OUT_DIR, "convergence.csv"), df)
    end
end

campaign_start = time()
global_best_x = nothing
global_best_cost = Inf

for island in 1:n_islands
    global global_best_x, global_best_cost
    Random.seed!(42 + island - 1)
    println("\n  -- Island $island / $n_islands " * "-"^25)
    flush(stdout)

    # Seeded initial population: known-good seed + 9 random variants
    island_start = time()
    population = Vector{Vector{Float64}}(undef, popsize)
    population[1] = clamp.(copy(seed_v), lo, hi)
    population[1][8] = Float64(round(Int, clamp(population[1][8], 3, 16)))
    for k in 2:popsize
        population[k] = lo .+ rand(Float64, dim) .* (hi .- lo)
    end

    # Evaluate initial population
    costs = [eval_v12_cold(x) for x in population]
    best_idx = argmin(costs)
    best_cost = costs[best_idx]
    best_x = copy(population[best_idx])
    @printf("  [gen 0] seeded best=%.2f  (seed=%.2f)\n", best_cost, costs[1])
    # Save gen-0 best immediately
    open(joinpath(OUT_DIR, "island_$(island)_best.csv"), "w") do f
        write(f, join(string.(best_x), ","))
    end
    open(joinpath(OUT_DIR, "island_$(island)_best_meta.txt"), "w") do f
        println(f, "island=$island gen=0 fitness=$best_cost")
    end
    flush(stdout)

    for iteration in 1:max_iter
        new_costs = copy(costs)
        for i in 1:popsize
            a, b, c = rand(1:popsize, 3)
            while a == i || b == i || c == i || a == b || a == c || b == c
                a, b, c = rand(1:popsize, 3)
            end
            F = 0.5 + 0.3 * rand()
            mutant = clamp.(population[a] .+ F .* (population[b] .- population[c]), lo, hi)
            CR = 0.7 + 0.2 * rand()
            trial = similar(population[i])
            j_rand = rand(1:dim)
            for j in 1:dim
                trial[j] = (rand() <= CR || j == j_rand) ? mutant[j] : population[i][j]
            end
            trial[8] = Float64(round(Int, clamp(trial[8], 3, 16)))
            cost_trial = eval_v12_cold(trial)
            if cost_trial <= costs[i]
                population[i] = trial
                new_costs[i] = cost_trial
                if cost_trial < best_cost
                    best_cost = cost_trial
                    best_x = copy(trial)
                end
            end
        end
        costs = new_costs

        push!(ALL_ROWS, (island, iteration, best_cost))
        save_progress()
        # Save best genome EVERY generation (survives crashes)
        if best_x !== nothing
            open(joinpath(OUT_DIR, "island_$(island)_best.csv"), "w") do f
                write(f, join(string.(best_x), ","))
            end
            open(joinpath(OUT_DIR, "island_$(island)_best_meta.txt"), "w") do f
                println(f, "island=$island gen=$iteration fitness=$best_cost")
            end
        end
        elapsed = round(time() - island_start, digits=0)
        @printf("  [Island %d/%d | gen %3d] best=%.2f  elapsed=%ds\n",
            island, n_islands, iteration, best_cost, elapsed)
        flush(stdout)
    end

    open(joinpath(OUT_DIR, "island_$(island)_best.csv"), "w") do f
        write(f, join(string.(best_x), ","))
    end

    if best_cost < global_best_cost
        global_best_cost = best_cost
        global_best_x = copy(best_x)
        println("  ** New global best: $(round(global_best_cost, digits=2)) **")
    end
    flush(stdout)
end

elapsed_total = round(time() - campaign_start, digits=0)
println("\n  Campaign complete in $(elapsed_total)s")
println("  Global best fitness: $(round(global_best_cost, digits=2))")
if global_best_x !== nothing
    open(joinpath(OUT_DIR, "best_vector.csv"), "w") do f
        write(f, join(string.(global_best_x), ","))
    end
end
save_progress(true)
println("  Results in $OUT_DIR")
