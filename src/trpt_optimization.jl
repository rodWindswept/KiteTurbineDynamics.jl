# src/trpt_optimization.jl
# TRPT Sizing Optimization module — Item B2.
#
# Physics model for the pentagonal TRPT rigid frame, sized for survival at
# peak 25 m/s wind loads with FOS ≥ 1.8.  Supports three manufacturable beam
# profiles (hollow circular, hollow elliptical, symmetric airfoil shell) and
# a scaling-along-length geometry for the pentagon frames.
#
# Mass model explicitly includes discrete 50 g knuckle point masses at each
# pentagon vertex (per B2 spec user approval, 2026-04-20).
#
# All structural analysis is analytic (Euler buckling + thin-wall second
# moment of area) so each objective-function evaluation is ≪1 ms.  This keeps
# the 168-hour search feasible with >1e8 evaluations of headroom.

using LinearAlgebra

# ── Material and manufacturability constants ─────────────────────────────────
# Re-used from structural_safety.jl (CFRP hollow tube).
const OPT_E_CFRP          = 70e9     # Pa   — Young's modulus
const OPT_RHO_CFRP        = 1600.0   # kg/m³ — density
const OPT_T_MIN_WALL      = 5e-4     # m    — 0.5 mm min manufacturable wall
const OPT_T_OVER_D_MAX    = 0.15     # unitless — above this, tube collapses to solid rod
const OPT_T_OVER_D_MIN    = 0.02     # unitless — below this, local shell buckling governs
const OPT_KNUCKLE_MASS_KG = 0.050    # kg — per-vertex knuckle (user approval 2026-04-20)

# ── Peak design load conditions ──────────────────────────────────────────────
const OPT_V_PEAK            = 25.0   # m/s — peak design wind speed
const OPT_CT_PEAK            = 1.0   # max BEM thrust coefficient (conservative)
const OPT_FOS_REQUIRED     = 1.8     # Factor of Safety (hard constraint)
const OPT_TORSION_MARGIN   = 1.10    # Required ratio A_actual / A_buckling_limit

# ── Combined design-load factor (DLF) ────────────────────────────────────────
# Under perfectly uniform taper + zero twist + zero gust, the net radial force
# per pentagon vertex is ZERO (tension components from segments above and below
# cancel).  In real operation the vertex feels:
#   (a) Taper-transition loads where non-uniformity exists
#   (b) Torque reaction — the peak shaft torque at fault conditions creates a
#       tangential line inclination (helix) that projects inward at each vertex
#   (c) Gust-induced asymmetric line tension — a single line can carry 1.5× the
#       mean during a 3-s gust (IEC 61400-1 coherent gust)
#
# DLF is a lumped envelope that converts line tension into an effective radial
# inward force per vertex.
#
# CALIBRATED 2026-04-20 from scripts/calibrate_dlf.jl by running the canonical
# 10 kW multi-body ODE through six structural-load scenarios and extracting the
# per-ring inward-force envelope.  Per-scenario peak DLFs:
#
#   steady 11 m/s         : 0.83   (rated operation)
#   steady 15 m/s         : 0.56
#   steady 20 m/s         : 0.40
#   steady 25 m/s         : 0.32   (peak design wind, no fault)
#   coherent gust 11→25   : 0.74   (gust transient)
#   emergency brake (3×k) : 1.39   ← FAULT CASE, MITIGATED OPERATIONALLY
#
# Reference data + figures: scripts/results/trpt_opt/dlf/.
#
# OPERATIONAL DECISION (Rod, 2026-04-20):
# Emergency brake at 3× k_mppt step is NOT a sizing case. The live system
# avoids sudden braking entirely — rotor shutdown sequence is:
#   1. Ease off the MPPT load through a controlled ramp (not a step).
#   2. Haul on the back-anchor tether to yaw the shaft off-axis.
#   3. Rotor stalls aerodynamically before mechanical braking is applied.
#   4. Haul the stalled rotor down on the lifter line.
# No step change in k_mppt ever hits the airframe in normal operation.
#
# Sizing envelope therefore excludes the ebrake peak. DLF is chosen at 1.2 to:
#   • Provide ~60% margin over the worst aero-only case (steady11 = 0.83).
#   • Cover coherent-gust transients (0.74) with 60% margin.
#   • Reserve margin for Class-A turbulence and manufacturing tolerance.
#   • Remain below the 1.39 ebrake peak (no design against avoided fault).
const OPT_DESIGN_LOAD_FACTOR = 1.2   # unitless — F_in_per_vertex = DLF × T_line

