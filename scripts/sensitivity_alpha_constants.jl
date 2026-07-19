#!/usr/bin/env julia
# scripts/sensitivity_alpha_constants.jl
# Gate 1: α-constant sensitivity — 4 candidates × 7 perturbations.
# RED criterion (Rod, 2026-07-18): any first-rank flip OR any pairwise
# ordering reversal = RED → constants need calibration before re-campaign.
# If GREEN: ranking is stable under constant uncertainty — proceed.

using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames, Statistics
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))
import KiteTurbineDynamics: SpokeParams, ExpansionPhysics,
    set_expansion_physics!, expansion_physics,
    EXP_CL_SLOPE, EXP_CL_MAX, EXP_TSR_DESIGN, EXP_THETA_I, EXP_PHI_DESIGN

# ── Build candidates ────────────────────────────────────────────────────────
# Rod-specified diversity set:
#   C1: triangle3   λ=0.85  (3 blades, low solidity, high-TSR regime)
#   C2: 12-gon      λ=0.80  (12 blades, high solidity, a near-equilibrium)
#   C3: 12-gon      λ≈0.45  (light loading, a→0 — must reduce to near-legacy)
#   C4: Island 51   from campaign archive (intermediate n_lines, competitive)

function build_c4()
    # Island 51: decode best_vector_island51.csv via the v10 design pipeline,
    # then build with build_kite_turbine_system_v5 (the same backend the
    # dashboard's build_from_campaign_v10 ultimately calls).
    fn = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_vector_island51.csv")
    x_raw = parse.(Float64, split(readline(fn), ","))
    x = copy(x_raw)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(KiteTurbineDynamics.N_VALID_MASKS))
    result = KiteTurbineDynamics.design_from_vector_v10(x, KiteTurbineDynamics.PROFILE_ELLIPTICAL,
        KiteTurbineDynamics.params_v5_50kw(); max_ground_radius=5.0, power_W=50000.0)
    design = result.design
    rotors = result.rotors
    # Build expansion rotor params with ring-index remapping (dashboard convention)
    n_rings = result.n_rings
    n_lines = design.n_lines
    expansion_params = KiteTurbineDynamics.ExpansionRotorParams[]
    for rotor in rotors
        i = rotor.ring_idx
        sys_ring_idx = i == n_rings ? n_rings + 2 : i + 1
        push!(expansion_params, KiteTurbineDynamics.ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            1.0, 0.02, 0.05, rotor.bank_angle_deg,
            0.5, sys_ring_idx, 1.0))
    end
    # Build system params with campaign geometry via GeometrySpec (dashboard convention:
    # design.r_hub → p.trpt_hub_radius; then build_kite_turbine_system reads it for ring spacing)
    geo = KiteTurbineDynamics.GeometrySpec(
        KiteTurbineDynamics.params_v5_50kw().elevation_angle,
        KiteTurbineDynamics.params_v5_50kw().lifter_elevation,
        5.0,  # rotor_radius — overwritten by hub disk dynamics
        design.tether_length, design.r_hub,
        KiteTurbineDynamics.params_v5_50kw().trpt_rL_ratio,
        n_lines, n_rings, n_lines)
    mat = KiteTurbineDynamics.MaterialSpec(0.008, 50e9, 0.5, 0.5)
    aero = KiteTurbineDynamics.AeroSpec(1.225, 11.0, 47.6, 1.0)
    ctrl = KiteTurbineDynamics.ControlSpec(1.0, 2.0, 50_000.0, 0.0, 45.0, 5.0, 0.5)
    back = KiteTurbineDynamics.BackLineSpec(1e6, 100.0, 5.0, 0.1)
    p = KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p; expansion_rotors=expansion_params)
    return sys, u0, p, "Island 51"
end

const DT      = ControlMapHunt.DT
const WIND_MS = 11.0
const AERO_TS = 60.0     # snapshot duration (single-point eval — Gate 3
                          # will window; here we want relative ranking only)

sp = SpokeParams(enabled=true)

function eval_candidate(label, sys, u0, p)
    sys.k_mppt_ref[] = 2.0   # fixed representative k; sensitivity to constants
                              # must be measured at consistent control.
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    u = settle_to_operational_state(sys, copy(u0), p, 60.0; wind_fn=wf)
    n = round(Int, AERO_TS / DT)
    out = Ref((0.0, 0.0, Inf))
    run_canonical_sim!(u, sys, p, wf, n, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(uc, tc, s) -> begin
            if s == n
                ef = capture_extended(uc, sys, p, tc, wf, nothing;
                    brake_engaged=sys.brake_engaged[])
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v)&&!isinf(v)&&v>0) && push!(airborne, v)
                end
                out[] = (ef.base.P_kw, ef.base.omega_hub*60/(2π),
                         isempty(airborne) ? Inf : minimum(airborne))
            end
        end)
    return out[]
end

# ── Perturbations ────────────────────────────────────────────────────────────
const PERTURBATIONS = Dict{String,Vector{Float64}}(
    "TSR_design" => [2.4, 3.6],
    "slope"      => [1.2π, 3π],
    "CL_max"     => [1.0, 1.4],
)

