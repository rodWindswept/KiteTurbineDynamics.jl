# Captions: the prior-analysis gallery

**Slug** `prior-analysis-gallery`. **Status** CANDIDATE. **Date** 2026-11-01.
**Seat** figures-images-diagrams. The caption wording rests with the author seat.

Section 9, after the instrument gallery (roster row 31).
The plate holds six panels, one per chart class that an earlier campaign ran.
Each panel prints its campaign, its commit and its void status.
The builder emits the figure label.
No caption below names the figure number.

The value rule: no panel prints a current claim.
Every value on the plate belongs to the tool or the campaign that printed it at that commit.
No register row signs a panel value.

## Plain caption

Six chart classes that the toolchain ran on earlier campaigns, each drawn from its own committed file.
Every panel prints its campaign, its commit and its void status.
These panels are historic analyses, not the latest results, and no panel carries a value of this report.

## Technical caption

The plate draws one example of each class.
The classes are power curve, FoS envelope, blade scaling, loss discriminator, BEM benchmark and design-space heatmap.

The first four panels come from the declarative chart set `charts/generate_charts.jl` at commit `86ca0e5`.
The model reads V10/constCL and the tier reads P.
The benchmark panel draws the Tulloch/Wacker torsional design chart at commit `3619ad7`.
The heatmap panel draws the pitch-depower V2 campaign at commit `719e298`.

Panel 2 carries a λ = 0.69 callout on the green envelope.
The value belongs to the V10/constCL chart at `86ca0e5`.

That campaign is void.
All 512 runs carry a disqualification flag, so the panel carries a void label.
The panel shows the class of analysis, not a result.

Every value on the plate belongs to the tool that printed it at that commit.
No panel supports a current claim.
No register row signs a panel value.

## Provenance line

Sources: `charts/output/F1_power_curve.svg`, `F2_fos_envelope.svg`, `F5_blade_scaling.svg` and `F6_loss_discriminator.svg` at commit `d19024e`.
Chart stamp: `86ca0e5`.
Benchmark source: `figures/report/fig_tulloch_wacker_chart.png` at commit `3619ad7`.
Heatmap source: `scripts/results/pitch_depower_campaign/analysis/03_heatmap_brake_time.png` at commit `719e298`.
Full record: the figure-provenance appendix.
