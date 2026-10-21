# Lever set: the candidate value list

**Slug** `lever-set`

**Status** CANDIDATE, UNSIGNED. **Date** 2026-10-21. **Owner**
@figures-images-diagrams.

**Contract** `prior-chart-classes.md` §5 (the four classes and their
seats). The numbers register (the firewall). The four-check gate
(`figure-generation-notes.md`).

## 1. What this file is

The four classes of row 8 need values before a plate can draw. This file
lists each value, its source cell, and a display form to sign or
replace. **It signs nothing.** No value here prints until the numbers
seat puts a register row beside it.

Every value below reads from the item-5 extract at `6c51f5c`, which
reads the telemetry at data commit `dd3cc6a`, run `a76c5e9`. The extract
is byte-stable from that commit to this kit, so the cells and the file
agree.

## 2. Slot 1: the sensitivity rank bar

Source `extract-objective-vs-gene.csv`, 10 rows. `spearman_rho` reads
the rank correlation of the gene against the objective over the 508 ok
rows. `delta_med_kg` reads the top-bin median minus the bottom-bin
median.

| gene | slot | rho (4 dp) | proposed form | delta kg (3 dp) | proposed form | bins |
|---|---|---|---|---|---|---|
| `target_Lr` | x3 | -0.5832 | -0.58 | -3.892 | -3.89 | q1 to q5 |
| `blade_scale_top` | x9 | +0.5042 | +0.50 | +2.759 | +2.76 | q1 to q3 |
| `bank_bottom` | x8 | -0.4033 | -0.40 | -2.896 | -2.90 | q1 to q5 |
| `r_bottom` | x2 | -0.2764 | -0.28 | -1.801 | -1.80 | q1 to q5 |
| `blade_scale_bottom` | x10 | +0.1656 | +0.17 | +1.356 | +1.36 | q1 to q4 |
| `bank_top` | x7 | +0.1252 | +0.13 | +0.669 | +0.67 | q1 to q5 |
| `rotor_count` | x6 | +0.1085 | +0.11 | +26.592 | +26.59 | 1 to 2 |
| `r_hub` | x1 | +0.0736 | +0.07 | +1.071 | +1.07 | q1 to q5 |
| `density_profile` | x5 | +0.0662 | +0.07 | -0.212 | -0.21 | q1 to q5 |
| `n_lines` | x4 | -0.0287 | -0.03 | +22.540 | +22.54 | 3 to 9 |

**One finding the plate shows and the register does not carry yet:**
`rotor_count` ranks seventh of ten on rho at +0.11, and **first** on the
bin shift at +26.59 kg. `n_lines` ranks tenth on rho at -0.03, and
**second** on the shift at +22.54 kg. A rank bar drawn on rho alone puts
the two largest shifts at the bottom of the chart. **The plate draws both columns, or it
misleads.** Two of the ten rows read rho near zero with a shift over 20
kg, because the integer genes step in large jumps.

The bins differ per gene. `blade_scale_top` reads three bins and
`blade_scale_bottom` four, because heavy ties collapse a bin set. The
caption must state the bin count of each gene it names, or the shift is
not comparable.

## 3. Slot 2: the disqualification census

Source `extract-failure-rates-by-value.csv`, 13 rows. Population 930:
508 ok, 301 reject, 110 clearance_reject, 11 reject_twist.

**`n_lines`.** Below 5 lines the ok share holds near two thirds. At 6 it
falls to 4.8 percent.

| n_lines | n | ok | reject | clearance | twist | ok share |
|---|---|---|---|---|---|---|
| 3 | 477 | 319 | 122 | 32 | 4 | 66.9 |
| 4 | 209 | 144 | 51 | 13 | 1 | 68.9 |
| 5 | 78 | 34 | 29 | 15 | 0 | 43.6 |
| 6 | 62 | 3 | 42 | 13 | 4 | 4.8 |
| 7 | 53 | 6 | 27 | 19 | 1 | 11.3 |
| 8 | 17 | 1 | 14 | 2 | 0 | 5.9 |
| 9 | 34 | 1 | 16 | 16 | 1 | 2.9 |

**`rotor_count`.** One rotor holds. Two rotors read 1.3 percent. Three
read zero.

| rotor_count | n | ok | reject | clearance | twist | ok share |
|---|---|---|---|---|---|---|
| 1 | 739 | 506 | 224 | 0 | 9 | 68.5 |
| 2 | 157 | 2 | 62 | 91 | 2 | 1.3 |
| 3 | 34 | 0 | 15 | 19 | 0 | 0.0 |

