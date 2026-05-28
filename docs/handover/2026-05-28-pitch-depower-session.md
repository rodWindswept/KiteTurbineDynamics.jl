# Handover — Pitch Depower Physics & Sequencing Session
**Date:** 2026-05-28  
**Repo:** KiteTurbineDynamics.jl  
**Scenario under investigation:**  pitch depower - typically 20s or 30s — Field IMU active damping ON, LPF Speed Mode 2 (`ctrl_mode=2.0`), rotary lift device elevation factor usually ~ 1.6× or 1.7x 

---

## 1. Issue Investigated: Red Ring Buckling FoS After Brake Engages

### Observation
After the PTO brake locks at t ≈ 1.5 s, intermediate TRPT ring beams progressively show
higher buckling utilisation — all turning red by end of playback. With no torque being
transmitted and a TRPT that should be unwinding, ring compression should decrease, not
increase.

### Root Cause — Three Compounding Effects

**1. Brake only locks the ground ring.**  
`apply_brake_constraint!` zeros `omega_gnd` (ring_idx = 1). The hub ring (`ring_idx = Nr`)
is completely free to rotate. Nothing in the force model arrests backward hub rotation.

(this is later confirmed normal and as expected as the turbine rotor is flying)

**2. BEM tables give near-zero torque at standstill and backward rotation.**  
`CP(0) = CT(0) = 0` by table anchor (`aerodynamics.jl`). The code also maps backward
rotation to forward-table lookup via `lambda_t = abs(omega_rotor) * R / v`, giving
near-zero restoring torque when the hub reverses.

**3. TRPT torsional restoring force drives hub backward without opposition.**  
Stored twist in the TRPT lines exerts an unwind torque on the hub. With the BEM model
providing zero counter-torque, the hub spins backward → reverse twist accumulates →
the same inward radial force mechanism as forward twist → ring compression grows
monotonically. The red rings are a **simulation artefact** from missing blade drag at
backward rotation.

*Physical reality:* backward-spinning blades at combined axial wind + tangential reverse
velocity experience AoA 40–70°, CD ≈ 1.3–2.0. Estimated restoring torque at ω = −2 rad/s:
~1950–2860 N·m vs ~200 N·m TRPT restoring force. The hub would not significantly reverse
in the real system.

### Fix Implemented — `src/ring_forces.jl` lines 68–113

Split the `tau_aero` block into two branches:

```
if omega_rotor >= 0:   existing BEM Cp table (unchanged)
else:                  blade-element drag model (new)
```

Backward-rotation model:
- CD_reverse = 1.3 (NACA4412 deep-stall)
- Blade chord from BEM solidity: `c = 0.113 × R` (≈ 0.60 m at R = 5 m)
- Blade span: R_i = 0.4 R (TRPT inner cutout) to R_o = R
- Approximated via 70%-span representative radius (±15% vs. full integration)
- Restoring torque is positive — drives omega back toward zero

Forward/standstill path is unchanged. `CP(0) = 0` at standstill is intentionally retained:
the TRPT turbine genuinely requires kickstarting at flat pitch, consistent with field experience.

---

## 2. Issue Investigated: Sky Anchor Violent Shaking After TRPT Unwinds

### Observation
After the TRPT lines straighten, a violent translational oscillation persists at the sky
anchor and propagates back down into the bearing and TRPT geometry — appearing in the
dashboard as renewed torsional resonance even though the TRPT has fully unwound.

### Root Cause — Missing Geometric Stiffness at Sky Anchor

The previous model applied the lifting kite force as a fixed vector in space:

```julia
lift_dir = cos(θ_lift) .* downwind .+ sin(θ_lift) .* [0.0, 0.0, 1.0]
forces[sky_anchor_gid] .+= T_lift .* lift_dir
```

`sky_anchor_pos` was never used to compute the force direction. A constant force does zero
net work around a closed cycle (conservative), but it provides **zero position-dependent
restoring force**. The sky anchor was therefore a free mass with no geometric spring from
the kite side.

Physical reality: the lift line runs from the sky anchor up to the topmost lifting kite. Tension acts along
that line. When the sky anchor displaces by δ⊥ perpendicular to the nominal line, the
restoring force component is `T_lift × δ⊥ / L_line`. For T_lift ≈ 2000 N, L_line = 25 m:
**k_geo ≈ 80 N/m** — absent from the previous model.

When the TRPT fully unwinds, the rapid change in rope geometry sends an impulse up through
the cyan line to the sky anchor. With no geometric spring, the sky anchor rings indefinitely
and re-excites the bearing and TRPT.

### Fix Implemented — `src/lift_kite.jl` + `src/ring_forces.jl` lines ~261–299

Added `lift_line_length()` dispatch (three one-liners for `SingleKiteParams`,
`RotaryLifterParams`, `StackedKitesParams`).

In the force application block, replaced fixed-direction application with tension along the
actual kite–sky-anchor line:

```
sky_anchor_eq = bearing_pos + CYAN_L0 × shaft_dir_c   (bearing is stable under bridles)
kite_pos      = sky_anchor_eq + L_line × lift_dir_eq   (quasi-static kite position)
tension_dir   = normalize(kite_pos − sky_anchor_pos)   (changes as sky anchor moves)
forces[sky_anchor_gid] += T_lift × tension_dir
```

At equilibrium, this is identical to the previous model. Off-equilibrium it provides the
missing ~80 N/m geometric spring in all transverse and vertical directions, damping the
post-unwind ringing.

---

## 3. Enhancement: Depower Sequence Control in Dashboard

### Added — `src/visualization.jl`

