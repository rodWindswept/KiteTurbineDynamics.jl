# scratch/r7_case_check.jl — which geometry fails the preload guard, and why.
using KiteTurbineDynamics, Printf, LinearAlgebra
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

function build_case(n_lines::Int, rotor_count::Float64)
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[4] = Float64(n_lines)
    x[6] = rotor_count
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

for (nl, rc) in ((6, 1.0), (4, 3.0))
    sys, u0, pc, lift, wf = build_case(nl, rc)
    F_ax = design_axial_preload(sys, pc, lift)
    intended = F_ax ./ pc.n_lines
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    nr = [sys.nodes[sys.ring_ids[k]].radius for k in 1:sys.n_ring]
    @printf("\n=== n_lines=%d rotor_count=%.1f  n_expansion_rotors=%d ===\n",
        nl, rc, length(sys.expansion_rotors))
    @printf("intended : %s\n", join(round.(intended, digits=0), ", "))
    @printf("achieved : %s\n", join(round.(ef.segment_tension, digits=0), ", "))
    @printf("rel err  : %s\n", join(round.(abs.(ef.segment_tension .- intended) ./ intended, digits=3), ", "))
    @printf("twist    : %s\n", join(round.(ef.segment_twist_deg, digits=2), ", "))
    @printf("ring radii     : %s\n", join(round.(nr, digits=3), ", "))
    if !isempty(sys.expansion_rotors)
        @printf("effective radii: %s\n", join(round.(sys.effective_radii, digits=3), ", "))
    end
    @printf("chord0   : %s\n", join(round.([ROPE_SUBSEGS * sys.sub_segs[(k-1)*pc.n_lines*ROPE_SUBSEGS+1].length_0 for k in 1:(sys.n_ring-1)], digits=4), ", "))
    @printf("EA_single=%.4e  ss.EA=%.4e\n",
        pc.e_modulus * π * (pc.tether_diameter / 2)^2, sys.sub_segs[1].EA)
end
