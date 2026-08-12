#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring; dt = 4e-5

# The correct k balances P_gen ≈ P_aero at the aero peak
# P_aero_peak ≈ 22.4 kW at ω≈9.5. P_gen = k × Nr × ω³
# k_balanced = 22400 / (11 × 9.5³) = 22400/9427 ≈ 2.38
# Stable operation: k slightly below balanced for positive margin

for k_test in [1.0, 2.0, 3.0, 4.0, 2.5]
    sys.k_mppt_ref[] = k_test
    println("\n── k=$k_test ──")
    
    # Find equilibrium ω where P_aero > P_gen  
    ω_max = min(cbrt(22400 / (k_test * Nr)), 12.0)  # where P_gen would exceed peak aero
    u_s = settle_to_operational_state(sys, u0, p, ω_max; wind_fn=wf, lift_device=ld)
    ω_s = u_s[6N+Nr+Nr]
    
    # Check: what ω did the scan actually find?
    println("  settle ω_max=$(round(ω_max, digits=1)) → actual=$(round(ω_s, digits=1)) rad/s")
    
    run_canonical_sim!(u_s, sys, p, wf, round(Int, 60.0/dt), dt; lin_damp=0.05, lift_device=ld)
    ω_end = u_s[6N+Nr+Nr]
    P = abs(sum(k_test * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    rpm = ω_end * 60 / (2π)
    println("  60s ODE: P=$(round(P, digits=1)) kW  ω=$(round(ω_end, digits=1)) rad/s ($(round(rpm, digits=1)) rpm)")
end

# Best candidate extended
println("\n── k=2.5, 120s ──")
sys.k_mppt_ref[] = 2.5
u_s = settle_to_operational_state(sys, u0, p, 10.0; wind_fn=wf, lift_device=ld)
run_canonical_sim!(u_s, sys, p, wf, round(Int, 120.0/dt), dt; lin_damp=0.05, lift_device=ld)
ω = u_s[6N+Nr+Nr]
P = abs(sum(2.5 * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
println("  120s: P=$(round(P, digits=1)) kW  ω=$(round(ω, digits=1)) rad/s ($(round(ω*60/(2π), digits=1)) rpm)")
