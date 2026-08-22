# Handover — 2026-08-21 (Daisy-anchored 5 kW campaign prep: gate alignment, blade-mass fix, window-flattery catch)

**From:** Hermes (desktop session)
**To:** next agent session (laptop or desktop)
**Repo:** /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
**State:** HEAD `b5902a0`, pushed, in sync with origin. Fast suite 1919/1919 green. Acceptance suite red-by-design (re-baseline pending).

## What this session accomplished

1. **Bookkeeping.** Pulled the two laptop commits (`08365e9`, `bb4dafa`) with a
   clean stash/pop cycle. Committed + pushed the 2026-08-21 working tree in two
   commits:
   - `9b6b494` — Daisy-anchored worktree: r_bottom decoder clamp 1.5→0.1 m,
     lifter mass excluded from tension sizing (`include_lifter=false`),
     reference-tension chain fixed (`base_params=p_base`, phantom 81 kg gone),
     annulus-aligned Betz gates, k=5.39 sweep-selected, seed mask proxy 0.0
     (single hub rotor), **gate alignment** (below), DECISIONS [2026-08-21].
   - `b5902a0` — Gate 1c blade mass renormalised (below).
   Net diff reviewed before each commit; suite run before each commit.

2. **Gate alignment — "same machine, same rules".** `ode_gate_v13.jl` (and
   regate/ladder, which include it) still built the 10 kW-DRR-theory machine:
   `params_10kw()` base, `mass_scale(..., 10.0, KW)`, theory k, power floor
   2.5 kW. The laptop's Aug-19 fix (commit `0ee2d4c`) had aligned the LIFT
   device only; the base params were never touched on either machine. Now:
   `params_daisy()` base, `mass_scale(..., 1.5, KW)`, k=5.39 at 5 kW, power
   floor 5.0 kW, L default 18.8 m. Runner, smoke, gate, regate, ladder now
   build one machine. Recorded in DECISIONS [2026-08-21] §"Gate alignment".

3. **Gate 1c blade-mass resolved.** The builder forces `n_blades = n_lines`
   (balanced polygon, `builders_util.jl:148-158`) while Daisy measured 3 blades
   on 6 lines — blade mass was 2× the anchor. Fixed in the anchor:
   `params_daisy` m_blade 0.420→0.210 kg so the built 6-blade rotors total the
   measured 1.26 kg/ring. Precedent: `params_10kw` 11/5 (2026-07-18). Audit:
   Daisy was the ONLY params set with the mismatch (all others are
   n_blades = n_lines consistent). DECISIONS [2026-08-21] §"RESOLVED".

4. **Smoke PASSED** (`scripts/smoke_masslift_v13.jl`, L=18.8, mass-min config,
   k=5.39, FoS floor 2.5, P floor 5.0): status ok, P_mean 7.15 kW, P_end
   5.97 kW, FoS 106, T_in = T_exp = 205.4 N at 0.00% rel (mass-aware lift
   verified per-genome), m_airborne = 13.12 kg.

5. **1-length DE launched, then killed ~2 min in** — the gate caught a
   fitness-integrity problem on the seed (below). Nothing was burned; the
   partial results dir `scripts/results/v13_5kw_masslift_len18.8/` is harmless
   (runner truncates PROVENANCE.md/telemetry.csv with `"w"` at launch).

## THE OPEN TASK — do this first: the evaluator window flatters power

The gate (30 s, P_gen at the ground ring) traces the seed's decay from the
idealized settle ω:

| t | ω_gnd | P_gen |
|---|-------|-------|
| 5 s | 12.12 | 7.57 kW |
| 10 s | 11.18 | 6.99 |
| 15 s | 10.44 | 6.13 |
| 20 s | 9.77 | 5.02 |
| 25 s | 9.05 | 3.99 |
| 30 s | 8.36 | **3.15** |

