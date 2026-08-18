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

  **Correction (2026-08-17, anchor-session finding — supersedes the verdict
  wording above, does not delete it):** the ω ≈ 0.25 rad/s stall is now
  understood as a cold-start artifact of the gate at scale (the scaled MPPT
  demand k·ω² plus the low-λ aero balance parks the machines before they
  ever spin — the same mechanism later diagnosed on the April-29 anchor
  rig). The ODE cells therefore carry no physics verdict of their own; the
  ladder can only say "UNPROVEN at ≥25 kW by this gate". The seed-rule
  area argument in the original finding (Betz ceiling 19.3 kW on ~40 m²,
  high rungs under-sized ~2.5×) remains valid as a DESIGN constraint — the
  seeds do need bigger rotors — but it is a scaling-rule argument, not
  something the ODE demonstrated. Before the ladder can judge ≥25 kW: fix
  the gate's cold-start balance at scale (warm start or k-bracket) AND grow
  the high-rung seeds' swept area. See §6 addendum.

  **Why it looks odd that the 50 kW-derived seed stalls at 50 kW — three
  test-side reasons (2026-08-17, code-verified):**
  (a) 50 kW at 11 m/s is standard physics — the swept area does the work
  (P = ½ρv³·A·Cp·η): 50 kW @ 11 m/s needs A ≈ 160–190 m² (rotor radius
  ≈ 7–8 m) at Cp 0.4–0.45, η 0.8–0.85. The seed carries only ~60 m²
  (r_hub 2.889 × (1+λ_t 0.519) → R 4.39 m) — a ~16–20 kW rotor at 11 m/s,
  consistent with its 50 kW label only at a ~15–16 m/s design wind. The
  rating and the geometry disagree ~3×; that mismatch is the finding, not
  an impossibility.
  (b) k_mppt scales ∝ P^2.5 (parameters.jl:507) while the aero drive scales
  ∝ P (area ∝ P): at 50 kW the generator demand at any ω is ~56× the 10 kW
  machine's — the cold-start balance (aero vs k·ω²) collapses to ω ≈ 0.25.
  This is a scaling-law artifact of the gate's controller, not the design.
  (c) The V10_50KW seed itself was never aero-validated — compute_seeds.jl
  marks it "structural proportions only — aero eval was broken". The ladder
  at ≥25 kW tests a phantom at its native size.
  Consequence: the ladder's meaningful signal is the DOWN-SCALED family
  (5–15 kW works at 11 m/s); the ≥25 kW cells are non-verdicts on all three
  grounds. Fix list for judging ≥25 kW: scale the seed swept area from the
  power budget at the rating wind (A ∝ P, R ≈ 7.5 m for 50 kW @ 11 m/s),
  k-bracket or warm start at scale, and an aero-validated 50 kW seed.
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

## 6. Addendum — the anchor session (2026-08-16/17, pre-retrospective)

A full session was spent calibrating the model against the 29-Apr-2020
mast-mount test (thesis config 9, the same field data behind Oliver's own
Fig 5.2(f) — his largest model-experiment discrepancy). The findings
belong in this retrospective because they are the same circle, one ring
out: the model admits what the physics does not, and instrumentation
found each layer.

**What was wrong with the anchor model (all four layers found by
instrumentation):**
1. dt=4e-5 unstable on the 2 mm ropes (ω·dt ≈ 103 → rope-break at step 7)
   — the "13.5 W at every wind" wind-blind artifact. Fixed: dt=4e-6.
2. Generator clamp 2.25 N·m (tau_max_safe scaling) capped extraction ~9×
   below the measured load. Fixed: measured τ(ω) table
   (GeneratorLoadMode :table — 12 knots from 30-s steady blocks,
   22.65→13.11 N·m over 9.75→12.86 rad/s; no-regen floor 2.5 rad/s).
3. Bucket tension scaled with wind (T ∝ v² law → 22 N at low wind).
   Fixed: `const_tension` flag (a hanging weight does not scale with v²).
4. Expansion-rotor α-model + induction on the same 10.8 m² annulus as the
   main rotor braked the machine to a stop in ~12 s (a→0.5, CL negative
   at the 6-blade solidity). Fixed: anchor rig uses the main cp rotor
   only — the thesis's own 6-blade representation (AeroDyn + solidity).

**Data-science lesson (Rod's 30-s-average challenge):** raw 1-2 s rows
carry 2-4 s gust lulls with phase-lagged power (rotor still ~110 rpm at
3.3-4.4 m/s wind → "100.2% of Betz" bins that were transients, not wind
error). The measured envelope is 30-s means: wind 5.5-7.0 m/s, P
168-267 W, ω 9.8-12.9 rad/s. The τ(ω) table's low-ω knots were rebuilt
from startup-transient rows the same way.

**The calibration result (F9):** model 234 W vs measured 223 ± 79 W at
6.25 m/s; Cp_sys ≈ 0.16 both, Oliver's spring-disc Cp_max = 0.166 — three
independent derivations agree at the plateau. Speed gap remains (model
parks at AeroDyn peak λ ≈ 7.6 vs field 4.35) — the thesis's own flagged
6-blade modelling gap. Open items: commit decision (source changes
staged, laptop-authoritative), Gemini vision pass over the test media,
the self-start/EXP_CD_STALL item, and Rod's system-Cp point (no raw field
Cp into the ODE — would double-count the generator).

**Direct relevance to §4:** the ladder's ≥25 kW stall and the anchor's
self-start blocker are the SAME mechanism at different scales — the
cold-start balance. Fix once, and both the ladder's high rungs and the
anchor's low-wind behaviour become testable properly.
