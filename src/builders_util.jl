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
using JSON3

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
    # n_lines (x[8]) and rotor_mask (x[10]) are decoded and clamped by the
    # authoritative decoder chain — design_from_vector_v4 (ring_spacing.jl:408,
    # n_lines ∈ [3,12]) and decode_rotor_mask (objective_v10.jl:69, mask ∈ [0,59]).
    # No pre-clamp here: a duplicate [3,16]/[0,60] pre-clamp used to disagree with
    # the decoder bounds (removed 2026-07-18, single-authority fix; outcome
    # bit-identical, guarded by test/test_documented_claims.jl).

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

    n_rotor_label = n_exp
    rot_label = string(n_rotor_label, " expansion rotors")
    r_bot_str = r_bottom_scale != 1.0 ? " r_bot×$(r_bottom_scale)" : ""
    bl_s_str  = blade_scale != 1.0 ? " blade×$(blade_scale)" : ""
    label_short = "V10 $(design.n_lines)-gon $(result.n_rings) rings$r_bot_str$bl_s_str ($rot_label)"

    println("$(label_short): n_lines=$(n_lines) n_rotors=$(n_exp) rings=$(n_rings) r_hub=$(round(design.r_hub,digits=3)) r_bot=$(round(design.r_bottom,digits=3))")

    return sys, u0, pc, label_short, design
end

# ═══════════════════════════════════════════════════════════════════════════
# PHANTOM TRIANGLE — deliberate faithful rebuild of the pre-fix system
# ═══════════════════════════════════════════════════════════════════════════
#
# Before 2026-07-17 the builder above hand-packed best_design.json fields in
# JSON order into the v4 decoder layout, producing a 3-line/22-ring/untapered
# (~2.99 m) system with λ gradient 1.0→0.88 and bank 25°/4° — NOT the 12-gon
# campaign winner.  All results shared with Strathclyde (0.85·k2: 117 kW @
# 11 m/s etc.) are THIS system.
#
# Decision (Rod, 2026-07-17): rebuild it deliberately so those results become
# "verified simulation of a now-deliberately-specified design" instead of
# "artifact of a bug".  This function reproduces the scrambled pack VERBATIM
# (including the r_bottom double-application and the rev-sort drop) so its
# output is bit-identical to the phantom.  Gate: kickstart protocol at
# blade=0.85, k=2, 11 m/s must reproduce 117.4 kW @ 411 rpm FoS 4.5
# (wind_sweep_triangle_legacy.csv row 4).
#
# Scrambled decode map (JSON-order pack → v4 decoder):
#   packed r_hub(2.889)      → decoder Do_top
#   packed r_bottom(2.0)     → decoder t_over_D
#   packed Do_top(0.06)      → decoder beam_aspect
#   packed t_over_D(0.01)    → decoder Do_scale_exp
#   packed target_Lr(2.99)   → decoder r_hub      (untapered ~2.99 m radius)
#   packed n_lines(12)       → decoder r_bottom   (→ clamped)
#   packed density(-0.11)    → decoder target_Lr
#   packed 0.519             → decoder n_lines    (clamp 3..16 → 3 = TRIANGLE)
#   packed 0.10              → decoder density_profile
#   packed 32.0              → decoder rotor_mask
#   packed 35.0              → decoder bank_top   (clamp → 25°)
#   packed n_active(4)       → decoder bank_bottom (4°)
#   packed 1.0               → decoder λ_top
#   packed aspect(0.88)      → decoder λ_bottom   (λ gradient 1.0→0.88)

