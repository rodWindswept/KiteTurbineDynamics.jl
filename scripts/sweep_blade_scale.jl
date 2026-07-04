#!/usr/bin/env julia
# scripts/sweep_blade_scale.jl
# Quick sweep: find blade scale λ where V10 produced P ≈ P_rated at 11 m/s.
# The left-flank hunt k will be higher (more braking = lower ω = less thrust).
#
# Usage:  julia --project=. scripts/sweep_blade_scale.jl

using KiteTurbineDynamics
using Printf, JSON3

const DT          = 4e-5
const T_SIM       = 10.0         # short sim — just need endpoint P
const P_RATED     = 50000.0      # 50 kW target
const V_WIND      = 11.0
const LAMBDAS     = [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80]
const K_SWEEP     = vcat([2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0])

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

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
        popfirst!(rotors)  # drop lowest
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
    return sys, u0, pc, "$(n_exp) rotors, λ=$λ"
end

function test_k(sys_orig, u0_orig, pc, k_val)
    sys = deepcopy(sys_orig)
    u0 = deepcopy(u0_orig)
    p = deepcopy(pc)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=lift, wind_fn=wf)
    n_steps = round(Int, T_SIM / DT)
    local P_kw = 0.0; local ω_rpm = 0.0; local min_fos = Inf
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift; brake_engaged=sys.brake_engaged[])
                P_kw = ef.base.P_kw
                ω_rpm = ef.base.omega_hub * 60 / (2π)
                fos = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(fos, v)
                end
                min_fos = isempty(fos) ? Inf : minimum(fos)
            end
        end)
    return P_kw / 1000.0, ω_rpm, min_fos
end

println("═"^70)
println("Blade-scale sweep: finding λ where P ≈ 50 kW at 11 m/s")
println("V10 Tight baseline: λ=1.0 → P≈172 kW, FoS≈2.30")
println("Expected target: λ ≈ √(50/172) ≈ 0.54")
println("═"^70)

for λ in LAMBDAS
    println("\n── λ = $λ ──")
    sys, u0, pc, label = build_scaled(λ)
    
    # Quick sweep to find best k
    best_P = 0.0; best_k = 0.0; best_ω = 0.0; best_fos = Inf
    for k in K_SWEEP
        P, ω, fos = test_k(sys, u0, pc, k)
        @printf("  k=%7.1f  P=%6.1f kW  ω=%5.0f rpm  FoS=%5.2f\n", k, P, ω, fos)
        if !isnan(P) && P > best_P
            best_P = P; best_k = k; best_ω = ω; best_fos = fos
        end
        if P > 55.0  # well above rated, stop sweeping
            break
        end
    end
    
    ratio = best_P / 50.0
    status = ratio > 0.95 && ratio < 1.05 ? "★ ON TARGET" :
             ratio > 0.5 && ratio < 2.0 ? "  close" : "  off"
    @printf("  → best: k=%.0f P=%.1f kW (%.0f%%) ω=%.0f rpm FoS=%.2f %s\n",
        best_k, best_P, ratio*100, best_ω, best_fos, status)
end
