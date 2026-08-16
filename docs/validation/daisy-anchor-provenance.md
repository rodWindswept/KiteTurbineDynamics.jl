# Daisy calibration anchor — data provenance (2026-08-15, with Rod)

What we can and cannot use from the Daisy field data, for the small-scale
gate-threshold derivation ((b) in the model-admissibility checklist).

## The two candidate test days

### PRIMARY ANCHOR: 2020-04-29 Mast Mount 6-rotor test
`/home/rod/Documents/kites/Test Data/2020 April 29 Mast Mount 6 rotor test`
- **Lift: KNOWN CONSTANT.** Rope over a mast-mounted pulley to a weighted
  bucket — **12 kg** (scale photo, Rod 2026-08-16). No kite dynamics.
- **Topology:** 12 rings = 10 TRPT rings + GS PTO ring + rotor ring;
  **6-blade rotor**. Hexagonal ring tower (`29APR20-Hexring-Tower`).
- **Controller software: AVAILABLE** — `29APR20-Hexring-Tower/` is the
  Arduino controller source for the VESC (the controller-version
  uncertainty of the other days does not apply).
- **Machine log** (`29APR2020srm rodread-20200429150326.csv`, 1,218 samples
  from 15:03:26): **109-161 W at cadence ~117-130** — sustained steady state.
- **Wind** (merged log `29April all data.csv`, channel Wind_tip_TSR_TSRset):
  **6.0-7.4 m/s**, logged at ~7 Hz.
- **Tension log: 17.9-22.0 kg — DISAGREES with the 12 kg bucket.** Either
  the sensor (unreliable, per Rod) or pulley geometry multiplies the line
  load. The bucket value is the mechanical truth; the logged tension is
  excluded from the comparison.
- Also present: `29 April 2020 all data and analysis.xlsx` (2021, possibly
  the unfinished efficiency calc), photos, video, 1.8 GB MOV.
- **Missing for the model build:** 12-ring geometry (diameters, spacing),
  6-blade rotor geometry (radius, chord, pitch), mast height, line length.

**Geometry from Rod (2026-08-16):**
- mast height ~4.3 m, ~15 cm between the bearing and the mast
- **hex rings: 70 cm diameter; 50 cm spacing** for the PTO + first 8 TRPT
  rings, then grading up (larger rings, wider spacing) toward the rotor ring
- **6 blades, 6 lines, line diameter 2 mm** (Rod, rig builder — the
  notebook's "4 mm" is an unverified transcription of the flying Config 8;
  thesis check pending when the PDF is available)
- ~the same equipment as Oliver Tulloch's last measured TRPT in his PhD data
- **Wind: ONLY the anemometer measured** (4.5-6.9 m/s, synced in the merged
  sheet). The `wind con` channel is a controller estimate, not a sensor.
- **Logged tension = AXIAL TENSION AT THE PTO WHEEL**, not the lift line:
  the 18-22 kg reading includes the chain angle/pulley factors over the
  12 kg bucket — a different quantity, not (only) sensor error.

**Derived from the logged channels** (tip speed + rotor rpm + mast height —
derived, not measured):
- rotor radius ≈ v_tip/ω: 9.43 m/s at 47 rpm → **~1.9-2.0 m** ("whatever Rod
  would normally make" — to be confirmed against build notes if available)
- SRM cadence (117-132) vs rotor rpm (47) → **~2.5:1 PTO gearing**

### 2018-12-13 ("7Line Snap 1.4kW Peak")
`/home/rod/Documents/kites/Test Data/2018 Dec 13 7Line Snap 1.4kW Peak`
- **Machine power: SOLID.** `srm 2011-...csv` (SRM power meter, 2,217 samples,
  11:37:52→13:10:08): max **1400.0 W at 13:09:41**, 50 samples ≥ 1000 W.
- **Wind: ABSENT** from all files that day. Rod: "I don't think we got good
  wind data on the day." The xlsm workbooks are a crashing Windows serial
  logger (VESC serial → Excel macro) — unreliable, channel map unrecorded.
- **Use as:** peak-power record only. Not an operating-point anchor.

### 2019-09-08 ("still needs efficiency calc")
`/home/rod/Documents/kites/Test Data/2019 Sept 8 still needs efficiency calc`
- `test01.csv` (~7 Hz): time, **wind ms-1**, tension g, brake A. Wind is
  logged this day. Session starts 15:59, wind 5.4-7.4 m/s, spin-up at
  15:59:09 (brake 0.02→14 A).
- `SRM20190908160053-Power With Torque.xlsx`: SRM power + torque (machine
  side). The efficiency calc Rod noted has never been finished.
- **Line tension: UNRELIABLE** (Rod, 2026-08-15) — exclude from any
  comparison.
- **Controller software: UNKNOWN version** (`/home/rod/Documents/Arduino`,
  not identifiable). The MPPT/brake behavior in the model is a bracketed
  parameter, not a known constant.
- **Config: 6-line TRPT.** The "7Line" in the 2018 folder title = 6 TRPT
  lines + one CENTRAL line, an experiment to set turbine length and stop
  lift tension crushing the rings. The fixed-length central line loosened
  and entangled (an adjustable central line may help — future design note).
  The model builds Daisy as the 6-line system (matches `daisy_builder.jl`).

## What the anchor can therefore support

**Power vs wind only.** Measured wind (7 Hz, test01.csv) against measured
power/torque (SRM) against the corrected-model Daisy build at those winds.
Excluded: tension, controller-level matching. The model side is ready
(`scripts/calibrate_daisy.jl`); the measured side needs the Sept 8 files
merged and quality-checked first.

Open question: the trustworthiness of the Sept 8 wind channel itself
(anemometer placement and type) — to be confirmed by Rod before any
derivation hangs on it.
