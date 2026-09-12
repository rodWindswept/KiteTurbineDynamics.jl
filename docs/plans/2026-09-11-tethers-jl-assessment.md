# Tethers.jl 2.0.0 — technology assessment for KTD

**Status:** assessment only. No `src/` or `test/` change. Date: 2026-09-11.
**Method:** source read from a clone of tag `v2.0.0` at `.julia_depot/Tethers.jl`
(`Project.toml:3` = `2.0.0`; HEAD `7241aaf`). Every claim cites a file+line or a URL.
Inference is marked **[inf]**; everything else is read off the source.

---

## 1. What is in Tethers.jl 2.0.0

`Project.toml:8-17` declares 10 direct deps (`ADTypes`, `CondaPkg`, `LinearAlgebra`, `MAT`,
`ModelingToolkit`, `NonlinearSolve`, `Parameters`, `Pkg`, `StaticArrays`, `Symbolics`), with
`ModelingToolkit = "11"` and `julia = "1.11, 1.12, 1.13"`. `src/Tethers.jl` is thin:
`using CondaPkg, Pkg` (`:3`), then two unconditional includes — `TetherComponent.jl` (`:8`,
the MTK component) and `Tether_quasisteady.jl` (`:11`, the QSM). Licence MIT (`LICENSE:1-3`).

**The `QuasiSteady` submodule** (`src/Tether_quasisteady.jl:8`) is the v2.0 addition
(`CHANGELOG.md:10`). Its `using` line is `LinearAlgebra, StaticArrays, ADTypes,
NonlinearSolve, MAT, Parameters` (`:10`) — **no ModelingToolkit token appears anywhere in
`src/Tether_quasisteady.jl` or `src/qsm_conventions.jl`** (grep for `ModelingToolkit|System(`
returns nothing in either file). MTK is still *loaded* transitively, because
`src/Tethers.jl:8` includes `TetherComponent.jl`, whose `:27` is `using ModelingToolkit`.

**API** (`:12-13`): exported `StaticSettings`, `Tether`, `init!`, `step!`, `clear!`,
`elevation`, `azimuth`, `tension`, `n_nodes`, `get_initial_conditions`,
`get_analytic_catenary`; `simulate_tether`/`init_quasisteady`/`res!` are unexported but
callable (`docs/quasisteady.md:43-50`).

- `StaticSettings` (`:35-64`) — fixed physics/solver config: `segments`, `elevation`,
  `azimuth`, `l_tether`, `slack`, `rho`, `g_earth::MVector{3}` (`:49`), `cd_tether = 0.958`
  (`:51`), `d_tether` **in mm** (`:53`), `rho_tether` **kg/m³** (`:55`), `c_spring = E·A`
  (`:57`), `alg`/`abs_tol`/`rel_tol`. Default solver `TrustRegion` + `AutoForwardDiff`,
  `max_trust_radius = 2` (`:29-30`), with a linear-tension fallback (`:33`).
- `Tether` (`:126-140`) — the state. **No ODE state**: `state_vec::MVector{3}` holds
  `(β [rad], φ [rad], Tn [N])` at the ground station (`:129`), carried between `step!` calls
  as the warm start; `tether_pos`/`force_gnd`/`force_kite`/`p0` are outputs (`:136-139`) and
  the buffers are reused (`docs/quasisteady.md:37-41`). So "no dynamic state to initialize" is
  accurate for positions/velocities — but there **is** a persistent nonlinear-solve warm
  start, and `init!` is required before the first `step!` (`:111-112`).
- `init!(te)` (`:226-242`) derives `kite_pos` from `elevation`/`azimuth`/`l_tether`
  (`:231-234`), guesses from a fitted catenary (`init_quasisteady`, `:639-722`), then runs one
  `step!`. `step!(te, kite_pos, kite_vel; tether_length, wind_vel)` (`:267-290`) re-solves via
  a 3-unknown `NonlinearProblem` (`:333-334`), solving tension on a log scale (`:373`) with a
  linear fallback (`:381`).

