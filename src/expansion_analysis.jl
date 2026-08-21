# src/expansion_analysis.jl
#
# Expansion rotor analysis — φ tracking and campaign telemetry.
#
# φ = mass/power ratio (kg/kW) is the central metric of the TRPT scaling
# paper.  Without expansion rotors, φ worsens from 1.15 kg/kW at 10 kW to
# 1.59 kg/kW at 50 kW.  The expansion rotor hypothesis: aerodynamic spreading
# increases effective radius → reduces tether tension → reduces required
# tether diameter → reduces airborne mass → restores near-linear φ scaling.
#
# Functions:
#   expansion_airborne_mass(sys, p)   — total airborne mass (kg)
#   expansion_phi(sys, p, power_w)    — mass/power ratio (kg/kW)
#   expansion_radius_summary(sys)     — effective radii per ring
#   expansion_telemetry(sys, p, power_w, v_wind) — full campaign record
#
# Reference: PLAN.md Phase 2.2 — φ improvement tracking

# ══════════════════════════════════════════════════════════════════════════════
# Airborne mass computation
# ══════════════════════════════════════════════════════════════════════════════

const DYNEEMA_DENSITY = 970.0  # kg/m³

"""
    expansion_airborne_mass(sys::KiteTurbineSystem, p::SystemParams) -> Float64

Compute total airborne mass including expansion rotors.

Components:
- Tether mass: n_lines × length × ρ × π·(d/2)²
- Ring mass: n_rings × m_ring (structural rings)
- Blade mass: n_blades × m_blade (main rotor blades)
- Expansion rotor mass: sum of mass_per_rotor across all expansion rotors
- Lifter mass: 5.0 kg (rotary lifter estimate)
"""
function expansion_airborne_mass(
    sys::KiteTurbineSystem, p::SystemParams; include_lifter::Bool=true
)
    # Tether mass
    m_tether =
        p.n_lines * p.tether_length * (DYNEEMA_DENSITY * π * (p.tether_diameter / 2)^2)

    # Structural rings
    m_rings = p.n_rings * p.m_ring

    # Main rotor blades
    m_blades = p.n_blades * p.m_blade

    # Expansion rotors
    m_expansion = sum(er -> er.mass, sys.expansion_rotors; init=0.0)

    # Lifter (autogyro rotor + lines).  Rod 2026-08-21: the lifter's own mass
    # must NOT drive the lift-line tension requirement (the stack carries
    # itself with its own lift) — tension sizing uses include_lifter=false.
    m_lifter = 5.0

    return m_tether + m_rings + m_blades + m_expansion + (include_lifter ? m_lifter : 0.0)
end

# ══════════════════════════════════════════════════════════════════════════════
# φ computation
# ══════════════════════════════════════════════════════════════════════════════

"""
    expansion_phi(sys::KiteTurbineSystem, p::SystemParams, power_w::Float64) -> Float64

Compute the mass/power ratio φ = m_airborne / power (kg/kW).

This is the central scaling metric. A lower φ means less airborne mass
per unit power — the key advantage expansion rotors aim to provide.
"""
function expansion_phi(sys::KiteTurbineSystem, p::SystemParams, power_w::Float64)
    power_w <= 0.0 && return Inf
    return expansion_airborne_mass(sys, p) / (power_w / 1000.0)
end

# ══════════════════════════════════════════════════════════════════════════════
# Radius summary
# ══════════════════════════════════════════════════════════════════════════════

"""
    expansion_radius_summary(sys::KiteTurbineSystem) -> Vector{Float64}

Return the effective radius for each ring in ring_idx order.
When expansion rotors are active, these differ from nominal radii.
"""
function expansion_radius_summary(sys::KiteTurbineSystem)
    if isempty(sys.expansion_rotors)
        # Return nominal radii
        return [node.radius for node in sys.nodes if node isa RingNode]
    end
    return copy(sys.effective_radii)
end

# ══════════════════════════════════════════════════════════════════════════════
# Telemetry record
# ══════════════════════════════════════════════════════════════════════════════

"""
    expansion_telemetry(sys::KiteTurbineSystem, p::SystemParams,
                        power_w::Float64, v_wind::Float64) -> NamedTuple

Produce a single campaign telemetry record with all key metrics.

Returns a NamedTuple suitable for building DataFrames row-by-row in
parameter sweep campaigns.
"""
function expansion_telemetry(
    sys::KiteTurbineSystem, p::SystemParams, power_w::Float64, v_wind::Float64
)
    m_airborne = expansion_airborne_mass(sys, p)
    phi_val = expansion_phi(sys, p, power_w)
    radii = expansion_radius_summary(sys)
    n_exp = length(sys.expansion_rotors)

    # Placement mode string
    placement = if n_exp == 0
        "none"
    elseif length(sys.expansion_rotors) >= 2
        # Detect if clustered (rings adjacent) or alternating
        ring_indices = sort([er.ring_idx for er in sys.expansion_rotors])
        diffs = diff(ring_indices)
        if all(d -> d == 1, diffs)
            "clustered"
        elseif all(d -> d >= 2, diffs)
            "alternating"
        else
            "custom"
        end
    else
        "single"
    end

    # Mean radius spread (how much expansion increased the radii)
    nominal_radii = [node.radius for node in sys.nodes if node isa RingNode]
    spreads = [
        radii[i] - nominal_radii[i] for i in 1:length(radii) if radii[i] != nominal_radii[i]
    ]
    mean_spread = isempty(spreads) ? 0.0 : mean(spreads)

    # Bank angle and blade span if expansion rotors present
    bank_angle = n_exp > 0 ? sys.expansion_rotors[1].bank_angle_deg : 0.0
    blade_tip = n_exp > 0 ? sys.expansion_rotors[1].blade_tip_radius : 0.0

    return (
        n_expansion=n_exp,
        placement=placement,
        n_rings=sys.n_ring,
        n_lines=p.n_lines,
        mass_airborne_kg=round(m_airborne; digits=3),
        mass_tether_kg=round(
            p.n_lines * p.tether_length * (DYNEEMA_DENSITY * π * (p.tether_diameter / 2)^2);
            digits=3,
        ),
        mass_expansion_kg=round(
            sum(er -> er.mass, sys.expansion_rotors; init=0.0); digits=3
        ),
        phi_kg_per_kw=round(phi_val; digits=4),
        power_w=power_w,
        wind_m_per_s=v_wind,
        mean_radius_spread_m=round(mean_spread; digits=6),
        bank_angle_deg=bank_angle,
        blade_tip_radius_m=blade_tip,
        hub_radius_m=p.rotor_radius,
        tether_diameter_mm=round(p.tether_diameter * 1000; digits=2),
        elevation_deg=round(rad2deg(p.elevation_angle); digits=1),
    )
end
