# Pitch Depower Campaign v1 — Critical Review & v2 Design
**Date:** 2026-05-27  
**Reviewer:** Claude (domain analysis)

---

## Executive Summary

The campaign ran and produced results, but five fundamental problems render most of its conclusions unreliable:

1. **`damping_mode` is a dead parameter** — it changes nothing in the physics.
2. **T_min = 0 for every single run** — all 768 runs produced a completely slack TRPT at some point, making the tension metric uniformly useless.
3. **Field IMU OFF means the brake never fires** — half the grid was running a different experiment (no-stop scenario) without realising it.
4. **The rotor reverses direction** (ω_hub < 0) in the "best" runs — an unphysical state inflating their scores.
5. **MPPT stall creates 1,000×-rated torques** via ω_gnd/ω_hub torsional decoupling — the most damaging parameter was being scored as just "less smooth", not "catastrophic failure".

The sensitivity finding — Duration > MPPT Stall > Field IMU — is partially real but completely confounded by these problems. We can't trust the recommended settings from v1.

---

## Finding 1: `damping_mode` Is a Dead Parameter (Proven)

**Evidence — exact duplicate rows in the CSV:**

| Run | dm | d_tau_gen_rms | T_mean | omega_hub_final |
|-----|----|-----------|----|---|
| 9   | 1  | 322,125.741… | 3402.24 | 0.01915… |
| 17  | 2  | 322,125.741… | 3402.24 | 0.01915… |

Runs 9 and 17 are identical in every metric despite having different `damping_mode` values. Runs 13/21, 14/22, 15/23, 16/24 are the same pattern — the entire second half of each Field-IMU-OFF block is a copy of the first half.

**Root cause:** `β_rate_max` is stored in `SystemParams` and passed to `override_params`, but the actual mode-switching logic in `ring_forces.jl` / `multibody_ode!` likely checks a hard-coded condition or uses `β_rate_max` for something else entirely (its reserved meaning). The generator control modes (Active Damping, LPF Speed) aren't activated by this field in the current physics code.

**Impact:** 2 out of 7 sweep axes (damping_mode, and by extension a third of all combinations) are testing nothing. 256 of 768 runs are duplicates.

---

## Finding 2: T_min = 0 for All 768 Runs — The Tension Metric Is Broken

**Evidence:** Every row in the CSV has `T_min = 0.0` and `slack_events = 500` (the maximum possible — meaning every saved frame has at least one slack line).

**What this means physically:** The TRPT goes completely slack at some point during every single run, in every parameter combination tested. Once any line hits T < 5 N (the slack threshold), the minimum-tension tracker bottoms out and stays there. The tension_raw metric becomes:

```
tension_raw = T_min - 200 × slack_events = 0 - 200 × 500 = -100,000  (constant)
```

This is constant for all 768 runs. The tension component contributes zero discrimination to the composite score. What you're actually scoring is **smoothness only**, with a +0.1 bonus for whether the brake was reached.

**Root cause hypothesis:** The TRPT goes slack because the rotor reverses. When ω_hub goes below zero (rotor spinning backward), the torsional spring in the TRPT unloads completely and the ropes fall into compression, which they can't carry. This is a genuine physics event — but it's happening in essentially all runs because nothing prevents rotor reversal in the current model.

---

## Finding 3: Field IMU OFF = Brake Never Fires

**Evidence:** Every run with `field_imu=0` has `brake_time=NaN` and `brake_engaged=0`. The brake-time heatmap shows a completely blank panel for Field IMU OFF.

**Root cause:** In `ring_forces.jl`, the brake logic is:
```julia
if p.kp_elev ≈ 1.0
    if sys.brake_engaged[] || abs(omega_hub) < 1.0
        ...
    end
end
```
`kp_elev = 1.0` is set only when `use_field_imu = true`. When Field IMU is OFF, this entire block is skipped — the brake never fires regardless of how slow the rotor gets.

