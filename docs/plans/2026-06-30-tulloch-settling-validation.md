# Plan: Tulloch Thesis Validation — Settling Time & Torsional Stiffness

**Date:** 2026-06-30
**Status:** Planned
**Reference:** Tulloch (2021), PhD thesis, University of Strathclyde, §5.3.3, Table 5.13 (p. 228)

## Motivation

Oliver Tulloch's PhD thesis is the only peer-reviewed TRPT dynamic analysis with
experimental backing.  His Table 5.13 (thesis page 228) quantifies a critical
operational characteristic of Daisy Kite TRPT systems:

> A 190 m optimised rotor at 6 m/s wind takes **200 seconds** to settle after a
> 1 Nm torque perturbation.  At 12 m/s the same system settles in **106 seconds**.

These are extraordinarily long settling times — ~3.3 minutes at low wind.  This
has direct implications for:

1. **Controller design** — a controller that hunts k_mppt faster than the TRPT
   can settle will thrash.  The ramp rates in our soft-ramp controller
   (`soft_ramp_controller.jl`) must respect these dynamics.

2. **Dynamic-aware DE campaigns** — the proposed hunt-verify inner loop
   (DECISIONS.md §2026-06-28) runs ~5s hunt sims.  If the TRPT hasn't settled
   in 5s, the hunt converges on a transient, not a steady state.  At 6 m/s
   Tulloch's system needs 200s — our 5s window captures only 2.5% of the
   settling curve.

3. **Attribution & provenance** — the τ(δα) formula, δα* critical twist, and
   torsional collapse concept in our code are all Tulloch's work.  The correct
   attribution (Strathclyde, NOT TU Delft) was fixed in this session across
   `src/ring_forces.jl`, `src/soft_ramp_controller.jl`, and
   `scripts/torsional_collapse_check.jl`.

We have adopted Tulloch's **steady-state torque formula** and **δα* collapse
criterion** but have never verified whether our dynamic model produces
settling times consistent with his spring-disc results.  This plan closes that
gap.

## Reference: Tulloch Table 5.13 (thesis p. 228)

### Experiment design

| Parameter | Value |
|---|---|
| Model | Spring-disc representation |
| TRPT | TRPT-4 geometry coupled to optimised rotor (§5.3.2) |
| TRPT length | 190 m (optimised design) |
| TRPT radius | 0.5 m (constant along length) |
| Section length | 1.25 m |
| Wind speeds | 6, 8, 10, 12 m/s |
| Generator control | TSR = 4.0 at steady state |
| Perturbation | Generator torque reduced by **1 Nm for 0.5 s** |
| Settling criterion | Ground station ω stays within **±2%** of steady state |

### Results

| Wind Speed (m/s) | Torsional Stiffness (Nm) | Settling Time (s) |
|---|---|---|
| 6 | 35–60 | 200 |
| 8 | 65–110 | 167 |
| 10 | 100–170 | 136 |
| 12 | 145–245 | 106 |

### Physics

- Torsional stiffness ∝ axial force ∝ V² → stiffer at higher wind
- Settling time shortens because the stiffer spring + same inertia = faster
  natural frequency → faster decay
- "Close-to linear relationship between V² and torsional stiffness"

## What Agrees Between KTD.jl and Tulloch (Pre-Existing)

| Aspect | Tulloch | KTD.jl | Match? |
|---|---|---|---|
| τ(δα) formula | Eq 4.31: Q = R₁R₂F_x sin(δ)/ls | `ring_forces.jl:273`: identical form | ✅ Exact |
| τ_cap formula | Derived from dQ/dδ=0 | `ring_forces.jl:280`, `trpt_optimization.jl:369` | ✅ Exact |
| δα* critical twist | Eq 4.34 (complex) | `soft_ramp_controller.jl:159`: simplified form | ⚠️ Differs numerically |
| Non-monotonic k_sec | Geometric hardening → peak → collapse | `soft_ramp_controller.jl:13-21`: all 4 regions documented | ✅ Qualitative |
| Wind-speed behaviour | Stiffness ∝ V², settling ∝ 1/V² | Emergent from rope dynamics + thrust ∝ V² | ✅ Qualitative |
| Collapse margin concept | Two equilibrium solutions separated by δcrit | `min_collapse_margin()` tracks δα* − \|Δα\| | ✅ Direct adoption |
| Attribution | University of Strathclyde | Fixed 2026-06-30 (was "TU Delft") | ✅ Now correct |

