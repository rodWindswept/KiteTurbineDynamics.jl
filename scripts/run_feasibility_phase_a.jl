#!/usr/bin/env julia
# scripts/run_feasibility_phase_a.jl
# Stage 2: Phase A v2 feasibility campaign — DE minimising objective_feasibility.
# Corrected A1-A5 physics (commit e7bbadf+), fresh start.
# Budget: pop=8, ≤21 gens, hard cap 176 evals.  Progressive saves, resume by hash.
# Seed: V10 winner only (post-A1-A5 — known feasible).

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics, SHA, JSON3, Dates, DataFrames, CSV, Random, DelimitedFiles, Base.Threads

const CSV_LOCK = ReentrantLock()  # thread-safe CSV writes

# ══════════════════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════════════════
const POP_SIZE    = 8
const MAX_GENS    = 6
const MAX_EVALS   = 48
const P_CAP        = 50.0
const P_FLOOR      = 25.0
const FOS_DESIGN   = 1.5
const F           = 0.8    # DE differential weight
const CR          = 0.9    # DE crossover rate

const SP          = KiteTurbineDynamics.SpokeParams(enabled=false)
const BEAM        = KiteTurbineDynamics.PROFILE_ELLIPTICAL
const P_BASE      = KiteTurbineDynamics.params_v5_50kw()
const POWER_W     = 50000.0
const V_RATED     = 11.0

# ── Lift device — DESIGN-AWARE (Rod, 2026-08-05) ─────────────────────────────
# Was: a fixed RotaryLifterParams(1.3 m, ...) delivering ~638 N to EVERY genome
# regardless of mass, while its reported "1.5× margin" was computed against a
# hard-coded 12 kg v5 reference shaft.  638 N is ≈61 kg of vertical support at
# 70°; the V6.2 optimum is 74.17 kg airborne on its own.  Heavy, stiff designs
# were therefore under-supported and the margin readout concealed it — a
# systematic bias against exactly the torsional rigidity we want to buy.
#
# Now: presume the coaxial autogyro stack supplies enough lift at the lift
# bearing to hold the machine smoothly in the air, and size it to 1.5× THIS
# genome's airborne mass.  Stack sizing lives in CoaxialAutogyroStacking.jl and
# is deliberately out of scope here.  The presumption is to be published as one.
#
# Passed as a function: sizing needs the built system's mass, which does not
# exist until the genome is decoded and built.
const LIFT_MARGIN = 1.5
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=LIFT_MARGIN, v_ref=V_RATED)
const LIFT_DEVICE = lift_for

const GIT_HASH    = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
# Bumped 2026-08-07 (F4b fix): ring beam taper now follows the genome's
# Do_scale_exp with raw t_over_D.  ALL pre-fix fitness values are stale —
# resume must not reuse them (see load_existing_hashes, era-filtered).
const PHYSICS_ERA = "post-4894787_f4b-taper-reconcile"

# ── F5 measurement horizon ────────────────────────────────────────────────
# The 2026-08-05 relax sweep and the altitude traces showed power still
# decaying at the old 10 s warm-start relax — the 30 s window was sampling a
# departing signal, so P_mean was not a mean and the stationarity gate could
# never fire (1/44 stationary in the 2026-08-06 campaign).  Extend the relax
# to 120 s (collapse completes by ~120 s per trace_altitude_torque.jl) so the
# window measures the settled state.  Set here, NOT in src — the source
# default stays 10 s so unit tests don't run 3.75× longer.
KiteTurbineDynamics.WARM_RELAX_S[] = 120.0

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const OUT_CSV = joinpath(OUT_DIR, "feasibility_phase_a_v2.csv")
mkpath(OUT_DIR)

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds + seeds
# ══════════════════════════════════════════════════════════════════════════════
lo_full, hi_full = KiteTurbineDynamics.search_bounds_v11(P_BASE, BEAM; max_ground_radius=5.0)

# V10 winner is OBSOLETE (2026-08-07, F1 audit): X_V10 sits OUTSIDE the v11
# search box in 5 of 15 dims (x1=0.06 < Do_lo=0.20; x3=0.88 < ar_lo=1.0;
# x5=2.89 < r_hub_lo=5.37; x11=31.99 > 25; x12=35 > 25) and evaluates to
# 0.39 W under current physics.  The DE cannot search where its anchor lives.
# Reseed with the best feasible genome from the 2026-08-06 run (79e2d24b,
# P=44.2 kW, n_lines=15) — inside the box, and the strongest known point.
# NOTE: its fitness in the CSV is STALE (pre-F4b); the era-filtered resume
# (load_existing_hashes) forces re-evaluation under the corrected physics.
const X_SEED = [0.2, 0.01, 1.0, 1.0, 5.366563145999496, 1.5, 2.290336420077981,
                15.380561394283504, 0.7635956009855438, 19.0, 22.42396791533018,
                25.0, 0.8804365395898538, 0.4636680969018283]  # 14-D (x15/k removed, S1)

function load_seeds()
    return [copy(X_SEED)]
end

# ══════════════════════════════════════════════════════════════════════════════
# Evaluation
# ══════════════════════════════════════════════════════════════════════════════

