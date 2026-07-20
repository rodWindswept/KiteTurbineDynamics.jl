#!/usr/bin/env julia
# scripts/run_anchor_batch.jl
#
# Phase 1c — anchor batch for multi-fidelity re-campaign.
# Generates ~50 design vectors via LHS over active dims (stratified per n_lines)
# plus ~10 legacy DE front members, evaluates each via warmstart_with_k_bracket,
# and saves progressive CSV with full provenance columns.
#
# GATE: do NOT launch until the warmstart regression test passes
#   (julia --project=. test/test_objective_v11.jl — "warmstart regression" testset).
#
# Plan ref: docs/plans/multifidelity_recampaign.md
#
# Columns in anchors.csv:
#   genome_hash, physics_era, git_hash,
#   x[1:15] (raw genome), n_lines, n_active,
#   f_v10, f_v11, P_mean_kw, FoS_min, omega_eq_rpm,
#   P_range_kw (noise weight for δ̂), drift_flag,
#   chosen_k, k_prior, k_bracket_results (JSON),
#   timestamp, anchor_source
#
# Resume: genome_hash in existing CSV → skip.  Progressive save after each anchor.

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics, SHA, JSON3, Dates, DataFrames, CSV, Random
import KiteTurbineDynamics: SpokeParams, PROFILE_ELLIPTICAL, params_v5_50kw,
    search_bounds_v11, warmstart_with_k_bracket, objective_v11_warmstart

const SP       = SpokeParams(enabled=false)
const BEAM     = PROFILE_ELLIPTICAL
const P_BASE   = params_v5_50kw()
const POWER_W  = 50000.0
const V_RATED  = 11.0
const ELEV     = π / 6

const OUT_DIR  = joinpath(@__DIR__, "results", "recampaign")
const OUT_CSV  = joinpath(OUT_DIR, "anchors.csv")

# ══════════════════════════════════════════════════════════════════════════════
# Provenance
# ══════════════════════════════════════════════════════════════════════════════
mkpath(OUT_DIR)

const GIT_HASH = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
const PHYSICS_ERA = "post-234a722_corrected-physics_ON"

# ══════════════════════════════════════════════════════════════════════════════
# LHS generator — simple Latin hypercube in [0,1]^d
# ══════════════════════════════════════════════════════════════════════════════

function latin_hypercube(n::Int, d::Int)
    """Generate n samples in d dimensions, each coordinate jittered within its stratum."""
    samples = zeros(n, d)
    for j in 1:d
        perm = randperm(n)
        for i in 1:n
            samples[i, j] = (perm[i] - 1.0 + rand()) / n
        end
    end
    return samples
end

# ══════════════════════════════════════════════════════════════════════════════
# Bounds — active dim subset with continuous scaling
# ══════════════════════════════════════════════════════════════════════════════

lo_full, hi_full = search_bounds_v11(P_BASE, BEAM; max_ground_radius=5.0)

# Active dim indices (1-based) for LHS stratification:
#   Rod directive: union of Phase 0 screened + physics-obvious dims.
#   Phase 0 top-6:  beam_aspect(3), Do_top(1), r_hub(5), t_over_D(2),
#                   Do_scale_exp(4), n_lines(8)
#   Physics-obvious: n_lines(8), λ_top(13), λ_bottom(14), r_hub(5), r_bottom(6)
#   Union: 1,2,3,4,5,6,8,13,14  (9 dims; n_lines is categorical → stratify)
#   Rod said "~7 dims" — ok for 60-100 LHS points.
const ACTIVE_DIMS = [1, 2, 3, 4, 5, 6, 13, 14]  # excludes n_lines (stratified)

# Default mid-range values for non-active dims (non-stratified)
function default_genome()
    x = zeros(15)
    # Use mid-range defaults for all dims; active dims will be overwritten
    for i in 1:15
        x[i] = (lo_full[i] + hi_full[i]) / 2.0
    end
    # Set sensible defaults for safety
    x[7]  = 2.5     # target_Lr — mid-range
    x[9]  = 0.0     # density_profile — uniform ring spacing
    x[10] = 5.0     # rotor_mask — modest 2-3 rotors
    x[11] = 15.0    # bank_top — 15° (mid)
    x[12] = 10.0    # bank_bottom — 10°
    x[15] = 1.0     # log10(k_mppt) → k=10 — modest default
    return x
end

