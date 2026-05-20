# Ring Per-Element Structural Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace whole-polygon uniform buckling with full 3D space-frame FEA per ring, giving per-beam combined N+M utilisation with fixed-fixed boundary conditions and per-beam colour rendering on the dashboard.

**Architecture:** New pure module `src/ring_element_analysis.jl` extracts per-vertex tether forces, assembles a 6n×6n 3D frame stiffness system (12×12 Euler–Bernoulli beam elements) with Tikhonov regularisation, solves for nodal displacements, and recovers N, M_ip, M_oop, T per beam. Existing `ring_safety_frame()` becomes a thin wrapper; `SimFrame` gains `ring_beam_utils`; the dashboard renders each polygon edge in its own colour.

**Tech Stack:** Julia 1.12, LinearAlgebra (stdlib), GLMakie, existing KiteTurbineDynamics types (`KiteTurbineSystem`, `SystemParams`, `RingNode`, `RopeSubSegment`).

**Spec:** `docs/superpowers/specs/2026-05-19-ring-element-analysis-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `src/ring_element_analysis.jl` | All per-element FEA logic — types, stiffness, assembly, solve, utilisation |
| Modify | `src/structural_safety.jl` | Add `G_CFRP`, `σ_CFRP_COMPR`; add `tube_props()`; `ring_safety_frame()` delegates to new module |
| Modify | `src/KiteTurbineDynamics.jl` | Add `include("ring_element_analysis.jl")` between structural_safety and sim_frame |
| Modify | `src/sim_frame.jl` | Add `ring_beam_utils` field to `SimFrame`; update `capture_frame()` |
| Modify | `src/visualization.jl` | Split ring polygon into per-beam `lines!`; extend progress to all scenarios |
| Create | `test/test_ring_element_analysis.jl` | Five unit/integration tests |
| Modify | `test/runtests.jl` | Include new test file |

---

## Task 1: Add constants and `tube_props` to `structural_safety.jl`

**Files:**
- Modify: `src/structural_safety.jl`

- [ ] **Add two constants after the existing CFRP block (after line 25)**

  In `src/structural_safety.jl`, after `const DO_SCALE = 0.01396`:
  ```julia
  const G_CFRP       = 5e9    # Pa — conservative shear modulus (woven CFRP layup)
  const σ_CFRP_COMPR = 600e6  # Pa — compressive strength (conservative unidirectional)
  ```

- [ ] **Replace `tube_I` with `tube_props` + backward-compat wrapper**

  Remove the existing `tube_I` function (lines 32–35) and replace with:
  ```julia
  """
      tube_props(R) → NamedTuple

  Cross-section properties of the CFRP design tube for a ring of radius R.
  Returns (Do, t, Di, A, I_bend, J) where J = 2·I_bend for a circular tube.
  """
  function tube_props(R::Float64)
      Do     = max(DO_SCALE * sqrt(R), T_MIN_WALL / T_OVER_D)
      t      = max(T_OVER_D * Do, T_MIN_WALL)
      Di     = Do - 2.0 * t
      A      = π / 4.0  * (Do^2 - Di^2)
      I_bend = π / 64.0 * (Do^4 - Di^4)
      J      = 2.0 * I_bend
      return (Do=Do, t=t, Di=Di, A=A, I_bend=I_bend, J=J)
  end

  # Backward-compat wrapper — existing callers unaffected
  tube_I(Do::Float64, t::Float64)::Float64 = π / 64.0 * (Do^4 - (Do - 2t)^4)
  ```

- [ ] **Update the existing inline tube sizing in `ring_safety_frame` to use `tube_props`**

  In `ring_safety_frame`, replace lines 122–125:
  ```julia
  # old:
  Do_design = max(DO_SCALE * sqrt(R), T_MIN_WALL / T_OVER_D)
  t_design  = max(T_OVER_D * Do_design, T_MIN_WALL)
  I_design  = tube_I(Do_design, t_design)
  P_crit    = π^2 * E_CFRP * I_design / L_poly^2
  ```
  with:
  ```julia
  tp       = tube_props(R)
  P_crit   = π^2 * E_CFRP * tp.I_bend / L_poly^2
  ```
  and update the `push!(results, ...)` line to use `tp.Do * 1e3` for `tube_Do_mm`.

- [ ] **Run the test suite to confirm nothing is broken**
  ```bash
  cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl/.claude/worktrees/stupefied-gauss-39fd0b
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20
  ```
  Expected: all existing tests pass.

- [ ] **Commit**
  ```bash
  git add src/structural_safety.jl
  git commit -m "refactor: add tube_props NamedTuple and CFRP shear/strength constants"
  ```

---

## Task 2: Scaffold `ring_element_analysis.jl` — types and module include

**Files:**
- Create: `src/ring_element_analysis.jl`
- Modify: `src/KiteTurbineDynamics.jl`

- [ ] **Create `src/ring_element_analysis.jl` with types**

  ```julia
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
  ```

- [ ] **Register the new file in `src/KiteTurbineDynamics.jl`**

  In `src/KiteTurbineDynamics.jl`, add between lines 15 and 17 (after structural_safety, before sim_frame):
  ```julia
  include("ring_element_analysis.jl")
  ```

- [ ] **Verify the module loads**
  ```bash
  julia --project=. -e 'using KiteTurbineDynamics; println("OK")'
  ```
  Expected: `OK` with no errors.

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl src/KiteTurbineDynamics.jl
  git commit -m "feat: scaffold ring_element_analysis module with BeamResult and RingElementFrame types"
  ```

