# src/ring_element_analysis.jl
# Per-beam-element 3D space-frame structural analysis for TRPT ring polygons.
# Replaces the whole-polygon uniform-load assumption in structural_safety.jl.
#
# Each intermediate ring is a closed n-gon of CFRP beam elements with rigid
# knuckle joints (fixed-fixed ends, effective length K=0.5).  Tether forces at
# each vertex are resolved from the ODE state; a 6n×6n stiffness system is
# assembled and solved; per-beam N, M_ip, M_oop, T are recovered and combined
# into a single interaction utilisation ratio.

using LinearAlgebra

"""
    BeamResult

Structural result for one beam element (one polygon side) of a ring frame.
`utilisation = N/N_crit + √(M_ip²+M_oop²)/M_el`; failure when ≥ 1.
"""
struct BeamResult
    N           :: Float64   # axial compression (+ve = compressive, N)
    M_ip        :: Float64   # max in-plane bending moment at either end (N·m)
    M_oop       :: Float64   # max OOP bending moment at either end (N·m)
    T_tor       :: Float64   # torsion (N·m) — tracked but not in interaction formula
    N_crit      :: Float64   # fixed-fixed critical buckling load (N)
    M_el        :: Float64   # elastic bending moment capacity (N·m)
    utilisation :: Float64   # combined interaction ratio (1.0 = limit state)
    fos         :: Float64   # 1 / utilisation
    exceeded    :: Bool
end

"""
    RingElementFrame

Per-beam structural results for one intermediate ring.
`max_util` is the worst-beam scalar used by the HUD and warning flags.
"""
struct RingElementFrame
    ring_id  :: Int
    radius   :: Float64
    beams    :: Vector{BeamResult}   # length = n_lines
    max_util :: Float64              # maximum utilisation across all beams
end

"""
    beam_stiffness_local(E, G, A, I, J, L) → 12×12 Matrix

Standard 3D Euler–Bernoulli beam element stiffness in local coordinates.
DOF order: [u1,v1,w1,θx1,θy1,θz1, u2,v2,w2,θx2,θy2,θz2].
x = beam axis, y = in-plane transverse, z = OOP (ring normal direction).
I_y = I_z = I (circular tube, equal bending in both planes).
"""
function beam_stiffness_local(E::Float64, G::Float64, A::Float64,
                               I::Float64, J::Float64, L::Float64)::Matrix{Float64}
    a = E*A/L                # axial
    b = 12E*I/L^3            # bending shear
    c =  6E*I/L^2            # bending-rotation coupling
    d =  4E*I/L              # bending (same-end)
    e =  2E*I/L              # bending (far-end)
    f =  G*J/L               # torsion

    K = zeros(12, 12)

    # Axial: DOFs 1, 7
    K[1,1]= a; K[1,7]=-a
    K[7,1]=-a; K[7,7]= a

    # In-plane bending (x-y plane, about z): DOFs 2,6,8,12
    K[2,2]= b; K[2,6]= c; K[2,8]=-b; K[2,12]= c
    K[6,2]= c; K[6,6]= d; K[6,8]=-c; K[6,12]= e
    K[8,2]=-b; K[8,6]=-c; K[8,8]= b; K[8,12]=-c
    K[12,2]= c; K[12,6]= e; K[12,8]=-c; K[12,12]= d

    # OOP bending (x-z plane, about y): DOFs 3,5,9,11
    # θy positive counterclockwise from +y → coupling sign negative
    K[3,3]= b; K[3,5]=-c; K[3,9]=-b; K[3,11]=-c
    K[5,3]=-c; K[5,5]= d; K[5,9]= c; K[5,11]= e
    K[9,3]=-b; K[9,5]= c; K[9,9]= b; K[9,11]= c
    K[11,3]=-c; K[11,5]= e; K[11,9]= c; K[11,11]= d

    # Torsion: DOFs 4, 10
    K[4,4]= f; K[4,10]=-f
    K[10,4]=-f; K[10,10]= f

    return K
end

