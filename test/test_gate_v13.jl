#!/usr/bin/env julia --project=.
#= test_gate_v13.jl — acceptance tests for the re-instrumented ODE gate
(scripts/ode_gate_v13.jl). RED on master (gate module does not exist yet),
GREEN after implementation. Standalone (not wired into runtests.jl — it runs
a 30s ODE window and is too expensive for the unit suite).

A1: the 5 kW island-1 winner FAILS the re-instrumented gate (master's
    hub-power gate passed it at 6.34 kW).
A2: the twist report flags the top-segment crossing (Δα > δα*).
A3: the detector does NOT flag the post-settle state (Δα≈0) — not always-on.
A4: reported P_gen equals τ_gen·ω_gnd recomputed via get_generator_torque.
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const PW = KW * 1000.0
const WINNER_CSV = joinpath(@__DIR__, "..", "scripts", "results", "v12_5kw_coldstart", "island_1_best.csv")

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

println("=== A1/A2: gate the collapsing island-1 winner ===")
x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
r = gate_design(x; L=21.2, KW=KW)
println("  verdict ok=", r.ok, "  P_gen_final=", round(r.P_gen_final, digits=2),
        " kW  ω_gnd_final=", round(r.w_gnd_final, digits=2),
        "  crossed=", r.crossed, "  max_twist_ratio=", round(r.max_twist_ratio, digits=1))
check("A1: island-1 winner FAILS the re-instrumented gate", !r.ok)
check("A2: twist detector flags the collapse (Δα > δα*)", r.crossed)

println("=== A3: detector must not flag the post-settle state ===")
p2 = params_10kw()
p = params_at_length(p2, 21.2, KW)
xv = copy(x)
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = clamp(xv[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
tr0 = twist_report(u, sys, N, Nr)
println("  post-settle: crossed=", tr0.crossed, "  max_ratio=", round(tr0.max_ratio, digits=3))
check("A3: no flag at post-settle (Δα≈0)", !tr0.crossed && tr0.max_ratio < 1.0)

println("=== A4: P_gen == τ_gen·ω_gnd (unit consistency) ===")
sys.k_mppt_ref[] = p.k_mppt
run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / 4e-5), 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
w_gnd = max(u[6N + Nr + gnd_ri], 0.0)
tau_gen, _ = get_generator_torque(u, sys, p, 5.0, wind_fn; brake_engaged=sys.brake_engaged[])
P_direct = tau_gen * w_gnd / 1000.0
t5 = r.trace[1]
println("  gate P_gen=", round(t5.P_gen, digits=3), " kW   direct P_gen=", round(P_direct, digits=3), " kW")
check("A4: P_gen matches τ_gen·ω_gnd recomputation", isapprox(t5.P_gen, P_direct; rtol=1e-9))

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    exit(1)
end
