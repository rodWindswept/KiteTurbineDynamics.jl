# Room response: sweep 36, the v0.79 to v0.91 span (2026-11-17, science-writer)

**Status** LANDED. **Seat** science-writer.
**Read at** `74052e59`. The record sits in `docs/reporting/draft-consistency-sweep.md`.
**Span** `c6d79b9..74052e59`. The read ran on 2026-11-17.

## The span

The span opens at `c6d79b9`, the Sweep 35 end.
It closes at `74052e59`, the tip at this read.
The span carries 119 commits, 16 draft movers and 5 register movers.
The draft moves across 12 versions, v0.79 to v0.91.
The register grows by 12 rows, NR-074 to NR-085.
It reads 85 base rows and 5 extension rows at the tip.

The local tree equals origin at this read.
The tree also holds a staged revert of the v0.91 author pass.
This pass takes no byte from it and names no part of it.

## The two word counters

`wc -w` reads 12,835 at v0.91.
The house counter reads 12,726.
The gap of 109 is a counting artefact, and it is not a draft change.
The house counter strips code spans and splits punctuated tokens.
The gap reads 191 at v0.79, so the gap moves with the text.
No one should difference the two counters, and the house count is the commit-message one.

## STE

The gate reads words 11,597 to 12,726 at v0.79 to v0.91.
Total violations read 28 to 31.
Per100w holds at 0.24 at both ends.
The offender delta reads long sentences 8 to 9, passive 4 to 5 and long paragraphs 14 to 15.
Contraction holds at 1 and nominalization holds at 1.
Em dashes read 0 at both ends.

## The token diff

The diff reads 12 added tokens and 0 removed.

| Token | Site | Support |
|---|---|---|
| 29 W, 57 W | line 352 | NR-014, no row for 57 W |
| 79 mm, 59.89 mm, 90°, Eq 4.30 to 4.34 | appendix, lines 1425 to 1470 | spec and pins |
| 0.154, 0.439, 0.593 | line 1046 | NR-013 ext2 |
| 5.630 m, 401.03 N·m | lines 185 and 356 | NR-032, NR-015, NR-029 |

The 0.593 at line 1046 reads a factor of safety.
The same digits print in NR-034 as the rounded Betz coefficient.
The two readings are separate quantities, and neither crosses the other.

## The finding

One token carries no signed row.
The gap reads 57 W at draft line 352, and the bracket names NR-014 alone.
NR-014 signs the 29 W window swing, and it signs nothing at 57 W.

The 57 W follows from the torque offset: 401.03 N·m less 396.76 N·m, times 13.38 rad/s.
The two inputs print at lines 355 and 356 under NR-030, NR-015 and NR-029.
No register row carries 57 W or 5.366 kW.

Two fixes exist.
The line 352 bracket takes NR-030, NR-015 and NR-029.
Or a derived row lands the recipe.
The room holds that call, and this pass moves no draft byte.

## Checks that pass

- Cited rows: 59 distinct rows in the draft.
  Every one holds a register row and every one carries a sign.
  The cited set reads the same as at Sweep 35.

- Appendix pins: 10 of 10 refs resolve in the tip ancestry.
  The tenth arrives with the tension-numeral pass at v0.87.
  The refs read `31ca00d`, `87e6b10`, `9241b23`, `a76c5e9`, `a82cafd`, `ce9c5d8`, `d0e410d`, `dd3cc6a`, `e3d664c` and `e66dd94`.

- Retired phrasing: `adaptive` reads 0 and `DifferentialEquations` reads 0.

- Prose-form census: `the room` reads 0, `seat checks` reads 0, `the pipeline` reads 1 and `campaign winner` reads 7.

- Exhibit stamps: the appendix names the dataset commit `dd3cc6a` and the launch commit `a76c5e9`, and both resolve.

## NR-086

NR-086 sits on `bank-derate-cos2p65` and takes no part in this read.
The register at the tip ends at NR-085.
The Glauert numeral does not print in v0.91.
Draft line 1526 reads that the value waits on a signed row.
So the cherry-pick of NR-086 is a condition on a later print, not on this text.

## What this pass moves

It moves no draft byte and no register row.
It moves no cited count.
It lands the record section and this receipt.

## Next action

The next read keys at the gate 2 push.
That push moves the draft, so sweep 37 opens at `74052e59`.
The 57 W bracket call sits with the room.

science-writer, 2026-11-17
