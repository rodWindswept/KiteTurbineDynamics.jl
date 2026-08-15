#!/usr/bin/env julia --project=.
# probe_stall_25kw.jl — why does the 25 kW seed stall at ω≈0.25 rad/s?
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))
include(joinpath(@__DIR__, "ode_gate_v13.jl"))

function probe()
    kw, L = 25.0, 21.2
    x = seed_genome(kw)
    p = params_at_length(params_10kw(), L, kw)
    xv = copy(x)
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = clamp(xv[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=kw * 1000.0)
    @printf("n_active=%d  n_rings=%d  n_lines=%d  r_hub=%.3f  k_mppt=%.3f  p_rated=%.0f\n",
        dec.n_active, dec.n_rings, dec.design.n_lines, dec.design.r_hub, p.k_mppt, p.p_rated_w)
    for (i, rotor) in enumerate(dec.rotors)
        @printf("  rotor %d: ring_idx=%d  blade_tip_radius=%.3f  ring z=%.2f\n",
            i, rotor.ring_idx, rotor.blade_tip_radius, dec.zs[clamp(rotor.ring_idx, 1, length(dec.zs))])
    end
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    lift = rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    N, Nr = sys.n_total, sys.n_ring
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    println("post-settle w_gnd=", u[6N+Nr+gnd_ri], "  (raw ω state)")
    # Betz budget for the decoded design
    A = sum(π * rotor.blade_tip_radius^2 for rotor in dec.rotors)
    betz = 0.593 * 0.5 * p.rho * p.v_wind_ref^3 * A / 1000.0
    @printf("swept area=%.2f m²  Betz ceiling=%.1f kW  aero@Cp0.3=%.1f kW  (rated %.0f kW)\n",
        A, betz, 0.3 / 0.593 * betz, kw)
end
probe()
