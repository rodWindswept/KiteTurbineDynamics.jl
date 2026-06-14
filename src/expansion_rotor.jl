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
- `blade_tip_radius`: distance from ring to blade tip (m — same as main rotor tip radius)
- `blade_hub_radius`: distance from ring to inner edge of annulus (m — same as main rotor hub radius)
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
    blade_tip_radius::Float64   # same as main rotor tip radius (m)
    blade_hub_radius::Float64   # same as main rotor hub radius (m)
    blade_chord::Float64        # same as main rotor chord (m)
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
    geometry_factor = 2.0 * tan(π / n_lines)
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

where `geometry_factor = 2 · tan(π / n_lines)`.

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
