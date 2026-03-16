# KiteTurbineDynamics.jl Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build `KiteTurbineDynamics.jl` — a new Julia package with full individual-line rope physics for the TRPT kite turbine, replacing the analytical torsion model with emergent geometry-driven torsional coupling.

**Architecture:** 241 unified nodes (16 RingNodes + 225 RopeNodes), 1478-state ODE. Each of the 5 tether lines per inter-ring segment is modelled individually with 3 intermediate rope nodes (4 sub-segments). Torsional coupling emerges from attachment-point geometry — no analytical torque formula. Tensile-only spring clamp makes torsional collapse and line sag physically emergent.

**Tech Stack:** Julia 1.12, DifferentialEquations.jl (QNDF), GLMakie 0.13+, LinearAlgebra, Printf, CSV, DataFrames

**Design doc:** `TRPTKiteTurbineJulia2/docs/plans/2026-03-16-kite-turbine-dynamics-design.md`
**Source reference:** `~/Documents/GitHub/TRPTKiteTurbineJulia2/src/` — port aerodynamics.jl, wind_profile.jl, parameters.jl verbatim or near-verbatim

---

## Node Index Formula (memorise this)

```
N_total  = 241   (16 ring/hub/ground + 225 rope)
N_ring   = 16

Ring node k (0-indexed, k=0=ground, k=15=hub):
  global_id = 1 + k*16
  ring_idx  = k + 1         ← index into 16-element twist sub-arrays

Rope node in segment s (1–15), line j (1–5), sub m (1–3):
  global_id = (s-1)*16 + 2 + (j-1)*3 + (m-1)

State vector:
  pos[i]   = u[3*(i-1)+1  : 3*i]          i ∈ 1:241
  vel[i]   = u[3*241+3*(i-1)+1 : 3*241+3*i]
  alpha[k] = u[6*241 + k]                  k ∈ 1:16  (ring_idx)
  omega[k] = u[6*241 + 16 + k]
  Total    = 6*241 + 2*16 = 1478
```

---

## Task 1: Package Scaffold

**Files:**
- Create: `~/Documents/GitHub/KiteTurbineDynamics.jl/Project.toml`
- Create: `~/Documents/GitHub/KiteTurbineDynamics.jl/src/KiteTurbineDynamics.jl`
- Create: `~/Documents/GitHub/KiteTurbineDynamics.jl/test/runtests.jl`

**Step 1: Create directory tree**
```bash
mkdir -p ~/Documents/GitHub/KiteTurbineDynamics.jl/{src,test,scripts,docs/plans}
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
git init
```

**Step 2: Write Project.toml**
```toml
name = "KiteTurbineDynamics"
uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
authors = ["Rod Read <rod@windswept.energy>"]
version = "0.1.0"

[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b466-afe8fa294f15"
DifferentialEquations = "0c46a032-eb83-5123-abaf-570d42b7fbaa"
GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d3"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
julia = "1.12"
```

**Step 3: Write package entry point**
```julia
# src/KiteTurbineDynamics.jl
module KiteTurbineDynamics

using LinearAlgebra, Printf, Statistics

include("parameters.jl")
include("aerodynamics.jl")
include("wind_profile.jl")
include("types.jl")
include("geometry.jl")
include("initialization.jl")
include("rope_forces.jl")
include("ring_forces.jl")
include("dynamics.jl")
include("structural_safety.jl")
include("visualization.jl")

export SystemParams, params_10kw, params_50kw
export RingNode, RopeNode, KiteTurbineSystem
export build_kite_turbine_system, state_size
export multibody_ode!

end
```

**Step 4: Write minimal test harness**
```julia
# test/runtests.jl
using Test

@testset "KiteTurbineDynamics" begin
    include("test_types.jl")
    include("test_geometry.jl")
    include("test_static_equilibrium.jl")
    include("test_emergent_torsion.jl")
    include("test_rope_sag.jl")
    include("test_power.jl")
end
```

**Step 5: Install dependencies**
```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

**Step 6: Commit**
```bash
git add .
git commit -m "feat: initial package scaffold"
```

---

## Task 2: Port Aerodynamics and Wind Profile

**Files:**
- Create: `src/aerodynamics.jl`  (copy from TRPTKiteTurbineJulia2)
- Create: `src/wind_profile.jl`  (copy from TRPTKiteTurbineJulia2)
- Create: `test/test_aerodynamics.jl`

**Step 1: Copy files verbatim**
```bash
cp ~/Documents/GitHub/TRPTKiteTurbineJulia2/src/aerodynamics.jl src/
cp ~/Documents/GitHub/TRPTKiteTurbineJulia2/src/wind_profile.jl src/
```

**Step 2: Write smoke tests**
```julia
# test/test_aerodynamics.jl  (add include to runtests.jl)
using Test
using KiteTurbineDynamics

@testset "aerodynamics" begin
    # Cp peaks near TSR 7 for a well-designed rotor
    @test cp_at_tsr(7.0) > 0.4
    @test cp_at_tsr(0.0) ≈ 0.0 atol=0.01
    @test cp_at_tsr(20.0) < 0.1

    # Ct is positive and bounded
    @test ct_at_tsr(7.0) > 0.0
    @test ct_at_tsr(7.0) < 1.0
end
```

**Step 3: Run tests**
```bash
julia --project=. test/runtests.jl
```
Expected: all aerodynamics tests pass.

**Step 4: Commit**
```bash
git add src/aerodynamics.jl src/wind_profile.jl test/test_aerodynamics.jl
git commit -m "feat: port aerodynamics and wind profile"
```

---

## Task 3: SystemParams

**Files:**
- Create: `src/parameters.jl`
- Create: `test/test_parameters.jl`

**Step 1: Write failing test**
```julia
# test/test_parameters.jl
using Test, KiteTurbineDynamics

@testset "parameters" begin
    p = params_10kw()
    @test p.n_rings == 14
    @test p.n_lines == 5
    @test p.rotor_radius > 0
    @test p.tether_length > 0
    @test p.v_wind_ref > 0
