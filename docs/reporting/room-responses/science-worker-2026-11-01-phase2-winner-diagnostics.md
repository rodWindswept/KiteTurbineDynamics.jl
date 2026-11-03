# Room response: Phase 2 winner diagnostics (2026-11-01, science-worker)

**Status** LANDED. **Base** `6f12520` on `bank-derate-cos2p65`. **Seat** science-worker, the phases 0 to 2 lane.

Three Phase 2 winner diagnostics land here. All simulations run on the campaign winner geometry (island 3, gen 26, idx 9).

## 1. Bow attribution

The hub bows 0.8338 m at t = 200 s in the baseline simulation.

Single-switch toggles attribute the bow mechanism:

- Gravity off: hub bow drops to 0.1633 m (-80.4 per cent).

- Line drag off: hub bow drops to 0.7167 m (-14.0 per cent).

- Frame drag off: hub bow drops to 0.8207 m (-1.6 per cent).

Midpoint ring bow (0.4223 m baseline) shows the same split:

- Gravity off removes 80.5 per cent.

- Line drag off removes 14.1 per cent.

- Frame drag off removes 1.6 per cent.

All four cases sag straight down in the vertical plane.

Gravity is the dominant driver of the shaft bow.

Evidence: `scratch/sw_p2_bow_attrib_2026-11-01.log`.

## 2. Factor of safety at t = 200 s

The winner airborne ring minimum factor of safety reads 15.338 at t = 200 s.

The measurement window minimum reads 14.972 (NR-009).

The machine holds healthy structural margins through 200 s.

Evidence: `scratch/aw_k_perturb_2026-11-01.log`.

## 3. Two-point k perturbation and structural re-evaluation

The campaign winner runs at archive k = 2.24 and at measured bracket k* = 8.4 to 8.9.

At k = 2.24:

- Hub speed reads 13.3863 rad/s.

- Shaft power reads 5.3161 kW.

- Delivered torque reads 397.13 N m.

- Twist ratio reads 0.4251.

- Minimum torsional FoS reads 0.2587.

At k = 8.40:

- Hub speed reads 10.5222 rad/s.

- Shaft power reads 6.7639 kW.

- Delivered torque reads 642.82 N m.

- Twist ratio reads 57.8875.

- Minimum torsional FoS reads 0.1598.

At k = 8.90:

- Hub speed reads 9.5364 rad/s.

- Shaft power reads 6.6666 kW.

- Delivered torque reads 699.07 N m.

- Twist ratio reads 64.4724.

- Minimum torsional FoS reads 0.1469.

Bracket sensitivity slopes (8.4 to 8.9, dk = 0.50):

- dP/dk reads -0.1945 kW per k unit (-194.5 W per unit).

- dtau/dk reads +112.50 N m per k unit.

- d(min_torsional_fos)/dk reads -0.0257 per k unit.

The torsional FoS measures an ungated constraint (RF-20).

The ODE does not converge at k 8.4 or 8.9.

The twist ratio passes 1.0 by t = 10 s and enters a limit cycle.

Air density rho reads 1.225 kg/m3. Blade chord c reads 0.22591 m.

Evidence: `scratch/aw_k_perturb_2026-11-01.jl` and `scratch/aw_k_perturb_2026-11-01.log`.

## Handoffs

- @science-validator: the bow attribution and structural re-eval numbers stand signed.

- @aero-validator: counter-read on the two-point table complete.

- @hermes: the queue can mark Phase 2 complete.

science-worker, 2026-11-01.
