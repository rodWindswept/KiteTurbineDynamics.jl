# Register status: machine evolution strip

**Slug** `machine-evolution-strip`. Status note for the figure row.
**Date** 2026-10-09. **Re-render** 2026-10-11.
**Script commit** `74cfef9`. First GENERATE `52ba1e7`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-005 | Island 3 best fitness. The winner panel identity, found gen 26 | Signed (science-validator, 2026-10-08) |
| NR-006 | The common seed. The first panel identity | Signed (science-validator, 2026-10-08) |
| NR-011 | Winner geometry. The winner panel check at GENERATE | Signed (science-validator, 2026-10-08) |
| NR-036 | Island 3 running-best objective at the seven milestones. The value under each panel | Signed (science-validator, 2026-10-11) |

The figure draws no other row. The panel genomes come byte-exact from
the signed extract (`strip-extract-2026-10-09-best-so-far`). The extract
sha256 is unchanged across the re-render.

Note on labels: the extract labels use the telemetry generation index
(gens 0 to 30, per the extract README). NR-006 prints the convergence.csv
index (gen 1) for the same seed. Flagged for the science-validator
counter-read.

Closed 2026-10-09 (science-validator): no mislabel. The convergence row i
is the running best over telemetry gens up to i, so the seed surfaces at
row 1 and the winner at row 26.

## The 2026-10-11 re-render (Harris 3.5 deltas)

- Layout: two rows, four panels above and three below. One shared scale
  and one window hold across all seven panels.
- Objective labels: the label strip carries the search objective under
  each panel, in kg. The values cite NR-036. This is a declared delta to
  the geometry-only rule. The strip prints no power value and no
  airborne mass value.
- Square axes: both scales read 16.601332567 px/m. The delta reads
  0.0000 ppm in `checks.log`.
- Manifest: the scale block declares `tolerance_px` 0.05.
- Footer: a third stamp line states the shaft frame. Distance along the
  shaft is vertical. The operating elevation is not drawn.
- Canvas: 896 by 1028 pixels at 0.060236 m per pixel. The panel size is
  212 by 340 pixels.
- Label fonts step up for print: gen 13 px, identity label 9 px,
  objective 9.5 px.

## Checks at GENERATE

All in-script checks pass at `74cfef9`: the per-panel decode checks,
the NR-011 winner check, and the NR-036 objective check on all seven
panels. `checks.log` holds the full record.

The science-validator panel check recomputed the extract from the raw
telemetry (2026-10-09). That check stands for the extract. The
re-render re-reads the same file.

## Validator gates

F-COUNT and F-PARSE passed 2026-10-09 on the SVG of the first
GENERATE (`9aeeed4`). That pass does not carry to the re-render. A
fresh pass runs on the SVG of this commit. Sign-off follows that pass.

The two earlier sub-pixel notes close here. The axes are square. The
manifest carries the tolerance field.

Text layer: the SVG emits glyph paths, not selectable text. The PDF
carries selectable text. The item stands open to the room as before.

## Reproduce

Command:
`scripts/ktd-julia docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl --script-commit 74cfef9`

Toolchain pin: julia 1.12.5, CairoMakie 0.15.11, mutool 1.23.10. The
PDF carries a normalised creation date (1970-01-01). The pipeline
replaces the cairo wall-clock stamp. The manifest pins the extract and
the output hashes.

Self-check: two consecutive runs stay byte-identical across all five
outputs (png, svg, pdf, manifest, checks.log). Verified 2026-10-11 at
`74cfef9`.
