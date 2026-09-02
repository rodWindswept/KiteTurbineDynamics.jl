abstract type AbstractNode end

"""Abstract supertype for all lift device configurations."""
abstract type LiftDevice end

struct RingNode <: AbstractNode
    id::Int
    ring_idx::Int       # index into twist sub-arrays (1-based)
    mass::Float64
    radius::Float64   # ring radius (m); 0 for ground anchor
    inertia_z::Float64
    is_fixed::Bool
end

struct RopeNode <: AbstractNode
    id::Int
    mass::Float64
    line_idx::Int        # which of the n_lines (1-based)
    seg_idx::Int        # which inter-ring segment (1-based)
    sub_idx::Int        # position within segment (1–3)
end

"""
    BearingNode

The lift bearing — a free particle connecting the cyan line (up to the sky
anchor) to the hub ring vertices via bridle lines.  Position and velocity
evolve under the ODE like any other non-fixed node; the tension network
determines where it settles.

After the 2026-05-12 sky-anchor change the bearing no longer sees the
backline or the kite-lift force directly — those terminate at the sky
anchor, and the bearing only feels gravity, the N bridles to the hub ring,
and the cyan-line tension.  This keeps the bearing on the shaft axis with
equal bridle lengths regardless of lifter elevation.
"""
struct BearingNode <: AbstractNode
    id::Int
    mass::Float64        # bearing mass (~0.05 kg)
end

"""
    SkyAnchorNode

The "knot in the sky" where the cyan line (down to the bearing), the back
line (down to the ground anchor) and the lifter-kite force all meet.  In
real hardware this is a three-way splice on the upper end of the cyan
line; in the simulation it's a small free particle with a few hundred
grams of mass.

Modelled as a full ODE node (position + velocity in the state vector) so
that paying out the back line lets the kite lift the anchor — and the
bearing with it — naturally, without any quasi-static balance hack.
"""
struct SkyAnchorNode <: AbstractNode
    id::Int
    mass::Float64        # ~0.3 kg — small splice/knot, not the lifter itself
end

# End of a sub-segment: either a rope node or a ring attachment point
struct SubSegmentEnd
    node_id::Int        # global node index
    is_ring::Bool
    line_idx::Int        # which line — used to compute attachment angle on ring
end

struct RopeSubSegment
    end_a::SubSegmentEnd   # lower end (toward ground)
    end_b::SubSegmentEnd   # upper end (toward hub)
    length_0::Float64         # rest length (m)
    EA::Float64         # single-line axial stiffness × area (N)
    c_damp::Float64         # structural damping coefficient (N·s/m)
    diameter::Float64         # line diameter (m)
end

struct RotorSpec
    node_id::Int
    radius::Float64          # OUTER tip radius r_out (m) — TSR + tip-speed reference
    blade_hub_radius::Float64  # INNER tip radius r_in of the swept annulus (m, ≥ 0).
                             # Swept area = π(r_out² − r_in²). 0.0 = legacy full disk.
    mass::Float64
    inertia_z::Float64
    wind_factor::Float64     # inflow multiplier (1.0 = freestream; <1 = downstream wake)
end

# Backward-compat: legacy 5-arg construction means freestream (no blocking).
RotorSpec(node_id, radius, blade_hub_radius, mass, inertia_z) =
    RotorSpec(node_id, radius, blade_hub_radius, mass, inertia_z, 1.0)

struct KiteSpec
    node_id::Int
    area::Float64
    mass::Float64
    CL::Float64
    CD::Float64
    tether_length::Float64
end

