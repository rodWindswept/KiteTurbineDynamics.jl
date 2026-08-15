#!/usr/bin/env julia --project=.
# diag: locate WHERE the 18m winner's ω_hub jumps to 1e66 — settle vs MPPT chunks
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v13_5kw_len18.0", "best_vector.csv"), String)), ",")]
p = KiteTurbineDynamics.params_10kw()
KW = 5.0
geo = KiteTurbineDynamics.GeometrySpec(p.elevation_angle, p.lifter_elevation, p.rotor_radius,
    18.0, p.trpt_hub_radius, p.trpt_rL_ratio, p.n_lines, p.n_rings, p.n_blades)
mat = KiteTurbineDynamics.MaterialSpec(p.tether_diameter, p.e_modulus, p.m_ring, p.m_blade)
aero = KiteTurbineDynamics.AeroSpec(p.rho, p.v_wind_ref, p.h_ref, p.cp)
ctrl = KiteTurbineDynamics.ControlSpec(p.i_pto, p.k_mppt, p.p_rated_w, p.β_min, p.β_max, p.β_rate_max, p.kp_elev)
back = KiteTurbineDynamics.BackLineSpec(p.EA_back_line, p.c_back_line, p.back_anchor_fwd_x, p.backline_payout)
p18 = KiteTurbineDynamics.mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
xr = copy(x)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p18; power_W=5000.0)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p18.k_mppt; tether_diameter=p18.tether_diameter)
println("rotor radius = ", sys.rotor.radius, "  n_rings = ", sys.n_ring)
wind_fn(r, t) = [p18.v_wind_ref, 0.0, 0.0]

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=rotary_lifter_default(), wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
w = @view u[(6N+Nr+1):(6N+2Nr)]
println("POST-SETTLE  max|ω| = ", maximum(abs, w), "   ω_hub = ", w[hub_ri])
sys.k_mppt_ref[] = p18.k_mppt
for chunk in 1:6
    run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / 4e-5), 4e-5; lift_device=rotary_lifter_default(), lin_damp=0.05)
    println("t=", chunk * 5, "s  max|ω| = ", maximum(abs, w), "   ω_hub = ", w[hub_ri],
            "   ω_gnd = ", w[1], "   alpha_hub = ", u[6N + Nr])
end
