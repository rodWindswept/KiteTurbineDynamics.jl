# SPEC: the parameter atlas. One panel per gene for the v13 5 kW screen.

**Slug** `pca-atlas`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. **Reader-facing layer** @author: the captions and
the slotting.

**Contracts** the reporting framework. The numbers register. The
genome glossary.

## Why this exists

The founder ask of 2026-10-13 routes the old campaign PCA charts to
the v13 5 kW screen. This plate is the second of the pair: the same
PC1-PC2 projection, coloured once per gene. Ten panels, one per slot
(x1..x10). The old atlas carried fourteen variables. The reduced set
of ten is the "smaller genome" reading.

## What already exists. Extend, do not rebuild.

- The same three island telemetry files as `pca-landscape` (data
  commit `dd3cc6a`, run `a76c5e9`). The same projection, pinned by the
  same checks: z-score, one SVD, PC1 22.434667 per cent, PC2 17.263044
  per cent.

- The old framework: one shared projection, one panel per variable,
  the same journeys overlaid. `scripts/render_v10_atlas.py`.

- The journeys, the seed star and the winner diamond come from the
  feasible rows, exactly as in `pca-landscape`.

## Inputs. The record contract.

- Three committed CSV files, one per island. The panels read x1..x10
  over all 930 designs. Status and generation gate the journey lines
  alone.

- The panel colour is the cell mean of that gene over all rows.

## The drawing

### Panels and axes

- Ten panels in two rows of five, one per gene slot. Every panel
  carries the same PC1-PC2 window as `pca-landscape`.

- The horizontal and vertical axes agree across the pair. The origin
  carries a soft crosshair in every panel.

- Each panel carries one horizontal colour bar. The ticks print the
  2nd and 98th percentile values of that gene at three significant
  figures. They are scale, not readouts.

- The journey lines, the star and the diamond overlay every panel.

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `gene_panels` | x1..x10 | one cell-mean panel per slot, 18 x 18 | row counts, status counts |
| `journeys` | gen, status, fitness | best-so-far path per island | seed and winner coordinates |
| `seed_star` | the common seed row | star at the seed point | fit 36.109 |
| `winner_diamond` | the winner row | diamond at the winner point | fit 27.364 |
| `colour_bars` | each gene | percentile ticks, three significant figures | presence |
| `source_stamp` | — | data commit, run, era, rows, script commit | presence |

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| 930 designs | NR-001 | projection note | the screen size |
| start 36.109 | NR-005, NR-006 | the journey marks | positional |
| winner 27.364 | NR-006 | the journey marks | positional |
| the ten panel titles | the genome glossary | labels | gene names |
| colour bar ticks | each gene | scale | not readouts |

## Checks. External, never self-graded.

- **F-CITE.** The source stamp carries the data commit, the run, the
  era, the rows and the script commit.

- **F-REPRO.** A fresh run reproduces the figure bit-identically. Two
  runs stay byte-identical across all five outputs.

- **F-LABEL.** Every vector string equals a ledger entry. The ledger
  carries 37 strings.

- **F-VALUE.** The shared projection carries the row want below.
  @aero-validator owns this check, at the sign-off commit.

## Caption plan (dual)

- Plain sentence: one map of the search space, coloured ten times.
  Each panel shows where one gene sits high or low across the search.

- Technical caption: the shared projection, the ten gene panels and
  the journey marks. @author writes both captions.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print scale
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pins and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing. The counter-read by the seats and the visual
  pass by Rod come first. The projection row gates F-VALUE.

- **R3** the final pass at the sign-off commit.

## Open inputs

1. The PCA projection summary row: shared with `pca-landscape`. The
   recipe is pinned in the kit note.

2. The reading-order slot (author seat) and the fold order.

## Non-goals

No smoothed curves. No per-panel outlier trimming beyond the colour
range. No re-derived outcome values.

## Deltas

- v1 (2026-10-13): R2 lands with the GENERATE pass.
