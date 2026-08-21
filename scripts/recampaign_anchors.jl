#!/usr/bin/env julia
# scripts/recampaign_anchors.jl
# Phase 1c — generate anchor batch for discrepancy modeling.
# Stratified LHS over active dims + legacy DE front members.
# Evaluates with warmstart_with_k_bracket. Progressive CSV saves.

using KiteTurbineDynamics, Printf, Statistics, Random, CSV, DataFrames

const OUT_DIR = joinpath(@__DIR__, "results", "recampaign")
const ANCHORS_CSV = joinpath(OUT_DIR, "anchors.csv")

# Active dimensions for LHS stratification (Phase 0 result)
const ACTIVE_DIMS = [:Do_top_m, :t_over_D, :beam_aspect, :Do_scale_exp,
                      :r_hub_m, :r_bottom_m, :target_Lr, :n_lines, :density_profile]

const N_ANCHORS_LHS = 40
const N_LEGACY = 10

# ══════════════════════════════════════════════════════════════════════════════

function generate_lhs_samples(p::SystemParams, n::Int)
    lo, hi = search_bounds_v11(p, PROFILE_ELLIPTICAL; max_ground_radius=5.0)
    d = length(lo)
    
    # Latin hypercube in [0,1]^d
    samples = zeros(n, d)
    for j in 1:d
        perm = randperm(n)
        for i in 1:n
            u = (perm[i] - 1.0 + rand()) / n
            samples[i, j] = lo[j] + u * (hi[j] - lo[j])
        end
    end
    
    # Round integer dims
    for i in 1:n
        samples[i, 8] = round(Int, clamp(samples[i, 8], 3, 16))  # n_lines
        samples[i, 10] = clamp(samples[i, 10], 0.0, Float64(N_VALID_MASKS))  # rotor_mask
    end
    
    return samples
end

function collect_legacy_front_members()
    base = joinpath(dirname(@__DIR__), "scripts", "results")
    members = Vector{Float64}[]
    
    # V10 tight — best islands
    for d in ["v10_campaign_50kw_tight", "v10_campaign_50kw_cons", "v10_campaign_50kw_old",
              "v9_0_campaign_50kw"]
        path = joinpath(base, d, "island_bests.csv")
        isfile(path) || continue
        df = CSV.read(path, DataFrame)
        for row in eachrow(df)
            x = zeros(15)
            for (j, col) in enumerate(ACTIVE_DIMS)
                if string(col) in names(df)
                    x[j] = row[col]
                end
            end
            # Fill missing V10 dims with defaults
            x[10] = hasproperty(row, :rotor_mask_proxy) ? row.rotor_mask_proxy : 8.0
            x[11] = hasproperty(row, :bank_top) ? row.bank_top : 15.0
            x[12] = hasproperty(row, :bank_bottom) ? row.bank_bottom : 5.0
            x[13] = hasproperty(row, :blade_scale_top) ? row.blade_scale_top :
                    (hasproperty(row, :lambda_top) ? row.lambda_top : 0.5)
            x[14] = hasproperty(row, :blade_scale_bottom) ? row.blade_scale_bottom :
                    (hasproperty(row, :lambda_bottom) ? row.lambda_bottom : 0.3)
            x[15] = 1.0  # log10(k=10) — reasonable default
            push!(members, x)
        end
    end
    
    return unique(members)[1:min(N_LEGACY, end)]
end

function evaluate_anchor_lhs(x::Vector{Float64}, p::SystemParams)
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    
    # V10 static fitness
    f_v10 = objective_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    
    # Single-k full protocol at λ²-prior (no bracket for LHS)
    result = design_from_vector_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    λ_eff = result.n_active > 0 ? result.rotors[1].blade_scale : 1.0
    k_prior = clamp(p.k_mppt * λ_eff^2, 0.01, 1000.0)
    
    f_v11 = objective_v11(x, PROFILE_ELLIPTICAL, p; spoke=spoke, k_mppt=k_prior)
    
    return (; f_v10=f_v10, f_v11=f_v11, k_best=k_prior,
             P_mean=NaN, FoS_min=NaN, ω_eq=NaN, P_range=NaN, drift=false)
