# Handover — BEM/ODE Gap Investigation 2026-08-11

**Session goal:** Calibrate KTD DE evaluator, find a working 50kW seed genome.

**Outcome:** Seed not found. Root cause identified as a force-level gap between
BEM aero predictions and ODE multibody dynamics. This is not a parameter tuning
problem — the ODE has a systematic reverse torque the BEM model doesn't capture.

## Source changes (committed to desktop, NOT pushed)

| File | Change |
|------|--------|
| `src/objective_evaluator.jl` | Added `tether_diameter` to `ObjectiveConfig` (was hardcoded `0.003`). Updated copy-constructor. Wired `lift_device` into warm-path `settle_to_equilibrium` call (line 334). `build_system_from_v10` now accepts `tether_diameter` kwarg. |
| `src/objective_evaluator_ramp.jl` | Wired `lift_device` into ramp-path `settle_to_equilibrium` call (line 90). |
| `scripts/ramp_calibration_campaign.jl` | Added `lift_device=rotary_lifter_default()` to eval call. |

**Test suite:** 1902/1902 green after all changes.

## Diagnostic scripts (new, in scripts/)

| Script | Purpose |
|--------|---------|
| `_diag_bem_scan.jl` | BEM aero power scan vs ODE power at matching ω |
| `_diag_k_mppt.jl` | Find k_mppt that balances BEM peak aero power |
| `_diag_k_sweep.jl` | Settle + ODE across k=23-29 + cold-start ramp 0→26 |
| `_diag_spinup.jl` | Free-spin, kickstart, and manual ramp strategies |
| `_diag_margin.jl` | Settle with margin (low ω_max, moderate k) + extended 120s |
| `_diag_k_low.jl` | Test k=1-4 range (correctly scaled to BEM peak) |
| `_diag_lift_test.jl` | Verify lift device effect on dashboard path |
| `_diag_path_compare.jl` | Dashboard builder vs evaluator path comparison |

## Key findings

### 1. The V10 reinforced genome is a ~22 kW machine, not 50 kW

The BEM scan shows peak aero power of 22.4 kW at ω=12 rad/s (cp=0.304 on a
5m hub rotor + 2 expansion rotors). The builder's `k_mppt=614.9` (p_base.k_mppt
× λ²) tries to extract 50 kW from a 22 kW rotor — guaranteed overload.

The correct k_mppt for this genome at 11 m/s is ~2.4 (not 614.9).

### 2. The dashboard "55 kW at FoS=2.30" label is not reproducible

Running the dashboard builder path (`build_v10_tight_no_lowest` with lift device,
`settle_to_operational_state`, then 60s ODE) produces 0.7 kW at ω=0.3 rad/s.
This label likely came from a static calculation or an older physics era.

### 3. `settle_to_operational_state` produces transient power, not sustained

The settle initialises rings at a high ω (6-12 rad/s depending on parameters).
The initial ODE frames show 100-140 kW of "power" — but this is the generator
extracting the stored rotational kinetic energy (flywheel discharging into a
brake). Within 30-60s, ω collapses to near-zero and then REVERSES.

### 4. No spin-up strategy works

Tested exhaustively across k=1→28:

| Strategy | Max ω achieved | Sustained? |
|----------|---------------|------------|
| Cold start (k=1) | 0.3 rad/s | No |
| Kickstart (PTO reversal 2s) | 0.2 rad/s | No |
| Manual ramp 0→30 over 60s | 0.5 rad/s | No |
| Settle + moderate k (k=2-4) | Settle at ω=8-12 | Collapses to -0.2 |
| Settle + low k (k=1-4) | Settle at ω=8-12 | Collapses to -0.2 |
| Settle + margin (ω_max=4-8) | Settle at ω_max | Collapses to -0.2 |

Every single test converges to ω≈-0.2 rad/s (reverse rotation, ~2 rpm backward).

### 5. The BEM scan itself is not wrong

The BEM scan accurately predicts P_aero at each ω. The problem is that the ODE
produces less net forward torque than the BEM model predicts. Something in the
multibody dynamics creates a persistent reverse bias that the BEM's `cp_at_tsr`
model doesn't capture.

### 6. Likely reverse torque sources (hypotheses, not tested)

- **Tether aerodynamic drag** (CDt=2.7): acts on the entire tether line, opposing
  motion. The BEM scan only models rotor aero, not tether drag.
- **Rope torsional dynamics**: the polygon chain may have a geometric bias
  toward unwinding under tension.
- **Ring polygon forces**: the interacting ring forces may create a net
  braking torque that scales nonlinearly with ω.
- **Lift kite coupling**: the bearing/sky-anchor force balance may impart a
  reverse moment at the top ring.

## What's eliminated

- ❌ Not a k_mppt selection problem (tested 1→28)
- ❌ Not a tether diameter problem (0.004 configured correctly)
- ❌ Not a missing lift device (wired everywhere)
- ❌ Not a warm vs cold start problem (both fail)
- ❌ Not a ramp rate problem (manual ramp tested)
- ❌ Not a margin problem (settle margin tested 1×→4×)
- ❌ Not a BEM scan accuracy problem (scan verified correct)

## Next session: instrument ODE force components

### Objective
Identify which force term(s) in `multibody_ode!` create the reverse bias that
prevents sustained forward rotation. Candidates to instrument in order:

1. **Isolate tether drag**: zero out CDt and re-test. If power sustains, tether
   drag is the dominant loss mechanism.
2. **Isolate rope damping**: zero c_damp in sub-segments.
3. **Isolate ring polygon forces**: output per-ring torque components during
   the ODE run to see if ring interactions create net braking.
4. **Compare BEM aero torque vs ODE aero torque** at the same ω across multiple
   rings to quantify the gap directly.

### Quick diagnostic command
```bash
# Zero CDt test — if this sustains power, tether drag is the culprit
julia --project=. -e '
using KiteTurbineDynamics
# ...build system, set all sub_seg CDt to 0, run ODE...
'
```

### Also pending
- `scripts/diag_dt_stability_budget.jl` — Rod is investigating dt limits
- Dashboard genome-slider PRD (`docs/plans/dashboard-objective-config-prd.md`)
  — planned but not started
- Daisy calibration (1.5kW) — blocked by same settle/ODE gap

## Git state
```
Modified (not staged):
  M src/objective_evaluator.jl
  M src/objective_evaluator_ramp.jl
  M scripts/ramp_calibration_campaign.jl
  (+ ~8 diagnostic scripts in scripts/_diag_*.jl)

NOT pushed. Laptop review required before push.
Test suite: 1902/1902 green.
```
