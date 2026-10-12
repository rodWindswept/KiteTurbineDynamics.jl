#!/usr/bin/env julia
# scratch/sv_probe_fignums.jl — science-validator, 2026-10-12
#
# Static decode probe (no ODE) for the figure-brief number check. Reproduces
# every numeric quote the nine-figure proposals carry for the island-3 winner:
# genome slots, decoded n_lines / rings / n_active / r_hub / r_bot, per-rotor
# bank and blade_scale, and the built machine's bank + radii.
#
# Chain mirrors scratch/sv_probe_winner_areas.jl (the NR-032/NR-033 receipt):
# discrete-gene rounding, canonical_v10, then the evaluator's own decode call
# (v_rated = cfg.v_rated EXPLICITLY — the decode default is the site wind
# p.v_wind_ref = 11.0097, not 11.0; omitting it builds a different rotor).
# The closing checks compare the built radii against the signed NR-032 values.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_fignums.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const CAMPAIGN = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW
const FOS_HARD = 2.5

# signed NR-032 receipts, pinned as check targets (pre-registered)
const NR032_R_OUT = 5.629560432565964
const NR032_R_IN = 4.130158464357515

# ── params at length (mirrors run_v13_5kw_masslift.jl + the winner pack) ──
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

const P_BASE = params_at_length(LENGTH)

# ── discrete-gene rounding — byte-identical to scratch/hermes_winner_pack.jl ──
function round_discrete!(x::Vector{Float64})
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # canonical n_lines
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # canonical rotor count
    return xr
end

function main()
    @printf("ROOT = %s\n", ROOT)
    genfile = joinpath(CAMPAIGN, "island_3", "island_3_best.csv")
    xraw = parse.(Float64, split(strip(read(genfile, String)), ","))
    @printf("file = %s\n", genfile)
    @printf("genome (10-D, raw):\n")
    names = ["x1 r_hub", "x2 r_bottom", "x3 target_Lr", "x4 n_lines",
        "x5 density_profile", "x6 rotor_count", "x7 bank_top", "x8 bank_bottom",
        "x9 blade_scale_top", "x10 blade_scale_bottom"]
    for i in 1:10
        @printf("  %-24s = %.17g\n", names[i], xraw[i])
    end

    cfg = KTD.ObjectiveConfig(; power_W=PW, v_rated=V_RATED, p_floor_kw=KW,
        fos_target=FOS_HARD, fos_hard=FOS_HARD, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BF)
    xesc = round_discrete!(xraw)
    xc = KTD.canonical_v10(xesc)
    @printf("\npost-round x[4]=%.1f  x[6]=%.1f  (canonical x[4]=%.1f  x[6]=%.1f)\n",
        xesc[4], xesc[6], xc[4], xc[6])

    dec = KTD.design_from_vector_v10(xc, PROFILE_ELLIPTICAL, P_BASE;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true, rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D)

    @printf("decoded: n_lines=%d rings=%d n_active=%d rotors=%d\n",
        dec.design.n_lines, dec.n_rings, dec.n_active, length(dec.rotors))
    @printf("decoded r_hub = %.17g  (quote 4.580)\n", dec.design.r_hub)
    @printf("decoded r_bottom = %.17g  (quote 0.804)\n", dec.design.r_bottom)
    for r in dec.rotors
        @printf("rotor: ring_idx=%d bank=%.17g  blade_scale=%.17g\n",
            r.ring_idx, r.bank_angle_deg, r.blade_scale)
    end
    @printf("any decoded rotor bank at slot-8 value 22.0: %s\n",
        any(b -> abs(b - 22.0) < 1e-9, [r.bank_angle_deg for r in dec.rotors]))
    @printf("any decoded rotor blade_scale at slot-10 value 0.2: %s\n",
        any(b -> abs(b - 0.2) < 1e-9, [r.blade_scale for r in dec.rotors]))

    # built machine — same construction knobs as the evaluator chain
    sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=P_BASE.tether_diameter, base_params=P_BASE,
        min_wall_m=2e-3, beam_sizing=sizing)
    @printf("\nbuilt sys.rotor bank_angle_deg = %.17g\n", sys.rotor.bank_angle_deg)
    @printf("built sys.rotor radius = %.17g  blade_hub_radius = %.17g\n",
        sys.rotor.radius, sys.rotor.blade_hub_radius)
    @printf("built expansion rotors = %d\n", length(sys.expansion_rotors))
    @printf("built swept area = %.17g\n", KTD.main_rotor_swept_area(sys))
    @printf("\ncheck: tip == NR-032 r_out pinned  : %s\n", sys.rotor.radius == NR032_R_OUT)
    @printf("check: r_in == NR-032 blade_hub pinned: %s\n", sys.rotor.blade_hub_radius == NR032_R_IN)
end
main()
