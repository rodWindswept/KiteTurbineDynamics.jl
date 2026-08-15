# Rope-break physics + the light-ring fling — getting P4 green

**Date:** 2026-08-14
**Status:** PROPOSAL — physics-model change; acceptance tests RED on master first.
**Retrospective booked for Monday (process session, separate).**
**Campaigns remain STOPPED until P4 green.**

## The failure, quantified (from diag_where_diverges.jl + genome arithmetic)

The 18 m v13 winner reaches ω_hub = 3.54×10⁶⁹ within 5 s of MPPT — a torque-equilibrium
fixed point (torques[hub] ≡ 0, alpha winds linearly) created by:

1. **Ring mass at the thinness bounds.** t_over_D = 0.005 → tube wall t = 1.4×10⁻⁴ m
   (0.14 mm). Ring mass ≈ n_lines·L_beam·π·D·t·ρ ≈ 13 · 0.225 m · 1.25×10⁻⁵ m² · 1600
   ≈ **58 g per ring**.
2. **Rotor thrust at operating point.** ct(λ≈7.4) ≈ 0.98 → thrust ≈ ½·1.225·(π·5²)·121·0.98
   ≈ **5.7 kN**. A 58-gram ring under 5.7 kN accelerates at ~10⁴ m/s² ≈ 10,000 g.
   **The fling is genuine physics, not numerics** — the DE built a ring lighter than a
   chocolate bar and asked it to hold a car's weight.
3. **The model then invents impossible rope.** The spring law integrates unbounded strain:
   tension reaches ~10¹³⁵ N (Dyneema fails at 3–4% strain ≈ 30–40 kN for a 4 mm line), and
   the stretched-line torque exactly cancels the aero brake at the balloon fixed point.
4. **The instruments miss it again** — the same NaN-filter family: post-fling ring FoS
   samples are NaN → filtered → FoS_min read from the remaining healthy rings.

## Change 1 — rope break physics (definite; correct regardless of anything else)

- **Criterion:** a sub-segment breaks when its strain exceeds the ultimate strain:
  ε_break = 0.035 (Dyneema SK99 ≈ 3.5%). Strain-based, because the spring law already
  computes ε per sub-segment.
- **Consequence:** a broken sub-segment transmits zero tension thereafter (a per-sub-seg
  broken flag — persistent slack). No invented wreckage physics: the machine loses
  transmission, power collapses, the evaluator's existing rejections (P below floor,
  twist flag, broken-line flag below) do the rest.
- **State representation:** broken flags live in a mutable bitfield on the system
  (not the ODE state vector) — `sys.broken_lines::BitVector` (1 per sub-seg), read by
  `get_subsegment_tension` (broken → 0.0).
- **New rejection channel:** evaluator + gate reject when any TRPT line is broken
  (a broken machine is not a candidate design).
- **Numerics:** with T ≤ ~40 kN the balloon fixed point is unreachable — tension is
  physically bounded for the first time.

## Change 2 — the fling: physics verdict first, then the companion fix

The fling is genuine (58 g vs 5.7 kN), but two questions remain before we decide the
structural fix:

- **Q1:** is the orbital-damping/bearing operator interacting with light rings correctly?
  Test: same winner with lin_damp=0 — if the fling changes materially, the operator needs
  a dt-scaling/light-ring audit (the dt-unscaled-operator family).
- **Q2:** why did the ring structural gates not reject this design earlier? The ODE ring
  FoS should have read ≈ 0 for a 0.14 mm-wall tube under 5.7 kN — trace whether the
  pre-fling samples were below fos_hard and were masked by the NaN filter, or whether the
  tube buckling model misses the thin-wall case.

**Companion fix options (after the verdict):**
- (a) ring-mass/strength coupling in the decode: t_over_D floor raised (e.g. ≥ 0.01) and/or
  Do_top floor — bounds are Rod's call, as always;
- (b) the static structural gates re-enable for ≤7 kW with a scale-aware threshold (the
  open item from before — this finding strengthens the case);
- (c) orbital-damping operator fix, if Q1 shows a numerical contribution.

## Acceptance tests (`test/test_rope_break.jl`, RED on master)

| # | Test | Expected |
|---|------|----------|
| R1 | unit — break criterion | sub-seg strain > 0.035 → tension 0.0 thereafter; below → unchanged (master: tension grows unbounded) |
| R2 | end-to-end — the 18m winner | 30 s run: NO balloon fixed point. Either all |ω| ≤ 1e3 rad/s or lines broken (tension never exceeds ~1e5 N at any checkpoint). Master: 3.54e69 ❌ |
| R3 | healthy design untouched | seed 30 s trajectory bit-identical to pre-change (strains ≪ 3.5% everywhere) — suite 1901/1901 stays green |
| R4 | broken-line rejection | a design whose lines break evaluates `:reject` with the broken flag set (master: no flag exists) |
| R5 | fling verdict recorded | diag: lin_damp=0 vs 0.05 comparison of the winner's first 5 s — the verdict (physics/numerics) lands in the results folder |

## Blast radius

- Every ODE simulation gains the break check (one comparison per sub-seg per step — the
  hot loop stays allocation-free; the flag lookup is a BitVector read).
- Healthy designs (strain ≪ 3.5%) are bit-identical — verified by R3 + the full suite.
- Past CSVs remain historical (new physics era, provenance stamps).
- DECISIONS entry on approval (strain value, consequence model, flag representation).

## Decision needed from Rod

1. ε_break = 0.035 (SK99 3.5%) — **CONFIRMED (SK99).**
2. Consequence model — **B: break = immediate disqualification.** Zero tension after
   break (same physics as persistent slack), but the evaluation STOPS at the break instant
   and returns `:reject` — no post-break simulation, clean telemetry, broken candidates
   stop burning compute. Small early-exit hook in `run_canonical_sim!`.
3. Companion fix — **(a) NOW: t_over_D floor 0.005 → 0.010 (the seed's own value);**
   **(b) MONDAY: scale-aware static-gate derivation with the retrospective.** (c) decided
   by the Q1 verdict when it lands.
