using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
const KTD = KiteTurbineDynamics
const KW = 5.0
function params_at_length(L)
    p2 = params_daisy()
    geo = KTD.GeometrySpec(
        p2.elevation_angle,
        p2.lifter_elevation,
        p2.rotor_radius,
        L,
        p2.trpt_hub_radius,
        p2.trpt_rL_ratio,
        p2.n_lines,
        p2.n_rings,
        p2.n_blades,
    )
    mat = KTD.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KTD.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KTD.ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = KTD.BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    return override_params(
        mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW); tether_length=L
    )
end
function main()
    X = seed_genome(KW)
    P = params_at_length(18.8)
    lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)
    cfg = ObjectiveConfig(;
        power_W=KW*1000.0,
        p_floor_kw=KW,
        p_ceiling_kw=KW,
        fos_target=2.5,
        fos_hard=2.5,
        power_stat=:tail5,
        k_mppt=K_MPPT_5KW_HONEST,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        tether_diameter=P.tether_diameter,
        relax_s=120.0,
        window_s=5.0,
    )
    r = KTD.evaluate_windowed(
        X,
        PROFILE_ELLIPTICAL,
        P,
        cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=KTD.appropriate_mass_fitness,
    )
    @printf(
        "relax_s=120 -> status=%-7s P_mean=%.3f kW twist_crossed=%s drifted=%s FoS=%.3f\n",
        r.status,
        r.P_mean,
        r.twist_crossed,
        r.drifted,
        r.FoS_min
    )
end
main()