end
```

**Step 2: Run — expect failure (SystemParams not defined)**

**Step 3: Port parameters.jl from TRPTKiteTurbineJulia2**
```bash
cp ~/Documents/GitHub/TRPTKiteTurbineJulia2/src/parameters.jl src/
```
Remove any `include()` calls that reference files not yet present.

**Step 4: Run tests — expect pass**
```bash
julia --project=. test/runtests.jl
```

**Step 5: Commit**
```bash
git add src/parameters.jl test/test_parameters.jl
git commit -m "feat: port SystemParams and preset configurations"
```

---

## Task 4: Node Types and KiteTurbineSystem

**Files:**
- Create: `src/types.jl`
- Create: `test/test_types.jl`

**Step 1: Write failing tests**
```julia
# test/test_types.jl
using Test, KiteTurbineDynamics

@testset "types and node counts" begin
    p = params_10kw()
    sys = build_kite_turbine_system(p)

    # Node counts
    n_ring  = p.n_rings + 2          # ground + 14 rings + hub = 16
    n_rope  = p.n_lines * 3 * (p.n_rings + 1)  # 5 * 3 * 15 = 225
    n_total = n_ring + n_rope        # 241

    @test length(sys.nodes) == n_total
    @test count(n -> isa(n, RingNode), sys.nodes) == n_ring
    @test count(n -> isa(n, RopeNode), sys.nodes) == n_rope

    # State size
    @test state_size(sys) == 6 * n_total + 2 * n_ring  # 1478

    # ring_idx values are 1:n_ring without gaps
    ring_nodes = filter(n -> isa(n, RingNode), sys.nodes)
    idxs = sort([n.ring_idx for n in ring_nodes])
    @test idxs == collect(1:n_ring)

    # Ground node is fixed
    @test sys.nodes[1].is_fixed == true

    # Hub node is last RingNode
    hub = sys.nodes[end]
    @test isa(hub, RingNode)
    @test hub.is_fixed == false
end
```

**Step 2: Run — expect failure**

**Step 3: Write types.jl**
```julia
# src/types.jl
abstract type AbstractNode end

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
```

`build_kite_turbine_system` will be added in Task 6 (initialization). For now add a stub:
```julia
# bottom of types.jl — stub so tests can load
function build_kite_turbine_system(p::SystemParams)
    error("build_kite_turbine_system not yet implemented")
end
```

**Step 4: Run test — expect error "not yet implemented" (not a load error)**

**Step 5: Commit**
```bash
git add src/types.jl test/test_types.jl
git commit -m "feat: node types, KiteTurbineSystem, state_size"
```

---

## Task 5: Geometry Helpers

**Files:**
- Create: `src/geometry.jl`
- Create: `test/test_geometry.jl`

**Step 1: Write failing tests**
```julia
# test/test_geometry.jl
using Test, KiteTurbineDynamics, LinearAlgebra

@testset "geometry" begin
    β = deg2rad(30.0)
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Basis vectors are unit length
    @test norm(perp1) ≈ 1.0 atol=1e-10
    @test norm(perp2) ≈ 1.0 atol=1e-10

    # All three are mutually orthogonal
    @test abs(dot(shaft_dir, perp1)) < 1e-10
    @test abs(dot(shaft_dir, perp2)) < 1e-10
    @test abs(dot(perp1, perp2))     < 1e-10

    # Attachment point is at correct radius from ring centre
    centre = [10.0, 0.0, 8.0]
    R      = 2.5
    alpha  = 0.3
    j      = 1
    n_lines = 5
    pt = attachment_point(centre, R, alpha, j, n_lines, perp1, perp2)
    @test norm(pt .- centre) ≈ R atol=1e-10

    # Five attachment points are equally spaced (same radius, 2π/5 apart)
    pts = [attachment_point(centre, R, alpha, j, n_lines, perp1, perp2) for j in 1:5]
    for j in 1:5
        @test norm(pts[j] .- centre) ≈ R atol=1e-10
    end
    angles = [atan(dot(pts[j].-centre, perp2), dot(pts[j].-centre, perp1)) for j in 1:5]
    diffs  = diff(sort(angles))
    @test all(d -> abs(d - 2π/5) < 1e-8, diffs)

    # Helix interpolation: fraction=0 → attachment A, fraction=1 → attachment B
    pos_A = pts[1]
    pos_B = [12.0, 1.0, 9.5]
    @test rope_helix_pos(pos_A, pos_B, 0.0) ≈ pos_A atol=1e-10
    @test rope_helix_pos(pos_A, pos_B, 1.0) ≈ pos_B atol=1e-10
end
```

**Step 2: Run — expect failure**

**Step 3: Write geometry.jl**
```julia
# src/geometry.jl
using LinearAlgebra

"""
    shaft_perp_basis(shaft_dir) → (perp1, perp2)

Two unit vectors spanning the plane perpendicular to shaft_dir.
perp1 × perp2 is parallel to shaft_dir (right-hand rule).
"""
function shaft_perp_basis(shaft_dir::AbstractVector)
    ref   = abs(shaft_dir[3]) < 0.99 ? [0.0, 0.0, 1.0] : [0.0, 1.0, 0.0]
    perp1 = normalize(cross(shaft_dir, ref))
    perp2 = cross(shaft_dir, perp1)
    return perp1, perp2
end

"""
    attachment_point(centre, R, alpha, j, n_lines, perp1, perp2) → Vector{Float64}

3D position of line j's attachment point on a ring with centre `centre`,
radius `R`, twist angle `alpha`, in a plane with basis (perp1, perp2).
"""
function attachment_point(centre::AbstractVector, R::Float64,
                           alpha::Float64, j::Int, n_lines::Int,
                           perp1::AbstractVector, perp2::AbstractVector)
    φ = alpha + (j - 1) * (2π / n_lines)
    return centre .+ R .* (cos(φ) .* perp1 .+ sin(φ) .* perp2)
