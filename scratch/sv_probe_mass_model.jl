# sv_probe_mass_model.jl — software-validator, 2026-10-02
#
# DECIDES: the score's mass term.  sv_probe_score_accounting.jl reproduced the
# campaign's fitness exactly (21.6983 vs the recorded 21.6980) and its arithmetic
# leaves a mass of 20.2135 kg, while a plain `build_system_from_v10` reports
# expansion_airborne_mass = 21.0971 kg for the same genome (0.884 kg apart).
#
# Cause under test: the evaluator passes `beam_sizing = size_beams_closed_form(...)`
# and `min_wall_m = cfg.min_wall_m` to the builder (objective_evaluator.jl:679,694).
# A plain call supplies neither, so it falls back to the legacy
# `Do_top·(r/r_hub)^Do_scale_exp` taper and the default wall floor — a different
# tube, hence a different mass, for the same genome.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_mass_model.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const L18 = 18.8

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

p = params_at_length(L18)
cfg = KTD.ObjectiveConfig(;
    k_mppt=K_MPPT_5KW_HONEST, power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0, relax_s=10.0, window_s=40.0,
    fos_target=2.5, fos_hard=2.5, power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0, rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    tether_diameter=p.tether_diameter)

function measure(label, dir)
    csv = joinpath(ROOT, "scripts", "results", dir, "best_vector.csv")
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sysA, _, pcA = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    sizing = KTD.size_beams_closed_form(dec, p, cfg)
    sysB, _, pcB = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing)
    println("\n--- ", label, " ---")
    @printf("  A plain build (no beam_sizing)   airborne = %.4f kg  (no lifter %.4f)\n",
        KTD.expansion_airborne_mass(sysA, pcA),
        KTD.expansion_airborne_mass(sysA, pcA; include_lifter=false))
    @printf("  B evaluator build (beam_sizing)   airborne = %.4f kg  (no lifter %.4f)\n",
        KTD.expansion_airborne_mass(sysB, pcB),
        KTD.expansion_airborne_mass(sysB, pcB; include_lifter=false))
    @printf("  Do_per_ring A = %s\n", string(round.(sysA.ring_Do_per_ring[], digits=4)))
    @printf("  Do_per_ring B = %s\n", string(round.(sysB.ring_Do_per_ring[], digits=4)))
    @printf("  t_over_D  A = %.5f   B = %.5f\n",
        sysA.ring_toverD[], sysB.ring_toverD[])
end

measure("bank-derate winner (10-field)", "v13_5kw_masslift_len18.8_rotorcount_bankderate")
measure("PRE-derate winner (14-field)", "v13_5kw_masslift_len18.8_rotorcount")
