#!/usr/bin/env julia
# scripts/run_trpt_optimization.jl
# Item B2 — TRPT Sizing Optimization Runner.
#
# Runs a Differential Evolution search over the TRPT design parameter space
# for one (config, profile) pair.  Designed to be launched as a detached
# background process with a 168-hour wall-clock budget.
#
# Usage:
#   julia --project=. scripts/run_trpt_optimization.jl \
#         --config 10kw --profile circular --output-dir scripts/results/trpt_opt/10kw_circular
#
# Logging contract (Item B2 acceptance criteria):
#   - CSV heartbeat log  (≤30 min cadence) at <out>/log.csv
#   - Serialized checkpoint (≤60 min cadence) at <out>/checkpoint.jls
#   - Final result JSON at <out>/best_design.json on convergence
#
# Recovery: on restart the runner reads checkpoint.jls if present and resumes
# from the saved generation.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using ArgParse, CSV, DataFrames, Dates, Random, Serialization, Printf, LinearAlgebra

# ── Configuration constants ───────────────────────────────────────────────────
const MAX_WALLCLOCK_SEC   = 168 * 3600      # 168-hour hard wall-clock cap
const HEARTBEAT_PERIOD_S  = 30 * 60         # 30-min CSV log cadence
const CHECKPOINT_PERIOD_S = 60 * 60         # 60-min checkpoint cadence
const POP_SIZE            = 48              # DE population
const MAX_GENERATIONS     = 2_000_000       # upper generation bound
const STALL_LIMIT_GEN     = 2_000           # trigger restart after N generations without improvement
const RESTART_KEEP_FRAC   = 0.20            # on restart, keep top 20% elite; re-seed the rest
const DE_F                = 0.7             # DE differential weight
const DE_CR               = 0.9             # DE crossover probability

# ── CLI parsing ──────────────────────────────────────────────────────────────
function parse_cli()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--config"
            help = "Baseline system: 10kw or 50kw"
            arg_type = String
            default = "10kw"
        "--profile"
            help = "Beam profile: circular, elliptical, airfoil"
            arg_type = String
            default = "circular"
        "--output-dir"
            help = "Output directory for logs + checkpoints"
            arg_type = String
            required = true
        "--seed"
            help = "RNG seed"
            arg_type = Int
            default = 42
        "--pop-size"
            help = "DE population size"
            arg_type = Int
            default = POP_SIZE
        "--max-generations"
            help = "Upper generation bound"
            arg_type = Int
            default = MAX_GENERATIONS
        "--max-hours"
            help = "Wall-clock cap (hours); default 168"
            arg_type = Float64
            default = 168.0
    end
    return parse_args(s)
end

# ── Helpers ──────────────────────────────────────────────────────────────────
function parse_config(name::String)
    lname = lowercase(name)
    return lname == "50kw" ? ("50 kW", params_50kw()) :
                              ("10 kW", params_10kw())
end

function parse_profile(name::String)
    lname = lowercase(name)
    if lname == "elliptical"
        return PROFILE_ELLIPTICAL
    elseif lname == "airfoil"
        return PROFILE_AIRFOIL
    else
        return PROFILE_CIRCULAR
    end
end

# ── Checkpoint/log infrastructure ─────────────────────────────────────────────
"""
    HeartbeatLogger

Buffered CSV writer that appends one row at each heartbeat.
"""
mutable struct HeartbeatLogger
    path          :: String
    initialized   :: Bool
end

function heartbeat!(logger::HeartbeatLogger; generation, evaluations,
                     best_mass, best_fos, infeasible_frac,
                     elapsed_s, best_params)
    row = DataFrame(
        timestamp       = [string(now())],
        generation      = [generation],
        evaluations     = [evaluations],
        best_mass_kg    = [best_mass],
        best_fos        = [best_fos],
        infeasible_frac = [infeasible_frac],
        elapsed_s       = [elapsed_s],
        Do_top_m        = [best_params[1]],
        t_over_D        = [best_params[2]],
        aspect_ratio    = [best_params[3]],
        Do_scale_exp    = [best_params[4]],
        r_hub_m         = [best_params[5]],
        taper_ratio     = [best_params[6]],
        n_rings         = [Int(round(best_params[7]))],
    )
    CSV.write(logger.path, row; append=logger.initialized,
              writeheader=!logger.initialized)
    logger.initialized = true
