#!/usr/bin/env julia --project=.
#=
ode_gate_5kw_winner.jl — validate the V12 5kW campaign winner through the
full ODE gate: settle → run_canonical_sim! with MPPT → check sustain.
Gate: P_mean >= p_floor (2.5 kW) AND omega_final > 0.
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5
const N_STEPS = 500_000  # 20 s ODE window

# Load island-2 winner (campaign global best, fitness -4.67)
x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_2_best.csv"), String)), ",")]
println("Winner genome loaded (", length(x), " dims)")

p = mass_scale(params_10kw(), 10.0, KW)
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))

dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)
println("Design: n_lines=", dec.design.n_lines, " rings=", dec.n_rings,
        " n_active=", dec.n_active, " r_hub=", round(dec.design.r_hub, digits=2))

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
lift = rotary_lifter_default()

# Settle
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
ω_settle = u[6N + Nr + Nr]
println("Settled ω = ", round(ω_settle, digits=2), " rad/s")

# ODE gate window with MPPT
sys.k_mppt_ref[] = p.k_mppt
run_canonical_sim!(u, sys, pc, wind_fn, N_STEPS, DT; lift_device=lift, lin_damp=0.05)

ω_final = u[6N + Nr + Nr]
gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
ω_gnd = u[6N + Nr + gnd_ri]
tau_gen, _ = get_generator_torque(u, sys, p, 20.0, wind_fn; brake_engaged=sys.brake_engaged[])
P_final = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
println("Final ω = ", round(ω_final, digits=2), " rad/s  (", round(ω_final*60/(2π), digits=1), " rpm)")
println("P_gen = ", round(P_final, digits=2), " kW")

# Gate verdict
passes = (P_final >= 2.5) && (ω_final > 0.5)
println("="^50)
if passes
    println("  ✅ GATE PASSES — winner sustains ", round(P_final, digits=2), " kW")
    println("  → seeds the 7 kW rung")
else
    println("  ❌ GATE FAILS — P=", round(P_final, digits=2), " kW, ω=", round(ω_final, digits=2))
end
println("="^50)
