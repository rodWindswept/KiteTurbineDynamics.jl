#!/usr/bin/env julia
# Quick validation: canonical 10 kW at 11 m/s only, with shortened verify.
# Prove the bisection logic works before running the full sweep.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf

include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt

println("Quick validation: Canonical 10 kW at 11 m/s")

# Override constants for speed
# Don't try to modify consts — just call with shorter durations 

# Build canonical
p = KiteTurbineDynamics.params_10kw()
sys, u0 = build_kite_turbine_system(p)
wf_11(pos, t) = begin
    z = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0 / 7.0)
    [11.0 * sh, 0.0, 0.0]
end
lift = KiteTurbineDynamics.rotary_lifter_default()

# Quick bracket check at 11 m/s
println("\nBracket check at k=2:")
sys.k_mppt_ref[] = 2.0
u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf_11)
n_steps_short = round(Int, 3.0 / ControlMapHunt.DT)
N = sys.n_total; Nr = sys.n_ring

run_canonical_sim!(u, sys, p, wf_11, n_steps_short, ControlMapHunt.DT;
    lift_device=lift, lin_damp=0.05,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_steps_short
            sf = capture_frame(u_curr, sys, p, t_curr, wf_11, lift; brake_engaged=false)
            @printf("k=2:   P=%.2f kW  ω=%.1f rpm  FoS=%.2f\n", sf.P_kw,
                sf.omega_hub*60/(2π), sf.fos_ring)
        end
    end)

# Quick bracket check at k=5000
sys2, u02 = build_kite_turbine_system(p)
sys2.k_mppt_ref[] = 5000.0
u2 = settle_to_operational_state(sys2, copy(u02), p, 9.5; lift_device=lift, wind_fn=wf_11)

run_canonical_sim!(u2, sys2, p, wf_11, n_steps_short, ControlMapHunt.DT;
    lift_device=lift, lin_damp=0.05,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_steps_short
            sf = capture_frame(u_curr, sys2, p, t_curr, wf_11, lift; brake_engaged=false)
            @printf("k=5000: P=%.2f kW  ω=%.1f rpm  FoS=%.2f\n", sf.P_kw,
                sf.omega_hub*60/(2π), sf.fos_ring)
        end
    end)

# Now test the bisection at 11 m/s with the actual module, but shorter
println("\nRunning bisection hunt at 11 m/s (5s hunt, 10s verify):")
result = ControlMapHunt.hunt_k_at_wind(
    ControlMapHunt.canonical_10kw_builder, 11.0, p.p_rated_w;
    verbose=true, lift_device=lift)

println("\nResult: k=$(result.k_mppt), P=$(result.P_kw) kW, ω=$(result.ω_rpm) rpm, FoS=$(result.min_fos)")
println("Expected: k≈4, P≈10 kW, FoS≥38")
