#!/usr/bin/env julia
# Sweep CD0_blade to find calibration match
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "daisy_builder.jl"))

v, P_meas, ω_meas = 5.57, 108.9, 121.0  # 16:02 ctrl5 — closest match
ω_rads = ω_meas * 2π / 60
k_eff = P_meas / ω_rads^3

println("Calibration sweep: 16:02 ctrl5  v=$(v)  P=$(P_meas)W  ω=$(ω_meas)rpm  k_eff=$(round(k_eff, digits=4))")
println()

for cd0 in [0.01, 0.02, 0.03, 0.05, 0.08]
    sys, u0, p, _, _ = build_daisy(blade_scale=1.0, cd0_blade=cd0)
    sys.k_mppt_ref[] = k_eff
    wf(pos, _) = [v, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, ω_rads*1.5; wind_fn=wf)
    ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
    P_sim = ef.base.P_kw * 1000
    ω_sim = ef.base.omega_hub * 60 / (2π)
    err_P = 100*(P_sim-P_meas)/P_meas
    err_ω = ω_sim - ω_meas
    @printf("  CD0=%.2f  P=%.0fW (%+.0f%%)  ω=%.0frpm (%+.0f)\n", cd0, P_sim, err_P, ω_sim, err_ω)
end
