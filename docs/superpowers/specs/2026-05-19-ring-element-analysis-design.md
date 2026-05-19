# Ring Per-Element Structural Analysis — Design Spec

**Date:** 2026-05-19
**Branch:** claude/stupefied-gauss-39fd0b
**Status:** Approved — ready for implementation planning

---

## Problem Statement

The current ring buckling analysis in `structural_safety.jl` (`ring_safety_frame()`) treats each
intermediate ring as a uniform-load polygon: it sums all inward radial forces, divides by `n`
vertices to get a single `F_v`, and computes one `N_comp` applied identically to every beam.

This is wrong in two ways:

1. **Load distribution:** Tether tensions vary around the ring (gravity, differential twist,
   aerodynamic asymmetry) — beams on the windward side carry more compression than leeward beams.
2. **Boundary conditions:** The current model uses pin-pin Euler buckling (`K = 1.0`). The physical
   knuckle joints are rigid casings that fully fix beam ends against relative rotation — this is
   fixed-fixed (`K = 0.5`), giving `P_crit` 4× higher than currently computed.

The goal is a full per-beam-element structural analysis with combined axial + bending utilisation,
per-beam colour rendering on the 3D dashboard ring geometry, and progress reporting for all
scenario types.

---

## Scope

- **Polygon orders supported:** n = 5 (pentagon) and n = 8 (octagon)
- **Loading:** Full 3D — in-plane radial, in-plane tangential, and out-of-plane (shaft-direction)
  force components at each knuckle vertex
- **Analysis type:** Linear elastic 3D space frame FEA, one solve per intermediate ring per frame
- **Failure check:** Combined axial + bending interaction (SRSS bending combination)
- **Boundary conditions:** Fixed-fixed at both beam ends (`K = 0.5`, `L_eff = L/2`)
- **Dashboard:** Per-beam colour on 3D ring edges; HUD scalars unchanged
- **Progress reporting:** Extend existing furl progress indicator to all scenarios

---

## Architecture

New module `src/ring_element_analysis.jl` slots between the ODE state and the structural safety
outputs. The ODE integrator and `rope_forces.jl` are untouched.

```
ODE state u + sys + p
        │
        ▼
extract_vertex_forces()           ← ring_element_analysis.jl
  Per-vertex 3D force vector at each polygon knuckle (3 × n_lines matrix)
        │
        ▼
ring_local_basis() + tube_props()
  Project forces to ring-local frame; compute A, I, J, G for CFRP tube
        │
        ▼
assemble_ring_frame()
  Build 6n×6n global stiffness matrix (12×12 per 3D beam element)
  Tikhonov regularisation (ε = 1e-6 × tr(K) / 6n) — no hard-pinned DOFs
        │
        ▼
solve_ring_frame()
  Solve K_reg·d = F; extract N, M_ip, M_oop, T per beam
        │
        ▼
beam_column_utilisation()
  util = N/N_crit + √(M_ip² + M_oop²) / M_el   (SRSS bending, fixed-fixed)
        │
        ▼
RingElementFrame (per ring: Vector{BeamResult})
  → stored in SimFrame.ring_beam_utils :: Vector{Vector{Float64}}
        │
        ▼
visualization.jl
  n_lines separate lines! per ring, each with own colour Observable
```

`structural_safety.jl` becomes a thin caller: `ring_safety_frame()` delegates to
`ring_element_analysis()` and wraps results in the existing NamedTuple format so all existing
consumers are unchanged.

---

## New Module: `src/ring_element_analysis.jl`

### New constants (added to `structural_safety.jl`)

```julia
const G_CFRP       = 5e9    # Pa — conservative shear modulus (woven CFRP layup)
const σ_CFRP_COMPR = 600e6  # Pa — compressive strength (conservative unidirectional)
```

### Types

```julia
struct BeamResult
    N           :: Float64  # axial compression (+ve = compressive, N)
    M_ip        :: Float64  # max in-plane bending moment at either end (N·m)
    M_oop       :: Float64  # max out-of-plane bending moment at either end (N·m)
    T_tor       :: Float64  # torsion (N·m) — captured but excluded from interaction formula
    N_crit      :: Float64  # fixed-fixed critical buckling load (N)
    M_el        :: Float64  # elastic bending moment capacity (N·m)
    utilisation :: Float64  # combined interaction ratio (1.0 = limit state)
    fos         :: Float64  # 1 / utilisation
    exceeded    :: Bool
end

struct RingElementFrame
    ring_id  :: Int
    radius   :: Float64
    beams    :: Vector{BeamResult}  # length = n_lines
    max_util :: Float64             # worst-beam utilisation scalar (for HUD)
end
```

### Functions

All functions are pure (no side effects) and independently unit-testable.