end

"""
    rope_helix_pos(pos_a, pos_b, frac) → Vector{Float64}

Linear interpolation between two attachment points at fraction `frac` ∈ [0,1].
Used to place rope nodes at initialisation. Gravity will sag them from this
straight-line position during the pre-solve settling step.
"""
function rope_helix_pos(pos_a::AbstractVector, pos_b::AbstractVector, frac::Float64)
    return pos_a .+ frac .* (pos_b .- pos_a)
end
```

**Step 4: Run tests — expect pass**
```bash
julia --project=. test/runtests.jl
```

**Step 5: Commit**
```bash
git add src/geometry.jl test/test_geometry.jl
git commit -m "feat: shaft basis, attachment points, helix interpolation"
```

---

## Task 6: System Initialisation

**Files:**
- Modify: `src/types.jl` — replace stub with real `build_kite_turbine_system`
- Create: `src/initialization.jl`

**Step 1: Write the real build function in initialization.jl**
```julia
# src/initialization.jl
using LinearAlgebra

"""
    build_kite_turbine_system(p; kite_area, kite_mass, kite_tether_length)
        → (sys::KiteTurbineSystem, u0::Vector{Float64})

Constructs the KiteTurbineSystem and a starting state vector u0 with nodes
placed along the shaft axis (rope nodes linearly interpolated between rings).
u0 is suitable as initial conditions for the pre-solve settling step.
"""
function build_kite_turbine_system(p::SystemParams;
                                   kite_area::Float64          = 10.0,
                                   kite_mass::Float64          = 5.0,
                                   kite_tether_length::Float64 = 20.0)

    n_seg    = p.n_rings + 1        # 15
    n_ring   = p.n_rings + 2        # 16  (ground + rings + hub)
    n_rope   = p.n_lines * 3 * n_seg  # 225
    n_total  = n_ring + n_rope        # 241

    β         = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # ── Ring radii (linear taper ground→hub) ──────────────────────────────
    r_top = p.trpt_hub_radius
    r_bot = 2.0 * p.tether_length * p.trpt_rL_ratio / n_seg - r_top
    seg_len_0 = p.tether_length / n_seg

    ring_radii = Vector{Float64}(undef, n_ring)
    ring_radii[1] = r_bot   # ground anchor (radius unused but defined)
    for k in 1:p.n_rings
        frac           = (k - 0.5) / n_seg
        ring_radii[k+1] = r_bot + frac * (r_top - r_bot)
    end
    ring_radii[n_ring] = r_top  # hub

    # ── Ring node positions along shaft ───────────────────────────────────
    EA_total  = p.e_modulus * π * (p.tether_diameter / 2)^2 * p.n_lines
    k_axial   = EA_total / seg_len_0

    m_rotor   = p.n_blades * p.m_blade
    g_z       = -9.81
    v         = p.v_wind_ref
    q         = 0.5 * p.rho * v^2
    kite_lift_z = q * kite_area * 1.2
    thrust_ax   = q * π * p.rotor_radius^2 * 0.8 * cos(β)^2
    F_aero_z    = kite_lift_z + thrust_ax * sin(β) + (m_rotor + kite_mass) * g_z
    F_top_ax    = max(-F_aero_z / sin(β), 20.0)

    g_axial_inc = p.m_ring * 9.81 / sin(β)
    F_axial     = zeros(n_seg)
    F_axial[n_seg] = F_top_ax
    for i in (n_seg-1):-1:1
        F_axial[i] = F_axial[i+1] + g_axial_inc
    end

    ring_pos = Vector{Vector{Float64}}(undef, n_ring)
    ring_pos[1] = [0.0, 0.0, 0.0]
    for i in 1:n_seg
        stretch     = max(0.0, F_axial[i] / k_axial)
        ring_pos[i+1] = ring_pos[i] .+ (seg_len_0 + stretch) .* shaft_dir
    end

    # ── Build node list (interleaved: ground, rope×15, ring, rope×15, ...) ─
    nodes = Vector{AbstractNode}(undef, n_total)
    ring_ids = Vector{Int}(undef, n_ring)

    EA_single = p.e_modulus * π * (p.tether_diameter / 2)^2
    sub_len_0 = seg_len_0 / 4.0
    m_rope_sub = DYNEEMA_DENSITY * π * (p.tether_diameter/2)^2 * sub_len_0

    # ground (ring index k=0)
    nodes[1] = RingNode(1, 1, 1e30, ring_radii[1], 1e30 * ring_radii[1]^2, true)
    ring_ids[1] = 1

    for s in 1:n_seg                      # segment s connects ring (s-1) to ring s
        # rope nodes for this segment
        for j in 1:p.n_lines
            for m in 1:3
                gid = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                nodes[gid] = RopeNode(gid, m_rope_sub, j, s, m)
            end
        end
        # ring at top of segment
        ring_k     = s          # 1-indexed ring (ring 1 … hub=15)
        gid_ring   = 1 + s * 16
        inertia_z  = (s < n_seg) ? p.m_ring * ring_radii[s+1]^2 :
                                   m_rotor * p.rotor_radius^2
        mass_node  = (s < n_seg) ? p.m_ring : m_rotor
        nodes[gid_ring] = RingNode(gid_ring, s+1, mass_node, ring_radii[s+1],
                                   inertia_z, false)
        ring_ids[s+1] = gid_ring
    end

    # ── Build sub-segment list (300 total) ────────────────────────────────
    zeta   = 1.5
    c_damp = 2.0 * zeta * sqrt(EA_single / sub_len_0 * m_rope_sub)
    sub_segs = Vector{RopeSubSegment}()
    sizehint!(sub_segs, 4 * p.n_lines * n_seg)

    for s in 1:n_seg
        ring_a_gid = ring_ids[s]      # lower ring global id
        ring_b_gid = ring_ids[s+1]    # upper ring global id
        for j in 1:p.n_lines
            # 4 sub-segs per line per segment:
            # end0 = ring A attachment, end1 = rope sub 1,
            # end2 = rope sub 2, end3 = rope sub 3, end4 = ring B attachment
            ends = Vector{SubSegmentEnd}(undef, 5)
            ends[1] = SubSegmentEnd(ring_a_gid, true,  j)
            for m in 1:3
                gid      = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                ends[m+1] = SubSegmentEnd(gid, false, j)
            end
            ends[5] = SubSegmentEnd(ring_b_gid, true, j)

            for sub in 1:4
                push!(sub_segs, RopeSubSegment(
                    ends[sub], ends[sub+1],
                    sub_len_0, EA_single, c_damp, p.tether_diameter))
            end
        end
    end

    rotor = RotorSpec(ring_ids[end], p.rotor_radius, m_rotor,
                      m_rotor * p.rotor_radius^2)
    kite  = KiteSpec(ring_ids[end], kite_area, kite_mass, 1.2, 0.1,
                     kite_tether_length)

    sys = KiteTurbineSystem(nodes, sub_segs, ring_ids, rotor, kite, n_ring, n_total)

    # ── Initial state vector (straight-line rope placement) ───────────────
    u0 = zeros(Float64, state_size(sys))
    for k in 1:n_ring
        gid = ring_ids[k]
        u0[3*(gid-1)+1 : 3*gid] .= ring_pos[k]
    end
    for s in 1:n_seg
        ring_a_pos = ring_pos[s]
        ring_b_pos = ring_pos[s+1]
        alpha_a = 0.0; alpha_b = 0.0   # zero twist at initialisation
        for j in 1:p.n_lines
            pa = attachment_point(ring_a_pos, ring_radii[s],   alpha_a, j, p.n_lines, perp1, perp2)
            pb = attachment_point(ring_b_pos, ring_radii[s+1], alpha_b, j, p.n_lines, perp1, perp2)
            for m in 1:3
                frac = m / 4.0
                gid  = (s-1)*16 + 2 + (j-1)*3 + (m-1)
                u0[3*(gid-1)+1 : 3*gid] .= rope_helix_pos(pa, pb, frac)
            end
        end
    end

    return sys, u0