"""
    build_phantom_triangle(; kwargs...)

Deliberate faithful rebuild of the pre-2026-07-17 "V10 Tight" system: 3-line
triangle frame, 22 rings, untapered ~2.99 m, λ gradient 1.0→0.88, bank 25°/4°.
Reproduces the scrambled JSON-order pack verbatim.  See block comment above.

Returns `(sys, u0, p, label, design)`.
"""
function build_phantom_triangle(;
    tether_diameter::Float64=0.003,
    r_bottom_scale::Float64=1.0,
    r_hub_scale::Float64=1.0,
    blade_scale::Float64=1.0,
    keep_lowest::Bool=false,
    do_scale::Float64=1.0,
    t_scale::Float64=1.0,
)
    drop = !keep_lowest
    best_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_design.json")
    isfile(best_path) || error("best_design.json not found at $best_path")
    best = JSON3.read(read(best_path, String))
    # NOTE: everything below is a verbatim resurrection of the pre-fix code,
    # including its bugs (r_bottom double-application; rev-sort "drop lowest"
    # actually removing the hub-adjacent rotor).  DO NOT "fix" — fidelity to
    # the legacy results is the whole point.
    r_hub_s = max(r_hub_scale, r_bottom_scale * best.r_bottom_m / max(best.r_hub_m, 1e-9))
    x = Float64[
        best.r_hub_m * r_hub_s, best.r_bottom_m * r_bottom_scale,
        best.Do_top_m, best.t_over_D,
        best.target_Lr, Float64(best.n_lines), best.density_profile,
        0.519, 0.10, 32.0, 35.0,
        Float64(best.n_active_rotors), 1.0, best.aspect_ratio, 1.0
    ]
    x[2] *= r_bottom_scale       # legacy double-application (deliberate)
    x[3] *= do_scale
    x[4] *= t_scale
    result = design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                     max_ground_radius=5.0, power_W=50000.0)
    rotors = sort(result.rotors, by=r -> r.ring_idx, rev=true)
    if drop && length(rotors) > 1
        dropped = popfirst!(rotors)   # legacy: removes HIGHEST ring_idx (hub-adjacent)
        println("Phantom: dropped hub-adjacent expansion rotor at ring $(dropped.ring_idx) (legacy 'drop lowest' behaviour)")
    end
    n_exp = length(rotors)
    n_lines = result.design.n_lines
    n_rings = result.n_rings
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        sr = rotor.ring_idx == n_rings ? n_rings + 2 : rotor.ring_idx + 1
        er = ExpansionRotorParams(
            n_lines,
            rotor.blade_tip_radius * blade_scale,
            rotor.blade_hub_radius * blade_scale,
            rotor.blade_chord * blade_scale,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg,
            expansion_blade_mass(rotor.blade_tip_radius * blade_scale, blade_scale),
            sr, 1.0,
        )
        push!(expansion_params, er)
    end
    p_base = params_v5_50kw()
    le = blade_scale
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0 * le,
                       result.design.tether_length, result.design.r_hub,
                       p_base.trpt_rL_ratio,
                       n_lines, result.n_rings, n_lines)
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, p_base.m_ring,
                       p_base.m_blade * le^2)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    km = p_base.k_mppt * le^2
    ctrl = ControlSpec(p_base.i_pto, km, p_base.p_rated_w, p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)
    if r_bottom_scale != 1.0
        sys, u0 = build_kite_turbine_system_v5(pc, result.design.target_Lr,
            result.design.r_bottom; expansion_rotors=expansion_params)
    else
        sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    end
    println("Phantom triangle: n_lines=$n_lines n_rotors=$n_exp rings=$n_rings blade_scale=$(blade_scale)")
    sys.ring_Do_top[] = best.Do_top_m * do_scale
    sys.ring_toverD[] = best.t_over_D * t_scale
    sys.ring_aspect_ratio[] = best.aspect_ratio
    return sys, u0, pc, "Phantom triangle (hub + $n_exp expansion rotors)", result.design
end

# ═══════════════════════════════════════════════════════════════════════════
# GEOMETRY FINGERPRINT — print what was built, every time (Phase 2b)
# ═══════════════════════════════════════════════════════════════════════════

"""
    geometry_fingerprint(sys, p, design; blade_scale=1.0) -> String

Absolute geometry record for CSV sidecars/headers: n_lines, rings, ring radii,
per-rotor blade count/tip/chord/area/mass, total blade area, hub disk radius.
Prevents cross-configuration tables from hiding a λ-reference shift.
"""
function geometry_fingerprint(sys, p, design; blade_scale::Float64=1.0)
    io = IOBuffer()
    println(io, "# geometry_fingerprint")
    println(io, "# n_lines=$(p.n_lines) n_rings=$(p.n_rings) tether_length=$(round(design.tether_length,digits=2))m")
    println(io, "# r_hub=$(round(design.r_hub,digits=4))m r_bottom=$(round(design.r_bottom,digits=4))m taper=$(design.r_hub ≈ design.r_bottom ? "none" : round(design.r_bottom/design.r_hub,digits=3))")
    println(io, "# blade_scale=$(blade_scale) hub_disk_radius=$(round(p.rotor_radius,digits=3))m")
    total_area = 0.0
    total_mass = 0.0
    for (i, er) in enumerate(sys.expansion_rotors)
        span = er.blade_tip_radius - er.blade_hub_radius
        area = er.n_blades * er.blade_chord * span
        total_area += area
        total_mass += er.mass * er.n_blades
        println(io, "# rotor$(i): ring=$(er.ring_idx) n_blades=$(er.n_blades) tip=$(round(er.blade_tip_radius,digits=3))m chord=$(round(er.blade_chord,digits=3))m span=$(round(span,digits=3))m area=$(round(area,digits=3))m² bank=$(round(er.bank_angle_deg,digits=1))° mass=$(round(er.mass,digits=3))kg")
    end
    println(io, "# total_blade_area=$(round(total_area,digits=3))m² total_blade_mass=$(round(total_mass,digits=3))kg n_rotors=$(length(sys.expansion_rotors))")
    return String(take!(io))
end
