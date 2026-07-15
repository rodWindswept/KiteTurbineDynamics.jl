#!/usr/bin/env julia
# Direct calibration using May 2019 test log data
# Matches VESC constant-current braking (k_eff = P/ω³) for each data point
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "daisy_builder.jl"))

# Stable test points from 17 May 2019 — Controller 4
# Each gives: (label, v_wind_mps, P_measured_W, ω_measured_rpm)
const TARGETS = [
    (label="15:27 ctrl4", v=5.22, P=42.9,  ω_rpm=109),
    (label="15:30 ctrl4", v=5.05, P=44.0,  ω_rpm=114),
    (label="15:31 ctrl4", v=5.04, P=48.9,  ω_rpm=117),
    (label="16:01 ctrl5", v=5.81, P=98.7,  ω_rpm=121),
    (label="16:02 ctrl5", v=5.57, P=108.9, ω_rpm=121),
]

println("═══════════════════════════════════════════════════════")
println("Daisy VESC Calibration — May 2019 test log")
println("═══════════════════════════════════════════════════════")
println()
println("Each point: known wind speed, known VESC braking → known k_eff")
println("k_eff = P_measured / ω³  (fixed-current braking, not MPPT)")
println()

for t in TARGETS
    ω_rads = t.ω_rpm * 2π / 60
    τ_gen  = t.P / ω_rads
    k_eff  = τ_gen / ω_rads^2

    sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
    sys.k_mppt_ref[] = k_eff
    wf(pos, _) = [t.v, 0.0, 0.0]

    # Scan ω down from ~1.5× measured to find equilibrium
    ω_max = ω_rads * 1.5
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; wind_fn=wf)
    ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)

    P_sim = ef.base.P_kw * 1000
    ω_sim = ef.base.omega_hub * 60 / (2π)

    err_P = 100 * (P_sim - t.P) / t.P
    err_ω = abs(ω_sim - t.ω_rpm)

    @printf("  %-15s v=%.2f  k_eff=%.4f  P=%.0f/%.0fW (%+.0f%%)  ω=%.0f/%.0frpm (%+.0f rpm)\n",
        t.label, t.v, k_eff, P_sim, t.P, err_P, ω_sim, t.ω_rpm, ω_sim - t.ω_rpm)
end

println()
println("Target: sim within ±30% of measured P and ω")
