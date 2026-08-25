#!/usr/bin/env julia
# scripts/combine_islands_v13.jl
#
# Combines per-island results from the PARALLEL v13_5kw_masslift campaign
# (each island runs as its own process via `--island N`) into a single global
# best.  Idempotent: reads island_N/island_N_best_meta.txt, picks the minimum
# fitness, copies the winner's island_N/island_N_best.csv to best_vector.csv at
# the campaign root, and writes combined_summary.csv + global_best_meta.txt.
#
# Usage: julia --project=. scripts/combine_islands_v13.jl [--length 18.8]

using Pkg; Pkg.activate(dirname(@__DIR__))
using Printf

const LENGTH = begin
    L = 18.8
    for (i, a) in enumerate(ARGS)
        if a == "--length" && i < length(ARGS)
            L = parse(Float64, ARGS[i+1])
        end
    end
    L
end

const BASE = joinpath(@__DIR__, "results", "v13_5kw_masslift_len$(LENGTH)_rotorcount")

isdir(BASE) || error("campaign root not found: $BASE")
islands = sort([d for d in readdir(BASE; join=true)
                if isdir(d) && occursin("island_", basename(d))])

best_fitness = Inf
best_island = 0
best_vec = nothing
rows = Tuple{Int,Int,Float64}[]

for d in islands
    m = match(r"island_(\d+)$", basename(d))
    m === nothing && continue
    n = parse(Int, m.captures[1])
    meta = joinpath(d, "island_$(n)_best_meta.txt")
    vecf = joinpath(d, "island_$(n)_best.csv")
    if !isfile(meta) || !isfile(vecf)
        @warn "missing results for island $n (skipping)"
        continue
    end
    line = chomp(readline(meta))
    fm = match(r"gen=(\d+)\s+fitness=([0-9.eE+-]+)", line)
    fm === nothing && error("unparseable meta for island $n: $line")
    gen = parse(Int, fm.captures[1])
    fit = parse(Float64, fm.captures[2])
    push!(rows, (n, gen, fit))
    if fit < best_fitness
        best_fitness = fit
        best_island = n
        best_vec = strip(read(vecf, String))
    end
end

println("=== v13_5kw_masslift_len$(LENGTH) — island combine ===")
for r in sort(rows; by = x -> x[1])
    @printf("  island %d: gen=%d  fitness=%.3f%s\n",
            r[1], r[2], r[3], r[1] == best_island ? "  ← WINNER" : "")
end

if best_vec === nothing
    error("no complete island results found in $BASE")
end

open(joinpath(BASE, "best_vector.csv"), "w") do f
    write(f, best_vec)
end
open(joinpath(BASE, "global_best_meta.txt"), "w") do f
    println(f, "island=$best_island fitness=$best_fitness length=$LENGTH")
end
open(joinpath(BASE, "combined_summary.csv"), "w") do f
    println(f, "island,gen,fitness")
    for r in sort(rows; by = x -> x[1])
        println(f, "$(r[1]),$(r[2]),$(r[3])")
    end
end

@printf("\nGlobal best: island %d, fitness %.3f\n", best_island, best_fitness)
println("Wrote best_vector.csv, global_best_meta.txt, combined_summary.csv to $BASE")
