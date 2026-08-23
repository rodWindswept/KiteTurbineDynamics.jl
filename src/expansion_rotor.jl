# src/expansion_rotor.jl
#
# Aerodynamic expansion rotor model for TRPT systems.
#
# Replaces passive carbon-fibre compression rings (heavy, dead mass) with
# actively-lifted blades that spread the tether line set outward through
# aerodynamic force during rotation.
#
# Concept: each expansion rotor uses the SAME blade annulus as the
# generating rotor — identical hub radius, tip radius, chord, and blade
# count — but banked downward toward the next ring on the TRPT shaft.
# The banking angle resolves blade lift into radial (spreading) and axial
# (thrust) components.
#
#   F_radial = n_blades · L_blade · cos(φ) · sin(bank)   (spreads ring)
#   F_axial  = n_blades · L_blade · cos(φ) · cos(bank)   (thrust)
#   τ_lift   = n_blades · L_blade · sin(φ) · cos(bank) · r_mean  (drives shaft)
#   τ_drag   = n_blades · D_blade · cos(φ) · r_mean       (parasitic)
#   τ_net    = τ_lift - τ_drag                            (>0 = drives, <0 = brakes)
#
# The blade annulus extends from hub_radius to tip_radius along the blade,
# mounted at the ring radius r_nominal.  Banking tilts the annulus downward
# by bank_angle, projecting it into the rotation plane:
#
#   r_tip   = r_nominal + blade_tip_radius · cos(bank_angle)
#   r_hub   = r_nominal + blade_hub_radius · cos(bank_angle)
#   r_mean  = r_nominal + (blade_hub_radius + blade_tip_radius)/2 · cos(bank)
#
# Blade span for area = blade_tip_radius - blade_hub_radius
#
# The apparent wind at the mean radius drives blade lift:
#   v_axial = v_wind · cos(elevation)              (along shaft)
#   v_app²  = v_axial² + (ω · r_mean)²
#
# Reference: PLAN.md Phase 1 — Expansion Rotor Element
#
# ══════════════════════════════════════════════════════════════════════════════
# Calibrated blade coefficients (2026-06-18 — supersedes placeholder values)
# ══════════════════════════════════════════════════════════════════════════════
#
# Source: NACA 4412 section data from Abbott & von Doenhoff "Theory of Wing
# Sections" (1959), §4.2, Re = 3×10⁶.  The TRPT expansion blades operate at
# Re ≈ 2×10⁶ (chord ≈ 0.1–1.0 m, v_app ≈ 20–50 m/s), so Re 3×10⁶ is a
# slightly high but defensible reference.
#
# 2D section values (Re = 3×10⁶):
#   CL_max ≈ 1.4, CD_min ≈ 0.006 (at CL ≈ 0.1)
#   Design point (max L/D ≈ 100): CL ≈ 0.8, CD ≈ 0.008
#
# 3D corrections for finite AR (≈ 6–15, depending on blade planform):
#   k_induced ≈ 1 / (π · AR · e)  where e ≈ 0.85 (Oswald)
#   For AR ≈ 8: k_induced ≈ 0.047.  At CL=0.7: CD_i ≈ 0.023.
#   Total CD ≈ 0.010 + 0.023 = 0.033  →  L/D ≈ 21.
#
# Conservative design values (below stall, account for off-design operation):
#   CL_design  = 0.7   — ~85% of 2D max-L/D point, margin against stall
#   CD0_design = 0.010 — 2D section drag at moderate lift + surface roughness
#   k_induced  = 0.050 — finite-AR induced drag factor (upper end for AR≈8)
#
# Previous placeholder values (CL=1.0, CD0=0.02, k=0.05) gave L/D ≈ 14.3.
# Calibrated values give L/D ≈ 0.7/(0.010+0.050×0.49) ≈ 20.3 — ~42% better.
# The primary change is CD0 halving from 0.02→0.010 (section drag was double
# the physical value) and CL reducing from 1.0→0.7 (stall margin).
#
# Validation gap: these are textbook values, not CFD or wind-tunnel data
# specific to the TRPT blade planform.  AeroDyn BEM sweep or XFOIL run at
# Re 2×10⁶ with the actual chord and AR would be the authoritative source.
# Marked as CALIBRATED (not VALIDATED) — better than placeholder, but CFD
# confirmation is pending.  See 03_missing_context.md item M5.
const EXP_CL_DESIGN  = 0.7
const EXP_CD0_DESIGN = 0.010
const EXP_K_INDUCED  = 0.050

