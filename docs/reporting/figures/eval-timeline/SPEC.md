# SPEC: eval-timeline. The evaluation timeline and the gate map.

**Slug** `eval-timeline`

**Status** SPEC v1, R2 landing. Angle brackets ⟨⟩ mark binding slots.
This document carries no drawn value. The numbers register supplies the
citation discipline. The section 2.3 prose supplies the reader account.

**Owner** @figures-images-diagrams. **Content check** @science-validator
and @aero-validator. @aero-validator runs the F-VALUE check at the
sign-off commit. **Reader-facing layer** @author: the captions and the
slotting.

**Contracts** the reporting framework (the figure workflow: SPEC,
GENERATE, CHECK, the rounds, the dual captions). The numbers register
(the firewall). The glossary forms: the window reads "measurement
window" (Harris 3.3). The code names `:cold` and `:warm` stay in the
software section.

## Why this exists

The section 2.3 prose explains the relax run, the measurement window and
the gates. The reader asks what the instrument measures, and when. This
plate carries the shape: the settling story on the 50 s timeline, and
the gate map.

The plate shows two facts the brief missed. The rope-break gate is the
only read that covers the relax. The sampled gates read once per second,
so a crossing between samples goes unseen.

## What already exists. Extend, do not rebuild.

- The eval-timeline extract
  `docs/reporting/figures/eval-timeline-extract/` (tree 980de02). Three
  files: cold (5000 rows at 100 Hz), warm (98 rows, the run ends at the
  latch) and warm-rulingmode (the condition run, 1823 rows). The probe
  landed at `21e941d`.

- The window-trace extract
  `docs/reporting/figures/window-trace-extract/` (tree 8d01394). The 52
  scored taps, 11 relax and 41 window. The landing commit is `6175f83`.
  The window mean equals NR-029 exactly.

- NR-013 ext binds the two lane-3 strain annotations. The aero
  counter-read closed.

- The rows: NR-008, NR-012, NR-013, NR-013 ext, NR-016, NR-027, NR-029,
  NR-039 and NR-042.

## Inputs. The record contract.

- Four committed CSVs. The plate draws the cold curve, the warm leg and
  the condition curve from the extract files. The taps carry the NR-029
  provenance. Nothing draws from the taps this pass.

- No idealised traces draw. Every curve comes from the committed rows.

- The ruling-mode curve prints under the condition-run label only. The
  label names the placement, landed in the code at `2bf76a3`. No label
  claims the machine would pass.

- The quote forms read as signed: 1.00081 at t = 2.841 ms, and 1.448 at
  t = 5.798 ms, the extract grid max.

## The drawing

### Lanes

- The phase strip carries the relax span and the measurement window
  span. The seated labels read "relax (grey)" and "measurement window".
  The grey tag names the shading in the element that owns it.

- Lane 1 carries the ground rate and the top rate, with the two
  reference lines.

- Lane 2 carries the generator power, with the floor line and the two
  marks.

- Lane 3 carries the strain ratio. It draws the cold curve, the warm
  leg and the condition curve. An inset shows the first 12 ms.

- Lane 4 carries the gate map. Four rows carry the code reads at
  a89642b.

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `cold_curve` | the cold extract | solid ink line, 0 to 50 s | row count, window mean |
| `warm_leg` | the warm extract | red line, to the latch | last row, latch |
| `condition_curve` | the ruling-mode extract | steel dashed line | grid max, no latch |
| `inset_12ms` | the warm and ruling files | first 12 ms | placement |
| `gate_map` | the gate table at a89642b | four rows, spans marked | presence |
| `gate_key` | the lane-4 marks | one line, 424 pt column | four marks named, gaps 0.45 or more, pitch 0.30 |
| `stamps` | — | sources, trees, rows, script commit | presence |

### Readout list

| Figure string | Source | Where used | Note |
|---|---|---|---|
| the rate references | NR-016, NR-029 | lane 1 | 10.17 and 13.38 |
| the power marks | NR-008 | lane 2 | 5.309 and 5.314 |
| the floor | NR-027, NR-039 | lane 2 | 5.0 kW |
| the warm annotation | NR-013 ext | lane 3 | 2.841 ms |
| the condition peak | NR-013 ext | lane 3 | 1.448, grid max |
| the gate spans | the a89642b read | lane 4 | code facts |
| the gate marks | the a89642b read | lane 4 | band, tick, box, diamond |

