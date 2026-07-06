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
    v_axial = v_wind * cos(elev_rad)

    # Apparent wind at mean radius: vector sum of axial wind + tangential rotation
    v_app = sqrt(v_axial^2 + (omega_shaft * r_mean)^2)

    # Dynamic pressure
    q = 0.5 * rho * v_app^2

    # Blade lift and drag (simplified 2D model, uniform inflow, no tip losses)
    L_blade = q * er.blade_chord * blade_span * er.CL_blade
    D_blade = q * er.blade_chord * blade_span * (er.CD0_blade + er.k_induced * er.CL_blade^2)

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

    phi = atan(v_axial, omega_shaft * r_mean)   # inflow angle from rotation plane
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

# ══════════════════════════════════════════════════════════════════════════════
# Blade mass
# ══════════════════════════════════════════════════════════════════════════════

"""
    expansion_blade_mass(blade_tip_radius, blade_scale) -> Float64

Total blade mass for one expansion rotor assembly (all `n_blades` blades).

Mass scales with the cube of blade linear dimension: mass ∝ volume ∝ span³.
The empirical constants (0.3 kg base + 0.1 kg/m per unit tip radius) are
calibrated from CFRP blade mass estimates for the V10 configuration.

# Arguments
- `blade_tip_radius`: outer tip radius (m), post-70/30 geometry
- `blade_scale`: dimensionless scalar (span/chord/mass), λ in [0, 1]
"""
function expansion_blade_mass(blade_tip_radius::Float64, blade_scale::Float64)::Float64
    return (0.3 + 0.1 * blade_tip_radius) * blade_scale^3
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
- `d_line::Float64`: spoke line diameter (m). 0.007 (7mm Dyneema, Rod 2026-07-06).
- `SWL_N::Float64`: safe working load per spoke, after splice/creep/fatigue derating (N).
  7mm SK78 Dyneema: break ~40 kN → SWL ~10 kN after 4× safety factor.
- `C_D::Float64`: drag coefficient for cylinder in cross-flow. ~1.0 at spoke Re.
- `enabled::Bool`: enable the structural check and drag torque. false = no-op.
"""
@kwdef struct SpokeParams
    d_line::Float64 = 0.007
    SWL_N::Float64  = 10_000.0
    C_D::Float64    = 1.0
    enabled::Bool   = true
end
