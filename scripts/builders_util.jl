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
    tether_diameter::Float64=0.003,       # default 3mm, pass 0.004 for reinforced
    r_bottom_scale::Float64=1.0,          # default 1.0, pass >1.0 for larger bottom
    r_hub_scale::Float64=1.0,             # default 1.0, auto-set to ≥ r_bottom_scale
    blade_scale::Float64=1.0,             # default 1.0, pass <1.0 for smaller blades (λ)
)
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    isfile(best_path) || error("best_design.json not found at $best_path")
    best = JSON3.read(read(best_path, String))
    # Ensure r_hub ≥ r_bottom (taper constraint: top ≥ bottom)
    r_hub_s = max(r_hub_scale, r_bottom_scale * best.r_bottom_m / max(best.r_hub_m, 1e-9))
    x = Float64[
        best.r_hub_m * r_hub_s, best.r_bottom_m * r_bottom_scale,
        best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, 1.0   # λ=1.0 gate: aspect_ratio from JSON, blade_scale always 1.0 in design vector
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
            n_lines,
            rotor.blade_tip_radius * blade_scale,    # post-scale blade dimensions
            rotor.blade_hub_radius * blade_scale,
            rotor.blade_chord * blade_scale,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg,
            KiteTurbineDynamics.expansion_blade_mass(
                rotor.blade_tip_radius * blade_scale, blade_scale
            ),
            sr, 1.0,
        )
        push!(expansion_params, er)
    end
    p_base = params_v5_50kw()
    le = blade_scale  # use the kwarg, not design vector's blade_scale (which is always 1.0)
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0 * le,  # scale hub rotor aero disk
                       result.design.tether_length, result.design.r_hub,  # trpt_hub_radius UNSCALED — ring geometry fixed
                       p_base.trpt_rL_ratio,
                       n_lines, result.n_rings, n_lines)
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, p_base.m_ring,
                       p_base.m_blade * le^2)  # blade mass ∝ area (λ²); was unscaled
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    km = p_base.k_mppt * le^2  # k ∝ λ² for blade-only scaling (fixed ring radii)
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    # Use v5 when scaling bottom rings — it matches ring_spacing_v4 geometry
    if r_bottom_scale != 1.0
        sys, u0 = build_kite_turbine_system_v5(pc, result.design.target_Lr,
            result.design.r_bottom; expansion_rotors=expansion_params)
    else
        sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    end
    println("V10 Tight no-lowest: n_lines=$n_lines n_rotors=$n_exp rings=$n_rings mass=$(round(best.best_mass_kg, digits=2))kg blade_scale=$(blade_scale)")
    return sys, u0, pc, "V10 Tight (hub + $n_exp expansion rotors)"
end
