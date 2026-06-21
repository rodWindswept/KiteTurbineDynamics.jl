#!/usr/bin/env julia
# scripts/run_v6_campaign.jl
#
# Phase 3.0 — V9.0 DE Optimisation Campaign (dynamic equilibrium objective).
#
# Changes from V6.8:
#   - Replaced static TSR=4.1 drag constraint with dynamic equilibrium solve:
#     solve_equilibrium_omega() scans ω from 1–300 rpm to find the actual
#     operating point where P_aero_total = P_par + P_gen.
#   - Constraint: ω_eq must exist AND P_gen(ω_eq) ≥ 50 kW AND structure
#     must survive loads at ω_eq (evaluated at the true operating point).
#   - Removed all ad-hoc drag margins (2× factor, 0.2 blanket, P_per_rotor×cos(bank) credit).
#     The equilibrium solve is the single physically-correct gate.
#   - Same 12-DoF search bounds as V6.5–V6.8.
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
# DESIGN VARIABLES (12-DoF — knuckle mass derived from beam geometry)
# ═══════════════════════════════════════════════════════════════════════════
#
#   x[1]  Do_top           beam outer diameter at hub (m)
#   x[2]  t_over_D         wall thickness ratio
#   x[3]  beam_aspect      elliptical b/a
#   x[4]  Do_scale_exp     Do(r) = Do_top·(r/r_hub)^exp
#   x[5]  r_hub            hub ring radius (m)
#   x[6]  r_bottom         ground ring radius (m)
#   x[7]  target_Lr        target L/r ratio
#   x[8]  n_lines          polygon sides (3–12, rounded to int)
#   x[9]  density_profile  ring density bias (−0.8..0.8)
#   x[10] n_expansion      number of expansion rotors (0–12, rounded to int)
#   x[11] bank_angle_deg   expansion blade bank angle (5°–35°)
#   x[12] blade_scale      expansion blade span/chord scale (0.02–2.0)
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
    max_ground_radius = nothing  # nil = use default
    for (i, arg) in enumerate(ARGS)
        if arg == "--power" && i < length(ARGS)
            power_kw = parse(Int, ARGS[i + 1])
        elseif arg == "--max-ground-radius" && i < length(ARGS)
            max_ground_radius = parse(Float64, ARGS[i + 1])
        end
    end
    return (quick=quick, power_kw=power_kw, max_ground_radius=max_ground_radius)
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

    # For 50kW, widen bounds: the mass-scaled trpt_hub_radius (3.58m) is
    # far smaller than the BEM rotor (7.4–9.3m), giving r_hub bounds of
    # only 2.9–4.3m.  This starves the torsional collapse check because
    # ground-adjacent ring radii (r_min) are too small relative to r_rotor.
    # Use a bounds params with trpt_hub_radius ≈ BEM rotor radius and a
    # larger max_ground_radius so the DE can find feasible geometries.
    mgr = if args.max_ground_radius !== nothing
        args.max_ground_radius
    elseif args.power_kw == 50
        5.0   # 50kW needs wider ground ring: r_bot/r_rotor must be >30%
    else
        OPT_MAX_GROUND_RADIUS  # 1.5m for 10kW (flatbed trailer limit)
    end

    p_bounds = if args.power_kw == 50
        # Use a trpt_hub_radius that matches the BEM rotor scale (~9m for 8 blades)
        # so r_hub bounds span 7.2–10.8m — wide enough for the DE to find the
        # right ring-to-rotor ratio.
        mass_scale(params_v5_10kw(), 10.0, 50.0 * (9.0 / 3.58)^2)
    else
        p
    end

    beam_profile = PROFILE_ELLIPTICAL
    lo, hi = search_bounds_v6(p_bounds, beam_profile; max_ground_radius=mgr)
    dim = length(lo)
    @printf("  Design space: %d dimensions\n", dim)
    @printf("  Bounds: [%.2f, %.2f] × ...\n", lo[1], hi[1])

    # ── Objective wrapper ──────────────────────────────────────────────────
    obj_wrapper =
        x -> begin
            # Round integer variables
            x_rounded = copy(x)
            x_rounded[8] = round(Int, clamp(x[8], 3, 24))    # n_lines (now at position 8)
            x_rounded[10] = round(Int, clamp(x[10], 0, 20))   # n_expansion (widened: 0-20)
            try
                return objective_v6(x_rounded, beam_profile, p; power_W=power_W, max_ground_radius=mgr)
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
    island_bests = Tuple{Int,Float64,Vector{Float64}}[]  # (island, mass, best_x)
    param_trace = Tuple{Int,Int,Vector{Float64}}[]  # (island, iteration, best_x)

    campaign_start = time()

    for island in 1:n_islands
        Random.seed!(42 + island - 1)
        println("\n  ── Island $island / $n_islands " * "─"^30)

        population = [lo .+ rand(Float64, dim) .* (hi .- lo) for _ in 1:popsize]

        best_x = nothing
        best_cost = Inf
        history = Float64[]
        collapse_count = 0
        collapse_no_improve = 0
        pre_collapse_best = Inf

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

            # FULL parameter trace: save best_x every iteration for correlation analysis
            if best_x !== nothing
                push!(param_trace, (island, iteration, copy(best_x)))
            end

            # ── Population collapse detection ────────────────────────────
            # Every 100 iterations, sample 10 random population members.
            # If all sampled costs == best_cost (within 1e-6), the population
            # has collapsed to identical candidates — NOT genuine convergence.
            if iteration % 100 == 0 && iteration > 0
                sample_idx = rand(1:popsize, min(10, popsize))
                sample_costs = [obj_wrapper(population[j]) for j in sample_idx]
                unique_sample = length(Set(round(c, digits=6) for c in sample_costs))
                if unique_sample <= 1
                    collapse_count += 1
                    # Track whether reseeds are producing improvement
                    if best_cost >= pre_collapse_best * 0.995
                        collapse_no_improve += 1
                    else
                        collapse_no_improve = 0
                        pre_collapse_best = best_cost
                    end
                    # After 10 collapses with no improvement, abandon island
                    if collapse_no_improve >= 10
                        @printf(
                            "  [Island %d | iter %6d] STAGNANT — %d collapses, no improvement. Moving on.\\n",
                            island, iteration, collapse_no_improve
                        )
                        break
                    end
                    # Reseed 98% of population with fresh random candidates.
                    # Keep only the single best individual (with small perturbation
                    # to avoid immediately converging back to the same point).
                    n_keep = 1
                    best_kept = copy(best_x)
                    # Perturb the kept best by ±5% in each dimension
                    for j in 1:dim
                        delta = 0.05 * (rand() - 0.5) * (hi[j] - lo[j])
                        best_kept[j] = clamp(best_kept[j] + delta, lo[j], hi[j])
                    end
                    new_pop = [best_kept]
                    for _ in 2:popsize
                        push!(new_pop, lo .+ rand(Float64, dim) .* (hi .- lo))
                    end
                    population = new_pop
                    # Re-evaluate best after reseed
                    best_cost = obj_wrapper(best_kept)
                    best_x = copy(best_kept)
                    @printf(
                        "  [Island %d | iter %6d] COLLAPSE #%d — reseeded %d candidates  best = %.2f kg\\n",
                        island, iteration, collapse_count, popsize - n_keep, best_cost
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

            # Convergence check removed — let the full 10,000 iterations run.
            # The collapse detection + reseed provides enough exploration;
            # stopping early just locks us into the first basin found.
            # Each island runs to max_iter, then moves to the next.
        end

        if best_cost < global_best_cost
            global_best_cost = best_cost
            global_best_x = best_x
            global_best_island = island
            @printf(
                "  ** New global best: %.3f kg (island %d) **\\n", global_best_cost, island
            )
        end

        # Save this island's final best for per-island analysis
        if best_x !== nothing
            push!(island_bests, (island, best_cost, copy(best_x)))
        end
    end

    elapsed = time() - campaign_start
    println("\n  Optimisation complete in $(_format_duration(elapsed))")
    @printf(
        "  Global best mass: %.2f kg  (island %d)\n", global_best_cost, global_best_island
    )

    # ── Save results ───────────────────────────────────────────────────────
    out_dir = joinpath(
        dirname(@__DIR__), "scripts", "results", "v9_0_campaign_$(args.power_kw)kw"
    )
    mkpath(out_dir)

    if global_best_x !== nothing
        result = design_from_vector_v6(global_best_x, beam_profile, p; max_ground_radius=mgr, power_W=power_W)
        design = result.design

        # Save best design as JSON
        best_json = Dict(
            "version" => "v9.0",
            "power_kw" => args.power_kw,
            "island_idx" => global_best_island,
            "best_mass_kg" => global_best_cost,
            "n_lines" => design.n_lines,
            "n_rings" => length(ring_radii(design)),
            "n_expansion" => length(result.stack),
            "bank_angle_deg" =>
                isempty(result.stack) ? 0.0 : result.stack[1].bank_angle_deg,
            "blade_tip_radius" => isempty(result.stack) ? 0.0 : result.stack[1].blade_tip_radius,
            "blade_scale" => isempty(result.stack) ? 1.0 : global_best_x[12],
            "profile" => string(beam_profile),
            "Do_top_m" => design.Do_top,
            "t_over_D" => design.t_over_D,
            "aspect_ratio" => design.beam_aspect,
            "Do_scale_exp" => design.Do_scale_exp,
            "r_hub_m" => design.r_hub,
            "r_bottom_m" => design.r_bottom,
            "target_Lr" => design.target_Lr,
            "density_profile" => design.density_profile,
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

        # Also save the raw DE vector for exact reproducibility
        vec_path = joinpath(out_dir, "best_vector.csv")
        open(vec_path, "w") do io
            println(io, join(global_best_x, ","))
        end
        println("  Raw vector saved to $vec_path")
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

    # Save per-island best vectors (one row per island) with named columns
    if !isempty(island_bests)
        island_df = DataFrame(;
            island=[t[1] for t in island_bests],
            mass_kg=[t[2] for t in island_bests],
        )
        col_names = ["Do_top_m", "t_over_D", "beam_aspect", "Do_scale_exp",
                     "r_hub_m", "r_bottom_m", "target_Lr", "n_lines",
                     "density_profile", "n_expansion", "bank_angle_deg", "blade_scale"]
        for (j, name) in enumerate(col_names)
            island_df[!, name] = [t[3][j] for t in island_bests]
        end
        island_path = joinpath(out_dir, "island_bests.csv")
        CSV.write(island_path, island_df)
        println("  Per-island best vectors saved to $island_path ($(length(island_bests)) islands)")
    end

    # Save FULL parameter trace (every iteration × every island) with named columns
    if !isempty(param_trace)
        trace_df = DataFrame(;
            island=[t[1] for t in param_trace],
            iteration=[t[2] for t in param_trace],
        )
        col_names = ["Do_top_m", "t_over_D", "beam_aspect", "Do_scale_exp",
                     "r_hub_m", "r_bottom_m", "target_Lr", "n_lines",
                     "density_profile", "n_expansion", "bank_angle_deg", "blade_scale"]
        for (j, name) in enumerate(col_names)
            trace_df[!, name] = [t[3][j] for t in param_trace]
        end
        trace_path = joinpath(out_dir, "parameter_trace.csv")
        CSV.write(trace_path, trace_df)
        println("  Full parameter trace saved to $trace_path ($(length(param_trace)) rows)")
    end

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