"""
    beam_transform(pa, pb, ring_normal) → 12×12 Matrix

Block-diagonal rotation matrix T mapping ring-local 3D frame to local beam frame.
pa, pb: 3D positions of the two beam-end vertices (in ring-local coordinates).
ring_normal: unit vector normal to the ring plane (shaft direction in ring-local = [0,0,1]).

Local beam axes:
  x_L = beam axis (pa → pb)
  z_L = ring_normal (OOP)
  y_L = z_L × x_L  (in-plane transverse, right-handed)

K_global_element = T' * K_local * T
"""
function beam_transform(pa::AbstractVector, pb::AbstractVector,
                         ring_normal::AbstractVector)::Matrix{Float64}
    x_L = (pb .- pa) ./ norm(pb .- pa)
    z_L = ring_normal ./ norm(ring_normal)
    y_L = cross(z_L, x_L)
    y_L ./= norm(y_L)

    R = [x_L'; y_L'; z_L']   # 3×3: rows are local axes in ring-local frame

    T = zeros(12, 12)
    for i in 0:3
        T[3i+1:3i+3, 3i+1:3i+3] = R
    end
    return T
end

"""
    assemble_ring_frame(R, n, α, tp, F_local)
        → (K_global, F_vec, K_locals, T_mats)

Assemble the 6n×6n global stiffness matrix and load vector for a closed n-gon ring.

Arguments:
  R       — ring radius (m)
  n       — number of polygon sides (= n_lines)
  α       — ring twist angle (rad); sets vertex azimuth φ_j = α + (j-1)·2π/n
  tp      — tube properties NamedTuple from tube_props(R); fields A, I_bend, J
  F_local — 3×n matrix of force vectors at each vertex in ring-local 3D frame

Returns:
  K_global — 6n×6n assembled stiffness matrix (with Tikhonov regularisation)
  F_vec    — 6n load vector
  K_locals — Vector of n 12×12 local stiffness matrices (for force recovery)
  T_mats   — Vector of n 12×12 transformation matrices (for force recovery)
"""
function assemble_ring_frame(R::Float64, n::Int, α::Float64,
                              tp::NamedTuple, F_local::Matrix{Float64})
    L_beam = 2.0 * R * sin(π / n)
    ring_normal = [0.0, 0.0, 1.0]   # z-axis in ring-local frame

    K_global = zeros(6n, 6n)
    F_vec    = zeros(6n)
    K_locals = Vector{Matrix{Float64}}(undef, n)
    T_mats   = Vector{Matrix{Float64}}(undef, n)

    for j in 1:n
        jnext = mod1(j + 1, n)
        φ_j    = α + (j    - 1) * 2π / n
        φ_jn   = α + (jnext - 1) * 2π / n
        pa = [R * cos(φ_j),  R * sin(φ_j),  0.0]
        pb = [R * cos(φ_jn), R * sin(φ_jn), 0.0]

        K_loc = beam_stiffness_local(E_CFRP, G_CFRP, tp.A, tp.I_bend, tp.J, L_beam)
        T_mat = beam_transform(pa, pb, ring_normal)
        K_elem = T_mat' * K_loc * T_mat

        K_locals[j] = K_loc
        T_mats[j]   = T_mat

        # Global DOF indices for vertices j and jnext
        idx = [6*(j-1)+1    : 6*j;
               6*(jnext-1)+1 : 6*jnext]
        K_global[idx, idx] .+= K_elem
    end

    # Load vector: point forces at each vertex (no applied moments)
    for j in 1:n
        F_vec[6*(j-1)+1 : 6*(j-1)+3] .= F_local[:, j]
    end

    # Self-equilibration check
    F_res = norm(sum(reshape(F_vec, 6, n), dims=2))          # net DOF imbalance across all nodes
    F_scl = maximum(abs, F_vec; init=1.0)
    if F_res / F_scl > 1e-2
        @warn "Ring frame: load imbalance $(round(F_res/F_scl*100, digits=1))% — inertial forces may be significant"
    end

    # Tikhonov regularisation — removes rigid body modes without pinning any DOF
    ε = 1e-6 * tr(K_global) / (6n)
    for i in 1:6n
        K_global[i, i] += ε
    end

    return K_global, F_vec, K_locals, T_mats
end

"""
    solve_ring_frame(K_global, F_vec) → d

Solve the regularised frame stiffness system K·d = F.
Returns the 6n nodal displacement vector.
"""
function solve_ring_frame(K_global::Matrix{Float64}, F_vec::Vector{Float64})::Vector{Float64}
    return K_global \ F_vec
end

"""
    extract_beam_forces(d, R, n, α, tp, K_locals, T_mats) → Vector{BeamResult}

Recover per-beam internal forces from the solved nodal displacement vector d.
Returns a Vector of n BeamResults (one per polygon side).

Sign convention:
  N > 0 = compressive (positive compression)
  M_ip, M_oop = max absolute bending moment at either end of the beam
  T_tor = torsion at node 1 of the beam
"""
function extract_beam_forces(d::Vector{Float64}, R::Float64, n::Int, α::Float64,
                              tp::NamedTuple, K_locals::Vector{Matrix{Float64}},
                              T_mats::Vector{Matrix{Float64}})::Vector{BeamResult}
    L_beam = 2.0 * R * sin(π / n)
    N_crit = 4.0 * π^2 * E_CFRP * tp.I_bend / L_beam^2   # fixed-fixed K=0.5
    M_el   = σ_CFRP_COMPR * tp.I_bend / (tp.Do / 2.0)    # elastic moment capacity

    results = Vector{BeamResult}(undef, n)

    for j in 1:n
        jnext = mod1(j + 1, n)

        # Extract 12-DOF element displacement in global ring-local frame
        idx_j    = 6*(j-1)+1    : 6*j
        idx_jn   = 6*(jnext-1)+1 : 6*jnext
        d_elem   = [d[idx_j]; d[idx_jn]]

        # Transform to local beam frame and compute local forces
        d_local  = T_mats[j] * d_elem
        f_local  = K_locals[j] * d_local

        # Internal forces (sign: f_local[1] = reaction on node 1 in +x_L direction)
        N_ax  = -f_local[1]         # compression positive
        M_ip  = max(abs(f_local[6]), abs(f_local[12]))   # bending about z (in-plane)
        M_oop = max(abs(f_local[5]), abs(f_local[11]))   # bending about y (OOP)
        T_tor = abs(f_local[4])                           # torsion

        util = beam_column_utilisation(N_ax, M_ip, M_oop, N_crit, M_el)
        fos  = util > 1e-12 ? 1.0 / util : Inf

        results[j] = BeamResult(N_ax, M_ip, M_oop, T_tor, N_crit, M_el,
                                 util, fos, util > 1.0)
    end
    return results
end

"""
    beam_column_utilisation(N, M_ip, M_oop, N_crit, M_el) → Float64

Combined axial + bending interaction ratio.
SRSS bending combination: util = N/N_crit + √(M_ip²+M_oop²)/M_el
util ≥ 1.0 means the beam has exceeded its combined capacity.
"""
function beam_column_utilisation(N::Float64, M_ip::Float64, M_oop::Float64,
                                  N_crit::Float64, M_el::Float64)::Float64
    N_term = max(N, 0.0) / max(N_crit, 1e-9)
    M_term = sqrt(M_ip^2 + M_oop^2) / max(M_el, 1e-9)
    return N_term + M_term
end

"""
    extract_vertex_forces(u, sys, ring_gid, alpha, p, perp1, perp2) → Matrix{Float64} (3 × n_lines)

Compute the net 3D tether force vector at each polygon vertex of the given ring.
Column j is the total force (N) acting on vertex j in the global simulation frame.
"""
function extract_vertex_forces(u       ::AbstractVector,
                                sys     ::KiteTurbineSystem,
                                ring_gid::Int,
                                alpha   ::AbstractVector,
                                p       ::SystemParams,
                                perp1   ::AbstractVector,
                                perp2   ::AbstractVector)::Matrix{Float64}
    node   = sys.nodes[ring_gid]::RingNode
    R      = node.radius
    ri     = node.ring_idx
    α_ring = alpha[ri]
    ctr    = u[3*(ring_gid-1)+1 : 3*ring_gid]
    n      = p.n_lines

    F_verts = zeros(3, n)   # 3D force at each vertex (global frame)

    for ss in sys.sub_segs
        on_b = ss.end_b.is_ring && ss.end_b.node_id == ring_gid
        on_a = ss.end_a.is_ring && ss.end_a.node_id == ring_gid
        (on_b || on_a) || continue

        if on_b
            j  = ss.end_b.line_idx
            pa = if ss.end_a.is_ring
                nd_a  = sys.nodes[ss.end_a.node_id]::RingNode
                ctr_a = u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
                attachment_point(ctr_a, nd_a.radius, alpha[nd_a.ring_idx],
                                 ss.end_a.line_idx, n, perp1, perp2)
            else
                u[3*(ss.end_a.node_id-1)+1 : 3*ss.end_a.node_id]
            end
            pb  = attachment_point(ctr, R, α_ring, j, n, perp1, perp2)
            len = norm(pb .- pa);  len < 1e-9 && continue
            T   = max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
            F_verts[:, j] .+= T .* ((pa .- pb) ./ len)   # force on pb toward pa

        else   # on_a
            j  = ss.end_a.line_idx
            pb = if ss.end_b.is_ring
                nd_b  = sys.nodes[ss.end_b.node_id]::RingNode
                ctr_b = u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
                attachment_point(ctr_b, nd_b.radius, alpha[nd_b.ring_idx],
                                 ss.end_b.line_idx, n, perp1, perp2)
            else
                u[3*(ss.end_b.node_id-1)+1 : 3*ss.end_b.node_id]
            end
            pa  = attachment_point(ctr, R, α_ring, j, n, perp1, perp2)
            len = norm(pb .- pa);  len < 1e-9 && continue
            T   = max(0.0, ss.EA * (len - ss.length_0) / ss.length_0)
            F_verts[:, j] .+= T .* ((pb .- pa) ./ len)   # force on pa toward pb
        end
    end

    return F_verts
end
