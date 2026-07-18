# PROPOSAL: Per-annulus axial-induction fixed point for expansion rotors

**Status:** AMENDED per Rod 2026-07-18 (4 amendments folded in: solver-
convergence assertion in test 1; §2a α model resolving fixed-point
existence — BLOCKING amendment, option (a) selected; test 4 bound relaxed to
Σ per-annulus Betz for v1; test 3 verified non-vacuous + FR4 assertion
restored). Ready for implementation on Rod's go.
**Authored:** 2026-07-18 (Hermes desktop, from Rod's source inspection + sketch).
**Prereqs read:** `wake_overlap_audit.jl` results (DECISIONS.md 2026-07-18),
Rod's confirmation: no induction at `expansion_rotor.jl:167`, fixed CL at
`:176`, ω²-growing driving torque opposed only by profile drag.

## 1. Problem (confirmed)

The expansion-rotor blade-element model computes forces from the free-stream
relative velocity with **no induced-velocity feedback**: extraction does not
deplete the inflow that produces it. Torque grows ~ω² unopposed by momentum,
so per-rotor power is unbounded by any physical ceiling.

Evidence chain:
- `wake_overlap_audit.jl` (2026-07-18): 12-gon stations share **zero**
  projected streamtube, yet report 326–540 kW converged against a 62 kW
  union-Betz ceiling at 11 m/s → the 5–9× violation is **per-rotor**, not
  wake-coupling. Triangle3 exceeds its corrected 97 kW ceiling by 1.3–2×.
- Wake overlap between stations is second-order (32% adjacent near-field,
  53% far-field on the triangle; 0% on the 12-gon) — a v2 refinement, not
  the first-order fix.

## 2. Proposed fix — per-annulus induction fixed point

For each expansion rotor, treat its shaft-axis swept annulus
(r ∈ [r_ring + blade_hub_offset, r_ring + blade_tip_offset], area A_ann,
axis-normal inflow v_n) as an actuator annulus:

1. Induced inflow: `v_eff = v_n · (1 − a)`.
2. Blade-element thrust `T_BE(a)`: current force integration, but with
   `v_eff` in the relative-velocity triangle (axial component only; the
   tangential/rotational component keeps ω·r as now).
3. Momentum thrust: `T_M(a) = ½ ρ A_ann v_n² · 4a(1−a)`, with the standard
   Glauert empirical branch for a > 0.4; hard cap a ≤ 0.5.
4. Solve `T_BE(a) = T_M(a)` per rotor per step — damped fixed point or
   bisection on a ∈ [0, 0.5]. 1-D, smooth, cheap (≤ ~10 iterations); cache
   last a as warm start, quasi-static between steps.
5. Torque/power follow from the blade-element forces at the induced inflow —
   per-annulus CP is then automatically Betz-bounded.

### 2a. Existence of the fixed point — the CL model (BLOCKING amendment, Rod 2026-07-18)

With CL held fixed (the unaddressed half of the diagnosis), the fixed point
can have **no solution**: at high tip speed the blade-element thrust is
dominated by the ω·r term — `T_BE ≈ n·½ρ(ωr)²·c·s·CL·cos(bank)` — nearly
independent of a, while momentum thrust maxes out at a = 0.5. Above a modest
ω there is no crossing in [0, 0.5]; a clamps, and power still grows without
bound (`P ≈ n·½ρ·c·s·CL·cos(bank)·v_eff·(ωr)²`) because induction constrains
thrust while fixed-CL torque never feels it. The Betz property test would
trip at the top of its own ω grid.

**Selected resolution — (a) minimal α model** (Rod's preference; fixes the
actual physics, still `expansion_rotor.jl`-only):

- `α = φ − θ_i`, with the incidence `θ_i` back-solved once per rotor so the
  **design point reproduces `EXP_CL_DESIGN` exactly** (backwards-compatible
  where it matters).
- `CL = clamp(slope·α, −CL_max, +CL_max)` (slope ≈ 2π or a stated finite
  value; CL_max stated).
- At high TSR, φ → 0 drives α negative, CL drops, torque brakes — the fixed
  point **always exists**, and the rotor gains the natural aerodynamic TSR
  equilibrium a fixed-CL model fundamentally lacks.

*(Rejected fallback (b): keep fixed CL and define the no-crossing branch
explicitly — momentum wins, forces rescaled to the momentum-consistent
CT-capped values, documented as such. A patch on a patch; retained here only
so the decision is on record.)*

Scope: `src/expansion_rotor.jl` only. The hub disk uses the BEM-coupled v2/v5
path (already momentum-limited) — verify, don't touch. A builder/sim kwarg
`induction::Bool` (default **true** after validation) preserves the legacy
model for reproduction runs: **the phantom gate (117.4 kW bit-identical) must
still pass with `induction=false`** — that gate certifies reproducibility of
the shared data, which the fix must not orphan.

Deferred to v2: inter-rotor wake deficits driven by the overlap matrix from
`wake_overlap_audit.jl` (triangle adjacent-station 32–53%); loaded-shaft
(bowed) geometry in the overlap calculation.

## 3. Acceptance tests (four, as amended by Rod 2026-07-18)

Write BEFORE the fix (TDD), register in `test/runtests.jl` as
`test_expansion_induction.jl`.

1. **Betz cap + solver convergence (property test):** for every expansion
   rotor across a grid of ω ∈ [1, 60] rad/s × v ∈ [5, 15] m/s ×
   λ ∈ {0.69, 0.85, 1.0}:
   - `P_rotor ≤ 0.593 · ½ρ A_ann v_n³` (small numerical tolerance), AND
   - the fixed-point solver **converges within N iterations to a stated
     residual tolerance** (e.g. N = 50, |residual| < 1e-8·T_ref) at every
     grid point. **Non-convergence fails the test** — no silent clamping.
     The fixed point is where an implementation bug will live if there is
     one; with the §2a α model a solution always exists, so failure here
     means the code, not the physics.
2. **Light-loading continuity:** at low solidity / low CL / low ω, a → 0 and
   forces converge to the legacy (`induction=false`) model within 1% —
   the fix must be a limit-correct extension, not a different aerodynamics.
   The §2a θ_i back-solve guarantees the design point reproduces
   `EXP_CL_DESIGN` exactly; assert that too.
3. **Daisy calibration preserved (verified non-vacuous):** re-run the Daisy
   validation; Bergey Cp match stays within ±5% of the current 98.4%, and
   the −20% TRPT offset does not worsen. *Non-vacuousness confirmed
   2026-07-18: `scripts/daisy_builder.jl:117–131` models Daisy's main rotor
   as an `ExpansionRotorParams` passed to the system builder — the Daisy path
   executes `expansion_rotor_forces` and WILL feel the induction change.*
4. **Energy balance closes (v1 bound = Σ per-annulus Betz):** re-run
   `wind_sweep_triangle3_90s.jl` with induction on: every row satisfies
   `P_gen ≤ ΣP_aero,annuli ≤ Σ per-annulus Betz limits` and the per-row
   energy-balance columns are self-consistent. **NOT union-Betz in v1**:
   the union bound implicitly assumes wake coupling, which §2 explicitly
   defers — with the triangle's 23% overlap and no inter-rotor deficits, a
   correctly implemented per-annulus model can legitimately total
   ~1.2–1.3× union-Betz. Union-Betz becomes the tightened bound when the
   v2 wake matrix lands (record both numbers in the CSV meta now so the
   v2 tightening is a one-line change).

Plus, restored per Rod: the **FR4 bit-identity assertion** — a system built
with `N_expansion = 0` produces bit-for-bit identical results to plain v5,
with induction on or off (expansion code must be provably inert when absent;
one line, asserted rather than assumed).

Plus the standing gates: full suite green, phantom gate green with
`induction=false`, JuliaFormatter, cache cleared after every src edit.

## 4. Campaign contamination — the consequence to plan for

**The fix does not rescale numbers; it reorders designs.** `objective_v10`
evaluated every DE candidate with the uncapped model, which rewards blade
area/solidity with unphysical returns. The 12-gon winner (12 blades/rotor,
high solidity) was selected *because* of the very physics this fix removes —
it is precisely the design type induction punishes hardest. Expect:

- The 12-gon is **likely dethroned** — its converged 326–540 kW collapses
  toward the 62 kW ceiling, and it already fails structure (FoS < 1.5
  everywhere, recheck 2026-07-18).
- Low-solidity / larger-radius / fewer-blade designs rise in the ranking.
- Therefore: **plan a V10 re-campaign** (fresh DE run under the
  momentum-limited objective), NOT just re-sweeps of the old winner.
  Re-sweeping a design selected by a broken objective answers the wrong
  question.
- Also contaminated and needing re-statement after the fix: every absolute
  kW in kickstart/wind CSVs (triangle AND 12-gon), `headless_verify`
  history, `dynamic_verification.txt`. Relative/qualitative findings
  (kickstart bistability, FoS-aliasing methodology, k-branch structure,
  drop-rotor experiment) survive.

## 5. Sequence

1. Rod signs off / amends this proposal (esp. the four tests).
2. TDD: write `test_expansion_induction.jl` (red).
3. Implement fixed point in `expansion_rotor.jl` (green). Suite + phantom gate.
4. Re-run `wind_sweep_triangle3_90s.jl` + a 12-gon spot-check with induction
   on → corrected estimates for the Strathclyde follow-up.
5. Scope the V10 re-campaign (objective unchanged apart from the model;
   K-bracket re-hunt mandatory — k_mppt optima will move with the power level).
