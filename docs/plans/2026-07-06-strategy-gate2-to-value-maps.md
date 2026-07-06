# Strategy — Gate 2 to Value Maps

**Date:** 2026-07-06
**Origin:** Cowork advisor (Claude) session (Rod + Claude), synthesizing the PRD 0006
recovery, spoke-tie design change, stability findings, and forward program.
**Status:** PLAN — reviewed by Rod in session; Hermes (DeepSeek) to execute
phase by phase.
**Companion docs:** `docs/prd/0006-gate2-spec.md` (v4, under revision),
`docs/prd/0006-outward-load-spec.md`, `DECISIONS.md` (2026-07-06 entries).

---

## Where we stand (post-recovery)

- Three defects found and fixed: 70/30 blade geometry (`13f304a`), missing
  expansion-blade centrifugal loads (`e5b4886`), invalid Gate 1 k-selection /
  convergence methodology (defects #2, #3).
- Radius ground truth corrected: expansion ring radii 2.2–3.0 m
  (`RingNode.radius`), r_tip 4.6–5.8 m. Mach validity retraction on record.
  Gate 1 max Mach 0.54 — BEM valid throughout.
- Spoke ties (Rod's design change): radial Dyneema spokes, ring vertex →
  floating center node, engage under net-outward load. The old "clamp"
  concept is retired; spoke engagement is a load-dependent sign change with
  a real structural check and a drag cost (ω³, first-order at high ω).
- Neutral radial loading (Rod's design philosophy): operate at small positive
  spoke tension near engagement onset, biased outward, offset set against
  site turbulence. Guard: ramp transients may dominate sizing.
- Stability: **V10 Tight retired** (second grounds — dynamically unstable at
  all low k, worsening as k drops; first grounds — 13 m/s FoS wall).
  **Reinforced marginal** (FoS oscillation likely engagement-boundary dwell —
  verify against signed radial load). **λ=0.69 stable, flat peak, FoS 3.87 —
  lead production candidate.**
- Stability gate calibration data: stable 1.2% / marginal 6.7% / unstable
  ≥11.8% windowed-P range → gate at 4–5%.

---

## Phase A — Preflight closeout (blocks everything)

1. **SWL/line-sizing inversion (Rod, this session):** stop fixing the spoke
   line a priori. `d_line` and MBL become parameters with a documented
   sizing rule; Gate 2 emits `required_MBL_N = FoS_gate × max_T_spoke /
   derating` per row. Line is purchased *after* the map exists, from standard
   co-op stock (3/4/5 mm candidates; 7 mm was sized against the retracted
   27 kN estimate). Reconcile the contradictory SWL entries in DECISIONS.md
   (10.5 vs 19.8 kN) — code is ground truth; delete the loser.
2. **DECISIONS.md fixes:** neutral-loading entry must reference the
   *engagement onset* (zero crossing), not the FoS-1.0 crossing; FoS gate
   entry internal contradiction (≥1.0 gate vs ≥1.5 optimum) resolved per
   Rod's call: **gate ≥1.0 hard, <1.5 caveat flag**; stale `@debug` →
   `@warn`; break nested 2026-07-06 decisions into their own dated entries.
3. **Hardware ceilings (Rod, this session):** generator rpm — *not a
   design-stage constraint* (sized via gearbox/voltage/cooling; drivetrain
   economics revisited after Gate 2). Wrap rate — **CONFIRMED applicable.**
   Stationary member on rotation axis: rigidised pipe-shrouded lift line
   segment passes through the top swivel bearing; back line above is
   ground-anchored. The swivel's rated RPM is the hardware ω ceiling.
   Mitigations (back-line ground anchor, proposed rigidised-pipe-to-backline
   flange) reduce torque ingress but don't raise the bearing's speed rating.
   **Rated RPM TBD — Rod to supply.**
4. **Config stamps** on the stability-investigation runs (git hash, spokes
   on/off, wind, T_sim, convergence machinery used).
5. **Parity guard verified in place:** `objective_v10` errors (not warns) if
   spokes enabled, until spoke drag exists in
   `solve_equilibrium_self_consistent`.

## Phase B — Complete the structural envelope (before Gate 2, not after)

Evaluator-side checks, no sim re-runs needed: strut tension (σ_yield sourced
— which CFRP allowable, from where), knuckle at spoke-termination load case,
blade-root bending (bank-angle decomposition of F_cf + aero; state
centrifugal-stiffening neglect). Envelope = min over compression, spoke,
strut tension, knuckle, blade-root. Every constant sourced and named; every
"expected FoS" stays out of the record until computed. Regressions: ω→0,
mass→0, spoke=nothing bit-identical, full suite green — **in that order,
before commit.**

## Phase C — Gate 2: the constrained operating map

- **2 builders × 6 winds = 12 rows.** λ=0.69 primary; Reinforced comparison.
  Tight dropped (retired twice; optionally one wind for completeness).
- Constraints: spoke FoS ≥ 1.0 (gate), stability gate 4–5% windowed-P range
  (calibrated, provenance: 2026-07-06 stability table), adaptive
  convergence (sliding window, cap 240 s), windowed-mean P only.
- CSV columns: Gate 1 set + `tip_mach_ss/max` (caveat), `n_spokes_engaged`,
  `max_spoke_tension_N`, `min_spoke_fos`, `spoke_drag_kW`,
  `standing_radial_load_N` (signed), `sign_flip_gust_ms`, `required_MBL_N`,
  `n_sims_hunt`, `T_converged_s`, `stability_flag`.
- Tripwire: Mach @ 260 rpm ∈ [0.30, 0.60] asserted at startup.
- Every number in spec/report regenerated by script, provenance-stamped.

## Phase D — Charts and the ramp check

1. λ=0.69 operating map — P(v), ω(v), FoS(v), spoke tension(v), 5–15 m/s.
2. MPPT-vs-neutral overlay — ω_neutral(v) (bisection on net radial load = 0)
   against the controller ω(v) line. The power-vs-fatigue trade, quantified.
3. Spoke tension vs ω — neutral crossing, caveat band entry.
4. Reinforced vs λ=0.69 side-by-side.
5. **Ramp trajectory** — `record_ramp_traces.jl` on λ=0.69 with spokes:
   (tension, ω) path through spin-up/down vs the structural envelope.
   Decides whether fly-light sizing is cruise- or ramp-bound. **The
   neutral-loading claim does not ship without this chart.**
6. Stability exhibit — λ=0.69 clean trace vs Tight divergence (diagnostic
   discipline shown, not described).

## Phase E — Community report → Zenodo DOI

- λ=0.69 operating map as centerpiece; methodology story (three defects
  found, fixed, retracted openly — including the Porto poster correction)
  as the credibility anchor. The retraction is the reproducibility proof;
  don't bury it.
- **"Predictions to test in the field" section:** spoke engagement onset is
  observable (lines going taut at predictable wind/ω); sign-flip margins;
  neutral band. Falsifiable claims for the AWES community (Strathclyde,
  Freiburg, Beaupoil, Ollie et al.).
- Versioned CSVs with tier-X/Y provenance pattern in the data statement.
- Neutral radial loading published as a design philosophy contribution,
  with the ramp bound stated honestly.

## Phase F — Deferred arc (recorded, not started)

Parity lift (spoke drag into static solver) → Phase 2 campaign re-evaluation
→ V11 campaign with neutral-band objective (min mass s.t. neutral-band
operation across a site wind distribution; ramp transients as the binding
off-design case).

## Phase G — Value maps (the destination)

Chain: constrained P(v) map ⊗ site Weibull (Global Wind Atlas, correct
operating-height layer) → AEP per grid cell → cost model (Rod's BOM +
fatigue-driven OPEX from sign-flip rate × site turbulence) → LCOE map →
**displaced-cost map** vs diesel/grid-absence (the mission metric: islands,
Sahel, highlands). Then invert via V11: feed (Weibull, turbulence) per cell,
output the design for that cell — a design-per-climate frontier. Airspace
(SORA) as a geographic constraint layer. Caveats carried: single-scale
validation, stated extrapolation bounds, cost-model honesty about unmeasured
failure rates (loops back to Phase E field predictions).

---

## Inputs owed by Rod (critical path)

| Input | Blocks | Status |
|-------|--------|--------|
| Wrap-rate applicability (stationary member on axis? swivel rating?) | Phase A item 3 | Pending |
| Site wind distribution (Weibull: k=2.0, λ=10.5 m/s — standard offshore-equivalent, provisional) | sign_flip_gust_ms denominator; Phase F/G | ✅ Recorded (Rod 2026-07-06) |
| Knuckle/joint rating when known (replaces derived constant) | Phase B refinement | Open, non-blocking |
| Line purchase (from `required_MBL_N` + co-op stock) | Field rig only | After Phase C |

## Standing discipline (applies to every phase)

CSV first, prose second. ✅ means executed-and-passed. Docs are generated,
not typed. Every constant sourced and named, in one place. Predicted-before-
computed conclusions stay out of the record. Tests before commit, narration
matching actual order. Never overwrite superseded data — move it (tier-X
pattern).
