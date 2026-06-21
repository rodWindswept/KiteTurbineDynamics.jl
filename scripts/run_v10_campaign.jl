#!/usr/bin/env julia
# scripts/run_v10_campaign.jl
#
# V10 DE Optimisation Campaign — unified rotor architecture, 14-DoF.
# Incremental CSV checkpointing, per-island headless verification, --resume flag.
#
# Usage:
#   julia --project=. scripts/run_v10_campaign.jl --power 50
#   julia --project=. scripts/run_v10_campaign.jl --power 50 --resume

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, DataFrames, CSV, Random, Statistics

function parse_args()
    quick = "--quick" in ARGS
    power_kw = 10
    max_ground_radius = nothing
    resume = "--resume" in ARGS
    islands_override = nothing
    iterations_override = nothing
    for (i, arg) in enumerate(ARGS)
        if arg == "--power" && i < length(ARGS)
            power_kw = parse(Int, ARGS[i + 1])
        elseif arg == "--max-ground-radius" && i < length(ARGS)
            max_ground_radius = parse(Float64, ARGS[i + 1])
        elseif arg == "--islands" && i < length(ARGS)
            islands_override = parse(Int, ARGS[i + 1])
        elseif arg == "--iterations" && i < length(ARGS)
            iterations_override = parse(Int, ARGS[i + 1])
        end
    end
    return (quick=quick, power_kw=power_kw, max_ground_radius=max_ground_radius,
            resume=resume, islands_override=islands_override, iterations_override=iterations_override)
end

function _fmt_dur(seconds::Float64)
    h = floor(Int, seconds / 3600); m = floor(Int, (seconds % 3600) / 60); s = round(Int, seconds % 60)
    h > 0 ? "$(h)h $(m)m $(s)s" : "$(m)m $(s)s"
end

