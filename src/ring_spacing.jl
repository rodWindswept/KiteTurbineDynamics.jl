# src/ring_spacing.jl
# v4 TRPT ring-spacing formulation: constant L/r targeting.
#
# Physics motivation
# ──────────────────
# In v2/v3, rings are uniformly spaced axially with radii interpolated along a
# profile curve. Uniform spacing with a tapered geometry creates unequal L/r per
# segment: thin bottom segments (small r) get the same axial L as wide top
# segments, giving them high L/r → near the Euler buckling limit → the optimiser
# is forced toward cylindrical geometry to equalise segment lengths.
#
# Key insight: L/r ≈ constant eliminates the L² buckling penalty from taper.
# With Do ∝ r^0.5 scaling:
#   I ∝ Do⁴ ∝ r²
#   P_crit = π²EI/L² ∝ r² / (c·r)² = 1/c² = constant  (c = target_Lr)
#   N_comp ≈ constant (axial thrust dominates)
#   → FoS uniform across all rings — no ring over- or under-designed.
#
# Ring positions: geometric series in radius
# ──────────────────────────────────────────
# For a linear taper r(z) = r_bot + (r_top-r_bot)·z/L and constant L_i/r_mid_i:
#   (r_i - r_{i+1}) / (α·(r_i+r_{i+1})/2) = target_Lr
#   ⟹  r_{i+1}/r_i = k  (constant ratio, geometric series)
#   where k = (2 - α·c)/(2 + α·c),  α = (r_top - r_bot)/L,  c = target_Lr
# Exact L/r_mid = target_Lr for all segments (not just approximately).
# n_rings is an output: determined by geometry, not specified by the optimiser.
#
# Design variables replacing n_rings + taper_ratio (v4 vs v2):
#   target_Lr  (bounds 0.4 – 2.0)   — slenderness of each segment
#   r_bottom   (bounds 0.3 m – max_ground_radius)  — ground ring radius

using LinearAlgebra, Statistics

# ── Constants ────────────────────────────────────────────────────────────────
const OPT_MAX_GROUND_RADIUS = 1.5   # m — deployment transport limit (flatbed trailer)
const TRPT_V4_DIM           = 9     # DoF count for v4 optimiser vector

