# Room response: the PCA levers first cut (figures seat)

**Date** 2026-10-13. **Seat** figures-images-diagrams.
**Scope** the founder ask of 2026-10-13 (the old campaign PCA charts
redone for the v13 5 kW screen), figure-map rows 20 to 22, and the
kits `pca-landscape` and `pca-atlas`.

## What landed

- Generator commit A: `3d36c7a` (both kits).
- Outputs and records: this commit (B). Five outputs per kit, plus
  the ledger, the checks log and the manifest.
- Figure-map rows 20 and 21 mint and land at R2. Row 22 mints
  proposed (the thrive/fail status view).

## The projection (row want)

- Recipe: z-score the 930 x 10 matrix of x1..x10, one SVD. Shares
  from the squared singular values.
- PC1: 22.434667 per cent. PC2: 17.263044 per cent. Together
  39.697710. The plates print one decimal: 22.4 and 17.3.
- Top loadings, four decimals. PC1: n_lines -0.5385, rotor_count
  -0.5222, blade_scale_top +0.5180. PC2: bank_bottom +0.5621,
  blade_scale_bottom -0.5605, density_profile -0.5018.
- The request: a "PCA projection summary" register row at the recipe
  above. @science-validator

## The readings (as drawn)

- PC1 reads blade scale against unit count: right is larger main
  blades (x9) and wider spacing (x3), left is more lines (x4) and
  more rotors (x6).
- PC2 reads second-rotor and clustering settings: up is a deeper
  second bank (x8), smaller second blades (x10) and rings biased to
  the ground (x5).
- The journeys: one common seed at 36.109. Islands 1 and 2 end
  mid-field. The winner (island 3) ends at the high-PC2 edge, 27.364.

## Checks

- F-LABEL: 46 strings (landscape), 37 (atlas), set-equal to the SVG
  text layers.
- F-REPRO: a second run at the stamp reproduces all ten outputs
  byte-identically (`scratch/fig_pca_repro.log`).
- In-script checks: row counts, status counts, the share values, the
  seed and winner coordinates and fits, and the top loadings, all
  pinned.
- Two vision rounds on the scratch set, plus a pass on the delivered
  set.

## Evidence

- `scratch/fig_pca_probe.py` (the projection probe)
- `scratch/fig_pca_repro.py` and `scratch/fig_pca_repro.log`

## Handoffs

- @science-validator the projection row above. The kit notes carry
  the recipe and the drawn precision.
- @aero-validator optional counter-read on the projection.
- @science-writer the axis names now stand in the kits, so the
  section 3.4 text can mirror them.
- @author rows 20 and 21 read on the map, so the draft can take the
  pointer when the seats clear.
- @user the two charts are attached for the scan.
