#!/usr/bin/env julia
# scripts/run_trpt_optimization_v2.jl
# Phase C of the 168-h Design Cartography programme.
#
# 12-DoF Differential Evolution over the enriched TRPTDesignV2 search space.
# Accepts a fixed axial profile family per island (caller handles combinatorial
# launch). Maintains an elite archive for cartography — not just the winner.
#
# Usage:
#   julia --project=. scripts/run_trpt_optimization_v2.jl \
#         --config 10kw --beam-profile circular --axial-profile parabolic \
#         --output-dir scripts/results/trpt_opt_v2/10kw_circular_parabolic_s1 \
#         --seed 1 --pop-size 64 --max-hours 12 --elite-archive-size 200

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using ArgParse, CSV, DataFrames, Dates, Random, Serialization, Printf, LinearAlgebra

# ── Configuration constants ───────────────────────────────────────────────────
const MAX_WALLCLOCK_SEC   = 168 * 3600
const HEARTBEAT_PERIOD_S  = 15 * 60
const CHECKPOINT_PERIOD_S = 30 * 60
const POP_SIZE_DEFAULT    = 64
const MAX_GENERATIONS     = 2_000_000
const STALL_LIMIT_GEN     = 1_500
const RESTART_KEEP_FRAC   = 0.15
const DE_F                = 0.7
const DE_CR               = 0.9
const ELITE_ARCHIVE_DEF   = 200

# ── CLI ──────────────────────────────────────────────────────────────────────
function parse_cli()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--config";          arg_type=String; default="10kw"
        "--beam-profile";    arg_type=String; default="circular"
        "--axial-profile";   arg_type=String; default="linear"  # or "free"
        "--output-dir";      arg_type=String; required=true
        "--seed";            arg_type=Int;    default=1
        "--pop-size";        arg_type=Int;    default=POP_SIZE_DEFAULT
        "--max-generations"; arg_type=Int;    default=MAX_GENERATIONS
        "--max-hours";       arg_type=Float64; default=12.0
        "--elite-archive-size"; arg_type=Int; default=ELITE_ARCHIVE_DEF
    end
    return parse_args(s)
end

# ── Resolvers ────────────────────────────────────────────────────────────────
parse_config(name)  = lowercase(name) == "50kw" ? ("50 kW", params_50kw()) :
                                                   ("10 kW", params_10kw())
parse_beam(name)    = (lowercase(name) == "elliptical" ? PROFILE_ELLIPTICAL :
                       lowercase(name) == "airfoil"    ? PROFILE_AIRFOIL    :
                                                         PROFILE_CIRCULAR)
function parse_axial(name)
    n = lowercase(name)
    n == "linear"         && return AXIAL_LINEAR
    n == "elliptic"       && return AXIAL_ELLIPTIC
    n == "parabolic"      && return AXIAL_PARABOLIC
    n == "trumpet"        && return AXIAL_TRUMPET
    n == "straight_taper" && return AXIAL_STRAIGHT_TAPER
    n == "free"           && return nothing      # optimizer explores all 5
    error("unknown axial profile '$name'")
end

# ── Elite archive ────────────────────────────────────────────────────────────
mutable struct ArchiveEntry
    x         :: Vector{Float64}
    mass      :: Float64
    fos       :: Float64
    feasible  :: Bool
    n_rings   :: Int
    n_lines   :: Int
    ax_idx    :: Int
    worst_ring:: Int
    r_hub     :: Float64
    taper     :: Float64
end

mutable struct EliteArchive
    capacity :: Int
    entries  :: Vector{ArchiveEntry}
end
EliteArchive(cap::Int) = EliteArchive(cap, ArchiveEntry[])

function maybe_add!(arch::EliteArchive, entry::ArchiveEntry)
    # Keep only feasible-or-nearly-feasible designs in archive
    if entry.mass >= 1e6
        return
    end
    # Diversity filter: don't store near-duplicates (L∞ < 5e-3 on normalized x)
    for e in arch.entries
        if length(e.x) == length(entry.x) &&
           maximum(abs.(e.x .- entry.x) ./ max.(abs.(e.x), 1e-6)) < 5e-3
            return
        end
    end
    push!(arch.entries, entry)
    sort!(arch.entries, by=e->e.mass)
    if length(arch.entries) > arch.capacity
        arch.entries = arch.entries[1:arch.capacity]
    end