# ── Core geometry function ───────────────────────────────────────────────────
"""
    ring_spacing_v4(r_top, r_bottom, tether_length, target_Lr; max_rings=20)
    → (z_positions, radii, n_rings)

Place polygon-frame rings along the TRPT shaft so every inter-ring segment
has L/r_mid ≈ target_Lr.

Algorithm: the constant-L/r constraint on a linearly tapered shaft forces radii
into a geometric series r_{i+1} = k·r_i where k = (r_bottom/r_top)^(1/n_segs).
n_segs is chosen by finding the integer nearest to the natural (continuous) value
log(r_bottom/r_top) / log(k_natural), then adjusting k so the series lands
exactly on r_bottom.  All segments then share the same L/r = actual_Lr ≈ target_Lr
(error bounded by the integer rounding of n_segs, typically < 2 %).

Special case r_top ≈ r_bottom (cylindrical): uniform spacing with L ≈ target_Lr·r.

Returns
  z_positions  — axial positions, ground=0 first, hub=tether_length last  (m)
  radii        — ring radii at each z_position, increasing ground→hub     (m)
  n_rings      — number of intermediate rings (total rings = n_rings + 2)
"""
function ring_spacing_v4(r_top::Float64,
                          r_bottom::Float64,
                          tether_length::Float64,
                          target_Lr::Float64;
                          max_rings::Int = 20)::Tuple{Vector{Float64}, Vector{Float64}, Int}

    r_top        > 0 || throw(ArgumentError("r_top must be positive"))
    r_bottom     > 0 || throw(ArgumentError("r_bottom must be positive"))
    r_top       >= r_bottom || throw(ArgumentError("r_top must be ≥ r_bottom"))
    tether_length > 0 || throw(ArgumentError("tether_length must be positive"))
    target_Lr    > 0 || throw(ArgumentError("target_Lr must be positive"))

    # ── Cylindrical degenerate case ──────────────────────────────────────────
    if (r_top - r_bottom) / r_top < 1e-9
        L_seg  = target_Lr * r_top
        n_segs = max(1, round(Int, tether_length / L_seg))
        n_segs = min(n_segs, max_rings + 1)
        n_tot  = n_segs + 1
        zs     = collect(range(0.0, tether_length, length=n_tot))
        rs     = fill(r_top, n_tot)
        return (zs, rs, n_segs - 1)
    end

    # ── General tapered case ─────────────────────────────────────────────────
    α = (r_top - r_bottom) / tether_length   # taper slope (m/m), positive

    # Natural geometric ratio for L/r_mid = target_Lr exactly:
    #   derived from (r_i - r_{i+1}) / (α·(r_i+r_{i+1})/2) = c
    c         = target_Lr
    k_natural = (2.0 - α * c) / (2.0 + α * c)
    if k_natural <= 0.0
        # target_Lr is so large that a single segment spans the full shaft;
        # clamp to 1 segment.
        zs = [0.0, tether_length]
        rs = [r_bottom, r_top]
        return (zs, rs, 0)
    end

    # Continuous number of segments needed to step from r_top down to r_bottom
    n_segs_natural = log(r_bottom / r_top) / log(k_natural)
    n_segs = clamp(round(Int, n_segs_natural), 1, max_rings + 1)

    # Adjust k so the geometric series lands exactly on r_bottom in n_segs steps
    k = (r_bottom / r_top)^(1.0 / n_segs)

    # Build radii from hub (index 1) down to ground (index n_segs+1)
    radii_hub_first = [r_top * k^i for i in 0:n_segs]
    radii_hub_first[end] = r_bottom   # force exact boundary

    # Compute z positions from the linear taper: z_i = (r_i - r_bottom) / α
    z_hub_first = [(r - r_bottom) / α for r in radii_hub_first]
    z_hub_first[1]   = tether_length  # force exact hub
    z_hub_first[end] = 0.0            # force exact ground

    # Return in ground-first order (ascending z)
    z_positions = reverse(z_hub_first)
    radii       = reverse(radii_hub_first)

    return (z_positions, radii, n_segs - 1)
end

# ── v4 design struct ─────────────────────────────────────────────────────────
"""
    TRPTDesignV4

TRPT structural design candidate using constant-L/r ring spacing.

Replaces (n_rings, taper_ratio, axial_profile, profile_exp, straight_frac)
from TRPTDesignV2 with two continuous variables:
  r_bottom   — ground ring radius (m), bounded by max_ground_radius
  target_Lr  — common L/r target for all segments

n_rings is computed from (r_hub, r_bottom, tether_length, target_Lr) and is
not a field of this struct.
"""
struct TRPTDesignV4
    beam_profile    :: BeamProfile
    Do_top          :: Float64
    t_over_D        :: Float64
    beam_aspect     :: Float64
    Do_scale_exp    :: Float64
    r_hub           :: Float64    # top (hub) ring radius
    r_bottom        :: Float64    # ground ring radius — design variable
    target_Lr       :: Float64    # target L/r for all segments — design variable
    tether_length   :: Float64
    n_lines         :: Int
    knuckle_mass_kg :: Float64
end

# ── Geometry helpers for v4 ──────────────────────────────────────────────────
"""
    ring_z_positions(design::TRPTDesignV4) → Vector{Float64}

Axial positions of all rings, ground-first (z=0) to hub (z=tether_length).
"""
function ring_z_positions(design::TRPTDesignV4)
    zs, _, _ = ring_spacing_v4(design.r_hub, design.r_bottom,
                                 design.tether_length, design.target_Lr)
    return zs
end

