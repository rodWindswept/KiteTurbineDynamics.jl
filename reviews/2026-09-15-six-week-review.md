# KiteTurbineDynamics.jl — six-week review (2026-09-15)

> **Provenance.** External review written 2026-09-15 by a separate agent session
> ("Clade") that did **not** have this repository checked out; it read commits,
> handovers, DECISIONS entries, retrospectives and plans, and reviewed from that
> record. Committed here 2026-09-15 at Rod's request so the document survives.
> The review's recommendations are not decisions: `DECISIONS.md` is the
> authority for what was ruled. Rod's rulings of 2026-09-15 are recorded in
> `DECISIONS.md` [2026-09-15] and the active sequence is in
> `docs/plans/ACTIVE.md`.

Reviewed: 156 commits 2026-08-04 → 2026-09-15 (HEAD `2d6233b`, master == origin/master), handovers 08-20 → 09-14, DECISIONS entries 08-16 → 09-14, retrospectives 08-17 and 08-26, docs/plans, docs/outreach. Repo on Rod's ThinkPad: `~/Documents/GitHub/KiteTurbineDynamics.jl` (sibling `CoaxialAutogyroStacking.jl` idle since 08-20).

## Arc

| Dates | Movement | Outcome |
|---|---|---|
| 4–16 Aug | Evaluator hardening v12→v13 (hub freewheel, ω→1e66, unbounded tension, Cp clamp) | rope-break, cp falloff, Betz, twist saturation. "DE is an excellent auditor" |
| 16–19 Aug | Daisy April-29 anchor | wind-blind was numerics + torque clamp; reproduces 212–227 W @ 5–8 m/s. Only external validation |
| 20–24 Aug | blade-mass law, honest 40 s window, FoS guard | 1st 5 kW campaign VOID (λ³); re-run verified; dead genes x6/x7/x9 |
| 25–28 Aug | three-section geometry, rotor_count_mode | session crash, FoS off-by-one → VOID; wake blocking backwards |
| 2–4 Sep | mass-model audit | VOID (toothpick rings, uniform ring mass, knuckles); fitness redesign; 18.49 kg winner FoS 17.2 |
| 6–10 Sep | FoS 17.2 = OD-floor artefact, true ≈1.2; R7 closed-form sizing, 10-D genome | relaunch: 47 genomes, 0 valid. Shaft wind-up + 10 s wobble; lin_damp=0.05 masks loads |
| 11–15 Sep | settle↔ODE coherence | wind-up root-caused; FoS 1.31 vs 2.5 real; lift chain was disconnected; CONTEXT diagram wrong; shaft bows ~1.5 m; asin(clamp) silent 90°; hardcoded ω; bearing offset derived from 31° bridle cone |

State 09-15: fast 2108 pass / 3 broken; acceptance 4/8 red, deliberately not rebased; no valid 5 kW design; static solver harness verified, not converging. Five campaign cycles, zero surviving winners.

## Validated
Daisy anchor; blade-mass exponent 3.0; rope break; min_airborne_fos; wind-blocking direction; non-finite FoS guard; realisability raises; tether-drag factor ≈1.09 vs Tveide (not landed); matched-place twist; physics-topology rulings.

## Open
Static solver; preload/load split; back-line contradiction (09-12 taut vs 09-13 slack); tilt (~35 % tension error); re-seed candidate `[2.6,0.575,2.0,6,0,3,11,11,0.8,0.8]` bank 11° (decided); banked main rotor; bearing damper; wobble policy; segments 7–8 under-carry torque; ω=4.842 observation.

## Direction recommendations
1. Campaign moratorium with a written exit gate (V2/V3/V6 promoted, back-line resolved, load split derived, acceptance 8/8 unrebased).
2. Static solver: dynamic relaxation with kinetic damping (Barnes) on the existing force evaluator, in src/ with the guard as test.
3. Decide lin_damp=0.05 (physical rope loss vs wobble gate) before any sizing — move to item 2.
4. 1.5 kW Daisy-scale campaign as validation before another 5 kW run.
5. Make the power target explicit (docs still say 10–50 kW; work is at 5 kW).
6. Publishable unit now: Daisy calibration + model-admissibility story; technical report's ⟨RB⟩ numbers wait.

