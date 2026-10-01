# 11. The blade-count sweep: does the bank derate depend on blade count?

Written 2026-10-01. This file answers the question raised by
`10-precone-sweep.md`: does the measured bank derate hold only for three-bladed
rotors?

## 1. What was run

The same verified AeroDyn v5.0.0 deck as `10-precone-sweep.md`, with the rotor
changed. Two six-blade variants.

| Variant | Blades | Chord | Solidity against the 3-blade rotor |
|---|---|---|---|
| `b6c100` | 6 | 0.500 m | **doubled** |
| `b6c050` | 6 | 0.250 m | **matched** |

`b6c050` is the clean test of blade count. It keeps the total blade area the same
and changes only how many blades share it. `b6c100` is the naive case where
adding blades also adds solidity, and it is reported separately because solidity
moves the whole Cp curve.

Everything else is unchanged: R 4.0 m, zero twist, NACA 4412 at Re 250k, wind
8.0 m/s, `ShftTilt=0`, `SkewMod=2`, `AFAeroMod=2`, precone 0 to 25 deg at
commanded lambda 2 to 8, 5.0 s per case, last timestep taken. 84 more cases,
about 16 minutes.

## 2. The result

Each rotor is compared at **its own** Cp peak, because doubling the solidity
moves the peak.

| Configured rotor | Peak lambda | Cp at peak | Retention at 20° bank | at 25° bank | Exponent fitted at 20° |
|---|---|---|---|---|---|
| 3 blades, chord 0.500 m | 4.0 | 0.2639 | **0.854** | 0.784 | 2.53 |
| 6 blades, chord 0.250 m | 4.0 | 0.2928 | **0.876** | 0.812 | 2.13 |
| 6 blades, chord 0.500 m | 3.0 | 0.2824 | **0.841** | 0.764 | 2.78 |

The two rules, for reference: `cos^2.65(20°) = 0.848` and `cos^3(20°) = 0.830`.

Twenty-degree retention across the whole lambda range, at matched solidity:

| commanded lambda | 2.0 | 3.0 | 4.0 | 5.0 | 6.0 |
|---|---|---|---|---|---|
| 3 blades | 0.904 | 0.893 | 0.854 | 0.748 | 0.331 |
| 6 blades | 0.922 | 0.910 | 0.876 | 0.794 | 0.546 |
| difference | +0.018 | +0.017 | +0.022 | +0.046 | +0.215 |

## 3. What it says

**1. The derate is close to blade-count independent near the peak.** At matched
solidity the three-blade rotor retains 0.854 and the six-blade rotor retains
0.876. That is a difference of 2.2 percentage points. So the 2026-09-30 result is
not a three-blade artefact.

**2. Six blades lose slightly less, not more.** The difference is consistent in
sign at every lambda: more blades, marginally less bank loss. The mechanism is
plausible. More blades at the same solidity means a shorter chord and a higher
aspect ratio, so the coned blade keeps a larger fraction of its effective span
outside the heavily unloaded region.

**3. `cos^2.65` sits inside the measured band and is never optimistic.** The three
measured retentions are 0.854, 0.876 and 0.841 against the 0.848 that the rule
predicts. Two are above it and one is 0.7 per cent below. The fitted exponents are
2.13, 2.53 and 2.78, so the 2.65 exponent sits inside the range for all three
configurations.

**4. The dependence grows away from the peak.** At lambda 6.0 the gap is 21.5
percentage points, not 2.2. That is because Cp is small there and the whole curve
shifts, so the ratio divides a small number by a small number. Do not read the
off-peak rows as a blade-count effect on the mechanism.

## 4. What it does not say

- **Two blade counts is not a curve.** Three and six blades bracket the design
  space, but the expansion rotors in this repo take one blade per line, which is six
  blades at six lines. Nothing below three blades was measured.
- **Solidity is not held constant in `b6c100`.** Its peak lambda is 3.0, not 4.0,
  so its 0.841 is a different operating point on a different curve. It is
  reported for completeness, not as a matched comparison.
- **Still the Daisy MVP rotor, not the campaign winner.** The ratio transfers
  better than the absolute Cp, as in `10-precone-sweep.md`.
- **Cp only.** Thrust has no measured bank derate at any blade count.

## 5. How to reproduce

```
cd scratch/precone_sweep
python3 gen_bladecount_drivers.py   # writes the 6-blade primaries, blade files and drivers
python3 run_bladecount.py           # runs 12 drivers, ~16 min
python3 parse_bladecount.py         # writes results/bladecount.csv and the tables
```

`gen_bladecount_drivers.py` reads the verified deck from
`/mnt/Windswept Energy/_hermes_brain/KNOWLEDGE/aerodyn-v5.0.0` by default. Set
`AERODYN_DECK` to point elsewhere.

The data is in `11-blade-count-sweep.csv`.

## 6. Instrument note

The template blade file is CRLF and its columns are tab-separated with padding
spaces. Rewriting the rows in normalised formatting makes AeroDyn abort with
`Blade1:ReadBladeInputs:ConvertLineToCols:Unable to read numeric data from all
columns in the table on row 1`. The generator changes only the chord token and
leaves every other byte alone.
