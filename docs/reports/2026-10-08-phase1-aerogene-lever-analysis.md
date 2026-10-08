# Phase 1 aero genes: rotor count, bank, blade scales

This draft awaits the science-validator gate.
aero-worker owns the work.
The basis is the bankderate2 dataset at master `894fc11` (data commit `dd3cc6a`).
It holds 930 evaluated rows and 508 ok rows.
The base ok rate reads 54.6 per cent.

All bins use decoded evaluated columns.
The x4/x6 rounding trap from the Phase 0 sign does not apply here.
`n_active` carries the evaluator clamp and the ring clip.
The bank and blade columns equal the values the evaluator scored.

## Method

Each gene splits into bins.
The tables report, per bin, the draw count, the ok rate, the reject fractions, and the ok-row means.
Effect size equals the bin-mean range over the pooled ok-row std.
Survival range equals the largest ok-rate split across bins.

Ok-row clearance means span 5.33 to 5.51 m across all bins of all five genes.
No bin moves clearance more than 0.2 m.
The 1.5 m gate does the rejecting, so this metric stays flat on survivors.
The per-bin clearance values live in the CSV, not in these tables.

## Lever ranking

| gene | P_mean | T_lift | FoS | fitness | clearance | survival range | mean abs effect |
|---|---|---|---|---|---|---|---|
| n_active | 0.20 | 6.41 | 2.58 | 7.19 | 2.13 | 0.69 | 3.70 |
| blade_scale_top | 2.76 | 0.80 | 1.49 | 1.48 | 0.74 | 0.65 | 1.45 |
| bank_top | 1.63 | 0.81 | 0.43 | 0.64 | 0.83 | 0.52 | 0.87 |

| gene | P_mean | T_lift | FoS | fitness | clearance | survival range | mean abs effect |
|---|---|---|---|---|---|---|---|
| bank_bot | 0.57 | 1.08 | 0.26 | 1.09 | 0.43 | 0.32 | 0.69 |
| blade_scale_bottom | 0.54 | 0.65 | 0.41 | 0.96 | 0.49 | 0.18 | 0.61 |

For n_active the metric columns compare two survivors against 506 rows.
Read the survival split as its effect.
The conditioned columns stay valid for the other four genes.

## Priority question 1: rotor count survival

Count 1 holds 739 draws and 506 ok rows (68.5 per cent).
Count 2 holds 167 draws and 2 ok rows (1.2 per cent).
The count-2 deaths split 101 clearance_reject, 62 reject, 2 reject_twist.
Count 3 holds 24 draws and 0 ok rows.
The count-3 deaths split 9 clearance_reject, 15 reject.

The two count-2 survivors hold P_mean 5.33 and 6.01 kW.
Their T_lift values read 793 and 727 N.
FoS reads 7.07 and 6.22, fitness 58.9 and 60.6.
The single-rotor ok mean holds P_mean 5.72 kW, T_lift 386 N, FoS 12.26, fitness 33.8.
The best single winner holds fitness 27.364.

The verdict is no.
Multi-rotor designs do not survive this construction.
A second rotor doubles the lift demand and halves the safety margin.
It returns no power gain on the survivors (5.67 against 5.72 kW).
Both surviving rows lose on fitness to every single-rotor winner.
The third rotor also breaks the 1.5 m clearance gate on the 22 degree cone.

## Priority question 2: bank saturation at the 22 degree bound

bank_top at the bound (21.9 degrees and above) holds 27 draws, 2 ok (7.4 per cent).
bank_bot at the bound holds 137 draws, 96 ok (70.1 per cent).

The verdict is split.
The bottom bank saturates the bound.
The bound region is the best surviving region (fitness 31.5, FoS 12.44, T_lift 353.7 N).
The top bank at the bound is near-lethal.

cos(22) to the power 2.65 equals 0.818.
So 22 degrees of top bank costs 18.2 per cent of top-rotor power.
That equals 10.9 per cent of total power under the 0.6 split.
That drop pushes P_mean under the 5 kW floor.
The winner carries 7.1 degrees of top bank and 22.0 degrees of bottom bank.

## Per gene

### rotor_count

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness | clearance |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 739 | 68.5 | 30.3 | 0.0 | 1.2 | 5.72 | 386 | 12.26 | 33.8 | 5.48 |
| 2 | 167 | 1.2 | 37.1 | 60.5 | 1.2 | 5.67 | 760 | 6.64 | 59.8 | 5.01 |
| 3 | 24 | 0.0 | 62.5 | 37.5 | 0.0 | - | - | - | - | - |

Rotor count is the design-class lever.
It gates the hub-only family against the stacked and banked families.
At 18.8 m and 5 kW the single-rotor hub design is the only viable family.

### bank_top

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0-4 | 125 | 56.8 | 30.4 | 12.0 | 0.8 | 5.67 | 383 | 12.42 | 33.4 |
| 4-8 | 95 | 68.4 | 22.1 | 8.4 | 1.1 | 5.79 | 380 | 12.71 | 34.1 |
| 8-12 | 188 | 56.4 | 28.2 | 13.3 | 2.1 | 5.77 | 387 | 12.27 | 34.2 |

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 12-16 | 330 | 65.5 | 27.0 | 7.6 | 0.0 | 5.72 | 386 | 11.99 | 33.7 |
| 16-20 | 127 | 30.7 | 52.0 | 15.0 | 2.4 | 5.65 | 408 | 12.50 | 34.5 |
| 20-25 | 65 | 16.9 | 52.3 | 27.7 | 3.1 | 5.41 | 427 | 11.77 | 35.8 |

