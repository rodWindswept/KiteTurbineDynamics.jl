# Room response: draft v0.57, the winner bow read folds (2026-10-16, author)

**Status** LANDED. **Seat** author. **Read at** `e639bb2` (branch `bank-derate-cos2p65`). The fold landed as `c825a01`, range `e639bb2..c825a01`. The rebuild and the origin readback ride this pass.

**Scope** This response folds the winner bow read into section 3.3. The row is NR-059, signed at `7aaf2ea`. The founder word "up" (2026-10-15) sent the read. The room chain holds: value + station + state. The read meets the 1.5 m line at the same station and the same state. The settle/run disagreement prints as an instrument finding.

## The fold, as landed

- The version pin refreshes to v0.57, dated 2026-10-16.

- The bow block lands at section 3.3, after the settle-state paragraph.
  It sits ahead of the window-mean speed sentence.
  It adds thirteen lines across three paragraphs.

The block reads:

The shaft axis bows off its design line, sagging straight down under gravity.
At the midpoint ring the bow reads 0.002 m at settle, and
0.105 to 0.310 m through the measurement window (NR-059).
The maximum sits at the hub and reads 0.209 to 0.613 m through the window (NR-059).

An extension run past the window ends at 0.422 m at the midpoint
and 0.833 m at the hub (NR-059).
Every state at the midpoint ring reads below the 1.5 m line (NR-059).

The settle hands off a straight stack while the run bows it.
The two do not agree on the bowed shape.
The disagreement reads as an instrument finding, not a design question (NR-059).

- The tracker takes the v0.57 entry.

## Guards held

- The changed-line census reads exact.
  One replace sits at the pin. One insert sits at the block, thirteen lines deep.
  The draft moves from 1,063 to 1,076 lines.
  The tracker insert reads five lines deep and moves 446 to 451.

- The declared token diff reads exact.
  The draft removes `56` and adds `57`, `0.002`, `0.105`, `0.209`, `0.310`, `0.422`, `0.613`, `0.833` and `1.5`.
  The tracker adds `57` and `3.3`.

- The held forms read level. `NR-016`, `10.170` and `13.38` hold their counts.
  The `NR-` count moves 250 to 255. NR-059 reads five.
  The word "bow" enters the draft at four occurrences.

- The new forms read once each.
  The untouched regions hold from the abstract through to the figure-provenance appendix.

- STE holds rc=0 on both files.
  The draft reads 7,341 to 7,465 words at total 8.
  The tracker reads 3,434 to 3,468 at total 12.
  Every category holds.

- The fold script holds 3 anchors and 33 guards, all closed.
  The candidate hashes read draft `31d0dada…` and tracker `b00ee694…`.

- The citation gate exits 0.
  It reads 53 cited rows, every one signed (59 signed rows total).
  NR-059 joins the cited set.

- No figure byte moves. The plates and the caption kits hold as shipped.

## The review-copy rebuild

- The build runs from the tip.
  The record reads draft `c825a01` and the register file at `7aaf2ea`.

- Eight of eight seats resolve. Nothing re-renders. The kits embed as shipped.

- Built 2026-10-16T13:26:38Z.
  The live copy `scratch/report-pdf-build/draft-live.docx` reads md5 `3b92d088cf2bab1fca739c2bd5082ab5`.

- The live copy reads byte-identical to its archived build `draft-c825a01-20261016-132638.docx`.
  Eight media entries carry the eight kits.

- The delivered file carries the phrase set. The pin reads once.
  Every block line reads once. NR-059 reads six (five in the draft, one in the register appendix).
  The old marks read zero.

- The delta from the founder copy reads two fronts.
  The v0.56 copy (md5 `5ecee42e…`) gains the pin line and the section 3.3 bow block.
  The register appendix gains the NR-059 row.

## Receipts

- The fold evidence rides `c825a01`.
  `scratch/au_v057_bow_read_fold.py` and its log read byte-verified at origin.

- The rebuild check rides this commit.
  `scratch/au_v057_rebuild_check.py` reads 43 checks, 0 fail. Its log sits beside it.

- The readback follows as `scratch/au_v057_readback.log`.

Recorded by @author (author seat).
