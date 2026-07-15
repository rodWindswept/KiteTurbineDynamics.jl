#!/usr/bin/env julia
# Calibrate against Tulloch's reference power curve
# Uses wind-matched ω_rated_max so settle finds the correct equilibrium
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "daisy_builder.jl"))

# Tulloch PowerCurve_with_exp reference curve (orange line)
const TULLOCH = [
    (v=5.0, P=125.0, λ_exp=4.2),
    (v=6.0, P=220.0, λ_exp=4.2),
    (v=7.0, P=340.0, λ_exp=4.2),
    (v=8.0, P=500.0, λ_exp=4.2),
]

println("═════════════════════════════════════════════════")
println("Daisy vs Tulloch Reference Power Curve")
println("═════════════════════════════════════════════════")
println()

for t in TULLOCH
    ω_exp = t.λ_exp * t.v / 1.52   # expected equilibrium ω
    ω_max = ω_exp * 1.3             # scan 30% above expected

    sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
    wf(pos, _) = [t.v, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; wind_fn=wf)
    ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)

    P_sim = ef.base.P_kw * 1000
    ω_sim = ef.base.omega_hub * 60 / (2π)
    λ_sim = ef.base.omega_hub * p.rotor_radius / t.v
    err = 100 * (P_sim - t.P) / t.P

    @printf("  v=%.0f  ref=%.0fW  sim=%.0fW  err=%+.0f%%  ω=%.0frpm  λ=%.1f\n",
        t.v, t.P, P_sim, err, ω_sim, λ_sim)
end

# Also run at 11 m/s to check against Rod's 1.4 kW
ω_exp = 4.2 * 11.0 / 1.52
sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
wf(pos, _) = [11.0, 0.0, 0.0]
u = settle_to_operational_state(sys, copy(u0), p, ω_exp*1.3; wind_fn=wf)
ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
P_sim = ef.base.P_kw * 1000
err = 100 * (P_sim - 1400) / 1400
ω_sim = ef.base.omega_hub * 60 / (2π)
@printf("  v=11  ref=1400W sim=%.0fW  err=%+.0f%%  ω=%.0frpm\n", P_sim, err, ω_sim)
