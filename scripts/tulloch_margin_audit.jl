#!/usr/bin/env julia --project=.
# tulloch_margin_audit.jl — compute Tulloch collapse margin for blowup designs
using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics

# --- helpers ---
function design_from_genome(x, p_base=params_v5_50kw())
    r = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=50000.0, v_rated=11.0)
    design = r.design
    n_lines = design.n_lines
    r_hub = design.r_hub
    r_bot = design.r_bottom
    tether = design.tether_length
    target_Lr = design.target_Lr
    # ring spacing: same logic as ring_spacing_v4
    zs, radii, n_rings = ring_spacing_v4(r_hub, r_bot, tether, target_Lr; max_rings=22)
    L_per_seg = tether / n_rings  # approximate per-segment length
    r_mean = (r_hub + r_bot) / 2.0
    return (; n_lines, r_hub, r_bot, tether, target_Lr, n_rings, L_per_seg, r_mean, design)
end

function tulloch_critical(r_mean, L)
    # δα* = 2·arcsin(L/√(2(L²+2r²)))  — the twist at which torque capacity vanishes
    denom = sqrt(2 * (L^2 + 2 * r_mean^2))
    arg = clamp(L / denom, 0.0, 1.0)
    return 2 * asin(arg)
end

function tulloch_torque_cap(n_lines, T_line, r_mean, L)
    # τ_cap = T_total × r² / √(L² + 2r²)  — max torque before collapse
    T_total = n_lines * T_line
    return T_total * r_mean^2 / sqrt(L^2 + 2 * r_mean^2)
end

function estimate_applied_twist(n_lines, k_chosen, omega_rad_s, r_mean, L)
    # τ = k·ω² applied to shaft
    # twist per segment δα ≈ τ / (GJ_eff) × L/n_rings
    # GJ_eff from line tension coupling: approximated from ring_forces τ(δα) model
    # Use simplified: applied torque → find δα that satisfies τ(δα) = k·ω²
    # τ(δα) = n_lines × T_line × r² × sin(δα) / √(L² + 4r² sin²(δα/2))
    # For T_line ~ tension per line, approximate from centrifugal loading
    # This is a quick audit — approximate T_line from ω² × mass
    return 0.0  # placeholder — need ODE state for actual twist
end

# --- load campaign data ---
csv_path = "scripts/results/recampaign/feasibility_phase_a_garbage.csv"
df = CSV.read(csv_path, DataFrame)

# Identify blowup rows: FoS > 1e6 or f < -0.99 or abs(P) > 1e6
df.is_blowup = (df.FoS_min .> 1e6) .| (df.f_feas .< -0.99) .| (abs.(df.P_mean_kw) .> 1e6)
blowups = df[df.is_blowup, :]
clean = df[.!df.is_blowup .&& (df.gen .> 0), :]  # exclude seeds

println("=== Blowup vs clean summary ===")
println("Total rows: $(nrow(df))")
println("Blowups: $(nrow(blowups)) ($(round(100*nrow(blowups)/nrow(df), digits=1))%)")
println("Clean (gen>0): $(nrow(clean))")
println()

# Decode a sample of blowup genomes and compute Tulloch margins
println("=== Tulloch collapse margin on blowup genomes ===")
println()

for (i, row) in enumerate(eachrow(first(blowups, 6)))
    x = [row.x1, row.x2, row.x3, row.x4, row.x5, row.x6, row.x7,
         row.x8, row.x9, row.x10, row.x11, row.x12, row.x13, row.x14, row.x15]
    n_lines_raw = row.n_lines
    k = row.k_chosen
    P = row.P_mean_kw
    FoS = row.FoS_min
    ω_rpm = row.omega_eq_rpm
    ω_rad = ω_rpm * π / 30.0
    
    try
        g = design_from_genome(x)
        δα_star = tulloch_critical(g.r_mean, g.L_per_seg)
        δα_star_deg = rad2deg(δα_star)
        
        # Applied torque = k·ω²
        τ_applied = k * ω_rad^2
        
        # Estimate T_line from simple tension model
        # T_line ≈ (k·ω²) / (n_lines × r_mean × sin(δ)) simplified
        # For audit: torque capacity at critical
        T_line_est = 500.0  # rough tension per line in N
        τ_cap = tulloch_torque_cap(g.n_lines, T_line_est, g.r_mean, g.L_per_seg)
        
        # Twist per segment from torque: solve τ_applied = τ(δα)
        # τ(δα) ≈ n_lines × T_line × r_mean² × sin(δα) / L_per_seg  (small-angle approx)
        # δα ≈ asin(τ_applied × L_per_seg / (n_lines × T_line × r_mean²))
        arg = clamp(τ_applied * g.L_per_seg / (g.n_lines * T_line_est * g.r_mean^2), 0.0, 1.0)
        δα_applied = asin(arg)
        δα_applied_deg = rad2deg(δα_applied)
        margin_deg = δα_star_deg - δα_applied_deg
        
        println("Blowup $(i): gen=$(row.gen) n_lines=$(g.n_lines) Do=$(round(row.x1, digits=3))m")
        println("  r_mean=$(round(g.r_mean,digits=2))m L/seg=$(round(g.L_per_seg,digits=2))m n_rings=$(g.n_rings)")
        println("  k=$(round(k,digits=1)) ω=$(round(ω_rpm,digits=0))rpm τ=$(round(τ_applied/1e3,digits=1))kNm")
        println("  δα*_crit=$(round(δα_star_deg,digits=1))°  δα_applied≈$(round(δα_applied_deg,digits=1))°  margin≈$(round(margin_deg,digits=1))°")
        println("  L/r=$(round(g.L_per_seg/g.r_mean,digits=2)) (wire-race max: 1.0)")
        println("  FoS=$(round(FoS,digits=3)) P=$(round(P,digits=1))kW")
        println()
    catch e
        println("Blowup $(i): decode failed — $(e)")
        println()
    end
end

# Compare L/r distribution: blowups vs clean
println("=== L/r ratio: blowups vs clean ===")
blowup_lr = Float64[]
clean_lr = Float64[]
for row in eachrow(blowups)
    x = [row.x1, row.x2, row.x3, row.x4, row.x5, row.x6, row.x7,
         row.x8, row.x9, row.x10, row.x11, row.x12, row.x13, row.x14, row.x15]
    try
        g = design_from_genome(x)
        push!(blowup_lr, g.L_per_seg / g.r_mean)
    catch; end
end
for row in eachrow(first(clean, min(30, nrow(clean))))
    x = [row.x1, row.x2, row.x3, row.x4, row.x5, row.x6, row.x7,
         row.x8, row.x9, row.x10, row.x11, row.x12, row.x13, row.x14, row.x15]
    try
        g = design_from_genome(x)
        push!(clean_lr, g.L_per_seg / g.r_mean)
    catch; end
end
println("Blowups L/r (n=$(length(blowup_lr))): mean=$(round(mean(blowup_lr),digits=2)) min=$(round(minimum(blowup_lr),digits=2)) max=$(round(maximum(blowup_lr),digits=2))")
println("Clean L/r (n=$(length(clean_lr))):   mean=$(round(mean(clean_lr),digits=2)) min=$(round(minimum(clean_lr),digits=2)) max=$(round(maximum(clean_lr),digits=2))")
println("Tulloch wire-race threshold: L/r ≈ 1.0 (lines cross at δα*)")
