# Handoff: Pitch Depower Parameter Sweep Campaign
**Date:** 2026-05-26  
**Status:** Code complete — ready to execute  
**Prepared by:** Claude (Cowork session, continuing from Gemini handover)

---

## 1. What This Is

A full-factorial headless simulation campaign to find the optimal control settings for the **Pitch Depower** scenario in the KiteTurbineDynamics.jl TRPT kite turbine simulator.

The dashboard has a Pitch Depower scenario button with 7 tunable controls. We don't know which combinations produce the smoothest, safest deceleration. This campaign runs all 768 combinations headlessly (no GLMakie), records time-series metrics for each, and generates a comprehensive visual analysis report (heatmaps, parallel coordinates, 3-D surfaces, ranked tables, time-series overlays).

**Primary metrics:**
- **Smoothness** — RMS of d(τ_gen)/dt (N·m/s): lower is better; jerky torque transitions stress the TRPT
- **Tension stability** — minimum tether tension (N): higher is better; slack = structural risk

**Secondary / indicative only:**
- Time for ω_hub to drop below 1 rad/s (brake threshold)
- Peak τ_gen before brake engagement
- Torsional loads (TRPT rings appear limp near sim end — not fully trusted per Rod)

---

## 2. Context: What Was Wrong Before, What Was Fixed

### 2a. Brake trigger bug (fixed in ring_forces.jl + sim_frame.jl)
**Old logic:** `abs(omega_hub) < 1.0 || abs(omega_gnd) < 1.0` — fired when PTO was slow but rotor was still fast (e.g. 5 rad/s). This is wrong: the ground brake must only engage when the *flying rotor* has nearly stopped (< 1 rad/s), otherwise it crushes the TRPT with the full kinetic energy of the spinning rotor.

**Fixed logic:** `abs(omega_hub) < 1.0` only. PTO speed is irrelevant to the trigger.

### 2b. Euler numerical oscillation in locked brake (fixed in visualization.jl + simulation.jl)
**Root cause:** `tanh(20·ω_gnd)` viscous brake model has linearised stiffness ~508,000 rad/s² near zero. Euler stability limit at dt=4e-5 is ~79 rad/s². This is 6,400× beyond stability — causing `ω_gnd` to oscillate numerically, not physically. This was causing the dashboard to show swinging τ_gen numbers even after "PTO Brake = LOCKED".

**Fix:** Export `apply_brake_constraint!(u, sys, N, Nr)` from `ring_forces.jl`. Call it in the Euler loop **between** the angular velocity update and the angle update. This hard-pins `u[6N + Nr + gnd_ri] = 0.0` every step when `sys.brake_engaged[]` is true, bypassing the tanh numerics entirely.

```julia
@views u[6N+Nr+1:6N+2Nr] .+= dt .* du[6N+Nr+1:6N+2Nr]
apply_brake_constraint!(u, sys, N, Nr)   # ← new — pins ω_gnd = 0 when latched
@views u[6N+1:6N+Nr]     .+= dt .* u[6N+Nr+1:6N+2Nr]
```

This fix is in **both** `src/visualization.jl` (dashboard) and `src/simulation.jl` (canonical loop).

### 2c. Test coverage gap (fixed in test/test_bearing_alignment.jl)
New testset `"brake Euler velocity constraint"` — 200-step integration test that verifies `apply_brake_constraint!` actually pins `ω_gnd = 0` every step. Expects 569 + 200 = **769 total tests** (pending run).

---

## 3. Files Changed in This Session

