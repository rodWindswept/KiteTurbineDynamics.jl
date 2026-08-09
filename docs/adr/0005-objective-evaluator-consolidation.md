## 2026-08-09: Consolidate the objective family into one windowed evaluator

### Status

Accepted and implemented.

### Context

The objective family (`objective_v5/6/10/11/12/feasibility.jl`) was a
copy-paste lineage: each version re-implemented the same evaluation protocol
(build → settle/kickstart or static pre-solve → windowed ODE run → gates →
score) with the fitness function as the only real difference.  The costs
surfaced as a live `UndefVarError` on the Betz rejection path, a phantom
`x[15]` k slot that made the exported 14-D interface throw `BoundsError` on
its own search space, inconsistent rejection sentinels (1e9 vs 12.0) that let
all-rejected genomes win their k-bracket, two conflicting ring-mapping
conventions that built different machines per path, and a module-Ref data
race in the threaded campaign launcher.  Full audit:
`references/objective-family-architecture.md`.

### Decision

1. **One deep evaluator module.** `evaluate_windowed(x, beam, p, cfg;
   start_mode, ..., fitness_fn)` in `src/objective_evaluator.jl` owns the
   protocol.  The fitness function is the version seam; version files are
   thin adapters.  A V13 objective is ~20 lines.
2. **The result contract is a named struct.** `EvalResult` with
   `status::Symbol` (:ok / :reject) as the single reject channel.  Consumers
   gate on status, never on fitness magnitude.  Tiered scores (e.g.
   objective_feasibility's 12.0 rejection band) remain scores produced by
   adapters for valid evals.
3. **k moves out of the genome.** `cfg.k_mppt` replaces the phantom `x[15]`
   slot.  The k-bracket owns k (λ²-scaled prior × {0.5, 1, 2}) and passes it
   per-eval via `ObjectiveConfig`.  Legacy 15-D vectors are still accepted
   and sliced (x[15] inert).
4. **Sweepable parameters are a bundle, not globals.** `ObjectiveConfig`
   (immutable, threaded per-eval) replaces the `WARM_RELAX_S` /
   `WARM_WINDOW_S` / `V12_*` module Refs.  Sweep mutation and eval reads meet
   at this argument — no shared mutable state, safe under `Threads.@threads`.
5. **The static family (v6/v10) is frozen.** Superseded evaluators, pinned by
   legacy campaign scripts; rebuilding them buys nothing.
6. **One ring-mapping authority.** `expansion_params_from_rotors` in
   builders_util.jl.  Rod's minimal-TRPT definition (1 flown bladed hub ring
   + 1 ground ring = 2 rings) is implemented as `minimal_hub=true` at the
   mapping level; builder geometry and the A3 decode gate (n_rings ≥ 5) are a
   flagged follow-on before a minimal machine builds end-to-end.
7. **The objective's minimum-acceptable FoS is `FOS_GATE`.** The old
   `const FOS_DESIGN = 1.5` shadowed structural_safety.jl's
   `FOS_DESIGN = 3.0` at load (every runtime lookup got 1.5, including the
   dashboard label).  `FOS_DESIGN` reverts to the structural 3.0.

### Consequences

- `objective_v11_warmstart` / `objective_v12_warmstart` now differ only in
  the fitness closure.  `warmstart_with_k_bracket` and
  `warmstart_with_k_bracket_v12` share `with_k_bracket`.
- Bracket returns `(EvalResult, k)`; warmstart returns `EvalResult`; cold
  objectives return scalar fitness with `Inf` on reject.  All script
  consumers updated in the same commit.
- Campaign launcher `PHYSICS_ERA` bumped to `post-20260809-evaluator-consolidation`
  (era-filtered resume already in place) — stale rows re-evaluate.
- Rejected evals can no longer enter campaign CSVs as real results.
- New test file `test_objective_v12.jl`; ring-mapping and bracket-contract
  testsets added; suite green 1861+ tests.

### Alternatives considered

- **Compat shims for the old tuple/15-D interfaces** — rejected: the 15-D
  convention was a comment-documented secret; every consumer was updated in
  the same commit ("the interface is the test surface").
- **One evaluator for the static family too** — rejected: different protocol
  (equilibrium solve, no ODE window), frozen legacy.
