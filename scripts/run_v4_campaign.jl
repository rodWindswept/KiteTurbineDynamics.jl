#!/usr/bin/env julia
# scripts/run_v4_campaign.jl
# 168-hour DE optimisation campaign using v4 physics (constant L/r ring spacing).
#
# 60 islands: 3 beam profiles × 5 seed-variants × 2 RNG seeds × 2 power configs
# Islands run sequentially.  Each island runs for ~2.8 h (168 h / 60 islands).
#
# Output: scripts/results/trpt_opt_v4/
#   island_NN/log.csv         — heartbeat rows every 15 min
#   island_NN/best_design.csv — single-row summary of best design found
#   campaign.log              — stdout (piped by caller via nohup)

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Dates, Random, Printf, LinearAlgebra

# ── Campaign constants ────────────────────────────────────────────────────────
const TOTAL_HOURS          = 168.0
const N_ISLANDS            = 60
const HOURS_PER_ISLAND     = TOTAL_HOURS / N_ISLANDS   # ≈ 2.8 h
const MAX_SEC_PER_ISLAND   = HOURS_PER_ISLAND * 3600.0

const POP_SIZE             = 64
const MAX_GENERATIONS      = 2_000_000
const STALL_LIMIT_GEN      = 1_500
const RESTART_KEEP_FRAC    = 0.15
const DE_F                 = 0.7
const DE_CR                = 0.9
const HEARTBEAT_PERIOD_S   = 15 * 60    # 15 min

# ── Island grid ───────────────────────────────────────────────────────────────
const BEAM_PROFILES = [PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL]
const BEAM_NAMES    = ["circular",       "elliptical",       "airfoil"]

# 5 Lr initialisation zones: bias each island's starting population toward a
# different part of the target_Lr search space.  DE then explores freely.
const LR_INIT_ZONES = [
    (0.4, 0.8),
    (0.7, 1.1),
    (1.0, 1.4),
    (1.3, 1.7),
    (1.6, 2.0),
]

# ── Island list ───────────────────────────────────────────────────────────────
struct Island
    idx      :: Int
    cfg_name :: String
    beam     :: BeamProfile
    bname    :: String
    variant  :: Int
    seed     :: Int
    lr_lo    :: Float64
    lr_hi    :: Float64
end

function build_island_list()::Vector{Island}
    islands = Island[]
    i = 0
    for cfg in ["10kw", "50kw"]
        for (bi, beam) in enumerate(BEAM_PROFILES)
            for variant in 1:5
                for seed in [1, 2]
                    i += 1
                    lr_lo, lr_hi = LR_INIT_ZONES[variant]
                    push!(islands, Island(i, cfg, beam, BEAM_NAMES[bi],
                                          variant, seed, lr_lo, lr_hi))
                end
            end
        end
    end
    @assert length(islands) == N_ISLANDS
    return islands
end

resolve_params(name) = name == "50kw" ? params_50kw() : params_10kw()