end

function write_archive_csv(path::String, arch::EliteArchive)
    rows = DataFrame(
        rank=1:length(arch.entries),
        mass_kg   =[e.mass     for e in arch.entries],
        min_fos   =[e.fos      for e in arch.entries],
        feasible  =[e.feasible for e in arch.entries],
        n_rings   =[e.n_rings  for e in arch.entries],
        n_lines   =[e.n_lines  for e in arch.entries],
        axial_idx =[e.ax_idx   for e in arch.entries],
        r_hub_m   =[e.r_hub    for e in arch.entries],
        taper     =[e.taper    for e in arch.entries],
        worst_ring=[e.worst_ring for e in arch.entries],
        Do_top_m          =[e.x[1] for e in arch.entries],
        t_over_D          =[e.x[2] for e in arch.entries],
        beam_aspect       =[e.x[3] for e in arch.entries],
        Do_scale_exp      =[e.x[4] for e in arch.entries],
        profile_exp       =[e.x[9] for e in arch.entries],
        straight_frac     =[e.x[10] for e in arch.entries],
        knuckle_mass_kg   =[e.x[11] for e in arch.entries],
    )
    CSV.write(path, rows)
end

# ── Optimizer state ──────────────────────────────────────────────────────────
mutable struct OptStateV2
    generation     :: Int
    evaluations    :: Int
    population     :: Matrix{Float64}
    fitness        :: Vector{Float64}
    fos_values     :: Vector{Float64}
    best_x         :: Vector{Float64}
    best_mass      :: Float64
    best_fos       :: Float64
    best_gen       :: Int
    stall_counter  :: Int
    rng_state      :: MersenneTwister
    cfg_name       :: String
    beam_name      :: String
    axial_name     :: String
    started_at     :: DateTime
    cumulative_s   :: Float64
    archive        :: EliteArchive
end

function save_checkpoint(path::String, s::OptStateV2)
    open(path, "w") do io; Serialization.serialize(io, s); end
end
function load_checkpoint(path::String)::Union{OptStateV2,Nothing}
    isfile(path) || return nothing
    try open(path, "r") do io; return Serialization.deserialize(io); end
    catch; return nothing end
end

mutable struct HBLogger
    path        :: String
    initialized :: Bool
end

function heartbeat!(lg::HBLogger; gen, evals, best_mass, best_fos,
                     infeas, elapsed_s, best_x, archive_size)
    row = DataFrame(
        timestamp     =[string(now())],
        generation    =[gen],
        evaluations   =[evals],
        best_mass_kg  =[best_mass],
        best_fos      =[best_fos],
        infeas_frac   =[infeas],
        elapsed_s     =[elapsed_s],
        archive_size  =[archive_size],
        Do_top_m      =[best_x[1]],
        t_over_D      =[best_x[2]],
        beam_aspect   =[best_x[3]],
        Do_scale_exp  =[best_x[4]],
        r_hub_m       =[best_x[5]],
        taper_ratio   =[best_x[6]],
        n_rings       =[Int(round(best_x[7]))],
        axial_idx     =[Int(round(best_x[8]))],
        profile_exp   =[best_x[9]],
        straight_frac =[best_x[10]],
        knuckle_mass_kg=[best_x[11]],
        n_lines       =[Int(round(best_x[12]))],
    )
    CSV.write(lg.path, row; append=lg.initialized, writeheader=!lg.initialized)
    lg.initialized = true
end