**Boundary conditions.** The ground station is **pinned at the origin**
(`docs/quasisteady.md:8-14`: "origin is the anchor point of the tether — which is exactly
where the model puts the ground station, at `[0,0,0]`"), realised by
`dir = SVector(cosβcosφ, cosβsinφ, sinβ); pos = Ls*dir` (`:476`). The other end takes a
**prescribed position and velocity** (`:481`, `:498`). No orientation/twist DOF and no moment
boundary condition at either end. (The *dynamic* MTK component is a different model:
`FixedEnd`/`MovingEnd`/`FreeEnd`, `src/TetherComponent.jl:296-349`.)

**Forces accounted for**, enumerated from `tether_shape` (`:453-513`):

| effect | in QSM? | evidence |
|---|---|---|
| gravity | yes, but **only the −z magnitude**: `g = abs(settings.g_earth[3])` applied as `SVector(0,0,mj*g)` | `:455`, `:488`, `:507` |
| segment mass | yes, `mj = rho_tether*Ls*A` | `:462`, `:487` |
| aerodynamic drag | yes, **normal component only**: `v_n = v_app - dot(v_app,dir)*dir` | `:412-420`, `:460` |
| rotating-frame (centrifugal) load | yes, but only `acc = cross(ω, cross(ω,pos))` — **no Euler `ω̇×pos` term** | `:398-402`, `:473`, `:488` |
| elasticity | yes, linear: `l = (|FT|/EA + 1)*Ls` | `:492`, `:509` |
| internal damping | **no** | grep `added\|damping\|damper\|torsion\|reynolds` in this file returns nothing |
| added mass | **no** | same grep |
| torsion / twist stiffness | **no** | same grep; unknowns are only `(β, φ, Tn)` (`:129`) |
| tangential (skin-friction) drag | **no** | `:416` projects drag onto the normal plane |

**Standalone, and the validation reproduced.** Verified here
(`scratch/qsm_standalone_probe.jl`): including **only** `src/Tether_quasisteady.jl` (it
`include`s `qsm_conventions.jl` itself) into a bare module whose deps are `LinearAlgebra,
StaticArrays, ADTypes, NonlinearSolve, MAT, Parameters` loads and runs with
`ModelingToolkit loaded? false` and `Symbolics loaded? false`. In that environment the
author's MATLAB reference comparison reproduced at `‖p0 − p0_ref‖ = 2.8e-14 m` and
`‖T0 − T0_ref‖ = 1.6e-11 N`, and the public API (`StaticSettings`/`Tether`/`init!`/`step!`)
ran on the 8-segment default case. So the QSM is a genuinely standalone solver, and the
"validated against MATLAB reference data" claim is independently confirmed.

**Validation actually performed.** `test/test_qsm.jl:34-82` is one static configuration
(`test/data/input_basic_test.mat`): 4 output comparisons (`Fobj`, `T0`, `pj`, `p0`) at
`rtol=1e-9` (`:79-82`), plus 85 API/convention/defaults assertions (`:86-301`). The MATLAB
agreement is genuine (measured max rel. error ~1e-16–1e-15, `docs/quasisteady.md:536-543`).
The analytic 2-D catenary fixture is only plotted, never asserted
(`examples/quasisteady/run_catenary_matlab.jl:26`). **There is no asserted comparison against
dynamic-reference data and none for a rotating case**; `examples/quasisteady/flying_circular.jl`
prints forces but asserts nothing (`:105-115`).

**Timings** (author's, `docs/quasisteady.md:407-409`, `:447-453`; Ryzen 7950X, 16 segments):
`simulate_tether` 23.4 µs cold / 63 allocations, **4.0 µs warm**; a cold solver failure costs
1.6 ms (`:458-459`). The announcement's "~1.5x faster than the mass-spring-damper model" was
not independently reproduced here.

## 2. Does it model a rotating TRPT shaft?

**(a) Rotating frame / centrifugal load — partially, and not as a free parameter.**
`node_kinematics` (`:398-402`) gives each node `vel = v_parallel*p_unit + cross(ω,pos)` and
`acc = cross(ω, cross(ω,pos))`; the force balance adds `mj_total*acc` (`:488`). That *is* the
centrifugal term of rigid-body rotation. But `ω` is not an input: `ω = cross(kite_p/|kite_p|²,
kite_vel)` (`:473`) — the angular velocity of the **position vector about the origin**, i.e.
rotation about an axis through the pinned ground station. No `ω̇` term, so non-uniform
rotation is not modelled. `flying_circular.jl` exercises this path (cone half-angle 10°,
`gamma_dot = 0.05 rad/s`, `:21-27`), so a rotating configuration is at least *runnable* — but
the axis is pinned through the ground station.

**(b) Arbitrary 3-D end positions and twist — no.** Two hard constraints:
1. The ground attachment is the origin (`docs/quasisteady.md:8-14`; code `:476`). A TRPT chain
   runs *ring attachment → ring attachment*, at `r_gnd = 0.575 m` and `r_hub = 2.4 m` from the
   shaft axis (`docs/plans/2026-09-11-tether-drag-validation.md:73`). Neither end is on the
   rotation axis, so neither can be placed at the model's origin without redefining that axis
   **[inf, from `:473`+`:476`]**.
2. There is no twist DOF. Three unknowns and a 3-component residual `kite_p - p0` (`:512`)
   fully determine the shape from the two endpoint positions; nothing is left over to carry a
   twist angle between two rings, and torsion is absent from the force model (grep, §1). KTD
   instead transmits torque by *twisting* between rings: `compute_rope_forces!` accumulates
   per-segment `tau_a`/`tau_b` and clamps to a saturation torque
   (`src/rope_forces.jl:321-323`, `:341-343`, `:359-402`). The QSM has no analogue.

**(c) Tangential drag of a line moving at ω·r — the *transverse* part is there, the
*tangential* part is not.** The rigid-rotation velocity `cross(ω,pos)` (`:399`) feeds the drag
as `v_app = vel - wind_col(...)` (`:481`, `:497`), so a line sweeping at ω·r does see drag
from that sweep. But `segment_drag` removes the component along the segment (`:416`): **no
drag along the line's own axis** — the same choice KTD makes in `tether_drag_force!`
(`src/aerodynamics.jl:404-407`). `TETHER_DRAG_CD = 1.0` (`src/aerodynamics.jl:335`) is close
to the QSM default `0.958` (`:51`).

**Verdict:** a gravity-plus-normal-drag catenary solver on a rotating frame pinned at the
origin — a *near neighbour* of a TRPT chain (mass, normal drag, elasticity, centrifugal load)
but not a TRPT shaft model: no twist, no off-axis anchor, no torsional stiffness, no damping.

## 3. What is usable for KTD

**(a) Quasi-steady solver as a cross-check — real, but narrow.** The QSM is a second,
independently written implementation of exactly the cable statics KTD's rope kernel
implements: lumped mass, linear elastic tension, **normal-only** quadratic drag. KTD's
`get_subsegment_tension` is `max(0, EA·(L−L0)/L0 + c_damp·vel_proj)`
(`src/rope_forces.jl:58`) and its drag is `0.5ρ·Cd·d·L·|v_perp|·v_perp` on the perpendicular
component (`src/aerodynamics.jl:404-415`) — the same functional form as the QSM's
`drag_coeff·|v_n|·v_n` with `drag_coeff = -0.5ρ·Ls·d·Cd` (`:419`, `:460`). A static,
zero-twist, zero-rotation single line between two prescribed points runs through the QSM API
as-is (translate the lower attachment to the origin; gravity stays −z), so its force-balanced
node positions can be compared against KTD's. Worth doing because it tests precisely the
defect behind problem 1: KTD places interior rope nodes by **linear interpolation** —
`u_start[...] .= pa .+ frac .* (pb .- pa)`, `frac = m/ROPE_SUBSEGS`
(`src/initialization.jl:1203-1207`) — which is not a force balance. **Caveats:** no
tension-only clamp in the QSM, so it and KTD legitimately differ in the slack regime; and this
validates the *gravity/catenary* part of the kernel only, not the twist-torque path that sets
KTD's line tension. The same scope limit applies to re-checking the Tveide `TetherDragODESolver`
result (`docs/plans/2026-09-11-tether-drag-validation.md`) — that is about **rotating** drag on
a twisting taper, which the QSM cannot represent (§2).

**(b) Removing the stiff rope state via a per-step quasi-steady solve — wishful.** Three
independent problems, increasing in severity:
1. **Structural mismatch.** §2(b): the QSM cannot take a TRPT chain's two off-axis ring
   attachments with a twist. Adoption means re-deriving `tether_shape` (`:453-513`) for an
   arbitrary start point and start-tension vector, adding tangential drag and twist. The
   *formulation* is a useful template (3 unknowns = start tension vector, 3 residuals = end
   position), but the code is not callable for a TRPT chain.
2. **It would not remove the wobble, which is the actual blocker.** The 10 s / ±0.49 m
   oscillation is a **ring/hub** lateral mode, not a rope-node mode: ring inertias span
   0.263–195.2 kg·m² while a rope node is 2.97e-3 kg
   (`docs/plans/2026-09-11-settle-ode-coherence.md:50`, `:63-65`), and the hub itself swings
   0.49 m (`docs/plans/2026-09-10-shaft-windup-workstream.md:153-154`). A quasi-steady rope
   still transmits end forces, so the ring/hub mode survives **[inf]**. Worse, the QSM has
   **no** internal damping (§1) whereas KTD's rope segments carry `c_damp` (`src/types.jl:83`,
   used at `src/rope_forces.jl:58`), so rope-sourced damping would be lost — and the drag that
   is already far too weak to damp the wobble (ζ ≈ 0.001,
   `docs/plans/2026-09-10-shaft-windup-workstream.md:219-241`) is the *only* dissipation the
   QSM has.
3. **Cost.** The QSM's warm solve is ~4 µs per cable (`docs/quasisteady.md:450`). KTD has
   `n_lines*(n_ring−1)` rope chains, each `ROPE_SUBSEGS = 4` sub-segments (`src/types.jl:11`,
   `src/rope_forces.jl:104`) — ~30 solves per RHS step against one `multibody_ode!` at
   ≈0.1–0.2 ms (`docs/plans/2026-09-11-settle-ode-coherence.md:113`)
   **[inf: ≈30 × 4 µs ≈ 0.12 ms, cost-neutral at best, and the solves are not independent
   because both ends are coupled ring states]**.

**What is real here:** a quasi-steady rope has no interior node positions to initialize, so
problem 1's *rope-node* half (the 3.05 kN imbalance, `settle-ode-coherence.md:51`, `:157`)
would disappear by construction. The *ring* half — the pinned rigid frame that leaves the
first segment 6.6° twisted against a running 48.8°, 7× off (`settle-ode-coherence.md:19-26`)
— is untouched.

**(c) Lift line / back line / cyan line — real for one of the three.** The cyan line
(bearing → sky anchor) is *already* a real rope chain in `sys.sub_segs` (`src/types.jl:112`,
`src/initialization.jl:154-182`), so there is nothing to gain. The lift and back lines are
**not** ropes: they are fixed-direction spring-dampers in `ring_forces.jl` plus a first-order
lag on the kite position, `r_rel .+= (dt/KITE_TAU_S).*(r_eq .- r_rel)` with `KITE_TAU_S = 3.0`
(`src/simulation.jl:12-14`, `:48`; `src/types.jl:254`), and
`docs/plans/2026-05-08-multi-segment-lift-backline.md` proposes replacing them with real
catenary nodes. That is the one embedded use the QSM is genuinely shaped for: a hanging
tether, fixed end at the hub/bearing, prescribed moving end at the kite, gravity −z.
Caveats: the fixed end must sit **at the origin** (§2b), and `ω` is derived from the kite
position vector about that origin (`:473`), which is not the right reference once the hub
itself moves **[inf]**. Realistic use: an offline reference for catenary sag and force
direction, not an inner-loop replacement.

## 4. Adoption cost and licence

**Direct deps.** KTD's `Project.toml:7-31` lists 22 direct deps (plus `Test` as a test
extra); Tethers.jl's root `Project.toml:8-17` adds 10 — `ADTypes`, `CondaPkg`, `MAT`,
`ModelingToolkit`, `NonlinearSolve`, `Parameters`, `StaticArrays`, `Symbolics`, `Pkg`,
`LinearAlgebra` — of which KTD has only `LinearAlgebra`. `--project=.` would additionally
have to satisfy `ModelingToolkit` v11 and `Symbolics` v7.16 against KTD's existing manifest.

