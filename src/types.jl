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

The lift bearing — a free particle connecting the lift device and back line
to the hub ring vertices via bridle lines.  Position and velocity evolve
under the ODE like any other non-fixed node; the tension network determines
where it settles.
"""
struct BearingNode <: AbstractNode
    id   :: Int
    mass :: Float64        # bearing mass (~0.05 kg)
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
    nodes       :: Vector{AbstractNode}
    sub_segs    :: Vector{RopeSubSegment}  # all sub-segments (TRPT + bridle)
    ring_ids    :: Vector{Int}             # global ids of ring nodes, in order ground→hub
    rotor       :: RotorSpec
    kite        :: KiteSpec
    bearing_id  :: Int                     # global id of the BearingNode
    n_ring      :: Int
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