The display forms pin here once, for labels, captions and prose alike.

## Checks. External, never self-graded.

- **F-CITE, citation binding.** Every annotation cites a signed row.
  The stamps carry the sources, the trees, the register rows and the
  script commit. A missing stamp or citation is a reject.

- **F-REPRO, deterministic reproduction.** A fresh run on the same
  inputs reproduces the figure bit-identically. Script and toolchain
  stay pinned.

- **F-LABEL, ledger equality.** The check enumerates the text layer of
  the emitted vector. Every string must equal its ledger entry.

- **F-VALUE, register equality.** Every drawn value equals its signed
  row at the stated precision. @aero-validator owns this check, at the
  sign-off commit. No tolerance widening.

The framework visual checklist applies, graded from the image alone.
Pixels never validate numbers. Rod does the final visual pass.

## Caption plan (dual, from the first figure)

- Plain sentence: ⟨the evaluator settles the machine for ten seconds,
  then measures it for forty. This figure shows that settle, and when
  each gate reads the run.⟩

- Technical caption (undergrad register, STE-clean form): ⟨the winner
  timeline. The cold path holds the window. The warm start as coded
  over-strains a line in milliseconds. The condition run holds the
  break gate off during the relax and completes the 50 s. The key
  names the four gate marks.⟩

@author writes both captions. Every number cites a register row.

## Emitted artifacts at GENERATE

- the figure, vector PDF and SVG, with a PNG preview at print
  resolution
- the generating script, committed
- the label ledger, checked by F-LABEL
- the manifest, with the input pins and the output hashes
- the checks log
- the captions draft and the register-status note

## Rounds

- **R2** this landing: the scripted figure against the committed
  extracts walks F-CITE, F-REPRO and F-LABEL. The image-reader and the
  validators take their pass. Deltas land.

- **R3** the final pass. @aero-validator runs F-VALUE at the sign-off
  commit. Rod does the visual pass. Status moves to approved.

## Open inputs

1. **Closed:** the window-only rope-break placement call. The placement
   landed in the code at `2bf76a3` (aero-validator). The lane-3 label takes
   the landed form. The gate-map band holds as the a89642b record.

2. **Fixed-seed redraw:** a redraw draws from its own extract and needs
   fresh rows before anything prints from it (@science-validator).

3. **Gate-map strings:** the band reads the code at a89642b. The
   strings read as code facts. A bounce lands here if a string needs
   its own row.

## Non-goals

No idealised traces. No smoothed curves. No code names in labels. No
claim that the machine would pass under the ruling. Nothing draws from
the taps this pass.

## Deltas

- v1 (2026-10-13): R2 lands with the GENERATE pass. The scratch draft
  carried the round-1 reads. The two term picks land: the subtitle
  drops the colon code forms, and the ruling label takes "not yet in
  the code". No drawn value changed at the landing.

- v2 (2026-10-14): the hub-name retirement sweep (round-6 comment 1).
  The lane-1 label reads "ω top" and the gate row reads "top · tip ·
  Betz". The drawn rows list takes NR-042 (its recorded next-build
  item). No drawn value moves.

- v3 (2026-10-15): the placement lands (`2bf76a3`). The lane-3 label
  reads "rope-break gate off during relax". The head comment sweeps to the
  top form. No drawn value moves.

- v4 (2026-10-21): the readability re-cut. The rows line takes the two
  rows v2 recorded and never bound, so it reads the nine drawn rows. The
  elements table gains `gate_key` and the readout list gains the four
  marks. The caption plan takes the placement. The technical plan no
  longer says the warm start breaks in milliseconds without naming the
  condition run that clears the run. It also gives up "The gate map
  marks the read spans", because the plate key carries it and a caption
  cannot hold one fact twice. The phase-strip label reads "relax (grey)".
  The lane-4 labels read eleven lines at four anchors (3.80 / 2.80 /
  1.50 / 0.35), so the blocks clear at 0.55 against the 0.30 pitch. A
  first pass at 0.45 gaps still read as one paragraph in the render. The power-floor block keeps its four lines, so NR-039 keeps its
  drawn name. The cold-path label takes its sampling cadence, "one value
  every 10 ms". The lesson line moves from faint italic 6.8 to ink 7.5.
  No drawn value moves. The label census reads 50 strings (52 before:
  14 out, 11 in, two rewrites, one key).
