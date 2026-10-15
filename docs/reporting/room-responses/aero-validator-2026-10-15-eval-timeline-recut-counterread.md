# Room response: the placement label re-cut counter-read (2026-10-15, aero-validator)

**Status** LANDED. **Seat** aero-validator. **Base** `feaaa82` (branch
`bank-derate-cos2p65`). The re-cut reads at script `a269636`, landing
`f5c2d59` (range `e6206de..f5c2d59`).

This read covers the eval-timeline placement label re-cut: the vector
census, the pins, the reproduction, the register join and the boundary.
Check set 35 checks, 0 fail (`scratch/av_et_pl_counterread.log`). The
figures checker re-runs at this seat: 63 checks, 0 fail.

## 1. The vector census

- Exactly two drawn strings move. The label:
  `rope-break gate off during relax (not yet in the code)` becomes
  `rope-break gate off during relax`. The footer stamp:
  `script commit 1af63fc` becomes `script commit a269636`.
- One box moves with the label. The patch box left edge reads
  337.42286 to 412.678329. The shorter label needs the smaller box.
- The digit census holds. The only digit-bearing string that changes is
  the stamp. The stamp carries a commit hash, not a measured value.
  Every drawn value reads as delivered.
- The caveat reads zero times in the vector, the ledger, the generator,
  the register note and the captions. The SPEC keeps one historical hit
  with its context. The map keeps one historical hit in the v18 delta.
- The delivered PNG passed a visual read at this seat. The lane-3 label
  reads "rope-break gate off during relax". The footer stamp reads
  "script commit a269636".

## 2. The pins and the reproduction

- The manifest pins recompute from the committed bytes. Script sha256
  `5f7a2d1f…`. Outputs: svg `373c2db3…`, pdf `f6a10be4…`, png
  `7a1297ce…`, ledger `e34bc924…`.
- The svg pin reads `373c2db3` in the manifest and both sweep records.
- F-REPRO at four locations. The in-place delivery, the two scratch
  outdirs and a fresh out-of-tree run from this seat produce five
  byte-identical outputs. The md5 table reads `f372aa67` (svg),
  `5bab519e` (pdf), `6fa0c538` (png), `5e040e77` (ledger) and
  `7cb63399` (manifest) at every location.
- The figures checker re-runs at this seat: 63 checks, 0 fail.

## 3. The register join

The three warm-extract CSVs bind to NR-013 ext2. Their git blob SHAs
read `770d9377…`, `05fb874b…` and `3b39f063…`, equal to the pinned
blobs and present in the register. The post-fix warm records and these
bytes read one chain.

## 4. The boundary

The range carries no draft byte and no docx byte. The plate slug sits
nowhere in the draft. This matches the figures read and the sweep 32
read.

## 5. One precision note for the figures seat

The re-cut receipt reads "one drawn string moves". The census reads
two: the label and the footer script-commit stamp refresh. The ledger
diff reads two lines for the same pair. The stamp refresh is the generator provenance move, and it reads
correct. No value moves
either way. This is a record count, not a defect. The figures seat
decides whether the receipt takes the line.

## Evidence

- `scratch/av_et_pl_counterread.py` and `.log` (35 checks, 0 fail)
- `scratch/av_et_pl_check_rerun.log` (the figures checker at this seat)
- `scratch/av_et_pl_fresh_run.log` and `scratch/av_et_pl_fresh/` (the
  fourth-location run)
- `scratch/av_et_pl_fresh_md5.log` (the four-location md5 compare)

aero-validator
