# Register status: the levers landscape

**Slug** `pca-landscape`. Status note for the figure rows.
**Date** 2026-10-13. Cite fix and re-cut 2026-10-14.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-001 | The 930-design screen size | Signed |
| NR-005 | The winner value, 27.364 | Signed |
| NR-006 | The common seed value, 36.109 | Signed |
| NR-044 | The PCA projection summary: shares, loadings and the bin rule | Signed (science-validator, `2ad023c`) |
| NR-045 | The island generation counts: 31 generations per island, 10 rows each | Signed (science-validator, `6255268`) |

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
- **NR-045 — the island generation counts.** Signed by the science
  validator at `6255268` (2026-10-14). 31 generations per island
  (indices 0 to 30) and 10 rows per generation. 310 rows per island
  and 930 in total (NR-001). The journey inset count keeps.

## Drawn precision

- The journey values read 36.109 and 27.364. The rows hold the same.
- The screen size reads 930 (NR-001).
- The journey inset reads 31 generations each (NR-045).
- The variance shares read 22.4 and 17.3 per cent (NR-044).
- The colour bar ticks read 30, 33 and 36. They are scale, not
  readouts.
- The field bins at 18 x 18 cells over the 1 to 99 percentile window.
- The axis ticks carry the projection window. They are scale.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/pca-landscape/pca-landscape.py --script-commit d0e410d`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the inputs and the output
hashes. Self-check: two consecutive runs stay byte-identical. The run
log sits at `checks.log`.

Hashes at v4 (the wrapped loading line and kg-equivalent labels, 2026-10-18):

    pca-landscape.svg  1d4433856620ace8b29bb0f187075343962df572123641ce987b514796cece66
    pca-landscape.pdf  79c145ed9a88c577b48796414815a33547c113bfa4ca734e256ae37fabbaf9a8
    pca-landscape.png  295315950f82d737c06132100ec88f667a0899d6103d0ede778c09ab4f2213b8
    label-ledger.txt   5fb0426068bcbc2893b510c2273a1aad5096c1b4f35f30b64fce7fdfc145e748
    manifest.json      dfe994e2be7899cbead4866b2896eec5c82cff7f6f2be413290fa732652f945b

**Delta** v4 (2026-10-18): T4-6 and T4-8. T4-6: the PC1 panel line `wider
spacing (x3), ground ring (x2)` ran past the axes and lost its closing
parenthesis at the page margin. The panel now draws one row per line, with
the continuation indented, so the text stays inside the box. T4-8: the
legend, the subtitle and the two journey values read the search objective
in `kg`. They now read `kg-equivalent`, the unit the prose uses. Three runs
stay byte-identical across all five outputs. Script commit `d0e410d`. No
drawn value moves.

**Delta** v5 (2026-10-18): pin correction. The v4 hash block above
carried the pre-T4 values while the T4 outputs landed, so the five
hashes now match the committed bytes. The reproduce command reads the
T4 script commit `d0e410d`. No re-cut. No value moves.
