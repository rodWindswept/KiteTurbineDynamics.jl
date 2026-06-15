#!/usr/bin/env julia
# scripts/run_v6_campaign.jl
#
# Phase 2.4 — v6 DE Optimisation Campaign.
#
# Differential Evolution optimisation of the TRPT system with expansion rotors.
# 11 design variables, 60 islands, ~168h compute budget.
#
# Objective: minimise total airborne mass (kg)
# Constraints: FoS_beam ≥ 1.8, FoS_torsion ≥ 1.5, ground radius ≤ 1.5m
#
# ═══════════════════════════════════════════════════════════════════════════
# USAGE
# ═══════════════════════════════════════════════════════════════════════════
#
#   Quick test (5 min, verifies everything works):
#     julia --project=. scripts/run_v6_campaign.jl --quick
#
#   Full campaign (60 islands, ~168h — run in screen/tmux/nohup):
#     julia --project=. scripts/run_v6_campaign.jl
#
#   Full campaign at 50 kW:
#     julia --project=. scripts/run_v6_campaign.jl --power 50
#
#   Background (nohup — survives SSH disconnect):
#     nohup julia --project=. scripts/run_v6_campaign.jl > v6_campaign.log 2>&1 &
#
#   Background (screen — reconnect to check progress):
#     screen -S v6
#     julia --project=. scripts/run_v6_campaign.jl
#     # Ctrl+A D to detach, screen -r v6 to reconnect
#
#   Check progress (from another terminal):
#     tail -f scripts/results/v6_campaign_10kw/convergence_history.csv
#
# ═══════════════════════════════════════════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════════════════════════════════════════
#
#   scripts/results/v6_campaign_10kw/best_design.json     — best design found
#   scripts/results/v6_campaign_50kw/best_design.json     — best design found
#   scripts/results/v6_campaign_10kw/convergence_history.csv — mass vs iteration
#
# ═══════════════════════════════════════════════════════════════════════════
# DESIGN VARIABLES (11-DoF)
# ═══════════════════════════════════════════════════════════════════════════
#
#   x[1]  Do_top           beam outer diameter at hub (m)
#   x[2]  t_over_D         wall thickness ratio
#   x[3]  beam_aspect      elliptical b/a
#   x[4]  Do_scale_exp     Do(r) = Do_top·(r/r_hub)^exp
#   x[5]  r_hub            hub ring radius (m)
#   x[6]  r_bottom         ground ring radius (m)
#   x[7]  target_Lr        target L/r ratio
#   x[8]  knuckle_mass_kg  per-vertex point mass (kg)
#   x[9]  n_lines          polygon sides (3–8, rounded to int)
#   x[10] n_expansion      number of expansion rotors (0–6, rounded to int)
#   x[11] bank_angle_deg   expansion blade bank angle (5°–45°)
#
# Expansion blade tip radius, hub radius, chord, and count are inherited
# from the generating rotor — same blade mould, banked downward.
#
# Soft penalty: infeasible designs get cost = mass × (fos_req/min_fos)
# × (1.5/min_torsional_fos), providing gradient toward feasibility.

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, DataFrames, CSV, Random, Statistics

function parse_args()
    quick = "--quick" in ARGS
    power_kw = 10
    for (i, arg) in enumerate(ARGS)
        if arg == "--power" && i < length(ARGS)
            power_kw = parse(Int, ARGS[i + 1])
        end
    end
    return (quick=quick, power_kw=power_kw)
end

