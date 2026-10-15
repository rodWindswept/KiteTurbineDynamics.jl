# machine-corner-grid: the four corner machines

The render set for figure map row 23. Four panels, one for each corner
of the drawn PC1-PC2 field. Each panel draws the nearest feasible
design to its [1,99] window corner (NR-051).

## Files

- `extract-corner-grid.csv` carries the render set, one row per corner.
- A row holds the corner, the identity tag, and the source telemetry
  fields verbatim (the `island` to `x10` block), plus the two
  projection columns.
- `extract-corner-grid.log` holds the mint record and the certificate.

## Provenance

- The dataset is `v13_5kw_masslift_len18.8_rotorcount_bankderate2`.
  Data commit `dd3cc6a`. Launch `a76c5e9`. Era
  `post-95c385d_wind-authority`.
- The projection repeats the certified pca-landscape kit (NR-044).
  Every anchor re-verifies before a row writes.
- NR-051 signs the four picks and the display forms. The objective
  prints at 3 dp.
- The mint is `scratch/fig_cg_extract.py`. The checker is
  `scratch/fig_cg_extract_check.py` (54 checks, 0 fail).

## State

The generator lands (`a4b4057`). Four panels, one per corner, at one
shared scale. All in-script checks pass, and the three-location
F-REPRO walk reads byte-identical across all five outputs. Next: the
counter-reads (aero F-CITE and F-VALUE, the science register read),
then the visual pass by Rod.

## Delivered files

- `machine-corner-grid.png` / `.svg` / `.pdf` carry the plate.
- `manifest.json` pins the extract, the knobs and the output hashes.
- `checks.log` holds the GENERATE record.
