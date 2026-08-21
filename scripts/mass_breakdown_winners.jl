#!/usr/bin/env julia
# Mass breakdown for the three v13 5 kW winners.
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const KW = 5.0
const PW = 5000.0
const V_RATED = 11.0
const LENGTHS = [18.0, 21.2, 25.0]
const RHO_DYN = 970.0

function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

function breakdown(x14::Vector{Float64}, p_base)
    xr = copy(x14)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    result = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW, v_rated=V_RATED)
    sys, u0, pc = KTD.build_system_from_v10(result, 1.0, p_base.k_mppt;
        tether_diameter=p_base.tether_diameter)

    # Rotor tip radius — from the BUILT system (what the ODE actually simulates),
    # not the raw decoded spec.
    R_tip = isempty(sys.expansion_rotors) ? NaN : maximum(er -> er.blade_tip_radius, sys.expansion_rotors)
    n_active = length(sys.expansion_rotors)

    m_tether = pc.n_lines * pc.tether_length * (RHO_DYN * π * (pc.tether_diameter / 2)^2)
    m_rings = pc.n_rings * pc.m_ring
    m_blades = pc.n_blades * pc.m_blade
    m_exp = sum(er -> er.mass, sys.expansion_rotors; init=0.0)
    m_lifter = 5.0
    total = expansion_airborne_mass(sys, pc)
    blade_total = m_blades + m_exp
    return (n_lines=pc.n_lines, rings=pc.n_rings, n_blades=pc.n_blades,
        n_rotors=length(sys.expansion_rotors), n_active=n_active, R_tip=R_tip,
        tether_d_mm=1000*pc.tether_diameter, tether_len=pc.tether_length,
        m_ring_ea=pc.m_ring, m_blade_ea=pc.m_blade,
        m_tether=m_tether, m_rings=m_rings, m_blades=m_blades, m_exp=m_exp,
        m_lifter=m_lifter, total=total, blade_total=blade_total,
        frac=blade_total/total)
end

const P_GEN = Dict(18.0 => 7.678, 21.2 => 8.243, 25.0 => 8.322)  # regate verdicts, kW
const RHO = 1.225
const V = 11.0

for L in LENGTHS
    dir = joinpath(@__DIR__, "results", "v13_5kw_len$(L)")
    x14 = [parse(Float64, v) for v in split(strip(read(joinpath(dir, "best_vector.csv"), String)), ',')]
    b = breakdown(x14, params_at_length(L))
    P = P_GEN[L] * 1000.0
    A = π * b.R_tip^2
    cp = P / (0.5 * RHO * A * V^3)
    @printf("L=%.1f m  R_tip=%.2f m  A=%.1f m²  P_gen=%.3f kW  -> Cp_sys=%.3f  (vs PhD 0.166)\n",
        L, b.R_tip, A, P/1000, cp)
end
