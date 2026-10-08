#!/usr/bin/env julia
# scratch/sv_probe_rotor_banks.jl — science-validator, 2026-10-08
#
# Static decode probe (no ODE). Reproduces the per-rotor bank threading that
# the bankderate2 winner pack records, for all three island winners.
# Mirrors scratch/hermes_winner_pack.jl: same discrete-gene rounding, same
# decode knobs, same construction chain. Prints the genome bank genes, the
# decoded rotor bank angles, and the built machine's main-rotor bank.
#
# Question answered: which bank angle does each rotor carry — the slot 7
# gene (bank_top), the slot 8 gene (bank_bottom), or an interpolation?
#
# USAGE: scripts/ktd-julia scratch/sv_probe_rotor_banks.jl

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
    for isl in 1:3
        genfile = joinpath(CAMPAIGN, "island_$isl", "island_$(isl)_best.csv")
        xraw = parse.(Float64, split(strip(read(genfile, String)), ","))
        xesc = round_discrete!(xraw)
        dec = design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
            cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
            cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)

        hub = dec.rotors[argmax([r.ring_idx for r in dec.rotors])]

        println("── island $isl ──")
        @printf("  genome slot 7 (bank_top)    = %.17g\n", xraw[7])
        @printf("  genome slot 8 (bank_bottom) = %.17g\n", xraw[8])
        @printf("  post-round x[4] n_lines=%.1f  x[6] count=%.1f\n", xesc[4], xesc[6])
        @printf("  decode: n_lines=%d rings=%d n_active=%d rotors=%d\n",
            dec.design.n_lines, dec.n_rings, dec.n_active, length(dec.rotors))
        for r in dec.rotors
            @printf("  rotor: ring_idx=%d bank=%.17g deg  cosd(bank)^2.65=%.6f  blade_scale=%.6f\n",
                r.ring_idx, r.bank_angle_deg, cosd(r.bank_angle_deg)^2.65, r.blade_scale)
        end
        @printf("  hub rotor (topmost) bank = %.17g deg\n", hub.bank_angle_deg)
        @printf("  any rotor at 22.0 deg: %s\n",
            any(b -> abs(b - 22.0) < 1e-9, [r.bank_angle_deg for r in dec.rotors]))

        # built machine check — same construction knobs as the winner pack
        cfg = KTD.ObjectiveConfig(; power_W=PW, v_rated=V_RATED, p_floor_kw=KW,
            fos_target=FOS_HARD, fos_hard=FOS_HARD, min_wall_m=2e-3, t_over_D=0.055,
            rotor_count_mode=true, power_split=0.6, blocking_factor=BF)
        sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
        sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
            tether_diameter=P_BASE.tether_diameter, base_params=P_BASE,
            min_wall_m=2e-3, beam_sizing=sizing)
        @printf("  built sys.rotor bank_angle_deg = %.17g\n", sys.rotor.bank_angle_deg)
        @printf("  built sys.rotor radius = %.6f  blade_hub_radius = %.6f\n",
            sys.rotor.radius, sys.rotor.blade_hub_radius)
        @printf("  built expansion rotors = %d", length(sys.expansion_rotors))
        if !isempty(sys.expansion_rotors)
            for er in sys.expansion_rotors
                @printf("  [ring=%d bank=%.17g]", er.ring_idx, er.bank_angle_deg)
            end
        end
        println()
        @printf("  built-machine any bank at 22.0: %s\n",
            any(b -> abs(b - 22.0) < 1e-9,
                [sys.rotor.bank_angle_deg; [er.bank_angle_deg for er in sys.expansion_rotors]]))
        println()
    end
end
main()
