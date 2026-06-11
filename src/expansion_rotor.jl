# src/expansion_rotor.jl
#
# Aerodynamic expansion rotor model for TRPT systems.
#
# Replaces passive carbon-fibre compression rings (heavy, dead mass) with
# actively-lifted blades that spread the tether line set outward through
# aerodynamic force during rotation.
#
# Concept: each expansion rotor is a small 3-blade propeller mounted on a
# TRPT ring. The blades generate lift from apparent wind (v_app² = v_wind² +
# (ω·r)²), and the lift is resolved through a bridle angle into radial
# (spreading) and axial (thrust) components. The radial force pushes the
# tether attachment points outward, increasing the effective ring radius.
#
#   F_radial = n_blades · L_blade · sin(bridle_angle)   (spreads the ring)
#   F_axial  = n_blades · L_blade · cos(bridle_angle)   (adds to rotor thrust)
#   τ_drag   = n_blades · D_blade · r_mean              (drag torque)
#
# The effective radius r_eff is computed from a force balance at the
# tether attachment point:
#
#   r_eff = r_nominal + Δr
#   Δr = F_radial · L_seg / (T_tether · geometry_factor)
#
# where geometry_factor = 2 · tan(π / n_lines) is the geometric advantage
# of the polygonal tether arrangement.
#
# Reference: PLAN.md Phase 1 — Expansion Rotor Element

# ══════════════════════════════════════════════════════════════════════════════
# Parameter struct
# ══════════════════════════════════════════════════════════════════════════════

"""
    ExpansionRotorParams

Parameters for a single expansion rotor element mounted on a TRPT ring.

# Fields
- `n_blades`: number of blades (typically 3)
- `blade_radius`: tip radius of each blade (m)
- `hub_radius`: hub radius (m) — inner edge of the blade annulus
- `blade_chord`: blade chord length (m)
- `CL_blade`: blade lift coefficient (design point)
- `CD0_blade`: blade zero-lift drag coefficient
- `k_induced`: induced drag factor (CDᵢ = k · CL²)
- `bridle_angle_deg`: bridle angle from axial (degrees) — controls radial/axial split
- `mass`: mass of the rotor assembly (kg)
- `ring_idx`: which TRPT ring this rotor is mounted on (1-based)
- `shaft_coupling`: torque coupling factor (1.0 = rigidly coupled to shaft)
"""
struct ExpansionRotorParams
    n_blades::Int
    blade_radius::Float64
    hub_radius::Float64
    blade_chord::Float64
    CL_blade::Float64
    CD0_blade::Float64
    k_induced::Float64
    bridle_angle_deg::Float64
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
        -> (F_radial, F_axial, tau_drag, r_eff, omega_rotor)

Compute aerodynamic forces from an expansion rotor element.

# Arguments
- `er::ExpansionRotorParams`: rotor parameters
- `rho::Float64`: air density (kg/m³)
- `v_wind::Float64`: wind speed at the rotor plane (m/s, scalar — uniform inflow)
- `omega_shaft::Float64`: shaft angular velocity (rad/s)
- `elevation_deg::Float64`: shaft elevation angle (degrees, unused — reserved for future cosⁿ scaling)
- `r_nominal::Float64`: nominal ring radius before spreading (m)
- `T_tether::Float64`: tether tension at this ring (N)
- `n_lines::Int`: number of tether lines

# Returns
- `F_radial::Float64`: radial spreading force (N)
- `F_axial::Float64`: axial thrust force (N)
- `tau_drag::Float64`: drag torque on the shaft (N·m)
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
    # Blade annulus mean radius
    r_mean = (er.blade_radius + er.hub_radius) / 2.0

    # Apparent wind speed at mean radius
    v_app = sqrt(v_wind^2 + (omega_shaft * r_mean)^2)

    # Dynamic pressure
    span = er.blade_radius - er.hub_radius
    q = 0.5 * rho * v_app^2

    # Blade lift and drag (simplified 2D model, uniform inflow, no tip losses)
    L_blade = q * er.blade_chord * span * er.CL_blade
    D_blade = q * er.blade_chord * span * (er.CD0_blade + er.k_induced * er.CL_blade^2)

    # Resolve through bridle angle
    bridle_rad = deg2rad(er.bridle_angle_deg)
    F_radial = er.n_blades * L_blade * sin(bridle_rad)
    F_axial = er.n_blades * L_blade * cos(bridle_rad)
    tau_drag = er.n_blades * D_blade * r_mean

    # Effective radius from force balance at tether attachment point
    geometry_factor = 2.0 * tan(π / n_lines)
    L_seg_estimate = r_nominal * 2.0   # approximate segment length
    r_eff = effective_radius(r_nominal, F_radial, T_tether, L_seg_estimate, geometry_factor)

    # Rotor angular velocity (simplified: rigid coupling)
    omega_rotor = omega_shaft   # extend with shaft_coupling for flexible coupling later

    return (F_radial, F_axial, tau_drag, r_eff, omega_rotor)
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
