# scratch/r7_sizing_dump.jl — R7 evidence: per-ring sizing on the 5 kW seed.
using KiteTurbineDynamics, Printf

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

for peak in (false, true)
    s = size_beams_closed_form(dec, p, cfg; hub_peak_load=peak)
    println("=== hub_peak_load=$peak  omega_eq=$(round(s.omega_eq, digits=2)) ===")
    println(" ring |    r   |  T_line |  N_comp |    Do(mm) | FoS")
    for i in eachindex(s.Do_per_ring)
        @printf("  %2d  | %6.3f | %7.1f | %7.1f | %8.2f | %6.2f%s\n",
            i, dec.radii[i], s.T_line_per_ring[i], s.N_comp_per_ring[i],
            s.Do_per_ring[i] * 1e3, s.fos_per_ring[i],
            i == length(dec.radii) ? "  <- hub" : "")
    end
    println()
end
