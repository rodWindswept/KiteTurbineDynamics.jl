# machine-power-trend: window-end power across the search

Companion to `machine-evolution-strip` (figure map row 9). The strip prints
the window-end power under each of seven machines.

This plate draws the same quantity for every generation, on all three
islands, against the 5 kW floor. The founder ordered it on 2026-10-20.

## Files

- `machine-power-trend.py` builds the plate. It reads the three telemetry
  files and runs no simulation.
- `machine-power-trend.svg` / `.pdf` / `.png` are the outputs. The SVG carries
  a text layer, not glyph paths.
- `label-ledger.txt` holds every drawn string. The script fails when the
  vector text layer and the ledger differ.
- `checks.log` holds the in-script checks, one line each.
- `manifest.json` pins the inputs and the outputs by sha256.
- `captions.md` carries the plain and technical tiers.
- `SPEC.md` carries the claim, the statistic, the population and the four
  checks.

## Run

```
/usr/bin/python3 docs/reporting/figures/machine-power-trend/machine-power-trend.py \
    --script-commit <hex>
```

## Inputs

- `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`
- Data commit `dd3cc6a`. Launch `a76c5e9`. Era `post-95c385d_wind-authority`.
- 310 rows per island and 930 rows in total. Generations 0 to 30 carry ten
  designs each.

## Statistic

- The plate draws the window-end power, `P_end`, of each island running-best
  machine.
- Running-best is the ok row of least recorded fitness with `gen <= G`.
- Ties break to the earliest `(gen, idx)`.
- One point per island per generation gives n = 3 at every generation.
- The plate draws 93 running-best values from 930 recorded designs.
- The line is a step. A new step starts only when a better design lands.
  Nothing interpolates between generations.

## Checks

The script asserts 13 conditions before it draws. Six of them carry the
plate.

- The common seed reads 36.109 and 5.86 kW on all three islands.
- The island 3 running-best fitness matches the seven NR-036 forms.
- The island 3 running-best power matches the seven NR-062 forms.
- The island 3 steps land on generations 0, 6, 10, 18, 22, 25 and 26. This
  is the panel set of the strip, so the plate and the cards describe the
  same machines.
- All 93 values sit at or above the 5 kW floor and below 6.0 kW.
- Island 1 sits on the floor from generation 8 to generation 14. The script
  names this set, so a reader can check it.

## Precision

- Power prints two decimals, the recorded precision of the export.
- Generation 6 prints 5.4 as recorded. These are two significant digits and
  not a defect.
- The axis ticks are calibration. They are not readouts.
- No derived numeral prints. The fall from the seed to the winner is two
  signed forms, not a subtraction.

## Seating

The plate is a candidate and it carries no appendix row.
`check_appendix_pins.py` maps a fixed kit table of nine rows. A tenth row
would read UNMAPPED and fail the gate.

Seating needs three changes in one pass: the draft row, the slug in that
table, and a re-mint. The strip kit does not move for this plate.
