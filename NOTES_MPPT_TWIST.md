# Task Note — MPPT × Twist Angle Analysis

**Created:** April 2026
**Status:** v2 sweep COMPLETE — 28 cases + wind ramp, corrected CT-thrust physics.

## What we're doing

Running a parametric sweep of MPPT gain (`k_mppt`) and hub wind speed (`v_wind`)
to characterise how the TRPT structural twist angle settles at steady state.

**Scripts:**
- `scripts/mppt_twist_sweep.jl` — v1 sweep (24 cases, 6 k_mult × 4 wind speeds)
- `scripts/mppt_twist_sweep_v2.jl` — v2 sweep (28 cases, 7 k_mult × 4 wind speeds + ramp)
- `scripts/mppt_ramp_only.jl` — standalone 7→14 m/s wind ramp (~23 min)
- `scripts/plot_mppt_sweep.py` — generates analysis PNG and markdown report

**Results:** `scripts/results/mppt_twist_sweep/`

## Why

Hypothesis (to be tested with data — no conclusion yet):

> The steady-state twist angle of the TRPT shaft may encode the blade
> incidence operating point.  If twist correlates with Cl/Cd ratio, it
> could serve as a passive or low-bandwidth control signal for bridling
> (adjusting blade angle of attack), without requiring an explicit blade
> pitch sensor.

This is a hunch worth investigating with simulation before any physical
experiment or control-loop design.

## v2 Sweep parameters (current)

| Variable | Values |
|---|---|
| `k_mppt` multiplier | 0.5×, 0.75×, 1.0×, 1.25×, 1.5×, 2.5×, 4.0× nominal (11 N·m·s²/rad²) |
| Hub wind speed | 8, 10, 11, 13 m/s |
| Simulation time | 60 s per combination (+ 5 s spin-up) |
| Record interval | 0.5 s |
| Wind ramp bonus | 7→14 m/s over 150 s at k×1.0 |

**Total:** 28 combinations + 1 ramp. Wall time: ~23 h for sweep + 23 min for ramp.

## How to resume / re-run

```bash
# Full v2 sweep (overnight):
nohup julia --project=. scripts/mppt_twist_sweep_v2.jl \
  > scripts/results/mppt_twist_sweep/sweep_v2.log 2>&1 &

# Ramp only (~23 min):
nohup julia --project=. scripts/mppt_ramp_only.jl \
  > /tmp/ramp_only.log 2>&1 &

# Regenerate plots from existing CSVs:
python3 scripts/plot_mppt_sweep.py
```

## What to look for in the results

1. **Twist vs k_mppt at fixed wind**: Does twist increase monotonically with
   MPPT gain (more braking = more torque = more shaft twist)? If yes, twist
   is a reliable proxy for torque load.

2. **Twist vs wind speed at fixed k_mppt**: Does twist change with wind speed?
   If twist is approximately wind-speed-independent at the same k_mppt, it
   reflects the control setting. If it tracks wind speed strongly, it could
   serve as a wind estimator.

3. **Twist stability**: Does the twist settle cleanly, or does it oscillate?
   The torsional damping fix (principal-value Δα, April 2026) should keep
   it stable — this data will confirm that.

4. **Power vs twist**: Is there an identifiable twist range where P/W is
   maximised? This would be the "sweet spot" for the bridling controller.

## v2 Sweep results (April 2026 — corrected CT-thrust physics)

Results in `scripts/results/mppt_twist_sweep/`. See `twist_sweep_v2_report.md`
for full tables. Key findings:

### Power vs k_mult

| k_mult | v=8 m/s P | v=10 m/s P | v=11 m/s P | v=13 m/s P |
|--------|-----------|------------|------------|------------|
| 0.5× | 2.71 kW | 5.18 kW | 6.82 kW | 11.07 kW |
| 0.75× | 3.13 kW | 5.97 kW | 7.86 kW | 12.71 kW |
| **1.0×** | **3.31 kW** | **6.29 kW** | **8.27 kW** | **13.35 kW** |
| **1.2×** | **3.34 kW** | **6.33 kW** | **8.31 kW** | **13.36 kW** |
| 1.5× | 3.27 kW | 6.17 kW | 8.09 kW | 12.97 kW |
| 2.5× | 2.50 kW | 4.66 kW | 6.07 kW | 9.61 kW |
| 4.0× | 0.78 kW | 1.36 kW | 1.72 kW | 2.62 kW |

- **Optimal k_mult = 1.2×** across all wind speeds (very flat peak between 1.0–1.2×)
- Twist at optimal: 238° (8 m/s) → 308° (13 m/s) — increases with wind speed
- Twist is NOT wind-speed-independent: it tracks wind speed (useful as a wind estimator)
- Twist IS ambiguous as a sole control signal (same twist at under- and over-braked)
- Torsional stability confirmed: twist std ≤ 1.7° in settled region
- τ/T ratio at rated: ~7.8–14.3 across the wind range — increases with wind speed

### Wind ramp (7→14 m/s over 150 s at k×1.0)

The ramp reveals TRPT long mechanical inertia time constant:

| t (s) | v_wind (m/s) | Twist (°) | P (kW) |
|--------|-------------|-----------|--------|
| 25 | 8.2 | 0.7° | 0.00 |
| 65 | 10.0 | 120° | 2.17 |
| 105 | 11.9 | 167° | 2.20 |
| 155 | 14.0 | 200° | 2.25 |

At v=14 m/s end of ramp, P = 2.25 kW vs 13.4 kW steady-state — the TRPT has not
had time to spin up from the v=7 m/s starting condition. This is a key result:
the TRPT cannot track a fast wind ramp and the spin-up time constant is >> 150 s.

**Implication for control**: The controller must account for a long inertial delay
between wind increase and power delivery. Twist-based sensing during ramps would
show undershoot vs the steady-state map.

**Torque wave note**: Oliver Tulloch (prior analysis) identified torque wave
phenomena in TRPT transmissions. The slow ramp spin-up, combined with the flat
power peak between k×1.0–1.2×, is consistent with a resonance interaction between
the elastic shaft and the MPPT generator load. To be investigated.

## Analytical twist prediction (from geometry + force ratios)

For small twist angles, the per-segment equilibrium gives:

    δα ≈ (τ / T) × L_seg / (n × r_s²)

where τ = shaft torque, T = tether tension per line, L_seg = inter-ring spacing,
n = number of lines, r_s = ring radius.

Total stack twist = sum over all segments:

    Δα_total ≈ (τ / T) × L_total / (n × r_s²)

Twist scales as the **torque:tension ratio** × a pure **geometry factor** (L/r² per line).
At large angles the full transcendental rope-chord equation must be used (ring_forces.jl),
but the ratio structure is preserved. Twist is directly predictable from measurable
quantities without running the simulator.

## Future work

- **Validate δα ≈ (τ/T)×geometry** against v2 sweep results
- **Torque wave resonance** — implement Oliver Tulloch's analysis; check whether the
  TRPT shaft natural torsional frequency coincides with rotor harmonic loading
- **TRPT collapse in low-wind** — see NOTES_LIFT_KITE.md §Open Issue; the ramp
  results confirm the simulator does not yet model collapse from over-slow spin-up
- **Design bridling controller** — once τ/T relationship is confirmed against
  physical data, use twist-over-tension as the primary MPPT feedback signal
- **v1 sweep re-run** — v1 (24 cases including k×0.25) not re-run with corrected
  physics; not critical since v2 covers the operationally relevant range