Monotonic decay, still falling at 30 s; the equilibrium is exact
(P = k·ω³ = 5.39 × 8.36³ = 3.15 kW). Extrapolated sustained power ≈ 2.5 kW —
the smoke's "5.97 kW P_end" was sampled mid-relaxation at 20–25 s. This is the
"ODE gate must outlast the fitness window" trap (2026-08-13), round 3: with
the 20 s window the DE believes the seed's ~10.8 m² annulus already delivers
~6–7 kW and has no pressure to grow it; winners would fail the gate. The seed
is genuinely under-rotored (needs ~17 m² at the model's equilibrium Cp ≈ 0.36
for 5 kW sustained).

**Decision needed (Rod):**
- **Option 1 (recommended):** honest window now — relax 10 s + window 40 s
  (tail5 at 35–40 s), log the ω_settle − ω_final gap per eval (the 2026-08-13
  gap metric), **re-sweep k under the honest window** (the 5.39 choice came
  from the flattered sweep and may not survive), then launch. Eval ~110–140 s
  → campaign ~28–35 h. No physics change.
- **Option 2:** fix the settle first — `settle_to_operational_state`'s
  idealized ω balance lands 10–60% too fast; the Aug-13 drag experiment showed
  drag is negligible (~26 W), so the gap is a Cp/TSR mismatch in the settle's
  aero model. Physics change to shared init → proposal + acceptance tests +
  DECISIONS. Makes every future campaign honest AND faster.
- Suggestion: 1 now, 2 as the parallel workstream.

## Other open items

- **Runner cosmetics (fix before launch):** banner hardcodes `fos_target=1.5`
  (cfg is 2.5, line 252); `GIT_HASH` reads "unknown" (broken `read(chomp, cmd)`
  syntax → real hash missing from provenance stamps).
- **Monitor cron:** `~/.hermes/scripts/masslift_monitor.sh` updated to len 18.8
  and change-gated; the cron job itself is deferred until the launch decision
  (see ktd-de-campaigns `references/masslift-redo-2026-08-19.md` for the
  flash-pinned cron recipe).
- **Length:** 18.8 m is Daisy-up (10.31 × √(5/1.5), runner comment); the old
  18.0/21.2/25.0 set traced to the 50 kW-era ladder. Rod confirmed 18.8 stays
  unless he says otherwise.
- **Acceptance suite** red-by-design until re-baselined on the re-run's
  winners (DECISIONS [2026-08-20]/[2026-08-21]).
- **Still open decisions:** Daisy i_pto placeholder 0.3 kg·m²; φ mass exponent
  underdetermined (field tests).

## Anchor facts (do not re-derive)

- Seed equilibrium at k=5.39: ω_gnd 8.36 rad/s, P 3.15 kW sustained (gate).
- Daisy anchor: see `docs/validation/tulloch-prototype-configurations.md`.
- k sweep (flattered window, superseded pending re-sweep):
  `scripts/results/k_sweep_daisy_5kw.csv` (knee k≈4.0, k<4 rejects at 0 kW).
- Fast suite: 1919/1919 (2026-08-21, two runs, green on both commits).

## Suggested skills

- `ktd-de-campaigns` — evaluator selection, per-rung config, launch checklist;
  read `references/mass-aware-lift-requirement.md` and
  `references/masslift-redo-2026-08-19.md` first.
- `ktd-campaign-dev` — handoff workflow, pre-launch admissibility, gate
  workflow, crash-proofing, campaign reporting standards.
- `ktd-desktop-workflow` — background-run hygiene, handoff-first rules.
- `ktd-instrument-faults` / `simulation-instrument-faults` — if the window
  decision reopens instrument-vs-physics questions.

## Reference paths

- DECISIONS.md [2026-08-21] — Daisy anchor, seed fixes, gate alignment, Gate 1c
- `docs/plans/2026-08-21-daisy-anchored-5kw-seed-fixes.md` — fix plan + verification sequence
- `docs/plans/2026-08-20-daisy-anchored-5kw-rerun.md` — re-run config
- `handovers/handover-2026-08-20-model-scaling-daisy-anchor.md` — prior session (still current for the Daisy anchor + mass-min objective)
- `scripts/diag_daisy_seed_stall.jl`, `scripts/sweep_k_mppt_5kw.jl` — diagnostic scripts
