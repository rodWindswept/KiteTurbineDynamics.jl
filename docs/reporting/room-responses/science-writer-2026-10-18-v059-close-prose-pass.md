# Science-writer receipt: the v0.59 close prose pass, the direction paragraphs, and the pinned long-paragraph, 2026-10-18

**State.**
Read at `0d9a375` (local == origin, branch `bank-derate-cos2p65`, tracked tree clean).
This receipt closes the prose-pass desk item from the value-prop track.
It covers three things: the shipped v0.59 close, the three direction paragraphs from the author supply, and the one STE hit the author could not pin.

## 1. The shipped v0.59 close

The shipped close applies every routed fix.
The label reads `No sentence in it cites a register row.`
The rung list reads `7, 10, 15, 25, 35 and 50 kW`.
No `yet`, no `first`.
The words `follows` and `stay in the record` are in.
The shipped close reads **164 words** on both the whitespace and the ste-lint tokenizer.
The correction from the author said 168.
The 4-word delta is theirs to reconcile.
Nothing turns on it.

STE on the extracted close: **1 hit (long_paragraph) at 0.61/100w, 0 em dashes**.
The same 164 words with the hard wraps removed read **0 hits at 0.00/100w**.
The probe file is `scratch/sw_v059_close_unwrapped.txt`.
The hit is a line-wrap artifact, not prose.
ste-lint splits sentences per physical line.
A sentence that ends at a wrap point leaves a fragment.
That fragment counts as one more sentence.
The targets paragraph wraps four times after sentence ends.
It counts 7 sentences where it holds 4.
The declared +1 from the author is this artifact.
The same mechanism inflates the pre-fold baseline too.
The fold needs no prose fix.
The fold may pre-join wrapped lines before the STE count.
Or the fold may keep the declared +1.

## 2. The direction paragraphs (author supply, ledger section 3a)

The pass script reads `scratch/sw_v059_directions_pass.py`.
Results on the three paragraphs: **103 words, 0 hits, 0.00/100w, 0 em dashes**.
Sentences per paragraph: 2, 3, 4.
All sit at or under the four-sentence ceiling.
The only numeric tokens are `60` (target-class, plan probe) and `2.3` (the section pointer).
No NR token.
No cost or carbon token.
No marketing or aspiration hit on the 50-word list.

Two catches the fold must apply.

1. **The row count.**
`Its three longer rows read below the power floor.`
NR-027 signs six rows: 18.8, 21.2 and 25.0 m, two rounds each.
The 18.8 m rows read below the floor too.
The count of three is wrong on both axes.
Fix: `All six rows read below the power floor.`
2. **The room.**
`so the room can study multi-rotor and expansion-class machines` uses a house term.
`the room` appears nowhere in the draft.
Fix: `so the pipeline can study multi-rotor and expansion-class machines.`

Taste set, author call.
`lands with tests` to `ships with tests`.
`The length study` to `The axial-length study`.
The plan document names it.
Structure: if the capability pair merges into the instrument paragraph, that paragraph reaches 8 real sentences.
It then earns a real long_paragraph.
Keep the new paragraphs separate.

## 3. Three open lines

- The label sentence names two movements.
The third paragraph adds a record movement.
Proposed label: `It states what the instrument does, the programme targets, and what the signed record shows.`
The binding sentence stays untouched.
Author call.
- `base length` is a fresh noun for the 18.8 m operating length.
It has zero hits in the draft.
The close cannot print the digit, so it needs a noun.
The phrase reads clearly against section 2.3 and NR-015.
@aero-validator, bless or replace.
- The word-count delta in section 1.

## 4. Handoffs

- @author: the two catches fold as given.
The taste set and the label line are yours.
The two scripts stand as fold-callable checks: `scratch/sw_v059_close_prose_pass.py` and `scratch/sw_v059_directions_pass.py`.
- @science-validator: no signed cell, no NR token, no repeated display form in either text.
The register has nothing to do here.
- @aero-validator: the `base length` line in section 3.
