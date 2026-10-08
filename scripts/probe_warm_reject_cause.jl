#!/usr/bin/env julia --project=.
# probe_warm_reject_cause.jl — which warm-path gate rejects the bankderate2
# winners? Replicates evaluate_windowed's :warm build chain exactly:
#   decode → size_beams_closed_form → build → omega_eq check → rope settle
# and prints the first failing stage for each island winner.
#
# Usage: julia --project=. scripts/probe_warm_reject_cause.jl
using KiteTurbineDynamics, Printf, DelimitedFiles
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const RESULTS = joinpath(@__DIR__, "results/v13_5kw_masslift_len18.8_rotorcount_bankderate2")

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function main()
    p_base = params_at_length(18.8)
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 10.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = K_MPPT_5KW_HONEST,
        tether_diameter = p_base.tether_diameter,
        rotor_count_mode = true,
        blocking_factor = BLOCKING_WIND_FACTOR_5KW,
    )

    for island in 1:3
        v = vec(readdlm(joinpath(RESULTS, "island_$island/best_vector.csv"), ',', Float64))
        x_canon = KiteTurbineDynamics.canonical_v10(v)
        dec = design_from_vector_v10(
            x_canon, PROFILE_ELLIPTICAL, p_base;
            power_W = cfg.power_W, v_rated = cfg.v_rated,
            cylinder_cone = true, rotor_count_mode = cfg.rotor_count_mode,
            power_split = cfg.power_split, cone_slope_deg = cfg.cone_slope_deg,
            rotor_spacing_frac = cfg.rotor_spacing_frac,
            blocking_factor = cfg.blocking_factor, beam_t_over_D = cfg.t_over_D,
        )
        stage = "decode+spacing OK"
        sizing = size_beams_closed_form(dec, p_base, cfg)
        omega = sizing.omega_eq
        if omega === nothing
            stage = "REJECT: sizing.omega_eq is nothing"
        elseif isnan(omega)
            stage = "REJECT: sizing.omega_eq is NaN"
        elseif omega <= 0.0
            stage = "REJECT: sizing.omega_eq <= 0 ($(round(omega, digits=6)))"
        end
        if stage == "decode+spacing OK"
            k_mppt = clamp(cfg.k_mppt, 0.01, KiteTurbineDynamics.K_MPPT_MAX)
            sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
                dec, 1.0, k_mppt;
                tether_diameter = cfg.tether_diameter,
                base_params = p_base,
                min_wall_m = cfg.min_wall_m,
                beam_sizing = sizing,
            )
            lift_dev = lift_for(sys, pc)
            wf(pos, t) = (z = max(pos[3], 1.0); [KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, z), 0.0, 0.0])
            u_settled = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; wind_fn = wf, lift_device = lift_dev)
            if any(isnan.(u_settled)) || any(isinf.(u_settled))
                stage = "REJECT: rope settle produced NaN/Inf state"
            else
                stage = "settle OK — warm path would fly the window"
            end
        end
        @printf("island %d  omega_eq = %-10s  -> %s\n", island,
            omega === nothing ? "nothing" : isnan(omega) ? "NaN" : string(round(omega, digits=4)), stage)
        flush(stdout)
    end
end

main()