end

"""
    OptState

Full optimizer state, serialised to checkpoint.jls for crash recovery.
"""
mutable struct OptState
    generation     :: Int
    evaluations    :: Int
    population     :: Matrix{Float64}    # pop_size × n_params
    fitness        :: Vector{Float64}    # pop_size
    best_x         :: Vector{Float64}
    best_mass      :: Float64
    best_fos       :: Float64
    best_gen       :: Int
    stall_counter  :: Int
    rng_state      :: MersenneTwister
    profile_name   :: String
    config_name    :: String
    started_at     :: DateTime
    cumulative_s   :: Float64
end

function save_checkpoint(path::String, state::OptState)
    open(path, "w") do io
        Serialization.serialize(io, state)
    end
end

function load_checkpoint(path::String)::Union{OptState, Nothing}
    isfile(path) || return nothing
    try
        open(path, "r") do io
            return Serialization.deserialize(io)
        end
    catch err
        @warn "failed to load checkpoint $path: $err"
        return nothing
    end
end

# ── Differential Evolution (rand/1/bin) ──────────────────────────────────────
"""
    de_step!(state, bounds, obj_fn, rng)

One DE generation (in-place mutation of `state.population` and `state.fitness`).
Standard rand/1/bin scheme:
    v = x_r1 + F · (x_r2 - x_r3)      (mutation)
    u_j = v_j  if rand() < CR else x_ij (crossover)
    replace if f(u) < f(x_i)          (selection)
"""
function de_step!(state::OptState, lo::Vector{Float64}, hi::Vector{Float64},
                   obj_fn::Function, rng::MersenneTwister)
    N, D = size(state.population)
    gen_best_mass = Inf
    gen_best_x    = state.best_x
    infeas_count  = 0

    for i in 1:N
        # pick 3 distinct others
        idxs = filter(j -> j != i, 1:N)
        r1, r2, r3 = idxs[rand(rng, 1:length(idxs), 3)]
        # ensure uniqueness
        while r1 == r2 || r1 == r3 || r2 == r3
            r1, r2, r3 = idxs[rand(rng, 1:length(idxs), 3)]
        end

        # Mutation
        v = state.population[r1, :] .+ DE_F .* (state.population[r2, :] .- state.population[r3, :])
        # Boundary handling (reflect)
        for d in 1:D
            if v[d] < lo[d]; v[d] = lo[d] + (lo[d] - v[d]) * 0.5; end
            if v[d] > hi[d]; v[d] = hi[d] - (v[d] - hi[d]) * 0.5; end
            v[d] = clamp(v[d], lo[d], hi[d])
        end

        # Crossover
        u   = copy(state.population[i, :])
        jr  = rand(rng, 1:D)
        for d in 1:D
            if rand(rng) < DE_CR || d == jr
                u[d] = v[d]
            end
        end

        # Evaluate & select
        f_u = obj_fn(u)
        state.evaluations += 1
        if f_u < state.fitness[i]
            state.population[i, :] .= u
            state.fitness[i] = f_u
        end
        if state.fitness[i] < gen_best_mass
            gen_best_mass = state.fitness[i]
            gen_best_x    = state.population[i, :]
        end
        if f_u >= 1e6
            infeas_count += 1
        end
    end

    return gen_best_mass, gen_best_x, infeas_count / N
end