end

function evaluate_anchor_legacy(x::Vector{Float64}, p::SystemParams)
    # Legacy fronts get the 3-point bracket
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    f_v10 = objective_v10(x[1:14], PROFILE_ELLIPTICAL, p)
    
    r, k_best = warmstart_with_k_bracket(x, PROFILE_ELLIPTICAL, p; spoke=spoke)
    f_v11 = r.fitness
    P_mean = r.P_mean
    FoS_min = r.FoS_min
    ω_eq = r.ω_eq
    P_range = r.P_range
    drift = r.drifted
    
    return (; f_v10=f_v10, f_v11=f_v11, k_best=k_best,
             P_mean=P_mean, FoS_min=FoS_min, ω_eq=ω_eq, P_range=P_range, drift=drift)
end

function main()
    mkpath(OUT_DIR)
    Random.seed!(42)
    
    p = params_v5_50kw()
    spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
    
    println("=== Phase 1c — Anchor Batch ===\n")
    
    # ── LHS samples ──────────────────────────────────────────────────────
    println("Generating $(N_ANCHORS_LHS) LHS samples...")
    lhs = generate_lhs_samples(p, N_ANCHORS_LHS)
    
    # ── Legacy front members ─────────────────────────────────────────────
    println("Collecting legacy front members...")
    legacy = collect_legacy_front_members()
    println("  $(length(legacy)) legacy members")
    
    all_samples = vcat([lhs[i, :] for i in 1:size(lhs, 1)], legacy)
    
    # ── Evaluate ─────────────────────────────────────────────────────────
    println("\nEvaluating $(length(all_samples)) anchors...")
    results = DataFrame(
        index = Int[],
        source = String[],
        # genome
        Do_top_m = Float64[], t_over_D = Float64[], beam_aspect = Float64[],
        Do_scale_exp = Float64[], r_hub_m = Float64[], r_bottom_m = Float64[],
        target_Lr = Float64[], n_lines = Float64[], density_profile = Float64[],
        rotor_mask = Float64[], bank_top = Float64[], bank_bottom = Float64[],
        lambda_top = Float64[], lambda_bottom = Float64[],
        log10_k = Float64[],
        # results
        f_v10 = Float64[], f_v11 = Float64[], k_best = Float64[],
        P_mean = Float64[], FoS_min = Float64[], omega_eq = Float64[],
        P_range = Float64[], drift = Bool[],
    )
    
    t0 = time()
    for (i, x) in enumerate(all_samples)
        src = i <= N_ANCHORS_LHS ? "lhs" : "legacy"
        if src == "lhs"
            r = evaluate_anchor_lhs(x, p)
        else
            r = evaluate_anchor_legacy(x, p)
        end
        
        push!(results, [
            i, src,
            x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9],
            x[10], x[11], x[12], x[13], x[14], x[15],
            r.f_v10, r.f_v11, r.k_best,
            r.P_mean, r.FoS_min, r.ω_eq, r.P_range, r.drift,
        ])
        
        elapsed = time() - t0
        eta = elapsed / i * (length(all_samples) - i) / 60
        @printf("  [%3d/%d] src=%-6s k=%.0f P=%.1f kW FoS=%.2f drift=%d  ETA: %.0f min\n",
                i, length(all_samples), src, r.k_best, r.P_mean, r.FoS_min, r.drift, eta)
        
        # Progressive save every 5 anchors
        if i % 5 == 0
            CSV.write(ANCHORS_CSV, results)
        end
    end
    
    CSV.write(ANCHORS_CSV, results)
    elapsed_total = time() - t0
    println("\nDone. $(length(all_samples)) anchors in $(round(elapsed_total/60, digits=1)) min")
    println("Results: $ANCHORS_CSV")
end

main()