**Impact on the campaign:** The 384 Field-IMU-OFF runs are simulating a different scenario: perpetual spin-down with no brake endpoint. The 384 Field-IMU-ON runs are simulating controlled depower to brake engagement. Comparing scores across this boundary is meaningless. The sensitivity analysis assigned 0.190 η² to Field IMU, but what it's really measuring is "did the run have a defined endpoint?"

---

## Finding 4: Rotor Reversal in the "Best" Runs

Looking at the best-5 time series: ω_hub drops below zero and reaches **-5 rad/s** in the top-ranked runs. This is a rotor spinning backwards — in reality the TRPT has no reverse torque transmission capability (the geometry relies on the twist direction to keep attachment points loaded). A reversing rotor would immediately unload all tether lines, drop the entire airborne system, and tangle the TRPT.

In the simulation, this doesn't trigger any failure — instead the ropes go slack (explaining T_min = 0), the rotor freely oscillates, and then the system eventually damps out. The long 45-second duration means the final 20+ seconds after reversal are calm, which dilutes the jerk metric and makes these runs look "smooth".

**The composite score rewards runs that have a violent transient followed by a long quiet period.** This is the opposite of what we want.

---

## Finding 5: MPPT Stall Creates Catastrophic Torques via Torsional Decoupling

**Evidence from CSV:**

| Run | mppt_stall | peak_tau_gen (N·m) | ω_gnd_final |
|-----|------------|-------------------|-------------|
| 4   | ON, imu=N | 48,929 | −32.4 rad/s |
| 2   | ON, imu=N | 162,363 | 0.84 rad/s |
| 10  | ON, imu=N | 105,117 | −9.6 rad/s |

Rated torque ≈ P_rated/ω_rated = 10,000/9 ≈ **1,111 N·m**. Peak values of 48,000–162,000 N·m are **44–146× rated torque**. The worst runs show τ_gen = 1.75×10⁶ N·m — **1,575× rated**.

**Why this happens:** The MPPT stall governor multiplies k_mppt on the **ground ring** (ω_gnd), not the hub ring. The TRPT allows torsional slip — ω_gnd and ω_hub can diverge. During depower, the backline payout tilts the shaft, changing the effective torque arm and unloading the hub, but ω_gnd continues to spin. With k_mppt at 9×:
```
τ_gen = 9 × 11 × ω_gnd²
```
If ω_gnd reaches 30 rad/s (possible during a recoil event): τ_gen = 99 × 900 = **89,100 N·m**.

The MPPT stall mechanism as designed applies enormous regenerative braking to the ground ring, which stores energy in the torsional spring of the TRPT (winding up the twist angle), which then releases as an impulsive torque spike. The mechanism is self-defeating.

---

## Finding 6: What the Data *Does* Tell Us Reliably

Despite the problems, a few conclusions are physically grounded:

**Duration matters (η² = 0.258) — confirmed and real.** A 45-second depower allows the sigmoid ramp to be much gentler: 15% delay = 6.75s, 70% active = 31.5s. At 10 seconds the ramp is brutally fast (1.5s delay, 7s active). The 3D surface showing a cliff between 10s and 20–30s is real physics — you can't depower a 30m TRPT in 10 seconds without large loads.

**Longer duration + Field IMU ON is the minimum viable combination.** All top-20 runs share these two features.

**Payout 25m > 15m for longer durations (weak signal).** Looking at the best-run labels: the very top configs use 25m payout. More payout = more shaft tilt = more power spill = can afford to be gentler on the torque.

**Active winch provides modest benefit (η² = 0.085).** The proportional payout rate control (T_min feedback) reduces the impulsive nature of the payout curve when segments are near-slack. This is directionally correct but the benefit is swamped by the duration effect.

---

## Root-Cause Diagnosis: What Is Actually Happening Physically

The pitch depower scenario as currently modelled is doing something different from what the name implies. The sequence is:

