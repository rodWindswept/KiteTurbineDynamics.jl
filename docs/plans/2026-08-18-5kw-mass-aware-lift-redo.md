# 5 kW Mass-Aware Lift Redo — Plan

**Date:** 2026-08-18
**Status:** Spec agreed with Rod; blocked on model-era decision (item 2) before launch.

## Why this exists

The first 5 kW v13 DE campaigns (18.0 / 21.2 / 25.0 m, run 2026-08-14/16, winners
re-gated green at 7.68 / 8.24 / 8.32 kW) were verified NOT to use mass-aware lift:

- Runner `scripts/run_v13_5kw.jl` (created f9f31ec, never modified) line 163:
  `lift_device = rotary_lifter_default()` — a FIXED autogyro lifter
  (1.5 m rotor, ω=33 rad/s held, PCA-2 disk coefficients, 4 kg). Tension is a
  function of wind + its own fixed geometry — identical for every genome,
  independent of machine mass.
- Verified at four independent levels: runner source, evaluator threading
  (`objective_evaluator.jl` 401/468/492/588), force application
  (`ring_forces.jl` 444–480), device semantics (`src/lift_kite.jl` 341–366).
- First attempt actually ran THREE lift regimes: campaign evals = rotary,
  `ode_gate_v13.jl` = rotary (line 93), `regate_winner_v13.jl` = NONE
  (no lift reference in the script).

**Decision (Rod, 2026-08-18):** the 5 kW rung must be redone with mass-aware
lifting before any 7 kW work.

## Rod's decisions recorded (2026-08-18)

1. **Lift semantics:** lift line tension is a function of the kite turbine's
   own mass only. Lift kite mass does NOT enter the tension calculation. The
   device is not modelled — tension exists at 1.5× vertical capacity of the
   machine's weight; the backline-to-ground-anchor restraint is the standing
   assumption.
2. **Margin:** 1.5× vertical lift capacity (`margin = 1.5`).
3. **CONSTANT TENSION (Rod, 2026-08-18):** vertical component = 1.5× mass at
   ALL wind speeds — no v² scaling. Modeling assumption: the lifter is
   actively modulated to hold constant tension (the standard kite turbine
   assumption for this campaign; distinct from the mast/bucket rig which is
   the anchor-only proxy). Implemented as `const_tension = true` on
   `StackedLifterParams`.
4. **First campaign results:** kept, not discarded — retrospectively augmented
   with lift-tension data.
5. **Redo scope:** identical to the first campaign in every respect except the
   lift device — "just mass aware". Seeds, RNG seeds, bounds, evaluator
   config, lengths, DE sizing all unchanged.
6. **Gate alignment:** the ODE gate AND the regate must use the same
   mass-aware constant lift tension as the main campaign (Rod, confirmed
   2026-08-18).

## Workstream A — retrospective lift-tension augmentation (first)

New script `scripts/lift_retrospective_v13.jl`:

- For each of `v13_5kw_len18.0/21.2/25.0/telemetry.csv`: decode every logged
  genome (x1–x14 are in the CSV), build via the builder path, compute
  `m_airborne = expansion_airborne_mass(sys, p)` and the mass-aware
  `T_ref = 1.5 · m_airborne · g / sin(70°)` per genome, plus the single fixed
  rotary tension every eval actually saw at rated wind
  (`lift_force_steady(rotary_lifter_default(), ρ, 11.0)`).
- Write `lift_tension_retrospective.csv` + a provenance note into each results
  folder. Original CSVs untouched — bit-identical first-campaign record
  preserved.
- Headline table: for each winner genome, the tension it was evaluated under
  vs the tension the mass-aware rule requires.
- No ODE evals — builder path only. Cheap.

## Workstream B — the 5 kW mass-aware redo

New runner `scripts/run_v13_5kw_masslift.jl` = copy of `run_v13_5kw.jl` with
exactly three changes:

1. `lift_device = lift_for` where
   `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED)`
   — the Phase A v2 pattern (commit ea32d6d).
2. Telemetry schema gains a `T_lift` column (T_lift_mean from
   ObjectiveResult) — the column the first campaign silently dropped.
3. New output dirs (`v13_5kw_masslift_lenX`), new physics-era tag naming it
   mass-aware, provenance note linking the first campaign as the baseline.

Unchanged: seed genome from `compute_seeds.jl` (`seed_genome(5.0)`),
`Random.seed!(42 + island - 1)`, tight bounds, v13 ObjectiveConfig
(tail5, no ceiling penalty, FoS 1.5/1.5, kickstart 0, k_mppt = p.k_mppt),
lengths 18.0 / 21.2 / 25.0 m, 30×5 islands × 100 gen.

**Gate alignment (required):**
- `scripts/ode_gate_v13.jl` line 93: `rotary_lifter_default()` → `lift_for`.
- `scripts/regate_winner_v13.jl`: currently passes NO lift device — must pass
  `lift_for`.

**Pre-launch checklist:**
- Smoke test the seed genome under `lift_for`: status `:ok`, and verify
  in-run tension ≈ `1.5 · m_airborne · g / sin(70°)` at rated wind —
  acceptance evidence that the lifter is genuinely mass-aware in-run.
- Pre-flight (clearance / Betz budget) on the seeds.
- Suite green on the launch model era.
- Archive any prior masslift dirs before relaunch (void-run hygiene).
- Launch all three lengths in parallel, one monitor cron, per-eval telemetry
  flushed every row.

## OPEN — blocks launch

- **Item 2 (model era):** anchor-session source changes (`lift_kite.jl`
  const_tension, `ring_forces.jl` +58 lines, `KiteTurbineDynamics.jl`) sit
  uncommitted in the desktop tree; laptop has not pushed since 16 Aug. The
  redo must name its model era before launch.
- **Item 3 (7 kW seed):** geometric seed vs winner-family seed, n_lines
  decision — still open, for the 7 kW spec after the redo.
- **Item 4 ((b) verdict):** scale-aware static-gate re-enable for ≤7 kW —
  still unrecorded; does not block the redo (unchanged gates) but must be
  settled before the 7 kW spec is final.