end
```

**Step 2: Replace stub in types.jl**

Remove the stub `build_kite_turbine_system` error function from `types.jl`.

**Step 3: Add DYNEEMA_DENSITY constant** — add to `parameters.jl` (it's currently in `force_analysis.jl` in v2):
```julia
const DYNEEMA_DENSITY = 970.0   # kg/m³
```

**Step 4: Run type tests — expect pass**
```bash
julia --project=. test/runtests.jl
```
All test_types.jl tests should pass.

**Step 5: Commit**
```bash
git add src/initialization.jl src/types.jl src/parameters.jl
git commit -m "feat: build_kite_turbine_system, 241 nodes, 300 sub-segments"
```

---

## Task 7: Rope Forces

**Files:**
- Create: `src/rope_forces.jl`
- Create: `test/test_rope_forces.jl`

**Step 1: Write failing test**
```julia
# test/test_rope_forces.jl
using Test, KiteTurbineDynamics, LinearAlgebra

@testset "rope forces" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N   = sys.n_total
    Nr  = sys.n_ring

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)

    # zero wind, zero velocity, straight-line init
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]
    alpha   = zeros(Nr)

    compute_rope_forces!(forces, torques, u0, alpha, sys, p, wind_fn, 0.0)

    # At rest on straight line with zero twist: net force on interior rope
    # nodes should be zero (no stretch, no wind).
    # Pick a middle rope node and check force is ~0
    mid_rope_gid = 8   # some rope node in segment 1
    @test norm(forces[mid_rope_gid]) < 1e-6

    # Forces on ring nodes from rope: at zero twist, net torque should be ~0
    @test maximum(abs.(torques)) < 1e-6
end
```

**Step 2: Run — expect failure**

**Step 3: Write rope_forces.jl**
```julia
# src/rope_forces.jl
using LinearAlgebra

"""
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t)

Accumulates sub-segment spring/damper/drag forces into `forces[i]` for all nodes,
and shaft-axis torques into `torques[k]` for RingNodes (indexed by ring_idx).

`alpha` is a length-n_ring vector of current twist angles (ring_idx order).
"""
function compute_rope_forces!(forces      ::Vector{<:AbstractVector},
                               torques     ::AbstractVector,
                               u           ::AbstractVector,
                               alpha       ::AbstractVector,
                               sys         ::KiteTurbineSystem,
                               p           ::SystemParams,
                               wind_fn     ::Function,
                               t           ::Float64)

    N  = sys.n_total
    Nr = sys.n_ring
    β  = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    # Helper: 3D position of a SubSegmentEnd
    function end_pos(se::SubSegmentEnd)
        if se.is_ring
            node  = sys.nodes[se.node_id]
            ri    = (node::RingNode).ring_idx
            R     = (node::RingNode).radius
            α     = alpha[ri]
            ctr   = u[3*(se.node_id-1)+1 : 3*se.node_id]
            return attachment_point(ctr, R, α, se.line_idx, p.n_lines, perp1, perp2)
        else
            return u[3*(se.node_id-1)+1 : 3*se.node_id]
        end
    end

    # Helper: velocity at a SubSegmentEnd (ring attachment point moves with ring)
    function end_vel(se::SubSegmentEnd)
        base = u[3*N+3*(se.node_id-1)+1 : 3*N+3*se.node_id]
        return base   # attachment point velocity ≈ ring centre velocity (ring is rigid)
    end

    for ss in sys.sub_segs
        pa = end_pos(ss.end_a)
        pb = end_pos(ss.end_b)
        va = end_vel(ss.end_a)
        vb = end_vel(ss.end_b)

        diff_pos    = pb .- pa
        current_len = norm(diff_pos)
        current_len < 1e-9 && continue

        dir      = diff_pos ./ current_len
        rel_vel  = vb .- va
        vel_proj = dot(rel_vel, dir)
        strain   = (current_len - ss.length_0) / ss.length_0
        tension  = max(0.0, ss.EA * strain + ss.c_damp * vel_proj)
        F_vec    = tension .* dir

        # Aerodynamic drag on the mid-point mass (rope nodes only)
        # Applied to end_b when it is a rope node (distributes half to each end
        # for a continuous rod, but lumped-mass: apply to the rope node)
        if !ss.end_b.is_ring
            mid_pos = (pa .+ pb) ./ 2.0
            v_wind  = wind_fn(Float64.(mid_pos), t)
            v_node  = vb
            v_rel   = v_wind .- v_node
            v_perp  = v_rel .- dot(v_rel, dir) .* dir
            v_perp_mag = norm(v_perp)
            if v_perp_mag > 0.01
                drag = 0.5 * p.rho * 1.0 * ss.diameter * ss.length_0 *
                       v_perp_mag .* v_perp
                forces[ss.end_b.node_id] .+= drag
            end
        end

        # Apply spring force to nodes
        if ss.end_a.is_ring
            node_a  = sys.nodes[ss.end_a.node_id]::RingNode
            ri_a    = node_a.ring_idx
            ctr_a   = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
            r_vec_a = pa .- ctr_a
            forces[ss.end_a.node_id]   .+= F_vec
            torques[ri_a]              += dot(cross(r_vec_a, F_vec), shaft_dir)
        else
            forces[ss.end_a.node_id] .+= F_vec
        end

        if ss.end_b.is_ring
            node_b  = sys.nodes[ss.end_b.node_id]::RingNode
            ri_b    = node_b.ring_idx
            ctr_b   = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
            r_vec_b = pb .- ctr_b
            forces[ss.end_b.node_id]   .-= F_vec
            torques[ri_b]              += dot(cross(r_vec_b, -F_vec), shaft_dir)
        else
            forces[ss.end_b.node_id] .-= F_vec
        end
    end