# ── DE step ──────────────────────────────────────────────────────────────────
function de_step_v2!(state::OptStateV2, lo::Vector{Float64}, hi::Vector{Float64},
                     obj_fn::Function, archive::EliteArchive,
                     sys_params, beam_profile,
                     rotor_radius::Float64, elev_angle::Float64,
                     rng::MersenneTwister)
    N, D = size(state.population)
    gen_best = Inf
    gen_best_x = state.best_x
    infeas_count = 0

    for i in 1:N
        r1 = r2 = r3 = i
        while r1 == i || r2 == i || r3 == i || r1 == r2 || r1 == r3 || r2 == r3
            r1 = rand(rng, 1:N); r2 = rand(rng, 1:N); r3 = rand(rng, 1:N)
        end
        v = state.population[r1,:] .+ DE_F .* (state.population[r2,:] .- state.population[r3,:])
        for d in 1:D
            if v[d] < lo[d]; v[d] = lo[d] + (lo[d]-v[d])*0.5; end
            if v[d] > hi[d]; v[d] = hi[d] - (v[d]-hi[d])*0.5; end
            v[d] = clamp(v[d], lo[d], hi[d])
        end
        u = copy(state.population[i,:])
        jr = rand(rng, 1:D)
        for d in 1:D
            if rand(rng) < DE_CR || d == jr
                u[d] = v[d]
            end
        end

        f_u = obj_fn(u)
        state.evaluations += 1

        # Evaluate full design for fos + archive metadata
        design = design_from_vector_v2(u, beam_profile, sys_params)
        r_ev = evaluate_design(design; r_rotor=rotor_radius, elev_angle=elev_angle)
        if r_ev.feasible
            entry = ArchiveEntry(copy(u), r_ev.mass_total_kg, r_ev.min_fos, true,
                                 design.n_rings, design.n_lines,
                                 Int(design.axial_profile),
                                 r_ev.worst_ring_idx,
                                 design.r_hub, design.taper_ratio)
            maybe_add!(archive, entry)
        end

        if f_u < state.fitness[i]
            state.population[i,:] .= u
            state.fitness[i] = f_u
            state.fos_values[i] = r_ev.min_fos
        end
        if state.fitness[i] < gen_best
            gen_best = state.fitness[i]
            gen_best_x = state.population[i,:]
        end
        if f_u >= 1e6
            infeas_count += 1
        end
    end

    return gen_best, gen_best_x, infeas_count / N
end

# ── Constrained bounds when axial profile is locked ──────────────────────────
function apply_axial_lock!(lo, hi, locked::Union{AxialProfile,Nothing})
    if locked !== nothing
        idx = Float64(Int(locked))
        lo[8] = idx
        hi[8] = idx
    end
    return lo, hi
end

