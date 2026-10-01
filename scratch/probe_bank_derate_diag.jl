#!/usr/bin/env julia --project=.
# Why is the bank torque ratio 0.796 rather than cos(20deg)^2.65 = 0.848?
using KiteTurbineDynamics, LinearAlgebra, Printf

p = params_10kw()
s0, u0 = build_kite_turbine_system(p; main_rotor_bank_deg=0.0)
s20, u20 = build_kite_turbine_system(p; main_rotor_bank_deg=20.0)

@printf("bank: planar %.4f   banked %.4f\n", s0.rotor.bank_angle_deg, s20.rotor.bank_angle_deg)
@printf("wind_factor: %.6f  %.6f\n", s0.rotor.wind_factor, s20.rotor.wind_factor)
@printf("radius: %.6f  %.6f\n", s0.rotor.radius, s20.rotor.radius)
@printf("blade_hub_radius: %.6f  %.6f\n", s0.rotor.blade_hub_radius, s20.rotor.blade_hub_radius)
@printf("n_ring: %d  %d    hub node: %d  %d\n", s0.n_ring, s20.n_ring, s0.rotor.node_id, s20.rotor.node_id)
@printf("u0 identical: %s   max|du| = %.3e   length %d vs %d\n",
        u0 == u20, maximum(abs.(u0 .- u20)), length(u0), length(u20))

hg = s0.rotor.node_id
@printf("hub_pos planar: %s\n", u0[3 * (hg - 1) .+ (1:3)])
@printf("hub_pos banked: %s\n", u20[3 * (hg - 1) .+ (1:3)])

# Reproduce the disc branch's own arithmetic for each system.
wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]
for (tag, s, u) in (("planar", s0, u0), ("banked", s20, u20))
    hub_pos = u[3 * (hg - 1) .+ (1:3)]
    elev = atan(hub_pos[3], sqrt(hub_pos[1]^2 + hub_pos[2]^2))
    v_wind = wind_fn(hub_pos, 0.0)
    v_hub = norm(v_wind) * s.rotor.wind_factor
    lam = 10.0 * s.rotor.radius / v_hub
    A = π * (s.rotor.radius^2 - s.rotor.blade_hub_radius^2)
    P = 0.5 * p.rho * v_hub^3 * A * cp_at_tsr(lam) *
        cos(elev)^2.65 * cosd(s.rotor.bank_angle_deg)^2.65
    @printf("%-7s elev_deg=%8.4f  v_hub=%8.4f  lam=%8.4f  cp=%8.5f  A=%8.4f  P=%12.4f  tau=%10.4f\n",
            tag, rad2deg(elev), v_hub, lam, cp_at_tsr(lam), A, P, P / 10.0)
end

# The disc torque is NOT the only thing written to torques[hub_ri]: the inter-ring
# torsional damper adds c_s * Δω.  A single spinning ring makes Δω non-zero, so the
# ratio of torques[hub_ri] is not the bank factor.  A uniform omega zeroes Δω.
println()
hub_ri = (s0.nodes[s0.rotor.node_id]::RingNode).ring_idx
for (tag, s, u) in (("planar", s0, u0), ("banked", s20, u20))
    for (oname, om) in (
        ("hub-only", let o = zeros(s.n_ring)
            o[hub_ri] = 10.0
            o
        end),
        ("uniform", fill(10.0, s.n_ring)),
    )
        forces = [zeros(3) for _ in 1:s.n_total]
        torques = zeros(s.n_ring)
        compute_ring_forces!(
            forces, torques, u, om, s, p, wind_fn, 0.0, rotary_lifter_default()
        )
        @printf("%-7s %-9s torques[hub]=%12.6f\n", tag, oname, torques[hub_ri])
    end
end
