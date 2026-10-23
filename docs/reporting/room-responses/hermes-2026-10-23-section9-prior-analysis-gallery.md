# Room response: section 9 prior-analysis-classes gallery (2026-10-23, hermes)

**Status** ROUTING. **Read at** `bece918` (branch `bank-derate-cos2p65`).

The founder asks for figures of the alternative analysis classes that
ran on prior campaigns, to sit in section 9 beside the instrument
gallery. This note opens the roster row and names the seats.

## 1. The ask

Section 9 carries the instrument gallery (row 31): three frames
from the tools of this repository. The founder wants the section to
classes of analysis the toolchain already ran on earlier campaigns.
`prior-chart-classes.md` answers the founder ask of 2026-10-20 with a
measured census of 37 recurring chart classes.

## 2. What the census says

- 320 image files sit in 16 directories at branch tip. They reduce to
  163 stems. 37 stems recur in three or more campaign sets.
- The campaign of record holds 930 rows and no time series. That fact
  sorts the 37 classes: one already drawn, 14 drawable now, four need
  one extract each, 16 need a dynamics run this campaign does not hold.
- The declarative set (`charts/chart-spec.toml` to
  `charts/generate_charts.jl`) produces six deterministic charts from
  committed inputs: F1 power curve, F2 FoS envelope, F3 energy
  waterfall, F4 static against dynamic, F5 blade scaling, F6 loss
  discriminator.

## 3. The proposed plate

One new row, `prior-analysis-gallery`, sits in section 9 after Figure
12. The plate holds six panels, one per class, drawn from committed
artefacts:

| panel | class | source |
|---|---|---|
| 1 | power curve | `charts/output/F1_power_curve.svg` |
| 2 | FoS envelope | `charts/output/F2_fos_envelope.svg` |
| 3 | blade scaling | `charts/output/F5_blade_scaling.svg` |
| 4 | loss discriminator | `charts/output/F6_loss_discriminator.svg` |
| 5 | BEM benchmark | `figures/report/fig_tulloch_wacker_chart.png` |
| 6 | design-space heatmap | one pitch-depower campaign set in `scripts/results/` |

Each panel prints its campaign, its commit and its void status where a
physics correction voided the data. No panel prints a current claim, so
no panel value needs a new register row. A panel that shows a voided
campaign carries its void label on the plate.

## 4. The seats

- **@figures-images-diagrams:** the plate, one provenance stamp per
  panel, the manifest, two runs that agree byte for byte.
- **@author:** the slot ruling (six panels in one plate against two),
  the caption, the placement in section 9, the reading order.
- **@science-validator:** the value gate. Historical panels carry
  campaign provenance, not register rows. Any current claim on the
  plate needs a signed row first.
- **@aero-validator:** the axis signs on the benchmark panel.

Recorded by @hermes (lead).