| File | What changed |
|------|-------------|
| `src/ring_forces.jl` | Brake trigger: removed `\|\| abs(omega_gnd) < 1.0`; added exported `apply_brake_constraint!` function |
| `src/sim_frame.jl` | Brake trigger: same fix as ring_forces.jl |
| `src/visualization.jl` | Euler loop: added `apply_brake_constraint!` call between velocity and angle updates |
| `src/simulation.jl` | Added `apply_brake_constraint!` to `run_canonical_sim!`; added `override_params`, `DepowerResult` struct, `run_pitch_depower!` function |
| `src/KiteTurbineDynamics.jl` | Exports: added `run_canonical_sim!`, `DepowerResult`, `run_pitch_depower!`, `override_params` |
| `test/test_bearing_alignment.jl` | Moved `_modified_params` to file scope; flipped Test 4; added `"brake Euler velocity constraint"` testset |
| `scripts/pitch_depower_campaign.jl` | **NEW** — full-factorial sweep script |
| `scripts/pitch_depower_analysis.py` | **NEW** — analysis and chart generation |

---

## 4. New Functions Reference

### `override_params(base::SystemParams; kwargs...) → SystemParams`
Pure utility — returns a copy of `base` with named fields replaced. Exported from module. Use this wherever the dashboard used its private `_modified_params`.

```julia
p2 = override_params(p; lifter_elevation = deg2rad(90.0), backline_payout = 12.5)
```

### `run_pitch_depower!(u, sys, p_base, wind_fn, n_steps, dt; kwargs...) → DepowerResult`
Headless depower runner. Exactly mirrors the dashboard's `_rerun!` loop for `:pitch_depower` scenario.

**Keyword arguments:**

| Kwarg | Default | Meaning |
|-------|---------|---------|
| `lift_device` | `nothing` | Lift kite device (pass `rotary_lifter_default()` — required for correct physics) |
| `use_active_winch` | `false` | Proportional payout rate ∝ T_min/150 N |
| `use_mppt_stall` | `false` | Ramp k_mppt from 1× to 9× through depower |
| `use_field_imu` | `false` | Field IMU torsional damping (kp_elev = 1.0) |
| `payout_base` | `15.0` | Max backline payout at full depower (m) |
| `damping_mode` | `0.0` | Generator control (0=MPPT, 1=Active Damping, 2=LPF) |
| `save_every` | auto | Save frame every this many steps (default ≈ 0.02 s) |

**Caller responsibilities:**
1. Pass a pre-settled `u` from `settle_to_operational_state()`
2. Reset `sys.brake_engaged[] = false` before calling
3. `u` is mutated in-place — pass `copy(u_settled)` if you need the original

### `DepowerResult` struct
Lightweight time-series output. Fields:
```julia
times, omega_hub, omega_gnd, tau_gen, T_max, n_slack,
backline_payout, k_mppt_scale,   # all Vector{Float64} (or Int for n_slack)
brake_time   # Float64 — NaN if brake never engaged
```

---

## 5. Campaign: Parameter Grid

**768 total combinations** across 7 axes:

| Axis | Levels | Values |
|------|--------|--------|
| `duration_s` | 4 | 10, 20, 30, 45 s |
| `lifter_elev_deg` | 4 | 70°, 80°, 90°, 100° (≈ 1.22–1.75 rad) |
| `field_imu` | 2 | false, true |
| `damping_mode` | 3 | 0 (MPPT), 1 (Active Damping), 2 (LPF Speed) |
| `active_winch` | 2 | false, true |
| `payout_base_m` | 2 | 15 m, 25 m |
| `mppt_stall` | 2 | false, true |

**Rod's prior hypotheses** (to be confirmed or refuted by the data):
- 30 s duration smoother than 10 s
- Lifter elevation ~100° (1.7 rad) better than 70° (1.2 rad)
- Field IMU on is better than off
- Progressively slower k_mppt ramp (mppt_stall) is better
- Active winch T_min feedback helps tension stability

---

## 6. How to Execute

### Step 1: Run the test suite (verify all 769 pass)
```bash
julia --project=. test/runtests.jl
```
Expected: 769 tests, 0 failures. If you get 569, the new `"brake Euler velocity constraint"` testset is missing — check that `test/test_bearing_alignment.jl` has the full content.