function evaluate_genome(x)
    x_copy = copy(x)
    try
        f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b, T_lift =
            KiteTurbineDynamics.warmstart_with_k_bracket(x_copy, BEAM, P_BASE;
                power_W=POWER_W, v_rated=V_RATED, spoke=SP, lift_device=LIFT_DEVICE)

        f_feas = objective_feasibility(P_mean, FoS_min; P_cap=P_CAP, P_floor=P_FLOOR, FoS_design=FOS_DESIGN, P_range=P_range)
        tier = P_mean < P_FLOOR ? "stalled" : FoS_min < FOS_DESIGN ? "feasibility" : "feasible"

        # S3: T_lift is the per-genome mean lift-line tension (real newtons)
        # measured over the scoring window — the sized lifter's T_ref scaled
        # by (v/v_ref)².  Previously this column recorded the dimensionless
        # LIFT_MARGIN constant (1.5) mislabelled as newtons.
        lift_tension = T_lift

        return (f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drifted, stationary,
                util_a, util_b, lift_tension, f_feas, tier, true)
    catch e
        # 12.0 (rejection band), NOT 11.0: an exception must never score better
        # than a null-FoS rejection, and 11.0 collides exactly with a legitimate
        # P_mean=0 stall (10 + (25-0)/25).  See handover-2026-08-05.
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
        # Era filter (2026-08-07, F1 audit): a genome hash is only "already
        # evaluated" if its row was scored under the CURRENT physics era.
        # Pre-fix rows (e.g. the 44-row 4894787 campaign) carry stale fitness
        # — the F4b taper fix changed the physics, so they must re-evaluate.
        if :physics_era in names(df)
            df = filter(row -> row.physics_era == PHYSICS_ERA, df)
        end
        return Set(string.(df.genome_hash))
    catch
        return Set{String}()
    end
end

function save_row(gh, x, n_lines, n_active, f_v11, k_chosen, P_mean, FoS_min, ω_eq,
                  P_range, drifted, stationary, util_a, util_b, lift_tension, f_feas, tier, gen)
    row = Dict{Symbol,Any}(
        :genome_hash => gh, :physics_era => PHYSICS_ERA, :git_hash => GIT_HASH,
        :x1=>x[1],:x2=>x[2],:x3=>x[3],:x4=>x[4],:x5=>x[5],
        :x6=>x[6],:x7=>x[7],:x8=>x[8],:x9=>x[9],:x10=>x[10],
        :x11=>x[11],:x12=>x[12],:x13=>x[13],:x14=>x[14],
        :x15 => log10(k_chosen),  # S1: k is bracket-owned; record log₁₀ of the k actually used
        :n_lines => n_lines, :n_active => n_active,
        :f_v11 => f_v11, :k_chosen => k_chosen, :P_mean_kw => P_mean,
        :FoS_min => FoS_min, :omega_eq_rpm => ω_eq * 60 / (2π),
        :P_range_kw => P_range, :drift_flag => drifted, :stationary => stationary,
        :util_axial => util_a, :util_bending => util_b,
        :lift_tension_N => lift_tension,
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

function differential_evolution(pop, fit, gen)
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

    # Pre-load existing hashes (read-only)
    existing_hashes = load_existing_hashes()

    # Threaded evaluation
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
                continue  # accepted stays false
            end
            nl = 0; na = 0
            try
                r = KiteTurbineDynamics.design_from_vector_v10(trial[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
                nl = r.design.n_lines; na = r.n_active
            catch; end
            lock(CSV_LOCK) do
                save_row(gh, trial, nl, na, f_v11, k_chosen,
                         P_mean, FoS_min, ω_eq, P_range, drifted, stationary, ua, ub, lift_tension, f_feas, tier, gen)
            end
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
    println("Phase A v2 — Feasibility Campaign (A1-A5 corrected)")
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
        f_v11, k, P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, ok = evaluate_genome(x)
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
        @printf("[init %d] %s  P=%.1f FoS=%.3f f_feas=%.3f tier=%s\n",
            eval_count, gh[1:8], P, FoS, f_feas, tier)
        nl = 0; na = 0
        try
            r = KiteTurbineDynamics.design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
            nl = r.design.n_lines; na = r.n_active
        catch; end
        save_row(gh, x, nl, na, f_v11, k,
                 P, FoS, ω, Pr, dr, st, ua, ub, lift_tension, f_feas, tier, 0)
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
        gen_best_P = 0.0; gen_best_FoS = Inf; gen_best_FoS_check = Inf; gen_best_stationary = false
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

        # Gate checks — must also be stationary
        if gen_best_FoS >= FOS_DESIGN && gen_best_P >= P_FLOOR && gen_best_stationary
            println("\n╔══════════════════════════════════════════════╗")
            @printf("║  GREEN: FoS ≥ %.1f, P ≥ %.0f kW, stationary  ║\n", FOS_DESIGN, P_FLOOR)
            println("║  Genome: $(genome_hash(pop[gen_best_idx])[1:8])  ║")
            println("╚══════════════════════════════════════════════╝")
            println("→ Freeze genome, proceed to Stage 3 verification.")
            break
        elseif gen_best_FoS >= FOS_DESIGN && gen_best_P >= P_FLOOR && !gen_best_stationary
            println("  → Gate: FoS/P met but stationary=false — NOT GREEN, continuing.")
        end
    end

    # Final verdict
    final_best_idx = argmin(fit)
    _, _, P_fin, FoS_fin, _, _, _, _, _, _, _, f_feas_fin, tier_fin, _ = evaluate_genome(pop[final_best_idx])
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
