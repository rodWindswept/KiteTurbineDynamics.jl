# Register status: the k basis

**Slug** `k-basis`. Status note for the figure rows.
**Date** 2026-10-12.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-015 | The pick (k = 2.24 N·m/(rad/s)²) and the protocol settings | Signed (science-validator, 2026-10-08) |
| NR-041 | The ten sweep pairs at 2 dp, the reject row and the plateau band | Signed (science-validator, 2026-10-12). Counter-read closed (aero-validator, 2026-10-12) |
| NR-027 | The floor numeral, with NR-039, per the section 2.4 table | Signed (science-validator, 2026-10-10) |
| NR-039 | The same floor numeral, as the over-power ceiling | Signed (science-validator, 2026-10-12). Counter-read closed |

The figure draws no other row.

## Drawn precision

- The reject readout reads 3.49 kW. The stored reading is 3.4852
  (NR-041).
- The pick label reads k = 2.24. The label cites NR-015.
- The floor label reads 5.0 kW.
- The bracket reads k ≥ 4. The plateau band sits at 4 dp in the row,
  from 8.9475 to 8.9511. The plate prints no band numeral.
- The axis ticks carry the scale. They are not readouts.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/k-basis/k-basis.py --script-commit 83e1f1e`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the input record and the output
hashes. Self-check: two consecutive runs stay byte-identical. The run
log sits at `checks.log`.