# Post-stall drag rise — provisional, pending real airfoil polars (M5).
# Below |CL_raw| ≤ CL_MAX:  CD = CD0 + k·CL²  (unchanged induced-drag model).
# Beyond CL_MAX: flow separation causes CD to rise nonlinearly.  The quadratic
# term restores aerodynamic damping in the saturated regime where clamping
# CL also clamped CD (the aero dead-zone).
#   CD_stall ≈ 0.15 is a conservative order-of-magnitude estimate for a
#   fully-separated blade section at Re 10⁵–10⁶.  Replace with polars when
#   available (Gate 3 PRD §airfoil-data).
# Ref (not const) so smoke tests can toggle it without source edits —
# run CD_STALL=0 for reproduction, then CD_STALL=0.15 for isolated effect.
const EXP_CD_STALL = Ref(0.15)

# ══════════════════════════════════════════════════════════════════════════════
# Parameter struct
# ══════════════════════════════════════════════════════════════════════════════

"""
    ExpansionRotorParams

Parameters for a single expansion rotor element mounted on a TRPT ring.
Uses the SAME blade annulus as the generating rotor — identical hub radius,
tip radius, chord, and blade count — banked downward toward the next ring.

# Fields
- `n_blades`: number of blades (inherited from main rotor)
- `blade_tip_radius`: outboard offset from ring — ~70% of blade span (positive, outward)
- `blade_hub_radius`: inboard offset from ring — ~30% of blade span (negative, inward of ring)
- `blade_chord`: blade chord length (m — same as main rotor chord)
- `CL_blade`: blade lift coefficient (design point)
- `CD0_blade`: blade zero-lift drag coefficient
- `k_induced`: induced drag factor (CDᵢ = k · CL²)
- `bank_angle_deg`: bank angle from rotation plane (degrees) — outer tip
  tilted down toward the next ring. Controls radial/axial split.
- `mass`: mass of the rotor assembly (kg)
- `ring_idx`: which TRPT ring this rotor is mounted on (1-based)
- `shaft_coupling`: torque coupling factor (1.0 = rigidly coupled to shaft)
"""
struct ExpansionRotorParams
    n_blades::Int
    blade_tip_radius::Float64   # outboard offset from ring, ~70% span (positive)
    blade_hub_radius::Float64   # inboard offset from ring, ~30% span (negative)
    blade_chord::Float64        # blade chord length (m)
    CL_blade::Float64
    CD0_blade::Float64
    k_induced::Float64
    bank_angle_deg::Float64     # blade banking angle toward next ring
    mass::Float64
    ring_idx::Int
    shaft_coupling::Float64
end