| Function | Inputs | Outputs | Purpose |
|----------|--------|---------|---------|
| `extract_vertex_forces` | `u, sys, ring_gid, alpha, p, perp1, perp2` | `Matrix{Float64}` 3×n | Sum all tether sub-segment tension vectors at each vertex j |
| `ring_local_basis` | `ring_gid, u, sys, perp1, perp2` | `(origin, e_r, e_t, e_ax)` per vertex | Ring-local radial/tangential/axial triad at each vertex |
| `tube_props` | `R, Do_scale, t_over_D, t_min` | NamedTuple `(Do, t, A, I_bend, J, L_beam)` | CFRP cross-section properties + beam chord length — NamedTuple for field access |
| `beam_stiffness_local` | `E, G, A, I_bend, J, L` | `12×12 Matrix` | Standard 3D Euler–Bernoulli beam element in local coords |
| `beam_transform` | `pa, pb, ring_normal` | `12×12 Matrix` | Rotation from local beam frame to ring-local 3D frame |
| `assemble_ring_frame` | `vertices_3d, F_vertices, beam_props` | `(K_6n×6n, F_6n, K_locals, T_mats)` | Assemble global stiffness + load vector with Tikhonov regularisation; also returns per-element local K and transform matrices for force recovery |
| `solve_ring_frame` | `K_6n×6n, F_6n` | `d_6n` | Solve `(K + εI) \ F`; returns nodal displacement vector |
| `extract_beam_forces` | `d_global, K_locals, T_mats, beam_props, n` | `Vector{BeamResult}` | Recover N, M_ip, M_oop, T at each beam from nodal displacements |
| `beam_column_utilisation` | `N, M_ip, M_oop, N_crit, M_el` | `Float64` | `N/N_crit + √(M_ip²+M_oop²)/M_el` |
| `analyse_ring` | `u, sys, ring_gid, alpha, p, perp1, perp2` | `RingElementFrame` | Top-level per-ring analysis: extract → assemble → solve → utilisation |
| `ring_element_analysis` | `u, alpha, sys, p` | `Vector{RingElementFrame}` | Iterate all intermediate rings; replacement for `ring_safety_frame()` |

### Key physics

**Fixed-fixed effective length:**
`L_eff = 0.5 × L_beam` → `N_crit = π²EI / L_eff² = 4π²EI / L²`

**SRSS bending combination:**
`M_combined = √(M_ip² + M_oop²)` — safe combination without sign assumptions

**Elastic bending capacity:**
`M_el = σ_CFRP_COMPR × I_bend / (Do/2)` — extreme fibre compressive failure

**Torsion:** Captured in `T_tor` but excluded from the interaction formula. Torsion arises only
from OOP load asymmetry and is secondary for a closed ring under predominantly radial loading.

**Constraint strategy — Tikhonov regularisation:**
No DOF is hard-pinned. Instead: `K_reg = K + ε·I` where `ε = 1e-6 × tr(K) / (6n)`.
This makes the system non-singular without introducing fictitious support reactions. Hard-pinning
any vertex would bias N and M in adjacent beams when loads are not perfectly self-equilibrating
(ODE inertial contributions cause small residual imbalances).

**Self-equilibration check (before solve):**
```julia
F_residual = norm(sum(reshape(F, 6, n), dims=2))
F_scale    = maximum(abs, F)
F_residual / F_scale > 1e-2 &&
    @warn "Ring $k: load imbalance $(round(F_residual/F_scale*100, digits=1))% — inertial forces may be significant"
```
If this warning fires frequently it is a signal to add D'Alembert correction (subtract
`m_vertex × a_vertex` at each knuckle). This is deferred as a follow-on improvement.

---

## Changes to Existing Files

### `src/structural_safety.jl`

- Add `G_CFRP` and `σ_CFRP_COMPR` constants alongside the existing CFRP block
- Replace `tube_I(Do, t)` with `tube_props(R, Do_scale, t_over_D, t_min)` returning full
  cross-section `(Do, t, Di, A, I_bend, J, L_beam)`; `tube_I()` becomes a one-line wrapper
  calling `tube_props()` so no existing code breaks
- `ring_safety_frame()` becomes a delegation wrapper:

```julia
function ring_safety_frame(u, alpha, sys, p)
    frames = ring_element_analysis(u, alpha, sys, p)
    return [(ring_id     = f.ring_id,
             radius      = f.radius,
             N_comp      = maximum(b.N    for b in f.beams),
             P_crit      = maximum(b.N_crit for b in f.beams),
             tube_Do_mm  = tube_props(f.radius, DO_SCALE, T_OVER_D, T_MIN_WALL).Do * 1e3,
             utilisation = f.max_util,
             fos         = 1.0 / max(f.max_util, 1e-9),
             exceeded    = (f.max_util > 1.0)) for f in frames]
end
```

