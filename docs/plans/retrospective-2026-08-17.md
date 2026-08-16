# Retrospective — 2026-08-17

**Scope:** the 2026-08-12 → 2026-08-14 cycle — 5 kW DE campaigns, instrument
faults, model admissibility, and the path to the graduated ladder (3→50 kW).

**Materials:** `docs/agents/instrument-trust-log.md`,
`docs/agents/exploit-register.md`, `DECISIONS.md`, the fresh
`scripts/results/ladder_v13.csv` (corrected-model ODE ladder), and the
campaign telemetry folders (`scripts/results/v12_5kw_coldstart`,
`v13_5kw_len*` — the v13 folders are VOID, see §3).

## 1. The circle, in timeline (what happened, not what we believed)

1. v12 cold-start crowning: 6.34 kW "winner" — actually hub freewheel, not
   transmitted power (gate read ω_hub; P_gen at ω_gnd was 1.57 kW).
2. Static torsional FoS gate: called over-conservative → verdict reversed after
   the ODE confirmed bottom-segment torsional collapse (twist 169× limit).
   The gate was right; the ODE was misread.
3. Evaluator v13 re-instrumentation (tail5, twist hard-reject, no ceiling
   penalty) → campaigns re-run → new winners from a NEW attractor:
   n_active=1, r_hub at lo bound, inverted taper, hub diverging to ω~1e66-1e87
   within 5 s while the ground side read healthy (NaN-frozen state).
4. Model audit after the user's Betz/decoupling critique: `_interp_bem`
   clamped Cp at +0.1376 for ALL TSR>8 (no brake); rope coupling was
   bounded/saturable; twist-crossing was observer-only.
5. A2 (cp falloff from the blade table, cubic drag brake past λ=9.61),
   B (per-rotor Betz ≤1.1×), C1 (crossing-limit torque saturation) — landed;
   P4 STILL red via a new mechanism: translational fling of the 58 g hub
   ring, line tension ~1e135 N (unbounded stretch, no rope failure in model).
6. Rope break (SK99 ε=3.5%, option B: break = immediate disqualification),
   C1 reworked onto the real TRPT-chain topology, t_over_D floor 0.010 —
   P4 green. All acceptance suites + main suite green (1900/1900).
   Pushed 1d0a38a.

**The circle, named:** each fix exposed the next exploit because the model
admitted designs the physics does not. The DE is an excellent auditor.

## 2. Root causes (systemic, not per-bug)

- **Instrument faults:** gate and ODE measured different quantities
  (ω_hub vs ω_gnd); flywheel-window metrics (10 s hot settle) crowned decay
  designs; NaN-filtered per-sample FoS silently passed divergent states
  (the 1e66 hub read healthy at the ground).
- **Model admissibility gaps:** no rope failure (unbounded tension), no
  high-TSR brake (Cp floor), torque transmission without saturation,
  ultra-thin rings without a floor. Each admitted an exploit.
- **Campaign-launch pressure:** campaigns were launched before the model
  was admissible, twice (v12 cold-start, then v13 pre-fix). Void results:
  both v13 finished campaigns + the killed 25 m.

## 3. The open question for today: model admissibility at small scale

The one piece left: **the static structural gates were disabled ≤7 kW
because the SEED scored below 1.5** — but the ODE evidence says the gates'
physics is right and the threshold is wrong at 5 kW. Proposals on the table:

- (b) scale-aware static-gate re-enable: derive the small-scale FoS
  threshold from Daisy (0.22 measured) + the collapse evidence, not from
  the 10-15 kW crossing point.
- A formal **model-admissibility audit** before any further campaign:
  list every gate, its floor/ceiling, its calibration evidence, and its
  acceptance test — a checklist a campaign cannot launch without.
- Q1 verdict pending: does the orbital-damping operator contribute to the
  light-ring fling (lin_damp=0 comparison), or is the 58 g ring doomed on
  its own (physics says doomed).

## 4. The scalability verdict (from ladder_v13.csv, run 2026-08-15)

Corrected-model ODE gate, seed-class design, 7 rungs × 6 lengths:

- **5–10 kW: PROVEN viable** in the design band — 4.4–7.9 kW transmitted at
  18–30 m, no twist, no breaks, no tip-speed violations. Failures only at the
  physical edges: 12 m (tip clearance), 25 m (marginal 2.2–2.4 kW), 40 m
  (twist ratios 0.84–1.82 — crossing at 7 kW+).
- **15 kW: viable at 18/25 m** (8.7/3.4 kW); other lengths clearance-limited
  (bigger rotors hit the ground-offset check).
- **25–50 kW: DENIED — total stall.** k_mppt=108.7 demands 25 kW but the
  seed's swept area is 40 m² (Betz ceiling 19.3 kW, realistic aero ≈9.8 kW
  at 11 m/s). The MPPT loads the machine, ω collapses to ~0.25 rad/s. Not a
  model fault — the seed-scaling rule under-sizes high rungs ~2.5× against
  Betz. The 25 kW rung needs bigger rotors, not just more rings/lines.
- **40 m column: twist-limited at every rung** — long segments wind past the
  crossing limit under the same seed line count; the C1 saturation clamps
  torque but the twist detector rejects. Long tethers need more lines or
  different segment geometry.

**Message:** the corrected model gives a coherent, physical scalability
envelope — viable at 5–15 kW in the design band, denied above by area, not
by numerics. The graduated ladder therefore needs per-rung redesign (which is
exactly what the DE does at each rung), and `seed_genome(kw)`'s high-rung
scaling must grow swept area to the Betz budget before those rungs can pass.

**Update (2026-08-15, evening):** the three DE campaigns at 5 kW completed
and ALL re-gate green — 7.68 / 8.24 / 8.32 kW at 18.0 / 21.2 / 25.0 m. The
25 m winner (8.32 kW) overturned the seed marginality this ladder found
(2.25 kW at 25 m): the DE fixes what the seed class lacks. All three winners
share one family: single rotor, r_hub at the 0.70 floor, n_lines growing with
length. First honest campaign winners of the cycle — see the
`regate_verdict.md` files in each `v13_5kw_len*` results folder.

## 5. Decisions — Monday session (held early: 2026-08-15, with Rod)

1. **LOCKED: model-admissibility checklist as a launch gate** — adopted.
   Implemented as `docs/validation/model-admissibility.md` (15 gates, each
   with floor/calibration/acceptance-test/status; pre-launch procedure;
   waiver log). No campaign launches without it.
2. (b) threshold derivation — schedule and ownership: OPEN (recommended
   before the 7 kW launch).
3. Campaign relaunch policy: ladder order vs parallel lengths — OPEN.
4. Q1 verdict → companion fix (c) in or out — OPEN (cheap test, deferred).
5. Retire the void v13 results folders — archived as `void_v13_pre-fix_*`,
   retirement note pending.
