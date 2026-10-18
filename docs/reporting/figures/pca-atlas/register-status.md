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

Hashes at v4 (three significant figures on the gene bars, 2026-10-18):

    pca-atlas.svg      7ce307f7f34d94cc103f72eca8517508
    pca-atlas.pdf      75007041122f0707c4ee51757e26b054
    pca-atlas.png      f999bf2404f8ad59701f54be80e62c02
    label-ledger.txt   10162700e9754ba4d70c4b0bb10bd90a
    manifest.json      8784bbe5f75a52262b91ecc3829fb0b6

**Delta** v4 (2026-10-18): T4-7. The gene colour bars printed with `:.3g`,
which drops trailing zeros. A tick read `1` or `1.5` against a prose claim
of three significant figures. `sig3()` keeps the zeros: `1.00`, `1.50`,
`2.00`, `10.0`, `16.0`, `22.0`, `0.500`, `0.660`, `0.820`. The tick labels
are ledger strings, so `label-ledger.txt` moves with them. Three runs stay
byte-identical across all five outputs. Script commit `d0e410d`. No signed
value moves.
