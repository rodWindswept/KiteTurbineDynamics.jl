# PRD 0007 Gate 3 — Windowed Objective with k in the Genome

**Status:** SPEC (2026-07-20 — following Gate 1 GREEN)
**Parent:** [Pre-gates scoping](docs/plans/pre_gates_scoping.md)
**Predecessors:** Gate 1 (α-constant sensitivity) ✅ · Gate 2 (blade inertia + mass) ⬜
**Gate:** Windowed ODE scoring replaces static-equilibrium snapshot

---

## Problem Statement

The V10 DE campaign uses a static-equilibrium solver (`objective_v10.jl`) that
evaluates each design at a single operating point. TRPT kite turbines
limit-cycle: a design that oscillates between 10 and 30 kW scores the same as
one steady at 20 kW in a snapshot evaluator — but has half the real energy
output. The convergence methodology developed during the kickstart diagnostic
(window-mean + window-min over a dynamic simulation) must be promoted into the
objective itself.

Separately, k_mppt is currently derived from a fixed `p.k_mppt` scaled by λ²
inside the evaluator. This couples control parameter selection to the fixed
parameter set and requires a separate pre-pass k-hunt per candidate (or
accepts biased selection). Making k_mppt a DE decision variable eliminates the
scan, lets the population simultaneously optimise geometry and control, and
removes selection bias.

## Design Language

This spec inherits the self-validating instrumentation pattern that
Gate 1 established:

- **Phantom gate:** prove the artifact is reproducible before claiming
  it's a model prediction.
- **Positive control:** prove the perturbation reaches the physics before
  interpreting sensitivity results.
- **k-bracket:** let the data pick k, not a prior — when the prior was
  wrong three times, the instrument earns its keep.

Every acceptance test in this PRD must prove the measurement apparatus
works before it proves the physics does. A test that doesn't validate
its own signal path is a hope, not a gate.

## Solution

1. **Windowed ODE evaluator** (`objective_v11.jl`, parallel to `v10`).
   Each candidate is built, settled, kicked, spun up, and evaluated over a
   dynamic MPPT window (60–90 s, 1 Hz snapshots). Scoring uses window-mean
   P_kw and window-min FoS.

2. **k_mppt in the DE genome** as `log₁₀(k)`. Bounds log₁₀(k) ∈ [−2, 3]
   cover k ∈ [0.01, 1000] — from triangle-k4 to well above the stiffest
   12-gon regime. The λ² scaling inside the evaluator is removed; the DE
   discovers the optimal k for each design.

3. **FoS-constrained fitness.** `fitness = P_score` with a penalty or
   hard constraint when `FoS_score < FOS_DESIGN`. The penalty shape is
   configurable (multiplicative penalty vs. infeasibility kill) — the spec
   leans multiplicative so the DE can see gradient toward feasibility, but
   implementation defers to Rod's call on the first draft.

## User Stories

1. As a DE campaign operator, I want each candidate evaluated by its
   window-mean power (not a single snapshot), so that designs which
   limit-cycle at low average power are correctly penalised relative to
   stable designs.

2. As a DE campaign operator, I want k_mppt optimised alongside geometry
   in a single pass, so that I don't need a separate per-candidate k-hunt
   and the population discovers control-geometry co-adaptation.

3. As a design analyst, I want the window-min FoS recorded alongside
   window-mean P, so that structural feasibility is scored from the same
   dynamic trajectory that produces the power estimate.

4. As a model maintainer, I want the legacy snapshot mode preserved (single
   equilibrium point) for backwards comparison, so that I can quantify the
   impact of the windowing change on winner ranking.

5. As a model maintainer, I want twin DE runs with identical params but
   different RNG seeds to converge on the same Pareto-front neighbourhood,
   so that the windowed objective eliminates the aliasing noise that
   snapshot evaluators introduce.

6. As a gate reviewer, I want the evaluator to produce a non-vacuous delta
   from the snapshot evaluator (≥10% P difference on a known-oscillating
   design), so that I know the window is measuring something the snapshot
   missed.