function main()
    args = parse_args()
    power_W = args.power_kw * 1000.0

    println("═"^55)
    println("  KTD.jl V10 — DE Optimisation Campaign")
    println("  Power: $(args.power_kw) kW  |  Mode: $(args.quick ? "QUICK" : "FULL")  |  Resume: $(args.resume)")
    println("═"^55)

    # ── Setup ──────────────────────────────────────────────────────────
    p = args.power_kw == 50 ? params_v5_50kw() : params_10kw()
    mgr = args.max_ground_radius !== nothing ? args.max_ground_radius :
          args.power_kw == 50 ? 5.0 : OPT_MAX_GROUND_RADIUS

    p_bounds = args.power_kw == 50 ?
        mass_scale(params_v5_10kw(), 10.0, 50.0 * (9.0 / 3.58)^2) : p

    beam_profile = PROFILE_ELLIPTICAL  # elliptical only for V10
    lo, hi = search_bounds_v10(p_bounds, beam_profile; max_ground_radius=mgr)
    dim = length(lo)
    @printf("  Design space: %d dimensions\n", dim)
    @printf("  Bounds: [%.2f, %.2f] x ...\n", lo[1], hi[1])
    @printf("  n_lines: [%.0f, %.0f]  r_bottom: [%.1f, %.1f]\n", lo[8], hi[8], lo[6], hi[6])

    # ── DE settings ────────────────────────────────────────────────────
    if args.quick
        popsize, n_islands, max_iter = 30, 5, 100
    else
        popsize, n_islands, max_iter = 80, 60, 10_000
    end
    if args.islands_override !== nothing
        n_islands = args.islands_override
    end
    if args.iterations_override !== nothing
        max_iter = args.iterations_override
    end
    @printf("  %d islands x %d population, up to %d iterations\n", n_islands, popsize, max_iter)

    # ── Output dir ─────────────────────────────────────────────────────
    out_dir = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_$(args.power_kw)kw")
    mkpath(out_dir)

    # ── Objective wrapper ──────────────────────────────────────────────
    obj_wrapper = x -> begin
        xr = copy(x)
        xr[8] = Float64(round(Int, clamp(x[8], 3, 16)))       # n_lines
        xr[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))    # rotor_mask (continuous proxy, decoded inside)
        try
            return objective_v10(xr, beam_profile, p; power_W=power_W, max_ground_radius=mgr)
        catch e
            @warn "Objective failed" exception = e
            return 1e9
        end
    end

    # ── State ──────────────────────────────────────────────────────────
    global_best_x = nothing; global_best_cost = Inf; global_best_island = 0
    all_history = Tuple{Int,Int,Float64}[]
    island_bests = Tuple{Int,Float64,Vector{Float64}}[]
    param_trace = Tuple{Int,Int,Vector{Float64}}[]
    verifications = Tuple{Int,Float64,Float64,Float64,Float64}[]  # island, ω_stat, ω_dyn, P_dyn, FoS

    campaign_start = time()
    start_island = args.resume && isfile(joinpath(out_dir, "island_bests.csv")) ?
        nrow(CSV.read(joinpath(out_dir, "island_bests.csv"), DataFrame)) + 1 : 1

    if start_island > 1
        println("  Resuming from island $start_island")
    end

    # ── Island loop ────────────────────────────────────────────────────
    for island in start_island:n_islands
        Random.seed!(42 + island - 1)
        println("\n  -- Island $island / $n_islands " * "-"^25)

        population = [lo .+ rand(Float64, dim) .* (hi .- lo) for _ in 1:popsize]
        best_x = nothing; best_cost = Inf
        collapse_count = 0; collapse_no_improve = 0; pre_collapse_best = Inf
        island_start = time(); last_report = island_start

        for iteration in 1:max_iter
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
                cost_trial = obj_wrapper(trial)
                cost_current = obj_wrapper(population[i])
                if cost_trial <= cost_current
                    population[i] = trial
                    if cost_trial < best_cost
                        best_cost = cost_trial; best_x = copy(trial)
                    end
                end
            end

            push!(all_history, (island, iteration, best_cost))
            if best_x !== nothing
                push!(param_trace, (island, iteration, copy(best_x)))
            end

            # ── Collapse detection ─────────────────────────────────
            if iteration % 100 == 0 && iteration > 0
                sample_idx = rand(1:popsize, min(10, popsize))
                sample_costs = [obj_wrapper(population[j]) for j in sample_idx]
                unique_sample = length(Set(round(c, digits=6) for c in sample_costs))
                if unique_sample <= 1
                    collapse_count += 1
                    if best_cost >= pre_collapse_best * 0.995
                        collapse_no_improve += 1
                    else
                        collapse_no_improve = 0; pre_collapse_best = best_cost
                    end
                    if collapse_no_improve >= 10
                        @printf("  [Island %d | iter %6d] STAGNANT after %d collapses\n", island, iteration, collapse_no_improve)
                        break
                    end
                    best_kept = copy(best_x)
                    for j in 1:dim
                        delta = 0.05 * (rand() - 0.5) * (hi[j] - lo[j])
                        best_kept[j] = clamp(best_kept[j] + delta, lo[j], hi[j])
                    end
                    population = Vector{Vector{Float64}}(undef, popsize)
                    population[1] = best_kept
                    for k in 2:popsize
                        population[k] = lo .+ rand(Float64, dim) .* (hi .- lo)
                    end
                    best_cost = obj_wrapper(best_kept); best_x = copy(best_kept)
                    @printf("  [Island %d | iter %6d] COLLAPSE #%d  best=%.2f kg\n", island, iteration, collapse_count, best_cost)
                end
            end

            now_t = time()
            if now_t - last_report > 30 || iteration == max_iter
                @printf("  [Island %d/%d | iter %6d]  best=%.3f kg  elapsed: %s\n",
                    island, n_islands, iteration, best_cost, _fmt_dur(now_t - island_start))
                last_report = now_t
            end
        end

        if best_cost < global_best_cost
            global_best_cost = best_cost; global_best_x = best_x; global_best_island = island
            @printf("  ** New global best: %.3f kg (island %d) **\n", global_best_cost, island)
        end
        if best_x !== nothing
            push!(island_bests, (island, best_cost, copy(best_x)))
        end

        # ── Headless verification (feasible designs only) ───────────
        if best_cost < 1_000_000 && best_x !== nothing
            xr = copy(best_x)
            xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
            dec = design_from_vector_v10(xr, beam_profile, p; max_ground_radius=mgr, power_W=power_W)
            vf = headless_verify(dec.design, dec.rotors, p; power_W=power_W)
            if vf !== nothing && vf.feasible
                ω_rpm = vf.ω_mean * 60 / (2π)
                push!(verifications, (island, 0.0, vf.ω_mean, vf.P_gen_peak, vf.tether_fos_min))
                @printf("  Verify: ω=%.1f rpm  P=%.1f kW\n", ω_rpm, vf.P_gen_peak / 1000)
            end
        end

        # ── Island validation gate ───────────────────────────────────
        if best_cost < 1_000_000 && best_x !== nothing
            valid, msg = _validate_island(best_x, best_cost, island, power_W, beam_profile, mgr)
            if !valid
                println("\n  !! ISLAND $island VALIDATION FAILED: $msg")
                println("  !! Campaign stopped. Fix the issue and resume with --resume.")
                break
            end
            println("  [Island $island] Validation: $msg")
        end

        # ── Incremental checkpoint ──────────────────────────────────
        _checkpoint_island(out_dir, island, all_history, island_bests, param_trace, verifications,
                           global_best_x, global_best_cost, global_best_island, beam_profile, args, mgr)
    end

    # ── Final save ─────────────────────────────────────────────────────
    elapsed = time() - campaign_start
    println("\n  Optimisation complete in $(_fmt_dur(elapsed))")
    @printf("  Global best mass: %.2f kg  (island %d)\n", global_best_cost, global_best_island)
    _save_final_results(out_dir, global_best_x, global_best_cost, global_best_island,
                        beam_profile, p, args, mgr, elapsed, n_islands, all_history, island_bests, param_trace, verifications)

    # ── Post-campaign dynamic verification ────────────────────────────
    _final_dynamic_verify(out_dir, global_best_x, global_best_cost, global_best_island,
                          beam_profile, p, args, mgr)

    println("\n  Campaign complete.")
