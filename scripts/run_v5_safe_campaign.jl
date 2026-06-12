#!/usr/bin/env julia
# scripts/run_v5_safe_campaign.jl
# v5-safe: corrected optimisation with per-config power levels, higher FOS margins,
# and anti-necking ground-ring constraint.
#
# Fixes vs the original v5 campaign:
#   1. CORRECTED: 10 kW islands use power_W=10000 (was hardcoded 50000)
#   2. SAFER:     FOS_torsion_required = 3.0 (was 1.5)
#   3. SAFER:     FOS_euler_required   = 2.5 (was 1.8)
#   4. ANTI-NECK: r_bottom ≥ 0.5 m     (was 0.3 m)
#
# 60 islands: 3 beam profiles × 5 Lr zones × 2 seeds × 2 power configs
# Estimated runtime: ~168 h on 60 cores (same budget as original v5)

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Dates, Random, Printf, LinearAlgebra

# ── Campaign constants ────────────────────────────────────────────────────────
const TOTAL_HOURS = 168.0
const N_ISLANDS = 60
const HOURS_PER_ISLAND = TOTAL_HOURS / N_ISLANDS
const MAX_SEC_PER_ISLAND = HOURS_PER_ISLAND * 3600.0

const POP_SIZE = 64
const MAX_GENERATIONS = 2_000_000
const STALL_LIMIT_GEN = 1_500
const RESTART_KEEP_FRAC = 0.15
const DE_F = 0.7
const DE_CR = 0.9
const HEARTBEAT_PERIOD_S = 15 * 60

# ── SAFETY OVERRIDES (higher than base constants) ─────────────────────────────
const SAFE_TORSION_FOS = 3.0    # was 1.5
const SAFE_EULER_FOS = 2.5    # was 1.8
const SAFE_R_BOTTOM_MIN = 0.5    # was 0.3 — prevents ground-end necking

const BEAM_PROFILES = [PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL]
const BEAM_NAMES = ["circular", "elliptical", "airfoil"]

const LR_INIT_ZONES = [(0.4, 0.8), (0.7, 1.1), (1.0, 1.4), (1.3, 1.7), (1.6, 2.0)]

struct Island
    idx::Int
    cfg_name::String
    beam::BeamProfile
    bname::String
    variant::Int
    seed::Int
    lr_lo::Float64
    lr_hi::Float64
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
                    push!(
                        islands,
                        Island(i, cfg, beam, BEAM_NAMES[bi], variant, seed, lr_lo, lr_hi),
                    )
                end
            end
        end
    end
    @assert length(islands) == N_ISLANDS
    return islands
end

resolve_params(name) = name == "50kw" ? params_50kw() : params_10kw()

# ── Safe objective: uses CORRECT power level + elevated FOS ────────────────────
function safe_objective_v5(x, beam, p, power_W, v_rated, elev_angle)
    design = design_from_vector_v4(x, beam, p; max_ground_radius=OPT_MAX_GROUND_RADIUS)
    # Apply safety r_bottom constraint
    if design.r_bottom < SAFE_R_BOTTOM_MIN
        return 1e6  # hard reject
    end
    r = evaluate_design(
        design;
        r_rotor=p.rotor_radius,
        elev_angle=elev_angle,
        v_peak=OPT_V_PEAK,
        fos_req=SAFE_EULER_FOS,
        v_rated=v_rated,
        P_rated=power_W,
    )
    # Override torsional FOS requirement
    torsional_ok = r.min_torsional_fos >= SAFE_TORSION_FOS
    feasible = r.feasible && torsional_ok
    return feasible ? r.mass_total_kg : 1e6 + r.mass_total_kg
end

