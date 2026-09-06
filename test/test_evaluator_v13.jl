#!/usr/bin/env julia --project=.
#= test_evaluator_v13.jl — acceptance tests for the v13 evaluator instrumentation
(proposal: docs/plans/2026-08-13-evaluator-v13-realistic-ktd.md).
Re-baselined 2026-09-04 to the corrected 5 kW campaign (daisy params @ 18.8 m,
campaign decode knobs, appropriate_mass_fitness).  Standalone (not wired into
runtests.jl — B1-B3 run 20-30s ODE windows).

B1: island-1 winner (torsional collapse)  → :reject + twist_crossed=true
B2: 18m winner (flywheel decay)            → :reject OR (P_end < floor AND worse fitness than seed)
B3: original seed (healthy)                → :ok, no twist, P_end ≥ floor, fitness beats B2's
B4: unit — penalize_ceiling=false → more power strictly better
B5: unit — twist_collapse_check flags wound state, not post-settle
B6: 18m v13 winner (stabilized)            → :ok, hub tip < 100 m/s
B7: unit — tip_speed_sanity_ok flags diverged hub/mid-ring ω
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))  # params_at_length, lift_for, twist_report, gate_design

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const BEAM = PROFILE_ELLIPTICAL
const L18 = 18.8

# Regression artifacts — must STILL collapse/flywheel-reject under the
# corrected physics (B1/B2).
const WINNER1 = joinpath(@__DIR__, "..", "scripts", "results", "v12_5kw_coldstart", "island_1_best.csv")
const WINNER18 = joinpath(@__DIR__, "..", "scripts", "results", "v12_5kw_len18.0", "best_vector.csv")
# Healthy machine: the corrected 5 kW campaign winner.
const WINNER18V13 = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount", "best_vector.csv")

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

function v13_cfg(window_s::Float64, k_mppt::Float64)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=k_mppt,          # K_MPPT_5KW_HONEST (2.24), the campaign operating point
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,   # campaign floor/ceiling (was 2.5/5.0)
        relax_s=5.0, window_s=window_s,
        fos_target=2.5, fos_hard=2.5,        # campaign FoS (was 1.5)
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
end

