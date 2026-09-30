# 10. The precone (bank) sweep: what a banked rotor actually delivers

Written 2026-09-30. This file answers the open question left in
`09-aerodyn-geometry-knobs.md`: which AeroDyn knob carries our bank angle, and
how much power does a banked rotor really lose?

## 1. Why the sweep exists

Three models disagree about the topmost rotor when it carries banked blades.
The spread between them is 5.6 times, so a measurement must decide.

| Model | Where it lives | What it retains at 20 deg bank |
|---|---|---|
| the disc (cp/ct) model | `src/ring_forces.jl` | 1.000. It ignores the bank |
| the banked expansion model | `src/expansion_rotor.jl` | **0.147** |
| the cos^3(beta) rule | `09-aerodyn-geometry-knobs.md`, Tulloch Eq. (4.1) | **0.830** |

The 0.147 figure is the one measured on 2026-09-30. The campaign winner fell
from 5.46 kW to 0.80 kW when the banked model took the topmost ring
(`docs/plans/2026-09-30-top-ring-brake-findings.md`).

AeroDyn gives a fourth opinion, from a different code and a different
formulation. That is the value of this sweep.

## 2. What was run

The verified AeroDyn v5.0.0 driver deck. The rotor is the Daisy MVP.

| Item | Value |
|---|---|
| tool | `AeroDyn_driver` v5.0.0, Apache-2.0, sha256 `787e23f4...97cd246` |
| rotor | Daisy MVP, 3 blades, R 4.000 m (HubRad 1.0 plus a 3.0 m blade) |
| blade | uniform chord 0.500 m, zero twist, NACA 4412, Re 250k |
| swept area | 50.26548 m^2, as reported by `RtArea` |
| wake model | BEMT, `WakeMod=1` |
| skew model | `SkewMod=2`, Pitt and Peters. The skewed inflow is modelled, not imposed |
| unsteady aero | `AFAeroMod=2`, `UAMod=3` |
| wind | 8.0 m/s, `PLExp=0` |
| shaft | `ShftTilt=0`. Pure bank, no elevation |
| budget | 84 cases, 5.0 s each at dT=2.314858e-3 s, 2 160 steps. Last timestep taken |
| convergence | worst change in Cp over the final 200 steps is 3.4e-3 |
| axis | 6 precone angles 0 to 25 deg at yaw 0, and 6 yaw angles 0 to 25 deg at precone 0 |
| lambda | 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, commanded through `RotSpd` |

Run time was 45 s per driver file, 12 files, 84 cases, about 9 minutes total.

## 3. The result

Cp at commanded lambda 4.0, which is the measured peak. The ratio column is
Cp(angle) divided by Cp(0) at the same lambda.

| Bank angle | Cp | ratio | Yaw Cp | yaw ratio | cos^3(beta) |
|---|---|---|---|---|---|
| 0 | 0.2639 | 1.000 | 0.2639 | 1.000 | 1.000 |
| 5 | 0.2597 | 0.984 | 0.2649 | 1.004 | 0.989 |
| 10 | 0.2518 | 0.954 | 0.2659 | 1.008 | 0.955 |
| 15 | 0.2404 | 0.911 | 0.2667 | 1.011 | 0.901 |
| 20 | **0.2254** | **0.854** | 0.2665 | 1.010 | **0.830** |
| 25 | 0.2070 | 0.784 | 0.2649 | 1.004 | 0.744 |

The bank penalty at 20 deg, across the whole lambda range:

| commanded lambda | 2.0 | 3.0 | 4.0 | 5.0 | 6.0 |
|---|---|---|---|---|---|
| Cp(20 deg) / Cp(0) | 0.904 | 0.893 | 0.854 | 0.748 | 0.331 |

Above lambda 6.0 Cp is negative on this twist-free blade, so ratios there divide
a small number by a small number and mean little.

## 4. What the measurement says

**1. A 20 deg bank costs about 15 per cent of Cp at the peak.** It retains
0.854. That is the headline.

**2. The repo's existing `cos^2.65` rule fits bank better than `cos^3` does.**
This is the useful surprise. The same exponent the repo already applies for
elevation matches the measured bank ratio almost exactly.

| Bank angle | measured | `cos^2.65` | `cos^3` | fitted exponent |
|---|---|---|---|---|
| 5 | 0.984 | 0.990 | 0.989 | 4.19 |
| 10 | 0.954 | 0.960 | 0.955 | 3.05 |
| 15 | 0.911 | 0.912 | 0.901 | 2.69 |
| 20 | **0.854** | **0.848** | 0.830 | 2.53 |
| 25 | 0.784 | 0.771 | 0.744 | 2.47 |