# ── Main ─────────────────────────────────────────────────────────────────────
function main()
    args = parse_cli()
    out_dir = args["output-dir"]; mkpath(out_dir)

    cfg_name, sys_params = parse_config(args["config"])
    beam = parse_beam(args["beam-profile"])
    axial_locked = parse_axial(args["axial-profile"])
    rotor_radius = sys_params.rotor_radius
    elev_angle   = sys_params.elevation_angle
    max_sec = min(args["max-hours"] * 3600.0, Float64(MAX_WALLCLOCK_SEC))

    println("=" ^ 72)
    println("TRPT v2 Sizing Optimization — Phase C")
    println("=" ^ 72)
    println("Config         : $(cfg_name)")
    println("Beam profile   : $(beam)")
    println("Axial profile  : $(axial_locked === nothing ? "FREE (all 5)" : axial_locked)")
    println("Seed           : $(args["seed"])")
    println("Pop size       : $(args["pop-size"])")
    println("Max wall-clock : $(round(max_sec/3600;digits=2)) h")
    println("Elite archive  : $(args["elite-archive-size"])")
    println("Output dir     : $(out_dir)")
    println("=" ^ 72)

    rng = MersenneTwister(args["seed"])
    lo, hi = search_bounds_v2(sys_params, beam)
    apply_axial_lock!(lo, hi, axial_locked)
    D = length(lo)
    @assert D == TRPT_V2_DIM

    ckpt_path = joinpath(out_dir, "checkpoint.jls")
    log_path  = joinpath(out_dir, "log.csv")
    arch_path = joinpath(out_dir, "elite_archive.csv")
    lg = HBLogger(log_path, isfile(log_path))

    state = load_checkpoint(ckpt_path)
    if state === nothing
        pop = zeros(Float64, args["pop-size"], D)
        for i in 1:args["pop-size"]
            for d in 1:D
                pop[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
            end
        end
        state = OptStateV2(
            0, 0, pop, fill(Inf, args["pop-size"]), fill(NaN, args["pop-size"]),
            zeros(Float64, D), Inf, 0.0, 0, 0, rng,
            cfg_name, string(beam),
            axial_locked === nothing ? "free" : string(axial_locked),
            now(), 0.0,
            EliteArchive(args["elite-archive-size"]),
        )
    else
        println(">>> Resumed from checkpoint: gen=$(state.generation), ",
                "best_mass=$(round(state.best_mass;digits=3)) kg, ",
                "archive=$(length(state.archive.entries))")
        rng = state.rng_state
    end

    obj_fn = x -> objective_v2(x, beam, sys_params;
                                rotor_radius=rotor_radius, elev_angle=elev_angle)

    # Initial eval
    if all(!isfinite, state.fitness)
        for i in 1:size(state.population, 1)
            f = obj_fn(state.population[i,:])
            state.fitness[i] = f
            state.evaluations += 1
            if f < state.best_mass
                state.best_mass = f
                state.best_x = state.population[i,:]
            end
        end
        d0 = design_from_vector_v2(state.best_x, beam, sys_params)
        r0 = evaluate_design(d0; r_rotor=rotor_radius, elev_angle=elev_angle)
        state.best_fos = r0.min_fos
        heartbeat!(lg; gen=0, evals=state.evaluations,
                   best_mass=state.best_mass, best_fos=state.best_fos,
                   infeas=sum(f -> f >= 1e6, state.fitness) / length(state.fitness),
                   elapsed_s=state.cumulative_s, best_x=state.best_x,
                   archive_size=length(state.archive.entries))
        save_checkpoint(ckpt_path, state)
    end

    t_start = time()
    t_last_hb = t_start
    t_last_ckpt = t_start
    t_last_arch = t_start

    for gen in state.generation+1 : args["max-generations"]
        gen_best, gen_best_x, infeas_frac = de_step_v2!(
            state, lo, hi, obj_fn, state.archive,
            sys_params, beam, rotor_radius, elev_angle, rng
        )
        state.generation = gen
        state.rng_state  = rng
        if gen_best < state.best_mass
            state.best_mass = gen_best
            state.best_x    = gen_best_x
            d_g = design_from_vector_v2(gen_best_x, beam, sys_params)
            r_g = evaluate_design(d_g; r_rotor=rotor_radius, elev_angle=elev_angle)
            state.best_fos = r_g.min_fos
            state.best_gen = gen
            state.stall_counter = 0
        else
            state.stall_counter += 1
        end

        now_t = time()
        state.cumulative_s += (now_t - t_start); t_start = now_t

        if now_t - t_last_hb >= HEARTBEAT_PERIOD_S
            heartbeat!(lg; gen=gen, evals=state.evaluations,
                       best_mass=state.best_mass, best_fos=state.best_fos,
                       infeas=infeas_frac, elapsed_s=state.cumulative_s,
                       best_x=state.best_x,
                       archive_size=length(state.archive.entries))
            t_last_hb = now_t
        end
        if now_t - t_last_ckpt >= CHECKPOINT_PERIOD_S
            save_checkpoint(ckpt_path, state); t_last_ckpt = now_t
        end
        if now_t - t_last_arch >= CHECKPOINT_PERIOD_S
            write_archive_csv(arch_path, state.archive); t_last_arch = now_t
        end

        if gen % 25 == 0
            @printf("[%s] gen=%d evals=%d best=%.3fkg FOS=%.2f infeas=%.2f archive=%d stall=%d\n",
                    string(now()), gen, state.evaluations, state.best_mass,
                    state.best_fos, infeas_frac, length(state.archive.entries),
                    state.stall_counter)
        end

        if state.cumulative_s >= max_sec
            @info "Wall-clock cap reached at gen $gen"; break
        end
        if state.stall_counter >= STALL_LIMIT_GEN
            n_pop = size(state.population, 1)
            n_keep = max(1, Int(round(RESTART_KEEP_FRAC * n_pop)))
            order = sortperm(state.fitness)
            elite = Set(order[1:n_keep])
            for i in 1:n_pop
                i in elite && continue
                for d in 1:D
                    state.population[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
                end
                state.fitness[i] = obj_fn(state.population[i, :])
                state.evaluations += 1
            end
            state.stall_counter = 0
            @info "Stalled; kicked non-elite at gen $gen"
        end
    end

    heartbeat!(lg; gen=state.generation, evals=state.evaluations,
               best_mass=state.best_mass, best_fos=state.best_fos,
               infeas=sum(f -> f >= 1e6, state.fitness) / length(state.fitness),
               elapsed_s=state.cumulative_s, best_x=state.best_x,
               archive_size=length(state.archive.entries))
    save_checkpoint(ckpt_path, state)
    write_archive_csv(arch_path, state.archive)

    # Final JSON
    d_best = design_from_vector_v2(state.best_x, beam, sys_params)
    r_best = evaluate_design(d_best; r_rotor=rotor_radius, elev_angle=elev_angle)
    write_best_json(joinpath(out_dir, "best_design.json"), state, d_best, r_best)

    println("=" ^ 72)
    println("Phase C optimization complete.")
    println("  Config/Beam/Axial : $(cfg_name) / $(beam) / $(state.axial_name)")
    println("  Best mass        : $(round(state.best_mass;digits=3)) kg")
    println("  Best FOS         : $(round(state.best_fos;digits=3))")
    println("  Generations      : $(state.generation)")
    println("  Evaluations      : $(state.evaluations)")
    println("  Elapsed          : $(round(state.cumulative_s/3600;digits=3)) h")
    println("  Elite archive    : $(length(state.archive.entries)) entries")
    println("=" ^ 72)
end

function write_best_json(path::String, state::OptStateV2,
                          d::TRPTDesignV2, r::EvalResult)
    open(path, "w") do io
        println(io, "{")
        println(io, "  \"config\": \"$(state.cfg_name)\",")
        println(io, "  \"beam_profile\": \"$(d.beam_profile)\",")
        println(io, "  \"axial_profile\": \"$(d.axial_profile)\",")
        println(io, "  \"timestamp\": \"$(now())\",")
        println(io, "  \"best_mass_kg\": $(state.best_mass),")
        println(io, "  \"min_fos\": $(state.best_fos),")
        println(io, "  \"evaluations\": $(state.evaluations),")
        println(io, "  \"generations\": $(state.generation),")
        println(io, "  \"elapsed_s\": $(state.cumulative_s),")
        println(io, "  \"archive_size\": $(length(state.archive.entries)),")
        println(io, "  \"design\": {")
        println(io, "    \"Do_top_m\": $(d.Do_top),")
        println(io, "    \"t_over_D\": $(d.t_over_D),")
        println(io, "    \"beam_aspect\": $(d.beam_aspect),")
        println(io, "    \"Do_scale_exp\": $(d.Do_scale_exp),")
        println(io, "    \"axial_profile\": \"$(d.axial_profile)\",")
        println(io, "    \"profile_exp\": $(d.profile_exp),")
        println(io, "    \"straight_frac\": $(d.straight_frac),")
        println(io, "    \"r_hub_m\": $(d.r_hub),")
        println(io, "    \"taper_ratio\": $(d.taper_ratio),")
        println(io, "    \"n_rings\": $(d.n_rings),")
        println(io, "    \"tether_length_m\": $(d.tether_length),")
        println(io, "    \"n_lines\": $(d.n_lines),")
        println(io, "    \"knuckle_mass_kg\": $(d.knuckle_mass_kg)")
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