end
```

**Step 4: Run tests — expect pass**
```bash
julia --project=. test/runtests.jl
```

**Step 5: Commit**
```bash
git add src/rope_forces.jl test/test_rope_forces.jl
git commit -m "feat: rope sub-segment spring/drag forces with emergent torsion"
```

---

## Task 8: Ring Forces (Rotor, Kite, Generator)

**Files:**
- Create: `src/ring_forces.jl`
- Create: `test/test_ring_forces.jl`

**Step 1: Write failing test**
```julia
# test/test_ring_forces.jl
using Test, KiteTurbineDynamics, LinearAlgebra

@testset "ring forces" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    N   = sys.n_total
    Nr  = sys.n_ring

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    omega   = zeros(Nr)

    wind_fn = (pos, t) -> [p.v_wind_ref, 0.0, 0.0]

    compute_ring_forces!(forces, torques, u0, omega, sys, p, wind_fn, 0.0)

    hub_gid = sys.rotor.node_id
    # Kite lift should push hub upward at rated wind
    @test forces[hub_gid][3] > 0

    # Aero torque on hub should be positive (rotor spinning)
    hub_ring_idx = (sys.nodes[hub_gid]::RingNode).ring_idx
    # Note: omega is zero so tau_aero = 0 (guarded). Check no NaN instead.
    @test !isnan(torques[hub_ring_idx])
end
```

**Step 2: Run — expect failure**

**Step 3: Write ring_forces.jl** — port from `multibody_dynamics.jl` lines 43–95,
extracting the kite and rotor force/torque logic:
```julia
# src/ring_forces.jl
using LinearAlgebra

function compute_ring_forces!(forces  ::Vector{<:AbstractVector},
                               torques ::AbstractVector,
                               u       ::AbstractVector,
                               omega   ::AbstractVector,
                               sys     ::KiteTurbineSystem,
                               p       ::SystemParams,
                               wind_fn ::Function,
                               t       ::Float64)
    N        = sys.n_total
    hub_gid  = sys.rotor.node_id
    hub_ri   = (sys.nodes[hub_gid]::RingNode).ring_idx
    hub_pos  = u[3*(hub_gid-1)+1 : 3*hub_gid]
    hub_vel  = u[3*N+3*(hub_gid-1)+1 : 3*N+3*hub_gid]
    β        = p.elevation_angle

    v_wind  = wind_fn(Float64.(hub_pos), t)
    v_app   = v_wind .- hub_vel
    v_mag   = norm(v_app)

    # ── Kite lift + drag ───────────────────────────────────────────────────
    if v_mag > 0.1
        q        = 0.5 * p.rho * v_mag^2
        drag_dir = v_app ./ v_mag
        ẑ        = [0.0, 0.0, 1.0]
        ẑ_perp   = ẑ .- dot(ẑ, drag_dir) .* drag_dir
        n_zp     = norm(ẑ_perp)
        lift_dir = n_zp > 1e-6 ? ẑ_perp ./ n_zp : ẑ
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CL .* lift_dir
        forces[hub_gid] .+= q * sys.kite.area * sys.kite.CD .* drag_dir
    end

    # ── Rotor thrust + aero torque ─────────────────────────────────────────
    v_hub_mag = norm(v_wind)
    if v_hub_mag > 0.1
        omega_rotor = omega[hub_ri]
        lambda_t    = abs(omega_rotor) * sys.rotor.radius / v_hub_mag
        elev_angle  = atan(real(hub_pos[3]), norm(real.(hub_pos[1:2])))

        thrust_mag  = 0.5 * p.rho * v_hub_mag^2 *
                      π * sys.rotor.radius^2 * 0.8 * cos(elev_angle)^2
        tether_dir  = hub_pos .- u[1:3]   # ground is node 1
        tl          = norm(tether_dir)
        if tl > 0; tether_dir ./= tl; end
        forces[hub_gid] .+= thrust_mag .* tether_dir

        P_aero   = 0.5 * p.rho * v_hub_mag^3 *
                   π * sys.rotor.radius^2 * cp_at_tsr(lambda_t) * cos(elev_angle)^3
        tau_aero = abs(omega_rotor) > 0.1 ?
                   sign(omega_rotor) * P_aero / abs(omega_rotor) : 0.0
        torques[hub_ri] += tau_aero
    end

    # ── Generator MPPT torque on ground node ──────────────────────────────
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx   # = 1
    omega_gnd = omega[gnd_ri]
    tau_gen   = p.k_mppt * omega_gnd^2 * sign(omega_gnd + 1e-9)
    torques[gnd_ri] -= tau_gen
