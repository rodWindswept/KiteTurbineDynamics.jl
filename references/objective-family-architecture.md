# Objective-family architecture (2026-08-09 audit + consolidation)

Findings from the deep-module audit of the objective family, and the
consolidation that followed.  The audit surfaced 7 deepening candidates; the
windowed-family consolidation (candidates 1–6) is implemented in this commit.

## The defect: a copy-paste lineage, not a family

`objective_v5/6/10/11/12/feasibility.jl` each re-implemented the evaluation
protocol (decode → build → settle/kickstart or static pre-solve → windowed
ODE run → gates → score) with the fitness line as the only real difference.
The codebase knew it was duplicating: `objective_v12.jl`'s header claimed it
"reuses V11 simulation infrastructure" while copying the cold body wholesale;
`build_system_from_v10`'s header admitted it was "adapted from
builders_util.jl".

Consequences, all observed:

- **Live crash on the rejection path.** The first of two Betz ceilings
  (objective_v11.jl:535-546) referenced `P_range` at :545 before its first
  assignment at :562 — an `UndefVarError` that fired exactly on the
  super-Betz outlier the gate existed to catch.  The two Betz ceilings also
  contradicted each other (hub-disk-only area vs banked-annulus area).
- **The interface lied about the genome.** `TRPT_V11_DIM = 14` and
  `search_bounds_v11` returned 14-D bounds, but `objective_v11`/`v12` read a
  secret `x[15]` = log₁₀ k_mppt slot.  Calling the exported objective with
  its own search space's output threw `BoundsError`.  The k contract lived in
  comments only (S1 audit 2026-08-07 had dropped the dead gene but kept the
  phantom slot).
- **Rejection sentinels inconsistent.** Cold paths rejected with `1e9`;
  warmstart with `12.0` (6 places) and `1e9` (1 place); the k-bracket
  filtered `fitness >= 1e8` which MISSED the 12.0 sentinel — an all-rejected
  genome "won" its bracket and entered campaign CSVs as a real result.
- **Stale tuple destructuring.** `diag_warmstart_comparison.jl` destructured
  7 names off the bracket's 11-tuple, silently dropping 4 fields.
- **Two ring-mapping conventions.** The rotor→system-ring mapping existed in
  5 copies; the warmstart static pre-solve and v10 used raw `rotor.ring_idx`
  while the ODE builder used `ring_idx + 1` — the same genome built different
  machines per path (the "13-gon" bug class, ac3db3c / 9ce8bed).
- **A data race in the shipping launcher.** `run_feasibility_phase_a.jl`
  mutated `WARM_RELAX_S[]` per-eval inside its `@threads` DE loop while
  worker threads read the same Ref — thread A's 30 s quick-check could read
  thread B's 120 s value.