1. **t = 0–1.5× delay**: System runs at rated ω, fully loaded.
2. **t = delay**: Backline payout begins. This lets the sky anchor rise, tilting the TRPT shaft toward vertical.
3. **TRPT tilts**: As β approaches 90°, the apparent rotor disk area to wind cos³(β) → 0. Aerodynamic torque drops.
4. **Problem**: The MPPT generator is still braking based on ω_gnd². As aero torque falls, the TRPT twist unloads. The ropes (low GJ) go slack. ω_hub decouples from ω_gnd.
5. **ω_hub oscillates around zero** because there's nothing to prevent reversal and the elastic stored energy in the TRPT recoils. MPPT stall makes this worse by amplifying ω_gnd² torques.
6. **Brake fires** (if Field IMU ON) when ω_hub < 1 rad/s — but this is now happening during an oscillation pass through zero, not a controlled approach to zero.

The depower is not smooth — it's a collapse followed by an oscillation. A real-world system would either (a) have blade pitch control to genuinely remove aerodynamic torque, or (b) have a mechanical freewheel that prevents reversal, or (c) gradually increase lift-to-drag ratio of the kite to reduce the torque arm cleanly.

---

## Hypotheses for Campaign v2

### Hypothesis 1: A freewheel constraint changes everything
If we add `ω_hub = max(0, ω_hub)` (zero-reversal constraint, like a mechanical freewheel or roller bearing), the rotor can't store recoil energy in reversed rotation. This will:
- Prevent T_min from hitting zero (no full-slack state)
- Make the MPPT stall behave as intended (braking, not oscillating)
- Give physically meaningful tension and smoothness metrics

### Hypothesis 2: The brake should fire independent of Field IMU
The brake physics (apply_brake_constraint!) is correct. The trigger logic (guarded by kp_elev ≈ 1.0) was a shortcut that accidentally made Field IMU a prerequisite. In v2, all runs should reach brake engagement — then we're actually comparing the quality of the deceleration path, not whether the run ended.

### Hypothesis 3: MPPT stall needs to track ω_hub, not ω_gnd
Apply k_mppt_scale to a torque computed on ω_hub (or the average of hub and gnd), not ω_gnd alone. This prevents the torsional-decoupling amplification. Alternatively, cap τ_gen at 3× rated as a hard limiter before applying the scale.

### Hypothesis 4: Lifter elevation may be a dead parameter — replace it with lift force magnitude
Verify whether `override_params(p; lifter_elevation=...)` actually changes any force in `multibody_ode!`. If `LiftForce` is pre-computed from the geometry at build time, changing the parameter at runtime does nothing. A more physical sweep axis would be `lift_kite_area` or the `RotaryLifterParams.radius`, which directly scales the upward force available to tilt the shaft.

### Hypothesis 5: Duration 60–120s reveals the true optimum
The v1 range (10–45s) showed a monotonic improvement with duration but never reached a plateau. The optimum may be at 60–90s where the depower ramp is gentle enough to avoid TRPT slack entirely. This is the most important axis to extend.

### Hypothesis 6: Wind speed at depower is a key missing variable
All v1 runs used rated wind (11 m/s). In reality, pitch depower is most needed at high wind (gust above rated). At 15–20 m/s the aerodynamic torque is much higher, the TRPT is much more tightly loaded, and the depower sequence is harder. The v2 campaign should sweep v_wind ∈ {9, 11, 14, 18} m/s to understand how the control strategy scales.

### Hypothesis 7: The start of depower matters as much as the rate
The current model starts the sigmoid ramp 15% into the run (the depower_delay). In a real operation, the delay would be chosen based on system state (e.g. TRPT twist < 30°, tension > 500 N, ω in normal range). A state-based trigger for beginning payout would be more representative than a fixed-time fraction.

---

## Proposed v2 Campaign Design

### Pre-campaign physics fixes (required)
1. **Add freewheel: `ω_hub = max(0, ω_hub)` post-step** (or use abs(ω) in aero torque computation)
2. **Decouple brake trigger from Field IMU** — brake fires when ω_hub < 1 rad/s always; Field IMU controls *how* it brakes (with or without active damping)
3. **Fix τ_gen cap**: hard-limit τ_gen to 3× τ_rated = 3,333 N·m before applying k_mppt_scale
4. **Verify lifter_elevation is live** or replace with `lift_force_N` as a direct parameter