# ── Per-island DE ─────────────────────────────────────────────────────────────
function run_island(isl::Island, out_dir::String)
    mkpath(out_dir)
    log_path  = joinpath(out_dir, "log.csv")
    best_path = joinpath(out_dir, "best_design.csv")

    p    = resolve_params(isl.cfg_name)
    beam = isl.beam
    lo, hi = search_bounds_v4(p, beam)
    D = length(lo)

    # Unique RNG per island
    rng_seed = isl.seed * 1000 + isl.variant * 100 + (isl.cfg_name == "50kw" ? 50 : 0)
    rng = MersenneTwister(rng_seed)

    # Initialise population, biasing x[7] (target_Lr) to this island's zone
    pop = zeros(Float64, POP_SIZE, D)
    for i in 1:POP_SIZE
        for d in 1:D
            pop[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
        end
        pop[i, 7] = clamp(isl.lr_lo + rand(rng) * (isl.lr_hi - isl.lr_lo), lo[7], hi[7])
    end

    fitness = fill(Inf, POP_SIZE)
    obj = x -> objective_v4(x, beam, p;
                             rotor_radius=p.rotor_radius,
                             elev_angle=p.elevation_angle)

    # Initial evaluation
    for i in 1:POP_SIZE
        fitness[i] = obj(pop[i, :])
    end

    best_idx  = argmin(fitness)
    best_x    = copy(pop[best_idx, :])
    best_mass = fitness[best_idx]
    d0        = design_from_vector_v4(best_x, beam, p)
    r0        = evaluate_design(d0; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    best_fos  = r0.min_fos

    stall     = 0
    evals     = POP_SIZE
    gen       = 0
    log_initialized = isfile(log_path)

    write_hb = (elapsed_s, infeas_frac) -> begin
        d = design_from_vector_v4(best_x, beam, p)
        row = DataFrame(
            timestamp    = [string(now())],
            generation   = [gen],
            evaluations  = [evals],
            best_mass_kg = [best_mass],
            best_fos     = [best_fos],
            infeas_frac  = [infeas_frac],
            elapsed_s    = [elapsed_s],
            r_hub_m      = [d.r_hub],
            r_bottom_m   = [d.r_bottom],
            target_Lr    = [d.target_Lr],
            n_lines      = [d.n_lines],
        )
        CSV.write(log_path, row; append=log_initialized, writeheader=!log_initialized)
        log_initialized = true
        nothing
    end

    t_start   = time()
    t_last_hb = t_start
    done      = false

    while gen < MAX_GENERATIONS && !done
        gen += 1
        infeas_count = 0
        gen_best   = Inf
        gen_best_x = best_x

        for i in 1:POP_SIZE
            r1 = r2 = r3 = i
            while r1 == i || r2 == i || r3 == i || r1 == r2 || r1 == r3 || r2 == r3
                r1 = rand(rng, 1:POP_SIZE)
                r2 = rand(rng, 1:POP_SIZE)
                r3 = rand(rng, 1:POP_SIZE)
            end
            v = pop[r1, :] .+ DE_F .* (pop[r2, :] .- pop[r3, :])
            for d in 1:D
                if v[d] < lo[d]; v[d] = lo[d] + (lo[d] - v[d]) * 0.5; end
                if v[d] > hi[d]; v[d] = hi[d] - (v[d] - hi[d]) * 0.5; end
                v[d] = clamp(v[d], lo[d], hi[d])
            end
            u = copy(pop[i, :])
            jr = rand(rng, 1:D)
            for d in 1:D
                if rand(rng) < DE_CR || d == jr
                    u[d] = v[d]
                end
            end

            f_u = obj(u)
            evals += 1
            f_u >= 1e6 && (infeas_count += 1)

            if f_u < fitness[i]
                pop[i, :] .= u
                fitness[i]  = f_u
            end
            if fitness[i] < gen_best
                gen_best   = fitness[i]
                gen_best_x = pop[i, :]
            end
        end

        if gen_best < best_mass
            best_mass = gen_best
            best_x    = copy(gen_best_x)
            dg = design_from_vector_v4(best_x, beam, p)
            rg = evaluate_design(dg; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
            best_fos = rg.min_fos
            stall    = 0
        else
            stall += 1
        end

        now_t   = time()
        elapsed = now_t - t_start

        if now_t - t_last_hb >= HEARTBEAT_PERIOD_S
            write_hb(elapsed, infeas_count / POP_SIZE)
            t_last_hb = now_t
        end

        if gen % 50 == 0
            @printf("[%s] island=%02d gen=%d evals=%d best=%.3fkg FOS=%.2f stall=%d\n",
                    Dates.format(now(), "HH:MM:SS"), isl.idx, gen, evals,
                    best_mass, best_fos, stall)
            flush(stdout)
        end

        if elapsed >= MAX_SEC_PER_ISLAND
            @printf("[%s] island=%02d budget reached at gen %d\n",
                    Dates.format(now(), "HH:MM:SS"), isl.idx, gen)
            flush(stdout)
            done = true
        end

        if stall >= STALL_LIMIT_GEN && !done
            n_keep = max(1, Int(round(RESTART_KEEP_FRAC * POP_SIZE)))
            order  = sortperm(fitness)
            elite  = Set(order[1:n_keep])
            for i in 1:POP_SIZE
                i in elite && continue
                for d in 1:D
                    pop[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
                end
                fitness[i] = obj(pop[i, :])
                evals += 1
            end
            stall = 0
            @printf("[%s] island=%02d stall restart gen=%d\n",
                    Dates.format(now(), "HH:MM:SS"), isl.idx, gen)
            flush(stdout)
        end
    end

    elapsed = time() - t_start
    write_hb(elapsed, 0.0)

    d_best = design_from_vector_v4(best_x, beam, p)
    r_best = evaluate_design(d_best; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)

    summary = DataFrame(
        island_idx      = [isl.idx],
        cfg_name        = [isl.cfg_name],
        beam_profile    = [isl.bname],
        variant         = [isl.variant],
        seed            = [isl.seed],
        best_mass_kg    = [best_mass],
        min_fos         = [best_fos],
        feasible        = [r_best.feasible],
        r_hub_m         = [d_best.r_hub],
        r_bottom_m      = [d_best.r_bottom],
        target_Lr       = [d_best.target_Lr],
        n_lines         = [d_best.n_lines],
        tether_length_m = [d_best.tether_length],
        Do_top_m        = [d_best.Do_top],
        t_over_D        = [d_best.t_over_D],
        beam_aspect     = [d_best.beam_aspect],
        Do_scale_exp    = [d_best.Do_scale_exp],
        knuckle_kg      = [d_best.knuckle_mass_kg],
        evaluations     = [evals],
        elapsed_s       = [elapsed],
        status          = [r_best.msg],
    )
    CSV.write(best_path, summary)

    return (idx=isl.idx, mass_kg=best_mass, fos=best_fos, feasible=r_best.feasible)
end

# ── Main ──────────────────────────────────────────────────────────────────────
function main()
    base_out = joinpath(@__DIR__, "results", "trpt_opt_v4")
    mkpath(base_out)

    islands = build_island_list()

    println("=" ^ 72)
    println("KiteTurbineDynamics — v4 DE Optimisation Campaign")
    @printf("168 h total  |  %d islands  |  %.2f h/island\n",
            N_ISLANDS, HOURS_PER_ISLAND)
    @printf("Pop: %d  F=%.1f  CR=%.1f  Stall=%d\n",
            POP_SIZE, DE_F, DE_CR, STALL_LIMIT_GEN)
    println("Output: ", base_out)
    println("Started: ", now())
    println("=" ^ 72)
    flush(stdout)

    results = NamedTuple[]

    for isl in islands
        @printf("\n▶ Island %02d/%d  cfg=%-5s  beam=%-10s  var=%d  seed=%d  Lr=[%.1f,%.1f]\n",
                isl.idx, N_ISLANDS, isl.cfg_name, isl.bname,
                isl.variant, isl.seed, isl.lr_lo, isl.lr_hi)
        flush(stdout)

        island_dir = joinpath(base_out, @sprintf("island_%02d", isl.idx))
        res = run_island(isl, island_dir)
        push!(results, res)

        @printf("✔ Island %02d done  mass=%.3f kg  FOS=%.2f  feasible=%s\n",
                isl.idx, res.mass_kg, res.fos, res.feasible)
        flush(stdout)
    end

    df = DataFrame(
        island   = [r.idx      for r in results],
        mass_kg  = [r.mass_kg  for r in results],
        fos      = [r.fos      for r in results],
        feasible = [r.feasible for r in results],
    )
    summary_path = joinpath(base_out, "campaign_summary.csv")
    CSV.write(summary_path, df)

    println()
    println("=" ^ 72)
    println("Campaign complete: ", now())
    b = argmin(df.mass_kg)
    @printf("Best island: %d  mass=%.3f kg  FOS=%.2f\n",
            df.island[b], df.mass_kg[b], df.fos[b])
    println("Summary: ", summary_path)
    println("=" ^ 72)
end

main()
