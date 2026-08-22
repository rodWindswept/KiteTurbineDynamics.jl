# Acceptance-suite re-baseline catalog (2026-08-22) — run AFTER the campaign

**Status:** PLAN — the six ODE acceptance files are red-by-design (calibrated
on pre-fix physics; DECISIONS [2026-08-20/21] re-baseline on the re-run's
winners).  This catalog maps every physics-calibrated expectation to what
changed, so the re-baseline is a deliberate re-measurement, not a debug
session.  Procedure: run each file, record the ACTUAL values on the
post-campaign HEAD, update the expectations with the new git hash, run again
to green, one commit.

**Do NOT re-baseline before the campaign finishes** (winners define the new
seed/artifacts) and BEFORE the non-finite-FoS guard lands (convention-fixes
proposal item 0) — otherwise the re-baselined expectations could encode the
exploit.

## Shared staleness

- `scripts/results/seed_5kw.csv` is the OLD seed (r_hub 0.914, blade_scale
  0.52/0.10 — pre-Daisy-anchored, 2026-08-12 era).  The current seed
  (`seed_genome(5.0)`) is r_hub 2.775, blade_scale 1.0, L=18.8 m.  Replace
  references with the campaign winner genome(s) or the current seed at 18.8.
- All ω/P/FoS numbers were measured on the wrong-length machine with the hub
  double-model — every numeric band is void.

## Per-file catalog

| File | Test | Expectation (old) | What changed | New anchor (measure on HEAD after campaign) |
|---|---|---|---|---|
| test_rope_break.jl | R3 | seed ω_gnd @30 s ∈ [12.5, 13.5] | machine now 18.8 m, hub fixed; seed sustains ω→14.3 | re-measure seed ω @30 s (trace showed ~14.3, still climbing — use the 40 s window value) |
| test_rope_break.jl | build_from | `seed_5kw.csv` @ 21.2 m | stale seed + length | current seed @ 18.8 (or campaign winner) |
| test_evaluator_v13.jl | B1/B2/B3/B6 | old winner CSVs + seed expectations (P_end ≥ 2.5 etc.) | old artifacts void; seed now 8 kW | re-point artifacts at campaign winners (B1 collapse + B2 flywheel are REGRESSION tests — keep the VOID winners archived as the failing artifacts, they must STILL fail) |
| test_gate_v13.jl | A1–A4 | island-1 winner fails gate; P_gen recomputation | structural — A1/A2/A3 should hold; A4 bit-identity holds | verify; re-baseline only if the artifact path is stale |
| test_settle_drag_alignment.jl | B | ω_zero_drag ≈ 16.05 ± 0.5 | settle now parks at 11.96 (18.8 m machine) | re-measure master anchor on current HEAD |
| test_settle_drag_alignment.jl | A | gap < 0.30 on "5kW winner" | winner artifact void; new settle UNDER-predicts (gap ≈ 0.20, passes) | re-point at the campaign winner; re-measure gap |
| test_settle_lowk_honest.jl | A3 | k=5.39 P_mean = 7.15 kW (bit-identical guard) | fixed machine sustains 8.95 kW at k=5.39 | re-measure (expect ~8.95) — keep the bit-identical GUARD semantics (clamp didn't perturb it) |
| test_settle_lowk_honest.jl | A1/A2 | low-k honest rejects (P_mean > 0) | k=0.5 now sustains 3.47 kW honestly; k=4 sustains 8.95 | verify still green; re-point seed at 18.8 |

## Sequencing (with the other post-campaign work)

1. Campaign finishes → winners picked + re-gated (`ode_gate_v13.jl`).
   **Screen every ok winner for the FoS=Inf signature** (the campaign's DE
   ran on the pre-guard evaluator — commit 402697b landed the guard
   mid-campaign; telemetry showed zero FoS=Inf ok-rows, but the re-gate
   must confirm it per winner).
2. Land the non-finite-FoS guard (TDD, RED test first).
3. Re-baseline this catalog on the winners + current HEAD (one commit).
4. Land the convention fixes (brake cap etc.) — then RE-RUN the acceptance
   suite once more (they may shift the numbers again) — amortise by landing
   convention fixes BEFORE the final re-baseline run if sequencing allows.
5. Stage A/B campaigns run on the green suite.

## Non-rebaseline items (verify green, do not touch)

- test_rotor_power_realism (P1–P4: Betz, cp table, divergence) — table-level,
  physics-era independent.
- test_evaluator_v13 B4/B5/B7 (unit gates) — structural.
- test_settle_drag_alignment C/E — monotonicity/sanity, structural.
