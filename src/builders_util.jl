# src/builders_util.jl
#
# V10 system builder functions — formerly scripts/builders_util.jl.
# Included into KiteTurbineDynamics; all KTD symbols and JSON3 are available
# from the parent module. No `using` needed here.
#
# 2026-07-17: x-vector packing fix (Phase 1 of fix_xvector_rerun_sweeps.md).
# _build_v10_tight now loads best_vector.csv directly and feeds it to
# design_from_vector_v10 in the correct v4 field order.  Previously it
# packed best_design.json fields into the wrong decoder layout, producing
# a phantom 3-line/22-ring/untapered triangle system.

import KiteTurbineDynamics: expansion_blade_mass

"""
    build_v10_tight()

Build the V10 campaign winner from best_vector.csv.  Reads the raw design
vector and decodes it via `design_from_vector_v10`.

Returns `(sys, u0, p, label, design)`.
"""
function build_v10_tight(;
    tether_diameter::Float64=0.003,
    r_bottom_scale::Float64=1.0,
    r_hub_scale::Float64=1.0,
    blade_scale::Float64=1.0,
    keep_lowest::Bool=false,
    do_scale::Float64=1.0,
    t_scale::Float64=1.0,
)
    return _build_v10_tight(; tether_diameter, r_bottom_scale, r_hub_scale, blade_scale, keep_lowest, drop=!keep_lowest, do_scale, t_scale)
end

function build_v10_tight_no_lowest(;
    tether_diameter::Float64=0.003,
    r_bottom_scale::Float64=1.0,
    r_hub_scale::Float64=1.0,
    blade_scale::Float64=1.0,
    do_scale::Float64=1.0,
    t_scale::Float64=1.0,
)
    return _build_v10_tight(; tether_diameter, r_bottom_scale, r_hub_scale, blade_scale, keep_lowest=false, drop=true, do_scale, t_scale)
end

function _build_v10_tight(;
    tether_diameter::Float64, r_bottom_scale::Float64,
    r_hub_scale::Float64, blade_scale::Float64,
    keep_lowest::Bool, drop::Bool,
    do_scale::Float64, t_scale::Float64,
)
    # ── Load winner vector from CSV (correct v4 field order) ──
    vec_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_vector.csv")
    isfile(vec_path) || error("best_vector.csv not found at $vec_path")
    x_raw = parse.(Float64, split(readline(vec_path), ","))
    x = copy(x_raw)
    # v4 layout: Do_top, t_over_D, beam_aspect, Do_scale_exp, r_hub, r_bottom,
    #            target_Lr, n_lines, density_profile, rotor_mask,
    #            bank_top, bank_bottom, λ_top, λ_bottom
    x[8]  = Float64(round(Int, clamp(x[8], 3, 16)))         # n_lines → integer
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))       # rotor_mask

    # ── Apply kwargs post-decode (see Gate 1c note: r_bottom scaling once) ──
    x[3] *= do_scale       # beam_aspect → Do_top effective
    x[4] *= t_scale        # t_over_D effective
    x[5] *= r_hub_scale    # r_hub
    x[6] *= r_bottom_scale # r_bottom — applied ONCE (was double-applied before fix)
    # Enforce taper: r_bottom ≤ r_hub
    if x[6] > x[5]
        x[6] = x[5]
    end

    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     max_ground_radius=5.0, power_W=50000.0)
    design = result.design
    rotors = copy(result.rotors)
    n_lines = design.n_lines
    n_rings = result.n_rings

    # ── Drop ground-adjacent expansion rotor (Gate 1b) ──
    if drop && length(rotors) > 1
        sort!(rotors, by=r -> r.ring_idx)          # ascending: lowest ring_idx first
        dropped = popfirst!(rotors)                  # removes ground-adjacent
        println("Dropped ground-adjacent expansion rotor at ring $(dropped.ring_idx)")
    end
    n_exp = length(rotors)

    # ── Build expansion params (Gate 1c: n_blades = n_lines for balanced polygon) ──
    expansion_params = ExpansionRotorParams[]
    sys_n_rings_total = n_rings + 2
    for rotor in rotors
        sys_ring = rotor.ring_idx == n_rings ? sys_n_rings_total : rotor.ring_idx + 1
        er = ExpansionRotorParams(
            n_lines,
            rotor.blade_tip_radius * blade_scale,
            rotor.blade_hub_radius * blade_scale,
            rotor.blade_chord * blade_scale,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg,
            expansion_blade_mass(rotor.blade_tip_radius * blade_scale, blade_scale),
            sys_ring, 1.0,
        )
        push!(expansion_params, er)
    end

    p_base = params_v5_50kw()
    le = blade_scale
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0 * le,
                       design.tether_length, design.r_hub,
                       p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, p_base.m_ring,
                       p_base.m_blade * le^2)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)

    # Use single builder for all r values (was separately branched for r_bottom_scale≠1.0,
    # which caused the catalog-vs-wind_sweep discrepancy)
    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)

    # Populate ring geometry from decoded design (not JSON — JSON order was wrong)
    sys.ring_Do_top[]       = x[1]  # Do_top (with do_scale applied)
    sys.ring_toverD[]       = x[2]  # t_over_D (with t_scale applied)
    sys.ring_aspect_ratio[] = x[3]  # beam_aspect

    n_rotor_label = drop ? n_exp : n_exp + 1
    rot_label = string(n_rotor_label, " expansion rotors")
    r_bot_str = r_bottom_scale != 1.0 ? " r_bot×$(r_bottom_scale)" : ""
    bl_s_str  = blade_scale != 1.0 ? " blade×$(blade_scale)" : ""
    label_short = "V10 $(design.n_lines)-gon $(result.n_rings) rings$r_bot_str$bl_s_str ($rot_label)"

    println("$(label_short): n_lines=$(n_lines) n_rotors=$(n_exp) rings=$(n_rings) r_hub=$(round(design.r_hub,digits=3)) r_bot=$(round(design.r_bottom,digits=3))")

    return sys, u0, pc, label_short, design
end