### New metrics (replace broken T_min and composite score)
| Metric | Definition | Why better |
|--------|-----------|-----------|
| `peak_tau_over_rated` | max(τ_gen) / τ_rated | Normalised peak load — 1.0 = rated, > 3 = dangerous |
| `t_stable` | time for ω_hub to stay < 2 rad/s for > 1s continuously | Physical settling time, not just first crossing |
| `T_min_active` | min(T_max) during 20–80% of run (active phase only) | Excludes pre-depower and post-reversal slack |
| `rotor_reversal` | Bool: did ω_hub < −0.2 rad/s? | Hard disqualifier |
| `slack_duration_pct` | fraction of active phase with any slack | Replaces binary slack_events count |

### Hard disqualifiers (any = run FAILED)
- `rotor_reversal == true`
- `peak_tau_gen > 5 × τ_rated`  
- `T_max > 2 × SWL` at any point during active phase

Only PASS runs contribute to the composite score.

### v2 parameter grid (reducing wasted axes, adding real ones)

| Axis | v1 | v2 | Reason |
|------|----|----|--------|
| Duration (s) | 10,20,30,45 | 20,30,45,60,90 | Extend toward the optimum, drop 10s (always worst) |
| Lifter force scale | — | 0.7×, 1.0×, 1.3×, 1.6× | Replace dead `lifter_elev` with direct force parameter |
| Wind speed (m/s) | fixed 11 | 9, 11, 14, 18 | Most important missing variable |
| MPPT stall (k scale) | 1× or 9× | 1×, 2×, 4×, 6× | v1 showed 9× is catastrophic; explore the safe range |
| Active winch | off/on | off/on | Keep — showed real signal |
| Payout base (m) | 15, 25 | 15, 20, 25 | Add midpoint |
| Field IMU | off/on | all runs ON | Not a sweep axis — it's a precondition |
| Damping mode | 0,1,2 | remove | Dead parameter; re-add only after verifying mode switch works |

**New grid:** 5 × 4 × 4 × 4 × 2 × 3 = **1,920 combinations** — larger, but all axes are live, all runs reach brake engagement, and failures are caught early.

With 8 threads and ~90s per run average: ~7 hours. Feasible overnight.

### Better composite scoring
```python
# Only for PASS runs:
composite = (
    0.40 * (1 - rank_percentile(peak_tau_over_rated))  # lower peak load = better
  + 0.35 * (1 - rank_percentile(t_stable))             # faster stable stop = better  
  + 0.25 * rank_percentile(T_min_active)               # higher tension during depower = better
)
# FAIL runs get composite = 0 (worst)
```

---

## Summary Table: v1 Problems → v2 Fixes

| v1 Problem | v2 Fix |
|-----------|--------|
| `damping_mode` dead parameter (η²=0.000) | Remove from sweep; fix mode-switch in physics first |
| T_min = 0 all runs, tension metric useless | Add freewheel + phase-aware T_min_active metric |
| Field IMU OFF never brakes = unfair split | Decouple brake from Field IMU; all runs brake |
| Rotor reversal inflates "best" run scores | Add freewheel constraint; rotor_reversal = hard fail |
| MPPT stall 9× creates 1,575× rated torque | Cap at 3× rated; sweep 1×→6× not 1× or 9× |
| Lifter elevation has zero effect (η²=0.000) | Verify parameter is live; replace with lift_force_scale |
| Fixed 11 m/s wind — missing key variable | Sweep v_wind ∈ {9, 11, 14, 18} m/s |
| Composite score dominated by duration alone | Phase-aware metrics; hard disqualifiers; reweight |

---

*The v1 campaign was necessary — it revealed problems that wouldn't have been visible from code inspection alone. The simulation is behaving in ways that are physically significant but not currently captured by the model's constraints (no freewheel, no torque cap, brake tied to Field IMU). Fix those four physics issues first, then the v2 campaign will produce actionable control recommendations.*
