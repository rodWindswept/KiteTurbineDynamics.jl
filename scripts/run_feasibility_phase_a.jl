#!/usr/bin/env julia
# scripts/run_feasibility_phase_a.jl
# Stage 2: Phase A v2 feasibility campaign — DE minimising objective_feasibility.
# Corrected A1-A5 physics, n_rings≥1, 30s decay checkpoint, OOM fixes.
# Budget: pop=8, ≤6 gens, hard cap 48 evals.  Progressive saves, resume by hash.
# Seed: V10 winner only (post-A1-A5 — known feasible).

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics, SHA, JSON3, Dates, DataFrames, CSV, Random, Base.Threads

const CSV_LOCK    = ReentrantLock()  # thread-safe CSV row buffer
const ROWS_BUFFER = Dict{Symbol,Any}[]

# ══════════════════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════════════════
const POP_SIZE    = 6
const MAX_GENS    = 4
const MAX_EVALS   = 48
const P_CAP        = 50.0
const P_FLOOR      = 25.0
const FOS_DESIGN   = 1.5
const F           = 0.8    # DE differential weight
const CR          = 0.9    # DE crossover rate
const DECAY_P_THRESHOLD = 1.0  # kW — abort if P_30s is below this

const SP          = KiteTurbineDynamics.SpokeParams(enabled=false)
const BEAM        = KiteTurbineDynamics.PROFILE_ELLIPTICAL
const P_BASE      = KiteTurbineDynamics.params_v5_50kw()
const POWER_W     = 50000.0
const V_RATED     = 11.0

# ── Lift device — DESIGN-AWARE ─────────────────────────────────────────────
const LIFT_MARGIN = 1.5
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=LIFT_MARGIN, v_ref=V_RATED)
const LIFT_DEVICE = lift_for

const GIT_HASH    = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
const PHYSICS_ERA = "post-20260809-evaluator-consolidation"

# ── F5 measurement horizon ────────────────────────────────────────────────
# (The old `KiteTurbineDynamics.WARM_RELAX_S[] = 120.0` global mutation is
# GONE — per-eval horizons ride in the ObjectiveConfig passed to the bracket,
# see _warmstart_at_relax below.  The module-level Refs were deleted
# 2026-08-09: mutating them inside a threaded DE loop was a data race.)

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const OUT_CSV = joinpath(OUT_DIR, "feasibility_phase_a_v3.csv")
mkpath(OUT_DIR)

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds + seeds
# ══════════════════════════════════════════════════════════════════════════════
lo_full, hi_full = KiteTurbineDynamics.search_bounds_v11(P_BASE, BEAM; max_ground_radius=5.0)

const X_SEED = [0.2, 0.01, 1.0, 1.0, 5.366563145999496, 1.5, 2.290336420077981,
                15.380561394283504, 0.7635956009855438, 19.0, 22.42396791533018,
                25.0, 0.8804365395898538, 0.4636680969018283]  # 14-D

function load_seeds()
    return [copy(X_SEED)]
end

# ══════════════════════════════════════════════════════════════════════════════
# Evaluation (with 30s decay checkpoint)
# ══════════════════════════════════════════════════════════════════════════════

function _warmstart_at_relax(x, relax_s)
    """Run warmstart_with_k_bracket at a specific relax horizon.

    The horizon rides in an ObjectiveConfig (per-eval, immutable) — no module
    global is mutated, so this is safe inside the threaded DE loop.  The old
    implementation wrote KiteTurbineDynamics.WARM_RELAX_S[] per-eval while
    worker threads read the same Ref: thread A's 30 s quick-check could read
    thread B's 120 s value (2026-08-09 architecture audit)."""
    cfg = KiteTurbineDynamics.ObjectiveConfig(; relax_s=relax_s)
    best, k_chosen = KiteTurbineDynamics.warmstart_with_k_bracket(
        x, BEAM, P_BASE;
        power_W=POWER_W, v_rated=V_RATED, spoke=SP, lift_device=LIFT_DEVICE,
        cfg=cfg)
    return best, k_chosen
end

