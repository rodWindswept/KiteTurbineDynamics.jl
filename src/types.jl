abstract type AbstractNode end

"""Abstract supertype for all lift device configurations."""
abstract type LiftDevice end

struct RingNode <: AbstractNode
    id        :: Int
    ring_idx  :: Int       # index into twist sub-arrays (1-based)
    mass      :: Float64
    radius    :: Float64   # ring radius (m); 0 for ground anchor
    inertia_z :: Float64
    is_fixed  :: Bool
end

struct RopeNode <: AbstractNode
    id       :: Int
    mass     :: Float64
    line_idx :: Int        # which of the n_lines (1-based)
    seg_idx  :: Int        # which inter-ring segment (1-based)
    sub_idx  :: Int        # position within segment (1–3)
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
    id   :: Int
    mass :: Float64        # bearing mass (~0.05 kg)
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
    id   :: Int
    mass :: Float64        # ~0.3 kg — small splice/knot, not the lifter itself
end

# End of a sub-segment: either a rope node or a ring attachment point
struct SubSegmentEnd
    node_id  :: Int        # global node index
    is_ring  :: Bool
    line_idx :: Int        # which line — used to compute attachment angle on ring
end

struct RopeSubSegment
    end_a    :: SubSegmentEnd   # lower end (toward ground)
    end_b    :: SubSegmentEnd   # upper end (toward hub)
    length_0 :: Float64         # rest length (m)
    EA       :: Float64         # single-line axial stiffness × area (N)
    c_damp   :: Float64         # structural damping coefficient (N·s/m)
    diameter :: Float64         # line diameter (m)
end

struct RotorSpec
    node_id   :: Int
    radius    :: Float64
    mass      :: Float64
    inertia_z :: Float64
end

struct KiteSpec
    node_id        :: Int
    area           :: Float64
    mass           :: Float64
    CL             :: Float64
    CD             :: Float64
    tether_length  :: Float64
end

struct KiteTurbineSystem
    nodes          :: Vector{AbstractNode}
    sub_segs       :: Vector{RopeSubSegment}  # all sub-segments (TRPT + bridle + cyan line)
    ring_ids       :: Vector{Int}             # global ids of ring nodes, in order ground→hub
    rotor          :: RotorSpec
    kite           :: KiteSpec
    bearing_id     :: Int                     # global id of the BearingNode
    sky_anchor_id  :: Int                     # global id of the SkyAnchorNode (knot above bearing)
    n_ring         :: Int

    n_total     :: Int
    # Quasi-static disc tilt: accumulated non-shaft torque per ring (ring_idx order)
    # Updated each ODE step; drives ring-plane tilt for the next step.
    ring_tilt_axis :: Vector{Vector{Float64}}
end

# Compliance: rad of ring-plane tilt per N·m of non-shaft torque.
# 2.5e-7 → ~1.7° tilt at 1 m bearing offset, ~5° at 3 m.
const DISC_TILT_COMPLIANCE = 2.5e-7

# Exponential smoothing factor for tilt torque storage (low-pass filter).
# Models the ring's rotational inertia: α = exp(-dt/τ) where τ is the
# pitch time constant.  With dt=4e-5 and α=0.99, τ ≈ 4 ms.
const TILT_SMOOTH = 0.995

state_size(sys::KiteTurbineSystem) = 6 * sys.n_total + 2 * sys.n_ring
