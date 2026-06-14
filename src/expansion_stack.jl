# src/expansion_stack.jl
#
# Expansion rotor stack configuration generator for Phase 2 campaigns.
#
# Defines how expansion rotors are placed across the TRPT ring stack.
# Three placement modes:
#
#   :alternating — every other ring gets an expansion rotor, starting from
#                  ring 2 (skipping ground ring 1 and hub ring N).
#   :clustered   — expansion rotors clustered near the hub (largest radius → 
#                  most effective spreading, since F_radial ∝ r² via v_app²).
#   :custom      — explicit list of ring indices supplied by the user.
#
# The generator produces a Vector{ExpansionRotorParams} that can be passed
# directly to KiteTurbineSystem's `expansion_rotors` field.
#
# Expansion blades use the SAME span and chord as the generating rotor —
# identical blade mould, just banked downward toward the next ring.
# See src/expansion_rotor.jl for the force model.
#
# Reference: PLAN.md Phase 2.1 — Configuration generator

# ══════════════════════════════════════════════════════════════════════════════
# Configuration struct
# ══════════════════════════════════════════════════════════════════════════════

"""
    ExpansionStackConfig

Configuration for a stack of expansion rotors mounted on TRPT rings.
Blade geometry (span, chord, count) is inherited from the generating rotor.

# Fields
- `placement::Symbol`: `:alternating`, `:clustered`, or `:custom`
- `custom_rings::Vector{Int}`: explicit ring indices for `:custom` mode (default empty)
- `n_rings::Int`: total number of rings in the TRPT system
- `n_expansion::Int`: how many expansion rotors to place (clamped to available rings)
- `n_blades::Int`: blade count (inherited from main rotor)
- `blade_span::Float64`: distance from ring to blade tip (m — same as main rotor tip radius)
- `blade_hub_radius::Float64`: distance from ring to inner edge of annulus (m — same as main rotor hub radius)
- `blade_chord::Float64`: chord length (m — same as main rotor: 0.113 × tip_radius)
- `CL_blade::Float64`: blade lift coefficient
- `CD0_blade::Float64`: zero-lift drag coefficient
- `k_induced::Float64`: induced drag factor (CDᵢ = k·CL²)
- `bank_angle_deg::Float64`: bank angle from rotation plane (degrees) — outer tip
  tilted down toward the next ring. Controls radial/axial split.
- `mass_per_rotor::Float64`: mass per expansion rotor assembly (kg)
- `shaft_coupling::Float64`: torque coupling factor (1.0 = rigid)
"""
struct ExpansionStackConfig
    placement::Symbol
    custom_rings::Vector{Int}
    n_rings::Int
    n_expansion::Int
    n_blades::Int
    blade_tip_radius::Float64
    blade_hub_radius::Float64
    blade_chord::Float64
    CL_blade::Float64
    CD0_blade::Float64
    k_induced::Float64
    bank_angle_deg::Float64
    mass_per_rotor::Float64
    shaft_coupling::Float64
end

# Default constructor — custom_rings defaults to empty
function ExpansionStackConfig(;
    placement::Symbol,
    n_rings::Int,
    n_expansion::Int,
    n_blades::Int,
    blade_tip_radius::Float64,
    blade_hub_radius::Float64,
    blade_chord::Float64,
    CL_blade::Float64,
    CD0_blade::Float64,
    k_induced::Float64,
    bank_angle_deg::Float64,
    mass_per_rotor::Float64,
    shaft_coupling::Float64=1.0,
    custom_rings::Vector{Int}=Int[],
)
    return ExpansionStackConfig(
        placement,
        custom_rings,
        n_rings,
        n_expansion,
        n_blades,
        blade_tip_radius,
        blade_hub_radius,
        blade_chord,
        CL_blade,
        CD0_blade,
        k_induced,
        bank_angle_deg,
        mass_per_rotor,
        shaft_coupling,
    )
end

# ══════════════════════════════════════════════════════════════════════════════
# Placement strategies
# ══════════════════════════════════════════════════════════════════════════════

"""
    _available_rings(n_rings::Int) -> Vector{Int}

Return the ring indices available for expansion rotors.
Excludes ring 1 (ground anchor) and ring n_rings (hub — already has main rotor).
"""
function _available_rings(n_rings::Int)
    return collect(2:(n_rings - 1))
end

"""
    _alternating_rings(available::Vector{Int}, n_expansion::Int) -> Vector{Int}

Place expansion rotors on every other ring, starting from ring 2 (ground end).
Gives uniform spacing for balanced spreading along the TRPT.
"""
function _alternating_rings(available::Vector{Int}, n_expansion::Int)
    candidates = available[1:2:end]
    n_actual = min(n_expansion, length(candidates))
    return candidates[1:n_actual]
end

"""
    _clustered_rings(available::Vector{Int}, n_expansion::Int) -> Vector{Int}

Place expansion rotors clustered near the hub (largest ring radii).
Most effective for spreading since F_radial ∝ r² via apparent wind.
Returns rings in descending order (hub-ward first).
"""
function _clustered_rings(available::Vector{Int}, n_expansion::Int)
    n_actual = min(n_expansion, length(available))
    return reverse(available[max(1, end - n_actual + 1):end])
end

# ══════════════════════════════════════════════════════════════════════════════
# Main generator
# ══════════════════════════════════════════════════════════════════════════════

"""
    build_expansion_stack(cfg::ExpansionStackConfig) -> Vector{ExpansionRotorParams}

Generate a vector of ExpansionRotorParams configured according to `cfg`.

The result can be passed directly to `KiteTurbineSystem(..., expansion_rotors=stack)`.
"""
function build_expansion_stack(cfg::ExpansionStackConfig)
    if cfg.n_expansion <= 0
        return ExpansionRotorParams[]
    end

    available = _available_rings(cfg.n_rings)
    if isempty(available)
        return ExpansionRotorParams[]
    end

    # Select ring indices based on placement strategy
    ring_indices = if cfg.placement == :alternating
        _alternating_rings(available, cfg.n_expansion)
    elseif cfg.placement == :clustered
        _clustered_rings(available, cfg.n_expansion)
    elseif cfg.placement == :custom
        intersect(cfg.custom_rings, available)
    else
        error(
            "Unknown placement mode: $(cfg.placement). Use :alternating, :clustered, or :custom.",
        )
    end

    # Build ExpansionRotorParams for each selected ring
    stack = ExpansionRotorParams[]
    for ring_idx in ring_indices
        er = ExpansionRotorParams(
            cfg.n_blades,
            cfg.blade_tip_radius,
            cfg.blade_hub_radius,
            cfg.blade_chord,
            cfg.CL_blade,
            cfg.CD0_blade,
            cfg.k_induced,
            cfg.bank_angle_deg,
            cfg.mass_per_rotor,
            ring_idx,
            cfg.shaft_coupling,
        )
        push!(stack, er)
    end

    return stack
end
