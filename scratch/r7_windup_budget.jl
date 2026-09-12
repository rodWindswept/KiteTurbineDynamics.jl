# scratch/r7_windup_budget.jl — workstream step 1: torque budget over the honest
# window. Distinguishes a generator/aero torque imbalance from a slow torsional
# mode as the cause of the shaft wind-up.
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

function build_for(k::Float64)
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0, fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3,
        t_over_D=0.055, rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=k)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, k;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = k
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=30_000)
    return sys, pc, u, lift, wf, dt
end

for k in (2.24, 3.0, 4.0, 5.39)
    sys, pc, u, lift, wf, dt = build_for(k)
    N = sys.n_total
    Nr = sys.n_ring
    println("=== k=$k ===")
    println(" t(s) | w_gnd | w_hub | dα(deg) | twist_r | P_gen | ΣP_aero | τ_gen | τ_shaft | τ_net")
    for c in 1:10
        run_canonical_sim!(u, sys, pc, wf, round(Int, 5.0 / dt), dt; lift_device=lift, lin_damp=0.05)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, c * 5.0, wf, lift)
        tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
        ω_g = u[6N + Nr + 1]
        ω_h = u[6N + Nr + Nr]
        dα = sum(ef.segment_twist_deg)
        P_gen = ef.base.P_kw
        P_aero = sum(ef.rotor_aero_power)
        τ_gen = ω_g > 0.1 ? P_gen * 1000.0 / ω_g : 0.0
        τ_shaft = ef.segment_torque[end]        # top segment (hub side)
        τ_net = P_aero * 1000.0 / max(abs(ω_h), 0.1) - τ_gen
        @printf(" %4d  | %5.2f | %5.2f | %7.2f | %7.3f | %5.2f | %7.2f | %5.1f | %7.1f | %6.1f\n",
            c * 5, ω_g, ω_h, dα, tr.max_ratio, P_gen, P_aero, τ_gen, τ_shaft, τ_net)
    end
    println()
end