function main()
    args = parse_args()
    power_W = args.power_kw * 1000.0

    println("═══════════════════════════════════════════")
    println("  KTD.jl v6 — DE Optimisation Campaign")
    println("  Power: $(args.power_kw) kW")
    println("  Mode:  $(args.quick ? "QUICK (test)" : "FULL (168h)")")
    println("═══════════════════════════════════════════")

    # ── Setup ──────────────────────────────────────────────────────────────
    p = if args.power_kw == 10
        params_10kw()
    elseif args.power_kw == 50
        params_v5_50kw()
    else
        params_v5_10kw()
    end

    beam_profile = PROFILE_ELLIPTICAL
    lo, hi = search_bounds_v6(p, beam_profile)
    dim = length(lo)
    @printf("  Design space: %d dimensions\n", dim)
    @printf("  Bounds: [%.2f, %.2f] × ...\n", lo[1], hi[1])

    # ── Objective wrapper ──────────────────────────────────────────────────
    obj_wrapper =
        x -> begin
            # Round integer variables
            x_rounded = copy(x)
            x_rounded[9] = round(Int, clamp(x[9], 3, 8))   # n_lines
            x_rounded[10] = round(Int, clamp(x[10], 0, 6))   # n_expansion
            try
                return objective_v6(x_rounded, beam_profile, p; power_W=power_W)
            catch e
                @warn "Objective failed" exception = e
                return 1e9
            end
        end

    # ── Population size and island count ───────────────────────────────────
    if args.quick
        popsize = 30
        n_islands = 5
        max_iter = 100
        @printf(
            "  Quick mode: %d islands × %d population, %d iterations\n",
            n_islands,
            popsize,
            max_iter
        )
    else
        popsize = 80
        n_islands = 60
        max_iter = 10_000
        @printf(
            "  Full mode: %d islands × %d population, up to %d iterations\n",
            n_islands,
            popsize,
            max_iter
        )
        println("  Estimated runtime: ~168 hours")
    end

    # ── Run DE optimisation — island model ────────────────────────────────
    global_best_x = nothing
    global_best_cost = Inf
    global_best_island = 0
    all_history = Tuple{Int, Int, Float64}[]   # (island, iteration, mass_kg)

    campaign_start = time()

    for island in 1:n_islands
        Random.seed!(42 + island - 1)
        println("\n  ── Island $island / $n_islands " * "─"^30)

        population = [lo .+ rand(Float64, dim) .* (hi .- lo) for _ in 1:popsize]

        best_x = nothing
        best_cost = Inf
        history = Float64[]

        island_start = time()
        last_report = island_start

        for iteration in 1:max_iter
            for i in 1:popsize
                # Select three distinct random vectors
                a, b, c = rand(1:popsize, 3)
                while a == i || b == i || c == i || a == b || a == c || b == c
                    a, b, c = rand(1:popsize, 3)
                end

                # Mutation: v = x_a + F * (x_b - x_c)
                F = 0.5 + 0.3 * rand()
                mutant = population[a] .+ F .* (population[b] .- population[c])
                mutant = clamp.(mutant, lo, hi)

                # Crossover: binomial
                CR = 0.7 + 0.2 * rand()
                trial = similar(population[i])
                j_rand = rand(1:dim)
                for j in 1:dim
                    if rand() <= CR || j == j_rand
                        trial[j] = mutant[j]
                    else
                        trial[j] = population[i][j]
                    end
                end

                # Selection
                cost_trial = obj_wrapper(trial)
                cost_current = obj_wrapper(population[i])

                if cost_trial <= cost_current
                    population[i] = trial
                    if cost_trial < best_cost
                        best_cost = cost_trial
                        best_x = copy(trial)
                    end
                end
            end

            push!(history, best_cost)
            push!(all_history, (island, iteration, best_cost))

            # ── Population collapse detection ────────────────────────────
            # Every 100 iterations, sample 10 random population members.
            # If all sampled costs == best_cost (within 1e-6), the population
            # has collapsed to identical candidates — NOT genuine convergence.
            if iteration % 100 == 0 && iteration > 0
                sample_idx = rand(1:popsize, min(10, popsize))
                sample_costs = [obj_wrapper(population[j]) for j in sample_idx]
                unique_sample = length(Set(round(c, digits=6) for c in sample_costs))
                if unique_sample <= 1
                    # Reseed 80% of population with fresh random candidates
                    n_keep = max(2, popsize ÷ 5)
                    sorted_idx = sortperm([obj_wrapper(p) for p in population])
                    new_pop = [copy(population[sorted_idx[j]]) for j in 1:n_keep]
                    for _ in (n_keep + 1):popsize
                        push!(new_pop, lo .+ rand(Float64, dim) .* (hi .- lo))
                    end
                    population = new_pop
                    # Re-evaluate best after reseed
                    best_cost = Inf
                    for p in population
                        c = obj_wrapper(p)
                        if c < best_cost
                            best_cost = c
                            best_x = copy(p)
                        end
                    end
                    @printf(
                        "  [Island %d | iter %6d] COLLAPSE — reseeded %d candidates  best = %.2f kg\\n",
                        island, iteration, popsize - n_keep, best_cost
                    )
                end
            end

            # Periodic reporting
            now_t = time()
            if now_t - last_report > 30 || iteration == max_iter
                elapsed = now_t - island_start
                @printf(
                    "  [Island %d / %d | iter %6d]  best = %.3f kg  elapsed: %s\n",
                    island,
                    n_islands,
                    iteration,
                    best_cost,
                    _format_duration(elapsed)
                )
                last_report = now_t
            end

            # Convergence check — requires sufficient burn-in AND a long
            # window of genuine no-improvement.  Also checks that the
            # population is NOT collapsed (std must be non-negligible
            # relative to the cost magnitude but still small).
            if iteration > 2000 && length(history) > 500
                recent = history[(end - 499):end]
                first_best = minimum(history[1:max(1, iteration-1000)])
                last_best  = minimum(recent)
                rel_improvement = (first_best - last_best) / max(abs(first_best), 0.01)
                if rel_improvement < 0.005 && std(recent) < 0.01 * abs(mean(recent))
                    @printf("  Converged at iteration %d (Δ=%.3f%%)\n", iteration, rel_improvement*100)
                    break
                end
            end
        end

        if best_cost < global_best_cost
            global_best_cost = best_cost
            global_best_x = best_x
            global_best_island = island
            @printf(
                "  ** New global best: %.3f kg (island %d) **\n", global_best_cost, island
            )
        end
    end

    elapsed = time() - campaign_start
    println("\n  Optimisation complete in $(_format_duration(elapsed))")
    @printf(
        "  Global best mass: %.2f kg  (island %d)\n", global_best_cost, global_best_island
    )

    # ── Save results ───────────────────────────────────────────────────────
    out_dir = joinpath(
        dirname(@__DIR__), "scripts", "results", "v6_campaign_$(args.power_kw)kw"
    )
    mkpath(out_dir)

    if global_best_x !== nothing
        result = design_from_vector_v6(global_best_x, beam_profile, p)
        design = result.design

        # Save best design as JSON
        best_json = Dict(
            "version" => "v6",
            "power_kw" => args.power_kw,
            "island_idx" => global_best_island,
            "best_mass_kg" => global_best_cost,
            "n_lines" => design.n_lines,
            "n_rings" => length(ring_radii(design)),
            "n_expansion" => length(result.stack),
            "bank_angle_deg" =>
                isempty(result.stack) ? 0.0 : result.stack[1].bank_angle_deg,
            "blade_tip_radius" => isempty(result.stack) ? 0.0 : result.stack[1].blade_tip_radius,
            "profile" => string(beam_profile),
            "Do_top_m" => design.Do_top,
            "t_over_D" => design.t_over_D,
            "aspect_ratio" => design.beam_aspect,
            "Do_scale_exp" => design.Do_scale_exp,
            "r_hub_m" => design.r_hub,
            "r_bottom_m" => design.r_bottom,
            "target_Lr" => design.target_Lr,
            "knuckle_mass_kg" => design.knuckle_mass_kg,
            "tether_length_m" => design.tether_length,
            "elapsed_seconds" => elapsed,
            "n_islands" => n_islands,
            "total_iterations" => length(all_history),
        )
        json_path = joinpath(out_dir, "best_design.json")
        open(json_path, "w") do io
            println(io, "{")
            for (i, (k, v)) in enumerate(best_json)
                comma = i < length(best_json) ? "," : ""
                if v isa String
                    println(io, "  \"$k\": \"$v\"$comma")
                elseif v isa AbstractFloat
                    println(io, "  \"$k\": $v$comma")
                else
                    println(io, "  \"$k\": $v$comma")
                end
            end
            return println(io, "}")
        end
        println("  Best design saved to $json_path")
    end

    # Save history (island, iteration, mass_kg)
    hist_df = DataFrame(;
        island=[t[1] for t in all_history],
        iteration=[t[2] for t in all_history],
        mass_kg=[t[3] for t in all_history],
    )
    hist_path = joinpath(out_dir, "convergence_history.csv")
    CSV.write(hist_path, hist_df)
    println("  Convergence history saved to $hist_path")

    return println("\n  Campaign complete.")
end

function _format_duration(seconds::Float64)
    h = floor(Int, seconds / 3600)
    m = floor(Int, (seconds % 3600) / 60)
    s = round(Int, seconds % 60)
    if h > 0
        return "$(h)h $(m)m $(s)s"
    else
        return "$(m)m $(s)s"
    end
end

main()