end

# ── Island validation ──────────────────────────────────────────────────────

function _validate_island(best_x, best_cost, island, power_W, beam_profile, mgr)
    xr = copy(best_x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))

    # Decode design
    result = design_from_vector_v10(xr, beam_profile, params_v5_50kw();
        max_ground_radius=mgr, power_W=power_W)

    d = result.design
    n_active = result.n_active

    # 1. Must have at least one active rotor
    n_active < 1 && return (false, "no active rotors")

    # 2. Mass sanity check
    best_cost > 300.0 && return (false, "mass $(round(best_cost,digits=1)) kg exceeds 300 kg ceiling")
    best_cost < 10.0  && return (false, "mass $(round(best_cost,digits=3)) kg is implausibly low")

    # 3. Rotor usefulness check (λ·cos(bank) — same as objective penalty)

    # 4. At least one rotor with meaningful blade area (λ·cos(bank) ≥ threshold)
    min_useful = minimum(r -> r.blade_scale * cosd(r.bank_angle_deg), result.rotors)
    min_useful < 0.01 && return (false, "min λ·cos(bank)=$(round(min_useful,digits=4)) — no rotor producing useful thrust")

    # 5. Power balance rough check
    n_lines = d.n_lines
    zs, radii, _ = ring_spacing_v4(d.r_hub, d.r_bottom, d.tether_length, d.target_Lr;
        density_profile=d.density_profile)
    expansion_params = ExpansionRotorParams[]
    for rotor in result.rotors
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, 0.0, rotor.ring_idx, 1.0,
        )
        push!(expansion_params, er)
    end
    ω_eq, _ = solve_equilibrium_self_consistent(
        d, expansion_params, params_v5_50kw(), n_lines, radii, zs;
        P_per_rotor=power_W / n_active, v_wind=11.0, elev_rad=π/6,
    )
    ω_eq === nothing && return (false, "no equilibrium ω — air brake")
    ω_rpm = ω_eq * 60 / (2π)
    ω_rpm < 1.0 && return (false, "ω=$(round(ω_rpm,digits=1)) rpm — too slow")
    ω_rpm > 250.0 && return (false, "ω=$(round(ω_rpm,digits=1)) rpm — overspeed")

    # 6. Power at equilibrium must be within 75%–125% of rated
    p_check = params_v5_50kw()
    P_gen_eq = p_check.k_mppt * ω_eq^3
    power_ratio = P_gen_eq / power_W
    power_ratio < 0.75 && return (false, "P_gen=$(round(P_gen_eq/1000,digits=1)) kW ($(round(power_ratio*100,digits=0))% of rated) — severely underpowered")
    power_ratio > 1.25 && return (false, "P_gen=$(round(P_gen_eq/1000,digits=1)) kW ($(round(power_ratio*100,digits=0))% of rated) — severely overpowered")

    # 7. Dynamic structural check: verify the gravity-settled TRPT is stable.
    #    Catches designs with degenerate geometry (bouncing head, no gravity
    #    settlement).  Full k_mppt power scan runs post-campaign on the
    #    global best (see _final_dynamic_verify below).
    vr = headless_verify_structural(d, result.rotors, params_v5_50kw();
        power_W=power_W, v_rated=11.0)
    if vr !== nothing && !vr.feasible
        return (false, "dynamic: gravity settle failed — TRPT structure is unstable")
    end

    return (true, "mass=$(round(best_cost,digits=1))kg  n_active=$n_active  ω=$(round(ω_rpm,digits=0))rpm  dyn_P=$(round(vr===nothing ? 0 : vr.P_gen_mean/1000,digits=1))kW")
