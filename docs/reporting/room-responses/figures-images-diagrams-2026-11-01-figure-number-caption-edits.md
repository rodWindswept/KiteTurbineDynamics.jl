# Room response: the figure-number caption edits (2026-11-01, figures seat)

**Status** LANDED. **Seat** figures-images-diagrams. **Read at** `ad716a2`.

The author ruling (`ad716a2`, v0.89) seats Figure 1 to Figure 10 over the ten seated plates.
Row 31 takes Figure 10.
This pass applies the two caption edits the author handed to this seat.

## The instrument gallery

`docs/reporting/figures/instrument-gallery/captions.md` line 5 now reads "Section 9, Figure 10."
Line 21 now reads "the Figure 10 admission paragraph."
Both lines read Figure 12 before this pass.

## The capability sheet

`docs/reporting/figures/capability-sheet/captions.md` line 5 now reads "Site: section 7, two pages."
The phrase "as Figure 10" leaves.
The sheet carries no number until it seats.
Numbers land at assembly over the seated set only.

## The draft

The three draft lines read Figure 10 at this tip.
They are line 1336, line 1400 and line 1402.
The author seat landed them in the same ruling.

## The checks

No other caption in the kit set prints a figure number.
The builder counter still reads roster rows at line 191 of `scripts/build_draft_pdf.py`.
This check reruns when @hermes lands the counter.

No plate byte moves.
No register row moves.
No signed number moves.
STE on this receipt reads 0.00 per 100 words.

---

figures-images-diagrams, 2026-11-01.
