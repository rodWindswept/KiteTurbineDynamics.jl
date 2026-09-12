# scratch/r7_feasibility.jl — R7 evidence: do the closed-form sized sections pass
# the FEA (now including the hub ring) on the 5 kW seed?
using KiteTurbineDynamics, Printf
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

p = params_5kw_188()
x = [0.08, 0.055, 1.0, 1.0, 2.4, 0.5751, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=0.75^(1 / 3))
cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
    fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055)

sizing = size_beams_closed_form(dec, p, cfg)
@printf("sizing omega_eq=%.2f  Do(mm)=%s\n", sizing.omega_eq,
    join(round.(sizing.Do_per_ring .* 1e3, digits=2), ", "))

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
    beam_sizing=sizing)
@printf("wired ring_Do_per_ring length=%d\n", length(sys.ring_Do_per_ring[]))
sys.k_mppt_ref[] = K_MPPT_5KW_HONEST

lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
wf = (r, t) -> [11.0, 0.0, 0.0]
dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
@printf("dt=%.3e\n", dt)
u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
for _ in 1:2
    run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
end
ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 10.0, wf, lift)

n_air = sys.n_ring - 1
println("airborne ring FEA frames = $(length(ef.ring_fos)) (expect $n_air incl. hub)")
println("lift T_ref = $(round(lift.T_ref, digits=1)) N total;  per line = $(round(lift.T_ref / pc.n_lines, digits=1)) N")
println("ring |  r   | Do(mm) |  FoS   | N_comp(N) | T_line(N) | util_ax | util_bend | N/T")
for k in eachindex(ef.ring_fos)
    # FEA frames are ring_ids[2:end] ground-first excluding ground ring
    idx = k + 1
    Tl = k <= length(ef.segment_tension) ? ef.segment_tension[k] : ef.segment_tension[end]
    @printf("  %2d | %5.3f | %6.2f | %6.2f | %9.1f | %9.1f | %7.3f | %9.3f | %.3f%s\n",
        idx, dec.radii[idx], sys.ring_Do_per_ring[][idx] * 1e3,
        ef.ring_fos[k], ef.ring_Ncomp[k], Tl,
        ef.ring_util_axial[k], ef.ring_util_bending[k],
        Tl > 0 ? ef.ring_Ncomp[k] / Tl : 0.0,
        idx == length(dec.radii) ? "  <- hub" : "")
end
@printf("FoS_min=%.3f  P_mean=%.3f kW\n",
    minimum(ef.ring_fos), ef.base.P_kw)
