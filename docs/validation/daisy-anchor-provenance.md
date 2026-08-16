# Daisy calibration anchor — data provenance (2026-08-15, with Rod)

What we can and cannot use from the Daisy field data, for the small-scale
gate-threshold derivation ((b) in the model-admissibility checklist).

## The two candidate test days

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
