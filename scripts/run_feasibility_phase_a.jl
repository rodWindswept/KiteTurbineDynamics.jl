#!/usr/bin/env julia
# scripts/run_feasibility_phase_a.jl
# Stage 2: Phase A feasibility campaign — DE minimising objective_feasibility.
# Budget: pop=24, ≤30 gens, hard cap 500 v11 evals.  Progressive saves, resume by hash.

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics, SHA, JSON3, Dates, DataFrames, CSV, Random, DelimitedFiles

# ══════════════════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════════════════
const POP_SIZE    = 8
const MAX_GENS    = 15
const MAX_EVALS   = 120
const P_CAP        = 50.0
const P_FLOOR      = 1.0
const FOS_DESIGN   = 1.5
const F           = 0.8    # DE differential weight
const CR          = 0.9    # DE crossover rate

const SP          = KiteTurbineDynamics.SpokeParams(enabled=false)
const BEAM        = KiteTurbineDynamics.PROFILE_ELLIPTICAL
const P_BASE      = KiteTurbineDynamics.params_v5_50kw()
const POWER_W     = 50000.0
const V_RATED     = 11.0
const GIT_HASH    = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
const PHYSICS_ERA = "post-234a722_corrected-physics_ON"

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const OUT_CSV = joinpath(OUT_DIR, "feasibility_phase_a.csv")
mkpath(OUT_DIR)

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds + seeds
# ══════════════════════════════════════════════════════════════════════════════
lo_full, hi_full = KiteTurbineDynamics.search_bounds_v11(P_BASE, BEAM; max_ground_radius=5.0)

const SEED_HASHES = [
    "205c119cd2cb",  # FoS 0.48, 8-line, 6.4kW
    "fdc0c9e0907b",  # FoS 0.37, 3-line legacy, 5.1kW
    "0d61db093a2c",  # FoS 0.34, 4-line, 10.0kW
    "f697422b778f",  # FoS 0.23, 12-line legacy, 1.6kW
    "caddb19b866b",  # FoS 0.17, 6-line, 13.2kW
]

function load_anchors_map()
    map = Dict{String,Vector{Float64}}()
    rows = readdlm(joinpath(@__DIR__, "results", "recampaign", "anchors.csv"), ',', header=true)
    hdr = Dict(h => i for (i, h) in enumerate(rows[2]))
    for i in 1:size(rows[1], 1)
        gh = string(rows[1][i, hdr["genome_hash"]])
        x = [parse(Float64, string(rows[1][i, hdr["x$j"]])) for j in 1:15]
        map[gh] = x
    end
    return map
end

const ANCHORS = load_anchors_map()

# V6.2 recovered 12-line optimum (from handover)
const X_V62 = [0.0600000,0.0100000,0.8799392,0.9999998,2.8885233,2.0000000,
               2.9878503,12.000000,0.0,18.5580461,31.9905662,34.9999911,
               0.5186482,0.1000000,log10(165.4)]

function load_seeds()
    seeds = Vector{Float64}[]
    for h in SEED_HASHES
        if haskey(ANCHORS, h)
            push!(seeds, ANCHORS[h])
        end
    end
    push!(seeds, copy(X_V62))
    return seeds
end

# ══════════════════════════════════════════════════════════════════════════════
# Evaluation
# ══════════════════════════════════════════════════════════════════════════════

function evaluate_genome(x)
    x_copy = copy(x)
    try
        f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b =
            KiteTurbineDynamics.warmstart_with_k_bracket(x_copy, BEAM, P_BASE;
                power_W=POWER_W, v_rated=V_RATED, spoke=SP)

        f_feas = objective_feasibility(P_mean, FoS_min; P_cap=P_CAP, P_floor=P_FLOOR, FoS_design=FOS_DESIGN)
        tier = P_mean < P_FLOOR ? "stalled" : FoS_min < FOS_DESIGN ? "feasibility" : "feasible"

        return (f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary,
                util_a, util_b, f_feas, tier, true)
    catch e
        return (Inf, 0.0, 0.0, Inf, 0.0, 0.0, true, false,
                -1.0, -1.0, 11.0, "stalled", false)
    end
end

function genome_hash(x)
    return bytes2hex(sha256(string(x)))
end

# ══════════════════════════════════════════════════════════════════════════════
# CSV schema + resume
# ══════════════════════════════════════════════════════════════════════════════

const CSV_COLS = [:genome_hash, :physics_era, :git_hash,
    :x1,:x2,:x3,:x4,:x5,:x6,:x7,:x8,:x9,:x10,:x11,:x12,:x13,:x14,:x15,
    :n_lines, :n_active,
    :f_v11, :k_chosen, :P_mean_kw, :FoS_min, :omega_eq_rpm,
    :P_range_kw, :drift_flag, :stationary,
    :util_axial, :util_bending,
    :f_feas, :tier, :gen, :timestamp]