**Measured transitive closure.** A `Pkg.develop(path=".julia_depot/Tethers.jl")` +
`Pkg.resolve` of a fresh repo-local environment resolved **209 packages**
(`scratch/dep_probe2.jl`). The heavy additions are the symbolic stack (`ModelingToolkit`,
`ModelingToolkitBase`, `ModelingToolkitTearing`, `Symbolics`, `SymbolicUtils`,
`SymbolicLimits`, `DynamicPolynomials`, `RuntimeGeneratedFunctions`, `StateSelection`), the
solver stack (`NonlinearSolve` + 6 sibling packages, `LinearSolve`, `DiffEqBase`), and two
surprises for a tether package: **`CondaPkg`** dragging in `MicroMamba`, `micromamba_jll`,
`pixi_jll`, `p7zip_jll`, and `MAT` dragging in `HDF5`/`HDF5_jll` + `XML2_jll`.

**The cheap route avoids MTK — and all new deps.** `src/Tether_quasisteady.jl:10` imports only
`LinearAlgebra, StaticArrays, ADTypes, NonlinearSolve, MAT, Parameters`, and neither it nor
`qsm_conventions.jl` references MTK (§1). Both packages are MIT (`LICENSE:1-3` in each), so
the two files (~810 lines) can be vendored, dropping `MAT` (used only by the two fixture
loaders, `:588`, `:737`). KTD's own `Manifest.toml` **already contains** `NonlinearSolve`,
`StaticArrays`, `ADTypes`, `Parameters`, `SimpleNonlinearSolve` and `ForwardDiff` (1 entry
each; `MAT`, `ModelingToolkit`, `Symbolics`, `CondaPkg` absent), so the vendored core adds
**no new package**. *Not determined:* whether KTD's *pinned* `NonlinearSolve` satisfies the
QSM's `TrustRegion(autodiff=AutoForwardDiff())` call path — the standalone probe resolved
`NonlinearSolve` fresh. The QSM uses no version-gated API **[inf]**.

