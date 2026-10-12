#!/usr/bin/env julia
# scratch/av_probe_clearance_knob.jl — aero-validator, 2026-10-12
#
# Static (no ODE) check of a decode-convention split found while auditing the
# figure-brief number chain. The campaign runner decodes each candidate twice:
#   gate path   scripts/run_v13_5kw_masslift.jl:250-253 — v_rated OMITTED
#               (decode default = p.v_wind_ref = 11.00969423693896)
#   score path  src/objective_evaluator.jl:716-729 — v_rated = cfg.v_rated = 11.0
# This probe rebuilds the bankderate2 island-3 winner under both conventions,
# verbatim call shapes, and prints the clearance each returns.
#
# Measured 2026-10-12 (main tree at 1a95ae0): gate path 5.4681239776600616 m,
# score path 5.4668473649653162 m — 1.28 mm apart; both round to the stored
# telemetry 5.47. The pair extract's own clearance line
# (docs/reporting/figures/pair-extract/extract-winner-operating-point.log:11,
# 5.468123977660059 m) equals the GATE path to 2.6e-15 m, not the score path:
# the extract mirrors the campaign's recorded decode chain, whose clearance
# column comes from this omitted-knob call.
#
# USAGE: scripts/ktd-julia scratch/av_probe_clearance_knob.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const CAMPAIGN = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
const KW = 5.0
const PW = KW * 1000.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW
const GROUND_OFFSET = 1.0   # run_v13_5kw_masslift.jl GROUND_OFFSET
const ELEV_DEG = 30.0       # rad2deg(ELEV) in the runner

const EXTRACT_CLEARANCE = 5.468123977660059   # extract log line 11

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

function main()
    genfile = joinpath(CAMPAIGN, "island_3", "island_3_best.csv")
    xraw = parse.(Float64, split(strip(read(genfile, String)), ","))
    xr = copy(xraw)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # n_lines (R7 10-D layout)
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # rotor count {1,2,3}
    @printf("genome file = %s\n", genfile)
    @printf("P_BASE.v_wind_ref = %.17g  (the omitted-knob decode default)\n",
        P_BASE.v_wind_ref)

    # (a) the runner's gate decode — v_rated omitted; verbatim shape of
    #     scripts/run_v13_5kw_masslift.jl:250-253
    dec_a = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)

    # (b) the evaluator's scored decode — v_rated passed; verbatim shape of
    #     src/objective_evaluator.jl:716-729
    dec_b = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        v_rated=11.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF,
        beam_t_over_D=0.055)

    clr_a = KTD.lowest_rotor_clearance(dec_a; ground_offset=GROUND_OFFSET,
        elevation_deg=ELEV_DEG)
    clr_b = KTD.lowest_rotor_clearance(dec_b; ground_offset=GROUND_OFFSET,
        elevation_deg=ELEV_DEG)

    ra = dec_a.rotors[1]
    rb = dec_b.rotors[1]
    @printf("\n(a) gate path (v_rated omitted -> %.17g)\n", P_BASE.v_wind_ref)
    @printf("    ring_idx=%d bank=%.17g  tip_off=%.17g  hub_off=%.17g\n",
        ra.ring_idx, ra.bank_angle_deg, ra.blade_tip_radius, ra.blade_hub_radius)
    @printf("    absolute tip = %.17g   clearance = %.17g\n",
        dec_a.radii[ra.ring_idx] + ra.blade_tip_radius, clr_a)
    @printf("(b) score path (v_rated = 11.0)\n")
    @printf("    ring_idx=%d bank=%.17g  tip_off=%.17g  hub_off=%.17g\n",
        rb.ring_idx, rb.bank_angle_deg, rb.blade_tip_radius, rb.blade_hub_radius)
    @printf("    absolute tip = %.17g   clearance = %.17g\n",
        dec_b.radii[rb.ring_idx] + rb.blade_tip_radius, clr_b)

    @printf("\ndiff vs extract clearance line %.15g :  gate (a) %.3e   score (b) %.3e\n",
        EXTRACT_CLEARANCE, clr_a - EXTRACT_CLEARANCE, clr_b - EXTRACT_CLEARANCE)
    @printf("clearance delta (b) - (a) = %.6e m  (gate reads %s than the score path)\n",
        clr_b - clr_a, clr_a > clr_b ? "HIGHER margin" : "lower margin")
    @printf("winner gate margin vs the 1.5 m floor (gate reading) = %.6f m\n",
        clr_a - 1.5)
    println("AV_CLEARANCE_KNOB_DONE")
end
main()
