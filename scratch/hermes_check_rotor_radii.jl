#!/usr/bin/env julia
# scratch/hermes_check_rotor_radii.jl — Hermes, 2026-10-02
# Verify the hub-rotor annulus convention the winner-pack figures draw:
# sys.rotor.radius / sys.rotor.blade_hub_radius — absolute radii, or
# offsets from the hub ring (r_ring + off)?  Prints all hypotheses + the
# code's own swept area per bankderate island winner.  No ODE.
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const BF = BLOCKING_WIND_FACTOR_5KW

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
const P_BASE = params_at_length(18.8)

const CAMP = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate")

for isl in 1:3
    csv = joinpath(CAMP, "island_$isl", "island_$(isl)_best.csv")
    isfile(csv) || continue
    x = parse.(Float64, split(strip(read(csv, String)), ","))
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
    cfg = KTD.ObjectiveConfig(;
        power_W=PW, v_rated=11.0, p_floor_kw=KW, fos_target=2.5, fos_hard=2.5,
        min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BF)
    sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=P_BASE.tether_diameter, base_params=P_BASE, min_wall_m=2e-3,
        beam_sizing=sizing)
    hub = dec.rotors[argmax([r.ring_idx for r in dec.rotors])]
    r_ring = dec.radii[hub.ring_idx]
    t_off = hub.blade_tip_radius
    h_off = hub.blade_hub_radius
    println("── island $isl ──")
    @printf("  r_ring(hub)=%.4f  tip_off=%.4f  hub_off=%.4f\n", r_ring, t_off, h_off)
    @printf("  sys.rotor.radius=%.4f  sys.rotor.blade_hub_radius=%.4f  bank=%.4f deg\n",
        sys.rotor.radius, sys.rotor.blade_hub_radius, sys.rotor.bank_angle_deg)
    @printf("  abs hypothesis:    r_ring+tip_off=%.4f   r_ring+hub_off=%.4f\n",
        r_ring + t_off, r_ring + h_off)
    @printf("  offset hypothesis: tip_off=%.4f          hub_off=%.4f\n", t_off, h_off)
    @printf("  swept area: code=%.4f m^2  (r_ring+off)=%.4f  (offset-only)=%.4f\n",
        KTD.main_rotor_swept_area(sys),
        π * ((r_ring + t_off)^2 - max(r_ring + h_off, 0.0)^2),
        π * max(t_off^2 - h_off^2, 0.0))
    for er in sys.expansion_rotors
        @printf("  expansion rotor on ring %d: r_out=%.4f r_in=%.4f\n",
            er.ring_idx,
            dec.radii[er.ring_idx] + er.blade_tip_radius,
            max(dec.radii[er.ring_idx] + er.blade_hub_radius, 0.0))
    end
end
