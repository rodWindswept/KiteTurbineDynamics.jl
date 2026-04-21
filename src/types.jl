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
    sub_segs    :: Vector{RopeSubSegment}  # all 300 sub-segments
    ring_ids    :: Vector{Int}             # global ids of ring nodes, in order ground→hub
    rotor       :: RotorSpec
    kite        :: KiteSpec
    n_ring      :: Int
    n_total     :: Int
end

state_size(sys::KiteTurbineSystem) = 6 * sys.n_total + 2 * sys.n_ring
