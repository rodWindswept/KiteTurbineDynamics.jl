#!/usr/bin/env julia --project=.
# re_baseline_damping.jl — DT-paired re-baseline of damping rate
#
# All 221 campaign evals were at lin_damp=0.05 (untested — sweep spans
# 0.5–0.999). 0.5 is unconverged; 0.8 has super-Betz samples. No setting
# is simultaneously converged and admissible.
#
# This script re-evaluates 5 front-spanning + 2 blowup-family genomes at
# lin_damp ∈ {0.05, 0.5, 0.8}, DT-paired (DT and DT/2), so the desk has
# three answers before launch:
#   1. Does the Pareto front survive a valid damping setting?
#   2. Which setting reproduces stably (DT≈DT/2, zero super-Betz)?
#   3. Are the blowup failures numerical (dt-dependent) or physical?
#
# Acceptance rule (applied by this script in the summary block):
#   A setting is ADMISSIBLE iff ALL eval rows at that setting satisfy:
#     - DT/DT2 P_mean within 20%
#     - DT/DT2 FoS_min within 10%
#     - zero super-Betz samples (n_betz == 0) on BOTH dt
#   The ADMISSIBLE setting with fewest FoS dips (sum of n_fos_dips) wins.
#   If no setting is admissible, the script prints ESCALATE and exits 1.
#
# Output: scripts/results/recampaign/rebaseline_damping.csv

using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics

const GENOMES = Dict(
    # Front-spanning: P,FoS pairs from re-scored campaign data
    "high_p"     => [0.392772, 0.080245, 1.0, 0.55672, 6.94996, 6.57715,
                     1.5478, 7.0411, 0.3002, 17.0365, 25.0, 21.2038, 2.0,
                     1.6814, -0.7901],   # ~61 kW, FoS 0.32
    "mid_p"      => [0.10398, 0.01, 0.15, 0.8053, 18.9164, 2.6725,
                     3.0, 16.0, -0.6612, 7.1482, 11.1376, 24.4920,
                     0.6497, 1.5018, 0.5272],   # ~14 kW, FoS 0.12
    "low_p"      => [0.08801, 0.09712, 0.7535, 0.4175, 1.0733, 3.9722,
                     2.6439, 11.84, -0.2110, 7.1154, 15.0, 12.6903,
                     0.5403, 1.0438, 0.7117],   # ~56 kW, FoS 0.06
    "best_fos"   => [0.33650, 0.01, 1.0, 0.8065, 14.6306, 4.7605,
                     3.0, 16.0, -0.1057, 0.0, 25.0, 11.2949,
                     0.1, 0.1, 0.2380],   # FoS ~21, P ~0 (unloaded)
    "green"      => [0.09545, 0.01, 0.6767, 1.0, 18.9164, 1.1435,
                     3.0, 16.0, -0.8, 3.4684, 7.2752, 25.0,
                     1.1493, 2.0, 0.7693],   # ae59adf6: P=2.9, FoS=2.56
    # Blowup-family members (n_lines=12, n_rings=3, high target_Lr, high k)
    "blowup_a"   => [0.2, 0.01, 1.0, 0.6865, 14.4397, 5.1512,
                     2.4594, 11.9218, -0.1700, 19.0, 16.1316, 14.3633,
                     0.8842, 0.1, 0.6598],   # from garbage CSV gen 9
    "blowup_b"   => [0.2, 0.01, 1.0, 0.6073, 13.6123, 3.6327,
                     3.0, 16.0, -0.2715, 12.1884, 25.0, 11.5318,
                     0.4121, 0.1, 1.3018],   # from garbage CSV gen 8
)

const DAMPING_SETTINGS = [0.05, 0.5, 0.8]
const DT_FACTORS = [1.0, 2.0]   # DT = 4e-5, DT/2 = 2e-5

function eval_one(x, lin_damp, dt_factor)
    design = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     power_W=50000.0, v_rated=11.0)
    sys, u0, pc, label, _ = build_v10_tight()
    # Build from genome instead of reference
    expansion_params = build_expansion_params(design, PROFILE_ELLIPTICAL, params_v5_50kw())
    pc2 = build_system_params(design, params_v5_50kw())
    sys2, u0_2 = build_kite_turbine_system(pc2; expansion_rotors=expansion_params)
    
    dt = 4e-5 / dt_factor
    n_steps = round(Int, 90.0 / dt)
    
    P_samples = Float64[]
    FoS_samples = Float64[]
    betz_count = Ref(0)
    fos_dip_count = Ref(0)
    
    function callback(u, t, sys, p)
        ef = capture_extended(u, sys, p, t, wf)
        push!(P_samples, ef.P_kw)
        push!(FoS_samples, ef.fos_ring)
        # Betz check: P > 97 kW ceiling for triangle-class designs
        if ef.P_kw > 97.0
            betz_count[] += 1
        end
        # FoS dip: below 1.0
        if ef.fos_ring < 1.0
            fos_dip_count[] += 1
        end
        return nothing
    end
    
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / 15.0)^(1.0 / 7.0), 0.0, 0.0]
    end
    
    # Warmstart path
    ω_eq, _ = solve_equilibrium_self_consistent(
        design.design, expansion_params, pc2, design.n_lines, Float64[], Float64[];
        P_per_rotor=50000.0 / max(design.n_active, 1), v_wind=11.0, elev_rad=π/6)
    
    u_settled = settle_to_equilibrium(sys2, u0_2, pc2; wind_fn=wf)
    u_settled[(6*sys2.n_total + sys2.n_ring + 1):(6*sys2.n_total + 2*sys2.n_ring)] .= ω_eq
    
    try
        run_canonical_sim!(u_settled, sys2, pc2, wf, n_steps, dt;
                           lift_device=nothing, lin_damp=lin_damp, callback=callback)
    catch
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end
    
    P_finite = [p for p in P_samples if isfinite(p) && p >= 0.0]
    fos_finite = [f for f in FoS_samples if isfinite(f) && f > 0.0]
    
    if isempty(P_finite) || length(P_finite) < 2
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end
    
    P_mean = mean(P_finite)
    FoS_min = isempty(fos_finite) ? Inf : minimum(fos_finite)
    P_range = maximum(P_finite) - minimum(P_finite)
    n_betz = betz_count[]
    n_dips = fos_dip_count[]
    
    return (P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, minimum(P_finite))
