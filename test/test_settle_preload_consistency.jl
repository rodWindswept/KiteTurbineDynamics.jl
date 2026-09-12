# test/test_settle_preload_consistency.jl
#
# Guard for the 2026-09-11 settle↔ODE coherence fix
# (docs/plans/2026-09-11-settle-ode-coherence.md).
#
# The previous initialiser set each segment's ring AXIAL gap for the *untwisted*
# line and only then applied the twist.  Because
#
#     chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos Δα
#
# the twist term alone stretches the line.  At the Δα the old bisection landed on
# (6.6°) that twist strain was 1.6e-3 — six times the intended preload strain
# (2.7e-4) — so the segment looked ~7× too stiff, the settle returned a ~7×
# under-twisted state, and the ODE spent ~100 s shortening the transmission to
# relieve it (the wind-up).
#
# The invariant that must hold for ANY design is:
#
#     line tension at the settled state  ==  the intended preload F_ax/n_lines
#
# plus the twist must be the twisted equilibrium, not the old 6.6°.
# This is a pure static check — no ODE window — so it belongs in the fast suite.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

# `nothing` for a gene keeps the seed's own value (the campaign seed).
function build_case(n_lines, rotor_count)
    p = params_5kw_188()
    x = seed_genome(5.0)
    n_lines === nothing || (x[4] = Float64(n_lines))
    rotor_count === nothing || (x[6] = rotor_count)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

function settled_case(n_lines, rotor_count)
    sys, u0, pc, lift, wf = build_case(n_lines, rotor_count)
    F_ax = design_axial_preload(sys, pc, lift)
    @test length(F_ax) == sys.n_ring - 1
    intended = F_ax ./ pc.n_lines
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    return sys, pc, u, intended, ef
end

@testset "settle matched-place preload — tension equals the intended preload" begin
    # The campaign seed: the geometry the wind-up was diagnosed and fixed on.
    for (nl, rc) in ((nothing, nothing), (4, 3.0))
        sys, pc, u, intended, ef = settled_case(nl, rc)
        err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
        @test err < 0.15

        # Guard against regression to the old ~7x-under-twisted state.  A correct
        # matched-place solve puts the first segment far past the old 6.6° — it
        # carries the full generator torque at the design tension.
        @test ef.segment_twist_deg[1] > 30.0

        # The transmission must shorten under torsion (rings pulled together),
        # not sit at the untwisted design length.
        untwisted = sum(
            ROPE_SUBSEGS * sys.sub_segs[(k - 1) * pc.n_lines * ROPE_SUBSEGS + 1].length_0
            for k in 1:(sys.n_ring - 1)
        )
        hub = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
        @test norm(hub) < untwisted
    end
end

@testset "settle matched-place preload — known tilt limitation" begin
    # KNOWN LIMITATION (2026-09-11).  `_matched_place_twist` uses the law of
    # cosines for a ring plane perpendicular to the shaft axis.  Where the settle
    # leaves the ring planes significantly tilted (`_tilted_ring_basis`, driven by
    # the bearing offset), the actual chord differs by ~0.1 mm — large next to the
    # ~0.3 mm intended preload strain — and the achieved tension runs ~35 % high.
    # This geometry (a 14-segment constant-radius shaft) trips it.  The twist, and
    # therefore the wind-up fix, is unaffected because Δα does not depend on L_ax.
    sys, pc, u, intended, ef = settled_case(6, 1.0)
    err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
    @test err < 0.60        # was 7x (600 %) before the fix
    @test ef.segment_twist_deg[1] > 30.0   # the wind-up fix still applies
end