# ══════════════════════════════════════════════════════════════════════════════
# Per-annulus axial induction + α model (2026-07-18, induction_fix_proposal.md)
# ══════════════════════════════════════════════════════════════════════════════
#
# Legacy model (induction OFF): fixed CL, free-stream inflow — extraction does
# not deplete the flow that produces it; torque grows ~ω² unbounded.
# Fix (induction ON):
#   1. α model: CL = clamp(EXP_CL_SLOPE·(φ − EXP_THETA_I), ±EXP_CL_MAX) with
#      θ_i back-solved so CL(φ_design) = EXP_CL_DESIGN exactly (§2a option a).
#      At high TSR φ→0 drives α negative → CL brakes → fixed point always exists.
#   2. Momentum: solve T_BE(a) = T_M(a) by bisection on a ∈ [0, 0.5];
#      T_M uses Glauert/Buhl empirical branch above a = 0.4.
# Toggle: unified expansion_rotor_physics (2026-07-18, pre_gates_scoping.md GATE 2).
# Replaces the scattered per-feature flags (EXPANSION_INDUCTION, soon blade_inertia,
# eventually wake_coupling) with a single struct — one atomic pin
# per era, safe by construction where multiple partial toggles were interacting silently.
# NOTE (2026-08-22): corrected_mass was removed from the struct — the unified
# blade-mass law (m = M_BLADE_REF_KG·(span/1.0)³, pricing the DECODED span;
# DECISIONS [2026-08-22]) is unconditional, so the
# n_blades-era toggle is dead.  Legacy-reproduction scripts get the new law by
# decision (the CFRP (0.3+0.1·tip) law it gated was wrong for rigid foam).
#
# Legacy reproduction scripts (phantom gate, archived sweep CSVs) call
#   set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
# once and any new era constant is added here.

@kwdef mutable struct ExpansionPhysics
    induction::Bool      = true    # per-annulus induction + α model
    blade_inertia::Bool  = true    # blade mass in rotational ODE (Gate 2b)
end

"Named era — pinned by all legacy-reproduction scripts."
const LEGACY_PHYSICS_PRE_2026_07_18 = ExpansionPhysics(false, false)

const EXPANSION_PHYSICS = Ref{ExpansionPhysics}(ExpansionPhysics())

"Set all physics flags atomically. The pre-2026-07-17 era is `LEGACY_PHYSICS_PRE_2026_07_18`."
set_expansion_physics!(p::ExpansionPhysics) = (EXPANSION_PHYSICS[] = p; p)
"No-argument query."
expansion_physics() = EXPANSION_PHYSICS[]

# Backward-compat shim — redirects legacy partial-pin calls to the full legacy era
# with a display warning.  Delete after the migration commit settles.
function set_expansion_induction!(b::Bool)
    @warn "set_expansion_induction! is deprecated — use set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)"
    if !b
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
    end
end
expansion_induction() = EXPANSION_PHYSICS[].induction

# α model constants (stated per proposal §2a)
const EXP_CL_SLOPE   = 2π                    # lift-curve slope (1/rad)
const EXP_CL_MAX     = 1.2                   # symmetric stall clamp
const EXP_TSR_DESIGN = 3.0                   # design annulus tip-speed ratio
const EXP_PHI_DESIGN = atan(1.0 / EXP_TSR_DESIGN)  # design inflow angle (rad)
# Back-solved incidence: CL(φ_design) ≡ EXP_CL_DESIGN exactly
const EXP_THETA_I    = EXP_PHI_DESIGN - EXP_CL_DESIGN / EXP_CL_SLOPE

"CL from inflow angle φ (rad) under the α model."
expansion_cl(phi::Float64) = clamp(EXP_CL_SLOPE * (phi - EXP_THETA_I), -EXP_CL_MAX, EXP_CL_MAX)

"Shaft-axis swept annulus area (m²) for an expansion rotor at ring radius r_nominal."
function expansion_annulus_area(er::ExpansionRotorParams, r_nominal::Float64)
    bank_rad = deg2rad(er.bank_angle_deg)
    r_out = r_nominal + er.blade_tip_radius * cos(bank_rad)
    r_in  = max(r_nominal + er.blade_hub_radius * cos(bank_rad), 0.0)
    return π * max(r_out^2 - r_in^2, 0.0)
end

# Buhl/Glauert empirical thrust coefficient (valid a ∈ [0, 0.5])
function _ct_momentum(a::Float64)
    if a <= 0.4
        return 4.0 * a * (1.0 - a)
    else
        # Buhl continuation: CT = 8/9 + (4F − 40/9)a + (50/9 − 4F)a², F = 1
        return 8/9 + (4 - 40/9)*a + (50/9 - 4)*a^2
    end
