# Room response: the section 9 prior-analysis gallery (2026-11-01, figures seat)

**Status** LANDED, draw-ready. **Seat** figures-images-diagrams. **Read at** `ff16a22`.

Row 32 opens at `0187383`.
This pass builds the plate.
The kit sits at `docs/reporting/figures/prior-analysis-gallery/`.

## The plate

Six panels, one per class.
The classes are power curve, FoS envelope, blade scaling, loss discriminator, BEM benchmark and design-space heatmap.
The grid reads two columns by three rows.

Each panel prints a two-line provenance stamp.
The stamp names the class, the campaign, the commit and the void status.
The plate prints 3638 x 3704 px at 531 dpi, or 174.02 x 177.18 mm.
The page proof reads 239.12 mm of 257, with 17.88 mm spare.

## The sources

The first four panels rasterise from `charts/output/F1`, `F2`, `F5` and `F6` at 300 dpi.
Their chart stamp reads `86ca0e5`.
Their file commit reads `d19024e`.
The model reads V10/constCL and the tier reads P.
The BEM benchmark copies `figures/report/fig_tulloch_wacker_chart.png` at `3619ad7`.
The heatmap copies `scripts/results/pitch_depower_campaign/analysis/03_heatmap_brake_time.png` at `719e298`.

## The void label

The pitch-depower V2 campaign carries no surviving run.
The campaign CSV reads 512 rows and 512 disqualified.
The composite score reads -99999.0 on every row.
The critique at `docs/reports/CRITIQUE_pitch_depower_campaigns.md` records zero viable configurations.
Panel six carries a red VOID tag and a red stamp line.
No other panel is void.

## The checks

The script runs 23 checks, 0 fail.
It reads its panel files before a byte draws.
Two runs reproduce the plate, the page proof and the manifest byte for byte.

The stamps measure at or under 1735 px against the 85 mm cell.
No panel prints a current claim.
No register row applies, because every panel carries campaign provenance.
STE reads 0.00 per 100 words on the caption file.

## Next gates

The author seat rules the six-panel shape and takes the caption wording.
The science seat reads the value gate: historical panels carry campaign provenance, not register rows.
The aero seat signs the benchmark axis.
The plate seats at section 9 after the instrument gallery, per the gallery routing note.

---

figures-images-diagrams, 2026-11-01.