**MTK symbolic compilation vs the optimisation inner loop.** `mtkcompile`
(`src/TetherComponent.jl:371`) is a one-off build cost and is *not* on the QSM path, so the
per-evaluation question reduces to the QSM's own numbers: 4 µs warm, 23.4 µs cold, 1.6 ms on a
cold solver failure (`docs/quasisteady.md:450`, `:458-459`) against KTD's ≈0.1–0.2 ms per
`multibody_ode!` call (`docs/plans/2026-09-11-settle-ode-coherence.md:113`). Per-call it is
compatible with an inner loop; the exposure is the tail (a cold failure ≈ 10× a whole KTD RHS
evaluation) and the number of solves per step (§3b). But **`using Tethers` loads MTK
regardless** (`src/Tethers.jl:8` → `TetherComponent.jl:27`), so depending on the package
rather than vendoring pays MTK's load time and the 209-package graph above.

**Licence.** Tethers.jl MIT, "Copyright (c) 2023, 2024 Uwe Fechner, Andrea Bertozzi, Bart van
de Lint" (`LICENSE:1-3`). KTD MIT, "Copyright (c) 2025–2026 Rod Read / Windswept & Interesting
Ltd" (`LICENSE:1-3`). Compatible; vendoring or depending is unencumbered. Cite Williams
(2017) via `paper/paper.bib:54-58`.