- **A pre-existing const shadowing.** `structural_safety.jl` defines
  `FOS_DESIGN = 3.0` (design-point buckling FoS); the objective's
  `const FOS_DESIGN = 1.5` silently shadowed it at load — every runtime
  lookup (including the dashboard's "FoS_design" label) got 1.5.
- **Zero coverage on the newest objective.** No `test_objective_v12.jl`.

## The consolidation

### New: `src/objective_evaluator.jl` — the deep module

- `ObjectiveConfig` — immutable bundle of tunables (k_mppt, relax_s,
  window_s, power_W, v_rated, V12 knobs).  Replaces the module-level Refs.
  Sweep control meets eval reads at this argument; nothing to race.
- `EvalResult` — named result with `status::Symbol` (:ok / :reject) as the
  single reject channel.  Rejected evals carry `fitness = Inf`, `P_mean = 0`,
  `FoS_min = Inf`, `util = -1.0` sentinels.  Tiered scores (objective_feasibility's
  12.0 band) remain legal SCORES produced by adapters — never transport.
- `evaluate_windowed(x, beam, p, cfg; start_mode, ..., fitness_fn)` — the one
  protocol.  `start_mode=:warm` (static pre-solve) or `:cold`
  (settle+kickstart).  The fitness function is the version seam:
  `fitness_fn(P_mean, FoS_min, cfg) -> Float64`; non-finite = hard reject.
- `with_k_bracket(scoring, x, beam, p; ...)` — the shared 3-point k bracket.
  Gates on `status`; an all-rejected genome returns `:reject`, never a fake
  score.  Returns `(EvalResult, k)`.
- Protocol constants moved here (WIND_MS, FOS_GATE, STATIONARITY_*,
  K_MPPT_MAX, V11_DT, WINDOW_S, DISCARD_S) and `build_system_from_v10` moved
  here from objective_v11.jl.

### `objective_v11.jl` / `objective_v12.jl` — thin adapters

Search space + fitness + versioned entry points.  `objective_v11_warmstart`
and `objective_v12_warmstart` are now identical modulo the fitness closure
(which is the point).  `warmstart_with_k_bracket` and
`warmstart_with_k_bracket_v12` share `with_k_bracket`.

Interface changes (all consumers updated in the same commit):

| Old | New |
|-----|-----|
| k via phantom `x[15]` | `cfg.k_mppt` kwarg / config field |
| warmstart returns 10-tuple | returns `EvalResult` |
| bracket returns 11-tuple | returns `(EvalResult, k)` |
| cold returns `1e9` reject | returns `Inf` (check `isfinite`) |
| `WARM_RELAX_S[]`/`WARM_WINDOW_S[]` Refs | `cfg.relax_s` / `cfg.window_s` |
| `V12_*` Refs | `ObjectiveConfig` fields |
| warmstart kwargs `power_W`/`v_rated` | in `cfg` |
| `objective_v11_snapshot` (v10 forwarder) | deleted; direct v10 pin in tests |

Legacy 15-D genome vectors are still accepted and sliced; `x[15]` is inert.

### `builders_util.jl` — `expansion_params_from_rotors`

The single rotor→system-ring mapping.  Canonical: total rings = n_rings + 2,
top rotor on the hub ring, others ring_idx + 1.  `minimal_hub=true`
implements Rod's minimal-TRPT definition (2026-08-09): 1 flown bladed hub
ring + 1 ground ring = 2 rings at n_rings = 1, total = n_rings + 1.

Wired: `build_v10_tight`, `build_system_from_v10`, and the warmstart static
pre-solve (which previously used raw ring_idx — the fix aligns the static
pre-solve's machine with the ODE's machine; the old
`expansion_blade_mass(tip, λ)` call also disagreed with the ODE path's mass
for λ ≠ 1 rotors).  NOT wired: objective_v10 (frozen legacy by decision,
Q1) and the phantom-triangle builder (verbatim legacy reproduction by
design).  `minimal_hub=true` is implemented at the mapping level; the
builder geometry (n_rings − 1 ring count) and the A3 decode gate
(n_rings ≥ 5) are the flagged follow-on before a minimal machine can be
built end-to-end.

### Fixes that fell out

- **Betz block 1 deleted.** The annulus-area ceiling (1.1× tolerance) is the
  intended physics; deleting the hub-disk-only variant removed the crash.
- **FOS_DESIGN shadowing fixed.** The objective's minimum-acceptable FoS is
  now `FOS_GATE = 1.5`; `FOS_DESIGN` reverts to structural_safety's 3.0
  (the dashboard label prints 3 again).
- **Campaign launcher de-raced.** `run_feasibility_phase_a.jl` builds an
  `ObjectiveConfig(; relax_s=...)` per phase instead of mutating a global;
  `PHYSICS_ERA` bumped to `post-20260809-evaluator-consolidation` so stale
  rows are re-evaluated (era-filtered resume already in place).
- **Rejected brackets cannot enter CSVs.** The launcher's `ok` flag now
  reflects `status === :ok`.

## Tests added / changed

- `test_objective_v11.jl`: A1/A2 updated to `EvalResult` + config-based short
  horizons; new `with_k_bracket — all-rejected genome cannot win` (no-ODE
  stub test); snapshot test replaced by a direct `objective_v10` pin.
- `test_objective_v12.jl` (new): v12_fitness power-window/FoS-target/hard-gate
  purity, config-knob independence, one short-horizon warmstart smoke.
- `test_builders_v10.jl`: `expansion_params_from_rotors` canonical,
  blade-scale, and minimal-machine testsets.

## Deletion test

All candidates passed: each merge concentrates complexity that was smeared
across files and scripts.  V13 becomes a ~20-line adapter, not a copy.

## What was deliberately NOT done

- v6/v10 static evaluators frozen (Q1 decision) — superseded, legacy scripts
  still call them.
- v5 aliases kept — 3 alias lines that legacy campaign scripts use; deleting
  them would just push complexity into the scripts.
- Phantom-triangle builder untouched — verbatim legacy reproduction.
- Minimal-machine geometry + A3 gate relaxation — flagged follow-on.