function run_island(isl::Island, out_dir::String)
    mkpath(out_dir)
    log_path = joinpath(out_dir, "log.csv")
    best_path = joinpath(out_dir, "best_design.csv")

    p = resolve_params(isl.cfg_name)
    beam = isl.beam
    lo, hi = search_bounds_v4(p, beam)
    # Apply safe r_bottom minimum
    lo[6] = max(lo[6], SAFE_R_BOTTOM_MIN)
    D = length(lo)

    # CORRECTED: use the island's actual power level
    power_W = isl.cfg_name == "50kw" ? 50_000.0 : 10_000.0
    v_rated = isl.cfg_name == "50kw" ? 12.0 : 11.0

    rng_seed = isl.seed * 1000 + isl.variant * 100 + (isl.cfg_name == "50kw" ? 50 : 0)
    rng = MersenneTwister(rng_seed)

    pop = zeros(Float64, POP_SIZE, D)
    for i in 1:POP_SIZE
        for d in 1:D
            pop[i, d] = lo[d] + rand(rng) * (hi[d] - lo[d])
        end
        pop[i, 7] = clamp(isl.lr_lo + rand(rng) * (isl.lr_hi - isl.lr_lo), lo[7], hi[7])
    end

    fitness = fill(Inf, POP_SIZE)
    obj = x -> safe_objective_v5(x, beam, p, power_W, v_rated, p.elevation_angle)

    for i in 1:POP_SIZE
        fitness[i] = obj(pop[i, :])
    end

    best_idx = argmin(fitness)
    best_x = copy(pop[best_idx, :])
    best_mass = fitness[best_idx]
    d0 = design_from_vector_v4(best_x, beam, p)
    r0 = evaluate_design(
        d0;
        r_rotor=p.rotor_radius,
        elev_angle=p.elevation_angle,
        v_rated=v_rated,
        P_rated=power_W,
    )
    best_fos = r0.min_fos
    best_tfos = r0.min_torsional_fos

    stall = 0
    evals = POP_SIZE
    gen = 0
    log_initialized = isfile(log_path)

    write_hb =
        (elapsed_s, infeas_frac) -> begin
            d = design_from_vector_v4(best_x, beam, p)
            row = DataFrame(;
                timestamp=[string(now())],
                generation=[gen],
                evaluations=[evals],
                best_mass_kg=[best_mass],
                best_fos=[best_fos],
                best_tfos=[best_tfos],
                infeas_frac=[infeas_frac],
                elapsed_s=[elapsed_s],
                r_hub_m=[d.r_hub],
                r_bottom_m=[d.r_bottom],
                target_Lr=[d.target_Lr],
                n_lines=[d.n_lines],
            )
            CSV.write(log_path, row; append=log_initialized, writeheader=(!log_initialized))
            log_initialized = true
        end

    t_start = time();
    t_last_hb = t_start;
    done = false

    while gen < MAX_GENERATIONS && !done
        gen += 1
        infeas_count = 0;
        gen_best = Inf;
        gen_best_x = best_x

        for i in 1:POP_SIZE
            r1=r2=r3=i
            while r1==i||r2==i||r3==i||r1==r2||r1==r3||r2==r3
                r1=rand(rng, 1:POP_SIZE);
                r2=rand(rng, 1:POP_SIZE);
                r3=rand(rng, 1:POP_SIZE)
            end
            v=pop[r1, :] .+ DE_F .* (pop[r2, :] .- pop[r3, :])
            for d in 1:D
                v[d]<lo[d] && (v[d]=lo[d]+(lo[d]-v[d])*0.5)
                v[d]>hi[d] && (v[d]=hi[d]-(v[d]-hi[d])*0.5)
                v[d]=clamp(v[d], lo[d], hi[d])
            end
            u=copy(pop[i, :]);
            jr=rand(rng, 1:D)
            for d in 1:D
                ;
                (rand(rng)<DE_CR||d==jr) && (u[d]=v[d]);
            end
            f_u=obj(u);
            evals+=1;
            f_u>=1e6 && (infeas_count+=1)
            if f_u<fitness[i]
                ;
                pop[i, :].=u;
                fitness[i]=f_u;
            end
            if fitness[i]<gen_best
                ;
                gen_best=fitness[i];
                gen_best_x=pop[i, :];
            end
        end

        if gen_best < best_mass
            best_mass=gen_best;
            best_x=copy(gen_best_x)
            dg=design_from_vector_v4(best_x, beam, p)
            rg=evaluate_design(
                dg;
                r_rotor=p.rotor_radius,
                elev_angle=p.elevation_angle,
                v_rated=v_rated,
                P_rated=power_W,
            )
            best_fos=rg.min_fos;
            best_tfos=rg.min_torsional_fos;
            stall=0
        else
            stall+=1
        end

        elapsed=time()-t_start
        if time()-t_last_hb>=HEARTBEAT_PERIOD_S
            ;
            write_hb(elapsed, infeas_count/POP_SIZE);
            t_last_hb=time();
        end
        if gen%50==0
            @printf(
                "[%s] island=%02d gen=%d evals=%d best=%.3fkg FOS=%.2f TFOS=%.2f stall=%d\n",
                Dates.format(now(), "HH:MM:SS"),
                isl.idx,
                gen,
                evals,
                best_mass,
                best_fos,
                best_tfos,
                stall
            )
            flush(stdout)
        end
        if elapsed>=MAX_SEC_PER_ISLAND
            @printf(
                "[%s] island=%02d budget reached\n",
                Dates.format(now(), "HH:MM:SS"),
                isl.idx
            )
            flush(stdout);
            done=true
        end
        if stall>=STALL_LIMIT_GEN && !done
            n_keep=max(1, Int(round(RESTART_KEEP_FRAC*POP_SIZE)))
            order=sortperm(fitness);
            elite=Set(order[1:n_keep])
            for i in 1:POP_SIZE
                i in elite && continue
                for d in 1:D
                    ;
                    pop[i, d]=lo[d]+rand(rng)*(hi[d]-lo[d]);
                end
                fitness[i]=obj(pop[i, :]);
                evals+=1
            end;
            stall=0
            @printf(
                "[%s] island=%02d stall restart\n", Dates.format(now(), "HH:MM:SS"), isl.idx
            )
            flush(stdout)
        end
    end

    d_best=design_from_vector_v4(best_x, beam, p)
    r_best=evaluate_design(
        d_best;
        r_rotor=p.rotor_radius,
        elev_angle=p.elevation_angle,
        v_rated=v_rated,
        P_rated=power_W,
    )
    summary=DataFrame(;
        island_idx=[isl.idx],
        cfg_name=[isl.cfg_name],
        beam_profile=[isl.bname],
        variant=[isl.variant],
        seed=[isl.seed],
        best_mass_kg=[best_mass],
        min_fos=[best_fos],
        min_torsional_fos=[best_tfos],
        feasible=[r_best.feasible && best_tfos>=SAFE_TORSION_FOS],
        r_hub_m=[d_best.r_hub],
        r_bottom_m=[d_best.r_bottom],
        target_Lr=[d_best.target_Lr],
        n_lines=[d_best.n_lines],
        tether_length_m=[d_best.tether_length],
        Do_top_m=[d_best.Do_top],
        t_over_D=[d_best.t_over_D],
        beam_aspect=[d_best.beam_aspect],
        Do_scale_exp=[d_best.Do_scale_exp],
        knuckle_kg=[d_best.knuckle_mass_kg],
        evaluations=[evals],
        elapsed_s=[elapsed],
        status=[r_best.constraint_msg],
    )
    CSV.write(best_path, summary)
    return (
        idx=isl.idx,
        mass_kg=best_mass,
        fos=best_fos,
        tfos=best_tfos,
        feasible=r_best.feasible&&best_tfos>=SAFE_TORSION_FOS,
    )
