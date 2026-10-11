#!/usr/bin/env julia --project=.
# sv_probe_winner_areas.jl — science-validator seat, 2026-10-11. Evidence
# receipt for NR-032 and NR-033 (committed with the re-base rows). The run log
# travels beside it as sv_probe_winner_areas.log.
# Static measurement (no ODE): the built winner's main-rotor radii and swept area,
# plus the reference radii for the lambda / Betz-area questions. Read-only: builds
# the winner through the evaluator's own decode -> size -> build chain and prints.
using KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const REPO = dirname(@__DIR__)
const WINNER = joinpath(REPO, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "best_vector.csv")

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
    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    println("genome raw       = ", x)
    println("genome evaluated = ", xr)

    p_base = params_at_length(LENGTH)
    cfg = ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=2.0e-3,
    )
    xc = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        xc, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true, rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    (; design, rotors, n_rings, zs, radii) = result
    println("\n== decode ==")
    println("n_lines=", design.n_lines, " n_rings=", n_rings, " n_active=", result.n_active)
    println("r_hub=", design.r_hub, " r_bottom=", design.r_bottom, " target_Lr=", design.target_Lr)
    println("zs    = ", zs)
    println("radii = ", radii)
    for (i, r) in enumerate(rotors)
        println("rotor ", i, ": ring_idx=", r.ring_idx, " bank=", r.bank_angle_deg,
            " blade_scale=", r.blade_scale, " r_rotor=", r.r_rotor,
            " blade_tip=", r.blade_tip_radius, " blade_hub=", r.blade_hub_radius,
            " v_wind=", r.v_wind, " wind_factor=", r.wind_factor)
    end
    println("p.v_wind_ref=", p_base.v_wind_ref, "  p.h_ref=", p_base.h_ref)
    println("projection_factor(bank, 30deg) = ",
        KiteTurbineDynamics.BEM.projection_factor(rotors[1].bank_angle_deg, π / 6))

    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, cfg.k_mppt;
        tether_diameter=cfg.tether_diameter,
        base_params=p_base,
        min_wall_m=cfg.min_wall_m,
        beam_sizing=sizing,
    )
    println("\n== built system ==")
    println("sys.n_ring=", sys.n_ring, " sys.n_total=", sys.n_total)
    println("sys.rotor.radius (R_main)   = ", sys.rotor.radius)
    println("sys.rotor.blade_hub_radius  = ", sys.rotor.blade_hub_radius)
    println("sys.rotor.bank_angle_deg    = ", sys.rotor.bank_angle_deg)
    println("sys.rotor.wind_factor       = ", sys.rotor.wind_factor)
    A_model = KiteTurbineDynamics.main_rotor_swept_area(sys)
    println("main_rotor_swept_area       = ", A_model)

    r_hub = design.r_hub; r_bot = design.r_bottom
    A_hub_bot = π * (r_hub^2 - r_bot^2)
    A_disc = π * r_hub^2
    println("pi(r_hub^2 - r_bot^2)       = ", A_hub_bot)
    println("pi r_hub^2 (ring disc)      = ", A_disc)
    println("span (tip offset)           = ", sys.rotor.radius - r_hub)
    println("span (built)                = ", sys.rotor.radius - sys.rotor.blade_hub_radius)

    w_gnd = 13.380259861740395
    w_hub = 13.380152462101652
    v_quote = 11.01
    v_site = p_base.v_wind_ref
    println("\n== lambda reference candidates (window mean) ==")
    for (name, R) in (("r_hub gene", r_hub), ("built R_main (tip)", sys.rotor.radius),
                      ("built blade_hub r_in", sys.rotor.blade_hub_radius),
                      ("r_bottom gene", r_bot))
        println("  ", name, " R=", R, "  lam_gnd(11.01)=", w_gnd * R / v_quote,
            "  lam_gnd(site exact)=", w_gnd * R / v_site)
    end

    ρ = p_base.rho
    println("\n== available power bases at v=11.01, rho=1.225 ==")
    for (name, A) in (("model annulus", A_model), ("hub-bottom annulus", A_hub_bot),
                      ("ring disc", A_disc))
        half = 0.5 * ρ * A * v_quote^3
        ceil_ = (16 / 27) * half * cos(π / 6)^3
        println("  ", name, " A=", A, " half_rho_Av3=", half / 1000,
            " kW  tilted-Betz=", ceil_ / 1000, " kW")
    end

    bank = sys.rotor.bank_angle_deg
    lam_tip = w_hub * sys.rotor.radius / v_quote
    lam_ring = w_hub * r_hub / v_quote
    println("\n== window-mean power reconstruction ==")
    println("lam(tip ref)=", lam_tip, "  cp_at_tsr=", cp_at_tsr(lam_tip))
    println("lam(ring ref)=", lam_ring, " cp_at_tsr=", cp_at_tsr(lam_ring))
    for (name, lam) in (("tip", lam_tip), ("ring", lam_ring))
        Paero = 0.5 * ρ * v_quote^3 * A_model * cp_at_tsr(lam) *
                cos(π / 6)^2.65 * cosd(bank)^2.65
        println("  P_aero(", name, ") = ", Paero / 1000, " kW")
    end
    println("P_mean recorded = 5.3087794439367935 kW (NR-008)")
    println("\nSV_AREAS_DONE")
end

main()
