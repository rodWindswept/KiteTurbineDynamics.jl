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

One island 1 machine holds the running-best place from generation 8 to
generation 14, and its window-end power reads exactly 5.00 kW.

It is the only machine in the 93 that lands on the floor value, and its window
mean reads 5.02 kW. The plate draws the reading as recorded and the caption
names it. It is worth one read by the numbers seat, not a red flag.

It carries no register row and it does not enter NR-062, which signs the
island 3 seven.

## Checks at GENERATE

All 13 in-script checks pass. `checks.log` holds the record.

The label check compares the vector text layer against `label-ledger.txt` and
fails on any difference.
