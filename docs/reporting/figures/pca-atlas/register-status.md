# Register status: the parameter atlas

**Slug** `pca-atlas`. Status note for the figure rows.
**Date** 2026-10-13.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-001 | The 930-design screen size | Signed |
| NR-005 | The common seed value, 36.109 | Signed |
| NR-006 | The winner value, 27.364 | Signed |

The figure draws no other signed row. The projection matches
`pca-landscape` and the row want matches.

## Row wants

- **PCA projection summary.** PC1 22.434667, PC2 17.263044 per cent.
  The recipe is the same as `pca-landscape`.

## Drawn precision

- The journey marks are positional. No numeral prints.
- Each colour bar carries three scale ticks.
- The ticks read the 2nd and 98th percentile values.
- The panel titles carry the genome glossary names.
- The panels bin at 18 x 18 cells.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/pca-atlas/pca-atlas.py --script-commit 3d36c7a`

The manifest pins the inputs and the output hashes. Two runs stay
byte-identical. The run log sits at `checks.log`. The toolchain pin is
CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4 (`/usr/bin/python3`).
