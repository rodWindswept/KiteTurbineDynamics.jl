#!/usr/bin/env julia --project=.
#= test_evaluator_v13.jl — acceptance tests for the v13 evaluator instrumentation
(proposal: docs/plans/2026-08-13-evaluator-v13-realistic-ktd.md).
RED on master (cfg kwargs + fields + twist_collapse_check do not exist yet),
GREEN after implementation. Standalone (not wired into runtests.jl — B1-B3
run 20-30s ODE windows).

B1: island-1 winner (torsional collapse)  → :reject + twist_crossed=true
B2: 18m winner (flywheel decay)            → :reject OR (P_end < 2.5 AND worse fitness than seed)
B3: original seed (healthy)                → :ok, no twist, P_end ≥ 2.5, fitness beats B2's
B4: unit — penalize_ceiling=false → more power strictly better
B5: unit — twist_collapse_check flags wound state, not post-settle
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))  # params_at_length, twist_report

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const BEAM = PROFILE_ELLIPTICAL

const WINNER1 = joinpath(@__DIR__, "..", "scripts", "results", "v12_5kw_coldstart", "island_1_best.csv")
const WINNER18 = joinpath(@__DIR__, "..", "scripts", "results", "v12_5kw_len18.0", "best_vector.csv")
const SEED_CSV = joinpath(@__DIR__, "..", "scripts", "results", "seed_5kw.csv")

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

function v13_cfg(window_s::Float64, k_mppt::Float64)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=k_mppt,          # the scaled system's rated MPPT gain (p.k_mppt ≈ 1.94 at 5 kW), NOT the 50kW default 10.0
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=2.5, p_ceiling_kw=5.0,
        relax_s=5.0, window_s=window_s,
        fos_target=1.5, fos_hard=1.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,   # ζ=0.05 reaches the productive branch directly; the kick winds chains past δα*
    )
end

function run_eval(x::Vector{Float64}, L::Float64, window_s::Float64)
    p = params_at_length(params_10kw(), L, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    return KiteTurbineDynamics.evaluate_windowed(
        xr, BEAM, p, v13_cfg(window_s, p.k_mppt);
        start_mode=:cold,
        lift_device=rotary_lifter_default(),
        fitness_fn=(P, F, c) -> KiteTurbineDynamics.v12_fitness(P, F, c),
    )
end

function read_vec(path::String)
    return [parse(Float64, s) for s in split(strip(read(path, String)), ",")]
end

println("=== B1: island-1 winner (collapse) through v13 ===")
r1 = run_eval(read_vec(WINNER1), 21.2, 30.0)
println("  status=", r1.status, "  twist_crossed=", r1.twist_crossed,
        "  P_mean=", round(r1.P_mean, digits=2), "  P_end=", round(r1.P_end, digits=2))
check("B1: collapse design is :reject with twist_crossed=true",
      r1.status === :reject && r1.twist_crossed)

println("=== B2: 18m winner (flywheel) through v13 ===")
r2 = run_eval(read_vec(WINNER18), 18.0, 20.0)
println("  status=", r2.status, "  twist_crossed=", r2.twist_crossed,
        "  P_mean=", round(r2.P_mean, digits=2), "  P_end=", round(r2.P_end, digits=2),
        "  fitness=", round(r2.fitness, digits=3))
b2_ok = r2.status === :reject || r2.P_end < 2.5
check("B2: flywheel design rejected OR P_end < 2.5 kW", b2_ok)

println("=== B3: original seed (healthy) through v13 ===")
r3 = run_eval(read_vec(SEED_CSV), 21.2, 20.0)
println("  status=", r3.status, "  twist_crossed=", r3.twist_crossed,
        "  P_mean=", round(r3.P_mean, digits=2), "  P_end=", round(r3.P_end, digits=2),
        "  fitness=", round(r3.fitness, digits=3))
check("B3a: seed is :ok with no twist flag", r3.status === :ok && !r3.twist_crossed)
check("B3b: seed P_end ≥ 2.5 kW", r3.P_end >= 2.5)
check("B3c: seed fitness strictly beats the flywheel design's",
      r3.status === :ok && r3.fitness < r2.fitness)

println("=== B4: unit — penalize_ceiling=false makes more power strictly better ===")
cfg_u = v13_cfg(10.0, 1.94)  # k_mppt is irrelevant for this pure fitness unit test
f_hi = KiteTurbineDynamics.v12_fitness(7.5, 3.0, cfg_u)
f_lo = KiteTurbineDynamics.v12_fitness(3.5, 3.0, cfg_u)
println("  fitness(7.5 kW)=", round(f_hi, digits=3), "  fitness(3.5 kW)=", round(f_lo, digits=3))
check("B4: fitness(7.5) < fitness(3.5)", f_hi < f_lo)

println("=== B5: unit — twist_collapse_check ===")
p = params_at_length(params_10kw(), 21.2, KW)
dec = design_from_vector_v10(read_vec(SEED_CSV), BEAM, p; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn, n_op=30_000)
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

println("=== B6: 18m v13 winner (hub divergence) must be rejected ===")
WINNER18V13 = joinpath(@__DIR__, "..", "scripts", "results", "v13_5kw_len18.0", "best_vector.csv")
if isfile(WINNER18V13)
    r6 = run_eval(read_vec(WINNER18V13), 18.0, 20.0)
    println("  status=", r6.status, "  twist_crossed=", r6.twist_crossed,
            "  P_mean=", round(r6.P_mean, digits=2), "  fitness=", round(r6.fitness, digits=3))
    check("B6: hub-diverged design is :reject", r6.status === :reject)
else
    println("  (18m v13 winner CSV not present — skipping B6)")
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
    exit(1)
end