# ── Main ─────────────────────────────────────────────────────────────────────
function main()
    args = parse_cli()
    out_dir = args["output-dir"]
    mkpath(out_dir)

    cfg_name, sys_params = parse_config(args["config"])
    profile              = parse_profile(args["profile"])
    rotor_radius         = sys_params.rotor_radius
    elev_angle           = sys_params.elevation_angle

    max_sec = min(args["max-hours"] * 3600.0, Float64(MAX_WALLCLOCK_SEC))

    println("=" ^ 72)
    println("TRPT Sizing Optimization — Item B2")
    println("=" ^ 72)
    println("Config        : $(cfg_name)  (r_rotor=$(round(rotor_radius;digits=2)) m)")
    println("Beam profile  : $(profile)")
    println("Max wall-clock: $(round(max_sec/3600;digits=1)) h")
    println("Pop size      : $(args["pop-size"])")
    println("Output dir    : $(out_dir)")
    println("=" ^ 72)

    rng = MersenneTwister(args["seed"])
    lo, hi = search_bounds(sys_params, profile)
    D = length(lo)

    # Load checkpoint if present
    ckpt_path = joinpath(out_dir, "checkpoint.jls")
    log_path  = joinpath(out_dir, "log.csv")
    logger = HeartbeatLogger(log_path, isfile(log_path))

    state = load_checkpoint(ckpt_path)
    if state === nothing
        # Fresh start
        population = zeros(Float64, args["pop-size"], D)
        for i in 1:args["pop-size"]
            for d in 1:D
                population[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
            end
        end
        fitness = fill(Inf, args["pop-size"])
        state = OptState(
            0, 0, population, fitness,
            zeros(Float64, D), Inf, 0.0, 0, 0,
            rng, string(profile), cfg_name, now(), 0.0,
        )
    else
        println(">>> Resumed from checkpoint: gen=$(state.generation), ",
                "best_mass=$(round(state.best_mass;digits=3)) kg")
        rng = state.rng_state
    end

    obj_fn = x -> objective(x, profile, sys_params;
                             rotor_radius=rotor_radius, elev_angle=elev_angle)

    # Evaluate initial population if fresh
    if all(!isfinite, state.fitness)
        for i in 1:size(state.population, 1)
            f = obj_fn(state.population[i, :])
            state.fitness[i] = f
            state.evaluations += 1
            if f < state.best_mass
                state.best_mass = f
                state.best_x    = state.population[i, :]
            end
        end
        # Recompute best_fos
        d0 = design_from_vector(state.best_x, profile, sys_params)
        r0 = evaluate_design(d0; r_rotor=rotor_radius, elev_angle=elev_angle)
        state.best_fos = r0.min_fos
        heartbeat!(logger;
                    generation=0, evaluations=state.evaluations,
                    best_mass=state.best_mass, best_fos=state.best_fos,
                    infeasible_frac=sum(f -> f >= 1e6, state.fitness) / length(state.fitness),
                    elapsed_s=state.cumulative_s, best_params=state.best_x)
        save_checkpoint(ckpt_path, state)
    end

    t_start     = time()
    t_last_hb   = t_start
    t_last_ckpt = t_start
    gen_start   = state.generation + 1

    for gen in gen_start:args["max-generations"]
        gen_best_mass, gen_best_x, infeas_frac = de_step!(state, lo, hi, obj_fn, rng)
        state.generation = gen
        state.rng_state  = rng

        if gen_best_mass < state.best_mass
            state.best_mass = gen_best_mass
            state.best_x    = gen_best_x
            d_g = design_from_vector(gen_best_x, profile, sys_params)
            r_g = evaluate_design(d_g; r_rotor=rotor_radius, elev_angle=elev_angle)
            state.best_fos  = r_g.min_fos
            state.best_gen  = gen
            state.stall_counter = 0
        else
            state.stall_counter += 1
        end

        now_t = time()
        state.cumulative_s += (now_t - t_start)
        t_start = now_t

        # Heartbeat
        if now_t - t_last_hb >= HEARTBEAT_PERIOD_S
            heartbeat!(logger;
                        generation=gen, evaluations=state.evaluations,
                        best_mass=state.best_mass, best_fos=state.best_fos,
                        infeasible_frac=infeas_frac,
                        elapsed_s=state.cumulative_s, best_params=state.best_x)
            t_last_hb = now_t
        end

        # Checkpoint
        if now_t - t_last_ckpt >= CHECKPOINT_PERIOD_S
            save_checkpoint(ckpt_path, state)
            t_last_ckpt = now_t
        end

        # Early-console update every 50 gens
        if gen % 50 == 0
            @printf("[%s] gen=%d evals=%d best_mass=%.3f kg FOS=%.2f stall=%d\n",
                     string(now()), gen, state.evaluations, state.best_mass,
                     state.best_fos, state.stall_counter)
        end

        # Termination
        if state.cumulative_s >= max_sec
            @info "Wall-clock limit reached ($(round(max_sec/3600;digits=1)) h) at gen $gen"
            break
        end
        if state.stall_counter >= STALL_LIMIT_GEN
            # Restart: preserve top elite, randomize rest, continue.  This
            # drives meaningful use of the 168-hour budget: each restart is
            # a new DE basin exploration from a new random seed set.
            @info "Stall at gen $gen — restarting population (elite keep=$(RESTART_KEEP_FRAC))"
            n_pop       = size(state.population, 1)
            n_keep      = max(1, Int(round(RESTART_KEEP_FRAC * n_pop)))
            order       = sortperm(state.fitness)
            elite_idx   = order[1:n_keep]
            # Randomly re-seed non-elite rows
            for i in 1:n_pop
                i in elite_idx && continue
                for d in 1:length(lo)
                    state.population[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
                end
                state.fitness[i] = obj_fn(state.population[i, :])
                state.evaluations += 1
            end
            state.stall_counter = 0
        end
    end

    # Final heartbeat and checkpoint
    heartbeat!(logger;
                generation=state.generation, evaluations=state.evaluations,
                best_mass=state.best_mass, best_fos=state.best_fos,
                infeasible_frac=sum(f -> f >= 1e6, state.fitness) / length(state.fitness),
                elapsed_s=state.cumulative_s, best_params=state.best_x)
    save_checkpoint(ckpt_path, state)

    # Final evaluation + JSON
    d_best = design_from_vector(state.best_x, profile, sys_params)
    r_best = evaluate_design(d_best; r_rotor=rotor_radius, elev_angle=elev_angle)
    write_best_design_json(joinpath(out_dir, "best_design.json"),
                            state, d_best, r_best, cfg_name)
    println("=" ^ 72)
    println("Optimization complete.")
    println("  Final best_mass = $(round(state.best_mass; digits=3)) kg")
    println("  Final best_fos  = $(round(state.best_fos; digits=3))")
    println("  Total evals     = $(state.evaluations)")
    println("  Elapsed (h)     = $(round(state.cumulative_s/3600; digits=2))")
    println("=" ^ 72)
end

"""
    write_best_design_json(path, state, design, eval_result, cfg_name)

Hand-rolled JSON writer — avoids JSON.jl dep on hot-reload path.
"""
function write_best_design_json(path::String, state::OptState,
                                  design::TRPTDesign, r::EvalResult,
                                  cfg_name::String)
    open(path, "w") do io
        println(io, "{")
        println(io, "  \"config\": \"$(cfg_name)\",")
        println(io, "  \"profile\": \"$(design.profile)\",")
        println(io, "  \"timestamp\": \"$(now())\",")
        println(io, "  \"best_mass_kg\": $(state.best_mass),")
        println(io, "  \"min_fos\": $(state.best_fos),")
        println(io, "  \"evaluations\": $(state.evaluations),")
        println(io, "  \"generations\": $(state.generation),")
        println(io, "  \"elapsed_s\": $(state.cumulative_s),")
        println(io, "  \"design\": {")
        println(io, "    \"Do_top_m\": $(design.Do_top),")
        println(io, "    \"t_over_D\": $(design.t_over_D),")
        println(io, "    \"aspect_ratio\": $(design.aspect_ratio),")
        println(io, "    \"Do_scale_exp\": $(design.Do_scale_exp),")
        println(io, "    \"r_hub_m\": $(design.r_hub),")
        println(io, "    \"taper_ratio\": $(design.taper_ratio),")
        println(io, "    \"n_rings\": $(design.n_rings),")
        println(io, "    \"tether_length_m\": $(design.tether_length),")
        println(io, "    \"n_lines\": $(design.n_lines),")
        println(io, "    \"knuckle_mass_kg\": $(design.knuckle_mass_kg)")
        println(io, "  },")
        println(io, "  \"evaluation\": {")
        println(io, "    \"mass_total_kg\": $(r.mass_total_kg),")
        println(io, "    \"mass_beams_kg\": $(r.mass_beams_kg),")
        println(io, "    \"mass_knuckles_kg\": $(r.mass_knuckles_kg),")
        println(io, "    \"min_fos\": $(r.min_fos),")
        println(io, "    \"worst_ring_idx\": $(r.worst_ring_idx),")
        println(io, "    \"feasible\": $(r.feasible)")
        println(io, "  }")
        println(io, "}")
    end
end

main()