New `depower_seq_obs` observable (integer 1/2/3) and "Depower Sequence" menu in the
dashboard control panel (after the Field IMU toggle).

| Option | Payout start | k_MPPT stall governor | Latch brake |
|---|---|---|---|
| **Stall → Lift** (current) | 15% of t_total | ramps with `release_frac` from start | fires at ω < 1 rad/s |
| **Lift ∥ Stall** (immediate payout) | t = 0 | ramps with `release_frac` from start | fires at ω < 1 rad/s |
| **Lift → Stall** (stall gov. after lift) | t = 0 | held at 1× until 30% payout, then ramps over remaining 70% | fires at ω < 1 rad/s — unchanged |

The latch brake (`abs(omega_hub) < 1.0 rad/s` → `sys.brake_engaged[]`) is **unmodified in
all three options**. There is no brake interlock.

---

## 4. Open Issue: Simulation Cannot Reproduce Intended Field Depower Sequence

### What the Intended Sequence Is

Release backline early → hub rises, rotor power spills under cos(β)³ reduction → rotor
decelerates naturally → once sufficient elevation is established, progressively ramp up
k_MPPT stall governor → latch brake fires normally when ω < 1 rad/s → generator torque
steps off (brake holds).

### Why the Current Simulation Cannot Do This

The sigmoid payout ramp over `0.70 × t_total` (14 s on a 20 s scenario) is far too slow
relative to the rotor deceleration timescale:

```
At t = 1.5 s on a 20 s scenario (seq 3, delay = 0):
  target_sig   = 1.5 / 14.0        = 0.107
  release_frac = 3×0.107² − 2×0.107³ ≈ 0.032   (3.2% of max payout)
  Backline out = 0.032 × 25 m      ≈ 0.8 m
  Hub rise     ≈ 0.8 × sin(30°)   ≈ 0.4 m over 30 m tether
  cos(β)³ change                  ≈ negligible
```

The rotor stalls from MPPT load alone at t ≈ 1.5 s in all three sequence options because
the hub has barely moved. The stall governor delay has no effect when the stall happens
before 30% payout is reached.

### Critical Field Note

**In the field, the backline can be released from its anchor at any time. Ground station
torque governing options (MPPT level, stall governor, active damping) can all be adjusted
freely and independently. The simulation sigmoid ramp rate does not represent any real
physical constraint — it is purely a code artefact of the current scenario parameterisation.**

The current code therefore prevents simulation of what is actually achievable in the field:
a rapid backline release that establishes meaningful hub elevation well before the stall
torque is applied.

---

## 5. Recommended Next Steps (Handover)

### 5a. Fix Payout Rate for Seq 3 — Priority

The sigmoid payout duration needs to be decoupled from the scenario duration for the
"Lift → Stall" sequence. The backline must reach ≥ 30% of max payout (≥ 7.5 m at 25 m
extended) before the rotor decelerates to ω ≈ 1 rad/s. Given the rotor decelerates in
~1.5–3 s, the initial payout needs to happen in roughly the same window.

Candidate approaches:
- **Fast initial burst**: for seq 3, use a much shorter `depower_duration` (e.g., 2–3 s
  rather than 14 s) so the ramp reaches 30% in the first 1–2 s. Remaining payout can
  continue at normal rate.
- **Snap-to threshold**: at t = 0 in seq 3, immediately set `backline_payout` to
  `max_payout × 0.35` (instant release), then ramp remainder at normal rate. Physically
  justified because the field team can release the backline anchor instantly.
- **Configurable payout time constant**: expose a `payout_ramp_time` slider (default 14 s
  for seq 1/2, shorter for seq 3) decoupled from `t_total`.

### 5b. Define the Stall Gov. Interlock Threshold

Currently hardcoded at `release_frac ≥ 0.30`. Consider whether this should be:
- A configurable slider in the dashboard
- Physics-based: trigger on measured hub elevation angle change rather than payout fraction
  (more robust across different tether lengths and max payouts)

### 5c. Clarify Active Damping Contribution to Early Stall

The Field IMU active damping adds `c_d_active × (ω_gnd − ω_hub)` to the generator torque.
When `ω_hub > ω_gnd` (normal operation, hub leads ground) this actually *reduces* generator
braking — so it should not cause early stall on its own. However this should be verified
by logging `tau_mppt` vs `tau_damp_active` over time in the dashboard or a dedicated test.

### 5d. Consider Separating Brake Enable from IMU Enable

Currently both the latch brake and the Field IMU active damping are gated on `p.kp_elev ≈ 1.0`.
Disabling active damping to test natural deceleration also disables the brake — the two are
conflated via a single parameter. Longer term, a proper `brake_always_enabled` field in
`SystemParams` would allow cleaner sequencing experiments. Three options were identified:

- **Option A**: encode a third state in `kp_elev` (e.g., 2.0 = brake on, IMU off)
- **Option B**: add `brake_always_enabled::Bool` field to `SystemParams`
- **Option C** (selected for now): leave coupling as-is, work around via the k_MPPT stall
  governor delay only (5c above clarifies whether IMU matters)

---

## 6. Files Changed This Session

| File | Change |
|---|---|
| `src/ring_forces.jl` | Backward-rotation blade drag model (lines 68–113); lifting kite geometric stiffness (lines ~261–299) |
| `src/lift_kite.jl` | Added `lift_line_length()` dispatch for all three `LiftDevice` subtypes |
| `src/visualization.jl` | `depower_seq_obs` observable; `seq_delay_frac`, `seq_stall_delayed`, `stall_ramp` logic; "Depower Sequence" menu UI in control panel |

All changes preserve existing test behaviour. Run `julia --project=. test/runtests.jl` to
verify before resuming.