end

# Blade-element axial thrust at induction a (whole rotor, N)
function _thrust_be(er::ExpansionRotorParams, rho, v_axial, omega, r_mean, bank_rad, a)
    v_eff = v_axial * (1.0 - a)
    phi = atan(v_eff, omega * r_mean)
    CL = expansion_cl(phi)
    CL_raw = EXP_CL_SLOPE * (phi - EXP_THETA_I)
    d_stall = max(abs(CL_raw) - EXP_CL_MAX, 0.0)
    cd_stall_rise = EXP_CD_STALL[] * (d_stall + d_stall^2)
    v_app2 = v_eff^2 + (omega * r_mean)^2
    q = 0.5 * rho * v_app2
    s = er.blade_tip_radius - er.blade_hub_radius
    L = q * er.blade_chord * s * CL
    D = q * er.blade_chord * s * (er.CD0_blade + er.k_induced * CL^2 + cd_stall_rise)
    return er.n_blades * (L * cos(phi) + D * sin(phi)) * cos(bank_rad)
end

"""
    solve_expansion_induction(er, rho, v_wind, omega_shaft, elevation_deg, r_nominal)
        -> (a, converged, iters, residual)

Per-annulus axial-induction fixed point: bisection on
`T_BE(a) − T_M(a) = 0`, a ∈ [0, 0.5]. Returns the converged induction factor.
`converged=false` when no sign change exists in the bracket (reported, never
silently clamped — acceptance test 1 fails on it).
"""
function solve_expansion_induction(
    er::ExpansionRotorParams, rho::Float64, v_wind::Float64,
    omega_shaft::Float64, elevation_deg::Float64, r_nominal::Float64,
)
    bank_rad = deg2rad(er.bank_angle_deg)
    r_mean = r_nominal + (er.blade_hub_radius + er.blade_tip_radius)/2 * cos(bank_rad)
    v_axial = v_wind * cos(deg2rad(elevation_deg))
    A_ann = expansion_annulus_area(er, r_nominal)

    (v_axial <= 1e-9 || A_ann <= 1e-9) && return (0.0, true, 0, 0.0)

    T_ref = 0.5 * rho * A_ann * v_axial^2          # residual scale
    f(a) = _thrust_be(er, rho, v_axial, omega_shaft, r_mean, bank_rad, a) -
           0.5 * rho * A_ann * v_axial^2 * _ct_momentum(a)

    f0 = f(0.0)
    f0 <= 0.0 && return (0.0, true, 0, 0.0)        # no/negative thrust → no induction
    fh = f(0.5)
    fh > 0.0 && return (0.5, false, 0, fh / T_ref) # no crossing — REPORTED not clamped

    lo, hi, flo = 0.0, 0.5, f0
    iters = 0
    a_mid, fm = 0.25, 0.0
    for _ in 1:80
        iters += 1
        a_mid = 0.5 * (lo + hi)
        fm = f(a_mid)
        if abs(fm) < 1e-8 * max(T_ref, 1e-6)
            return (a_mid, true, iters, fm / T_ref)
        end
        if sign(fm) == sign(flo)
            lo, flo = a_mid, fm
        else
            hi = a_mid
        end
        (hi - lo) < 1e-12 && break
    end
    # bracket collapsed to machine width — converged by interval
    return (a_mid, (hi - lo) < 1e-10, iters, fm / T_ref)
end

# ══════════════════════════════════════════════════════════════════════════════
# Force model
# ══════════════════════════════════════════════════════════════════════════════

