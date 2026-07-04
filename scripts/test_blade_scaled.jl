#!/usr/bin/env julia
# Quick targeted test: λ=0.54 blade scale at 11 m/s
# Uses the hunt_k_at_wind logic directly.
using KiteTurbineDynamics
using Printf, JSON3

const DT          = 4e-5
const T_HUNT      = 5.0
const P_RATED     = 50000.0
const V_WIND      = 11.0
const LAMBDA      = 0.54

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
include(joinpath(dirname(@__DIR__), "scripts", "hunt_kmppt_bisect.jl"))

function build_scaled(λ::Float64)
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    best = JSON3.read(read(best_path, String))
    x = Float64[
        best.r_hub_m, best.r_bottom_m,
        best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, λ,
    ]
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     max_ground_radius=5.0, power_W=50000.0)
    rotors = sort(result.rotors, by=r -> r.ring_idx, rev=true)
    if length(rotors) > 1
        popfirst!(rotors)
    end
    n_exp = length(rotors)
    n_lines = result.design.n_lines
    n_rings = result.n_rings
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        sr = rotor.ring_idx == n_rings ? n_rings + 2 : rotor.ring_idx + 1
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, 0.0, sr, 1.0,
        )
        push!(expansion_params, er)
    end
    p_base = params_v5_50kw()
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0,
                       result.design.tether_length, result.design.r_hub, p_base.trpt_rL_ratio,
                      n_lines, result.n_rings, n_lines)
    mat = MaterialSpec(0.003, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    le = isempty(rotors) ? λ : rotors[1].blade_scale
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    println("Built: $(n_exp) rotors, λ=$λ, n_lines=$n_lines, rings=$n_rings")
    return () -> (sys, u0, pc, "λ=$λ")
end

println("═"^60)
println("Targeted test: λ=$LAMBDA at $(V_WIND) m/s")
println("Expected P ≈ 50 kW (from 172.7 × $(LAMBDA)^2 = $(round(172.7*LAMBDA^2, digits=1)))")
println("═"^60)

builder = build_scaled(LAMBDA)
lift = KiteTurbineDynamics.rotary_lifter_default()
result, slices = ControlMapHunt.hunt_k_at_wind(builder, V_WIND, P_RATED; verbose=true, lift_device=lift)

println("\n── RESULT ──")
@printf("k_mppt=%.1f  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  cm=%.1f°  status=%s\n",
    result.k_mppt, result.P_kw, result.ω_rpm, result.min_fos, result.collapse_margin_deg, result.status)

if !isempty(slices)
    s = slices[end]
    @printf("Final slice (t=%.1fs): P=%.1f kW ω=%.0f rpm FoS=%.2f cm=%.1f° %d/%d failing\n",
        s.t_sim, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
        s.n_failing, length(s.ring_fos)-1)
end