"""
    ring_radii(design::TRPTDesignV4) → Vector{Float64}

Radii of all rings in ground-first order.
"""
function ring_radii(design::TRPTDesignV4)
    _, rs, _ = ring_spacing_v4(design.r_hub, design.r_bottom,
                                 design.tether_length, design.target_Lr)
    return rs
end

"""
    segment_axial_lengths(design::TRPTDesignV4) → Vector{Float64}

Axial lengths of consecutive inter-ring segments (non-uniform in general).
"""
function segment_axial_lengths(design::TRPTDesignV4)
    zs = ring_z_positions(design)
    return diff(zs)
end

"""
    beam_spec_at_ring(design::TRPTDesignV4, r) → BeamSpec
"""
function beam_spec_at_ring(design::TRPTDesignV4, r::Float64)
    scale = (r / max(design.r_hub, 1e-12))^design.Do_scale_exp
    return BeamSpec(design.beam_profile,
                    design.Do_top * scale,
                    design.t_over_D,
                    design.beam_aspect)
end

# ── Structural evaluation for v4 ─────────────────────────────────────────────
"""
    evaluate_design(design::TRPTDesignV4; r_rotor, elev_angle, v_peak, fos_req,
                    omega_rotor, m_blade_total, max_ground_radius) → EvalResult

Structural evaluation using v4 constant-L/r ring geometry.

Identical physics to the v2 evaluator (Euler buckling of polygon segments,
centripetal off-loading of hub blades, compressive stress margin) but uses the
non-uniform axial spacings from ring_spacing_v4 instead of uniform spacing.

Additional feasibility constraint: design.r_bottom ≤ max_ground_radius
(deployment/transport limit on the ground ring footprint).
"""
function evaluate_design(design::TRPTDesignV4;
                          r_rotor          :: Float64 = 5.0,
                          elev_angle       :: Float64 = π/6,
                          v_peak           :: Float64 = OPT_V_PEAK,
                          fos_req          :: Float64 = OPT_FOS_REQUIRED,
                          omega_rotor      :: Float64 = 4.1 * OPT_V_PEAK / 5.0,
                          m_blade_total    :: Float64 = 11.0,
                          max_ground_radius:: Float64 = OPT_MAX_GROUND_RADIUS)

    # ── Ground ring deployment constraint ─────────────────────────────────
    if design.r_bottom > max_ground_radius
        return EvalResult(false, Inf, Inf, 0.0, 0.0, 0, Float64[], Float64[],
                          Float64[], Float64[], false,
                          "r_bottom exceeds max_ground_radius")
    end

    # ── Basic geometry sanity ─────────────────────────────────────────────
    if design.Do_top <= 0 || design.t_over_D <= 0 ||
       design.r_hub <= 0  || design.r_bottom <= 0  ||
       design.target_Lr <= 0 || design.n_lines < 3 ||
       design.knuckle_mass_kg <= 0
        return EvalResult(false, Inf, Inf, 0.0, 0.0, 0, Float64[], Float64[],
                          Float64[], Float64[], false, "invalid geometry")
    end

    # ── Compute ring positions ────────────────────────────────────────────
    zs, radii, _ = ring_spacing_v4(design.r_hub, design.r_bottom,
                                    design.tether_length, design.target_Lr)
    L_seg       = diff(zs)          # non-uniform axial segment lengths
    n_rings_tot = length(radii)
    n_seg       = length(L_seg)

    # ── Line tension distribution ─────────────────────────────────────────
    T_peak       = peak_hub_thrust(r_rotor, elev_angle; v=v_peak)
    T_line_axial = T_peak / design.n_lines

    # Pre-compute beam sections
    specs    = [beam_spec_at_ring(design, r) for r in radii]
    secprops = [beam_section_properties(s) for s in specs]
    A_ring   = [sp[1] for sp in secprops]
    I_ring   = [sp[2] for sp in secprops]

    m_blade_per_vertex = m_blade_total / design.n_lines

    # ── Per-ring structural analysis ──────────────────────────────────────
    fos_per_ring   = Float64[]
    Ncomp_per_ring = Float64[]
    Pcrit_per_ring = Float64[]
    Do_per_ring    = Float64[]
    min_fos        = Inf
    worst_idx      = 0
    torsion_ok     = true
    mass_beams     = 0.0

    for (i, r) in enumerate(radii)
        line_len_below = i > 1 ?
            sqrt(L_seg[i-1]^2 + (radii[i] - radii[i-1])^2) : L_seg[1]
        line_len_above = i < n_rings_tot ?
            sqrt(L_seg[i]^2   + (radii[i+1] - radii[i])^2) : L_seg[end]
        T_line = T_line_axial * max(line_len_below, line_len_above) /
                  min(L_seg[max(i-1, 1)], L_seg[min(i, n_seg)])

        F_in_per_vertex_aero = OPT_DESIGN_LOAD_FACTOR * T_line

        n_float = float(design.n_lines)
        L_poly  = 2.0 * r * sin(π / n_float)

        m_beam_per_vertex = OPT_RHO_CFRP * A_ring[i] * L_poly
        m_vertex = design.knuckle_mass_kg + m_beam_per_vertex +
                    (i == n_rings_tot ? m_blade_per_vertex : 0.0)

        F_centripetal = m_vertex * omega_rotor^2 * r
        F_v    = max(F_in_per_vertex_aero - F_centripetal, 0.0)
        N_comp = F_v / (2.0 * tan(π / n_float))

        P_crit = π^2 * OPT_E_CFRP * I_ring[i] / max(L_poly, 1e-12)^2

        is_buckling_ring = (i > 1 && i < n_rings_tot)
        if is_buckling_ring && N_comp > 0
            fos = P_crit / N_comp
            push!(fos_per_ring, fos)
            push!(Ncomp_per_ring, N_comp)
            push!(Pcrit_per_ring, P_crit)
            push!(Do_per_ring, specs[i].Do)
            if fos < min_fos
                min_fos   = fos
                worst_idx = i
            end
        else
            push!(fos_per_ring, Inf)
            push!(Ncomp_per_ring, 0.0)
            push!(Pcrit_per_ring, 0.0)
            push!(Do_per_ring, specs[i].Do)
        end

        if is_buckling_ring && A_ring[i] < (OPT_TORSION_MARGIN * abs(N_comp) / 5e8)
            torsion_ok = false
        end

        mass_beams += design.n_lines * OPT_RHO_CFRP * A_ring[i] * L_poly
    end

    mass_knuckles = design.knuckle_mass_kg * design.n_lines * n_rings_tot
    mass_total    = mass_beams + mass_knuckles

    feasible = (min_fos >= fos_req) && torsion_ok &&
               (design.t_over_D >= OPT_T_OVER_D_MIN) &&
               (design.t_over_D <= OPT_T_OVER_D_MAX)
    msg = feasible ? "OK" :
          (!torsion_ok ? "compressive stress > 500 MPa limit" :
           min_fos < fos_req ?
               "FOS $(round(min_fos, digits=2)) < $fos_req at ring $worst_idx" :
           "t/D out of manufacturable bounds")

    return EvalResult(feasible, mass_total, mass_beams, mass_knuckles,
                      min_fos, worst_idx, fos_per_ring, Ncomp_per_ring,
                      Pcrit_per_ring, Do_per_ring, torsion_ok, msg)
