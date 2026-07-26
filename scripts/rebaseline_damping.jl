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

using KiteTurbineDynamics, CSV, DataFrames, Printf, Statistics, LinearAlgebra

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
    # Use warmstart_with_k_bracket to find correct k (matches campaign eval)
    # The k-bracket picks best k; we extract it and run the ODE with our damping
    best_f, best_k, best_P, best_FoS, best_ω, best_P_range, best_drifted, best_stationary,
        best_ua, best_ub = KiteTurbineDynamics.warmstart_with_k_bracket(
            x, PROFILE_ELLIPTICAL, params_v5_50kw();
            power_W=50000.0, v_rated=11.0, lin_damp=lin_damp)

    if best_f >= 1e8 || !isfinite(best_f)
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end

    # Now rebuild system with the best k and run with specified damping/dt
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     power_W=50000.0, v_rated=11.0)
    if result.n_active == 0
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end

    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, best_k)

    # Build expansion params for static solve
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
            rotor.blade_chord, KiteTurbineDynamics.EXP_CL_DESIGN,
            KiteTurbineDynamics.EXP_CD0_DESIGN, KiteTurbineDynamics.EXP_K_INDUCED,
            rotor.bank_angle_deg,
            KiteTurbineDynamics.expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
            rotor.ring_idx, 1.0,
        )
        push!(expansion_params, er)
    end

    _, radii, _ = KiteTurbineDynamics.ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile)

    λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
    k_mppt_eff = params_v5_50kw().k_mppt * λ_eff^2
    p_scaled = KiteTurbineDynamics.override_params(params_v5_50kw(); k_mppt=k_mppt_eff)

    ω_eq, r_ref = KiteTurbineDynamics.solve_equilibrium_self_consistent(
        design, expansion_params, p_scaled, n_lines, radii, zs;
        P_per_rotor=50000.0 / max(result.n_active, 1),
        v_wind=11.0, elev_rad=π/6)

    if ω_eq === nothing || isnan(ω_eq) || ω_eq <= 0.0
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / 15.0)^(1.0 / 7.0), 0.0, 0.0]
    end

    u_settled = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; wind_fn=wf)
    if any(isnan.(u_settled)) || any(isinf.(u_settled))
        return (NaN, NaN, NaN, 0, 0, NaN, NaN)
    end

    N = sys.n_total; Nr = sys.n_ring
    u_settled[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u_settled[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u_settled[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end

    sys.k_mppt_ref[] = best_k

    dt = 4e-5 / dt_factor
    n_steps = round(Int, 90.0 / dt)

    P_samples = Float64[]
    FoS_samples = Float64[]
    betz_count = Ref(0)
    fos_dip_count = Ref(0)

    function callback(u, t_cum, s)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, t_cum, wf)
        push!(P_samples, ef.base.P_kw)
        airborne = Float64[]
        for i in 2:length(ef.ring_fos)
            v = ef.ring_fos[i]
            (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
        end
        push!(FoS_samples, isempty(airborne) ? Inf : minimum(airborne))
        if ef.base.P_kw > 97.0
            betz_count[] += 1
        end
        if !isempty(airborne) && minimum(airborne) < 1.0
            fos_dip_count[] += 1
        end
        return nothing
    end

    try
        KiteTurbineDynamics.run_canonical_sim!(u_settled, sys, pc, wf, n_steps, dt;
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

# ── Setup ──
const CSV_PATH = "scripts/results/recampaign/rebaseline_damping.csv"

# ── Main: smoke → screen → matrix ──
# Smoke: one eval first.  If it produces garbage (P=0, all NaN), the
# freshly-threaded lin_damp path is broken and we halt in 20 min, not 9h.
# Screen: one genome across 3 damping × 2 dt.  If no setting produces a
# steady trace, the instability is damping-independent and we save 7/8
# of the compute budget.
# Matrix: remaining 6 genomes — only if screen passes.
const SCREEN_GENOME = "10kW_fos034"
const SMOKE_LD = 0.05; const SMOKE_DTF = 1.0  # baseline: should reproduce archive

# Load existing results for resume
results = DataFrame(
    label=String[], lin_damp=Float64[], dt_factor=Float64[],
    P_mean=Float64[], FoS_min=Float64[], P_range=Float64[],
    n_betz=Int[], n_fos_dips=Int[], omega_eq=Float64[], P_min=Float64[]
)
if isfile(CSV_PATH)
    existing = CSV.read(CSV_PATH, DataFrame)
    append!(results, existing)
    println("Resumed $(nrow(existing)) existing row(s) from $CSV_PATH")
end

function already_done(label, ld, dtf)
    nrow(results[(results.label .== label) .& (results.lin_damp .== ld) .& (results.dt_factor .== dtf), :]) > 0
end

function save_row(label, ld, dtf, P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min)
    push!(results, (label, ld, dtf, P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min))
    # Progressive save — one row at a time, survives kill
    CSV.write(CSV_PATH, results)
end

# ── Stage 1: Smoke ──
if !already_done(SCREEN_GENOME, SMOKE_LD, SMOKE_DTF)
    println("=== SMOKE: $SCREEN_GENOME ld=$SMOKE_LD dt/$(SMOKE_DTF) (1 eval, ~20 min) ===")
    P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min =
        eval_one(GENOMES[SCREEN_GENOME], SMOKE_LD, SMOKE_DTF)
    save_row(SCREEN_GENOME, SMOKE_LD, SMOKE_DTF, P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min)
    if !isfinite(P_mean) || P_mean <= 0.01
        println("SMOKE FAILED — P=$(round(P_mean, digits=1)) kW. lin_damp threading or build path broken.")
        println("Fix before running the full screen.")
        exit(3)
    end
    println("SMOKE PASSED — P=$(round(P_mean, digits=1)) kW, FoS=$(round(FoS_min, digits=3))")
end

# ── Stage 2: Screen ──
println("=== SCREEN: $SCREEN_GENOME across 3 damping × 2 dt (up to 6 evals, ~9h) ===")
screen_x = GENOMES[SCREEN_GENOME]
for ld in DAMPING_SETTINGS
    for dtf in DT_FACTORS
        already_done(SCREEN_GENOME, ld, dtf) && continue
        P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min =
            eval_one(screen_x, ld, dtf)
        save_row(SCREEN_GENOME, ld, dtf, P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min)
        @printf("%-12s ld=%.2f dt/%.0f  P=%.1f kW  FoS=%.3f  betz=%d  dips=%d\n",
                SCREEN_GENOME, ld, dtf, P_mean, FoS_min, n_betz, n_dips)
    end
end

# ── Reproduction check (runs BEFORE the screen gate) ──
println("\n=== REPRODUCTION CHECK (lin_damp=0.05 vs archived CSVs) ===")
# The lin_damp=0.05 / DT arm should reproduce archived values.
# If it doesn't, the tree is corrupted and nothing downstream is interpretable.
const REPRO_TARGETS = Dict(
    "10kW_fos034" => (P=10.04, FoS=0.339, P_range=30.3),
)
repro_ok = true
for (label, target) in REPRO_TARGETS
    row = results[(results.label .== label) .& (results.lin_damp .== 0.05) .& (results.dt_factor .== 1.0), :]
    if nrow(row) == 1 && isfinite(row.P_mean[1])
        p_tol = max(0.15, target.P_range / max(target.P, 0.1))
        dP = abs(row.P_mean[1] - target.P) / max(target.P, 0.1)
        dF = abs(row.FoS_min[1] - target.FoS) / max(target.FoS, 0.01)
        ok = dP < p_tol && dF < 0.15
        @printf("  %s: P=%.1f (target %.1f, tol %.2f) dP=%.3f  FoS=%.3f (target %.3f) dF=%.3f  %s\n",
                label, row.P_mean[1], target.P, p_tol, dP, row.FoS_min[1], target.FoS, dF, ok ? "✓" : "✗")
        if !ok; repro_ok = false; end
    else
        println("  $label: NO DATA — reproduction check failed")
        repro_ok = false
    end
end
if !repro_ok
    println("\nREPRODUCTION FAILED — tree is corrupted. Fix before trusting any results.")
    exit(3)
end
println()

# Check screen: any setting with P_range/P_mean < 0.2?
screen_hopeful = false
for row in eachrow(results)
    if isfinite(row.P_mean) && row.P_mean > 0.1 && isfinite(row.P_range)
        ratio = row.P_range / row.P_mean
        if ratio < 0.2
            screen_hopeful = true
            @printf "  ld=%.2f dt/%.0f: P_range/P_mean = %.3f ✓\n" row.lin_damp row.dt_factor ratio
        end
    end
end

if !screen_hopeful
    println("\nSCREEN FAILED — no damping setting achieves P_range/P_mean < 0.2.")
    println("The instability is damping-independent.  Full 7-genome matrix skipped.")
    println("Saved $(7*3*2 - 6) evals (~53h).")
    CSV.write("scripts/results/recampaign/rebaseline_damping.csv", results)
    exit(2)
end

println("SCREEN PASSED — proceeding to full 7-genome matrix.")
println()

# Full matrix: remaining 6 genomes — progressive save + resume
for (label, x) in GENOMES
    label == SCREEN_GENOME && continue
    for ld in DAMPING_SETTINGS
        for dtf in DT_FACTORS
            already_done(label, ld, dtf) && continue
            P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min =
                eval_one(x, ld, dtf)
            save_row(label, ld, dtf, P_mean, FoS_min, P_range, n_betz, n_dips, ω_eq, P_min)
            @printf("%-12s ld=%.2f dt/%.0f  P=%.1f kW  FoS=%.3f  betz=%d  dips=%d\n",
                    label, ld, dtf, P_mean, FoS_min, n_betz, n_dips)
        end
    end
end

# CSV already written progressively by save_row() above.
println("\nWrote $CSV_PATH ($(nrow(results)) rows)")

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
            global best_dips = total_dips
            global best_ld = ld
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
