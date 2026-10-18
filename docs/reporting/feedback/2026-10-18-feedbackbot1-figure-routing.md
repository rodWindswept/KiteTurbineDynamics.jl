# FEEDBACKBOT1: figure routing (2026-10-18)

**Source** `scratch/report-pdf-build/FEEDBACKBOT1.docx` (the founder's
review copy). This record is the figures seat slice. It captures every
figure-side note with its disposition. Status keys: OPEN, GATED, CALL,
LANDED.

A note names its immediate gate:

- **RE-CUT** means a byte-moving render on a seated kit. The A/B train,
  the pin refresh and the counter-read follow.
- **MINT** means a new roster row.
- **KIT-TEXT** means kit text only. No render moves.
- **NOTE-ON-ROW** means the note folds into an existing row brief. No
  new row.
- **ROOM-CALL** means an open decision for the room or the founder.
- **OTHER-SEAT** means the note routes out of the figures seat.

## A. Re-cuts on seated plates (data-unblocked)

| ID | Item | Row | Disposition | Gate |
|---|---|---|---|---|
| F-1 | `ring-utilisation`: a linear axis with the FoS 2.5 campaign gate drawn at utilisation 0.40. R5 reads a tension badge, not a compression bar | 6 | RE-CUT | Value list first. The NR-021 axial forms and the NR-015 gate. All signed |
| F-2 | `ring-utilisation`: a companion signed axial-force chart (R2 to R6 against their critical loads) | 6 | ROOM-CALL | A panel-B add on the F-1 cut, only if the figure budget admits it |
| F-3 | `twist-limit`: panel B draws the 1.5 torsional FoS gate. The four canvas method lines move to the technical caption | 7 | RE-CUT | NR-052 signed |
| F-4 | `pca-landscape`: the clipped top-panel label (T4-6) and the kg-equivalent forms (T4-8) | 20 | RE-CUT | Layout fix. The label forms ride the kg-equivalent sweep |
| F-5 | `pca-atlas`: colour-bar ticks at three significant figures (T4-7) and the kg-equivalent forms (T4-8) | 21 | RE-CUT | Layout fix |
| F-6 | `machine-winner-hero`: the small top-panel callout font (T4-9). Coordinate triads and the clearance plane are optional. They join the visual pass | 10 | RE-CUT | Layout fix |
| F-7 | `system-anatomy`: the garbled footer phrase and the stroke-weight upgrade. The shaded rendering upgrade is a machine-renderer SPEC change. It stages separately | 2 | RE-CUT | Layout fix plus a SPEC delta |
| F-8 | The Makie renderer family: legend tokens to natural labels, the PDF date normalisation strings out of the footers | 9, 10, 23 | RE-CUT | Layout fix. The exact forms ride the label ledger |
| F-9 | Micro-typography floor: 8 to 10 pt equivalent at A4 across every seated plate | all seated | RE-CUT | Rides the same cuts as F-1 to F-8. No separate pass |
| F-10 | Strip the git hashes and script filenames from the plate canvases | all seated | ROOM-CALL | The drawn stamp carries the F-REPRO feature. Provenance already prints in the captions and the appendix. Needs the house ruling |

## B. Metric-card additions (value sourcing first)

| ID | Item | Row | Disposition | Gate |
|---|---|---|---|---|
| F-11 | `machine-evolution-strip`: per-frame metric cards (mass, power). The objective values are signed (NR-036). Per-milestone power needs rows | 9 | RE-CUT | GATED on the science-validator value list |
| F-12 | `machine-corner-grid`: per-panel metric cards (n_lines, rotor count, r_hub, mass, penalty, power). The decode fields and the objective are signed (NR-051). Per-pick mass and power need rows | 23 | RE-CUT | GATED on the science-validator value list |

## C. New plates (mints)

| ID | Item | Row | Disposition | Gate |
|---|---|---|---|---|
| F-13 | Parallel coordinates: active genes and outputs, one line per design, status ink, the island-3 journey highlighted. This supplements the field pair. It does not replace rows 20 and 21 unless the room rules a retirement | new | MINT | The island telemetry (data commit `dd3cc6a`, run `a76c5e9`). Value list, SPEC, slot ruling |
| F-14 | Window traces: power, speed, tension and shaft bow across settle, relax, window and the extension | new | MINT | `window-trace-extract` (`6175f83`). The NR-059 capture. Per-trace value list |
| F-15 | Genome geometry schematic: r_hub, r_rotor, r_bottom, segment length, polygon count, bank and the 22 degree transition cone | new | MINT | The decode fields, NR-011, NR-043. SPEC. Reconcile against row 15 |

## D. Folds onto existing rows

| ID | Item | Row | Disposition | Gate |
|---|---|---|---|---|
| F-16 | Gate attrition funnel for the 930 designs | 16 | NOTE-ON-ROW | Panel 1 already draws the pooled status mix. The nested funnel form rides a row-16 re-cut. GATED on the six-class row (the re-derivation in flight at the science seat) |
| F-17 | Penalty decomposition across milestones | 16 | NOTE-ON-ROW | Companion panel on row 16. NR-039 signed |
| F-18 | Dual-axis k-sweep trade-off with the threshold lines | 5 | NOTE-ON-ROW | The row-5 rework scope gains the 5 kW floor, the tip-speed ceiling and the k = 2.24 marker |
| F-19 | Pipeline flowchart and phase timeline | 19 | NOTE-ON-ROW | Folds into the row-19 brief. The phase timeline already draws as row 4 |
| F-20 | AWES taxonomy diagram | 1 | NOTE-ON-ROW | Row 1 exists. The review sharpens its brief. Track A still gates it |
| F-21 | Sensitivity tornado | 17 | NOTE-ON-ROW | Row 17 exists. The review sharpens its brief |

## E. Calls and cross-seat items

| ID | Item | Row | Disposition | Gate |
|---|---|---|---|---|
| F-22 | `scaling-ladder`: a full page for one filled rung | 24 | ROOM-CALL | Two options. Condense to an inline roadmap (author seat). Or upgrade to a scaling-law projection (figures seat, and the derived curves need register rows). The seated plate holds until the founder visual pass lands |
| F-23 | Inline placement and figure numbers | all seated | OTHER-SEAT | Builder and author seats. The seats exist in the draft. The figures seat verifies the embeds after the rebuild |
| F-24 | Inline source strings against plate footers | all seated | OTHER-SEAT | Cross-seat audit. The kit manifests carry the ground truth per plate |

## Working order

1. Batch A first: F-1 and F-3. The review praises both structural plates
   and asks to unify them.
2. Then F-4 to F-8, the kg-equivalent sweep and the micro-typography
   floor. They ride together.
3. Batch B when the value lists sign.
4. Batch C when the SPECs and the slot rulings land.
5. Batch D rides the row-16, row-5 and row-19 reworks.
6. Batch E waits on the room calls.

The six-class re-derivation at the science seat gates F-16 only. Nothing
in batches A, B or C draws the class split.

## In plain English

The review asks for a lot of chart work. This record splits it into five
batches. The safe batch is a set of re-cuts on the plates the review
praises. The ring utilisation chart gets a linear axis and the true
campaign gate line. The twist chart gets the 1.5 torsional gate. Type
gets bigger everywhere, and the labels get honest units.

Three new plates join the roster as new rows. They are a parallel
coordinates view, a time-trace view and a geometry schematic. The record
flags items that need other seats or an owner call. It does not execute
them.

Nothing here draws the six-class numbers. The pending re-derivation
gates only the rejection funnel.
