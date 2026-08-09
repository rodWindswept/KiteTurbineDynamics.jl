# Handover — 2026-08-09 objective-evaluator consolidation

**For:** the other session (laptop or desktop), next pull.
**Status:** code + tests complete; suite green; NOT pushed (left for you to
review and push — this session ran unattended overnight).

## TL;DR

The objective family was a copy-paste lineage.  One shared windowed
evaluator now owns the protocol; v11/v12 are thin adapters; k left the
genome; sweepable constants became an immutable config bundle; the
ring-mapping has a single authority with your minimal-TRPT definition
implemented at the mapping level.  The campaign launcher's data race is gone.

Full audit + consolidation record: `references/objective-family-architecture.md`.
Decision record: `docs/adr/0005-objective-evaluator-consolidation.md`.

## What changed (file level)

| File | Change |
|------|--------|
| `src/objective_evaluator.jl` | NEW — the deep module: `ObjectiveConfig`, `EvalResult`, `evaluate_windowed`, `with_k_bracket`, `build_system_from_v10` (moved), protocol consts (moved, `FOS_DESIGN`→`FOS_GATE`) |
| `src/objective_v11.jl` | Adapter only: search space, `v11_fitness`, cold/warmstart/bracket entry points. Betz block 1 (the crash) deleted. `objective_v11_snapshot` deleted |
| `src/objective_v12.jl` | Adapter only: `v12_fitness(P, FoS, cfg)`, cold/warmstart/bracket entry points. `V12_*` Refs deleted |
| `src/builders_util.jl` | NEW `expansion_params_from_rotors` (single ring-mapping authority); `_build_v10_tight` wired to it. Phantom-triangle builder untouched (verbatim legacy) |
| `src/KiteTurbineDynamics.jl` | include + exports for the new module; duplicate `include("simulation.jl")` removed; `objective_v11_snapshot` export removed |
| `scripts/run_feasibility_phase_a.jl` | **Race fixed**: per-eval `ObjectiveConfig(; relax_s=...)` instead of `WARM_RELAX_S[]` mutation; EvalResult destructuring; `PHYSICS_ERA` bumped to `post-20260809-evaluator-consolidation`; `ok` flag reflects `status` |
| `scripts/trace_altitude_torque.jl` | Config-based horizons; EvalResult access; global-reset lines removed |
| `scripts/diagnose_relax_sensitivity.jl` | Config-based horizons; EvalResult destructuring |
| `scripts/diag_warmstart_comparison.jl` | EvalResult/kwarg-k; stale 7-name destructure fixed |
| `scripts/rebaseline_damping.jl` | EvalResult destructuring; `status !== :ok` gate |
| `scripts/run_anchor_batch.jl` | EvalResult destructuring; rejected_eval catch |
| `scripts/recampaign_anchors.jl` | `k_mppt=` kwarg (was x[15] pack); EvalResult destructuring |
| `test/test_objective_v11.jl` | A1/A2 → EvalResult + config windows; new bracket-contract test; snapshot test → direct v10 pin; `FOS_GATE` |
| `test/test_objective_v12.jl` | NEW — first coverage for the newest objective |
| `test/test_builders_v10.jl` | NEW ring-mapping testsets (canonical / blade-scale / minimal machine) |
| `test/runtests.jl` | wire `test_objective_v12.jl` |
| `CONTEXT.md` | vocabulary: windowed evaluator, objective config, eval result, minimal TRPT |
| `docs/adr/0005-…` / `references/objective-family-architecture.md` | decision + audit record |

## Interface changes (consumers updated in the same commit)

- warmstart returns `EvalResult` (was 10-tuple); bracket returns `(EvalResult, k)` (was 11-tuple).
- k: `cfg.k_mppt` or `k_mppt=` kwarg (was phantom `x[15]`).  15-D vectors still accepted, x[15] inert.
- Sweep horizons: `ObjectiveConfig(; relax_s=…)` (was `WARM_RELAX_S[] = …`).  The Refs are **deleted** — any remaining reference errors loudly.
- Cold objectives return `Inf` on reject (was `1e9`); `objective_feasibility`'s tier scores unchanged.
- `warmstart_with_k_bracket(…; cfg=…)` accepts base tunables.

## Where the audit was corrected by you

- The raw-`ring_idx` convention in the warmstart static path: you confirmed it
  came from the need to describe a **minimal TRPT** (1 flown bladed hub ring +
  1 ground ring).  Implemented as `expansion_params_from_rotors(…; minimal_hub=true)`.
  The live paths now use the canonical +1 mapping (static pre-solve and ODE
  finally agree on the machine); v10's copy stays frozen.
- `objective_v5.jl` is NOT "53 lines of aliases" — it is real V5 code with 3
  alias lines that legacy scripts use.  Kept.

## Verification

- Full suite: **1861/1861** baseline before changes → **1861+ new tests
  (v12: 17, ring mapping: 11, bracket contract: 3) green** after (exact final
  count from the suite log, ~4.5–5 min).
- Single-file runs: test_objective_v11, test_objective_v12, test_builders_v10
  all green; A1/A2 short-horizon evals confirm the old Betz crash path now
  runs clean.
- All 16 edited files `Meta.parseall` clean.

## Runbook for the other session

1. `git pull` — review the diff.  Nothing is pushed from this side.
2. If you run a campaign: `scripts/run_feasibility_phase_a.jl` works as-is
   (era bump means old rows re-evaluate — expected).
3. Anything referencing `WARM_RELAX_S` / `WARM_WINDOW_S` / `V12_*` /
   `objective_v11_snapshot` / `x[15]` packing in un-updated scripts/scratch
   files will error — route them through `ObjectiveConfig` per this handover.
4. `julia --project=. test/runtests.jl` before committing (AGENTS.md gate).

## Known limitations / follow-ons

- **Minimal machine is mapping-ready, not build-ready.** `minimal_hub=true`
  maps rotors correctly (2 rings at n_rings=1), but the builder geometry
  (ring count n_rings − 1) and the A3 decode gate (n_rings ≥ 5) must change
  before a minimal TRPT can be built and campaigned.  When you want to run
  the "minimal vs chain" comparison, say the word.
- v6/v10 frozen (superseded).  v5 aliases kept.  Phantom triangle untouched.
- The v12 power window is a SOFT preference: `fitness = -P/(penalty)`, so
  60 kW still outranks 40 kW; the quadratic penalty only bites deeper above
  the ceiling (80 < 60 kW).  If you intended a hard cap, that is a scoring
  change to `v12_fitness`, not a bug.
- `trace_altitude_torque.jl` long-horizon traces: config horizons work; run
  as before otherwise.