## 5. Recommendation

> **Scope note (Rod, 2026-09-11).** Rod's framing, and the reason this package was
> raised at all: Tethers.jl belongs to the **single-line yo-yo AWES** family — one
> tether from a ground station to a kite, with a fixed rotation reference. It is
> **not** aimed at the many individual tethers of a TRPT system, and should not be
> read as a candidate model for the TRPT shaft. That is consistent with §2
> (independently derived), so the recommendation below stands as written.
>
> Concretely: the TRPT shaft is `n_lines` discrete tension members twisted between
> off-axis rings, carrying torque — a different modelling problem, governed by the
> references already in hand (`Tveide` for the rotating-line drag/shape, Dunker for
> line drag at the operating Reynolds number). Tethers.jl is a candidate only where
> KTD has a **genuine single hanging tether**: the lift line and the back lines,
> which are currently a fixed-direction spring-damper plus the `KITE_TAU_S` lag
> (`src/simulation.jl:12-14,48`) rather than a catenary. There, and only there, it
> is a reasonable offline reference for the already-planned multi-segment lift/
> back-line work. It is not a TRPT-shaft tool, and no TRPT result should be
> validated against it.

**Use only as an offline validation reference — do not adopt as a solver.** Tethers.jl 2.0.0
is a clean, genuinely validated (single static case, `rtol=1e-9`, `test/test_qsm.jl:79-82`)
implementation of the same cable statics KTD's rope kernel already implements, so the useful
move is a one-off static cross-check of `compute_rope_forces!` against
`Tethers.QuasiSteady` on a zero-twist, zero-rotation line — putting a second implementation
behind the node-placement defect (linear interpolation,
`src/initialization.jl:1203-1207`) that produces the 3.05 kN first-frame imbalance. It cannot
be adopted as KTD's line solver: it pins the ground end at the origin and fixes the rotation
axis through it (`docs/quasisteady.md:8-14`, `Tether_quasisteady.jl:473-476`), it has no
twist/torsion DOF or torsional stiffness (only `(β, φ, Tn)`), its drag is normal-only, and it
has no internal damping — so it can represent neither a TRPT chain between two off-axis rings
nor the shaft's torque transmission, and it would not touch the ring/hub wobble that is the
actual blocker. Its one real embedded-use case is the not-yet-built lift/back-line catenary
(`docs/plans/2026-05-08-multi-segment-lift-backline.md`), and even there only via vendoring
the two QSM files to avoid pulling ModelingToolkit v11 into the DE inner loop.

