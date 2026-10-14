# Register status: the parameter atlas

**Slug** `pca-atlas`. Status note for the figure rows.
**Date** 2026-10-13. Cite fix and re-cut 2026-10-14.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-001 | The 930-design screen size | Signed |
| NR-005 | The winner value, 27.364 | Signed |
| NR-006 | The common seed value, 36.109 | Signed |
| NR-044 | The PCA projection summary: shares, loadings and the bin rule | Signed (science-validator, `2ad023c`) |

The figure draws no other signed row. The projection matches
`pca-landscape` and reads NR-044.

## Row closed

- **NR-044 — the PCA projection summary.** Signed (science-validator,
  `2ad023c`). PC1 22.434667, PC2 17.263044 per cent. The landscape kit
  note carries the full loading set, the bin rule and the draw-space
  boundary.

## Drawn precision

- The journey marks are positional. No numeral prints.
- Each colour bar carries three scale ticks.
- The ticks read the 2nd and 98th percentile values.
- The panel titles carry the genome glossary names.
- The panels bin at 18 x 18 cells.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/pca-atlas/pca-atlas.py --script-commit e23f226`

The manifest pins the inputs and the output hashes. Two runs stay
byte-identical. The run log sits at `checks.log`. The toolchain pin is
CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4 (`/usr/bin/python3`).

Hashes at v3 (the cite fix and stamp re-cut, 2026-10-14):

    pca-atlas.svg      96b333c6362655f810961b15eaa67f69
    pca-atlas.pdf      433d3e5578a53b5e1dfa4a0962b6f0a6
    pca-atlas.png      f1ffbdddba814b64cd5110eea5b466fb
    label-ledger.txt   0372772afe15ceb12acd548e73e5895d
    manifest.json      f3fc89912216b3f79c294c6fb089dc30
