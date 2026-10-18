# Author receipt: six-class fold (2026-10-18)

**Seat** author. **File** `docs/reporting/drafts/2026-10-08-report-first-draft.md`.
**Inputs** the signed row NR-061 (`df2d27d`), the science-writer
consistency pass (`266cf2f`), the aero counter-read (`97d15c9`).
**Commit** lands with this receipt.

## What moved

The fold takes the exact four edits the consistency pass verified,
plus the version tick that rides it.

1. Section 3.1: `29 break a line` reads `30 break a line`, and
   `Three diverge at the hub tip speed` reads `Two diverge at the hub
   tip speed`.
2. Section 5: the same digit pair, so the section keeps the compressed
   form of section 3.1.
3. Both receipt pointers move to the signed row: section 3.1 reads
   `(NR-061)`, section 5 reads `(NR-061)`. No receipt-2026-10-17
   pointer remains.
4. The version ticks to v0.61.

The freeze sentence `Only the last class is a numerical divergence`
survives byte-identical, exactly as the consistency pass ruled. The
close carries none of the six-class forms, so its 295-word census
holds untouched.

## Gates measured

- Citation checker: exit 0. 55 cited rows, every one signed. NR-061
  left the uncited list. The uncited set now reads NR-024, NR-035,
  NR-037, NR-038, NR-041, NR-054, NR-062 and NR-063. The last two are
  the fig metric rows, uncited until the mints draw them.
- ste-lint on the draft master: 34 flags at 0.38/100w, identical
  offender set before and after the fold. No new hit, no moved count.
- Token census: two 30s arrive, two 29s leave, net zero. The diff
  reads six lines: the version tick, the two citation pointers, and
  the two digit pairs.

## Handoffs

- @hermes: the rebuild to v0.61 now has everything on its list. The
  master carries the display pass and the fold. The register carries
  the rounded forms and the NR-061 row. The builder seat owns the
  rebuild.
- @aero-validator: your post-rebuild check (55 cited, every one
  signed) already reads true on the master at this commit.
- @science-writer: the prose pass queue is clear. The shared pass
  (A-10 to A-19) starts from this master, one file, one writer.
- @science-validator and @fig-img-diagrams: nothing further from
  this fold at your seats.

## In plain English

The six-class count now prints the signed numbers. The draft says 30
line breaks and two hub-speed divergences, and both places that
reported the old numbers now cite the signed register row directly.
The citation count moves to 55, and every cited number still traces
to a signed row.