7. As a gate reviewer, I want the legacy 12-gon winner (aliased 326 kW /
   FoS 2.15) re-evaluated under the windowed objective and its fitness to
   drop materially, confirming the snapshot was flattering it.

## Implementation Decisions

### Decision 1: New objective module, not a patch

`src/objective_v11.jl` — a new file that imports `src/objective_v10.jl`'s
design vector decode (`design_from_vector_v10`, `decode_rotor_mask`) but
replaces the equilibrium solver with an ODE window. V10 is left untouched
for backwards comparison. V11 is the re-campaign evaluator.

The design vector is the V10 genome (14 DoF).  x15 (log₁₀ k_mppt) was
introduced as a 15th gene but removed 2026-08-07 (S1 audit): the warm-start
bracket overwrote it before every evaluation, so it had zero fitness effect
and only railed at a bound.  k is now owned solely by
`warmstart_with_k_bracket`'s λ²-scaled prior + 3-point bracket.

| Index | Name | Type | Bounds |
|-------|------|------|--------|
| 1–14 | V10 genome | — | unchanged |

`search_bounds_v11` is now identical to `search_bounds_v10`.

### Decision 2: Window protocol

Per candidate:

1. Build system from genome (geometry + λ from x[1:14], k_mppt from
   the bracket's k_try, appended as the objective's internal x[15]).
2. Set `sys.k_mppt_ref[] = k_mppt` directly — the bracket owns k (λ²-scaled
   prior × {0.5, 1, 2}, clamped to [0.01, K_MPPT_MAX]).
3. Settle: `settle_to_operational_state` with the standard wind profile
   (power-law shear, 11 m/s at hub height).
4. Kick + spin-up: apply the kickstart protocol from the convergence
   diagnostic (brief PTO torque reversal to spin the rotor).
5. MPPT window: simulate for `WINDOW_S + DISCARD_S` seconds (e.g. 60 s
   window + 30 s discard). Sample `capture_extended` at 1 Hz during
   the window.
6. Score:
   - `P_score = mean(P_kw_samples)` or 0 if no samples
   - `FoS_score = min(FoS_samples)` or Inf if no samples
   - `fitness = -P_score * FoS_penalty` (negative because DE minimises)

### Decision 3: FoS penalty shape

If `FoS_score < FOS_DESIGN` (default 1.5): `FoS_penalty = FOS_DESIGN /
FoS_score`. This is multiplicative — a design at FoS 0.75 pays 2× penalty,
a design at FoS 0.38 pays 4×. The DE sees gradient back to feasibility
rather than a cliff.

Rationale: the soft penalty gives the DE a continuous surface to climb
toward feasible designs, unlike a hard kill (return +Inf) which creates
flat fitness plateaus the DE cannot navigate. The specific multiplier
shape can be tuned after the first campaign.

### Decision 4: Spoke integration

The windowed evaluator MUST include spokes if `SPOKES_ENABLED` is set.
Unlike the static solver (which has a parity guard rejecting spokes),
the ODE handles spoke drag and FoS natively via `compute_ring_forces!`.

### Decision 5: ODE parameters (non-DE)

These are fixed across the campaign, not in the genome:

| Parameter | Value | Source |
|-----------|-------|--------|
| Wind speed | 11 m/s (uniform or power-law) | Rated wind |
| Elevation | 30° | System params |
| Window duration | 60 s | Gate 1 convergence diagnostic |
| Discard (transient) | 30 s | Gate 1 convergence diagnostic |
| Sample rate | 1 Hz | Gate 1 convergence diagnostic |
| FoS_design | 1.5 | Gate 2 |
| Kickstart protocol | 2 s PTO reversal @ 60 N·m | Kickstart diagnostic |

### Decision 6: Safety limits

- k_mppt floor at 10^−2 (≈0.01) — designs with k→0 are unstartable and
  waste DE budget
- ω ceiling at the swivel RPM limit (TBD — Rod to supply) or 500 rpm
  (provisional). Designs that hit the ceiling during the window are
  penalised (power clipped, fitness degraded).
- Tether FoS: scored from the window-min tether tension, not a static
  equilibrium point.

## Testing Decisions

### Test file: `test/test_objective_v11.jl`