"""
    expansion_rotor_forces(er, rho, v_wind, omega_shaft, elevation_deg,
                           r_nominal, T_tether, n_lines)
        -> (F_radial, F_axial, tau_net, r_eff, omega_rotor)

Compute aerodynamic forces from an expansion rotor element.

The blade annulus (hub → tip) is banked by bank_angle_deg toward the next
ring.  The mean aerodynamic radius accounts for the ring position and the
projected annulus centre in the rotation plane.

# Arguments
- `er::ExpansionRotorParams`: rotor parameters
- `rho::Float64`: air density (kg/m³)
- `v_wind::Float64`: wind speed at the rotor plane (m/s, scalar — uniform inflow)
- `omega_shaft::Float64`: shaft angular velocity (rad/s)
- `elevation_deg::Float64`: shaft elevation angle (degrees, unused — reserved)
- `r_nominal::Float64`: nominal ring radius before spreading (m)
- `T_tether::Float64`: tether tension at this ring (N)
- `n_lines::Int`: number of tether lines

# Returns
- `F_radial::Float64`: radial spreading force (N)
- `F_axial::Float64`: axial thrust force (N)
- `tau_net::Float64`: net shaft torque (N·m). Positive = driving\n  (injects power into shaft — τ_lift dominates). Negative = braking\n  (parasitic — τ_drag dominates).
- `r_eff::Float64`: effective ring radius after spreading (m)
- `omega_rotor::Float64`: rotor angular velocity (rad/s)
"""
function expansion_rotor_forces(
    er::ExpansionRotorParams,
    rho::Float64,
    v_wind::Float64,
    omega_shaft::Float64,
    elevation_deg::Float64,
    r_nominal::Float64,
    T_tether::Float64,
    n_lines::Int,
)
    bank_rad = deg2rad(er.bank_angle_deg)

    # Annulus centre in the blade plane, projected into rotation plane
    r_mean_annulus = (er.blade_hub_radius + er.blade_tip_radius) / 2.0
    r_mean = r_nominal + r_mean_annulus * cos(bank_rad)

    # Physical blade span for area calculation
    blade_span = er.blade_tip_radius - er.blade_hub_radius

    elev_rad = deg2rad(elevation_deg)

    # Wind component along the shaft axis (horizontal wind × cos(elevation))
    v_axial_free = v_wind * cos(elev_rad)

    # ── Induction (2026-07-18): deplete the inflow by the momentum-consistent
    # axial induction factor a, and use the α model for CL. OFF (default)
    # reproduces the legacy fixed-CL free-stream model bit-for-bit.
    local a_ind::Float64 = 0.0
    if EXPANSION_PHYSICS[].induction
        a_ind, _, _, _ = solve_expansion_induction(
            er, rho, v_wind, omega_shaft, elevation_deg, r_nominal)
    end
    v_axial = v_axial_free * (1.0 - a_ind)

    # Apparent wind at mean radius: vector sum of axial wind + tangential rotation
    v_app = sqrt(v_axial^2 + (omega_shaft * r_mean)^2)

    # Dynamic pressure
    q = 0.5 * rho * v_app^2

    # Inflow angle (needed for the α model before lift/drag)
    phi = atan(v_axial, omega_shaft * r_mean)   # inflow angle from rotation plane

    # Blade lift and drag (2D model, uniform inflow, no tip losses)
    # Legacy: fixed CL_blade. Induction ON: α model CL(φ).
    CL_eff = EXPANSION_PHYSICS[].induction ? expansion_cl(phi) : er.CL_blade
    L_blade = q * er.blade_chord * blade_span * CL_eff
    # Post-stall drag rise: CD decoupled from clamped CL to restore
    # aerodynamic damping in saturated regime (aero dead-zone fix).
    CL_raw = EXP_CL_SLOPE * (phi - EXP_THETA_I)
    d_stall = max(abs(CL_raw) - EXP_CL_MAX, 0.0)
    D_blade = q * er.blade_chord * blade_span *
        (er.CD0_blade + er.k_induced * CL_eff^2 + EXP_CD_STALL[] * (d_stall + d_stall^2))

    # Resolve lift perpendicular to apparent wind into shaft-frame components.
    # The apparent wind approaches at inflow angle φ from the rotation plane.
    #   φ = atan(v_wind, ω·r_mean)
    #
    # Lift L_blade is ⊥ to apparent wind. Its shaft-frame decomposition:
    #   F_radial = n_blades · L_blade · cos(φ) · sin(bank)    [spreads ring]
    #   F_axial  = n_blades · L_blade · cos(φ) · cos(bank)    [thrust]
    #   τ_lift   = n_blades · L_blade · sin(φ) · cos(bank) · r_mean  [drives shaft]
    #
    # Drag D_blade is ∥ to apparent wind:
    #   τ_drag   = n_blades · D_blade · cos(φ) · r_mean        [opposes rotation]
    #
    # Net shaft torque τ_net = τ_lift - τ_drag.
    # Positive = driving (injects power into shaft, like main rotor aerodynamics).
    # Negative = braking (extracts power, parasitic).

    sin_phi = sin(phi)
    cos_phi = cos(phi)

    L_tangential = L_blade * sin_phi * cos(bank_rad)  # per blade, tangential
    D_tangential = D_blade * cos_phi                    # per blade, tangential

    F_radial = er.n_blades * L_blade * cos_phi * sin(bank_rad)
    F_axial  = er.n_blades * L_blade * cos_phi * cos(bank_rad)
    tau_lift = er.n_blades * L_tangential * r_mean
    tau_drag = er.n_blades * D_tangential * r_mean
    tau_net  = tau_lift - tau_drag   # > 0 = driving, < 0 = braking

    # Effective radius from force balance at tether attachment point
    geometry_factor = 2.0 * sin(π / n_lines)
    L_seg_estimate = r_nominal * 2.0   # approximate segment length
    r_eff = effective_radius(r_nominal, F_radial, T_tether, L_seg_estimate, geometry_factor)

    # Rotor angular velocity (simplified: rigid coupling)
    omega_rotor = omega_shaft

    return (F_radial, F_axial, tau_net, r_eff, omega_rotor)