end

function main()
    base_out=joinpath(@__DIR__, "results", "trpt_opt_v5_safe");
    mkpath(base_out)
    islands=build_island_list()
    println("="^72)
    println("KiteTurbineDynamics — v5-SAFE Optimisation Campaign")
    @printf("168 h | %d islands | %.2f h/island\n", N_ISLANDS, HOURS_PER_ISLAND)
    @printf(
        "Torsion FOS≥%.1f  Euler FOS≥%.1f  r_bottom≥%.1fm\n",
        SAFE_TORSION_FOS,
        SAFE_EULER_FOS,
        SAFE_R_BOTTOM_MIN
    )
    println("CORRECTED: per-config power levels (10kW→10kW, 50kW→50kW)")
    println("Output: ", base_out);
    println("Started: ", now());
    println("="^72);
    flush(stdout)

    results=NamedTuple[]
    for isl in islands
        @printf(
            "\n▶ Island %02d/%d cfg=%-5s beam=%-10s var=%d seed=%d\n",
            isl.idx,
            N_ISLANDS,
            isl.cfg_name,
            isl.bname,
            isl.variant,
            isl.seed
        )
        flush(stdout)
        island_dir=joinpath(base_out, @sprintf("island_%02d", isl.idx))
        res=run_island(isl, island_dir);
        push!(results, res)
        @printf(
            "✔ Island %02d mass=%.3fkg FOS=%.2f TFOS=%.2f\n",
            isl.idx,
            res.mass_kg,
            res.fos,
            res.tfos
        )
        flush(stdout)
    end
    CSV.write(
        joinpath(base_out, "campaign_summary.csv"),
        DataFrame(;
            island=[r.idx for r in results],
            mass_kg=[r.mass_kg for r in results],
            fos=[r.fos for r in results],
            tfos=[r.tfos for r in results],
            feasible=[r.feasible for r in results],
        ),
    )
    return println("\nCampaign complete: ", now())
end

main()
