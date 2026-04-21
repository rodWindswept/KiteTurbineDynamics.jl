# src/trpt_axial_profiles.jl
# Phase A of the 168-h Design Cartography programme (Item B2 extension).
#
# Extends trpt_optimization.jl with a family of radial-vs-axial profiles so the
# optimizer can explore non-linear tapers — elliptic, parabolic, trumpet, and
# a straight-bottom-then-grow profile that matches the historical Grasshopper
# design studies.
#
# Each profile maps axial coordinate z ∈ [0, L] to local pentagon radius r(z).
# The curve is fully defined by:
#   (AxialProfile, profile_exp, straight_frac, taper_ratio, r_hub, tether_length)
#
# The Do-scaling along length now uses the *same* profile family applied to Do(z):
#   Do(z) = Do_top · (r(z) / r_hub)^Do_scale_exp
# (so a thinner ring naturally gets a thinner tube under the r-driven square-root
# scaling law from structural_safety.jl).
#
# ── n_lines coupling (Phase A direction, 2026-04-20) ────────────────────────
# In the TRPT topology, the polygon spacer count is identical to the line count
# and the blade count. Making n_lines a design variable therefore modifies
# simultaneously:
#   • n_polygon_sides = n_lines   (pentagon = 5, hexagon = 6, …)
#   • n_lines         = n_lines   (tether lines running the axial length)
#   • n_blades        = n_lines   (one blade per vertex on the hub ring)
# The structural pentagon analysis already consumes n_lines through tan(π/n_lines)
# and the blade centripetal term now consumes the same n_lines through m_blade_total
# distributed across n_lines hub vertices. The three quantities must always remain
# equal in this model.
#
# ── Centripetal acceleration (Phase B direction, 2026-04-20) ─────────────────
# Each vertex of radius r spinning at ω_rotor experiences an outward centrifugal
# force m_lumped · ω² · r (reactive in the rotating frame). This force *subtracts*
# from the inward force delivered by line tension, so pentagon-beam compression is
# N_comp = max(0, (F_inward − F_centripetal)) / (2 tan(π/n))
# At rated ω ≈ 20 rad/s and peak v_sizing the blade mass on the hub ring produces
# hundreds of newtons of outward force, so this term is structurally non-negligible.

using LinearAlgebra

# ── Axial radius profile family ──────────────────────────────────────────────
@enum AxialProfile begin
    AXIAL_LINEAR         = 1  # r(z) = r_bot + (r_top - r_bot)(z/L)
    AXIAL_ELLIPTIC       = 2  # r(z) = r_bot + (r_top - r_bot) sin(π/2 · z/L)  ; flat-near-ground, steep-near-hub
    AXIAL_PARABOLIC      = 3  # r(z) = r_bot + (r_top - r_bot)(z/L)^p          ; p<1 concave, p>1 convex
    AXIAL_TRUMPET        = 4  # r(z) = r_bot + (r_top - r_bot)(1-(1-z/L)^p)    ; steep-near-ground, flat-near-hub
    AXIAL_STRAIGHT_TAPER = 5  # constant r_bot for z < z_str, linear to r_top after
end

const AXIAL_PROFILE_COUNT = 5

axial_profile_name(p::AxialProfile) =
    p == AXIAL_LINEAR         ? "linear"         :
    p == AXIAL_ELLIPTIC       ? "elliptic"       :
    p == AXIAL_PARABOLIC      ? "parabolic"      :
    p == AXIAL_TRUMPET        ? "trumpet"        :
    p == AXIAL_STRAIGHT_TAPER ? "straight_taper" : "unknown"

axial_profile_from_index(i::Integer) =
    AxialProfile(clamp(Int(i), 1, AXIAL_PROFILE_COUNT))

# ── Core r(z) evaluator ──────────────────────────────────────────────────────
"""
    r_of_z(axial_profile, profile_exp, straight_frac, r_bot, r_top, L, z) → radius (m)

Radial coordinate r at axial position z (ground z=0, hub z=L).
"""
function r_of_z(axial_profile::AxialProfile,
                 profile_exp::Float64,
                 straight_frac::Float64,
                 r_bot::Float64,
                 r_top::Float64,
                 L::Float64,
                 z::Float64)::Float64
    ζ = clamp(z / max(L, 1e-12), 0.0, 1.0)
    Δr = r_top - r_bot
    if axial_profile == AXIAL_LINEAR
        return r_bot + Δr * ζ
    elseif axial_profile == AXIAL_ELLIPTIC
        return r_bot + Δr * sin(π/2 * ζ)
    elseif axial_profile == AXIAL_PARABOLIC
        p = clamp(profile_exp, 0.2, 4.0)
        return r_bot + Δr * ζ^p
    elseif axial_profile == AXIAL_TRUMPET
        p = clamp(profile_exp, 0.2, 4.0)
        return r_bot + Δr * (1.0 - (1.0 - ζ)^p)
    elseif axial_profile == AXIAL_STRAIGHT_TAPER
        # straight bottom portion then linear ramp
        ζ_str = clamp(straight_frac, 0.0, 0.9)
        if ζ <= ζ_str
            return r_bot
        else
            ζ_eff = (ζ - ζ_str) / (1.0 - ζ_str)
            return r_bot + Δr * ζ_eff
        end
    else
        return r_bot + Δr * ζ
    end