end

# ══════════════════════════════════════════════════════════════════════════════
# Effective radius
# ══════════════════════════════════════════════════════════════════════════════

"""
    effective_radius(r_nominal, F_radial, T_tether, L_seg, geometry_factor) -> Float64

Compute the effective ring radius after expansion due to radial aerodynamic force.

The radial force F_radial deflects the tether outward. From force equilibrium
at the attachment point on a polygonal ring of n_lines sides:

    Δr = F_radial · L_seg / (T_tether · geometry_factor)

where `geometry_factor = 2 · sin(π / n_lines)`.

# Returns
- `r_nominal` if F_radial ≤ 0 or T_tether ≤ 0 (no spreading)
"""
function effective_radius(
    r_nominal::Float64,
    F_radial::Float64,
    T_tether::Float64,
    L_seg::Float64,
    geometry_factor::Float64,
)::Float64
    if F_radial <= 0.0 || T_tether <= 0.0
        return r_nominal
    end

    Δr = F_radial * L_seg / (T_tether * geometry_factor)
    return r_nominal + Δr
end

"""
    expansion_rotor_inertia(er::ExpansionRotorParams, r_nominal::Float64) -> Float64

Total moment of inertia (kg·m²) about the shaft axis for one expansion rotor's
blades (uniform slender rods spanning the blade annulus).

Formula: J_rotor = n_blades · m_per_blade · (r₂² + r₂·r₁ + r₁²)/3
where r₁ = r_nominal + blade_hub_radius, r₂ = r_nominal + blade_tip_radius
(axis radii — NOT blade-local offsets; the ring-radius² term dominates).
Gated by `EXPANSION_PHYSICS[].blade_inertia`.
"""
function expansion_rotor_inertia(er::ExpansionRotorParams, r_nominal::Float64)
    r₁ = r_nominal + er.blade_hub_radius
    r₂ = r_nominal + er.blade_tip_radius
    m_per_blade = er.mass / er.n_blades
    return er.n_blades * m_per_blade * (r₂^2 + r₂*r₁ + r₁^2) / 3
