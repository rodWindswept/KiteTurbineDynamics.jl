#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring; dt = 4e-5

# Use settle_to_operational_state but with LOW ω_rated_max + reasonable k
# This forces the scan to find ω where P_aero has margin
for (label, k_test, ω_max) in [
    ("k=15, ω_max=8", 15.0, 8.0),
    ("k=10, ω_max=6", 10.0, 6.0),
    ("k=8, ω_max=5", 8.0, 5.0),
    ("k=5, ω_max=4", 5.0, 4.0),
]
    sys.k_mppt_ref[] = k_test
    println("\n── $label ──")
    u_s = settle_to_operational_state(sys, u0, p, ω_max; wind_fn=wf, lift_device=ld)
    ω_settle = u_s[6N+Nr+Nr]
    P_settle = abs(k_test * ω_settle^3 * Nr) / 1000
    println("  After settle: ω=$(round(ω_settle, digits=2)), P_gen=$(round(P_settle, digits=1)) kW")
    
    run_canonical_sim!(u_s, sys, p, wf, round(Int, 60.0/dt), dt; lin_damp=0.05, lift_device=ld)
    ω_end = u_s[6N+Nr+Nr]
    P_end = abs(sum(k_test * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    println("  After 60s ODE: P=$(round(P_end, digits=1)) kW  ω=$(round(ω_end, digits=1)) rad/s ($(round(ω_end*60/(2π), digits=1)) rpm)")
end

# Best candidate: test longer
println("\n── Extended: k=10, ω_max=6, 120s ──")
sys.k_mppt_ref[] = 10.0
u_s = settle_to_operational_state(sys, u0, p, 6.0; wind_fn=wf, lift_device=ld)
for t_sim in [30.0, 60.0, 90.0, 120.0]
    u_s = settle_to_operational_state(sys, u0, p, 6.0; wind_fn=wf, lift_device=ld)
    run_canonical_sim!(u_s, sys, p, wf, round(Int, t_sim/dt), dt; lin_damp=0.05, lift_device=ld)
    ω = u_s[6N+Nr+Nr]
    P = abs(sum(10.0 * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    println("  $(Int(t_sim))s: P=$(round(P, digits=1)) kW  ω=$(round(ω, digits=1)) rad/s ($(round(ω*60/(2π), digits=1)) rpm)")
end