# Beam profile types — discrete choice for the optimizer
@enum BeamProfile PROFILE_CIRCULAR=1 PROFILE_ELLIPTICAL=2 PROFILE_AIRFOIL=3

"""
    BeamSpec

Geometric specification of one pentagon-segment beam.

Fields:
- `profile`        — one of PROFILE_CIRCULAR, PROFILE_ELLIPTICAL, PROFILE_AIRFOIL
- `Do`             — outer dimension (m): diameter (circular), major axis (elliptical), chord (airfoil)
- `t_over_D`       — wall thickness ratio (unitless)
- `aspect_ratio`   — Do_minor / Do_major for elliptical; thickness-to-chord for airfoil; ignored for circular
"""
struct BeamSpec
    profile      :: BeamProfile
    Do           :: Float64
    t_over_D     :: Float64
    aspect_ratio :: Float64
end

"""
    TRPTDesign

Full specification of a TRPT structural design candidate.

Fields:
- `profile`          — beam cross-section type (same for all rings)
- `Do_top`           — outer dimension at the hub-side (topmost) ring (m)
- `t_over_D`         — wall thickness ratio
- `aspect_ratio`     — profile-specific secondary dimension ratio
- `Do_scale_exp`     — exponent for Do scaling along TRPT: Do_i = Do_top × (r_i/r_top)^exp
                       exp=0 ⇒ uniform; exp=0.5 ⇒ sqrt (current baseline); exp=1 ⇒ linear
- `r_hub`            — top ring radius (m)
- `taper_ratio`      — r_bottom / r_top for the tapered pentagon stack
- `n_rings`          — number of intermediate polygon spacer rings (integer)
- `tether_length`    — total axial length of the TRPT (m, inherited from system)
- `n_lines`          — number of pentagon lines (5 for a regular pentagon)
- `knuckle_mass_kg`  — point mass at each vertex (kg)
"""
struct TRPTDesign
    profile         :: BeamProfile
    Do_top          :: Float64
    t_over_D        :: Float64
    aspect_ratio    :: Float64
    Do_scale_exp    :: Float64
    r_hub           :: Float64
    taper_ratio     :: Float64
    n_rings         :: Int
    tether_length   :: Float64
    n_lines         :: Int
    knuckle_mass_kg :: Float64
end

# ── Beam cross-section properties ────────────────────────────────────────────
"""
    beam_section_properties(spec::BeamSpec) → (A, I_min, I_torsional)

Cross-section area (m²), minimum second moment of area (m⁴, controlling
Euler buckling), and torsional constant (m⁴, for reference).
"""
function beam_section_properties(spec::BeamSpec)
    p = spec.profile
    Do = spec.Do
    t  = max(spec.t_over_D * Do, OPT_T_MIN_WALL)
    if p == PROFILE_CIRCULAR
        # Hollow circular tube.
        Di = max(Do - 2t, 0.0)
        A  = π/4 * (Do^2 - Di^2)
        I  = π/64 * (Do^4 - Di^4)
        J  = 2 * I
        return (A, I, J)
    elseif p == PROFILE_ELLIPTICAL
        # Hollow elliptical tube; aspect_ratio = b/a  (minor/major).
        a  = Do / 2.0
        b  = max(spec.aspect_ratio, 0.1) * a
        ai = max(a - t, 0.0)
        bi = max(b - t, 0.0)
        A  = π * (a*b - ai*bi)
        # I about the major axis (bending perpendicular — minor-axis direction); this is I_min
        # since the minor axis is smaller:
        I_minor = π/4 * (a  * b ^3 - ai * bi^3)  # bending about major — weaker
        I_major = π/4 * (a^3 * b    - ai^3 * bi) # bending about minor — stronger
        I_min   = min(I_minor, I_major)
        # Thin-wall torsion constant (approximate, Bredt):
        perim = π * (a + b) * (1 + 3*((a-b)/(a+b))^2 / (10 + sqrt(4 - 3*((a-b)/(a+b))^2)))
        J     = 4 * (π*a*b)^2 * t / max(perim, 1e-9)
        return (A, I_min, J)
    else # PROFILE_AIRFOIL — symmetric airfoil thin-wall shell (NACA 00XX-like)
        c      = Do                                   # chord
        t_c    = max(spec.aspect_ratio, 0.05)         # thickness-to-chord
        t_max  = t_c * c                              # max thickness
        t_w    = max(spec.t_over_D * c, OPT_T_MIN_WALL)  # wall thickness
        # Thin-wall perimeter (symmetric airfoil approx):
        perim  = 2.03 * c * (1 + 0.25*t_c^2)
        A      = perim * t_w
        # Flap bending (weak axis): skin contribution dominates.
        # I_flap ≈ 0.073 × c × t_max² × t_w  (calibrated for NACA 0015 thin shell)
        I_flap = 0.073 * c * t_max^2 * t_w
        # Edge bending (strong axis): much larger — not a buckling concern here.
        I_min  = I_flap
        # Single-cell torsion (thin-wall, Bredt):
        A_encl = 0.685 * c * t_max   # enclosed area for a symmetric airfoil
        J      = 4 * A_encl^2 * t_w / max(perim, 1e-9)
        return (A, I_min, J)
    end