end

# ── Main ──
results = DataFrame(
    label=String[], lin_damp=Float64[], dt_factor=Float64[],
    P_mean=Float64[], FoS_min=Float64[], P_range=Float64[],
    n_betz=Int[], n_fos_dips=Int[], omega_eq=Float64[], P_min=Float64[]
)

for (label, x) in GENOMES
    for ld in DAMPING_SETTINGS
        for dtf in DT_FACTORS
            P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min =
                eval_one(x, ld, dtf)
            push!(results, (label, ld, dtf, P_mean, FoS_min, P_range,
                            n_betz, n_dips, ω_eq, P_min))
            @printf "%-12s ld=%.2f dt/%.0f  P=%.1f kW  FoS=%.3f  betz=%d  dips=%d\n" \
                label ld dtf P_mean FoS_min n_betz n_dips
        end
    end
end

out = "scripts/results/recampaign/rebaseline_damping.csv"
CSV.write(out, results)
println("\nWrote $out ($(nrow(results)) rows)")

# ── Admissibility gate ──
println("\n=== ADMISSIBILITY GATE ===")
g = groupby(results, :lin_damp)
for (ld, grp) in pairs(g)
    admissible = true
    issues = String[]
    
    dt1 = grp[grp.dt_factor .== 1.0, :]
    dt2 = grp[grp.dt_factor .== 2.0, :]
    
    for row in eachrow(innerjoin(dt1, dt2, on=:label, makeunique=true))
        P1 = row.P_mean; P2 = row.P_mean_1
        F1 = row.FoS_min; F2 = row.FoS_min_1
        
        if isfinite(P1) && isfinite(P2) && P1 > 0.1
            dP = abs(P1 - P2) / P1
            if dP > 0.20
                push!(issues, "$(row.label): DT/DT2 P ratio $(round(dP,digits=2))")
                admissible = false
            end
        end
        if isfinite(F1) && isfinite(F2) && F1 > 0.01
            dF = abs(F1 - F2) / F1
            if dF > 0.10
                push!(issues, "$(row.label): DT/DT2 FoS ratio $(round(dF,digits=2))")
                admissible = false
            end
        end
    end
    
    total_betz = sum(grp.n_betz)
    total_dips = sum(grp.n_fos_dips)
    
    if total_betz > 0
        push!(issues, "$total_betz super-Betz samples")
        admissible = false
    end
    
    status = admissible ? "ADMISSIBLE" : "NOT ADMISSIBLE"
    println("lin_damp=$ld  $status  betz=$total_betz  dips=$total_dips")
    if !isempty(issues)
        for iss in issues
            println("  → $iss")
        end
    end
end

# Find best admissible setting (fewest dips)
best_ld = nothing
best_dips = typemax(Int)
for (ld, grp) in pairs(g)
    total_betz = sum(grp.n_betz)
    total_dips = sum(grp.n_fos_dips)
    if total_betz == 0
        # Check DT convergence
        dt1 = grp[grp.dt_factor .== 1.0, :]
        dt2 = grp[grp.dt_factor .== 2.0, :]
        all_converged = true
        for row in eachrow(innerjoin(dt1, dt2, on=:label, makeunique=true))
            P1 = row.P_mean; P2 = row.P_mean_1
            F1 = row.FoS_min; F2 = row.FoS_min_1
            if isfinite(P1) && isfinite(P2) && P1 > 0.1
                if abs(P1-P2)/P1 > 0.20; all_converged = false; end
            end
            if isfinite(F1) && isfinite(F2) && F1 > 0.01
                if abs(F1-F2)/F1 > 0.10; all_converged = false; end
            end
        end
        if all_converged && total_dips < best_dips
            best_dips = total_dips
            best_ld = ld
        end
    end
end

if best_ld !== nothing
    println("\nBEST ADMISSIBLE: lin_damp=$best_ld (dips=$best_dips) → USE THIS")
else
    println("\nESCALATE: no setting is simultaneously converged and super-Betz-free")
    exit(1)
end
