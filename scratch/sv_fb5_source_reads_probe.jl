#!/usr/bin/env julia
# scratch/sv_fb5_source_reads_probe.jl
# science-validator, 2026-10-14 — feedback round 5 source reads (blade-scale base).
# Geometry decode only, no ODE. Prints the blade-scale base chain and the
# transition-cone geometry for the island-3 winner (bankderate2 dataset).
# The decode passes v_rated=11.0, the campaign cfg value the evaluator threads
# (objective_evaluator.jl:721), so the built blade pair matches NR-043.
# Usage: julia --project=. scratch/sv_fb5_source_reads_probe.jl

using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const LENGTH = 18.8

# Copied verbatim from scripts/run_v13_5kw_masslift.jl (lines 124-138).
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

p_base = params_at_length(LENGTH)
@printf("# p.v_wind_ref=%.12f (the evaluator decode passes v_rated=11.0)\n", p_base.v_wind_ref)

# Winner genome — bankderate2 dataset, island 3 (the register winner).
vecpath = joinpath(@__DIR__, "..", "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_3", "best_vector.csv")
x = [parse(Float64, s) for s in split(strip(read(vecpath, String)), ",")]
println("# winner genome raw (10-D): ", join(x, ", "))

xr = copy(x)
xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # n_lines (runner line 245)
xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # rotor count (runner line 246)

# The evaluated decode: v_rated = cfg.v_rated = 11.0 (objective_evaluator.jl:721).
dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW,
    v_rated=11.0,
    cylinder_cone=true, rotor_count_mode=true,
    power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)

@printf("# n_lines=%d n_rings=%d n_active=%d\n", dec.design.n_lines, dec.n_rings, dec.n_active)
@printf("# r_hub=%.12f r_bottom=%.12f tether=%.6f\n",
    dec.design.r_hub, dec.design.r_bottom, dec.design.tether_length)
@printf("# taper_start_z=%.12f harvest_length=%.12f\n", dec.taper_start_z, dec.harvest_length)
cone_len = (dec.design.r_hub - dec.design.r_bottom) / tand(22.0)
@printf("# cone_length (r_hub-r_bottom)/tan(22 deg) = %.12f\n", cone_len)

for r in dec.rotors
    base_span  = 0.75 * r.r_rotor
    base_chord = 0.113 * r.r_rotor
    span = r.blade_tip_radius - r.blade_hub_radius
    @printf("# rotor ring=%d bank=%.12f blade_scale=%.12f\n",
        r.ring_idx, r.bank_angle_deg, r.blade_scale)
    @printf("#   v_wind=%.12f r_rotor=%.12f wind_factor=%.6f\n", r.v_wind, r.r_rotor, r.wind_factor)
    @printf("#   blade_tip=%.12f blade_hub=%.12f blade_chord=%.12f\n",
        r.blade_tip_radius, r.blade_hub_radius, r.blade_chord)
    @printf("#   base_span=0.75*r=%.12f span=tip-hub=%.12f base_chord=0.113*r=%.12f\n",
        base_span, span, base_chord)
    @printf("#   check span == 0.75*r*scale:     %s\n",
        isapprox(span, base_span * r.blade_scale; rtol=1e-12))
    @printf("#   check chord == 0.113*r*scale:   %s\n",
        isapprox(r.blade_chord, base_chord * r.blade_scale; rtol=1e-12))
    @printf("#   mass_per_blade = 0.420*span^3 = %.12f kg; assembly(3) = %.12f kg\n",
        KiteTurbineDynamics.M_BLADE_REF_KG * span^3,
        3 * KiteTurbineDynamics.M_BLADE_REF_KG * span^3)
end

# Convention boundary: the runner's standalone clearance decode (lines 250-253)
# omits v_rated, so it reads p.v_wind_ref (11.009694...) and a 0.13 per cent
# different rotor radius. The evaluated machine (and this probe's main decode)
# use cfg.v_rated = 11.0.
alt = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true,
    power_split=0.6, cone_slope_deg=22.0,
    rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
@printf("# counterfactual (no v_rated, runner clearance-call convention): r_rotor=%.12f v_wind=%.12f span=%.12f\n",
    alt.rotors[1].r_rotor, alt.rotors[1].v_wind,
    alt.rotors[1].blade_tip_radius - alt.rotors[1].blade_hub_radius)

h = try
    chomp(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse HEAD`, String))
catch
    "unknown"
end
println("# HEAD: ", h)