end

# ── Geometry helpers ─────────────────────────────────────────────────────────
"""
    ring_radii(design) → Vector{Float64}

Return the radii (m) of all n_rings+2 pentagon frames: ground (index 1),
intermediate (2..n_rings+1), and hub (index n_rings+2).

Ground ring is always r_bottom = r_hub × taper_ratio; hub ring is r_hub.
Intermediate rings are linearly interpolated in radius.
"""
function ring_radii(design::TRPTDesign)
    n_total = design.n_rings + 2
    r_top   = design.r_hub
    r_bot   = design.r_hub * design.taper_ratio
    return [r_bot + (r_top - r_bot) * (i - 1) / (n_total - 1) for i in 1:n_total]
end

"""
    segment_axial_lengths(design) → Vector{Float64}

Axial length (m) of each of the n_rings+1 inter-ring segments.
Uniform axial spacing: L_seg = tether_length / (n_rings + 1).
"""
function segment_axial_lengths(design::TRPTDesign)
    n_seg = design.n_rings + 1
    return fill(design.tether_length / n_seg, n_seg)
end

"""
    beam_spec_at_ring(design, r) → BeamSpec

Return the beam spec for a ring at radius r, using the scaling
Do_i = Do_top × (r_i / r_top)^Do_scale_exp.
"""
function beam_spec_at_ring(design::TRPTDesign, r::Float64)
    scale = (r / design.r_hub)^design.Do_scale_exp
    return BeamSpec(design.profile,
                    design.Do_top * scale,
                    design.t_over_D,
                    design.aspect_ratio)
end

# ── Peak load distribution at 25 m/s ─────────────────────────────────────────
"""
    peak_hub_thrust(r_rotor, elev_angle; v=OPT_V_PEAK, ρ=1.225, CT=OPT_CT_PEAK)

Aerodynamic thrust on the rotor disc at peak wind speed (N).
Conservative CT=1.0 captures the worst case within the BEM envelope
(actual BEM peak CT ≈ 0.55 at λ_opt, but gust/runaway conditions can
push CT toward the Betz upper bound of 8/9; 1.0 is a safe ceiling).
"""
function peak_hub_thrust(r_rotor::Float64, elev_angle::Float64;
                          v::Float64=OPT_V_PEAK, ρ::Float64=1.225,
                          CT::Float64=OPT_CT_PEAK)
    return 0.5 * ρ * v^2 * π * r_rotor^2 * CT * cos(elev_angle)^2
end