At 20 deg the measured retention is 0.854. `cos^2.65` predicts 0.848, a match to
0.7 per cent. `cos^3` predicts 0.830, which is 2.8 per cent more pessimistic. The
fitted exponent falls from about 3.0 at 10 deg to 2.5 at 25 deg, so 2.65 sits in
the middle of the measured band. The 5 deg row is noisy, because its exponent
divides a small number by a small number.

This answers open question 2 of `09-aerodyn-geometry-knobs.md` from a
measurement rather than from a BEM sweep. Keep `cos^2.65`.

**3. Yaw is not a substitute for bank.** At the peak, yawing the rotor costs
almost nothing and marginally increases Cp (0.010 above unity at 20 deg). Yaw
redistributes the local angle of attack, and near the peak that helps the
advancing side about as much as it hurts the retreating side. Bank cones the
blade out of its own plane and loses projected radius, so it loses power. The
two mechanisms are different, and the repo must not model bank as yaw.

**4. The banked expansion model is wrong by 5.8 times at the peak.** It retains
0.147 where the measurement retains 0.854. The ratio 0.854 / 0.147 is 5.81. So
the 0.80 kW reading is a brake, and AeroDyn confirms it from an independent
formulation.

**5. The disc model is mildly optimistic.** It retains 1.000 where the
measurement retains 0.854. It ignores the bank entirely.

## 5. What the measurement does not say

- **This is the Daisy MVP, not the campaign winner.** R 4.0 m, uniform 0.5 m
  chord, no twist. The absolute Cp of 0.264 is not the winner's Cp. The ratio
  transfers to the bank question more reliably than the absolute value does,
  because the ratio is set by the geometry change rather than the blade quality.
  Treat the ratio as evidence and the absolute Cp as a property of this rotor.
- **AeroDyn cones the blade; our blade is ring-anchored.** AeroDyn's `Precone`
  tilts a rigid straight blade out of the rotor plane. Our banked blade roots at
  the ring, runs its outer span down-shaft and its inner span up-shaft. Section
  3 of `09-aerodyn-geometry-knobs.md` gives three reasons to doubt the identity.
  They still stand. This sweep measures a coned rotor, which is the closest
  AeroDyn analogue to our bank.
- **The peak is bracketed, not resolved.** Seven lambda points place the peak at
  or near 4.0. A finer sweep would sharpen it.
- **`ShftTilt` is zero.** This isolates the bank. Our rotor also sits at about
  20 deg elevation, and that derate is separate.
- **The penalty deepens sharply above the peak.** At lambda 6.0 a 20 deg bank
  retains only 0.331. A banked rotor that falls off its peak loses much more, so
  the constant is not the whole story.

## 6. How to reproduce

```
cd scratch/precone_sweep
python3 gen_precone_drivers.py     # writes deck/ad_pc*.inp and deck/ad_yw*.inp
python3 run_sweep.py               # runs the driver on all 12 files, ~9 min
python3 parse_sweep.py             # writes results/sweep.csv
/usr/bin/python3 plot_sweep.py     # writes results/precone_sweep.png
```

`gen_precone_drivers.py` reads the verified deck from
`/mnt/Windswept Energy/_hermes_brain/KNOWLEDGE/aerodyn-v5.0.0` by default. Set
`AERODYN_DECK` to point elsewhere. The driver binary is at `~/bin/aerodyn_driver`.

The data is in `10-precone-sweep.csv`. The figure is
`figures/precone-sweep-Cp-vs-bank.png`.

## 7. Instrument notes

**Column indices do not carry between AeroDyn versions.** The `aerodyn-bem`
skill records `RtAeroCp=18`, `RtAeroCt=20`, `RtTSR=31`. This v5.0.0 output puts
them at 23, 25 and 27. The parser here looks every column up by name. An index
from the wrong generation returns a plausible number from the wrong channel and
raises no error, so never index.

**AeroDyn's `RtTSR` uses an angle-dependent reference length.** It rises with
yaw, by `1/cos(yaw)`: the commanded lambda 6.0 case reports `RtTSR` 6.00 at yaw
0, 6.20 at 10 deg, 6.40 at 20 deg. It falls with precone in a way that is not
the precone angle alone: commanded lambda 6.0 reports `RtTSR` 6.00 at precone 0
and 5.80 at precone 20 deg. Aligning rows on `RtTSR` would therefore compare
different rotor speeds. The rows here align on the **commanded** lambda, which
holds the rotor speed and the wind fixed while the angle changes. That is the
control the comparison needs. The precone radius convention is open and is not
needed for this result.
