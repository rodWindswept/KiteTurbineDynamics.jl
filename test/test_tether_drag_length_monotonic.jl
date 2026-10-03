# test/test_tether_drag_length_monotonic.jl
#
# Guard: tether drag power is monotone in axial length at fixed reference
# height.  This is the physical fact behind "length is never free": lengthening
# the TRPT shaft always adds tether line drag, whatever the wind-reference
# convention (frozen-anchor h_ref = 9.412 m, or hub-anchor h_ref = L·sin(elev)).
#
# The guard isolates the tether term with a geometry trick that does NOT touch
# the sizing chain (design_from_vector_v10 -> size_beams_closed_form ->
# sized_lifter_for), so it is independent of the open test_trpt_realisability
# fixture re-baseline and of the frozen-vs-hub anchor decision.
#
# settle_parasitic_drag_power reads each ring node's RADIUS from sys.nodes but
# its segment LENGTH from the node POSITIONS in the state vector.  Scaling every
# ring-node position by a factor f therefore:
#   * multiplies every tether segment length L_seg by f (norm is homogeneous),
#   * leaves every radius r_mid unchanged (radii come from sys.nodes),
#   * leaves the beam drag unchanged (it is radius-only, no position term).
# So P(f) = P_beam + f · P_tether: strictly increasing in f, and the
# finite-difference ratio (P(f3)-P(f1))/(P(f2)-P(f1)) = (f3-f1)/(f2-f1) exactly.
# Any refactor that makes P_tether length-independent (a flat segment length, or
# dropping the position term) flips BOTH the monotonicity and the ratio red.
#
# Wired into test/runtests.jl (fast unit suite); runs standalone too.

using Test, KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

# Daisy 1.5 kW -> 5 kW at length L (mirrors run_v13_5kw_masslift.jl /
# test_rope_break.jl).  mass_scale also scales the tether length, so the FINAL
# length is restored via override_params (2026-08-22 fix).
function params_at_length(L::Float64)
    p2 = KiteTurbineDynamics.params_daisy()
    geo = KiteTurbineDynamics.GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = KiteTurbineDynamics.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KiteTurbineDynamics.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = KiteTurbineDynamics.BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = KiteTurbineDynamics.mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0)
    return KiteTurbineDynamics.override_params(scaled; tether_length=L)
end

# Scale every ring-node POSITION by f, leaving sys.nodes radii untouched.
function stretch_ring_positions(u::Vector{Float64}, sys, f::Float64)
    u2 = copy(u)
    for i in 1:sys.n_ring
        gid = sys.ring_ids[i]
        idx = (3 * (gid - 1) + 1):(3 * gid)
        @views u2[idx] .*= f
    end
    return u2
end

@testset "tether drag grows with axial length at fixed h_ref" begin
    D = KiteTurbineDynamics
    p = params_at_length(18.8)
    x = copy(seed_genome(5.0))
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    dec = D.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, _pc = D.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)

    ω = 10.0
    P(f) = D.settle_parasitic_drag_power(sys, p, ω, stretch_ring_positions(u0, sys, f))
    P1, P2, P3 = P(1.0), P(1.2), P(1.4)

    @test P2 > P1
    @test P3 > P2
    @test isapprox((P3 - P1) / (P2 - P1), 2.0; rtol = 1e-6)
end