## 6. Evidence

**Tethers.jl** (clone of tag `v2.0.0`, HEAD `7241aaf`, `.julia_depot/Tethers.jl`):
`Project.toml:3,8-17` · `LICENSE:1-3` · `CHANGELOG.md:10` · `src/Tethers.jl:3,8,11` ·
`src/TetherComponent.jl:27,60-76,164-289,223,296-349,371` ·
`src/Tether_quasisteady.jl:8,10,12-13,29-33,35-64,49,51,53,55,57,101,111-112,126-140,129,136-139,226-242,231-234,267-290,321-357,333-334,373,381,398-402,412-420,419,453-513,455,460,462,473,476,481,487,488,492,497,498,500,507,509,510,512,588,639-722,715-716,737` ·
`src/qsm_conventions.jl` (whole) · `docs/quasisteady.md:8-14,37-41,43-50,407-409,447-453,458-459,536-543` ·
`docs/src/theory.md` · `examples/quasisteady/flying_circular.jl:21-27,105-115` ·
`examples/quasisteady/run_catenary_matlab.jl:26` · `examples/quasisteady/benchmark_qsm.jl` ·
`test/test_qsm.jl:34-82,79-82,86-301` · `paper/paper.bib:54-58`.

**Announcement:** https://discourse.julialang.org/t/ann-tethers-jl/118376/8 (11 Sep 2026) —
source of the "1.5x faster", "no dynamic state to initialize" and "validated against MATLAB
reference data" claims, each checked against the source above.
**Docs/repo:** https://ufechner7.github.io/Tethers.jl/dev/ · https://github.com/ufechner7/Tethers.jl

**KTD:** `Project.toml:7-31` · `LICENSE:1-3` · `src/types.jl:11-12,83,112,254` ·
`src/aerodynamics.jl:335,343,389-418,404-415` ·
`src/rope_forces.jl:58,104,204-403,300-301,321-323,341-343,359-402` ·
`src/initialization.jl:33,154-182,1203-1207` · `src/dynamics.jl:3` · `src/simulation.jl:12-14,48` ·
`src/KiteTurbineDynamics.jl:53,65`.
**Plans:** `docs/plans/2026-09-11-settle-ode-coherence.md:19-26,31-35,41-56,50,51,63-65,113,157,159` ·
`docs/plans/2026-09-11-tether-drag-validation.md:73` (§4.1, §5) ·
`docs/plans/2026-09-10-shaft-windup-workstream.md:153-154,219-241` ·
`docs/plans/2026-05-08-multi-segment-lift-backline.md` (header).
**Probes:** `scratch/dep_probe2.jl` — `Pkg.develop`/`resolve` of a repo-local Tethers.jl
environment, resolving 209 packages. `scratch/qsm_standalone_probe.jl` — QSM loaded without
ModelingToolkit/Symbolics, MATLAB reference reproduced at 2.8e-14 m / 1.6e-11 N, API smoke
tested. (`scratch/dep_probe.jl`, a parallel `develop`+`instantiate` attempt, was superseded
and killed.)