end

# ── v4 search space ───────────────────────────────────────────────────────────
"""
Vector layout for v4 optimisation (9 DoF):

  x[1]  Do_top              [m]    beam outer dim at hub ring
  x[2]  t_over_D            [-]    wall thickness ratio
  x[3]  beam_aspect         [-]    ellip b/a or airfoil t/c
  x[4]  Do_scale_exp        [-]    Do(r) = Do_top·(r/r_hub)^exp
  x[5]  r_hub               [m]    hub ring radius (= r_top)
  x[6]  r_bottom            [m]    ground ring radius  ← NEW (replaces taper_ratio)
  x[7]  target_Lr           [-]    common L/r target   ← NEW (replaces n_rings float)
  x[8]  knuckle_mass_kg     [kg]   per-vertex point mass
  x[9]  n_lines             [int]  polygon sides 3..8
"""
function search_bounds_v4(p::SystemParams, beam_profile::BeamProfile;
                           max_ground_radius::Float64 = OPT_MAX_GROUND_RADIUS)
    sc     = sqrt(p.trpt_hub_radius / 2.0)
    Do_lo  = 0.005 * sc;  Do_hi = 0.120 * sc

    r_hub_lo = 0.80 * p.trpt_hub_radius
    r_hub_hi = 1.20 * p.trpt_hub_radius

    r_bot_lo = 0.3
    r_bot_hi = max_ground_radius

    Lr_lo = 0.4;  Lr_hi = 2.0

    knuckle_lo = 0.010;  knuckle_hi = 0.200
    n_lines_lo = 3.0;    n_lines_hi = 8.0

    ar_lo, ar_hi = if beam_profile == PROFILE_ELLIPTICAL
        0.25, 1.0
    elseif beam_profile == PROFILE_AIRFOIL
        0.08, 0.20
    else
        1.0, 1.0
    end

    lo = [Do_lo, OPT_T_OVER_D_MIN, ar_lo, 0.0,
          r_hub_lo, r_bot_lo, Lr_lo, knuckle_lo, n_lines_lo]
    hi = [Do_hi, OPT_T_OVER_D_MAX, ar_hi, 1.0,
          r_hub_hi, r_bot_hi, Lr_hi, knuckle_hi, n_lines_hi]
    return lo, hi
