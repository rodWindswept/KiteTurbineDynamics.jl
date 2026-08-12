#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring; dt = 4e-5

# Test k_mppt on the descending side (stable)
for (label, k_test) in [("k=26.6 (85%)", 26.56), ("k=28.7 (80%)", 28.66), ("k=23.4 (90%)", 23.42)]
    sys.k_mppt_ref[] = k_test
    println("\n── $label ──")
    for t_sim in [10.0, 30.0, 60.0]
        u_s = settle_to_operational_state(sys, u0, p, 12.0; wind_fn=wf, lift_device=ld)
        run_canonical_sim!(u_s, sys, p, wf, round(Int, t_sim/dt), dt; lin_damp=0.05, lift_device=ld)
        P_kw = abs(sum(k_test * u_s[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
        ω = u_s[6N + Nr + Nr]
        rpm = ω * 60 / (2π)
        println("  $(Int(t_sim))s: P=$(round(P_kw, digits=1)) kW  ω=$(round(ω, digits=1)) rad/s ($(round(rpm, digits=1)) rpm)")
    end
end

# Also try: skip settle, cold start with low k and spin up naturally
println("\n── Cold start: low k, no settle, let it find equilibrium ──")
sys.k_mppt_ref[] = 1.0  # very soft generator
u_cold = copy(u0)
# Just run the ODE from builder state — no settle at all
run_canonical_sim!(u_cold, sys, p, wf, round(Int, 30.0/dt), dt; lin_damp=0.05, lift_device=ld)
ω30 = u_cold[6N+Nr+Nr]
P30 = abs(sum(1.0 * u_cold[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
println("  k=1.0, 30s: ω=$(round(ω30, digits=1)) rad/s, P=$(round(P30, digits=1)) kW")

# Now ramp k up in stages
for (new_k, run_s) in [(5.0, 10.0), (15.0, 20.0), (26.0, 30.0)]
    sys.k_mppt_ref[] = new_k
    run_canonical_sim!(u_cold, sys, p, wf, round(Int, run_s/dt), dt; lin_damp=0.05, lift_device=ld)
    ω_r = u_cold[6N+Nr+Nr]
    P_r = abs(sum(new_k * u_cold[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    println("  ramp to k=$new_k, +$(Int(run_s))s: P=$(round(P_r, digits=1)) kW  ω=$(round(ω_r, digits=1)) rad/s ($(round(ω_r*60/(2π), digits=1)) rpm)")
end