struct KiteTurbineSystem
    nodes::Vector{AbstractNode}
    sub_segs::Vector{RopeSubSegment}  # all sub-segments (TRPT + bridle + cyan line)
    ring_ids::Vector{Int}             # global ids of ring nodes, in order ground→hub
    rotor::RotorSpec
    kite::KiteSpec
    bearing_id::Int                     # global id of the BearingNode
    sky_anchor_id::Int                     # global id of the SkyAnchorNode (knot above bearing)
    n_ring::Int

    n_total::Int
    # Quasi-static disc tilt: accumulated non-shaft torque per ring (ring_idx order)
    # Updated each ODE step; drives ring-plane tilt for the next step.
    ring_tilt_axis::Vector{Vector{Float64}}
    # Latched ground station PTO mechanical brake state
    brake_engaged::Ref{Bool}

    # Live MPPT gain constant k_mppt (N·m·s²/rad²) — mutable so the dashboard
    # and future soft-ramp controller can adjust generator load in real time
    # without reconstructing SystemParams.  Initialised from p.k_mppt.
    k_mppt_ref::Ref{Float64}

    # ── Dynamic kite position (first-order lag toward sky-anchor equilibrium) ──
    # In previous model the kite was frozen at the design sky-anchor position,
    # which created a spurious geometric spring that oscillated when the sky
    # anchor rose above its design point during backline payout.
    #
    # Physics: the kite cannot snap instantly to a new equilibrium — it has
    # inertia (m_lifter ≈ 4 kg) and the 25 m lift line has aerodynamic drag.
    # We model this as a first-order lag:
    #
    #   d(kite_pos)/dt = (kite_eq(sky_anchor_pos) − kite_pos) / τ_kite
    #
    # where kite_eq = sky_anchor_pos + lift_line_len · lift_dir  (instantaneous
    # equilibrium if the kite could teleport) and τ_kite is the time constant.
    #
    # The lift line tension acts along  (kite_pos − sky_anchor_pos); if this
    # vector is shorter than the design line length the line is slack (T = 0).
    kite_pos::Vector{Float64}   # 3-element mutable; updated each simulation step

    # ── Expansion rotors (Phase 1) ────────────────────────────────────────
    # Aerodynamic expansion rotor elements mounted on TRPT rings.
    # Empty vector = no expansion rotors (backward-compatible with v5).
    expansion_rotors::Vector{ExpansionRotorParams}

    # Effective ring radii after expansion spreading (m).
    # Same length as ring_ids; updated each ODE step when expansion
    # rotors are present.  Initialised to nominal ring radii at build time.
    effective_radii::Vector{Float64}

    # Ring beam design geometry — populated by builder, read by ring_element_analysis
    ring_Do_top::Base.RefValue{Float64}
    ring_toverD::Base.RefValue{Float64}
    ring_aspect_ratio::Base.RefValue{Float64}
    # Taper law: Do(r) = Do_top · (r / r_ref)^exp.  r_ref is the hub ring
    # radius (design.r_hub) so the campaign path (design === nothing in
    # analyse_ring) reproduces the design path exactly.  Exp is the DE genome
    # x4 (Do_scale_exp); 0.5 recovers the legacy √R law.  Zero r_ref means
    # "fall back to p.trpt_hub_radius" for legacy builders that predate these
    # refs.
    ring_Do_scale_exp::Base.RefValue{Float64}
    ring_r_hub::Base.RefValue{Float64}

    # True airborne ring structural mass and ring→cable knuckle mass, summed
    # per-ring by the builder (build_system_from_v10) and read by
    # expansion_airborne_mass.  0.0 = not yet populated (legacy builders that
    # predate these fields); expansion_airborne_mass falls back to the old
    # (n_ring − 1)·p.m_ring average in that case.
    ring_mass_total::Base.RefValue{Float64}
    ring_knuckle_mass::Base.RefValue{Float64}

    # Rope break state (2026-08-14): one flag per sub-segment (BitVector);
    # any_broken is a dirty latch checked per step by run_canonical_sim!
    # for the early-exit disqualification (Rod: option B).
    broken_lines::BitVector
    any_broken::Ref{Bool}
    # Break detection is enabled only for REAL operation (run_canonical_sim!),
    # not the settle's exploratory transients, which can over-strain a line
    # momentarily while searching the equilibrium (would break healthy
    # machines before their eval even starts).
    breaks_enabled::Ref{Bool}
    # Static mapping sub-seg index → TRPT segment index (1..n_ring-1; 0 for
    # non-TRPT chain sub-segs like bridle/cyan). Precomputed at build because
    # the per-sub-seg scan would be O(n) per step in the hot loop. TRPT lines
    # are ring→rope-node→…→ring chains, so "both ends rings" is NOT the
    # classification — membership is by node-gid range between consecutive
    # ring_ids.
    sub_seg_trpt_seg::Vector{Int}
end

# Default ring geometry (legacy circular 0.05 t/D, Do ∝ √R)
# Used when builder doesn't populate these fields
function default_ring_do(R::Float64)
    return max(0.01396 * sqrt(R), 5e-4 / 0.05)
end

# Default kite time constant (s).
# Physical basis:
#   m_lifter = 4 kg, lift line length = 25 m.
#   Aerodynamic damping on the line scales as ρ·CD·d·L·v ≈ 1.225·1.0·0.003·25·6 ≈ 0.55 N/(m/s).
#   τ = m / c_aero ≈ 4 / 0.55 ≈ 7 s at 6 m/s wind.
#   Rounded conservatively to 3 s to reflect that the rotary lifter is heavier
#   and stiffer than a passive kite but the line still has finite drag.
const KITE_TAU_S = 3.0

state_size(sys::KiteTurbineSystem) = 6 * sys.n_total + 2 * sys.n_ring