end

# ── Enriched design object ───────────────────────────────────────────────────
"""
    TRPTDesignV2

Full specification of an enriched TRPT structural design candidate.

Includes axial-profile family, knuckle mass as a free DoF, and n_lines as a
free DoF (for the pentagon → hexagon → heptagon exploration).
"""
struct TRPTDesignV2
    # Cross-section
    beam_profile    :: BeamProfile
    Do_top          :: Float64    # outer dim at hub (top) ring (m)
    t_over_D        :: Float64
    beam_aspect     :: Float64    # ellip b/a, or airfoil t/c
    Do_scale_exp    :: Float64    # Do(r) ~ (r/r_top)^exp
    # Axial geometry
    axial_profile   :: AxialProfile
    profile_exp     :: Float64    # parabolic / trumpet exponent
    straight_frac   :: Float64    # fraction of axial length constant r for STRAIGHT_TAPER
    r_hub           :: Float64
    taper_ratio     :: Float64    # r_bot / r_top
    n_rings         :: Int
    tether_length   :: Float64
    # Topology & knuckles
    n_lines         :: Int
    knuckle_mass_kg :: Float64
end

# ── Geometry helpers for v2 designs ──────────────────────────────────────────
"""
    ring_z_positions(design) → Vector{Float64}

Axial position (ground-relative, m) of each of the n_rings+2 pentagon frames.
Uniform axial spacing: ground @ 0, hub @ L.
"""
function ring_z_positions(design::TRPTDesignV2)
    n_total = design.n_rings + 2
    return [design.tether_length * (i - 1) / (n_total - 1) for i in 1:n_total]
end

"""
    ring_radii(design::TRPTDesignV2) → Vector{Float64}

Radii (m) of all n_rings+2 pentagon frames for a v2 design.
"""
function ring_radii(design::TRPTDesignV2)
    r_top = design.r_hub
    r_bot = design.r_hub * design.taper_ratio
    L     = design.tether_length
    zs    = ring_z_positions(design)
    return [r_of_z(design.axial_profile, design.profile_exp, design.straight_frac,
                   r_bot, r_top, L, z) for z in zs]
end

"""
    segment_axial_lengths(design::TRPTDesignV2) → Vector{Float64}

Uniform axial spacing between adjacent rings.
"""
function segment_axial_lengths(design::TRPTDesignV2)
    n_seg = design.n_rings + 1
    return fill(design.tether_length / n_seg, n_seg)
end

"""
    beam_spec_at_ring(design::TRPTDesignV2, r) → BeamSpec

Return the beam spec at a ring of radius r using Do(r) = Do_top · (r/r_top)^exp.
"""
function beam_spec_at_ring(design::TRPTDesignV2, r::Float64)
    scale = (r / max(design.r_hub, 1e-12))^design.Do_scale_exp
    return BeamSpec(design.beam_profile,
                    design.Do_top * scale,
                    design.t_over_D,
                    design.beam_aspect)
end

