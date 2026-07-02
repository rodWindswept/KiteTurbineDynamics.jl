# scripts/builders_util.jl
#
# Standalone utility module that provides system builders used by both the
# interactive dashboard and headless analysis scripts.
#
# Import this instead of `include("interactive_dashboard.jl")` to avoid
# triggering the GLMakie GUI and its event loop.

using KiteTurbineDynamics
using JSON3

"""
    build_v10_tight_no_lowest()

Build the V10 Tight winner system (49.2 kg, 4 rotors, Island 1) with the
lowest-expansion rotor removed.  Reads `best_design.json` from the
`v10_campaign_50kw/` results directory.

Returns `(sys, u0, p, label)`.
"""
function build_v10_tight_no_lowest(;
    r_bottom_scale::Float64 = 1.0,
    tether_diameter::Float64 = 0.003,
)
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    isfile(best_path) || error("best_design.json not found at $best_path")
    best = JSON3.read(read(best_path, String))
    x = Float64[
        best.r_hub_m, best.r_bottom_m, best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, 1.0
    ]
    x[2] *= r_bottom_scale       # reinforce bottom ring radius
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     max_ground_radius=5.0, power_W=50000.0)
    rotors = sort(result.rotors, by=r -> r.ring_idx, rev=true)
    if length(rotors) > 1
        dropped = popfirst!(rotors)
        println("Dropped lowest expansion rotor at ring $(dropped.ring_idx)")
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
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, p_base.m_ring, p_base.m_blade)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    le = isempty(rotors) ? 1.0 : rotors[1].blade_scale
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    println("V10 Tight no-lowest: n_lines=$n_lines n_rotors=$n_exp rings=$n_rings mass=$(round(best.best_mass_kg, digits=2))kg")
    return sys, u0, pc, "V10 Tight ($n_exp rotors)"
end