"""
    segment_inward_force(design, seg_idx, T_line) → F_inward_per_vertex

Inward radial force per pentagon vertex (N) on the lower ring of segment
seg_idx, due to the line tension T_line flowing through that segment with a
taper angle determined by the radii of its two end rings.

Each ring receives contributions from TWO adjacent segments (one above,
one below); this function returns the contribution of one segment.
"""
function segment_inward_force(design::TRPTDesign, seg_idx::Int,
                               T_line::Float64, radii::AbstractVector,
                               L_seg::AbstractVector)
    r_lo = radii[seg_idx]       # lower ring
    r_hi = radii[seg_idx+1]     # upper ring
    L    = L_seg[seg_idx]
    # Line length along the taper:
    line_len = sqrt(L^2 + (r_hi - r_lo)^2)
    # Inward radial component of tension at lower ring (lines taper inward going up):
    sin_theta = (r_hi - r_lo) / max(line_len, 1e-12)   # + if hi > lo (ring_hi larger, line leans outward going up)
    # We want the inward component on the LOWER ring.  If r_hi > r_lo (unusual,
    # for inverted taper), line leans outward going up → tension pulls lower
    # ring outward (negative inward).  Normal case r_hi < r_lo: line leans
    # inward going up → tension pulls lower ring inward.
    return -T_line * sin_theta   # sign: +inward
end

# ── Design evaluation ────────────────────────────────────────────────────────
"""
    EvalResult

Outcome of evaluating one candidate TRPT design.
"""
struct EvalResult
    feasible          :: Bool
    mass_total_kg     :: Float64
    mass_beams_kg     :: Float64
    mass_knuckles_kg  :: Float64
    min_fos           :: Float64
    worst_ring_idx    :: Int
    fos_per_ring      :: Vector{Float64}
    N_comp_per_ring   :: Vector{Float64}
    P_crit_per_ring   :: Vector{Float64}
    Do_per_ring       :: Vector{Float64}
    torsion_margin_ok :: Bool
    constraint_msg    :: String
end