# ── Enriched evaluation ──────────────────────────────────────────────────────
"""
    evaluate_design(design::TRPTDesignV2; r_rotor, elev_angle, v_peak, fos_req,
                    omega_rotor, m_blade_total) → EvalResult

Extended structural evaluation for v2 designs. Uses the new curve family for
ring_radii and now subtracts per-vertex centripetal force from the inward
line load before computing polygon-beam compression.

Keyword args:
  r_rotor       -- rotor tip radius (m), used to compute peak hub thrust
  elev_angle    -- TRPT shaft elevation (rad)
  v_peak        -- peak design wind for T_peak (m/s)
  fos_req       -- required factor of safety
  omega_rotor   -- rotor angular velocity (rad/s) for centripetal term.
                   Default: λ_opt · v_peak / r_rotor with λ_opt = 4.1.
  m_blade_total -- total blade mass (kg). Lumped to hub ring only. Default 11 kg.
"""
function evaluate_design(design::TRPTDesignV2;
                          r_rotor     :: Float64 = 5.0,
                          elev_angle  :: Float64 = π/6,
                          v_peak      :: Float64 = OPT_V_PEAK,
                          fos_req     :: Float64 = OPT_FOS_REQUIRED,
                          omega_rotor :: Float64 = 4.1 * OPT_V_PEAK / 5.0,
                          m_blade_total :: Float64 = 11.0)

    # Validity sanity
    if design.Do_top <= 0 || design.t_over_D <= 0 ||
       design.n_rings < 3 || design.taper_ratio <= 0 ||
       design.r_hub <= 0 || design.n_lines < 3 || design.knuckle_mass_kg <= 0
        return EvalResult(false, Inf, Inf, 0.0, 0.0, 0, Float64[], Float64[],
                          Float64[], Float64[], false, "invalid geometry")
    end

    radii       = ring_radii(design)
    L_seg       = segment_axial_lengths(design)
    n_rings_tot = length(radii)
    n_seg       = length(L_seg)

    # ── Line tension distribution ────────────────────────────────────────────
    T_peak       = peak_hub_thrust(r_rotor, elev_angle; v=v_peak)
    T_line_axial = T_peak / design.n_lines

    # Pre-compute beam sections so we can use A[i] for centripetal mass
    specs = [beam_spec_at_ring(design, r) for r in radii]
    secprops = [beam_section_properties(s) for s in specs]
    A_ring = [sp[1] for sp in secprops]
    I_ring = [sp[2] for sp in secprops]

    # Blade mass lumped to hub vertex (one blade per n_lines vertex)
    m_blade_per_vertex = m_blade_total / design.n_lines

    # ── Per-ring analysis ────────────────────────────────────────────────────
    fos_per_ring    = Float64[]
    Ncomp_per_ring  = Float64[]
    Pcrit_per_ring  = Float64[]
    Do_per_ring     = Float64[]
    min_fos         = Inf
    worst_idx       = 0
    torsion_ok      = true
    mass_beams      = 0.0

    for (i, r) in enumerate(radii)
        # Local line-length multiplier picks up taper steepness
        line_len_below = i > 1 ?
            sqrt(L_seg[i-1]^2 + (radii[i] - radii[i-1])^2) : L_seg[1]
        line_len_above = i < n_rings_tot ?
            sqrt(L_seg[i]^2 + (radii[i+1] - radii[i])^2) : L_seg[end]
        T_line = T_line_axial * max(line_len_below, line_len_above) /
                  min(L_seg[max(i-1,1)], L_seg[min(i, n_seg)])
        F_in_per_vertex_aero = OPT_DESIGN_LOAD_FACTOR * T_line

        n_float = float(design.n_lines)
        L_poly  = 2.0 * r * sin(π / n_float)

        # Lumped vertex mass: knuckle + half of each adjacent polygon side.
        # Per-vertex beam mass = ρ·A·L_poly (two half-beams, total one full side).
        m_beam_per_vertex = OPT_RHO_CFRP * A_ring[i] * L_poly
        m_vertex = design.knuckle_mass_kg + m_beam_per_vertex +
                    (i == n_rings_tot ? m_blade_per_vertex : 0.0)

        # Centripetal (outward) force on each vertex reduces compression load.
        F_centripetal_per_vertex = m_vertex * omega_rotor^2 * r

        # Net inward force must be ≥ 0 (otherwise line would go slack, but we
        # still require structural FOS to handle the compressive case, so floor
        # the subtraction at 0 — centripetal excess never reduces compression
        # below zero for feasibility purposes, it just means the line is slack).
        F_v = max(F_in_per_vertex_aero - F_centripetal_per_vertex, 0.0)
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

        # Compressive stress floor check (same 500 MPa allowable as v1)
        if is_buckling_ring && A_ring[i] < (OPT_TORSION_MARGIN * abs(N_comp) / 5e8)
            torsion_ok = false
        end

        # Beam mass: n_lines polygon sides, each length L_poly, area A, density ρ
        mass_beams += design.n_lines * OPT_RHO_CFRP * A_ring[i] * L_poly
    end

    # Knuckle mass contribution (one per vertex per ring)
    n_vertices    = design.n_lines * n_rings_tot
    mass_knuckles = design.knuckle_mass_kg * n_vertices
    mass_total    = mass_beams + mass_knuckles

    feasible = (min_fos >= fos_req) && torsion_ok &&
               (design.t_over_D >= OPT_T_OVER_D_MIN) &&
               (design.t_over_D <= OPT_T_OVER_D_MAX)
    msg = feasible ? "OK" :
          (!torsion_ok ? "compressive stress > 500 MPa limit" :
           min_fos < fos_req ? "FOS $(round(min_fos, digits=2)) < $fos_req at ring $worst_idx" :
           "t/D out of manufacturable bounds")

    return EvalResult(feasible, mass_total, mass_beams, mass_knuckles,
                      min_fos, worst_idx, fos_per_ring, Ncomp_per_ring,
                      Pcrit_per_ring, Do_per_ring, torsion_ok, msg)
end