end

function design_from_vector_v4(x::AbstractVector,
                                 beam_profile::BeamProfile,
                                 p::SystemParams;
                                 max_ground_radius::Float64 = OPT_MAX_GROUND_RADIUS)
    n_lines = clamp(Int(round(x[9])), 3, 8)
    r_hub   = x[5]
    r_bot   = clamp(x[6], 0.1, max_ground_radius)
    # Ensure r_bottom ≤ r_hub (ground ring never wider than hub ring)
    r_bot   = min(r_bot, r_hub)
    return TRPTDesignV4(
        beam_profile,
        x[1],                            # Do_top
        x[2],                            # t_over_D
        x[3],                            # beam_aspect
        x[4],                            # Do_scale_exp
        r_hub,                           # r_hub
        r_bot,                           # r_bottom
        clamp(x[7], 0.1, 5.0),           # target_Lr
        p.tether_length,
        n_lines,
        x[8],                            # knuckle_mass_kg
    )
end

function objective_v4(x::AbstractVector, beam_profile::BeamProfile, p::SystemParams;
                       rotor_radius::Float64     = 5.0,
                       elev_angle::Float64       = π/6,
                       v_peak::Float64           = OPT_V_PEAK,
                       max_ground_radius::Float64 = OPT_MAX_GROUND_RADIUS)
    design = design_from_vector_v4(x, beam_profile, p;
                                    max_ground_radius=max_ground_radius)
    r      = evaluate_design(design; r_rotor=rotor_radius, elev_angle=elev_angle,
                              v_peak=v_peak, max_ground_radius=max_ground_radius)
    return r.feasible ? r.mass_total_kg : 1e6 + r.mass_total_kg
end

# ── Baseline v4 design ────────────────────────────────────────────────────────
function baseline_design_v4(p::SystemParams)::TRPTDesignV4
    r_hub  = p.trpt_hub_radius
    Do_top = 0.01396 * sqrt(r_hub)
    return TRPTDesignV4(
        PROFILE_CIRCULAR,
        Do_top, 0.05, 1.0, 0.5,
        r_hub,
        0.48 * r_hub,    # r_bottom = 0.48·r_hub (same ratio as baseline taper)
        1.0,             # target_Lr = 1.0 (moderate slenderness)
        p.tether_length,
        p.n_lines,
        OPT_KNUCKLE_MASS_KG,
    )
end
