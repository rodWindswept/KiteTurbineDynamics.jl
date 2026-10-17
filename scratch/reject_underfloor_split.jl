#!/usr/bin/env julia
# scratch/reject_underfloor_split.jl
# For the 96 "under_floor" rows (post-window reject, FoS=Inf, no cheap latch),
# split them into the two remaining hard-reject paths WITHOUT re-running the ODE:
#   betz_cp_floor : betz_cp_floor_kw(sys,p,cfg) < p_floor_kw*0.8   (line 1111)
#                   -> rotor physically cannot reach 80% of the 5 kW floor
#   betz_ceiling  : P_mean > 1.1 * Betz_ceiling_kW                  (line 1115)
#                   -> aggregate power over the physical Betz ceiling
# betz_cp_floor_kw is STATIC (swept area x Cp x rho v^3 /2), so we can compute
# it from a decoded+built system with no window simulation.
using KiteTurbineDynamics
import KiteTurbineDynamics

const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const LENGTH = 18.8

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
beam_profile = PROFILE_ELLIPTICAL

cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED, p_floor_kw = 5.0, p_ceiling_kw = 5.0,
    relax_s = 10.0, window_s = 40.0, fos_target = 2.5, fos_hard = 2.5,
    power_stat = :tail5, penalize_ceiling = false, kickstart_s = 0.0,
    k_mppt = 2.24, tether_diameter = p_base.tether_diameter,
    rotor_count_mode = true, power_split = 0.6, cone_slope_deg = 22.0,
    rotor_spacing_frac = 0.8, blocking_factor = 0.85^(1 / 3), min_wall_m = 2e-3,
)

# Parse the 96 under_floor rows from the probe log.
under = Tuple{Int,Int,Int}[]
open("/tmp/reject_probe_full.log") do io
    for line in eachline(io)
        m = match(r"\[(\d+)/\d+\] island=(\d+) gen=(\d+) idx=(\d+)\s+under_floor", line)
        m === nothing && continue
        push!(under, (parse(Int, m[2]), parse(Int, m[3]), parse(Int, m[4])))
    end
end

# load genome x1..x10 for those rows
xrows = Dict{Tuple{Int,Int,Int},Vector{Float64}}()
for isl in 1:3
    f = joinpath("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2", "island_$isl", "telemetry.csv")
    open(f) do io
        lines = readlines(io)
        hdr = split(strip(lines[2]), ',')
        for ln in lines[3:end]
            d = Dict(zip(hdr, split(strip(ln), ',')))
            key = (parse(Int, d["island"]), parse(Int, d["gen"]), parse(Int, d["idx"]))
            key in under || continue
            xrows[key] = [parse(Float64, d["x$j"]) for j in 1:10]
        end
    end
end

function static_gate(x::Vector{Float64})
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    x_canon = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, beam_profile, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated, cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode, power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg, rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, clamp(cfg.k_mppt, 0.01, KiteTurbineDynamics.K_MPPT_MAX);
        tether_diameter=cfg.tether_diameter, base_params=p_base,
        min_wall_m=cfg.min_wall_m, beam_sizing=sizing,
    )
    cp_floor = KiteTurbineDynamics.betz_cp_floor_kw(sys, p_base, cfg)
    return cp_floor
end

counts = Dict{Symbol,Int}(:betz_cp_floor => 0, :betz_ceiling_or_other => 0, :error => 0)
cp_values = Float64[]
for key in under
    x = get(xrows, key, nothing)
    x === nothing && continue
    cp = try
        static_gate(x)
    catch
        -1.0
    end
    if cp < 0.0
        counts[:error] += 1
    elseif cp < cfg.p_floor_kw * 0.8
        counts[:betz_cp_floor] += 1
        push!(cp_values, cp)
    else
        counts[:betz_ceiling_or_other] += 1
    end
end

println("=== static split of the 96 under_floor rows ===")
for (k, v) in sort(collect(counts), by = x -> -x[2])
    println("  ", k, ": ", v)
end
println("betz_cp_floor threshold (0.8*floor): ", cfg.p_floor_kw * 0.8, " kW")
println("cp_floor values (betz_cp_floor class): ", isempty(cp_values) ? "n/a" : "$(round(minimum(cp_values), digits=2))..$(round(maximum(cp_values), digits=2)) kW")
