# SPEC: the levers landscape. The PCA redo for the v13 5 kW campaign.

**Slug** `pca-landscape`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline. The section 3.4 prose supplies the reader account.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. **Reader-facing layer** @author: the captions and
the slotting.

**Contracts** the reporting framework (SPEC, GENERATE, CHECK, the
rounds, the dual captions). The numbers register (the firewall). The
genome glossary (the gene meanings).

## Why this exists

Rod asked for the old campaign PCA charts redone for the latest
campaign (2026-10-13). The old set comes from the V10 campaign (June
2026). `scripts/render_v10_landscape.py` is the flagship there. This
plate carries the layout framework at the reduced scale: named axes
with direction reads, one reading inset per axis, and the journeys.
The section 3.4 text carries the reading. The plate carries the shape.

## What already exists. Extend, do not rebuild.

- The three island telemetry files (data commit `dd3cc6a`, run
  `a76c5e9`, era `post-95c385d_wind-authority`). 310 rows per island,
  930 rows total. Columns x1..x10 sit beside fitness, status and the
  outcomes.

- The old framework: two axes with direction reads, the reading
  insets, the journey inset, the objective field with the island paths.
  The redo keeps the framework and drops the 3D view and the tight
  variants.

- The projection: a z-score of the 930 x 10 gene matrix, one SVD. PC1
  carries 22.434667 per cent of the variance. PC2 carries 17.263044
  per cent. The plate prints one decimal. The shares read NR-044
  (signed 2026-10-13).

## Inputs. The record contract.

- Three committed CSV files, one per island. The plate reads x1..x10,
  fitness, status and generation. Nothing else draws.

- The colour field draws feasible rows only (status ok). The sentinel
  rows draw nothing. Blank cells carry no feasible design.

- The journey lines draw the best-so-far path per island, one step per
  generation, from the feasible rows.

## The drawing

### Panel and axes

- One main panel. The horizontal axis carries PC1. The vertical axis
  carries PC2. The window is the 1 to 99 percentile rectangle of the
  full screen.

- Colour is the cell mean of the search objective in kg-equivalent. The
  field bins at 18 by 18 cells. Bright reads lower. The colour bar
  carries three scale ticks and no readout.

- Three journey lines, one per island. One common seed star. End
  markers: a circle for islands 1 and 2, a diamond for the winner.

- Two reading insets carry the direction reads. One journey inset
  carries the screen size and the two signed values.

- Three dashed contours sit on the objective field. They carry no
  labels.

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `objective_field` | fitness, feasible rows | 18 x 18 binned cell means | row counts, status counts |
| `contours` | the same field | three dashed levels, no labels | presence |
| `journeys` | gen, status, fitness | best-so-far path per island | seed and winner coordinates |
| `seed_star` | the common seed row | star at the seed point | fit 36.109 |
| `winner_diamond` | the winner row | diamond at the winner point | fit 27.364 |
| `reading_insets` | the loadings | direction reads per axis | top loadings |
| `source_stamp` | — | data commit, run, era, rows, script commit | presence |

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| 930 designs | NR-001 | subtitle, journey inset | the screen size |
| 31 generations each | NR-045 | journey inset | signed (science-validator, `6255268`) |
| start 36.109 | NR-006 | map label, journey inset | the common seed |
| winner 27.364 | NR-005 | map label, journey inset | island 3 |
| variance shares 22.4 / 17.3 | NR-044 | the two inset titles | signed (science-validator, `2ad023c`) |
| colour bar ticks 30 / 33 / 36 | the colour norm | scale | not readouts |
| axis ticks | the projection window | scale | not readouts |

The display forms pin here once, for labels, captions and prose alike.

## Checks. External, never self-graded.

- **F-CITE, citation binding.** Every annotation cites a signed row.
  The source stamp carries the data commit, the run, the era, the
  rows and the script commit. A missing stamp or citation is a reject.

- **F-REPRO, deterministic reproduction.** A fresh run on the same
  inputs reproduces the figure bit-identically. Two runs stay
  byte-identical across all five outputs. Script and toolchain stay
  pinned.

- **F-LABEL, ledger equality.** The check enumerates the text layer of
  the emitted vector. Every string equals a ledger entry. The ledger
  carries 46 strings.

- **F-VALUE, register equality.** Every drawn value equals its signed
  row at the stated precision. The projection row signed as NR-044.
  @aero-validator owns the counter-read, at the sign-off commit.

## Caption plan (dual)

- Plain sentence: one seed, three islands. This figure maps the search
  journeys in gene space and shows where the light machines live.

- Technical caption: the projection, the axes, the journeys and the
  objective field. @author writes both captions. Every number cites a
  register row.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print scale
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pins and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing: the scripted figure against the committed
  record walks F-CITE, F-REPRO and F-LABEL. The counter-read by the
  seats and the visual pass by Rod come first. The projection row
  signed as NR-044. The counter-read at `331f60d` held the drawn values
  and routed the cite fix. The re-census at `7329191` closes F-VALUE on
  the fix commit (`d6d4db9`).

- **R3** the final pass. Rod does the visual pass. Status moves to
  approved.

## Open inputs

1. The reading-order slot (author seat) and the fold order.

The projection row closed as NR-044 (signed 2026-10-13). The
generation count closed as NR-045 (signed 2026-10-14). The plate
prints no other waited value.

## Non-goals

No 3D view. No tight pair grid. No smoothed curve. No re-derived
outcome values. The colour bar and the axis ticks are scale, not
readouts.

## Deltas

- v3 (2026-10-14): the cite fix and the stamp re-cut. The readout list
  takes the register mapping for NR-005 and NR-006. It cites NR-045 for
  the generation count. The drawn row list takes NR-044 and NR-045.
  The projection stamp takes its signed form. The caption text takes
  the kg-equivalent form. New pins at script commit `e23f226`.
- v2 (2026-10-13): NR-044 signs (`2ad023c`); the row want closes. No
  plate byte moves.
- v1 (2026-10-13): R2 lands with the GENERATE pass. The scratch draft
  carried two vision rounds before the kit.
