#!/usr/bin/env julia --project=.
#= diag_long_window.jl — run the 5kW island-1 winner for 60s to see whether
ω converges to the settle value (slow transient) or to a lower true
equilibrium (real mismatch). =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0; const PW = 5000.0; const DT = 4e-5
p = mass_scale(params_10kw(), 10.0, KW)
x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), String)), ",")]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
lift = rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
ω0 = u[6N + Nr + Nr]
println("ω_settle = ", round(ω0, digits=2))
sys.k_mppt_ref[] = p.k_mppt

# 60s window, 5s checkpoints
for chunk in 1:12
    run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
    ω = u[6N + Nr + Nr]
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    ω_gnd = u[6N + Nr + gnd_ri]
    tau_gen, _ = get_generator_torque(u, sys, p, chunk * 5.0, wind_fn; brake_engaged=sys.brake_engaged[])
    P = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
    @printf("t=%2ds: ω=%6.2f  P=%.2f kW\n", chunk*5, ω, P)
end
ωf = u[6N + Nr + Nr]
gap = abs(ω0 - ωf)/ω0
@printf("final gap vs settle: %.1f%%\n", 100*gap)