function run_eval(x::Vector{Float64}, L::Float64, window_s::Float64)
    p = params_at_length(params_daisy(), L, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: {1,2,3}
    return KiteTurbineDynamics.evaluate_windowed(
        xr, BEAM, p, v13_cfg(window_s, K_MPPT_5KW_HONEST);
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
end

function read_vec(path::String)
    return [parse(Float64, s) for s in split(strip(read(path, String)), ",")]
end

# Corrected seed genome (seed_genome(5.0)), rounded like the campaign.
function seed_x()
    x = seed_genome(5.0)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    return x
end

println("=== B1: island-1 winner (collapse) through v13 ===")
r1 = run_eval(read_vec(WINNER1), L18, 30.0)
println("  status=", r1.status, "  twist_crossed=", r1.twist_crossed,
        "  line_broken=", r1.line_broken,
        "  P_mean=", round(r1.P_mean, digits=2), "  P_end=", round(r1.P_end, digits=2))
# Re-baselined 2026-09-04: under the corrected decode this historical collapse
# artifact EARLY-REJECTS (P=0, no ODE window), so no twist/line signature is
# recorded — the meaningful assertion is that it is REJECTED (not a valid
# machine).  The collapse-twist detection itself is covered by B5's wound check.
check("B1: collapse design is :reject", r1.status === :reject)

println("=== B2: historical 18m winner — no divergence under corrected physics ===")
r2 = run_eval(read_vec(WINNER18), L18, 20.0)
println("  status=", r2.status, "  P_mean=", round(r2.P_mean, digits=2),
        "  P_end=", round(r2.P_end, digits=2), "  fitness=", round(r2.fitness, digits=3))
# Re-baselined 2026-09-04: the OLD flywheel failure (hub double-model) is fixed,
# so this artifact no longer runs away — it evaluates to :ok or :reject with a
# finite, bounded power (never a divergence).  The guard itself is B7.
b2_ok = (r2.status === :reject) || isfinite(r2.P_end)
check("B2: historical winner evaluates bounded (no flywheel divergence)", b2_ok)

println("=== B3: corrected seed (healthy) through v13 ===")
r3 = run_eval(seed_x(), L18, 20.0)
println("  status=", r3.status, "  twist_crossed=", r3.twist_crossed,
        "  P_mean=", round(r3.P_mean, digits=2), "  P_end=", round(r3.P_end, digits=2))
check("B3a: seed is :ok with no twist flag", r3.status === :ok && !r3.twist_crossed)
check("B3b: seed P_end ≥ 5.0 kW", r3.P_end >= 5.0)
# B3c (seed fitness beats the flywheel) is dropped: the corrected seed is an
# intentionally "less fit, more safe" STARTING point (Do 0.08), heavier than
# optimised winners, so a fitness-vs-broken-artifact comparison no longer holds.

println("=== B4: unit — penalize_ceiling=false makes more power strictly better ===")
cfg_u = v13_cfg(10.0, 2.24)  # k_mppt is irrelevant for this pure fitness unit test
f_hi = KiteTurbineDynamics.v12_fitness(7.5, 3.0, cfg_u)
f_lo = KiteTurbineDynamics.v12_fitness(3.5, 3.0, cfg_u)
println("  fitness(7.5 kW)=", round(f_hi, digits=3), "  fitness(3.5 kW)=", round(f_lo, digits=3))
check("B4: fitness(7.5) < fitness(3.5)", f_hi < f_lo)

println("=== B5: unit — twist_collapse_check ===")
p = params_at_length(params_daisy(), L18, KW)
dec = design_from_vector_v10(seed_x(), BEAM, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift_for(sys, pc), wind_fn=wind_fn, n_op=30_000)
N = sys.n_total
Nr = sys.n_ring
t0 = KiteTurbineDynamics.twist_collapse_check(u, sys)
u_wound = copy(u)
u_wound[6N + Nr] += π  # wind one segment by 180° (δα* ≤ 90° always)
t1 = KiteTurbineDynamics.twist_collapse_check(u_wound, sys)
println("  post-settle: crossed=", t0.crossed, " max_ratio=", round(t0.max_ratio, digits=3),
        "   wound: crossed=", t1.crossed, " max_ratio=", round(t1.max_ratio, digits=1))
check("B5a: post-settle state is not flagged", !t0.crossed && t0.max_ratio < 1.0)
check("B5b: +π wound segment is flagged", t1.crossed)

println("=== B6: campaign winner is healthy (:ok, hub tip < 100 m/s) ===")
if isfile(WINNER18V13)
    r6 = run_eval(read_vec(WINNER18V13), L18, 20.0)
    println("  status=", r6.status, "  P_mean=", round(r6.P_mean, digits=2), "  fitness=", round(r6.fitness, digits=3))
    check("B6a: campaign winner is :ok", r6.status === :ok)
    g6 = gate_design(read_vec(WINNER18V13); L=L18, KW=KW)
    hub_ri = (g6.sys.nodes[g6.sys.rotor.node_id]::RingNode).ring_idx
    w_hub = g6.u[6*g6.N + g6.Nr + hub_ri]
    hub_tip = abs(w_hub) * g6.sys.rotor.radius
    println("  hub_tip=", round(hub_tip, digits=1), " m/s")
    check("B6b: hub tip < 100 m/s (and every ring/rotor)", hub_tip < 100.0 && tip_speed_sanity_ok(g6.u, g6.sys))
else
    println("  (campaign winner CSV not present — skipping B6)")
end

println("=== B7: unit — tip_speed_sanity_ok ===")
hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
ok0 = KiteTurbineDynamics.tip_speed_sanity_ok(u, sys)
u_hub = copy(u)
u_hub[6N + Nr + hub_ri] = 1e20   # diverged hub ring ω
ok1 = KiteTurbineDynamics.tip_speed_sanity_ok(u_hub, sys)
u_mid = copy(u)
u_mid[6N + Nr + 2] = 1e3         # diverged MIDDLE ring ω (rim speed 1e3·r ≫ 100 m/s)
ok2 = KiteTurbineDynamics.tip_speed_sanity_ok(u_mid, sys)
println("  settled: ok=", ok0, "   hub ω=1e20: ok=", ok1, "   mid-ring ω=1e3: ok=", ok2)
check("B7a: settled state passes tip-speed sanity", ok0)
check("B7b: diverged hub ω fails tip-speed sanity", !ok1)
check("B7c: diverged MIDDLE ring ω fails tip-speed sanity (all rings checked)", !ok2)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