`n_active` repeats the rotor story at 68.5, 1.2 and 0.0, because it
reads the same decode. **The plate draws one of the two and names the
other in the caption.** Two panels of the same numbers read as two
findings.

**One fact the table carries and no caption may soften:** every
`clearance_reject` at `rotor_count` 1 is zero. All 110 clearance
rejections sit at two rotors or more. The second rotor is what breaks
ground clearance in this population.

## 4. Slot 3: the charge waterfall

Source `extract-penalty-contributions.csv`, 508 ok rows, with
`extract-penalty-summary.csv`, 4 rows. The charges recompute through the
NR-046 forms at recorded precision.

| channel | fired | sum kg | share % | largest in | median kg | max kg |
|---|---|---|---|---|---|---|
| over-power | 507 of 508 | 1462.3155 | 69.31 | 453 | 2.8125 | 8.8445 |
| utilisation | 508 of 508 | 506.3577 | 24.00 | 46 | 0.7190 | 12.3611 |
| twist | 508 of 508 | 141.1349 | 6.69 | 9 | 0.1579 | 8.2856 |
| total | 508 of 508 | 2109.8081 | 100.00 | - | 3.9569 | 15.1428 |

**The reading the plate must not lose:** utilisation holds the higher
single charge, 12.36 against 8.84, and over-power holds 69.31 percent of
the total. The caption states the sum and the dominance count. It does
not rank the channels by their maximum, because that rank inverts the
finding.

## 5. Slot 4: the response surface

Source `extract-objective-by-gene-bins.csv`, 46 rows: the objective
conditioned on one gene at a time, five quantile bins for continuous
genes, decoder values for integer genes. 508 ok rows.

The plate draws the median per bin, not the mean: the mean sits above
the median in **42 of the 46 bins**, so the two forms disagree almost
everywhere. The bin edges print on the axis, and the count per bin
prints in the box.

**A defect this file must flag before the SPEC:** the bins are uneven,
and their counts run from **1 row to 506**. One bin holds a single
design, so its median is that design. The plate takes a floor of n >= 5
and greys or drops the bins below it, or the surface draws a cell with
no population behind it. That rule belongs in the SPEC, not in the
caption.

## 6. What this file does not do

It signs nothing and it draws nothing. It moves no register row, no
cited count, no draft byte, no plate hash and no manifest pin. The
numbers seat may replace any display form above; the plate follows the
signed form, not this one.

## 7. Sign-off: the numbers seat (2026-10-21, science-validator)

Every value in this list checks against the raw telemetry and is signed
at `numbers-register.md` NR-074 to NR-077. The checker
`scratch/sv_lever_set_sign.py` recomputes all of it from the three island
telemetry files; it reads 77 checks, 0 fail. The plate follows the signed
forms there, not the candidate forms above.

Four candidate forms are replaced.

1. **`delta kg` and `sum kg` read kg-equivalent.** The shift is a fitness
   difference and the charges are penalty values, not masses. The unit
   note of 2026-10-13 binds both (NR-036, NR-039). The over-power sum
   reads 1462.3155 kg-equivalent, not 1462.3155 kg.

2. **The shift column prints its populations.** Every row carries its bin
   pair and both counts. `rotor_count`'s top bin holds **2** designs and
   `n_lines`' holds **1**; they are the two largest shifts (+26.59 and
   +22.54). A row under five designs at either end draws thin and takes
   no order in any caption. The signed sentence is "the two largest bin
   shifts sit on two designs and one", never "the largest levers".

3. **"42 of the 46 bins" reads 41 of the 42 bins holding five or more
   designs.** Three of the four exceptions are the single- and
   two-design bins, where mean and median are equal by construction. The
   fourth is `target_Lr` q4, 102 designs, where the mean sits below.

4. **"The second rotor is what breaks ground clearance" leaves.** The
   measured form is containment: every clearance rejection in this
   population sits at two rotors or more, and none sits at one. The
   population does not isolate the rotor count, because the two-rotor
   designs differ in the other nine genes too.

One correction for the figures seat, not a value: `prior-chart-classes.md`
§5 calls slot 1 "a population read over 930 designs". It reads the **508
ok designs**. The extract's own recipe line says so, and so does NR-074.
