# Tulloch PhD — recorded Daisy Kite prototype configurations (posterity)

**Source:** `Tulloch, PhD Thesis Final Submission.pdf`, Strathclyde folder on
the Windswept drive (`03_Engineering/Academic Uni & Research/Strathclyde/`).
Extracted 2026-08-20 (Rod) to preserve the recorded configurations that
anchor the small-scale mass/geometry calibration.

**Campaign scale:** 45 tests over 41 days, May 2017 → May 2020, **120 hours**
of test data on **9 prototype configurations**. The 1.6 kW day (and the
"<2 kg flying weight" record, AWEC 2019) was the **3-blade** rigid rotor.

## Table 3.1 — the nine configurations

| Config | Wing | Rotors | TRPT version | TRPT length (m) | Test hours |
|---|---|---|---|---|---|
| 1 | Soft | 1 | 1 | 6.7 | 27.5 |
| 2 | Soft | 1 | 2 | 7.7 | 12.5 |
| 3 | Soft | 1 | 3 | 6.7 | 9.0 |
| 4 | Soft | 2 | 1 | 6.7 | 21.0 |
| 5 | Soft | 2 | 2 | 7.7 | 5.5 |
| 6 | Soft | 3 | 2 | 7.7 | 18.5 |
| 7 | Rigid | 1 | 3 | 6.7 | 8.0 |
| 8 | Rigid | 1 | 4 | **10.3** | 13.5 |
| 9 | Rigid (6-wing) | 1 | 5 | **9.5** | 1.5 |

**Config 8** = the optimised rigid rotor (ring 1.52 m, tips 1.22/2.22 m,
solidity 7.5%, NACA 4412 — the 70/30 anchor). **Config 9** = the 6-wing
TRPT-5 machine, i.e. the 2020-04-29 mast rig lineage. The April-29 rig is
thesis-documented as TRPT-5 (hex rings, central tether removed).

## Geometry records (rigid rotor)

- **Ring radius 1.52 m** ("the ring, for all prototypes, has a radius of
  1.52 m", encased in a dacron sleeve; carbon fibre ring of straight joined
  rods + 6 radial tethers to the centre).
- **Rigid rotor tips: inner 1.22 m, outer 2.22 m** → outboard 0.70 m,
  inboard 0.30 m = **70/30 ring-anchored split**; swept annulus π(2.22² −
  1.22²) = **10.8 m²** (blog record: **11.2 m²**).
- **Soft rotor inner tip 1.16 m** (soft kites).
- **Solidity 7.5%**; blade pitch 3°; inner tip recommendation r/R = 0.37
  (prototype rigid started at 0.55).
- **Blade profile NACA 4412** (chosen for small-HAWT use).
- **Blade construction (Rod):** 420 g foam core + plastic shrink-wrap skin +
  2 carbon spar tubes (~9 mm OD / 0.5 mm wall) + custom 3D-printed fuselage
  (thesis Fig 3.6). 6-blade rotor uses the same wings/fuselages as the
  3-blade.
- **Flying weight < 2 kg** (3-blade: 3 × 420 g + TRPT + single-skin lifter),
  **> 1.5 kW at 10 m/s** (AWEC 2019).

## Power records

| Record | Value | Source |
|---|---|---|
| 2019-12-24 blog | **624 W / 146 rpm / 6-blade / 11.2 m² / ζ = 3.77** | Dec 2019 blog |
| 2018-12-13 | peak **1400 W** (50 samples ≥ 1000 W) | SRM log |
| 2020-04-29 mast | 109–161 W at cadence ~117–130, 6.0–7.4 m/s | SRM + merged wind |
| System Cp | **0.15** (config 8), optimised **0.18**; F9: model 234 W vs 223±79 W | thesis + F9 |

## Anchor implications (cross-checks)

- **Mass**: 3-blade <2 kg at >1.5 kW → **φ ≈ 1.3 kg/kW**. 5 kW ≈ 4–7 kg
  (φ ≈ 0.8–1.4); consistent with the fixed model's φ ≈ 1 kg/kW.
- **Length**: flown TRPT lengths **6.7–10.3 m**; the optimised machine was
  **10.3 m**. A 5 kW device should scale UP from ~10 m (NOT the 21.2 m legacy
  campaign default).
- **Swept area**: annulus 10.8 m² ≈ measured 11.2 m² — validates the
  ring-anchored geometry.
- **30 m** was the lift-kite distance from the ground station, NOT the
  turbine config length.

## Open items

- Component masses per ring/tether (for the mass exponent) — the blade mass
  is recorded (420 g); the ring/tether masses are in the thesis's dynamic
  model parameters (image-rendered tables) — pull when needed.
- The 624 W (6-blade, 146 rpm) vs ">1.5 kW @ 10 m/s" (3-blade) operating
  points need wind to reconcile Cp — the blog point implies Cp_sys ≈ 0.125
  at ~9 m/s; the AWEC claim implies ≈ 0.22 at 10 m/s. Both consistent with
  the 0.15–0.18 plateau band.