end
```

**Step 4: Run tests — expect pass**

**Step 5: Commit**
```bash
git add src/ring_forces.jl test/test_ring_forces.jl
git commit -m "feat: ring forces — kite aero, rotor thrust/torque, generator MPPT"
```

---

## Task 9: ODE — dynamics.jl

**Files:**
- Create: `src/dynamics.jl`
- Create: `test/test_dynamics.jl`

**Step 1: Write failing test**
```julia
# test/test_dynamics.jl
using Test, KiteTurbineDynamics, LinearAlgebra

@testset "ODE smoke test" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]  # zero wind
    du      = zeros(state_size(sys))

    # Should not throw
    @test_nowarn multibody_ode!(du, u0, (sys, p, wind_fn), 0.0)

    # du should not contain NaN or Inf
    @test all(isfinite, du)
end
```

**Step 2: Run — expect failure**

**Step 3: Write dynamics.jl**
```julia
# src/dynamics.jl
using LinearAlgebra

function multibody_ode!(du, u, params, t)
    sys, p, wind_fn = params
    N  = sys.n_total
    Nr = sys.n_ring
    g  = [0.0, 0.0, -9.81]

    # ── Extract twist states ───────────────────────────────────────────────
    alpha = u[6N+1    : 6N+Nr]
    omega = u[6N+Nr+1 : 6N+2Nr]

    # ── Initialise accumulators ────────────────────────────────────────────
    forces  = [zeros(eltype(u), 3) for _ in 1:N]
    torques = zeros(eltype(u), Nr)

    # ── Gravity on all nodes ───────────────────────────────────────────────
    for i in 1:N
        node = sys.nodes[i]
        m    = node isa RingNode ? node.mass : node.mass
        forces[i] .+= m .* g
    end

    # ── Rope sub-segment forces (spring/damp/drag + emergent torsion) ──────
    compute_rope_forces!(forces, torques, u, alpha, sys, p, wind_fn, t)

    # ── Rotor/kite aero + generator torque ────────────────────────────────
    compute_ring_forces!(forces, torques, u, omega, sys, p, wind_fn, t)

    # ── Assemble du ────────────────────────────────────────────────────────
    for i in 1:N
        node   = sys.nodes[i]
        bp     = 3*(i-1)+1
        bv     = 3N+3*(i-1)+1

        if node isa RingNode && node.is_fixed
            du[bp:bp+2]   .= 0.0
            du[bv:bv+2]   .= 0.0
        else
            du[bp:bp+2] .= u[bv:bv+2]        # d(pos)/dt = vel
            m = node isa RingNode ? node.mass : (node::RopeNode).mass
            du[bv:bv+2] .= forces[i] ./ m    # d(vel)/dt = F/m
        end
    end

    # Twist states — only for RingNodes
    for node in sys.nodes
        node isa RingNode || continue
        ri    = node.ring_idx
        I_z   = node.inertia_z
        du[6N + ri]      = omega[ri]
        du[6N + Nr + ri] = node.is_fixed ? 0.0 : torques[ri] / I_z
    end

    return nothing
end
```

**Step 4: Run tests — expect pass**
```bash
julia --project=. test/runtests.jl
```

**Step 5: Commit**
```bash
git add src/dynamics.jl test/test_dynamics.jl
git commit -m "feat: multibody_ode! with unified 1478-state vector"
```

---

## Task 10: Static Equilibrium Pre-Solve

**Files:**
- Modify: `src/initialization.jl` — add `settle_to_equilibrium!`
- Create: `test/test_static_equilibrium.jl`
- Create: `test/test_rope_sag.jl`

**Step 1: Write failing tests**
```julia
# test/test_static_equilibrium.jl
using Test, KiteTurbineDynamics, LinearAlgebra, DifferentialEquations

@testset "static equilibrium" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    u_settled = settle_to_equilibrium(sys, u0, p)

    N  = sys.n_total
    Nr = sys.n_ring

    # Hub should be above ground
    hub_gid = sys.rotor.node_id
    hub_z   = u_settled[3*(hub_gid-1)+3]
    @test hub_z > 5.0

    # No node should be below ground except the fixed ground anchor
    for i in 2:N
        z = u_settled[3*(i-1)+3]
        @test z >= -0.5   # allow tiny numerical overshoot
    end

    # All velocities should be near zero after settling
    vels = u_settled[3N+1 : 6N]
    @test maximum(abs.(vels)) < 1.0
end

# test/test_rope_sag.jl
@testset "rope sag in zero wind" begin
    p_low = SystemParams(params_10kw(); v_wind_ref=0.5)  # near-zero wind
    sys, u0 = build_kite_turbine_system(p_low)
    u_settled = settle_to_equilibrium(sys, u0, p_low)

    # Middle rope node in segment 1, line 1 (sub_idx=2) should sag below
    # the straight line between its two ring attachment points
    seg1_rope_mid_gid = 4   # seg=1, line=1, sub=2 → global id = 4
    rope_z = u_settled[3*(seg1_rope_mid_gid-1)+3]

    # The two ring attachment points for seg 1
    gnd_z = u_settled[3]      # ground at 0
    ring1_gid = sys.ring_ids[2]
    ring1_z   = u_settled[3*(ring1_gid-1)+3]
    midline_z = (gnd_z + ring1_z) / 2.0

    # Rope node should be below the straight line (sagging)
    @test rope_z < midline_z