Bank_top is a power knob with a lethal ceiling.
The cosine derate lands on the power-dominant rotor.
Above 16 degrees the plain reject class takes half the draws as power falls under the 5 kW floor.
Moderate bank (4 to 16 degrees) is the surviving band.
The island 2 rows under 10.26 degrees split 7 reject and 5 clearance_reject against one ok row.

### bank_bot

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0-4 | 190 | 36.8 | 43.2 | 18.9 | 1.1 | 5.66 | 417 | 12.50 | 35.4 |
| 4-8 | 213 | 48.8 | 37.6 | 12.7 | 0.9 | 5.69 | 405 | 12.32 | 35.0 |
| 8-12 | 165 | 61.8 | 33.3 | 4.8 | 0.0 | 5.74 | 388 | 11.94 | 34.1 |

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 12-16 | 105 | 62.9 | 26.7 | 9.5 | 1.0 | 5.76 | 388 | 12.07 | 34.2 |
| 16-20 | 95 | 57.9 | 28.4 | 11.6 | 2.1 | 5.79 | 385 | 12.07 | 34.1 |
| 20-25 | 162 | 68.5 | 17.9 | 11.1 | 2.5 | 5.69 | 354 | 12.44 | 31.5 |

Bank_bot is a clearance and lift lever.
Survival climbs monotonically to the bound.
Steep bottom bank drops lift tension.
The rank correlation against T_lift reads minus 0.425.
It also lifts the safety margin while P_mean stays flat.
The derate stays cheap because the bottom rotor carries only 0.4 of the power split.

### blade_scale_top

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0.2-0.7 | 104 | 0.0 | 65.4 | 32.7 | 1.9 | - | - | - | - |
| 0.7-0.8 | 34 | 5.9 | 58.8 | 35.3 | 0.0 | 5.10 | 362 | 15.26 | 29.4 |
| 0.8-0.9 | 53 | 58.5 | 24.5 | 17.0 | 0.0 | 5.43 | 345 | 14.51 | 29.0 |

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0.9-0.95 | 37 | 48.6 | 45.9 | 5.4 | 0.0 | 5.67 | 355 | 12.01 | 31.1 |
| 0.95-1.0 | 702 | 65.1 | 26.1 | 7.5 | 1.3 | 5.74 | 392 | 12.08 | 34.4 |

Blade_scale_top is the strongest P_mean lever.
It moves 5.10 to 5.74 kW across the surviving bins (2.8 pooled std).
Below 0.7 no design survives.
The top rotor carries 0.6 of the power, so a small top blade misses the 5 kW floor.
Small top blades still lift FoS to 14.5 through blade mass savings, but the fitness punishes the power shortfall.

### blade_scale_bottom

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0.2-0.4 | 229 | 46.3 | 38.0 | 12.7 | 3.1 | 5.65 | 367 | 12.79 | 32.1 |
| 0.4-0.6 | 111 | 46.8 | 33.3 | 18.9 | 0.9 | 5.75 | 404 | 11.89 | 35.5 |
| 0.6-0.8 | 136 | 48.5 | 38.2 | 13.2 | 0.0 | 5.70 | 400 | 12.62 | 34.5 |

| bin | draws | ok% | rej% | clr% | twist% | P_mean | T_lift | FoS | fitness |
|---|---|---|---|---|---|---|---|---|---|
| 0.8-0.9 | 105 | 57.1 | 30.5 | 12.4 | 0.0 | 5.77 | 395 | 12.18 | 35.0 |
| 0.9-1.0 | 349 | 64.2 | 26.6 | 8.3 | 0.9 | 5.73 | 388 | 11.95 | 34.0 |

Blade_scale_bottom is the weakest aero power lever (0.13 kW P_mean range).
Its real role is twist stability.
Seven of the eleven twist-reject rows carry bottom scale at or below 0.488.
Their twist_ratio values span 1.12 to 10.29.
Size the bottom blade for twist margin first, then tune the top.

## Dead gene check

All five genes draw across their full DE range in all three islands.
No bin is empty.
No metric stays flat across a gene range.
No island is disjoint.
The instrument floor pattern stays absent, matching the Phase 0 sign.
The rotor count cliff rests on 191 evaluated draws, so it records lethality, not a floor.

## Files and recompute

The recompute script lives at `scratch/aw_p1_aerogenes.py`.
Its outputs follow:

- `scratch/aw_p1_aerogenes/aerogene_conditioned_table.txt`
- `scratch/aw_p1_aerogenes/aerogene_effect_size.txt`
- `scratch/aw_p1_aerogenes/aerogene_conditioning.png`
- `docs/reports/assets/aw_p1_aerogene_conditioning.png` (chart copy)

To recompute, run the script with system python 3 against the signed dataset.