"""
    evaluate_design(design, r_rotor, elev_angle; v_peak, fos_req) → EvalResult

Static structural analysis of a TRPT design candidate under peak 25 m/s
wind load.  Performs:

1. Rotor thrust calc → line tension (per of n_lines lines).
2. For each ring, sum inward force from the segments above and below.
3. Polygon segment compression N_comp from inward force (standard n-gon equilibrium).
4. Per-segment Euler buckling capacity P_crit = π²·E·I_min / L_poly².
5. FOS = P_crit / N_comp for each ring.  Design is feasible iff min FOS ≥ fos_req.
6. Torsional rigidity check: A(cross-section) ≥ OPT_TORSION_MARGIN × A_buckling_limit.
7. Total mass = Σ beam_mass + n_vertices × knuckle_mass.
"""
function evaluate_design(design::TRPTDesign;
                          r_rotor     :: Float64 = 5.0,
                          elev_angle  :: Float64 = π/6,
                          v_peak      :: Float64 = OPT_V_PEAK,
                          fos_req     :: Float64 = OPT_FOS_REQUIRED)

    # Early-reject obviously invalid designs
    if design.Do_top <= 0 || design.t_over_D <= 0 ||
       design.n_rings < 3 || design.taper_ratio <= 0 ||
       design.r_hub <= 0
        return EvalResult(false, Inf, Inf, 0.0, 0.0, 0, Float64[], Float64[],
                          Float64[], Float64[], false, "invalid geometry")
    end

    radii      = ring_radii(design)
    L_seg      = segment_axial_lengths(design)
    n_rings_tot = length(radii)            # includes ground + hub
    n_seg      = length(L_seg)

    # ── Line tension distribution ────────────────────────────────────────────
    # Total axial thrust transmitted through the n_lines tether lines.  Each
    # line carries T_axial_per_line = T_peak / n_lines along its (near-axial)
    # direction.  For the near-uniform taper the tilt is small, so line
    # tension ≈ T_peak / (n_lines·cos θ) ≈ T_peak / n_lines.  Per-segment
    # radial components are resolved by the ring.
    T_peak       = peak_hub_thrust(r_rotor, elev_angle; v=v_peak)
    T_line_axial = T_peak / design.n_lines          # tension projected on shaft

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
        # Effective inward force per vertex under the combined design-load
        # envelope (torque-fault + coherent gust).  See OPT_DESIGN_LOAD_FACTOR.
        # T_line scales with local axial-line inclination (near unity for small
        # taper angles, significant only where taper is steep).
        line_len_below = i > 1 ?
            sqrt(L_seg[i-1]^2 + (radii[i] - radii[i-1])^2) : L_seg[1]
        line_len_above = i < n_rings_tot ?
            sqrt(L_seg[i]^2 + (radii[i+1] - radii[i])^2) : L_seg[end]
        # Use the MAX of the two adjacent segment line-lengths to pick the line
        # tension with greatest inclination; ensures conservatism.
        T_line = T_line_axial * max(line_len_below, line_len_above) /
                  min(L_seg[max(i-1,1)], L_seg[min(i, n_seg)])
        F_in_per_vertex = OPT_DESIGN_LOAD_FACTOR * T_line

        # Convert per-vertex inward force to polygon segment compression.
        # Standard regular n-gon: F_v per vertex radial inward →
        # N_comp per segment = F_v / (2·tan(π/n)).
        n_float = float(design.n_lines)
        F_v     = F_in_per_vertex
        N_comp  = F_v / (2.0 * tan(π / n_float))

        # Segment length for buckling
        L_poly = 2.0 * r * sin(π / n_float)

        # Beam spec at this ring
        spec = beam_spec_at_ring(design, r)
        A, I_min, _ = beam_section_properties(spec)
        P_crit = π^2 * OPT_E_CFRP * I_min / L_poly^2

        # FOS — skip ground and hub rings (those are treated as rigid connections,
        # not free pentagon frames) for buckling FOS eval, but count their mass.
        is_buckling_ring = (i > 1 && i < n_rings_tot)
        if is_buckling_ring && N_comp > 0
            fos = P_crit / N_comp
            push!(fos_per_ring, fos)
            push!(Ncomp_per_ring, N_comp)
            push!(Pcrit_per_ring, P_crit)
            push!(Do_per_ring, spec.Do)
            if fos < min_fos
                min_fos = fos
                worst_idx = i
            end
        else
            push!(fos_per_ring, Inf)
            push!(Ncomp_per_ring, 0.0)
            push!(Pcrit_per_ring, 0.0)
            push!(Do_per_ring, spec.Do)
        end

        # Torsional/stiffness margin check
        A_req = OPT_TORSION_MARGIN * N_comp / (OPT_E_CFRP * 1e-4)  # loose floor from modulus
        if is_buckling_ring && A < (OPT_TORSION_MARGIN * abs(N_comp) / 5e8)
            # Compressive stress σ = N_comp/A must not exceed half yield (CFRP ≈ 500 MPa)
            torsion_ok = false
        end

        # Beam mass contribution: each ring has n_lines beams (polygon sides),
        # each of length L_poly, density ρ, area A.
        mass_beams += design.n_lines * OPT_RHO_CFRP * A * L_poly
    end

    # Knuckle point-mass contribution: one at each polygon vertex, each ring
    n_vertices    = design.n_lines * n_rings_tot
    mass_knuckles = design.knuckle_mass_kg * n_vertices
    mass_total    = mass_beams + mass_knuckles

    # Feasibility
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

# ── Baseline extraction from existing SystemParams ────────────────────────────
"""
    baseline_design(p::SystemParams) → TRPTDesign

Construct the baseline TRPT design matching the current `SystemParams`:
CFRP hollow circular tube, Do=0.01396×√R scaling (exponent=0.5), uniform
axial spacing, taper consistent with current rL ratio.
"""
function baseline_design(p::SystemParams)::TRPTDesign
    r_hub       = p.trpt_hub_radius
    r_bot_guess = 0.48 * r_hub   # DRR: 2.0 → 0.96 for 10 kW; ratio ≈ 0.48
    taper_ratio = r_bot_guess / r_hub
    n_rings     = p.n_rings
    tether_len  = p.tether_length
    # Baseline Do_top = DO_SCALE × √r_hub (matches structural_safety.jl scaling)
    Do_top      = 0.01396 * sqrt(r_hub)
    return TRPTDesign(
        PROFILE_CIRCULAR,
        Do_top,
        0.05,                  # baseline t/D
        1.0,                   # aspect_ratio unused for circular
        0.5,                   # Do_scale_exp: sqrt scaling
        r_hub,
        taper_ratio,
        n_rings,
        tether_len,
        p.n_lines,
        OPT_KNUCKLE_MASS_KG,
    )
