# Register status: the levers landscape

**Slug** `pca-landscape`. Status note for the figure rows.
**Date** 2026-10-13.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-001 | The 930-design screen size | Signed |
| NR-005 | The common seed value, 36.109 | Signed |
| NR-006 | The winner value, 27.364 | Signed |
| NR-044 | The PCA projection summary: shares, loadings and the bin rule | Signed (science-validator, `2ad023c`) |

The figure draws no other signed row.

## Row closed

- **NR-044 — the PCA projection summary.** Signed by the science
  validator at `2ad023c` (2026-10-13). Shares PC1 22.434667, PC2
  17.263044, pair total 39.697710. The independent reproduction ran a
  Julia svd over the three committed telemetry files, not the kit
  numpy path. Recipe: z-score the 930 x 10 matrix of x1..x10, one
  SVD, shares from the squared singular values. The plate prints one
  decimal: 22.4 and 17.3.

Boundary carried on the row: the projection reads the raw draw columns
as logged. The evaluator rounding of x4 and x6 does not apply. The
figure maps the draw space.

Top loadings per axis (four decimals, under the abs(v) >= 0.2 rule):

- PC1: n_lines -0.5385, rotor_count -0.5222, blade_scale_top +0.5180,
  target_Lr +0.2517, r_bottom +0.2036.
- PC2: bank_bottom +0.5621, blade_scale_bottom -0.5605, density_profile
  -0.5018, bank_top -0.2444.

## Drawn precision

- The journey values read 36.109 and 27.364. The rows hold the same.
- The screen size reads 930 (NR-001).
- The variance shares read 22.4 and 17.3 per cent (NR-044).
- The colour bar ticks read 30, 33 and 36. They are scale, not
  readouts.
- The field bins at 18 x 18 cells over the 1 to 99 percentile window.
- The axis ticks carry the projection window. They are scale.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/pca-landscape/pca-landscape.py --script-commit 3d36c7a`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the inputs and the output
hashes. Self-check: two consecutive runs stay byte-identical. The run
log sits at `checks.log`.