## Management recommendations
Lines since 08-04: src +5.6k, test +3.8k, docs +32.6k, handovers +5.4k, DECISIONS +3.8k, scratch +9.2k (138 files). Handover prose is now an error source (09-13 phantom failures; 09-14 wrong-caused conclusion).
1. `scripts/status` — machine-generated state (HEAD, suite summary line, acceptance per file, campaign register).
2. Handover template capped ~100 lines.
3. `docs/plans/ACTIVE.md` single priority list; one item per session; CLAUDE.md reflect-back names the item.
4. Probes must assert or their numbers aren't cited; lint scratch/ citations; triage scratch.
5. `scripts/results/REGISTER.md` campaign register VALID/VOID.
6. Remove `script -q -c` (exit 0 mask) from CLAUDE.md; add a one-page model-rules digest like physics-topology.md.
7. Hermes + Claude both write the tree — same handover/decision path.
8. One formatting-only commit; handovers/README gaps; dead export `design_preload_from_sky_anchor`.

## Decisions asked of Rod
Q4 deliverable (design / report+DOI / Oct visit)? Damper: physical value or wobble gate? Is ~1.5 m hub bow acceptable or a design constraint?

## Rod's rulings (2026-09-15)

**Q4 deliverable — RULED.** Priority is the validated 5 kW "design" (model-space analysis). Then the 1.5 kW Daisy-scale validation; the two together make the report. End-of-October Alicante visit stands; prep starts once the 5 kW space is explored and openly reported. 10–50 kW systems on hold until then. Rec 4 (1.5 kW before 5 kW) is therefore reversed: 5 kW first.

**Damper — RULED (see `DECISIONS.md` [2026-09-15]).** Rod's understanding was that line damping is drag-based (Tveide) and only the lift-bearing damper is suspect. Source check (`src/initialization.jl:584-656`, HEAD `2d6233b`) shows four separate mechanisms:
- `p.zeta = 0.05` — rope **material** damping (Dyneema), physical, `parameters.jl:177,224`.
- `TETHER_DRAG_CD = 1.0` — aerodynamic line drag, Tveide-validated, `aerodynamics.jl:346-389`.
- `lin_damp=0.05` — applied to **rope (TRPT line) nodes**, not the bearing: every step the non-orbital component of each rope node's velocity is multiplied by 0.05 (calibrated at dt=4e-5 → decay rate ≈7.5e4 s⁻¹, time constant ≈13 µs). Numerical, not physical. The `# bearing damper retention factor` comment on it in `objective_evaluator.jl:508` and `objective_v11.jl` was mislabelled and is now corrected.
- `bearing_tr_damp=0.99994` and `ang_damp=1.0` — legacy `simulate()` only; `run_canonical_sim!` accepts neither, so they have never been active in a campaign evaluation.
Ruling: **every damping term must be justified**; the wobble is **gated** (review option (c)), not given a DLF.

**Hub bow — RULED: output, not a constraint.** Terminology: "bow" in the handovers = lateral deflection of the column axis from the design line, driven by the perpendicular gravity component on the tilted axis (catenary-like sag in the shaft plane, 09-12 handover §2). Note the 1.5 m figure is a rigid-tilt estimate (sin θ = 124/1589 over 18.8 m), not a solved shape; a relaxation probe on 09-13 gave 0.116–0.776 m depending on bridle rest length, and did not converge. Rod: ~1.5 m at operation is plausible for a large system in low wind; if bow varies by configuration and drives fitness, that is a scaling/design-law result and may motivate cyclic blade banking. If the settle/rapid solver and the ODE disagree on bow, the fault is re-initialisation from settle or force/transient scaling — a bug, not a design question.