end

"""
    expansion_blade_mass(span, n_blades=nothing; span_ref=1.0) -> Float64

Total blade mass for one expansion rotor assembly (all `n_blades` blades).

**Span³ volume law (2026-08-22, corrected):** rigid-foam blades scale with
VOLUME, and the decoder's blade linear scale is the SPAN
(`span = blade_tip − blade_hub = 0.75·r_rotor·λ` with r_rotor from the BEM
power sizing), so the honest law prices the decoded span:

    m_per_blade = M_BLADE_REF_KG · (span / span_ref)³

`M_BLADE_REF_KG = 0.420` is the MEASURED Daisy blade at the reference span
`span_ref = 1.0 m` (tips 1.22/2.22, ring 1.52).  The rung and the genome
enter through the decoded span; the law is absolute, not λ-relative.

**Why not λ³ (the 2026-08-22 correction):** the first implementation priced
`m = m_ref·λ³`, assuming λ is the total linear scale.  The decoder instead
sets span = 0.75·r_rotor·λ with r_rotor fixed by the BEM sizing, so the DE
could choose small λ with large r_rotor: blades LONGER than the Daisy
reference priced as if tiny.  The completed 5 kW campaign's winners were all
such artifacts (span 1.24-1.71 m priced at λ³ = 15× under the true volume;
global best φ 0.315 kg/kW vs the 1.3 anchor).  Priced by span, the same
blades weigh 3-15× more.  All winners VOID; campaign re-runs on this law.

# Arguments
- `span`: decoded blade span (m), tip − hub, × any builder dial
- `n_blades`: number of blades (default nothing → 3, the legacy assembly
  convention, preserved for backward-compatible signatures)
- `span_ref`: reference span at the anchor (default 1.0 m, Daisy)
"""
function expansion_blade_mass(
    span::Float64, n_blades::Union{Int,Nothing}=nothing;
    span_ref::Float64=1.0,
)::Float64
    n = n_blades === nothing ? 3 : max(n_blades, 0)
    return n * M_BLADE_REF_KG * (span / span_ref)^3
end

# ══════════════════════════════════════════════════════════════════════════════
# Radial spoke ties (2026-07-06 — Rod's design change)
# ══════════════════════════════════════════════════════════════════════════════

"""
    SpokeParams

Radial spoke ties from each ring vertex to a floating center node.
Engage under net-outward radial load — carry the force the clamp currently
discards. `nothing` = disabled = current behavior (bit-identical).

# Fields
- `d_line::Float64`: spoke line diameter for drag computation (m). Sizing parameter —
  the actual line is selected post-hoc from `required_MBL_N` in the Gate 2 CSV.
  0.004 default (~4mm, plausible neighbourhood for corrected loads).
- `SWL_N::Float64`: safe working load (N). Used for structural FoS during evaluation.
  Derived from d_line sizing rule. Not the final line spec — see `required_MBL_N`.
  7mm SK78 Dyneema: MBL ≈ 44.0 kN (generic catalogue, provisional).
  Deratings: splice 0.90, creep/fatigue/UV 0.50 → SWL = 44.0 × 0.90 × 0.50 = 19.8 kN.
  PROVISIONAL pending Gate 2 output — `required_MBL_N` in CSV supersedes this constant.
- `C_D::Float64`: drag coefficient for cylinder in cross-flow. ~1.0 at spoke Re.
- `enabled::Bool`: enable the structural check and drag torque. false = no-op.
"""
@kwdef struct SpokeParams
    d_line::Float64 = 0.007
    SWL_N::Float64  = 19_800.0
    C_D::Float64    = 1.0
    enabled::Bool   = true
    epsilon::Float64 = 1e-6  # minimum ring drift before spoke engages (m)
end