end

# ── Post-campaign dynamic verification ────────────────────────────────────

function _final_dynamic_verify(out_dir, global_best_x, global_best_cost, global_best_island,
                               beam_profile, p, args, mgr)
    println("\n" * "="^70)
    println("  POST-CAMPAIGN DYNAMIC VERIFICATION")
    println("="^70)

    xr = copy(global_best_x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))

    result = design_from_vector_v10(xr, beam_profile, params_v5_50kw();
        max_ground_radius=mgr, power_W=args["power"])
    d = result.design

    println("  Running full k_mppt power scan on global best...")
    println("  (This takes ~5 minutes — scanning 8 k_mppt values)")

    vr = headless_verify(d, result.rotors, params_v5_50kw();
        power_W=args["power"], v_rated=11.0)

    if vr === nothing
        println("  Skipped (no active rotors).")
        return
    end

    ω_rpm = vr.ω_mean * 60 / (2π)
    println()
    println("  ── DYNAMIC VERIFICATION RESULT ──")
    println("  Best k_mppt:     $(round(vr.k_mppt_best, digits=0))")
    println("  Settled ω:       $(round(ω_rpm, digits=1)) rpm")
    println("  P_gen at best k: $(round(vr.P_gen_mean/1000, digits=1)) kW")
    println("  Power ratio:     $(round(vr.power_ratio * 100, digits=1))% of rated")

    if vr.feasible
        println()
        println("  *** DESIGN IS DYNAMICALLY VIABLE ***")
        println("  *** Produces >80% rated power at k_mppt=$(round(vr.k_mppt_best,digits=0)) ***")
    else
        println()
        println("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        println("  !!  WARNING: DESIGN IS DYNAMICALLY DEAD    !!")
        println("  !!  Best P_gen = $(round(vr.P_gen_mean/1000,digits=1)) kW ($(round(vr.power_ratio*100,digits=0))% rated)            !!")
        println("  !!  No k_mppt value produces >80% rated.   !!")
        println("  !!  This design passes static gates but     !!")
        println("  !!  fails dynamically — DO NOT CITE.        !!")
        println("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    end

    # Save dynamic verification report
    open(joinpath(out_dir, "dynamic_verification.txt"), "w") do io
        println(io, "Dynamic Verification Report")
        println(io, "==========================")
        println(io, "Campaign: v10_50kw")
        println(io, "Global best: Island $global_best_island, $(round(global_best_cost,digits=2)) kg")
        println(io)
        println(io, "k_mppt scan results:")
        println(io, "  Best k_mppt:     $(round(vr.k_mppt_best, digits=0))")
        println(io, "  Settled ω:       $(round(ω_rpm, digits=1)) rpm")
        println(io, "  P_gen:           $(round(vr.P_gen_mean/1000, digits=1)) kW")
        println(io, "  Power ratio:     $(round(vr.power_ratio * 100, digits=1))%")
        println(io, "  Dynamically viable: $(vr.feasible)")
    end
    println("  Report saved to $(joinpath(out_dir, "dynamic_verification.txt"))")
end

# ── Checkpoint helpers ─────────────────────────────────────────────────────

function _checkpoint_island(out_dir, island, all_history, island_bests, param_trace, verifications,
                            global_best_x, global_best_cost, global_best_island, beam_profile, args, mgr)
    # Append convergence history for this island
    ch_rows = [(i, it, m) for (i, it, m) in all_history if i == island]
    if !isempty(ch_rows)
        ch_df = DataFrame(island=[r[1] for r in ch_rows], iteration=[r[2] for r in ch_rows], mass_kg=[r[3] for r in ch_rows])
        ch_path = joinpath(out_dir, "convergence_history.csv")
        if isfile(ch_path)
            existing = CSV.read(ch_path, DataFrame)
            # Remove old entries for this island
            existing = existing[existing.island .!= island, :]
            ch_df = vcat(existing, ch_df)
        end
        CSV.write(ch_path, ch_df)
        flush(stdout)  # ensure OS writes
    end

    # Island bests
    ib_rows = [(i, m, v) for (i, m, v) in island_bests if i <= island]
    if !isempty(ib_rows)
        col_names = ["Do_top_m", "t_over_D", "beam_aspect", "Do_scale_exp", "r_hub_m", "r_bottom_m",
                     "target_Lr", "n_lines", "density_profile", "rotor_mask_proxy", "bank_top", "bank_bottom", "lambda_top", "lambda_bottom"]
        ib_df = DataFrame(island=Int[], mass_kg=Float64[])
        for c in col_names; ib_df[!, c] = Float64[]; end
        for (i, m, v) in ib_rows
            push!(ib_df, [i, m, v...])
        end
        CSV.write(joinpath(out_dir, "island_bests.csv"), ib_df)
    end

    # Verification log
    if !isempty(verifications)
        vf_df = DataFrame(
            island=[v[1] for v in verifications],
            omega_dyn=[v[3] for v in verifications],
            P_gen_peak=[v[4] for v in verifications],
            tether_fos=[v[5] for v in verifications],
        )
        CSV.write(joinpath(out_dir, "verification_log.csv"), vf_df)
    end

    # Best design (if improved)
    if global_best_x !== nothing
        xr = copy(global_best_x)
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        result = design_from_vector_v10(xr, beam_profile, params_v5_50kw(); max_ground_radius=mgr, power_W=args.power_kw * 1000.0)
        d = result.design
        best_json = Dict(
            "version" => "v10", "power_kw" => args.power_kw, "island_idx" => global_best_island,
            "best_mass_kg" => global_best_cost, "n_lines" => d.n_lines, "n_rings" => result.n_rings,
            "n_active_rotors" => result.n_active,
            "profile" => string(beam_profile), "Do_top_m" => d.Do_top, "t_over_D" => d.t_over_D,
            "aspect_ratio" => d.beam_aspect, "Do_scale_exp" => d.Do_scale_exp, "r_hub_m" => d.r_hub,
            "r_bottom_m" => d.r_bottom, "target_Lr" => d.target_Lr, "density_profile" => d.density_profile,
            "tether_length_m" => d.tether_length, "n_islands" => 60,
        )
        open(joinpath(out_dir, "best_design.json"), "w") do f
            println(f, "{")
            for (i, (k, v)) in enumerate(best_json)
                comma = i < length(best_json) ? "," : ""
                if v isa String
                    println(f, "  \"$k\": \"$v\"$comma")
                elseif v isa Float64
                    println(f, "  \"$k\": $v$comma")
                else
                    println(f, "  \"$k\": $v$comma")
                end
            end
            println(f, "}")
        end
        open(joinpath(out_dir, "best_vector.csv"), "w") do f
            write(f, join(string.(global_best_x), ","))
        end
    end
end

function _save_final_results(out_dir, global_best_x, global_best_cost, global_best_island,
                             beam_profile, p, args, mgr, elapsed, n_islands, all_history, island_bests, param_trace, verifications)
    # Full convergence history
    ch_df = DataFrame(island=[r[1] for r in all_history], iteration=[r[2] for r in all_history], mass_kg=[r[3] for r in all_history])
    CSV.write(joinpath(out_dir, "convergence_history.csv"), ch_df)

    # Full parameter trace
    col_names = ["Do_top_m", "t_over_D", "beam_aspect", "Do_scale_exp", "r_hub_m", "r_bottom_m",
                 "target_Lr", "n_lines", "density_profile", "rotor_mask_proxy", "bank_top", "bank_bottom", "lambda_top", "lambda_bottom"]
    pt_df = DataFrame(island=Int[], iteration=Int[])
    for c in col_names; pt_df[!, c] = Float64[]; end
    for (i, it, v) in param_trace
        push!(pt_df, [i, it, v...])
    end
    CSV.write(joinpath(out_dir, "parameter_trace.csv"), pt_df)

    # Island bests
    ib_df = DataFrame(island=Int[], mass_kg=Float64[])
    for c in col_names; ib_df[!, c] = Float64[]; end
    for (i, m, v) in island_bests
        push!(ib_df, [i, m, v...])
    end
    CSV.write(joinpath(out_dir, "island_bests.csv"), ib_df)

    # Verification log
    if !isempty(verifications)
        vf_df = DataFrame(
            island=[v[1] for v in verifications],
            omega_dyn=[v[3] for v in verifications],
            P_gen_peak=[v[4] for v in verifications],
            tether_fos=[v[5] for v in verifications],
        )
        CSV.write(joinpath(out_dir, "verification_log.csv"), vf_df)
    end

    # Final best
    if global_best_x !== nothing
        _checkpoint_island(out_dir, 999, [], [], [], [], global_best_x, global_best_cost, global_best_island, beam_profile, args, mgr)
    end

    println("  Results saved to $out_dir")
end

main()