end

# ── Search-space bounds ──────────────────────────────────────────────────────
"""
    search_bounds(p::SystemParams, profile::BeamProfile) → (lo, hi)

Vector-form bounds for the optimizer, for a fixed beam profile:
  x = [Do_top, t_over_D, aspect_ratio, Do_scale_exp, r_hub, taper_ratio, n_rings_float]
"""
function search_bounds(p::SystemParams, profile::BeamProfile)
    # Scale bounds by system size (square-root of rotor radius) so 50 kW and
    # 10 kW share the same bounds function.
    sc = sqrt(p.trpt_hub_radius / 2.0)          # =1 at 10 kW, ≈2.24 at 50 kW
    Do_lo = 0.005 * sc;  Do_hi = 0.120 * sc     # 5–120 mm at 10 kW

    # r_hub is tightly constrained — it must match the rotor-hub mounting
    # geometry (blade root attachment).  Allow ±10% from baseline to let the
    # optimizer probe small-radius advantages without breaking rotor assembly.
    r_hub_lo = 0.90 * p.trpt_hub_radius
    r_hub_hi = 1.10 * p.trpt_hub_radius

    # taper_ratio lower bound enforced by ground-anchor footprint; a
    # realistic minimum is r_bot ≥ 0.6 m regardless of hub radius.  Upper
    # limit 1.0 = no taper (cylindrical TRPT).
    taper_lo = max(0.20, 0.6 / p.trpt_hub_radius)
    taper_hi = 1.0

    # n_rings — torsional stability floor (empirical): need enough rings to
    # keep per-segment twist below buckling of the rope helix.  Baseline has
    # 14 rings for 30 m; use min 7 (one every ~4 m) and max 40.
    n_rings_lo = 7.0
    n_rings_hi = 40.0

    if profile == PROFILE_ELLIPTICAL
        ar_lo = 0.25;  ar_hi = 1.0          # minor/major
    elseif profile == PROFILE_AIRFOIL
        ar_lo = 0.08;  ar_hi = 0.20         # NACA 0008 to 0020
    else
        ar_lo = 1.0;  ar_hi = 1.0           # ignored (fixed at 1.0 for circular)
    end
    # [Do_top, t_over_D, aspect_ratio, Do_scale_exp, r_hub, taper_ratio, n_rings]
    lo = [Do_lo, OPT_T_OVER_D_MIN, ar_lo, 0.0, r_hub_lo, taper_lo, n_rings_lo]
    hi = [Do_hi, OPT_T_OVER_D_MAX, ar_hi, 1.0, r_hub_hi, taper_hi, n_rings_hi]
    return lo, hi
end

"""
    design_from_vector(x, profile, p) → TRPTDesign

Map a flat parameter vector (as emitted by the optimizer) into a TRPTDesign.
"""
function design_from_vector(x::AbstractVector, profile::BeamProfile, p::SystemParams)
    n_rings = max(3, Int(round(x[7])))
    return TRPTDesign(
        profile,
        x[1],                        # Do_top
        x[2],                        # t_over_D
        x[3],                        # aspect_ratio
        x[4],                        # Do_scale_exp
        x[5],                        # r_hub
        clamp(x[6], 0.05, 1.0),      # taper_ratio
        n_rings,
        p.tether_length,
        p.n_lines,
        OPT_KNUCKLE_MASS_KG,
    )
end

"""
    objective(x, profile, p) → mass (or +∞ if infeasible)

Scalar cost function for the optimizer.
"""
function objective(x::AbstractVector, profile::BeamProfile, p::SystemParams;
                    rotor_radius::Float64 = 5.0,
                    elev_angle::Float64   = π/6)
    design = design_from_vector(x, profile, p)
    r_rotor = rotor_radius                        # passed from caller for scaling
    result  = evaluate_design(design; r_rotor=r_rotor, elev_angle=elev_angle)
    return result.feasible ? result.mass_total_kg : 1e6 + result.mass_total_kg
end
