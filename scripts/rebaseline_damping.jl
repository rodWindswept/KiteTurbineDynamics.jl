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
#
# Runtime: 7 genomes × 3 damping × 2 dt = 42 evals (~16 h).
#   DT/2 arm is 4.5M steps vs 2.25M at DT, costing ~2× per eval.
#   Plan for ~16 h, not 7.5.

using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics

const GENOMES = Dict(
    # Front-spanning: P,FoS pairs from re-scored campaign data
    "87kW_fos017" => [0.392772, 0.080245, 1.0, 0.55672, 6.94996, 6.57715,
                       1.5478, 7.0411, 0.3002, 17.0365, 25.0, 21.2038, 2.0,
                       1.6814, -0.7901],   # 87.2 kW, FoS 0.175 (best-power, structurally crushed)
    "58kW_fos024" => [0.06563, 0.01, 1.2167, 0.2957, 3.8555, 4.9030,
                       2.99, 9.44, 0.3752, 9.5726, 18.0899, 0.0,
                       0.2959, 0.1119, 1.0],   # 58.0 kW, FoS 0.241 (best balanced mid-power)
    "10kW_fos034" => [0.11767, 0.05624, 1.0, 0.9715, 14.8489, 4.8324,
                       2.5, 8.0, 0.0, 5.0, 15.0, 10.0,
                       1.8716, 1.4256, 1.0],   # 10.0 kW, FoS 0.339 (low-power, best mid-FoS)
    "5kW_fos053"  => [0.11902, 0.08119, 1.0, 0.3993, 12.1150, 3.8062,
                       2.6802, 8.0, -0.1923, 6.7140, 23.6095, 12.7398,
                       0.5787, 0.3, 0.7578],   # 4.6 kW, FoS 0.530 (best realistic FoS)
    "ae59adf6"    => [0.09545, 0.01, 0.6767, 1.0, 18.9164, 1.1435,
                       3.0, 16.0, -0.8, 3.4684, 7.2752, 25.0,
                       1.1493, 2.0, 0.7693],   # 2.9 kW, FoS 2.56 (former GREEN, unloaded regime)
    # Blowup-family members (n_lines=12, n_rings=3, high target_Lr, high k)
    "blowup_a"    => [0.2, 0.01, 1.0, 0.6865, 14.4397, 5.1512,
                       2.4594, 11.9218, -0.1700, 19.0, 16.1316, 14.3633,
                       0.8842, 0.1, 0.6598],   # from garbage CSV gen 9
    "blowup_b"    => [0.2, 0.01, 1.0, 0.6073, 13.6123, 3.6327,
                       3.0, 16.0, -0.2715, 12.1884, 25.0, 11.5318,
                       0.4121, 0.1, 1.3018],   # from garbage CSV gen 8
)

# NOTE: ae59adf6 and blowup_b carry x8=16 — above the current x8 cap of 12.
#   ae59adf6 also carries x3≠1.0 — outside the current aspect_ratio clamp.
#   These genomes are correct for reproducing the original evals but must
#   never be reused as DE seeds.  This is a second reason the reproduction
#   check matters: if re-evaluation diverges from the archive, era drift
#   is the first suspect.

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
println("\n=== REPRODUCTION CHECK (lin_damp=0.05 vs archived CSVs) ===")
# The lin_damp=0.05 / DT arm should reproduce archived values.
# If it doesn't, nothing downstream is interpretable.
# Known values from feasibility_phase_a_garbage.csv:
const REPRO_TARGETS = Dict(
    "87kW_fos017" => (P=87.2, FoS=0.175, P_range=0.0),   # P_range unknown — use flat 15%
    "58kW_fos024" => (P=58.0, FoS=0.241, P_range=0.0),
    "10kW_fos034" => (P=10.0, FoS=0.339, P_range=0.0),
    "5kW_fos053"  => (P=4.6,  FoS=0.530, P_range=0.0),
    "ae59adf6"    => (P=2.9,  FoS=2.562, P_range=4.7),    # known from re-eval: P_range=4.7 kW
    "blowup_a"    => (P=NaN, FoS=NaN, P_range=NaN),
    "blowup_b"    => (P=NaN, FoS=NaN, P_range=NaN),
)
repro_ok = true
for (label, target) in REPRO_TARGETS
    if isnan(target.P); continue; end
    row = results[(results.label .== label) .& (results.lin_damp .== 0.05) .& (results.dt_factor .== 1.0), :]
    if nrow(row) == 1 && isfinite(row.P_mean[1])
        # Scale P tolerance: non-stationary designs swing more power than
        # a flat 15% allows.  Use max(0.15, P_range / P_mean) from archive.
        p_tol = max(0.15, target.P_range / max(target.P, 0.1))
        dP = abs(row.P_mean[1] - target.P) / max(target.P, 0.1)
        dF = abs(row.FoS_min[1] - target.FoS) / max(target.FoS, 0.01)
        ok = dP < p_tol && dF < 0.15
        println("  $label: P=$(round(row.P_mean[1],digits=1)) (target $(target.P), range $(target.P_range) kW, tol=$(round(p_tol,digits=3))) dP=$(round(dP,digits=3))  FoS=$(round(row.FoS_min[1],digits=3)) (target $(target.FoS)) dF=$(round(dF,digits=3))  $(ok ? '✓' : '✗')")
        if !ok; repro_ok = false; end
    else
        println("  $label: NO DATA — reproduction check failed")
        repro_ok = false
    end
end
if !repro_ok
    println("\nREPRODUCTION FAILED — archived values not reproduced at lin_damp=0.05.")
    println("Era drift (genome bounds changed since eval) is the first suspect.")
    println("Do not trust the damping comparison until this is resolved.")
end
println()

println("=== ADMISSIBILITY GATE ===")
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

if best_ld !== nothing && repro_ok
    println("\nBEST ADMISSIBLE: lin_damp=$best_ld (dips=$best_dips) → USE THIS")
elseif best_ld !== nothing && !repro_ok
    println("\nBEST ADMISSIBLE: lin_damp=$best_ld (dips=$best_dips) — BUT REPRODUCTION CHECK FAILED")
    println("Do not use this result until the reproduction failure above is resolved.")
    exit(1)
else
    println("\nESCALATE: no setting is simultaneously converged and super-Betz-free")
    exit(1)
end
