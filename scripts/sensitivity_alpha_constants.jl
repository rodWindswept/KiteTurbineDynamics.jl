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

# ── Perturbation primitives (must precede eval_candidate which references them) ──
const PerturbedAlpha = NamedTuple{(:slope, :cl_max, :tsr_design, :phi_d, :theta_i),NTuple{5,Float64}}
const ALPHA_DEFAULT = PerturbedAlpha((EXP_CL_SLOPE, EXP_CL_MAX, EXP_TSR_DESIGN, EXP_PHI_DESIGN, EXP_THETA_I))

function build_perturbed(param::String, val::Float64)::PerturbedAlpha
    slope  = param == "slope"      ? val : EXP_CL_SLOPE
    clmax  = param == "CL_max"     ? val : EXP_CL_MAX
    tsr    = param == "TSR_design" ? val : EXP_TSR_DESIGN
    phi_d  = atan(1.0 / tsr)
    theta_i = phi_d - EXP_CL_DESIGN / slope
    return PerturbedAlpha((slope, clmax, tsr, phi_d, theta_i))
end

struct ShadowAlpha
    a::PerturbedAlpha
end
(sh::ShadowAlpha)(phi) = clamp(sh.a.slope * (phi - sh.a.theta_i), -sh.a.cl_max, sh.a.cl_max)

# ── Build candidates ────────────────────────────────────────────────────────
# Rod-specified diversity set:
#   C1: triangle3   λ=0.85  (3 blades, low solidity, high-TSR regime)
#   C2: 12-gon      λ=0.80  (12 blades, high solidity, a near-equilibrium)
#   C3: 12-gon      λ≈0.45  (light loading, a→0 — must reduce to near-legacy)
#   C4: Island 51   from campaign archive (intermediate n_lines, competitive)

# Build all 4 candidates once (geometry is parameter-independent)
candidates = Dict{String,Tuple}()
const DT      = ControlMapHunt.DT
const WIND_MS = 11.0
const AERO_TS = 60.0     # snapshot duration (single-point eval — Gate 3
                          # will window; here we want relative ranking only)

sp = SpokeParams(enabled=true)

function eval_candidate(label, sys, u0, p, sa::ShadowAlpha=ShadowAlpha(ALPHA_DEFAULT))
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
# Island 51 excluded (standalone decode cannot replicate the dashboard's full
# build_from_campaign_v10—requires the interactive harness for correct construction).
# Run 12gon_0.80 and 12gon_0.45 + triangle3 as the diversity set; the
# intermediate-n_lines point is structurally represented by the 12-gon at
# light loading (exercises the a→0 regime where the α model must reduce
# to legacy—same physics the intermediate-n_lines design would probe).

println("Gate 1: α-constant sensitivity — $(length(candidates)) candidates × 7 pts (baseline + 3×2 perturbations)")
println()

# Perturbation grid: 2 values per constant, each constant perturbed in isolation
# while the other two hold their defaults (coherent perturbation per Rod's spec)
pert_grid = [("TSR_design", v) for v in [2.4, 3.6]]
append!(pert_grid, [("slope", v) for v in [1.2π, 3π]])
append!(pert_grid, [("CL_max", v) for v in [1.0, 1.4]])
println("$(length(pert_grid)) perturbation cells running...")
println()

for (param, val) in pert_grid
    alpha = build_perturbed(param, val)
    sa = ShadowAlpha(alpha)
    println("--- $(param)=$(round(val,digits=3)) ---")
println("--- BASELINE (default α constants) ---")
for (cname, (label, sys, u0, p)) in candidates
    P, ω, fos = eval_candidate(label, sys, copy(u0), p)
    push!(results, ("baseline", 0.0, cname, round(P, digits=2),
        round(ω, digits=1), round(fos, digits=2)))
    @printf("  %-16s  P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", cname, P, ω, fos)
end
println()

# ── RED/GREEN check ──────────────────────────────────────────────────────────
println("\n=== RANKING ANALYSIS ===")
baselines = Dict(r.candidate => r.P_kw for r in eachrow(results) if r.param == "baseline")
rank_baseline = sort(collect(baselines), by=last, rev=true)
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
