#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra, Statistics

# V10 reinforced genome + lift device
x = [0.06, 0.01, 0.87994, 1.0, 2.8885, 2.6, 2.9879, 13.208, -0.1098,
     18.558, 31.99, 34.999, 1.0, 1.0]
p = params_v5_50kw()
dt = 4e-5

# Dashboard path WITH lift device
sys, u0, p_d, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p_d.h_ref)^(1.0 / 7.0), 0.0, 0.0])

println("Dashboard path WITH lift device:")
u_s = settle_to_operational_state(sys, u0, p_d, 9.5; wind_fn=wf, lift_device=ld)
N = sys.n_total; Nr = sys.n_ring
ω_init = mean(u_s[6N+Nr+ri] for ri in 1:Nr)
println("  After settle: ω=$(round(ω_init, digits=2)) rad/s")

# Run 30s ODE
println("  Running 30s ODE...")
run_canonical_sim!(u_s, sys, p_d, wf, round(Int, 30.0/dt), dt; lin_damp=0.05, lift_device=ld)

function power_kw(u, sys)
    N = sys.n_total; Nr = sys.n_ring
    P = sum(sys.k_mppt_ref[] * u[6N+Nr+ri]^3 for ri in 1:Nr)
    abs(P) / 1000
end
P_kw = power_kw(u_s, sys)
ω_final = u_s[6N+Nr+Nr]
rpm = ω_final * 60 / (2π)
println("  After 30s: P=$(round(P_kw, digits=1)) kW  ω=$(round(ω_final, digits=1)) rad/s ($(round(rpm, digits=1)) rpm)")

# Check 10s and 20s
u2 = settle_to_operational_state(sys, u0, p_d, 9.5; wind_fn=wf, lift_device=ld)
run_canonical_sim!(u2, sys, p_d, wf, round(Int, 10.0/dt), dt; lin_damp=0.05, lift_device=ld)
P10 = power_kw(u2, sys)
ω10 = u2[6N+Nr+Nr]
println("  After 10s: P=$(round(P10, digits=1)) kW  ω=$(round(ω10, digits=1)) rad/s ($(round(ω10*60/(2π), digits=1)) rpm)")

u3 = settle_to_operational_state(sys, u0, p_d, 9.5; wind_fn=wf, lift_device=ld)
run_canonical_sim!(u3, sys, p_d, wf, round(Int, 20.0/dt), dt; lin_damp=0.05, lift_device=ld)
P20 = power_kw(u3, sys)
ω20 = u3[6N+Nr+Nr]
println("  After 20s: P=$(round(P20, digits=1)) kW  ω=$(round(ω20, digits=1)) rad/s ($(round(ω20*60/(2π), digits=1)) rpm)")
