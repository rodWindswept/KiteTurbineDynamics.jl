#!/usr/bin/env julia
# scripts/run_blade_scaled_control_map.jl
# Full control map for blade-scaled V10 design (λ=0.54).
# Standalone — no module wrap needed, runs hunt_kmppt_bisect directly.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf, JSON3

const P_RATED   = 50000.0
const WINDS     = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const LAMBDA    = 0.54
const OUT_DIR   = joinpath(dirname(@__DIR__), "scripts", "results", "control_maps")

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
include(joinpath(dirname(@__DIR__), "scripts", "hunt_kmppt_bisect.jl"))

function build_blade_scaled()
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    best = JSON3.read(read(best_path, String))
    # V10 design vector: [r_hub, r_bottom, Do_top, t/D, target_Lr, n_lines, density,
    #                      param8, param9, param10, param11, n_active, param13, aspect_ratio, blade_scale]
    x = Float64[
        best.r_hub_m, best.r_bottom_m,
        best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, LAMBDA,
    ]
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     max_ground_radius=5.0, power_W=P_RATED)
    rotors = sort(result.rotors, by=r -> r.ring_idx, rev=true)
    if length(rotors) > 1
        dropped = popfirst!(rotors)
        println("Dropped lowest rotor at ring $(dropped.ring_idx)")
    end
    n_exp = length(rotors)
    n_lines = result.design.n_lines
    n_rings = result.n_rings
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        sr = rotor.ring_idx == n_rings ? n_rings + 2 : rotor.ring_idx + 1
        push!(expansion_params, ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, 0.0, sr, 1.0,
        ))
    end
    p_base = params_v5_50kw()
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0,
                       result.design.tether_length, result.design.r_hub, p_base.trpt_rL_ratio,
                      n_lines, result.n_rings, n_lines)
    mat = MaterialSpec(0.003, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    le = isempty(rotors) ? LAMBDA : rotors[1].blade_scale
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    println("Built: n_lines=$n_lines n_exp=$n_exp n_rings=$n_rings λ=$LAMBDA")
    println("Mass estimate from DE: $(best.best_mass_kg) kg (static, unmodified by blade scale)")
    return () -> (sys, u0, pc, "V10 λ=$LAMBDA")
end

println("═"^60)
println("Blade-scaled control map: V10 λ=$LAMBDA")
println("Expected P at 11 m/s ≈ $(round(172.7 * LAMBDA^2, digits=1)) kW")
println("═"^60)

builder = build_blade_scaled()
lift = KiteTurbineDynamics.rotary_lifter_default()
ControlMapHunt.hunt_control_map(
    builder, P_RATED, WINDS;
    out_dir=OUT_DIR, name="v10_blade_scaled_054",
    lift_device=lift, verbose=true)

println("\nDone. Results in $OUT_DIR/v10_blade_scaled_054_*.csv")