end
```

**Step 2: Run — expect failure**

**Step 3: Add settle_to_equilibrium to initialization.jl**
```julia
"""
    settle_to_equilibrium(sys, u0, p; t_settle=5.0) → Vector{Float64}

Runs the ODE at zero wind and zero rotation with high damping for `t_settle`
seconds to let rope nodes sag under gravity to their true equilibrium positions.
Returns the settled state vector.
"""
function settle_to_equilibrium(sys::KiteTurbineSystem,
                                u0 ::Vector{Float64},
                                p  ::SystemParams;
                                t_settle::Float64 = 5.0)
    wind_zero = (pos, t) -> [0.0, 0.0, 0.0]
    prob = ODEProblem(multibody_ode!, u0, (0.0, t_settle), (sys, p, wind_zero))
    sol  = solve(prob, QNDF(autodiff=false),
                 saveat=t_settle, maxiters=1_000_000,
                 abstol=1e-2, reltol=1e-2)
    return sol.u[end]
end
```

Add `using DifferentialEquations` to `initialization.jl`.

**Step 4: Run tests — expect pass**
```bash
julia --project=. test/runtests.jl
```

**Step 5: Commit**
```bash
git add src/initialization.jl test/test_static_equilibrium.jl test/test_rope_sag.jl
git commit -m "feat: settle_to_equilibrium pre-solve, gravity sag test passing"
```

---

## Task 11: Emergent Torsion Test

**Files:**
- Create: `test/test_emergent_torsion.jl`

**Step 1: Write test**
```julia
# test/test_emergent_torsion.jl
using Test, KiteTurbineDynamics, LinearAlgebra

@testset "emergent torsion" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)

    # Apply a small twist between ring 1 and ground: increase alpha[2]
    # (ring 1 ring_idx = 2)
    Nr = sys.n_ring
    N  = sys.n_total
    alpha = zeros(Nr)
    alpha[2] = 0.1   # 0.1 rad twist on ring 1

    forces  = [zeros(3) for _ in 1:N]
    torques = zeros(Nr)
    wind_fn = (pos, t) -> [0.0, 0.0, 0.0]

    # Use pre-settled state but inject the twist
    u_test = copy(u0)
    u_test[6N+2] = 0.1   # alpha[2] = 0.1 rad

    compute_rope_forces!(forces, torques, u_test, alpha, sys, p, wind_fn, 0.0)

    # Torque on ring 1 (ring_idx=2) should oppose the twist (restoring torque)
    @test torques[2] < 0.0   # negative = opposing positive twist

    # Torque on ground (ring_idx=1) should be positive (reaction)
    @test torques[1] > 0.0
end
```

**Step 2: Run — expect pass** (emergent torsion is already coded in rope_forces.jl)

**Step 3: Commit**
```bash
git add test/test_emergent_torsion.jl
git commit -m "test: verify emergent torsional coupling direction"
```

---

## Task 12: Power Generation Test

**Files:**
- Create: `test/test_power.jl`

**Step 1: Write test**
```julia
# test/test_power.jl
using Test, KiteTurbineDynamics, LinearAlgebra, DifferentialEquations

@testset "power generation" begin
    p   = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    u_settled = settle_to_equilibrium(sys, u0, p)

    # Seed hub with startup omega
    N  = sys.n_total
    Nr = sys.n_ring
    u_start = copy(u_settled)
    u_start[6N + Nr + Nr] = 1.0   # hub ring_idx=Nr, omega = 1 rad/s

    wind_fn = (pos, t) -> begin
        z  = max(pos[3], 1.0)
        sh = (z / p.h_ref)^(1.0/7.0)
        [p.v_wind_ref * sh, 0.0, 0.0]
    end

    prob = ODEProblem(multibody_ode!, u_start, (0.0, 30.0), (sys, p, wind_fn))
    sol  = solve(prob, QNDF(autodiff=false),
                 saveat=1.0, maxiters=5_000_000,
                 abstol=1e-3, reltol=1e-3)

    @test sol.retcode == ReturnCode.Success || sol.t[end] > 15.0

    # Hub should be spinning at end
    omega_hub_final = sol.u[end][6N + Nr + Nr]
    @test abs(omega_hub_final) > 0.5   # at least 0.5 rad/s
end
```

**Step 2: Run — this test will be slow (~minutes). Expected: pass**
```bash
julia --project=. -e 'include("test/test_power.jl")'
```

**Step 3: Commit**
```bash
git add test/test_power.jl
git commit -m "test: power generation at rated wind"
```

---

## Task 13: Structural Safety Indicators

**Files:**
- Create: `src/structural_safety.jl`

**Step 1: Write structural_safety.jl**
```julia
# src/structural_safety.jl
# Ring hoop compression and buckling FoS — post-process only, no ODE coupling.

const RING_SWL      = 500.0    # N — conservative buckling limit
const TETHER_SWL    = 3500.0   # N — Dyneema 3mm safe working load

