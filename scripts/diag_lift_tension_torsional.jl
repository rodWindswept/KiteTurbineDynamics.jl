#!/usr/bin/env julia --project=.
#=
diag_lift_tension_torsional.jl — measure lift-device axial tension vs rotor
thrust at the 5kW operating point, and recompute the static torsional FoS
with lift tension included in T_total.

Question: does the lift kite tension materially change the torsional gate
at 5 kW, or is it negligible next to rotor thrust?
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5

# Use the verified 5kW winner (island 1, sustains 6.34 kW)
x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), String)), ",")]
p = mass_scale(params_10kw(), 10.0, KW)
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
lift = rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
sys.k_mppt_ref[] = p.k_mppt
run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 20.0/DT), DT; lift_device=lift, lin_damp=0.05)

# ── Extract T_lift and rotor thrust from the live state ─────────────────
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 20.0, wind_fn, lift; brake_engaged=sys.brake_engaged[])
println("T_lift (lift device axial tension) = ", round(ef.base.T_lift, digits=1), " N")

# Rotor thrust at rated: from the static evaluator path
r = evaluate_design_v5(dec.design; power_W=PW)
println("Static evaluator T_total (thrust only) implicit in tors gate")
println("Static torsional FoS (no lift)     = ", round(r.min_torsional_fos, digits=3))

# Thrust estimate from BEM: CT=0.55, rotor area
A_hub = π * p.rotor_radius^2
T_thrust = 0.5 * p.rho * A_hub * p.v_wind_ref^2 * 0.55
println("\n── Comparison ──")
println("Rotor thrust (BEM est)             = ", round(T_thrust, digits=1), " N")
println("Lift device tension (ODE)          = ", round(ef.base.T_lift, digits=1), " N")
ratio = ef.base.T_lift / max(T_thrust, 1.0)
println("T_lift / T_thrust                  = ", round(ratio, digits=3))

# ── Recompute torsional FoS with lift included ────────────────────────────
# τ_cap ∝ T_total, so FoS scales linearly: FoS' = FoS × (T_thrust+T_lift)/T_thrust
fos_lift = r.min_torsional_fos * (1.0 + ratio)
println("\nTorsional FoS with lift tension    = ", round(fos_lift, digits=3))
println("Gate                              = 1.5")
if fos_lift >= 1.5
    println("✅ Lift tension closes the gap")
else
    println("❌ Lift tension insufficient — need ", round(1.5/fos_lift, digits=1), "× more")
end