function evaluate_genome(x)
    x_copy = copy(x)
    try
        # Phase 1: 30s quick-check — abort decaying designs early
        best30, k30 = _warmstart_at_relax(x_copy, 30.0)
        f_v11_30 = best30.fitness
        P_30 = best30.P_mean
        FoS_30 = best30.FoS_min
        ω30 = best30.ω_eq
        Pr30 = best30.P_range
        dr30 = best30.drifted
        st30 = best30.stationary
        ua30 = best30.util_a
        ub30 = best30.util_b
        Tl30 = best30.T_lift

        # Decay checkpoint: if power is already negligible at 30s, abort
        # (a rejected bracket also lands here — its row is written with the
        # status flag so it cannot be mistaken for a real measurement)
        if P_30 < DECAY_P_THRESHOLD || best30.status !== :ok
            f_feas = objective_feasibility(P_30, FoS_30; P_cap=P_CAP, P_floor=P_FLOOR,
                                           FoS_design=FOS_DESIGN, P_range=Pr30)
            tier = "decay_30s"
            return (f_v11_30, k30, P_30, FoS_30, ω30, Pr30, dr30, st30,
                    ua30, ub30, Tl30, f_feas, tier, best30.status === :ok)
        end

        # Phase 2: full 120s evaluation for promising designs
        best, k_chosen = _warmstart_at_relax(x_copy, 120.0)
        f_v11 = best.fitness
        P_mean = best.P_mean
        FoS_min = best.FoS_min
        ω_eq = best.ω_eq
        P_range = best.P_range
        drifted = best.drifted
        stationary = best.stationary
        util_a = best.util_a
        util_b = best.util_b
        T_lift = best.T_lift

        f_feas = objective_feasibility(P_mean, FoS_min; P_cap=P_CAP, P_floor=P_FLOOR,
                                       FoS_design=FOS_DESIGN, P_range=P_range)
        tier = P_mean < P_FLOOR ? "stalled" :
               FoS_min < FOS_DESIGN ? "feasibility" : "feasible"

        return (f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary,
                util_a, util_b, T_lift, f_feas, tier, best.status === :ok)
    catch e
        @warn "genome eval threw" exception=(e, catch_backtrace())
        return (Inf, 0.0, 0.0, Inf, 0.0, 0.0, true, false,
                -1.0, -1.0, -1.0, 12.0, "rejected", false)
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
    :lift_tension_N,
    :f_feas, :tier, :gen, :timestamp]

function load_existing_hashes()
    isfile(OUT_CSV) || return Set{String}()
    try
        df = CSV.read(OUT_CSV, DataFrame)
        if :physics_era in names(df)
            df = filter(row -> row.physics_era == PHYSICS_ERA, df)
        end
        return Set(string.(df.genome_hash))
    catch
        return Set{String}()
    end
end

function _row_dict(gh, x, n_lines, n_active, f_v11, k_chosen, P_mean, FoS_min, ω_eq,
                   P_range, drifted, stationary, util_a, util_b, lift_tension, f_feas, tier, gen)
    return Dict{Symbol,Any}(
        :genome_hash => gh, :physics_era => PHYSICS_ERA, :git_hash => GIT_HASH,
        :x1=>x[1],:x2=>x[2],:x3=>x[3],:x4=>x[4],:x5=>x[5],
        :x6=>x[6],:x7=>x[7],:x8=>x[8],:x9=>x[9],:x10=>x[10],
        :x11=>x[11],:x12=>x[12],:x13=>x[13],:x14=>x[14],
        :x15 => log10(k_chosen),
        :n_lines => n_lines, :n_active => n_active,
        :f_v11 => f_v11, :k_chosen => k_chosen, :P_mean_kw => P_mean,
        :FoS_min => FoS_min, :omega_eq_rpm => ω_eq * 60 / (2π),
        :P_range_kw => P_range, :drift_flag => drifted, :stationary => stationary,
        :util_axial => util_a, :util_bending => util_b,
        :lift_tension_N => lift_tension,
        :f_feas => f_feas, :tier => tier, :gen => gen,
        :timestamp => string(Dates.now()),
    )
