# Register status: the machine power trend

**Slug** `machine-power-trend`. Status note for the candidate row.
**Date** 2026-10-20. **Script commit** `7c680d8`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-005 | The campaign winner 27.364 at generation 26. The sub-line | Signed |
| NR-006 | The common seed 36.109. The sub-line | Signed |
| NR-062 | The window-end power pair. The seven island 3 forms, four of them printed | Signed (science-validator, 2026-10-18) |

The figure draws no other row. The plate prints four power forms (5.86, 5.4,
5.89, 5.31) and two objective forms (36.109, 27.364).

Every other numeral is an axis tick or the 5 kW floor label. The floor is a
configuration knob and not a reading.

## Drawn precision

- Power prints two decimals, as recorded. Generation 6 prints 5.4.
- The objective forms print three decimals, as signed.
- No derived numeral prints: no difference, no mean and no slope.

## Open reading for the numbers seat

The island 1 running-best window-end power reads exactly 5.00 kW from
generation 8 to generation 14.

Seven generations of different machines landing on one value is worth a read.
The plate draws the value as recorded and the caption names it.

It carries no register row and it does not enter NR-062, which signs the
island 3 seven.

## Checks at GENERATE

All 13 in-script checks pass. `checks.log` holds the record.

The label check compares the vector text layer against `label-ledger.txt` and
fails on any difference.
