#!/usr/bin/env julia
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "daisy_builder.jl"))

sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
wf(pos, t) = [10.0, 0.0, 0.0]

println("settle_to_operational_state...")
u = settle_to_operational_state(sys, copy(u0), p, 40.0; wind_fn=wf)

N = sys.n_total; Nr = sys.n_ring

# Check ω
omega = u[(6N + Nr + 1):(6N + 2Nr)]
println("ω per ring: $(round.(omega, digits=2))")

# Check some positions
for k in 1:Nr
    gid = sys.ring_ids[k]
    pos = u[(3*(gid-1)+1):(3*gid)]
    println(" Ring $k: $(round.(pos, digits=2))")
end

# Check NaN
nan_pos = 0
for i in 1:N
    pi = u[(3*(i-1)+1):(3*i)]
    if any(isnan, pi); nan_pos += 1; end
end
println("NaN positions: $nan_pos")

# Run capture
ef = capture_extended(u, sys, p, 0.0, wf, nothing; brake_engaged=false)
println("P=$(ef.base.P_kw) kW  ω=$(ef.base.omega_hub) rad/s  T=$(ef.base.T_max) N")