### Step 2: Smoke test (12 combos, ~5–10 min)
```bash
julia --project=. --threads=auto scripts/pitch_depower_campaign.jl --test
```
This runs 12 representative configs and writes to `scripts/results/pitch_depower_campaign/`. Verify:
- No Julia errors / panics
- `campaign_metrics.csv` has 12 rows
- A few `timeseries_NNNN.csv` files exist
- `brake_engaged` column has at least some `1`s (brake was reached for some configs)

If any runs fail (NaN rows in CSV), read the `@warn` messages in stdout. Common causes:
- `settle_to_operational_state` diverges for extreme lifter elevations → try reducing elevation range
- Numerical instability → check dt (5-line: 4e-5, 8-line: 1e-5)

### Step 3: Full overnight campaign
```bash
julia --project=. --threads=auto scripts/pitch_depower_campaign.jl
```
**Estimated time:** 3–5 hours on 8 cores (30 s sims dominate; 45 s sims take ~50% longer).  
Progress logs every completed run with ETA.  
Results accumulate in `scripts/results/pitch_depower_campaign/`.

### Step 4: Analysis (runs in ~2 min after CSVs exist)
```bash
/usr/bin/python3 scripts/pitch_depower_analysis.py
```
Required Python packages (all pre-installed in system Python):
```
numpy, pandas, matplotlib, scipy
```
If any are missing: `pip install numpy pandas matplotlib --break-system-packages`

Output goes to `scripts/results/pitch_depower_campaign/analysis/`. Key files:
- `analysis_report.pdf` — full combined report
- `11_sensitivity_bar.png` — single most important chart: which axis matters most
- `05_ranked_configs.png` — top-20 and bottom-20 configurations
- `04_parallel_coordinates.png` — all 768 runs overlaid, coloured by composite rank

---

## 7. Physics Notes for the Executing Agent

### Why `lifter_elevation` matters for depower
The pitch depower works by paying out the backline (the constraint tether from the sky anchor to the ground), allowing the sky anchor to rise under the lifter kite's pull. A higher lifter elevation angle (more vertical) gives a larger vertical component of lift force, tilting the TRPT shaft from its 30° operating angle toward vertical more aggressively. This reduces the apparent rotor disk area projected into the wind, spilling power.

The `lifter_elevation` is the angle of the lift kite's tether from horizontal. At 70° (default) the pull is mostly vertical already. At 100° it's slightly past vertical (pulling slightly backward) — may destabilise the sky anchor. This is one of the things the campaign will reveal.

### Why `damping_mode` matters
`β_rate_max` in `SystemParams` is a repurposed field used by `multibody_ode!` as the generator control mode:
- 0 = pure MPPT (τ_gen = k·ω²), plus the "PTO co-braking" proportional ring velocity damp during depower
- 1 = Active Damping Mode 1 (modulates τ_gen to damp Δω between hub and PTO)
- 2 = LPF Speed Mode (low-pass filtered ω drives τ_gen, reduces response to torsional oscillations)

### Why TRPT torsional loads are not the primary metric
Rod noted the rings "appear to hang limp near sim end" — the torsional stiffness (GJ) of the Dyneema rope stack is very low, and near the end of a depower sequence (low tension, payout extended) the rings lose their geometric rigidity. The torsional load calculations in this regime are not fully trusted. Tension and rotational metrics are the reliable primary signals.

### Euler stability and dt
The simulation uses explicit forward Euler at dt = 4e-5 s (5-line) or 1e-5 s (8-line v5). Both are stable for normal operating conditions. During depower:
- The brake constraint pins ω_gnd = 0 by post-step override (no stiffness issue)
- The MPPT stall governor multiplies k_mppt up to 9× — this increases the effective torsional damping, which is stabilising for Euler
- If you see NaN / Inf in the state vector, the sim has blown up — reduce dt or check the lifter elevation is physically reachable

---

## 8. Output File Structure

