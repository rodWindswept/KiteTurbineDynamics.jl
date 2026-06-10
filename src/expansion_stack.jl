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
# Reference: PLAN.md Phase 2.1 — Configuration generator

# ══════════════════════════════════════════════════════════════════════════════
# Configuration struct
# ══════════════════════════════════════════════════════════════════════════════

"""
    ExpansionStackConfig

Configuration for a stack of expansion rotors mounted on TRPT rings.

# Fields
- `placement::Symbol`: `:alternating`, `:clustered`, or `:custom`
- `custom_rings::Vector{Int}`: explicit ring indices for `:custom` mode (default empty)
- `n_rings::Int`: total number of rings in the TRPT system
- `n_expansion::Int`: how many expansion rotors to place (clamped to available rings)
- `blade_radius::Float64`: tip radius of each blade (m)
- `hub_radius::Float64`: hub radius (m)
- `blade_chord::Float64`: chord length (m)
- `CL_blade::Float64`: blade lift coefficient
- `CD0_blade::Float64`: zero-lift drag coefficient
- `k_induced::Float64`: induced drag factor (CDᵢ = k·CL²)
- `bridle_angle_deg::Float64`: bridle angle from axial (degrees)
- `mass_per_rotor::Float64`: mass per expansion rotor assembly (kg)
- `shaft_coupling::Float64`: torque coupling factor (1.0 = rigid)
"""
struct ExpansionStackConfig
    placement        :: Symbol
    custom_rings     :: Vector{Int}
    n_rings          :: Int
    n_expansion      :: Int
    blade_radius     :: Float64
    hub_radius       :: Float64
    blade_chord      :: Float64
    CL_blade         :: Float64
    CD0_blade        :: Float64
    k_induced        :: Float64
    bridle_angle_deg :: Float64
    mass_per_rotor   :: Float64
    shaft_coupling   :: Float64
end

# Default constructor — custom_rings defaults to empty
function ExpansionStackConfig(; placement::Symbol, n_rings::Int, n_expansion::Int,
                               blade_radius::Float64, hub_radius::Float64,
                               blade_chord::Float64, CL_blade::Float64,
                               CD0_blade::Float64, k_induced::Float64,
                               bridle_angle_deg::Float64, mass_per_rotor::Float64,
                               shaft_coupling::Float64=1.0,
                               custom_rings::Vector{Int}=Int[])
    return ExpansionStackConfig(placement, custom_rings, n_rings, n_expansion,
                                 blade_radius, hub_radius, blade_chord,
                                 CL_blade, CD0_blade, k_induced,
                                 bridle_angle_deg, mass_per_rotor, shaft_coupling)
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
    # Take every other ring from the available list, starting from the ground end
    candidates = available[1:2:end]  # indices 1,3,5,7... = every other
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
    # Take the n_actual rings closest to the hub (largest indices), descending
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
        # Filter custom rings to available ones
        intersect(cfg.custom_rings, available)
    else
        error("Unknown placement mode: $(cfg.placement). Use :alternating, :clustered, or :custom.")
    end

    # Build ExpansionRotorParams for each selected ring
    n_blades = 3  # standard 3-blade configuration
    stack = ExpansionRotorParams[]
    for ring_idx in ring_indices
        er = ExpansionRotorParams(
            n_blades,
            cfg.blade_radius,
            cfg.hub_radius,
            cfg.blade_chord,
            cfg.CL_blade,
            cfg.CD0_blade,
            cfg.k_induced,
            cfg.bridle_angle_deg,
            cfg.mass_per_rotor,
            ring_idx,
            cfg.shaft_coupling,
        )
        push!(stack, er)
    end

    return stack
end