---

## Task 3: Implement `beam_stiffness_local` — 12×12 Euler–Bernoulli matrix

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `beam_stiffness_local` to the module**

  DOF order per node: `[u, v, w, θx, θy, θz]`
  — `u` = axial (beam axis), `v` = in-plane transverse, `w` = OOP transverse,
    `θx` = torsion, `θy` = OOP bending rotation, `θz` = in-plane bending rotation.

  ```julia
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
  ```

- [ ] **Quick sanity check in REPL — cantilever deflection**

  A cantilever of length L with fixed node 1 (`w1=θy1=0`), point load P in +z at node 2
  must give `w2 = PL³/(3EI)`:

  ```julia
  julia --project=. -e '
  using KiteTurbineDynamics, LinearAlgebra
  E,G,A,I,J,L,P = 70e9, 5e9, 1e-4, 1e-8, 2e-8, 1.0, 100.0
  K = KiteTurbineDynamics.beam_stiffness_local(E,G,A,I,J,L)
  # Free DOFs for cantilever: fix u1,v1,w1,θx1,θy1,θz1 → keep DOFs 7-12
  Kff = K[7:12, 7:12]
  F   = zeros(6); F[3] = P   # load in w direction (DOF 9 in full, index 3 in reduced)
  d   = Kff \ F
  w2_numeric  = d[3]
  w2_analytic = P*L^3/(3E*I)
  println("w2 numeric = ", w2_numeric, "  analytic = ", w2_analytic,
          "  ratio = ", w2_numeric/w2_analytic)
  '
  ```
  Expected: `ratio = 1.0` (to machine precision).

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl
  git commit -m "feat: add beam_stiffness_local — 12x12 Euler-Bernoulli 3D beam element"
  ```

---

## Task 4: Implement `beam_transform` — local-to-global rotation

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `beam_transform` to the module**

  ```julia
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
  ```

- [ ] **Verify orthonormality**
  ```julia
  julia --project=. -e '
  using KiteTurbineDynamics, LinearAlgebra
  pa = [0.0, 2.0, 0.0]; pb = [1.902, 0.618, 0.0]; rn = [0.0, 0.0, 1.0]
  T = KiteTurbineDynamics.beam_transform(pa, pb, rn)
  R3 = T[1:3, 1:3]
  println("R orthonormal: ", isapprox(R3 * R3'"'"', I, atol=1e-12))
  println("det(R) = ", det(R3))
  '
  ```
  Expected: `R orthonormal: true`, `det(R) = 1.0`.

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl
  git commit -m "feat: add beam_transform — block-diagonal rotation matrix for 3D beam elements"
  ```

---

## Task 5: Implement `assemble_ring_frame` and `solve_ring_frame`

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `assemble_ring_frame` to the module**

  Works entirely in ring-local 3D coordinates (perp1/perp2/shaft_dir basis).
  Vertex j at position `[R·cos(φ_j), R·sin(φ_j), 0]` where `φ_j = α + (j-1)·2π/n`.

  ```julia
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
      F_res = norm(sum(reshape(F_vec[1:6:end], :), dims=1))   # residual force
      F_scl = maximum(abs, F_vec; init=1.0)
      if F_res / F_scl > 1e-2
          @warn "Ring frame: load imbalance $(round(F_res/F_scl*100, digits=1))% — inertial forces may be significant"
      end

      # Tikhonov regularisation — removes rigid body modes without pinning any DOF
      ε = 1e-6 * tr(K_global) / (6n)
      K_global .+= ε * I

      return K_global, F_vec, K_locals, T_mats
  end
  ```

- [ ] **Append `solve_ring_frame`**

  ```julia
  """
      solve_ring_frame(K_global, F_vec) → d

  Solve the regularised frame stiffness system K·d = F.
  Returns the 6n nodal displacement vector.
  """
  function solve_ring_frame(K_global::Matrix{Float64}, F_vec::Vector{Float64})::Vector{Float64}
      return K_global \ F_vec
  end
  ```

- [ ] **Smoke-test: symmetric inward loads on a pentagon give non-NaN displacements**
  ```julia
  julia --project=. -e '
  using KiteTurbineDynamics, LinearAlgebra
  R=2.0; n=5; α=0.0; F=1000.0
  tp = KiteTurbineDynamics.tube_props(R)
  # Inward radial force at each vertex (pointing toward centre)
  F_local = zeros(3, n)
  for j in 1:n
      φ = α + (j-1)*2π/n
      F_local[1,j] = -F*cos(φ)   # inward radial x-component
      F_local[2,j] = -F*sin(φ)   # inward radial y-component
  end
  K,Fv,_,_ = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
  d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
  println("d finite: ", all(isfinite, d))
  println("max |d|: ", maximum(abs, d))
  '
  ```
  Expected: `d finite: true`, some small displacement value.

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl
  git commit -m "feat: add assemble_ring_frame and solve_ring_frame with Tikhonov regularisation"
  ```

---

## Task 6: Implement `extract_beam_forces` and `beam_column_utilisation`

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `extract_beam_forces` to the module**

  ```julia
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
  ```

- [ ] **Append `beam_column_utilisation`**

  ```julia
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
  ```

- [ ] **Write the failing test for N_crit ratio (Test 2)**

  Create `test/test_ring_element_analysis.jl`:
  ```julia
  # test/test_ring_element_analysis.jl
  # Tests for the per-beam ring element structural analysis.

  @testset "ring_element_analysis" begin

  @testset "Test 2: fixed-fixed N_crit is 4× pin-pin" begin
      R = 2.0; n = 5
      tp = KiteTurbineDynamics.tube_props(R)
      L_beam = 2.0 * R * sin(π / n)
      N_crit_fixed = 4.0 * π^2 * KiteTurbineDynamics.E_CFRP * tp.I_bend / L_beam^2
      N_crit_pinpin =       π^2 * KiteTurbineDynamics.E_CFRP * tp.I_bend / L_beam^2
      @test isapprox(N_crit_fixed / N_crit_pinpin, 4.0, atol=1e-10)
  end

  end  # @testset "ring_element_analysis"
  ```

- [ ] **Run the failing test**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | grep -A5 "Test 2"
  ```
  Expected: Test 2 passes (it's a pure ratio; as long as the constants exist it should pass immediately). If it fails, check that `E_CFRP` is exported/accessible.

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl test/test_ring_element_analysis.jl
  git commit -m "feat: add extract_beam_forces, beam_column_utilisation, and N_crit ratio test"
  ```

---

## Task 7: Implement `extract_vertex_forces`

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `extract_vertex_forces` to the module**

  Mirrors the sub-segment loop in `ring_safety_frame()` but records 3D force vectors
  per vertex (indexed by `line_idx`) instead of summing a scalar.

  ```julia
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
  ```

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl
  git commit -m "feat: add extract_vertex_forces — per-vertex 3D tether force from ODE state"
  ```

---

## Task 8: Implement `analyse_ring` and `ring_element_analysis`

**Files:**
- Modify: `src/ring_element_analysis.jl`

- [ ] **Append `analyse_ring` to the module**

  ```julia
  """
      analyse_ring(u, sys, ring_gid, alpha, p) → RingElementFrame

  Full per-beam structural analysis for one intermediate ring:
    1. Extract per-vertex 3D tether forces from ODE state
    2. Transform forces to ring-local frame (perp1/perp2/shaft_dir)
    3. Assemble 6n×6n stiffness system and solve
    4. Recover N, M_ip, M_oop, T per beam and compute interaction utilisation
  """
  function analyse_ring(u       ::AbstractVector,
                         sys     ::KiteTurbineSystem,
                         ring_gid::Int,
                         alpha   ::AbstractVector,
                         p       ::SystemParams)::RingElementFrame
      node   = sys.nodes[ring_gid]::RingNode
      R      = node.radius
      ri     = node.ring_idx
      α_ring = alpha[ri]
      n      = p.n_lines
      β      = p.elevation_angle
      shaft_dir = [cos(β), 0.0, sin(β)]
      perp1, perp2 = shaft_perp_basis(shaft_dir)

      # Step 1: per-vertex forces in global frame (3 × n)
      F_global = extract_vertex_forces(u, sys, ring_gid, alpha, p, perp1, perp2)

      # Step 2: transform to ring-local 3D frame (perp1, perp2, shaft_dir as axes)
      R_to_local = [perp1'; perp2'; shaft_dir']   # 3×3
      F_local    = R_to_local * F_global           # 3×n in ring-local

      # Step 3: assemble and solve
      tp = tube_props(R)
      K_global, F_vec, K_locals, T_mats = assemble_ring_frame(R, n, α_ring, tp, F_local)
      d = solve_ring_frame(K_global, F_vec)

      # Step 4: recover per-beam forces
      beams    = extract_beam_forces(d, R, n, α_ring, tp, K_locals, T_mats)
      max_util = maximum(b.utilisation for b in beams; init=0.0)

      # ring_id relative to intermediate rings (will be set by caller)
      return RingElementFrame(ring_gid, R, beams, max_util)
  end
  ```

- [ ] **Append `ring_element_analysis` to the module**

  ```julia
  """
      ring_element_analysis(u, alpha, sys, p) → Vector{RingElementFrame}

  Run per-beam structural analysis for all intermediate rings (skipping ground and hub).
  Replaces `ring_safety_frame()` as the primary structural post-processing function.
  """
  function ring_element_analysis(u     ::AbstractVector,
                                  alpha ::AbstractVector,
                                  sys   ::KiteTurbineSystem,
                                  p     ::SystemParams)::Vector{RingElementFrame}
      results = Vector{RingElementFrame}()
      for (k, ring_gid) in enumerate(sys.ring_ids[2:end-1])
          frame = analyse_ring(u, sys, ring_gid, alpha, p)
          push!(results, RingElementFrame(k, frame.radius, frame.beams, frame.max_util))
      end
      return results
  end
  ```

- [ ] **Commit**
  ```bash
  git add src/ring_element_analysis.jl
  git commit -m "feat: add analyse_ring and ring_element_analysis — top-level per-ring FEA"
  ```

---

## Task 9: Write and verify integration tests (Tests 1, 3, 4, 5)

**Files:**
- Modify: `test/test_ring_element_analysis.jl`

- [ ] **Add Test 1 — symmetric inward load → uniform N, zero bending**

  Append inside the outer `@testset "ring_element_analysis"` block, after Test 2:
  ```julia
  @testset "Test 1: symmetric load → uniform N, zero M" begin
      R=2.0; n=5; α=0.0; F=1000.0
      tp = KiteTurbineDynamics.tube_props(R)

      # Equal inward radial force at each vertex
      F_local = zeros(3, n)
      for j in 1:n
          φ = α + (j-1) * 2π/n
          F_local[1,j] = -F * cos(φ)
          F_local[2,j] = -F * sin(φ)
      end

      K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
      d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
      beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

      N_analytic = F / (2.0 * tan(π / n))
      for b in beams
          @test isapprox(b.N, N_analytic, rtol=1e-4)
          @test isapprox(b.M_ip,  0.0, atol=1e-3)
          @test isapprox(b.M_oop, 0.0, atol=1e-3)
      end
  end
  ```

- [ ] **Add Test 3 — asymmetric load → N varies across beams**

  ```julia
  @testset "Test 3: asymmetric load → N varies" begin
      R=2.0; n=5; α=0.0; F=1000.0
      tp = KiteTurbineDynamics.tube_props(R)

      # Double force at vertex 1, no force at vertex 3 (same total inward force)
      F_local = zeros(3, n)
      forces = [2F, F, 0.0, F, F]   # inward magnitudes
      for j in 1:n
          φ = α + (j-1) * 2π/n
          F_local[1,j] = -forces[j] * cos(φ)
          F_local[2,j] = -forces[j] * sin(φ)
      end

      K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
      d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
      beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

      Ns = [b.N for b in beams]
      # All beams in compression (inward loads → compressive polygon)
      @test all(N -> N > 0, Ns)
      # N values are not all equal (asymmetric loading breaks uniformity)
      @test maximum(Ns) - minimum(Ns) > 1.0   # at least 1 N variation
  end
  ```

- [ ] **Add Test 4 — OOP load → M_oop > 0, M_ip ≈ 0**

  ```julia
  @testset "Test 4: OOP load → M_oop nonzero, M_ip zero" begin
      R=2.0; n=5; α=0.0; F=500.0
      tp = KiteTurbineDynamics.tube_props(R)

      # Pure shaft-direction (OOP) force at vertex 1 only
      # Self-equilibrate: equal and opposite at vertex 3
      F_local = zeros(3, n)
      F_local[3, 1] =  F     # OOP force at vertex 1
      F_local[3, 3] = -F     # opposing at vertex 3

      K,Fv,Klocs,Tmats = KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)
      d = KiteTurbineDynamics.solve_ring_frame(K, Fv)
      beams = KiteTurbineDynamics.extract_beam_forces(d, R, n, α, tp, Klocs, Tmats)

      # Adjacent beams to loaded vertex should have M_oop > 0
      @test beams[1].M_oop > 1.0    # beam 1→2 (adjacent to vertex 1)
      @test beams[n].M_oop > 1.0    # beam n→1 (adjacent to vertex 1)
      # In-plane moment should be near zero (pure OOP load, symmetric in-plane)
      @test beams[1].M_ip < 1.0
  end
  ```

- [ ] **Add Test 5 — self-equilibration warning**

  ```julia
  @testset "Test 5: self-equilibration warning fires for unbalanced loads" begin
      R=2.0; n=5; α=0.0
      tp = KiteTurbineDynamics.tube_props(R)

      # Unbalanced: net force = [1000, 0, 0]
      F_local = zeros(3, n)
      F_local[1, 1] = 1000.0   # lone force, not balanced

      @test_warn "load imbalance" KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local)

      # Balanced loads: no warning
      F_local2 = zeros(3, n)
      for j in 1:n
          φ = α + (j-1) * 2π/n
          F_local2[1,j] = -500.0 * cos(φ)
          F_local2[2,j] = -500.0 * sin(φ)
      end
      # If no warning, this just runs silently
      KiteTurbineDynamics.assemble_ring_frame(R, n, α, tp, F_local2)
  end
  ```

- [ ] **Register the test file in `test/runtests.jl`**

  Add before `test_dashboard_smoke`:
  ```julia
  include("test_ring_element_analysis.jl")
  ```

- [ ] **Run the full test suite**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -30
  ```
  Expected: all 5 ring_element_analysis tests pass. Fix any failures before proceeding.

- [ ] **Commit**
  ```bash
  git add test/test_ring_element_analysis.jl test/runtests.jl
  git commit -m "test: add ring_element_analysis integration tests (symmetric N, asymmetric N, OOP M, warning)"
  ```

---

## Task 10: Delegate `ring_safety_frame` to the new module

**Files:**
- Modify: `src/structural_safety.jl`

- [ ] **Replace `ring_safety_frame` body with delegation**

  Remove the current body of `ring_safety_frame` (lines 53–139 in the original file — everything
  after the function signature, before the `end`) and replace with:

  ```julia
  function ring_safety_frame(u      ::AbstractVector,
                              alpha  ::AbstractVector,
                              sys    ::KiteTurbineSystem,
                              p      ::SystemParams)
      frames = ring_element_analysis(u, alpha, sys, p)
      return [(ring_id     = f.ring_id,
               radius      = f.radius,
               N_comp      = maximum(b.N     for b in f.beams; init=0.0),
               P_crit      = maximum(b.N_crit for b in f.beams; init=1.0),
               tube_Do_mm  = tube_props(f.radius).Do * 1e3,
               utilisation = f.max_util,
               fos         = f.max_util > 1e-9 ? 1.0 / f.max_util : Inf,
               exceeded    = (f.max_util > 1.0)) for f in frames]
  end
  ```

- [ ] **Run the full test suite**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20
  ```
  Expected: all tests pass. If `test_dashboard_smoke` fails, check that the NamedTuple fields
  (`ring_id`, `radius`, `N_comp`, `P_crit`, `tube_Do_mm`, `utilisation`, `fos`, `exceeded`)
  are identical to what the old code produced.

- [ ] **Commit**
  ```bash
  git add src/structural_safety.jl
  git commit -m "refactor: ring_safety_frame delegates to ring_element_analysis"
  ```

---

## Task 11: Update `SimFrame` and `capture_frame`

**Files:**
- Modify: `src/sim_frame.jl`

- [ ] **Add `ring_beam_utils` field to `SimFrame`**

  In `src/sim_frame.jl`, find the `ring_utils` field (line 57):
  ```julia
  ring_utils        :: Vector{Float64}  # length = n_rings (intermediate only, excludes ground+hub)
  ```
  Replace with:
  ```julia
  ring_utils        :: Vector{Float64}           # worst-beam util per ring (HUD/peaks/warnings)
  ring_beam_utils   :: Vector{Vector{Float64}}   # [ring_idx][beam_idx] — for per-beam 3D colour
  ```

- [ ] **Update `capture_frame` structural block**

  In `capture_frame`, replace lines 176–179:
  ```julia
  sf_results  = ring_safety_frame(u, collect(alpha_vec), sys, p)
  ring_utils  = [r.utilisation for r in sf_results]
  max_util    = isempty(ring_utils) ? 0.0 : maximum(ring_utils)
  fos_ring    = max_util > 0.0 ? 1.0 / max_util : Inf
  ```
  with:
  ```julia
  rea_results     = ring_element_analysis(u, collect(alpha_vec), sys, p)
  ring_beam_utils = [[b.utilisation for b in ref.beams] for ref in rea_results]
  ring_utils      = [ref.max_util for ref in rea_results]
  max_util        = isempty(ring_utils) ? 0.0 : maximum(ring_utils)
  fos_ring        = max_util > 0.0 ? 1.0 / max_util : Inf
  ```

- [ ] **Add `ring_beam_utils` to the `SimFrame(...)` constructor call**

  In the `return SimFrame(...)` at the bottom of `capture_frame`, insert `ring_beam_utils`
  immediately after `ring_utils` in the argument list. The constructor positional order must
  match the struct field order.

- [ ] **Run the full test suite**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20
  ```
  Expected: all tests pass.

- [ ] **Commit**
  ```bash
  git add src/sim_frame.jl
  git commit -m "feat: add ring_beam_utils to SimFrame and update capture_frame to use ring_element_analysis"
  ```

---

## Task 12: Per-beam ring colour rendering in `visualization.jl`

**Files:**
- Modify: `src/visualization.jl`

- [ ] **Replace the single-colour ring polygon block with per-beam edges**

  In `src/visualization.jl`, locate the comment `# Intermediate ring polygons — hoop-compression colour`
  (around line 283) and replace the entire block (ending at the closing `end` around line 307) with:

  ```julia
  # Intermediate ring polygons — per-beam utilisation colour
  for k in 2:(Nr-1)
      gid_k = sys.ring_ids[k]
      nk    = sys.nodes[gid_k]::RingNode
      R_k   = nk.radius
      ri_k  = nk.ring_idx
      for j in 1:p.n_lines
          j_next = mod1(j + 1, p.n_lines)
          edge_obs = @lift begin
              u    = $u_obs
              ctr  = u[3*(gid_k-1)+1 : 3*gid_k]
              α    = u[6N + ri_k]
              pp1, pp2 = _perp_fn(u)
              pa = attachment_point(ctr, R_k, α, j,      p.n_lines, pp1, pp2)
              pb = attachment_point(ctr, R_k, α, j_next, p.n_lines, pp1, pp2)
              ([pa[1], pb[1]], [pa[2], pb[2]], [pa[3], pb[3]])
          end
          ec = @lift begin
              sfs  = $sim_frames_obs
              fi   = $frame_obs
              util = (fi <= length(sfs) &&
                      k-1 <= length(sfs[fi].ring_beam_utils) &&
                      j   <= length(sfs[fi].ring_beam_utils[k-1])) ?
                     sfs[fi].ring_beam_utils[k-1][j] : 0.0
              _ring_util_color(util)
          end
          lines!(ax3d, @lift($edge_obs[1]), @lift($edge_obs[2]), @lift($edge_obs[3]);
                 color=ec, linewidth=2.0, visible=vis_rings)
      end
  end
  ```

- [ ] **Run the test suite**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20
  ```
  Expected: all tests pass (the dashboard smoke test doesn't open a window — it only checks
  that `build_dashboard` returns without error).

- [ ] **Commit**
  ```bash
  git add src/visualization.jl
  git commit -m "feat: render each polygon beam edge in its own colour by per-beam utilisation"
  ```

---

## Task 13: Extend progress reporting to all scenarios

**Files:**
- Modify: `src/visualization.jl`

- [ ] **Split the furl progress block into physics-only and universal progress**

  In `src/visualization.jl`, inside `_rerun!`, locate the block (around line 807):
  ```julia
  if scenario == :furl && step % 500 == 0
      furl_delay    = t_total / 6
      furl_duration = 5 * t_total / 6
      x             = clamp((t - furl_delay) / furl_duration, 0.0, 1.0)
      release_frac  = x * x * x
      p_furl = _modified_params(p_run;
          backline_payout = 15.0 * release_frac)
      ode_p = isnothing(ld) ? (sys, p_furl, wf) : (sys, p_furl, wf, ld)

      # Progress update — keep the UI alive during long furl runs
      pct = round(Int, 100 * t / t_total)
      scenario_msg[] = "⟳ Furl … $pct% (payout=$(round(15.0*release_frac,digits=2))m, t=$(round(t,digits=1))s / $(round(t_total,digits=0))s)"
      yield()
  end
  ```

  Replace with two separate blocks:
  ```julia
  # furl-only: winch payout physics (unchanged logic)
  if scenario == :furl && step % 500 == 0
      furl_delay    = t_total / 6
      furl_duration = 5 * t_total / 6
      x             = clamp((t - furl_delay) / furl_duration, 0.0, 1.0)
      release_frac  = x * x * x
      p_furl = _modified_params(p_run;
          backline_payout = 15.0 * release_frac)
      ode_p = isnothing(ld) ? (sys, p_furl, wf) : (sys, p_furl, wf, ld)
  end

  # all scenarios: progress update + yield every 500 steps
  if step % 500 == 0
      pct = round(Int, 100 * t / t_total)
      scenario_msg[] = if scenario == :furl
          "⟳ Furl … $pct%  (payout=$(round(15.0*release_frac, digits=2)) m,  t=$(round(t,digits=1)) / $(round(t_total,digits=0)) s)"
      else
          "⟳ $label … $pct%  (t=$(round(t,digits=1)) / $(round(t_total,digits=0)) s)"
      end
      yield()
  end
  ```

- [ ] **Run the full test suite**
  ```bash
  julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20
  ```
  Expected: all tests pass.

- [ ] **Commit**
  ```bash
  git add src/visualization.jl
  git commit -m "feat: extend scenario progress indicator to all run types, not just furl"
  ```

---

## Self-Review Checklist

### Spec coverage

| Spec requirement | Task |
|-----------------|------|
| New `ring_element_analysis.jl` module | Tasks 2–8 |
| `BeamResult`, `RingElementFrame` types | Task 2 |
| `beam_stiffness_local` 12×12 matrix | Task 3 |
| `beam_transform` rotation | Task 4 |
| `assemble_ring_frame` with Tikhonov regularisation | Task 5 |
| `solve_ring_frame` | Task 5 |
| `extract_beam_forces` with N, M_ip, M_oop, T | Task 6 |
| `beam_column_utilisation` SRSS formula | Task 6 |
| `extract_vertex_forces` from ODE state | Task 7 |
| `analyse_ring` top-level | Task 8 |
| `ring_element_analysis` iterates intermediate rings | Task 8 |
| `G_CFRP`, `σ_CFRP_COMPR` constants | Task 1 |
| `tube_props` NamedTuple | Task 1 |
| `ring_safety_frame` delegation wrapper | Task 10 |
| `SimFrame.ring_beam_utils` field | Task 11 |
| `capture_frame` uses `ring_element_analysis` | Task 11 |
| Per-beam colour on 3D ring edges | Task 12 |
| Progress reporting for all scenarios | Task 13 |
| Test 1: symmetric load | Task 9 |
| Test 2: N_crit 4× ratio | Task 6 |
| Test 3: asymmetric N varies | Task 9 |
| Test 4: OOP load gives M_oop | Task 9 |
| Test 5: self-equilibration warning | Task 9 |
| Fixed-fixed K=0.5 in N_crit | Task 6 |
| Self-equilibration check before solve | Task 5 |

All spec requirements are covered. ✓