"""
    ring_safety_frame(u, alpha, sys, p) → Vector{NamedTuple}

Compute per-ring hoop compression and Euler buckling FoS for one ODE frame.
"""
function ring_safety_frame(u::AbstractVector, alpha::AbstractVector,
                            sys::KiteTurbineSystem, p::SystemParams)
    N        = sys.n_total
    Nr       = sys.n_ring
    β        = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)

    results = Vector{NamedTuple}()
    E_ring  = p.e_modulus
    d_ring  = 0.005   # 5 mm ring cross-section diameter (placeholder — update from DRR)
    I_ring  = π * (d_ring/2)^4 / 4.0

    for (k, ring_gid) in enumerate(sys.ring_ids[2:end-1])  # skip ground and hub
        node = sys.nodes[ring_gid]::RingNode
        R    = node.radius
        ri   = node.ring_idx

        # Sum inward radial tension components from all lines at this ring
        α_ring = alpha[ri]
        ctr    = u[3*(ring_gid-1)+1 : 3*ring_gid]
        F_inward = 0.0

        for ss in sys.sub_segs
            # Only sub-segments whose end_b is this ring (upper attachment)
            if ss.end_b.is_ring && ss.end_b.node_id == ring_gid
                pa = if ss.end_a.is_ring
                    node_a = sys.nodes[ss.end_a.node_id]::RingNode
                    ctr_a  = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                    attachment_point(ctr_a, node_a.radius, alpha[node_a.ring_idx],
                                     ss.end_a.line_idx, p.n_lines, perp1, perp2)
                else
                    u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                end
                pb  = attachment_point(ctr, R, α_ring, ss.end_b.line_idx,
                                       p.n_lines, perp1, perp2)
                len = norm(pb .- pa)
                len < 1e-9 && continue
                dir    = (pb .- pa) ./ len
                strain = (len - ss.length_0) / ss.length_0
                T      = max(0.0, ss.EA * strain)
                r_vec  = pb .- ctr
                r_norm = norm(r_vec)
                r_norm < 1e-9 && continue
                r_hat  = r_vec ./ r_norm
                F_inward += T * abs(dot(dir, -r_hat))   # inward radial component
            end
        end

        F_hoop  = F_inward / (2π)
        L_circ  = 2π * R
        P_crit  = (π^2 * E_ring * I_ring) / L_circ^2
        util    = F_hoop / max(P_crit, 1e-9)
        fos     = P_crit / max(F_hoop, 1e-9)

        push!(results, (ring_id=k, radius=R,
                        F_hoop=F_hoop, P_crit=P_crit,
                        utilisation=util, fos=fos,
                        exceeded=(util > 1.0)))
    end
    return results
end
```

**Step 2: Commit**
```bash
git add src/structural_safety.jl
git commit -m "feat: ring hoop compression and buckling FoS safety indicators"
```

---

## Task 14: GLMakie Dashboard

**Files:**
- Create: `src/visualization.jl`
- Create: `scripts/interactive_dashboard.jl`

**Step 1: Port visualization.jl from TRPTKiteTurbineJulia2**

Copy `TRPTKiteTurbineJulia2/src/visualization.jl` as a starting point, then update:

- `extract_geometry` must read rope node positions directly from `u` (no formula — they're in the state vector)
- Tether line rendering: for each segment s, line j, connect `[attachment_A, rope_sub_1, rope_sub_2, rope_sub_3, attachment_B]` — 5 points per line, 4 segments visible
- Ring coloring: use `ring_safety_frame` utilisation ratio (blue→red vs buckling limit) instead of twist ratio
- Tether line coloring: tension vs TETHER_SWL (need to read tension from most recent sub-segment spring forces)
- HUD: add ring FoS panel; keep power, omega/RPM, collapse warning

The structural HUD should display:
```
Structural Loads
Tether: max XXXX N · FoS X.X
Rings:  max utilisation XX%
!! BUCKLING RISK  (if any ring util > 0.8)
!! TORSIONAL COLLAPSE (if any line slack > threshold)
```

**Step 2: Write scripts/interactive_dashboard.jl**
```julia
# scripts/interactive_dashboard.jl
using Pkg; Pkg.activate(".")
using KiteTurbineDynamics, GLMakie, DifferentialEquations, Printf

p        = params_10kw()
sys, u0  = build_kite_turbine_system(p)
u_start  = settle_to_equilibrium(sys, u0, p)

# Seed hub omega for startup
N  = sys.n_total
Nr = sys.n_ring
u_start[6N + Nr + Nr] = 1.0

wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

prob = ODEProblem(multibody_ode!, u_start, (0.0, 60.0), (sys, p, wind_fn))
println("Solving 60 s simulation...")
sol  = solve(prob, QNDF(autodiff=false),
             saveat=0.2, maxiters=10_000_000,
             abstol=1e-3, reltol=1e-3)
println("Solved: $(length(sol.t)) frames, t_end=$(sol.t[end]) s")

fig = build_dashboard(sys, p, sol)
display(fig)
wait(fig.scene)
```

**Step 3: Run smoke test**
```bash
julia --project=. scripts/interactive_dashboard.jl
```
Expected: window opens showing rope sag, helical tether lines, ring polygons.

**Step 4: Commit**
```bash
git add src/visualization.jl scripts/interactive_dashboard.jl
git commit -m "feat: GLMakie dashboard with rope node geometry and structural HUD"
```

---

## Task 15: README and OSS Preparation

**Files:**
- Create: `README.md`
- Verify: `Project.toml` UUID is real (generate with `import UUIDs; UUIDs.uuid4()`)

**Step 1: Generate a real UUID**
```julia
julia -e 'import UUIDs; println(UUIDs.uuid4())'
```
Replace the placeholder UUID in `Project.toml`.

**Step 2: Write README.md** covering: what it is, install, quick start, system diagram description, link to Windswept & Interesting, MIT licence.

**Step 3: Final test run**
```bash
julia --project=. test/runtests.jl
```
Expected: all tests pass.

**Step 4: Final commit**
```bash
git add README.md Project.toml
git commit -m "docs: README, real UUID, ready for OSS release"
```

---

## Summary

| Task | Key deliverable | Tests |
|---|---|---|
| 1 | Package scaffold | — |
| 2 | aerodynamics + wind_profile | smoke tests |
| 3 | SystemParams | field checks |
| 4 | Node types + KiteTurbineSystem | node counts, state size |
| 5 | Geometry helpers | attachment point, basis |
| 6 | build_kite_turbine_system | 241 nodes, 300 sub-segs |
| 7 | rope_forces.jl | zero-force at rest |
| 8 | ring_forces.jl | kite lift, no NaN |
| 9 | multibody_ode! | no NaN, finite du |
| 10 | settle_to_equilibrium | sag test, no below-ground |
| 11 | Emergent torsion | restoring torque direction |
| 12 | Power generation | hub spinning at rated wind |
| 13 | Structural safety | ring FoS computed |
| 14 | GLMakie dashboard | visual smoke test |
| 15 | README + UUID | all tests pass |
