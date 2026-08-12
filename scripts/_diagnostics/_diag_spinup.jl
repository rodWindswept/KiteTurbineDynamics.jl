#!/usr/bin/env julia
using KiteTurbineDynamics, LinearAlgebra

sys, u0, p, _, _ = build_v10_tight_no_lowest(r_bottom_scale=1.30, tether_diameter=0.004)
ld = rotary_lifter_default()
wf(pos, t) = (z = max(pos[3], 1.0); [11.0 * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0])
N = sys.n_total; Nr = sys.n_ring; dt = 4e-5

function measure(u, sys, k)
    P = abs(sum(k * u[6N+Nr+ri]^3 for ri in 1:Nr)) / 1000
    ω = u[6N + Nr + Nr]
    return (P=P, ω=ω)
end

# Approach 1: spin up with k≈0, then settle_to_equilibrium, then load
println("── Approach 1: free spin-up (k=0.001) → load ──")
sys.k_mppt_ref[] = 0.001
u = settle_to_equilibrium(sys, u0, p; wind_fn=wf, lift_device=ld)
run_canonical_sim!(u, sys, p, wf, round(Int, 30.0/dt), dt; lin_damp=0.05, lift_device=ld)
m = measure(u, sys, 0.001)
println("  After 30s free spin: ω=$(round(m.ω, digits=1)) rad/s")

# Now load with k=20
sys.k_mppt_ref[] = 20.0
run_canonical_sim!(u, sys, p, wf, round(Int, 30.0/dt), dt; lin_damp=0.05, lift_device=ld)
m = measure(u, sys, 20.0)
println("  After loading k=20 for 30s: P=$(round(m.P, digits=1)) kW  ω=$(round(m.ω, digits=1)) rad/s ($(round(m.ω*60/(2π), digits=1)) rpm)")

# Approach 2: kickstart (PTO reversal), then settle, then load
println("\n── Approach 2: kickstart → settle → load ──")
sys.k_mppt_ref[] = -60.0  # motor
u2 = copy(u0)
run_canonical_sim!(u2, sys, p, wf, round(Int, 2.0/dt), dt; lin_damp=0.05, lift_device=ld)
m = measure(u2, sys, -60.0)
println("  After 2s motor: ω=$(round(m.ω, digits=1)) rad/s")

# Settle with lift and wind
u2 = settle_to_equilibrium(sys, u2, p; wind_fn=wf, lift_device=ld)
m = measure(u2, sys, -60.0)
println("  After settle: ω=$(round(m.ω, digits=1)) rad/s")

# Load with k=15
sys.k_mppt_ref[] = 15.0
run_canonical_sim!(u2, sys, p, wf, round(Int, 30.0/dt), dt; lin_damp=0.05, lift_device=ld)
m = measure(u2, sys, 15.0)
println("  After loading k=15 for 30s: P=$(round(m.P, digits=1)) kW  ω=$(round(m.ω, digits=1)) rad/s ($(round(m.ω*60/(2π), digits=1)) rpm)")

# Approach 3: gradual ramp from k=0.001 to k=30 over 60s (manual ramp controller)
println("\n── Approach 3: manual ramp 0.001→30 over 60s ──")
sys.k_mppt_ref[] = 0.001
u3 = settle_to_equilibrium(sys, u0, p; wind_fn=wf, lift_device=ld)
chunk_s = 2.0
chunk_steps = round(Int, chunk_s/dt)
k_start = 0.001
k_end = 30.0
n_chunks = 30  # 60s total
for i in 1:n_chunks
    frac = (i-1) / (n_chunks-1)
    k_i = k_start + frac * (k_end - k_start)
    sys.k_mppt_ref[] = k_i
    try
        run_canonical_sim!(u3, sys, p, wf, chunk_steps, dt; lin_damp=0.05, lift_device=ld)
    catch e
        println("  Chunk $i crashed: $e"); break
    end
    if i % 10 == 0 || i == n_chunks
        m = measure(u3, sys, k_i)
        println("  chunk $i: k=$(round(k_i, digits=1))  P=$(round(m.P, digits=1)) kW  ω=$(round(m.ω, digits=1)) rad/s ($(round(m.ω*60/(2π), digits=1)) rpm)")
    end
end