**What makes a good test:** External behaviour only. Test that the windowed
evaluator produces a different score than the snapshot evaluator on a known
oscillating design. Test that twin identical evaluations produce identical
scores (determinism). Test that k_mppt at the genome bounds doesn't crash.

**Prior art:** `test/test_objective_v10.jl` (if it exists — check),
`test/phantom_gate_test.jl` (bit-reproduction pattern), Gate 1 sensitivity
script (window-mean scoring).

### Acceptance tests

1. **Non-vacuous delta (acceptance test 1):** On the triangle3 candidate
   (known to oscillate at low k), `|P_window − P_snapshot| / P_window ≥
   0.10`. If the delta is <10%, the window isn't measuring anything the
   snapshot didn't already capture — the method is vacuous.

2. **Legacy winner deflation (acceptance test 2):** Re-evaluate the V10
   12-gon winner (aliased 326 kW / FoS 2.15) under the windowed objective.
   Its window-mean P must drop materially (≥20% below the snapshot P).
   The snapshot was aliasing a spike; the window must reveal the true
   average.

3. **Determinism (acceptance test 3):** Two calls to the windowed evaluator
   with the same genome produce identical fitness within floating-point
   tolerance. The ODE + window-mean path must be deterministic (fixed seed
   or no RNG in the evaluation path).

4. **k_mppt bounds don't crash (acceptance test 4):** Evaluate a design at
   k=0.01 (log₁₀(k)=−2) and k=1000 (log₁₀(k)=3). Both must return a finite
   fitness (not NaN/Inf from ODE instability). Note: they may return very
   poor fitness — that's expected and is the DE's job to avoid.

5. **Twin RNG convergence (acceptance test 5):** Run a mini-DE (2 islands,
   5 iterations, 3 population) with two different RNG seeds. Both runs must
   converge on the same best-fitness neighbourhood (±5%). This gates the
   claim that windowing removes snapshot-aliasing randomness from the DE
   search.

6. **Backwards-compat snapshot (acceptance test 6):** The snapshot mode
   (`window_s=0` or a separate `objective_v11_snapshot(x)`) produces the
   same fitness as `objective_v10` on a known-feasible design. The decode
   path must be bit-compatible.

### Test fixtures

- **Triangle3 candidate:** `build_phantom_triangle(blade_scale=0.85)`
  evaluated at k=4 — known oscillator, low FoS, should show large
  window-vs-snapshot delta.
- **12-gon V10 winner:** Best from `v10_campaign_50kw_tight/island_bests.csv`
  — high snapshot P, check window deflation.
- **Feasible mid-range:** A hand-picked design with moderate P and FoS > 1.5
  — sanity check that feasible designs score sensibly.

## Out of Scope

- **k-refinement post-campaign.** The re-campaign finds a best k per
  design during evolution. A focused k-sweep around the winner's k
  (refinement only) is post-campaign analysis — not the evaluator.
- **Multi-wind scoring.** The evaluator scores at a single rated wind
  (11 m/s). Multi-wind power curves are post-campaign.
- **Tulloch/AeroDyn α-constant calibration.** Gate 1 is GREEN — the model
  is stable enough for re-campaign without further constant tuning.
- **Gate 2 (inertia + mass fix).** Must land before Gate 3 — the windowed
  evaluator needs correct blade inertia in the ODE to score mass correctly.
- **Spoke SWL sourcing.** The 19.8 kN provisional SWL is Gate 2 scope.
  Gate 3 uses whatever `SpokeParams` Gate 2 establishes.
- **Parallel DE (distributed islands).** Single-machine DE is sufficient
  for Gate 3. Distributed islands are a scaling concern for the full
  re-campaign, not the gate itself.

## Post-Campaign Gate: Winner-Front α-Retest

Gate 1 passed GREEN using a frozen-ω post-hoc measurement. That screen
had a known blind spot: the spinning rotors sit saturated at CL_max in
the operating range, making slope/TSR perturbations invisible. The check
was cheap but incomplete.

**After the re-campaign produces a winner front (3–5 best designs):**