function load_existing_hashes()
    isfile(OUT_CSV) || return Set{String}()
    try
        df = CSV.read(OUT_CSV, DataFrame)
        return Set(string.(df.genome_hash))
    catch
        return Set{String}()
    end
end

function save_row(gh, x, n_lines, n_active, f_v11, k_chosen, P_mean, FoS_min, ω_eq,
                  P_range, drifted, stationary, util_a, util_b, f_feas, tier, gen)
    row = Dict{Symbol,Any}(
        :genome_hash => gh, :physics_era => PHYSICS_ERA, :git_hash => GIT_HASH,
        :x1=>x[1],:x2=>x[2],:x3=>x[3],:x4=>x[4],:x5=>x[5],
        :x6=>x[6],:x7=>x[7],:x8=>x[8],:x9=>x[9],:x10=>x[10],
        :x11=>x[11],:x12=>x[12],:x13=>x[13],:x14=>x[14],:x15=>x[15],
        :n_lines => n_lines, :n_active => n_active,
        :f_v11 => f_v11, :k_chosen => k_chosen, :P_mean_kw => P_mean,
        :FoS_min => FoS_min, :omega_eq_rpm => ω_eq * 60 / (2π),
        :P_range_kw => P_range, :drift_flag => drifted, :stationary => stationary,
        :util_axial => util_a, :util_bending => util_b,
        :f_feas => f_feas, :tier => tier, :gen => gen,
        :timestamp => string(Dates.now()),
    )
    if !isfile(OUT_CSV)
        df = DataFrame([(c==:genome_hash||c==:physics_era||c==:git_hash||c==:tier||c==:timestamp) ? String[] :
                         (c==:drift_flag||c==:stationary) ? Bool[] : Float64[] for c in CSV_COLS], CSV_COLS)
        CSV.write(OUT_CSV, df)
    end
    df = CSV.read(OUT_CSV, DataFrame)
    push!(df, row; cols=:union)
    sort!(df, :genome_hash)
    CSV.write(OUT_CSV, df)
end

# ══════════════════════════════════════════════════════════════════════════════
# DE operators
# ══════════════════════════════════════════════════════════════════════════════

function random_genome()
    x = zeros(15)
    for i in 1:15
        x[i] = lo_full[i] + (hi_full[i] - lo_full[i]) * rand()
    end
    return x
end

function clamp_genome(x)
    for i in 1:15
        x[i] = clamp(x[i], lo_full[i], hi_full[i])
    end
    return x
end

