# The round-6 counter-read fold-back and the corner-grid opening

**Seat:** figures-images-diagrams (@fig-img-diagrams). **Date:** 2026-10-15.
**Base:** `0739ee7`, the round-6 counter-read close.
**Landing:** `4987e28` and `b02ecdf`, then the records, seat page and
readback commits of this train.

## 1. The fold-back lands

- The five re-cut rows (2, 4, 6, 7 and 10) take the closure. Each row
  now reads the close at `3038656` (136 checks). The visual pass by Rod
  is the next gate at each row.
- Row 23 records the open. The extract mints and the generator build
  runs next.
- Map delta v38 records the fold-back, the form-note hold and the
  corner open.
- The checker `scratch/fig_r6fb_check.py` reads the map, the two kit
  notes, the seat page, this receipt and the extract: 29 checks, 0 fail.

## 2. The five form notes hold

The term gate left five generator comment lines for this seat. They
hold, and the hold is recorded at three levels: the map delta, the two
kit register notes, and this receipt.

- `eval-timeline.py` line 10, the lane-1 docstring line. One comment.
- `machine-winner-hero.jl` lines 208, 371, 398 and 492. Four comments.

Reason. The comments never print. A sweep moves the two manifest
`script.sha256` fields, and the reproduce check compares the manifests
byte for byte. So a sweep would ask a fresh reproduce walk for no
reader-visible gain. It rides the next build of the two kits. One
line reopens the sweep if the room reads the trade the other way.

## 3. The corner grid opens (row 23)

- The extract mints at
  `docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv`,
  with its log and the kit README.
- The extract sha256 reads
  `03abd0c660e0ad22db89f767a7b033c18db82f67dde69593c31cbb3a3919a4d5`.
- Four rows, one per corner, in the NR-051 order. The genome tokens
  copy byte-exact from the telemetry rows, over 128 fields re-read.
- The picks re-derive to the signed set: `i1-g13-i1`, `i1-g7-i7`,
  `i2-g21-i4` and `i3-g26-i8`. The objectives read 60.646, 58.864,
  33.704 and 33.812.
- Every NR-044 anchor gates before a row writes: 12 of 12. The
  certificate rides the kit log.
- The checker `scratch/fig_cg_extract_check.py`: 54 checks, 0 fail.
- The full precision travels in the file. The display forms gate on
  NR-051 at GENERATE. No plate prints yet.

## 4. Records and gates

- Commits: `4987e28` (the fold-back), `b02ecdf` (the mint script and
  its checker), the records commit, the seat page commit and the
  readback log of this train.
- STE per 100 words: map 1.86, et note 1.94, hero note 1.26, seat
  page 0.20, README 0.62, receipt 1.60. The bar is 2.0.
- Readback: every committed blob of this train byte-read at origin.
  Local matches origin.

**Handoffs.**

- @aero-validator: the counter-read close folds back at the map. The
  corner extract stands open to your F-CITE read when the generator
  lands. No re-key is asked now.
- @science-validator: the form-note hold is recorded for the term
  gate. The extract re-reads NR-051 to the signed digits.
- @author: the map rows read the visual pass as their next gate. No
  plate byte moves.
- @hermes: the queue can record the fold-back and the corner open.
- @user: plain. The figure map now reads the finished check. The
  corner-machine build holds its four machines pinned to exact data.
  The drawings come next.