# ══════════════════════════════════════════════════════════════════════════════
# LHS anchor generation — stratified per n_lines
# ══════════════════════════════════════════════════════════════════════════════

function generate_lhs_anchors(n_total::Int=40)
    """Generate LHS samples stratified across representative n_lines values."""
    # Stratify across key polygon counts
    n_lines_values = [3, 4, 6, 8, 12, 16]
    n_per = ceil(Int, n_total / length(n_lines_values))
    
    anchors = Vector{Float64}[]
    for nl in n_lines_values
        n_pts = min(n_per, n_total - length(anchors))
        n_pts <= 0 && break
        
        # Generate LHS in active-dims space (unit cube)
        lhs = latin_hypercube(n_pts, length(ACTIVE_DIMS))
        
        for row in 1:n_pts
            x = default_genome()
            x[8] = Float64(nl)  # n_lines
            for (k, dim) in enumerate(ACTIVE_DIMS)
                # Scale from [0,1] to [lo, hi]
                u = lhs[row, k]
                x[dim] = lo_full[dim] + u * (hi_full[dim] - lo_full[dim])
            end
            # Enforce r_bottom ≤ r_hub (taper constraint)
            if x[6] > x[5]
                # Swap: keep the LHS sampling but enforce physical ordering
                x[5], x[6] = x[6], x[5]  # smaller radius becomes r_bottom
            end
            push!(anchors, x)
        end
    end
    return anchors[1:min(n_total, length(anchors))]
end

# ══════════════════════════════════════════════════════════════════════════════
# Legacy DE front members
# ══════════════════════════════════════════════════════════════════════════════

function generate_legacy_anchors()
    """Hard-coded legacy designs that the DE will likely revisit."""
    legacy = Vector{Float64}[]
    
    # 1. V10 Tight campaign winner (12-gon, 4 rotors)
    #    From best_vector.csv, decoded via design_from_vector_v10
    vec_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_vector.csv")
    if isfile(vec_path)
        x_raw = parse.(Float64, split(readline(vec_path), ","))
        winner = zeros(15)
        winner[1:14] = x_raw[1:14]
        winner[15] = log10(166.0)   # k_mppt from dynamic verification (~166)
        push!(legacy, winner)
    end
    
    # 2. Phantom triangle (3-line, pre-fix system — Rod says this is a validated design now)
    tri = zeros(15)
    tri[1]=0.06; tri[2]=0.01; tri[3]=1.0; tri[4]=0.5; tri[5]=2.99
    tri[6]=2.0; tri[7]=2.99; tri[8]=3.0; tri[9]=-0.11; tri[10]=32.0
    tri[11]=25.0; tri[12]=4.0; tri[13]=1.0; tri[14]=0.88; tri[15]=log10(2.0)
    push!(legacy, tri)
    
    # 3. 12-gon reference design (from test/test_objective_v11.jl)
    x12 = zeros(15)
    x12[1]=0.075; x12[2]=0.01; x12[3]=1.0; x12[4]=0.5; x12[5]=3.7
    x12[6]=2.0; x12[7]=2.5; x12[8]=12.0; x12[9]=0.0; x12[10]=8.0
    x12[11]=15.0; x12[12]=5.0; x12[13]=0.5; x12[14]=0.3; x12[15]=1.0
    push!(legacy, x12)
    
    # 4. 6-gon variant
    x6 = copy(x12)
    x6[8] = 6.0
    x6[10] = 2.0  # different mask for fewer rings
    push!(legacy, x6)
    
    # 5. 8-gon variant
    x8 = copy(x12)
    x8[8] = 8.0
    push!(legacy, x8)
    
    # 6. Low-blade-scale variant
    x_low = copy(x12)
    x_low[13] = 0.2; x_low[14] = 0.15
    push!(legacy, x_low)
    
    # 7. High-blade-scale variant
    x_high = copy(x12)
    x_high[13] = 1.5; x_high[14] = 1.2
    push!(legacy, x_high)
    
    # 8. Small-radius variant
    x_small = copy(x12)
    x_small[5] = 1.5; x_small[6] = 0.8
    push!(legacy, x_small)
    
    # 9. Large-radius, low taper
    x_large = copy(x12)
    x_large[5] = 8.0; x_large[6] = 4.0
    push!(legacy, x_large)
    
    # 10. High bank angle
    x_bank = copy(x12)
    x_bank[11] = 25.0; x_bank[12] = 25.0
    push!(legacy, x_bank)
    
    return legacy
end

