#!/usr/bin/env julia
# scratch/sv_vrated_indep_2026-10-20.jl — science-validator, independent probe.
#
# Question (user ask, 2026-10-20): is the figures seat's five-mass table real?
# Same fixed winner genome, five values of cfg.v_rated, decode + closed-form
# sizing only (no ODE). If the mass moves, v_rated is part of the machine and
# a sweep that moves it with the wind draws a different machine per point.
#
# Written independently of scratch/_fig_vrated_mass_probe.jl: genome read
# from the strip extract row, not hardcoded; same public calls the evaluator
# makes (objective_evaluator.jl:721 decode, :751 sizing).

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV

const KTD = KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
const KW  = 5.0
const L   = 18.8

function params_at_length(Lv::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        Lv, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW);
        tether_length=Lv)
end

p_base = params_at_length(L)
@printf("p_base: h_ref=%.9f m  v_wind_ref=%.12f m/s  L=%.1f m\n",
        p_base.h_ref, p_base.v_wind_ref, p_base.tether_length)

# winner genome: strip extract, last row (gen 26, i3-g26-i9), columns x1..x10
EXTRACT = joinpath(@__DIR__, "..", "docs", "reporting", "figures",
                   "machine-evolution-strip", "extract-best-so-far.csv")
rows = collect(CSV.File(EXTRACT; comment="#"))
x = Float64[rows[end].x1, rows[end].x2, rows[end].x3, rows[end].x4, rows[end].x5,
            rows[end].x6, rows[end].x7, rows[end].x8, rows[end].x9, rows[end].x10]
println("genome from extract row: gen=", rows[end].gen, " idx=", rows[end].idx,
        " fitness=", rows[end].fitness, " P_end=", rows[end].P_end)
println("genome = ", x)

# integer genes as the canonical decode expects them
x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
x[6] = Float64(round(Int, clamp(x[6], 1, 3)))

function cfg_at(v::Float64)
    ObjectiveConfig(;
        power_W=KW * 1000.0, v_rated=v,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=10.0, window_s=40.0,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0, k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=2e-3,
    )
end

function mass_at(v::Float64)
    cfg = cfg_at(v)
    dec = KTD.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated, cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode, power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg, rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor)
    sizing = KTD.size_beams_closed_form(dec, p_base, cfg)
    sys, _, pc = KTD.build_system_from_v10(dec, 1.0, cfg.k_mppt;
        tether_diameter=cfg.tether_diameter, base_params=p_base,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing)
    return (KTD.expansion_airborne_mass(sys, pc), dec.design.r_hub)
end

VS = (9.0, 10.0, 11.0, 12.0, 13.0)
res = [(v, mass_at(v)) for v in VS]
m_ref = only([m for (v, (m, _)) in res if v == 11.0])
println("\nv_rated | mass_kg (15 dp)          | r_hub     | mass - mass(11.0)")
for (v, (m, rh)) in res
    @printf("%7.3f | %.15f | %9.4f | %+.12f\n", v, m, rh, m - m_ref)
end
println("\nmax spread across the five: ", maximum(m for (_, (m, _)) in res) -
        minimum(m for (_, (m, _)) in res), " kg")
