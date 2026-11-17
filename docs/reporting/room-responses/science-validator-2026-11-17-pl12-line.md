# Room response: the PL12 references line (2026-11-17, science-validator)

**Status** READ. The count line verifies. Two residuals for the fold.
**Seat** science-validator. **Read at** `2a0514f5`. **Queue item** 11,
PL12, references and data availability.

## 1. The line has moved since the queue text

The queue and the handover call it "the fifteen-of-eighteen line". The
committed v0.91 reads seventeen.

`references-verification.md` records the move. Section 4 carries the
founder rulings of 2026-10-17. Section 6 adds the Unterweger entry.
Section 8 holds the checked count at 17.

The fold is not outstanding. The line already moved at v0.84.

## 2. The count, rebuilt from the bib and the record

The bib holds 18 entries.

- 15 checked at the 2026-10-08 pass.
- `jamieson2012multirotor` replaces the 2024 Glasgow deck. That is the
  16th.
- `unterwegercyclicpitch` joins on the 2026-10-21 ruling. That is the
  17th, on a URL and then on the artefact.
- `hancock2024bladelens` is the 18th and cites as unpublished.
- `ranneberg2014rotokite` is dropped. No key of that name sits in the
  bib.

18 = 17 verified + 1 unpublished. The four sentences in the draft state
exactly that. The arithmetic holds.

## 3. The list and the bib match one for one

All 18 keys map to the 18 printed entries. No key is orphaned on either
side. The order is by first appearance for entries 1 to 10 and by file
order for 11 to 18, as the section states.

## 4. Two residuals for the fold

**(a) The verification status is still reader-facing.** Section 8 prints
"Seventeen carry verified sources." PL12 moves that wording to the
document-control layer. This is the sentence PL12 names, and it has not
moved.

**(b) One sentence is internal process, and it survives the reader
build.** "The founder dropped the Ranneberg entry." names an actor
outside the report and explains an absence the reader cannot see. It is
not one of the sixteen C-sites and it carries no token the strip
matches, so it prints in the assembled reader copy at line 1321. I
re-read that copy at `/home/rod/ktd-author-gate2/scratch/report-reader-build/`
to confirm it.

## 5. The form I would fold

Body:

> Eighteen sources follow.

Then the list, with entry 17's own "Unpublished." line doing the work
the third sentence does now.

Document control or the tracker takes the status count and the Ranneberg
note. That is where PL12 sends them.

If the room wants a status sentence in the body, it reads reader-facing:

> Seventeen of the eighteen entries carry a DOI or a live public source.
> The eighteenth is unpublished.

That states provenance for the reader. It does not state the procedure
of the room. The wording call is @author's at the fold.

## 6. One thing the line does not say

Only 11 of the 18 entries are cited in the body: [1] to [10] and [18].

Entries 11 to 17 carry no in-text call at all. Read 2018, Joshi 2025,
Aull 2020, Joshi 2023, Weber 2021, Jamieson 2012 and Hancock 2024 never
appear outside the list.

The section opens "A bracketed number in the body points at its entry
here." Seven entries have no such point. A formal release will draw the
question.

Two ways to close it. Cite each one where it belongs, or cut the seven.
Cutting moves the count line to eleven, and the Hancock sentence goes
with it.

This is a room call. I do not fold it here.

## 7. The item-5 leg

The item-5 printed forms closed at this seat on 2026-10-14, receipt
`science-validator-2026-10-14-item5-counterread.md`, and the queue
records the close at `d0679d3`. Nothing in that leg moves here.

## Handoffs

- @author: the fold keys on section 5. Residual (b) is one line out of
  the body either way.
- @science-writer: if the seven uncited entries are cut, the count line
  and the Hancock sentence move together.
- @hermes: PL12 reads as run. The count verifies; the fold is the
  author's.

## 8. Addendum, same day: both residuals are ruled at `5547aba3`

@author's gate 2 commit rules both.

C17 drops "The founder dropped the Ranneberg entry." from the reader copy.
C18 keeps all eighteen entries and states that entries 11 to 17 stand as
further reading. That answers section 6 without cutting verified sources,
which is a better call than either option I offered there.

I re-read the assembled copy the seat built at 16:09 to confirm. It reads
0 founder hits and 0 Ranneberg hits, and the C18 sentence prints at line
1315.

One item stays open, and it is a draft fold rather than a strip site.
"Seventeen carry verified sources." still prints in the reader copy at
line 1319, because the draft is untouched at `5547aba3`. It leaves when
the draft next moves. It needs no C-site, as @author ruled.

## 9. Note: the list now reads nineteen, and the arithmetic still holds (2026-11-17)

Option A landed after this read. `references.bib` at `92a51cfa` holds 19
entries, and `tveide2026samara` joins Hancock in the unpublished class.

The count reads 19 = 17 verified + 2 unpublished. Section 2 above records
the eighteen-entry form, which was correct at v0.92. The two forms read as
a date, not a drift.

Two spellings need one owner. The `.bib` note reads "Private communication
with the author, November 2026". The printed entry and section 10 read
"private communication". One surface should win before the fold.

And the `.bib` note carries the phrase "the two new results". The
validation record at
`docs/validation/trpt-reference/12-tallak-tveide-pyramid-nov-2026.md`
says the peak-torque identity is "algebraically identical to Tulloch
(2021) (4.31) at (4.34)". So "new" is not a claim that record supports.
The note should read "the two results" until the joint short note states
the literature check. A note field is a field a style can render, so this
is one manifest line away from printing.

science-validator, 2026-11-17.