# ══════════════════════════════════════════════════════════════════════════════
# Genome hash — deterministic resume key
# ══════════════════════════════════════════════════════════════════════════════

function genome_hash(x::AbstractVector)
    """SHA256 of the genome vector truncated to 12 hex chars."""
    raw = join(string.(round.(x, digits=8)), ",")
    return bytes2hex(sha256(raw))[1:12]
end

# ══════════════════════════════════════════════════════════════════════════════
# Load existing CSV for resume
# ══════════════════════════════════════════════════════════════════════════════

function load_existing_hashes()
    hashes = Set{String}()
    isfile(OUT_CSV) || return hashes
    try
        df = CSV.read(OUT_CSV, DataFrame)
        if :genome_hash in names(df)
            for h in df.genome_hash
                push!(hashes, string(h))
            end
        end
        println("Resume: $(length(hashes)) existing anchors in $OUT_CSV")
    catch e
        println("Warning: could not read existing CSV: $e")
    end
    return hashes
end

# ══════════════════════════════════════════════════════════════════════════════
# CSV column schema
# ══════════════════════════════════════════════════════════════════════════════

const CSV_COLS = [
    :genome_hash, :physics_era, :git_hash,
    :x1, :x2, :x3, :x4, :x5, :x6, :x7, :x8, :x9, :x10,
    :x11, :x12, :x13, :x14, :x15,
    :n_lines, :n_active,
    :f_v10, :f_v11, :P_mean_kw, :FoS_min, :omega_eq_rpm,
    :P_range_kw, :drift_flag,
    :chosen_k, :k_prior, :k_bracket_results,
    :timestamp, :anchor_source,
]

# Seed for reproducible LHS (same seed = same anchors across runs)
Random.seed!(20260720)

function init_csv()
    if !isfile(OUT_CSV)
        df = DataFrame([(c == :k_bracket_results || c == :anchor_source || c == :physics_era || c == :git_hash || c == :genome_hash || c == :timestamp) ? String[] :
                         (c == :drift_flag) ? Bool[] : Float64[] for c in CSV_COLS], CSV_COLS)
        CSV.write(OUT_CSV, df)
        println("Initialised: $OUT_CSV")
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# Evaluate one anchor
# ══════════════════════════════════════════════════════════════════════════════

function evaluate_anchor(x::AbstractVector, source::String)
    """Evaluate one anchor: f_v10 (static) + f_v11 (warm-start with k-bracket)."""
    gh = genome_hash(x)
    
    # ── f_v10 (static solver) ──
    f_v10 = try
        objective_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED, elev_angle=ELEV)
    catch e
        @warn "f_v10 failed for $gh" exception=e
        1e9
    end
    
    # ── f_v11 warm-start with k-bracket ──
    result = try
        warmstart_with_k_bracket(x, BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED, spoke=SP)
    catch e
        @warn "warmstart failed for $gh" exception=e
        (1e9, 0.0, 0.0, Inf, 0.0, 0.0, true)
    end
    
    f_v11, k_chosen, P_mean, FoS_min, ω_eq, P_range, drift = result
    
    # ── Decode for metadata ──
    n_active = 0
    n_lines_decoded = 0
    try
        res = design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
        n_active = res.n_active
        n_lines_decoded = res.design.n_lines
    catch
    end
    
    # ── k_prior for context ──
    λ_eff = try
        r = design_from_vector_v10(x[1:14], BEAM, P_BASE; power_W=POWER_W, v_rated=V_RATED)
        r.n_active > 0 ? r.rotors[1].blade_scale : 1.0
    catch
        1.0
    end
    k_prior = P_BASE.k_mppt * λ_eff^2
    
    # ── k bracket results as JSON ──
    k_results = Dict{String,Any}("k_chosen" => k_chosen, "k_prior" => k_prior)
    
    # ── Build row ──
    row = Dict{Symbol,Any}(
        :genome_hash => gh,
        :physics_era => PHYSICS_ERA,
        :git_hash => GIT_HASH,
        :x1=>x[1], :x2=>x[2], :x3=>x[3], :x4=>x[4], :x5=>x[5],
        :x6=>x[6], :x7=>x[7], :x8=>x[8], :x9=>x[9], :x10=>x[10],
        :x11=>x[11], :x12=>x[12], :x13=>x[13], :x14=>x[14], :x15=>x[15],
        :n_lines => n_lines_decoded,
        :n_active => n_active,
        :f_v10 => f_v10,
        :f_v11 => f_v11,
        :P_mean_kw => P_mean,
        :FoS_min => FoS_min,
        :omega_eq_rpm => ω_eq * 60 / (2π),
        :P_range_kw => P_range,
        :drift_flag => drift,
        :chosen_k => k_chosen,
        :k_prior => k_prior,
        :k_bracket_results => JSON3.write(k_results),
        :timestamp => string(Dates.now()),
        :anchor_source => source,
    )
    return row