1. Re-evaluate every winner-front design under the full 7-perturbation
   α-constant grid (TSR_design ±20%, slope ±30–50%, CL_max ±17%) **in
   full dynamic sim** — settle + kick + window, same ODE protocol as
   the campaign evaluator.
2. If any first-rank flip or pairwise ordering reversal occurs among the
   winner-front designs under α perturbation: **RED — re-campaign winner
   is not reliable, constants need calibration** (Tulloch/AeroDyn
   critical path).
3. If ranking holds: **GREEN — winner is stable under α-model uncertainty
   at the dynamic operating point.**

~35 evaluations (5 designs × 7 perturbations), a few hours of compute.
Converts a hope ("the frozen-ω screen was good enough") into a scheduled
check with the same instrument that picked the winner.

## Known Model Gaps

These do not block the re-campaign but constrain what its results mean.

### CL_max saturation

Gate 1 v14 found that spinning rotors at operating φ sit pinned at
CL_max — slope and TSR_design perturbations were invisible because the
CL curve is saturated. This makes CL_max the only α constant that
matters for operating-point power, and CL_max = 1.2 is the least
anchored constant in the α model. The re-campaign's power rankings
are effectively a CL_max ranking until calibrated.

### Optimistic drag at CL_max

The expansion CL/CD model uses `CD = CD0 + k_induced × CL²`. At
CL_max (≈1.2), this is a pre-stall polar with no post-stall drag
rise. Real airfoils at CL_max have CD 2–5× higher than the
quadratic polar predicts. The re-campaign's power numbers are
optimistic at the operating point — designs that sit near CL_max
(the current operating regime) overstate net power. This gap
narrows when calibrated polars replace the quadratic model, but
the re-campaign's *ranking* may still be valid if all designs
share the same optimistic drag offset.

## Further Notes

### Sequencing reminder

```
GATE 2 (inertia + mass fix) → GATE 3 (this spec) → V10 RE-CAMPAIGN
```

Gate 3 cannot run on a model with zero blade inertia — the windowed ODE
would see designs that put mass in blades paying zero dynamic cost,
defeating the purpose of mass-inclusive scoring. Gate 2 must land first.

### k_mppt and λ² coupling

In the current V10 evaluator, k_mppt_eff = p.k_mppt × λ_eff² ×
k_mppt_safety. With k in the genome, the λ² scaling is removed — the DE
discovers the relationship organically. If designs with small blades need
larger k to start, the DE will find that k. If designs with large blades
need smaller k to avoid overspeed, the DE will find that too.

The one constraint: the DE must be able to explore both low-k and high-k
regions. The log₁₀ encoding ensures uniform exploration across orders of
magnitude. Linear k encoding would bias search toward high k (where
gradients are smaller relative to the parameter) — log encoding is the
standard solution for parameters spanning multiple orders.

### Compute budget

Per-candidate ODE simulation: ~10–30 s (90 s sim at DT ~0.01, variable
with stiffness). DE population × iterations: ~500–2000 evaluations per
island. Total: ~days, comparable to the current V10 campaign budget.
The k variable adds zero evaluations — it's part of the same genome,
evaluated in the same ODE run.

### Relationship to Gate 1 sensitivity

Gate 1 tested α-constant sensitivity at a frozen operating point (cheap
screen). The windowed ODE evaluator re-tests sensitivity organically
during the campaign — every design is evaluated at a dynamically-settled
operating point that reflects its actual α-constant response. The Gate 1
GREEN verdict means we proceed without recalibrating constants; the Gate 3
evaluator inherits that decision.

### Strathclyde collaboration ask

Gate 1 identified CL_max as the only α constant that materially affects
operating-point power rankings, and the current quadratic-polar CD model
is optimistic at CL_max. The collaboration request to Strathclyde (Hong
Yue, Amjad Zulfazli) becomes concrete: **stalled-regime polars from your
AeroDyn tooling** — CL/CD curves for representative expansion-blade
airfoils at Re 10⁵–10⁶ through the stall break and into the post-stall
regime. A specific data product, not a vague "collaborate on aero." The
re-campaign's post-campaign α-retest gates whether this is a dependency
(RED → critical path) or a refinement (GREEN → nice-to-have).