## What Needs Verification (Disagreements / Unknowns)

### 1. δα* formula — simplified vs. full

Our code uses `δα* = 2·arcsin(L/√(2(L²+2r²)))` (derived assuming equal
ring radii R₁=R₂=r).  Tulloch's Eq 4.34 is the full form:

```
cos(δcrit) = (R₁²+R₂²−l_t² ± √(l_t⁴+R₁⁴+R₂⁴−2R₁²l_t²−2R₂²l_t²−2R₁²R₂²)) / (2R₁R₂)
```

For the TRPT-4 geometry (r=0.32m, L=0.52m), the simplified and full
formulas give different numeric values — but the simplified form is valid
for equal-ring segments which is our use case.  We should verify that
the simplified form is the correct reduction of Eq 4.34 for R₁=R₂=r.

### 2. Settling times — never measured

We have never run a torque-perturbation settling experiment.  Our soft-ramp
controller ramps k_mppt over seconds, and our dynamic sims typically run ≤60s.
At Tulloch's 6 m/s settling time of 200s, our current sims never reach steady
state.

**Key question:** Does KTD.jl produce settling times on the same order of
magnitude as Tulloch's Table 5.13 for a comparable geometry?

### 3. Model-class difference

Tulloch Table 5.13 uses the **spring-disc model** (constant axial force per
section, rigid rings as lumped masses).  KTD.jl uses per-line rope dynamics
with variable tension (closer to Tulloch's **multi-spring model**).

Tulloch's thesis (§5.2.2) compares the two models and finds the multi-spring
model shows *larger amplitude oscillations* but similar frequency content.
The settling times may differ.

### 4. Explicit damper

We add `c_s = 2√(k_sec × I_s)` per ring pair for ζ=1.0 locally
(`ring_forces.jl:307-309`).  Tulloch's spring-disc model has no explicit
structural damper — settling comes from aerodynamic damping and tether material
hysteresis.  Our damper will **reduce** settling times compared to Tulloch's.

## Implementation Plan

### Phase 1: Settling-time test harness (new script)

**Script:** `scripts/verify_tulloch_settling.jl`

Replicate Tulloch's Table 5.13 methodology:

```
For each wind speed v ∈ [6, 8, 10, 12] m/s:
  1. Build system with TRPT-4 geometry (0.32m rings, 10.3m, 6 tethers)
     — OR — optimised system geometry (0.5m rings, 190m, 1.25m sections)
  2. Set generator torque for TSR = 4.0 at v
  3. Run to steady state (ω within ±0.5% for 30s)
  4. Apply torque perturbation: reduce k_mppt to drop τ_gen by 1 Nm for 0.5s
  5. Record ω(t) until it stays within ±2% of pre-perturbation steady state
  6. Compute per-segment k_sec from geometry + tension → total TRPT stiffness
  7. Output: (v, k_total, t_settle) for comparison with Table 5.13
```

**Key decisions:**

- **Which geometry?**  We don't have TRPT-4's exact ring layout (number of
  rings, spacing).  Tulloch's Table 5.13 is for the **190m optimised system**
  with 0.5m rings and 1.25m sections (152 rings).  This is closer to our V10
  designs.  Start with this.

- **Damper on/off?**  Run BOTH to quantify effect:
  - With ζ=1.0 damper (current default) — expected to settle faster
  - Without damper (`c_s = 0`) — closer to Tulloch's spring-disc model

- **Controller?**  Use fixed k_mppt (no soft-ramp controller) — we're testing
  open-loop dynamics, not closed-loop control.

### Phase 2: δα* formula verification (desk check)

Verify that our simplified δα* formula is the correct reduction of Tulloch's
Eq 4.34 for R₁=R₂=r.  This is a paper-and-pencil derivation, not code:

1. Start from Eq 4.34: cos(δcrit) = (2r² − l_t² ± √(…)) / (2r²)
2. Simplify for R₁=R₂=r
3. Compare with our `δα* = 2·arcsin(L/√(2(L²+2r²)))`
4. If they disagree, determine which is correct and fix

### Phase 3: k_sec sweep comparison (headless)

For our optimised V10-geometry designs at steady state, compute:

- **Total TRPT torsional stiffness** = sum of per-segment effective k_sec
  (all segments in series: 1/k_total = Σ 1/k_i)
- Compare the range against Tulloch's Table 5.13 for each wind speed
- This tests whether our emergent stiffness (from rope dynamics) matches
  Tulloch's spring-disc model at the same scale

**Script:** extend `scripts/torsional_collapse_check.jl` to compute and
report total TRPT stiffness.

### Phase 4: Controller ramp-rate calibration

Use the verified settling times to calibrate our soft-ramp controller:

- **Kp upper bound:** ramp rate must be slow enough that the TRPT can settle
  between k_mppt changes.  If settling time at 10 m/s is 136s, and we want
  the system to settle within ~5% before the next k_mppt step, we need at
  least 136 × 0.05 / dt ≈ 170 frames at dt=0.04s between steps.

- **Idle hold time:** currently 0.5s (`soft_ramp_controller.jl`).  At 6 m/s
  this is 1/400th of the settling time — the TRPT hasn't begun to respond
  before the controller starts ramping.

- **Hold detection:** the ±hold_pct tolerance must account for the fact that
  at low wind, ω oscillates with long-period transients.

## Deliverables

| # | File | Purpose |
|---|---|---|
| 1 | `scripts/verify_tulloch_settling.jl` | Settling-time experiment harness |
| 2 | `docs/case-notes/tulloch-table-5.13-validation.md` | Results writeup |
| 3 | `scripts/results/tulloch_validation/` | Output CSVs + figures |
| 4 | `scripts/torsional_collapse_check.jl` (extended) | Total TRPT stiffness report |
| 5 | `src/soft_ramp_controller.jl` (optional) | Ramp-rate recalibration |
| 6 | `docs/plans/2026-06-30-tulloch-settling-validation.md` | This plan |

## Risks & Open Questions

1. **TRPT-4 exact geometry unknown.**  The thesis describes TRPT-4 as 10.31m
   long with 0.32m ring radius and 0.52m section length, but the *number* of
   rings and exact ring positions are not specified.  The Table 5.13 experiment
   uses the *190m optimised system*, not TRPT-4 — the geometry is described
   in §5.3.2-5.3.3.  We need to extract these parameters accurately.

2. **Spring-disc vs. multi-spring settling.**  Tulloch §5.2.2 states the
   multi-spring model shows larger oscillations but comparable RMSE.  Our
   model (closer to multi-spring) may produce *longer* settling times than
   Table 5.13 because variable axial force introduces additional dynamics.

3. **Wind ≠ 12 m/s.**  The Table 5.13 experiment uses rated wind for the
   optimised rotor.  Our V10 designs are rated at different wind speeds —
   we should normalise by rated wind or run at the same absolute speeds.

4. **1 Nm perturbation is tiny at 50 kW scale.**  Tulloch's system operates at
   ~100 Nm rated torque (1 kW at ~100 rpm).  A 1 Nm perturbation is ~1%.
   Our 50 kW system at 50 rpm has ~10,000 Nm rated torque — a 1% perturbation
   would be 100 Nm.  We need to scale the perturbation magnitude.

## Timeline

- Phase 1 (script): 1–2 hours
- Phase 2 (formula verification): 30 min
- Phase 3 (k_sec sweep): 30 min
- Phase 4 (controller calibration): 1 hour
- **Total:** ~4 hours