end

function append_csv(row::Dict)
    """Append a single row to the CSV immediately (progressive save)."""
    df = CSV.read(OUT_CSV, DataFrame)
    push!(df, row; cols=:union)
    # Sort by genome_hash for stable ordering
    sort!(df, :genome_hash)
    CSV.write(OUT_CSV, df)
    n = nrow(df)
    @printf("  ✓ saved %s  P=%.1f kW  FoS=%.2f  k=%.1f  (%d total)\n",
           row[:genome_hash], row[:P_mean_kw], row[:FoS_min], row[:chosen_k], n)
    flush(stdout)
end

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

function main()
    println("═══════════════════════════════════════════════")
    println("Anchor Batch — Phase 1c")
    println("git=$GIT_HASH  era=$PHYSICS_ERA")
    println("═══════════════════════════════════════════════")
    
    init_csv()
    existing = load_existing_hashes()
    
    # ── Generate anchors ──
    lhs_anchors = generate_lhs_anchors(40)
    legacy_anchors = generate_legacy_anchors()
    
    println("\nGenerated $(length(lhs_anchors)) LHS anchors + $(length(legacy_anchors)) legacy")
    
    all_anchors = vcat(lhs_anchors, legacy_anchors)
    
    # ── Filter for resume ──
    to_eval = [(x, i <= length(lhs_anchors) ? "LHS" : "legacy") 
               for (i, x) in enumerate(all_anchors)
               if !(genome_hash(x) in existing)]
    
    println("After resume filter: $(length(to_eval)) to evaluate ($(length(existing)) already done)\n")
    
    if isempty(to_eval)
        println("All anchors already evaluated. Done.")
        return
    end
    
    # ═══ GATE CHECK ═══════════════════════════════════════════════════════════
    println("╔══════════════════════════════════════════════════════════════╗")
    println("║  GATE: Regression test must pass before launching.          ║")
    println("║                                                            ║")
    println("║  Command:                                                   ║")
    println("║    julia --project=. test/test_objective_v11.jl             ║")
    println("║                                                            ║")
    println("║  Required: testset \"warmstart regression vs full protocol\"  ║")
    println("║            must PASS on BOTH reference designs.             ║")
    println("║                                                            ║")
    println("║  Fallback if regression fails:                              ║")
    println("║    Re-run with full protocol (~15 min/anchor)               ║")
    println("║    → ~50 anchors overnight instead of 100.                  ║")
    println("║                                                            ║")
    println("║  To launch (after gate passes):                             ║")
    println("║    SKIP_GATE=true julia --project=. scripts/run_anchor_batch.jl")
    println("╚══════════════════════════════════════════════════════════════╝")
    println()
    if !haskey(ENV, "SKIP_GATE")
        println("GATE ACTIVE — set SKIP_GATE=true to launch the batch.")
        println("Anchors ready: $(length(to_eval)) queued.")
        return
    end
    println("GATE BYPASSED — launching batch.")
    # ═══════════════════════════════════════════════════════════════════════════
    
    t_start = time()
    n_eval = length(to_eval)
    
    for (i, (x, source)) in enumerate(to_eval)
        gh = genome_hash(x)
        nl = round(Int, clamp(x[8], 3, 16))
        println("[$(i)/$(n_eval)] $(gh)  source=$(source)  n_lines=$(nl)")
        
        row = evaluate_anchor(x, source)
        append_csv(row)
        
        # Progress estimate
        elapsed = time() - t_start
        rate = i / elapsed
        remaining = (n_eval - i) / rate
        @printf("  progress: %d/%d  %.1f min elapsed  ~%.0f min remaining\n\n",
                i, n_eval, elapsed / 60, remaining / 60)
    end
    
    total_elapsed = time() - t_start
    println("═══════════════════════════════════════════════")
    @printf("Batch complete. %d anchors in %.1f min.\n", n_eval, total_elapsed / 60)
    println("Output: $OUT_CSV")
    println("═══════════════════════════════════════════════")
end

main()