# ── Extended search space (14 DoF) ───────────────────────────────────────────
"""
Vector layout for v2 optimization:

  x[1]  Do_top              [m]         beam cross-section outer dim at hub
  x[2]  t_over_D            [-]         wall thickness ratio
  x[3]  beam_aspect         [-]         ellip minor/major or airfoil t/c
  x[4]  Do_scale_exp        [-]         Do(r) = Do_top·(r/r_top)^exp
  x[5]  r_hub               [m]         hub ring radius
  x[6]  taper_ratio         [-]         r_bot / r_top
  x[7]  n_rings             [float→int] count of intermediate pentagon spacers
  x[8]  axial_profile       [float→int] 1..5 enum index
  x[9]  profile_exp         [-]         parabolic/trumpet exponent
  x[10] straight_frac       [-]         fraction constant r (STRAIGHT_TAPER only)
  x[11] knuckle_mass_kg     [kg]        per-vertex point mass
  x[12] n_lines             [float→int] pentagon→heptagon exploration (3..8)
"""
const TRPT_V2_DIM = 12

function search_bounds_v2(p::SystemParams, beam_profile::BeamProfile)
    sc = sqrt(p.trpt_hub_radius / 2.0)
    Do_lo = 0.005 * sc;  Do_hi = 0.120 * sc

    r_hub_lo = 0.80 * p.trpt_hub_radius
    r_hub_hi = 1.20 * p.trpt_hub_radius
    taper_lo = max(0.15, 0.5 / p.trpt_hub_radius)
    taper_hi = 1.0
    n_rings_lo = 5.0
    n_rings_hi = 50.0
    axial_lo = 1.0
    axial_hi = Float64(AXIAL_PROFILE_COUNT)
    profile_exp_lo = 0.3
    profile_exp_hi = 3.5
    straight_frac_lo = 0.0
    straight_frac_hi = 0.70
    knuckle_lo = 0.010
    knuckle_hi = 0.200
    n_lines_lo = 3.0
    n_lines_hi = 8.0

    if beam_profile == PROFILE_ELLIPTICAL
        ar_lo, ar_hi = 0.25, 1.0
    elseif beam_profile == PROFILE_AIRFOIL
        ar_lo, ar_hi = 0.08, 0.20
    else
        ar_lo, ar_hi = 1.0, 1.0
    end

    lo = [Do_lo, OPT_T_OVER_D_MIN, ar_lo, 0.0, r_hub_lo, taper_lo, n_rings_lo,
          axial_lo, profile_exp_lo, straight_frac_lo, knuckle_lo, n_lines_lo]
    hi = [Do_hi, OPT_T_OVER_D_MAX, ar_hi, 1.0, r_hub_hi, taper_hi, n_rings_hi,
          axial_hi, profile_exp_hi, straight_frac_hi, knuckle_hi, n_lines_hi]
    return lo, hi
end

function design_from_vector_v2(x::AbstractVector,
                                beam_profile::BeamProfile,
                                p::SystemParams)
    n_rings       = max(3, Int(round(x[7])))
    axial_profile = axial_profile_from_index(Int(round(x[8])))
    n_lines       = clamp(Int(round(x[12])), 3, 8)
    return TRPTDesignV2(
        beam_profile,
        x[1], x[2], x[3], x[4],           # beam params
        axial_profile,
        x[9],                             # profile_exp
        clamp(x[10], 0.0, 0.9),           # straight_frac
        x[5],                             # r_hub
        clamp(x[6], 0.05, 1.0),           # taper_ratio
        n_rings,
        p.tether_length,
        n_lines,
        x[11],                            # knuckle_mass_kg
    )
end

function objective_v2(x::AbstractVector, beam_profile::BeamProfile, p::SystemParams;
                       rotor_radius::Float64 = 5.0,
                       elev_angle::Float64   = π/6,
                       v_peak::Float64       = OPT_V_PEAK)
    design = design_from_vector_v2(x, beam_profile, p)
    r      = evaluate_design(design; r_rotor=rotor_radius, elev_angle=elev_angle,
                              v_peak=v_peak)
    return r.feasible ? r.mass_total_kg : 1e6 + r.mass_total_kg
end

# ── Baseline v2 — matches existing physical design with LINEAR taper ─────────
function baseline_design_v2(p::SystemParams)::TRPTDesignV2
    r_hub       = p.trpt_hub_radius
    r_bot_guess = 0.48 * r_hub
    taper_ratio = r_bot_guess / r_hub
    Do_top      = 0.01396 * sqrt(r_hub)
    return TRPTDesignV2(
        PROFILE_CIRCULAR,
        Do_top, 0.05, 1.0, 0.5,
        AXIAL_LINEAR, 1.0, 0.0,
        r_hub, taper_ratio,
        p.n_rings, p.tether_length,
        p.n_lines, OPT_KNUCKLE_MASS_KG,
    )
end