end

function save_row(gh, x, n_lines, n_active, f_v11, k_chosen, P_mean, FoS_min, ω_eq,
                  P_range, drifted, stationary, util_a, util_b, lift_tension, f_feas, tier, gen)
    row = _row_dict(gh, x, n_lines, n_active, f_v11, k_chosen, P_mean, FoS_min, ω_eq,
                    P_range, drifted, stationary, util_a, util_b, lift_tension, f_feas, tier, gen)
    lock(CSV_LOCK) do
        push!(ROWS_BUFFER, row)
    end
end

function flush_csv()
    isempty(ROWS_BUFFER) && return
    df_new = DataFrame(ROWS_BUFFER)
    if isfile(OUT_CSV)
        try
            df_existing = CSV.read(OUT_CSV, DataFrame)
            df = vcat(df_existing, df_new; cols=:union)
        catch
            df = df_new
        end
    else
        df = df_new
    end
    sort!(df, :genome_hash)
    CSV.write(OUT_CSV, df)
    empty!(ROWS_BUFFER)
    println("  [flush] wrote $(nrow(df)) rows to $OUT_CSV")
end

# ══════════════════════════════════════════════════════════════════════════════
# DE operators
# ══════════════════════════════════════════════════════════════════════════════

function random_genome()
    x = zeros(length(lo_full))
    for i in eachindex(x)
        x[i] = lo_full[i] + (hi_full[i] - lo_full[i]) * rand()
    end
    return x
end

function clamp_genome(x)
    for i in eachindex(x)
        x[i] = clamp(x[i], lo_full[i], hi_full[i])
    end
    return x
end

