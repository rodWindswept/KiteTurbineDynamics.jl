#!/usr/bin/env julia
# Probe the settle scan in settle_to_operational_state: for each k in the
# sweep grid, replicate the ω-scan EXACTLY as written (initialization.jl
# lines ~815-853) and print the crossing the settle would pick.
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 20.0
const LENGTH = 18.8

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
end

p_base = params_at_length(LENGTH)
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
xr = clamp.(copy(seed_v), lo, hi)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW)
sys0, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec, 1.0, 5.39; tether_diameter=p_base.tether_diameter, base_params=p_base)

println("seed geometry:")
println("  r_hub=$(round(dec.design.r_hub,digits=3))  n_lines=$(dec.design.n_lines)  n_rings=$(dec.n_rings)  n_active=$(dec.n_active)")
println("  hub rotor: R=$(round(sys0.rotor.radius,digits=3))  r_in=$(round(sys0.rotor.blade_hub_radius,digits=3))")
println("  annulus A = $(round(π*(sys0.rotor.radius^2 - sys0.rotor.blade_hub_radius^2), digits=2)) m²")
println("  p_base: k_mppt=$(p_base.k_mppt)  m_blade=$(p_base.m_blade)  tether_d=$(p_base.tether_diameter)")
const _cp_end = KiteTurbineDynamics.BEM_CP_END_TSR
const _cp_zero = KiteTurbineDynamics.BEM_CP_ZERO_TSR
println("  cp peak/end/zero: TSR end=$(_cp_end) zero=$(_cp_zero)  cp_end=$(KiteTurbineDynamics.BEM_CP_END_VAL)")
println()

v_mag = V_RATED
R = sys0.rotor.radius
r_in = sys0.rotor.blade_hub_radius
A = π * (R^2 - r_in^2)
β = p_base.elevation_angle

println(" k      ω_eq(scan)   λ_eq    cp_eq    P_aero(kW)  P_gen(kW)  margin")
for k in [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]
    ω_eq = 60.0
    found = false
    for w in range(60.0, 0.1; length=200)
        lambda = w * R / v_mag
        P_aero = 0.5 * p_base.rho * v_mag^3 * A * cp_at_tsr(lambda) * cos(β)^2.65
        P_gen = k * w^3
        if P_aero > P_gen
            ω_eq = w
            found = true
            break
        end
    end
    λ_eq = ω_eq * R / v_mag
    cp_eq = cp_at_tsr(λ_eq)
    P_aero = 0.5 * p_base.rho * v_mag^3 * A * cp_eq * cos(β)^2.65
    P_gen = k * ω_eq^3
    @printf("%-5s %-11.2f %-8.3f %-7.3f %-11.2f %-11.2f %s\n",
        k, found ? ω_eq : NaN, λ_eq, cp_eq, P_aero/1000, P_gen/1000,
        found ? "" : "NOT FOUND (ω_eq stays 60!)")
end

println()
println("cp(λ) landmarks: λ=6 → $(round(cp_at_tsr(6.0),digits=3))  λ=7 → $(round(cp_at_tsr(7.0),digits=3))  λ=8 → $(round(cp_at_tsr(8.0),digits=3))  λ=9 → $(round(cp_at_tsr(9.0),digits=3))  λ=9.61 → $(round(cp_at_tsr(9.61),digits=4))  λ=10 → $(round(cp_at_tsr(10.0),digits=3))  λ=12 → $(round(cp_at_tsr(12.0),digits=3))")
