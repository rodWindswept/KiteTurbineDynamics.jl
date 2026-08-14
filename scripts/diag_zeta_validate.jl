#!/usr/bin/env julia --project=.
# Quick end-to-end validation of zeta=0.05 fix.
# Uses the real run_canonical_sim! from simulation.jl with MPPT active.

using KiteTurbineDynamics

p = params_10kw()
println("zeta = ", p.zeta, "  (was 1.5)")

sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p)
lift = KiteTurbineDynamics.rotary_lifter_default()
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

println("Settling...")
u = KiteTurbineDynamics.settle_to_operational_state(
    sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wind_fn)
println("Settle complete.")

# Set low ω and re-init rope velocities
N = sys.n_total; Nr = sys.n_ring
HubIdx = 6N + Nr + Nr
println("Setting ω = 2.0 rad/s...")
@views u[(6N + Nr + 1):(6N + 2Nr)] .= 2.0
KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)

# Enable MPPT
sys.k_mppt_ref[] = p.k_mppt
println("k_mppt = ", p.k_mppt)

# Use the canonical simulation loop
dt = 4e-5
n_steps = 250_000  # 10 s
println("Running ", n_steps, " steps (", n_steps*dt, " s)...")

KiteTurbineDynamics.run_canonical_sim!(
    u, sys, p, wind_fn, n_steps, dt;
    lift_device=lift, lin_damp=0.05)

ω_final = u[HubIdx]
println("\nω: 2.0 → ", round(ω_final, digits=3), " rad/s")

if ω_final > 5.0
    println("✅ FIX CONFIRMED — rotor spins up and sustains with zeta=", p.zeta)
elseif ω_final < -0.1
    println("❌ STILL STALLING — reverse torque persists despite zeta=", p.zeta)
else
    println("⚠️  AMBIGUOUS — ω=", round(ω_final, digits=3))
end