function differential_evolution(pop, fit, gen, existing_hashes)
    n = length(pop)
    d = length(lo_full)
    new_pop = Vector{Float64}[]
    new_fit = Float64[]

    # Pre-compute trials (read-only on pop/fit)
    trials = Vector{Vector{Float64}}(undef, n)
    base_indices = Vector{Int}(undef, n)
    for i in 1:n
        a = b = c = i
        while a == i; a = rand(1:n); end
        while b == i || b == a; b = rand(1:n); end
        while c == i || c == a || c == b; c = rand(1:n); end
        mutant = pop[a] .+ F .* (pop[b] .- pop[c])
        trial = copy(pop[i])
        j = rand(1:d)
        for k in 1:d
            if rand() < CR || k == d - j + 1
                trial[j] = mutant[j]
            end
            j = (j % d) + 1
        end
        trials[i] = clamp_genome(trial)
        base_indices[i] = i
    end

    # Threaded evaluation — existing_hashes is pre-computed OUTSIDE the loop
    accepted = falses(n)
    f_feas_results = zeros(n)
    @threads for i in 1:n
        trial = trials[i]
        gh = genome_hash(trial)
        if gh in existing_hashes
            continue  # accepted stays false
        else
            f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, ua, ub, lift_tension, f_feas, tier, ok = evaluate_genome(trial)
            if !ok
                continue
            end
            nl = 0; na = 0
            try
                r = KiteTurbineDynamics.design_from_vector_v10(trial[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
                nl = r.design.n_lines; na = r.n_active
            catch; end
            save_row(gh, trial, nl, na, f_v11, k_chosen,
                     P_mean, FoS_min, ω_eq, P_range, drifted, stationary, ua, ub, lift_tension, f_feas, tier, gen)
            f_feas_results[i] = f_feas
            accepted[i] = f_feas < fit[base_indices[i]]
        end
    end

    # Sequential population update
    for i in 1:n
        if accepted[i]
            push!(new_pop, trials[i])
            push!(new_fit, f_feas_results[i])
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
    println("Phase A v3 — Feasibility Campaign (OOM fixes, n_rings≥1, 30s decay ck)")
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

    # Seeds first
    for x in seeds
        gh = genome_hash(x)
        if gh in existing
            push!(pop, x)
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
            @printf("[seed %d] %s  (resumed)\n", length(pop), gh[1:8])
            continue
        end
        f_v11, k, P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, ok = evaluate_genome(x)
        if !ok; continue; end
        push!(pop, x)
        push!(fit, f_feas)
        eval_count += 1
        @printf("[seed %d] %s  P=%.1f FoS=%.3f f=%.3f tier=%s\n",
            eval_count, gh[1:8], P, FoS, f_feas, tier)
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, x, nl, na, f_v11, k,
                 P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, 0)
    end

    # Fill to pop size with random
    while length(pop) < POP_SIZE
        x = random_genome()
        gh = genome_hash(x)
        if gh in existing; continue; end
        f_v11, k, P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, ok = evaluate_genome(x)
        if !ok; continue; end
        push!(pop, x)
        push!(fit, f_feas)
        eval_count += 1
        @printf("[init %d] %s  P=%.1f FoS=%.3f f=%.3f tier=%s\n",
            eval_count, gh[1:8], P, FoS, f_feas, tier)
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, x, nl, na, f_v11, k,
                 P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, 0)
    end

    flush_csv()
    println("\nInitial population: $(length(pop))  Evals so far: $eval_count\n")

    best_fit_ever = minimum(fit)
    best_idx = argmin(fit)

    for gen in 1:MAX_GENS
        eval_count >= MAX_EVALS && break

        # Refresh existing hashes before this generation
        existing = load_existing_hashes()

        pop, fit = differential_evolution(pop, fit, gen, existing)
        eval_count += POP_SIZE

        # Flush CSV and force GC between generations
        flush_csv()
        GC.gc()

        gen_best = minimum(fit)
        gen_best_idx = argmin(fit)
        gen_best_P = 0.0; gen_best_FoS = Inf; gen_best_stationary = false
        try
            _, _, p, f, _, _, d, st, _, _, _, _, _, _ = evaluate_genome(pop[gen_best_idx])
            gen_best_P = p; gen_best_FoS = f; gen_best_stationary = st
        catch; end

        elapsed = (time() - t0) / 60
        @printf("[gen %2d] best_f=%.3f best_P=%.1f best_FoS=%.3f  evals=%d  wall=%.0fm\n",
            gen, gen_best, gen_best_P, gen_best_FoS, eval_count, elapsed)

        if gen_best < best_fit_ever
            best_fit_ever = gen_best
            @printf("  → NEW BEST: f=%.3f\n", gen_best)
        end

        # Gate checks
        if gen_best_FoS >= FOS_DESIGN && gen_best_P >= P_FLOOR && gen_best_stationary
            println("\n╔══════════════════════════════════════════════╗")
            @printf("║  GREEN: FoS ≥ %.1f, P ≥ %.0f kW, stationary  ║\n", FOS_DESIGN, P_FLOOR)
            println("║  Genome: $(genome_hash(pop[gen_best_idx])[1:8])  ║")
            println("╚══════════════════════════════════════════════╝")
            break
        elseif gen_best_FoS >= FOS_DESIGN && gen_best_P >= P_FLOOR && !gen_best_stationary
            println("  → FoS/P met but stationary=false — NOT GREEN.")
        end
    end

    # Final flush
    flush_csv()

    # Final verdict
    final_best_idx = argmin(fit)
    _, _, P_fin, FoS_fin, _, _, _, _, _, _, _, f_feas_fin, tier_fin, _ = evaluate_genome(pop[final_best_idx])
    println()
    println("═══════════════════════════════════════════════")
    if FoS_fin >= FOS_DESIGN && P_fin >= P_FLOOR
        println("GREEN — feasible design found.")
    elseif FoS_fin >= 1.0
        println("AMBER — best FoS ≥ 1.0 but < 1.5.")
        @printf("  Best: FoS=%.3f P=%.1f kW f_feas=%.3f\n", FoS_fin, P_fin, f_feas_fin)
    else
        println("PROVISIONAL RED — best FoS < 1.0 after $eval_count evals.")
        @printf("  Best: FoS=%.3f P=%.1f kW f_feas=%.3f\n", FoS_fin, P_fin, f_feas_fin)
    end
    println("Output: $OUT_CSV")
    println("═══════════════════════════════════════════════")
end

main()