# ── Run ──────────────────────────────────────────────────────────────────────
set_expansion_physics!(ExpansionPhysics(true, true, true))
OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "sensitivity_alpha_constants.csv")
mkpath(dirname(OUT_CSV))

results = DataFrame(param=String[], value=Float64[], candidate=String[], P_kw=Float64[],
    omega_rpm=Float64[], min_fos=Float64[])

# Build all 4 candidates once (geometry is parameter-independent)
candidates = Dict{String,Tuple}()
sys1, u0_1, p1, lbl1 = build_phantom_triangle(blade_scale=0.85)
candidates["triangle3_0.85"] = (lbl1, sys1, u0_1, p1)
sys2, u0_2, p2, lbl2 = build_v10_tight_no_lowest(blade_scale=0.80)
candidates["12gon_0.80"] = (lbl2, sys2, u0_2, p2)
sys3, u0_3, p3, lbl3 = build_v10_tight_no_lowest(blade_scale=0.45)
candidates["12gon_0.45"] = ("12gon_0.45", sys3, u0_3, p3)
candidates["island51"] = ("Island 51", build_c4()...)

println("Gate 1: α-constant sensitivity — $(length(candidates)) candidates × $(1+sum(length(v) for v in values(PERTURBATIONS))) pts")
println()

# Baseline: default α constants
println("--- BASELINE (default α constants) ---")
for (cname, (label, sys, u0, p)) in candidates
    P, ω, fos = eval_candidate(label, sys, copy(u0), p)
    push!(results, ("baseline", 0.0, cname, round(P, digits=2),
        round(ω, digits=1), round(fos, digits=2)))
    @printf("  %-16s  P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", cname, P, ω, fos)
end
println()

for (param, vals) in PERTURBATIONS, val in vals
    # Re-derive θ_i from the perturbed constant + clamped defaults for others
    tsr  = param == "TSR_design" ? val : EXP_TSR_DESIGN
    slope = param == "slope" ? val : EXP_CL_SLOPE
    clmax = param == "CL_max" ? val : EXP_CL_MAX
    phi_d = atan(1.0 / tsr)
    theta_i = phi_d - EXP_CL_DESIGN / slope

    # Bypass const-ness via eval (sensitivity gate is a one-off analysis script;
    # production code should keep the consts — this path is temporary)
    @eval KiteTurbineDynamics EXP_CL_SLOPE   = $slope
    @eval KiteTurbineDynamics EXP_CL_MAX     = $clmax
    @eval KiteTurbineDynamics EXP_TSR_DESIGN = $tsr
    @eval KiteTurbineDynamics EXP_PHI_DESIGN = $phi_d
    @eval KiteTurbineDynamics EXP_THETA_I    = $theta_i

    println("--- $(param)=$(round(val,digits=3)) ---")
    for (cname, (label, sys, u0, p)) in candidates
        P, ω, fos = eval_candidate(label, sys, copy(u0), p)
        push!(results, (; param, val, candidate=cname,
            P_kw=round(P, digits=2), omega_rpm=round(ω, digits=1),
            min_fos=round(fos, digits=2)))
        @printf("  %-16s  P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", cname, P, ω, fos)
    end
end

# ── RED/GREEN check ──────────────────────────────────────────────────────────
println("\n=== RANKING ANALYSIS ===")
baselines = Dict(r.candidate => r.P_kw for r in eachrow(results) if r.param == "baseline")
rank_baseline = sort(collect(baselines), by=last, rev=true)  # descending power
println("Baseline ranking (P_kw):")
for (i, (c, p)) in enumerate(rank_baseline)
    println("  $i. $c = $p kW")
end

red = false
for grp in groupby(results[results.param .!= "", :], [:param, :value])
    vals = Dict(r.candidate => r.P_kw for r in eachrow(grp))
    rank = sort(collect(vals), by=last, rev=true)
    # First-rank flip
    if rank[1][1] != rank_baseline[1][1]
        println("RED: first-rank flip under $(grp[1,:param])=$(grp[1,:value]) → $(rank[1][1])")
        red = true
    end
    # Pairwise reversal
    bl = Dict(c => i for (i, (c, _)) in enumerate(rank_baseline))
    for i in 1:length(rank)-1, j in i+1:length(rank)
        c_i, c_j = rank[i][1], rank[j][1]
        if bl[c_i] > bl[c_j]  # order reversed vs baseline
            println("RED: reversal $(c_j) ↕ $(c_i) under $(grp[1,:param])=$(grp[1,:value])")
            red = true
        end
    end
end

if !red
    println("\nGATE 1: GREEN — ranking stable under all perturbations.")
    println("Proceed to re-campaign without further constant calibration.")
else
    println("\nGATE 1: RED — constants need calibration before re-campaign.")
    println("Tulloch benchmarks / AeroDyn collaboration critical path.")
end

CSV.write(OUT_CSV, results)
println("\nResults: $OUT_CSV")