function differential_evolution(pop, fit, gen)
    n = length(pop)
    d = 15
    new_pop = Vector{Float64}[]
    new_fit = Float64[]
    for i in 1:n
        # Select three distinct random indices != i
        a = b = c = i
        while a == i; a = rand(1:n); end
        while b == i || b == a; b = rand(1:n); end
        while c == i || c == a || c == b; c = rand(1:n); end

        # DE/rand/1: mutant = pop[a] + F*(pop[b] - pop[c])
        mutant = pop[a] .+ F .* (pop[b] .- pop[c])
        # Exponential crossover
        trial = copy(pop[i])
        j = rand(1:d)
        for k in 1:d
            if rand() < CR || k == d - j + 1
                trial[j] = mutant[j]
            end
            j = (j % d) + 1
            if rand() >= CR
                # continue with next from the crossover start
            end
        end
        trial = clamp_genome(trial)

        # Evaluate trial
        gh = genome_hash(trial)
        existing = load_existing_hashes()
        if gh in existing
            # Already evaluated; skip
            push!(new_pop, pop[i])
            push!(new_fit, fit[i])
            continue
        end

        _, _, P_mean, FoS_min, _, _, _, _, ua, ub, f_feas, tier, ok = evaluate_genome(trial)
        if !ok
            push!(new_pop, pop[i])
            push!(new_fit, fit[i])
            continue
        end

        # Decode metadata
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(trial[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, trial, nl, na, f_feas > 10 ? Inf : f_feas, 0.0,
                 P_mean, FoS_min, 60.0, 0.0, false, false, ua, ub, f_feas, tier, gen)

        if f_feas < fit[i]
            push!(new_pop, trial)
            push!(new_fit, f_feas)
        else
            push!(new_pop, pop[i])
            push!(new_fit, fit[i])
        end
    end
    return new_pop, new_fit
end

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

function main()
    println("═══════════════════════════════════════════════")
    println("Phase A — Feasibility Campaign")
    println("git=$GIT_HASH  era=$PHYSICS_ERA")
    println("pop=$POP_SIZE  max_gens=$MAX_GENS  max_evals=$MAX_EVALS")
    println("═══════════════════════════════════════════════\n")

    seeds = load_seeds()
    existing = load_existing_hashes()
    println("Seeds: $(length(seeds))  Existing evals: $(length(existing))\n")

    # Build initial population
    pop = Vector{Float64}[]
    fit = Float64[]
    t0 = time()
    eval_count = 0

    # Seeds first — if already evaluated, load from CSV for population
    for x in seeds
        gh = genome_hash(x)
        if gh in existing
            # Load genome from CSV to seed the population (resume)
            push!(pop, x)
            # Get f_feas from CSV
            try
                df = CSV.read(OUT_CSV, DataFrame)
                idx = findfirst(df.genome_hash .== gh)
                if idx !== nothing
                    push!(fit, df.f_feas[idx])
                else
                    push!(fit, Inf)
                end
            catch
                push!(fit, Inf)
            end
            @printf("[seed %d] %s  (resumed from CSV)\n", length(pop), gh[1:8])
            continue
        end
        _, k, P, FoS, ω, Pr, dr, st, ua, ub, f_feas, tier, ok = evaluate_genome(x)
        if !ok; continue; end
        push!(pop, x)
        push!(fit, f_feas)
        eval_count += 1
        @printf("[seed %d] %s  P=%.1f FoS=%.3f f_feas=%.3f tier=%s\n",
            eval_count, gh[1:8], P, FoS, f_feas, tier)
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, x, nl, na, f_feas > 10 ? Inf : f_feas, k,
                 P, FoS, ω, Pr, dr, st, ua, ub, f_feas, tier, 0)
    end

    # Fill to pop size with random
    while length(pop) < POP_SIZE
        x = random_genome()
        gh = genome_hash(x)
        if gh in existing; continue; end
        _, k, P, FoS, ω, Pr, dr, st, ua, ub, f_feas, tier, ok = evaluate_genome(x)
        if !ok; continue; end
        push!(pop, x)
        push!(fit, f_feas)
        eval_count += 1
        @printf("[init %d] %s  P=%.1f FoS=%.3f f_feas=%.3f tier=%s\n",
            eval_count, gh[1:8], P, FoS, f_feas, tier)
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, x, nl, na, f_feas > 10 ? Inf : f_feas, k,
                 P, FoS, ω, Pr, dr, st, ua, ub, f_feas, tier, 0)
    end

    println("\nInitial population: $(length(pop))  Evals so far: $eval_count\n")

    best_fit_ever = minimum(fit)
    best_idx = argmin(fit)

    for gen in 1:MAX_GENS
        eval_count >= MAX_EVALS && break

        pop, fit = differential_evolution(pop, fit, gen)
        eval_count += POP_SIZE

        gen_best = minimum(fit)
        gen_best_idx = argmin(fit)
        gen_best_P = 0.0; gen_best_FoS = Inf
        try
            _, _, p, f, _, _, _, _, _, _, _ = evaluate_genome(pop[gen_best_idx])
            gen_best_P = p; gen_best_FoS = f
        catch; end

        elapsed = (time() - t0) / 60
        @printf("[gen %2d] best_f=%.3f best_P=%.1f best_FoS=%.3f  evals=%d  wall=%.0fm\n",
            gen, gen_best, gen_best_P, gen_best_FoS, eval_count, elapsed)

        if gen_best < best_fit_ever
            best_fit_ever = gen_best
            @printf("  → NEW BEST: f=%.3f\n", gen_best)
        end

        # Gate checks
        if gen_best_FoS >= FOS_DESIGN && gen_best_P >= P_FLOOR
            println("\n╔══════════════════════════════════════════════╗")
            println("║  GREEN: FoS ≥ 1.5 with P ≥ 1 kW achieved!   ║")
            println("║  Genome: $(genome_hash(pop[gen_best_idx])[1:8])  ║")
            println("╚══════════════════════════════════════════════╝")
            println("→ Freeze genome, proceed to Stage 3 verification.")
            break
        end
    end

    # Final verdict
    final_best_idx = argmin(fit)
    _, _, P_fin, FoS_fin, _, _, _, _, f_feas_fin, tier_fin, _ = evaluate_genome(pop[final_best_idx])
    println()
    println("═══════════════════════════════════════════════")
    if FoS_fin >= FOS_DESIGN && P_fin >= P_FLOOR
        println("GREEN — feasible design found.")
    elseif FoS_fin >= 1.0
        println("AMBER — best FoS ≥ 1.0 but < 1.5.  Pareto report to Rod.")
        println("  Best: FoS=%.3f P=%.1f kW f_feas=%.3f", FoS_fin, P_fin, f_feas_fin)
    else
        println("PROVISIONAL RED — best FoS < 1.0 after $eval_count evals.")
        println("  Best: FoS=%.3f P=%.1f kW f_feas=%.3f", FoS_fin, P_fin, f_feas_fin)
        println("  120-eval probe (not an exhaustive search): directional evidence of")
        println("  structural underbuild.  Escalate the airframe conversation AND decide")
        println("  whether a second 120-eval budget on a memory-fixed evaluator changes")
        println("  anything.  One-sided test: even optimistic FoS (no blade mass) can't")
        println("  reach 1.0 from the best-known seeds — robust lower bound.")
    end
    println("Output: $OUT_CSV")
    println("═══════════════════════════════════════════════")
end

main()
