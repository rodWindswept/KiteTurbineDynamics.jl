#!/usr/bin/env julia
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "daisy_builder.jl"))

println("══════════════════════════════════════════════════════")
println("Daisy Calibration — Tulloch Config 8, TRPT-4, 11 m/s")
println("══════════════════════════════════════════════════════")
println()
println("Reference: Tulloch §3.5, rigid wing, experimental peak 1.4 kW at 10-11 m/s")
println("Target:    P ≈ 1.0–1.4 kW, ω ≈ 220–300 rpm, Cp ≈ 0.20")

sys, u0, p, label, _ = build_daisy(blade_scale=1.0)
wf(pos, t) = [11.0, 0.0, 0.0]

println("Settling...")
u = settle_to_operational_state(sys, copy(u0), p, 40.0; wind_fn=wf)

ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
P_w = ef.base.P_kw * 1000
ω_rpm = ef.base.omega_hub * 60 / (2π)
ω_rads = ef.base.omega_hub

v_eff = 11.0
λ = ω_rads * p.rotor_radius / v_eff
A_ref = 10.8
Cp = P_w / (0.5 * 1.225 * A_ref * v_eff^3)

airborne = Float64[]
for i in 2:length(ef.ring_fos)
    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
end
fos = isempty(airborne) ? Inf : minimum(airborne)

println()
println("═══ RESULTS ═══")
@printf("  P        = %.0f W   (Tulloch peak: ~1400 W)\n", P_w)
@printf("  ω        = %.0f rpm  (expected 220–300 rpm)\n", ω_rpm)
@printf("  λ        = %.2f  (expected 3.5–4.5)\n", λ)
@printf("  Cp       = %.3f  (Tulloch experimental: 0.20–0.25)\n", Cp)
@printf("  FoS      = %.1f\n", fos)
@printf("  T_max    = %.0f N\n", ef.base.T_max)

println()
if Cp > 0.10
    println("✓ Daisy simulation produces real power at Tulloch scale")
    @printf("  Sim Cp=%.3f vs published Cp=0.20 — factor ~%.1f×\n", Cp, 0.20/Cp)
else
    println("⚠ Cp below calibration target")
end