All existing consumers of `ring_safety_frame()` (NamedTuple field access) continue working
without modification.

### `src/sim_frame.jl` — `SimFrame` struct

```julia
# Replace:
ring_utils        :: Vector{Float64}

# With:
ring_utils        :: Vector{Float64}        # worst beam per ring — HUD/peaks/warnings unchanged
ring_beam_utils   :: Vector{Vector{Float64}} # [ring_idx][beam_idx] — per-beam, for 3D renderer
```

`capture_peaks()`, `fos_ring`, and `buckling_risk` all read `ring_utils` (worst-beam scalar)
and require no changes.

### `src/sim_frame.jl` — `capture_frame()` structural block

```julia
# Replace lines 175–179:
rea_results     = ring_element_analysis(u, collect(alpha_vec), sys, p)
ring_beam_utils = [[b.utilisation for b in ref.beams] for ref in rea_results]
ring_utils      = [ref.max_util for ref in rea_results]
max_util        = isempty(ring_utils) ? 0.0 : maximum(ring_utils)
fos_ring        = max_util > 0.0 ? 1.0 / max_util : Inf
```

Add `ring_beam_utils` as an argument to the `SimFrame(...)` constructor call immediately after
`ring_utils`. Everything else in `capture_frame()` is untouched.

---

## Dashboard Changes

### 3D ring rendering — `src/visualization.jl` lines 284–307

Replace the current single `lines!` per ring (n+1 points, 1 colour) with `n_lines` separate
two-point `lines!` calls (one per beam edge), each with its own colour `Observable`:

```julia
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

Observable count: `n_intermediate_rings × n_lines × 2` (worst case 14 × 8 × 2 = 224, vs 14
previously). Each is cheap — two `attachment_point` evaluations per update. Well within GLMakie's
budget.

### HUD — no changes

`ring_max_util` and `fos_ring` remain unchanged scalars. Per-beam breakdown is visible spatially
on the 3D ring; no additional panel needed. The `_rerun!` / `sim_frames_obs` update path already
propagates `ring_beam_utils` through the Observable chain.

---

## Progress Reporting for All Scenarios

### Current state

The progress update and `yield()` call are inside the `scenario == :furl && step % 500 == 0`
block. All other scenarios run silently with the UI frozen.

### Fix — split furl physics from progress reporting

```julia
# furl-only: update physics params (unchanged logic)
if scenario == :furl && step % 500 == 0
    furl_delay    = t_total / 6
    furl_duration = 5 * t_total / 6
    x             = clamp((t - furl_delay) / furl_duration, 0.0, 1.0)
    release_frac  = x^3
    p_furl = _modified_params(p_run; backline_payout = 15.0 * release_frac)
    ode_p  = isnothing(ld) ? (sys, p_furl, wf) : (sys, p_furl, wf, ld)
end

# all scenarios: progress + yield every 500 steps
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

No new widgets, no pre-run time estimate. All scenarios show live percentage and elapsed/total
time; furl additionally shows payout distance.

---

## Testing Strategy

New file: `test/test_ring_element_analysis.jl`

All tests construct inputs by hand — no ODE state required.

| Test | Setup | Assert |
|------|-------|--------|
| **1 — Symmetric load → uniform axial, zero bending** | Equal inward radial `F` at all n vertices | All beams: same `N` matching `F/(2·tan(π/n))`; `M_ip = M_oop = T_tor ≈ 0` |
| **2 — Fixed-fixed N_crit is 4× pin-pin** | Same beam geometry, compare K=0.5 vs K=1.0 | `N_crit_fixed / N_crit_pinned ≈ 4.0` (exact) |
| **3 — Asymmetric load → method-of-sections check** | Pentagon: `2F` at vertex 1, `F` elsewhere | Per-beam `N` matches hand-computed method-of-sections result |
| **4 — OOP load → nonzero M_oop, zero M_ip** | Pure shaft-direction force at one vertex | `M_ip ≈ 0`; `M_oop > 0` in adjacent beams |
| **5 — Self-equilibration warning** | Deliberately unbalanced load (ΣF ≠ 0) | `@test_warn` fires; balanced loads are silent |

Test 1 also serves as a regression guard: the new per-element analysis must reproduce the
existing whole-polygon result for the symmetric case, confirming no change to the rated-condition
FoS figures already validated in the dashboard.

---

## Out of Scope (Follow-on)

- D'Alembert inertial correction (subtract `m_vertex × a_vertex` at each knuckle before solve)
- Local wall buckling check (separate thin-wall stability criterion)
- Torsion included in interaction formula
- Per-beam FoS readout in HUD (currently worst-beam scalar is sufficient)
