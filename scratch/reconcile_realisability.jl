# scratch/reconcile_realisability.jl
#
# FLOOR RECONCILIATION (Rod 2026-09-13).  Two estimates of the torsional
# realisability margin disagreed by ~2.5x:
#   closed-form floor (plan §2.4.1)  -> sin(dAlpha) ~0.95 at T_top = 1344.7 N
#   the settled ODE state            -> sin(dAlpha) ~0.38
#
# Candidate causes, all visible in code:
#   * `capture_extended` (sim_frame.jl:435-443) uses
#         L_seg = tether_length / n_seg          (UNIFORM axial length)
#         r_s   = 0.5*(r_a + r_b)                (MEAN radius)
#         chord = sqrt(L_seg^2 + 2*r_s^2*(1-cos dAlpha))   (equal-radius chord)
#     but the seed's ring spacing is NOT uniform and r_a != r_b (it is a cone),
#     and the true chord is  sqrt(L_ax^2 + r_a^2 + r_b^2 - 2 r_a r_b cos dAlpha).
#   * bare `RingNode.radius` vs `sys.effective_radii` (2026-09-11: a 55 % tension
#     error came from exactly this swap when expansion rotors are present).
#
# This script evaluates BOTH torque formulas on the SAME settled state, with the
# ring radii (bare and effective), the real axial gaps and the real attachment
# chord, and reports the twist each would need to carry the OPERATING torque.
#
#   scripts/ktd-julia scratch/reconcile_realisability.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

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

function build_case()
    p = params_5kw_188()
    x = seed_genome(5.0)
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

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case()
    N, Nr = sys.n_total, sys.n_ring
    n_seg = Nr - 1
    hub = sys.rotor.node_id
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    ef = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift)
    α = [u[6N + ri] for ri in 1:Nr]
    ω = abs(u[6N + Nr + 1])
    τ_target = sys.k_mppt_ref[] * ω^2
    L_seg_used = p.tether_length / n_seg
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)

    @printf("operating torque τ = k·ω² = %.1f × %.3f² = %.2f N·m\n",
        sys.k_mppt_ref[], ω, τ_target)
    @printf("expansion rotors at ring indices: %s   (n_exp=%d)\n",
        string([er.ring_idx for er in sys.expansion_rotors]), length(sys.expansion_rotors))
    @printf("n_ring=%d  ground ring idx=%d  hub ring idx=%d\n\n", Nr,
        (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx,
        (sys.nodes[hub]::RingNode).ring_idx)
    @printf("capture_extended uses the UNIFORM L_seg = tether_length/n_seg = %.4f m\n", L_seg_used)
    @printf("  %3s %8s %8s %8s %8s %9s %9s %10s %10s %8s %8s\n",
        "seg", "r_a", "r_b", "L_ax", "chord", "T_s", "dAlpha", "tau_ODE", "tau_true",
        "sin_true", "sin_need")
    for s in 1:n_seg
        ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
        ra_bare = (sys.nodes[ga]::RingNode).radius
        rb_bare = (sys.nodes[gb]::RingNode).radius
        ra_eff = isempty(sys.expansion_rotors) ? ra_bare : sys.effective_radii[s]
        rb_eff = isempty(sys.expansion_rotors) ? rb_bare : sys.effective_radii[s + 1]
        ca, cb = pos(u, ga), pos(u, gb)
        L_ax = dot(cb .- ca, sd)
        # TRUE attachment chord: ring-vertex to ring-vertex, line 1, tilted basis
        pa = attachment_point(ca, ra_eff, α[s], 1, p.n_lines, pp1, pp2)
        pb = attachment_point(cb, rb_eff, α[s + 1], 1, p.n_lines, pp1, pp2)
        chord = norm(pb .- pa)
        dα = mod(α[s + 1] - α[s] + π, 2π) - π
        r_s = 0.5 * (ra_bare + rb_bare)
        T_s = ef.segment_tension[s]
        # ODE telemetry formula (uniform L_seg, mean radius squared, equal-radius chord)
        chord_ode = sqrt(L_seg_used^2 + 2 * r_s^2 * (1 - cos(dα)))
        τ_ode = p.n_lines * T_s * r_s^2 * sin(abs(dα)) / max(chord_ode, 1e-9)
        # true formula on the real geometry
        τ_true = p.n_lines * T_s * ra_eff * rb_eff * sin(abs(dα)) / max(chord, 1e-9)
        # twist needed to carry the OPERATING torque at this tension (true law)
        sin_need = τ_target * chord / max(p.n_lines * T_s * ra_eff * rb_eff, 1e-12)
        @printf("  %3d %8.4f %8.4f %8.4f %8.4f %9.2f %9.2f %10.1f %10.1f %8.3f %8.3f\n",
            s, ra_eff, rb_eff, L_ax, chord, T_s, rad2deg(dα), τ_ode, τ_true,
            sin(abs(dα)), sin_need)
    end
    @printf("\n  sum tau_ODE  = %.1f N·m   sum tau_true = %.1f N·m   target = %.1f N·m\n",
        sum(ef.segment_torque), 0.0, τ_target)
    @printf("  sin_need > 1 on any segment  =>  that segment cannot carry τ at its tension\n")
    return nothing
end

main()