After a complete run:

```
scripts/results/pitch_depower_campaign/
├── campaign_metrics.csv              ← 768-row summary (one row per run)
├── timeseries_0001.csv               ← per-run frame data (run 1)
├── timeseries_0002.csv
│   ... (768 files)
└── analysis/
    ├── 01_heatmaps_smoothness.png    ← τ_gen RMS jerk, all 21 parameter pairs
    ├── 02_heatmaps_tension.png       ← min tension, all 21 parameter pairs
    ├── 03_heatmap_brake_time.png     ← time to brake, duration × lifter elev
    ├── 04_parallel_coordinates.png   ← all runs overlaid, colour by rank
    ├── 05_ranked_configs.png         ← top-20 / bottom-20 bar chart
    ├── 06_3d_surface_duration_elev.png
    ├── 07_3d_surface_payout_dmode.png
    ├── 08_timeseries_best5.png       ← ω, τ, T, payout time series
    ├── 09_timeseries_worst5.png
    ├── 10_composite_waterfall.png    ← sorted composite scores
    ├── 11_sensitivity_bar.png        ← η² — which axis matters most
    └── analysis_report.pdf           ← all 11 figures combined
```

`campaign_metrics.csv` columns:
```
run_id, duration_s, lifter_elev_deg, field_imu, damping_mode,
active_winch, payout_base_m, mppt_stall,
d_tau_gen_rms,    ← PRIMARY: τ_gen smoothness (lower = better)
d_omega_rms,      ← PRIMARY: ω_hub smoothness
T_min,            ← PRIMARY: tension safety (higher = better)
T_mean, T_std, slack_events,
brake_time, brake_engaged,
omega_hub_final, omega_gnd_final,
time_to_omega1, max_payout_reached,
peak_tau_gen, min_tension_before_brake,
smoothness_raw, tension_raw, composite_score
```

---

## 9. Known Issues / Watch For

1. **Test 4 bound in `test_bearing_alignment.jl`** — the `abs(accel_no_premature) < 10000.0` bound is intentionally loose (conservative upper bound, not a tight specification). Once you have run the test suite and seen the actual value, tighten it to ~2× the observed value and commit.

2. **`lifter_elev_deg = 100°`** — near or above vertical. The sky anchor geometry may produce near-zero or negative cyan-line tension. If many runs at 100° fail (NaN), drop this level to 95° and re-run those rows.

3. **`damping_mode = 2` (LPF Speed)** — this mode's implementation in `ring_forces.jl` should be verified before trusting its results. If all mode-2 runs produce identical outputs to mode-0, the mode switch isn't being applied correctly.

4. **`settle_to_operational_state` convergence** — if lifter elevation is changed, the back-line geometry changes and the operational pre-settle may not find a valid equilibrium at very high elevation angles. Watch for `@warn` messages from `run_one` in the campaign log.

5. **Thread safety** — `build_kite_turbine_system` allocates a fresh `sys` per run, so each thread has its own `sys.brake_engaged[]` ref. This is correct. Do **not** share `sys` objects between threads.

---

## 10. What to Report Back to Rod

After the campaign completes, the key questions to answer from the data:

1. **Which single parameter explains the most variance in composite score?** (sensitivity bar, chart 11)
2. **Does duration 30s beat 10s?** (heatmap row for duration_s vs d_tau_gen_rms)
3. **Does lifter_elev 100° beat 70°?** (same heatmap)
4. **Is Field IMU on always better, or only in combination with certain damping modes?**
5. **Active winch + MPPT stall together: is the combination better than either alone?** (2-way interaction heatmap)
6. **What are the top-3 recommended configurations?** (ranked table, chart 5)
7. **Do the best configs all achieve brake engagement?** (brake_time column)

---

*This handoff written 2026-05-26. All code is committed to the workspace. Run `test/runtests.jl` first to confirm 769 green tests, then proceed with the campaign.*
