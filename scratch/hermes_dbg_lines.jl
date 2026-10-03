#!/usr/bin/env julia
# scratch/hermes_dbg_lines.jl — verify drawn line endpoints for island 3 winner
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
using LinearAlgebra
const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const CAMPAIGN = joinpath(ROOT, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate")
const KW = 5.0; const PW = KW * 1000.0; const V_RATED = 11.0
const LENGTH = 18.8; const BF = BLOCKING_WIND_FACTOR_5KW
const FOS_HARD = 2.5

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

function round_discrete!(x::Vector{Float64})
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    return xr
end

isl = 3
idir = joinpath(CAMPAIGN, "island_$isl")
xraw = parse.(Float64, split(strip(read(joinpath(idir, "island_$(isl)_best.csv"), String)), ","))
xesc = round_discrete!(xraw)
dec = design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF)
cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=FOS_HARD, fos_hard=FOS_HARD,
    min_wall_m=2e-3, t_over_D=0.055,
    rotor_count_mode=true, power_split=0.6, blocking_factor=BF,
)
sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=P_BASE.tether_diameter, base_params=P_BASE, min_wall_m=2e-3,
    beam_sizing=sizing)

pos(id) = u0[(3 * (id - 1) + 1):(3 * id)]
Nn = sys.n_total
println("n_lines(pc) = ", pc.n_lines, "   n_ring = ", sys.n_ring, "   n_total = ", Nn)

brg = copy(pos(sys.bearing_id))
sw  = copy(pos(sys.sky_anchor_id))
back_ax = pc.tether_length * cos(pc.elevation_angle) + pc.back_anchor_fwd_x
ga  = [back_ax, 0.0, 0.0]
@printf("bearing    = [%.2f, %.2f, %.2f]\n", brg...)
@printf("sky anchor = [%.2f, %.2f, %.2f]\n", sw...)
@printf("back_ax    = %.3f  (tether_length %.2f · cos(elev %.4f rad) + fwd %.3f)\n",
    back_ax, pc.tether_length, pc.elevation_angle, pc.back_anchor_fwd_x)
@printf("ground an. = [%.2f, %.2f, %.2f]\n", ga...)

ld = KTD.sized_lifter_for(sys, pc; margin=1.5, v_ref=V_RATED, const_tension=true)
println("lifter type = ", typeof(ld))
_, _, elev_deg = KTD.lift_force_steady(ld, pc.rho, V_RATED)
ll = ld isa KTD.SingleKiteParams ? ld.line_length :
     (ld isa KTD.StackedKitesParams ? ld.spacing * ld.n_kites : ld.line_length)
@printf("lifter: line_length = %.2f m   steady elev = %.2f deg at v=%.1f\n", ll, elev_deg, V_RATED)

shsh = sw ./ max(norm(sw), 1e-6)
sh_h = [shsh[1], shsh[2], 0.0]; sh_h = sh_h ./ max(norm(sh_h), 1e-6)
th = deg2rad(clamp(elev_deg, 5.0, 89.0))
kite = sw .+ ll .* (sh_h .* cos(th) .+ [0.0, 0.0, sin(th)])
@printf("lift dir h = [%.3f, %.3f, %.3f]\n", sh_h...)
@printf("kite       = [%.2f, %.2f, %.2f]\n", kite...)

centers = [pos(id) for id in sys.ring_ids]
c1 = centers[1]
shaft = normalize(centers[end] .- c1)
side = normalize(cross([0.0, 1.0, 0.0], shaft))
println("c1 = [", join(round.(c1, digits=2), ", "), "]   shaft = [",
        join(round.(shaft, digits=3), ", "), "]")
for (nm, p) in (("bearing", brg), ("sky anchor", sw), ("ground anchor", ga), ("kite", kite))
    d = p .- c1
    si = dot(d, shaft)
    rad = d .- si .* shaft
    @printf("2D %-13s: signed radius %+7.2f   s %7.2f\n", nm, dot(rad, side), si)
end
zmax = max(maximum(sw), kite[3], maximum(c1), 18.8 * shaft[3] + c1[3])
@printf("all-drawn z-extent approx: z from %.2f to %.2f (kite z %.2f)\n",
    min(0.0, c1[3]), kite[3], kite[3])
println("done")
