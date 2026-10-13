# Founder docx return — note extract and dispositions (2026-10-13, author seat)

Source copy: `scratch/report-pdf-build/draft-live-rod-comments.docx` — saved 16:42:34 BST, revision 3.

Source sha256: `e6b743d278291930e7f07ffa8d34a6e939d722a83b02ef8c5b9ffc390d498ce7`.

Base copy: `scratch/report-pdf-build/draft-live.docx` — the certified review copy.

Base sha256: `2ace43735158b06ab4c461138e6bdfdc936da700c72b70a497a675b4dd94eaa9`.

Method. Both copies convert to plain text under pandoc, one paragraph per line.

The line diff sits in `au_draft_docx_notes_capture_2026-10-13.patch`.

The full returned text sits in `au_draft_docx_annotated_capture_2026-10-13.md`.

The return carries no comments and no tracked changes. The input is direct edits plus fifteen bracketed notes.

## The change set

Eleven change blocks, all in the front quarter — abstract through section 2.2.

The rest of the document carries no content change.

Two raw diff blocks hold format only — the failure list and the appendix hash lists. Bullet reflow, no text change.

Block list, in document order:

1. Abstract. Seven edit sites and six notes.

2. Section 1 opening. Family rewrites and the AWES splits.

3. Section 1. "multiple, short rigid blades" — one site.

4. Section 1. The TRPT rewrite and the objectives rewrite.

5. Section 1. Literature splits, order, and the name query.

6. Section 1. The Flather and Ranneberg splits.

7. Section 2.1. Heading retitle — "The kite turbine and its terms".

8. Section 2.1. Terms rewrite. n_Lines, the PTO ring sentence, bank and blade-scale notes, the gene list.

9. Section 2.1 figure. "lifting autogyro kite stack", "Six triangular rings", the blade-span ask.

10. Section 2.2. Assembly wording, then the retitle and the new 2.2.1 material.

11. Section 2.3 heading to 2.2.2, with the block-diagram ask.

## The fifteen notes and dispositions

Each entry holds the note in short form, the disposition this seat read, and the fold action.

1. Load query (abstract). Quote:

"was this one fixed power law gen load for the whole set or one for each candidate…??"

Answer: one law, the whole set. k 2.24, one constant, one source (NR-015).

Fold: the common-load form.

2. Wind basis (abstract). Quote:

"at wind speed rotor centre height…??"

Answer: the record holds one wind — 11.01 m/s at 9.41 m. NR-032 carries the basis. The boundary note on the trace rows states it.

Fold: the power sentence takes the basis.

3. FoS display (abstract). Quote:

"1dp resolution fine here"

Display call. Routed to @science-validator — display note, the row keeps 14.972 (NR-009).

4. Term gloss (abstract). Quote:

"Introduce term segment torque margin"

Fold: first-use gloss, capacity over demand per segment (NR-040, from NR-023). Glossary entry queued for the Track D owner.

5. Segment label (abstract). Quote:

"S1???"

Answer: S1 is the first of the five segments between rings.

Fold: the label form beside the quote.

6. Bank-derate definition (abstract). Quote:

"bank derate is a calculated depowering … due to banked blades sweeping less streamtube frontal area"

Fold: first-use gloss from the note. Glossary entry queued for the Track D owner.

7. Tube query (section 1). Quote:

"was tube OD and thickness also here or did we drop that previously??"

Answer: the genome carries no tube slot. The sizing solve derives tube Do and wall per ring (DECISIONS 2026-09-16 block, one tube authority). The slot layout lives in `src/objective_v10.jl`. The design-space list stands.

8. Constraints pointer (section 1). Quote:

"more about these constraints coming up in the report soon I hope"

Fold: a short pointer to the gate treatment (sections 2.3 and 3.3, the gate-map plate).

9. Name query (section 1). Quote:

"Van de Kamp? Surely…"

Answer: two authors, "Van de Kaa and Kamp" already reads right (`vandekaa2021exploring`). Form stands.

10. AeroDyn term (section 2.1). Quote:

"the equivalent term in AeroDyn is pre-cone..."

Routed: @aero-validator reads the equivalence before the fold installs the gloss.

11. Blade scale (section 2.1). Quote:

"more about this and how it works"

Fold: one explanatory sentence with the span link.

12. Gene list presentation (section 2.1). Quote:

"include and highlight above each gene we are referring to with a description"

Fold: one-line descriptions beside the gene list.

13. Blade span (section 2.1 figure). Quote:

"include blade span"

Routed: the span value wants its source form first. Rides the plate follow-ups (@fig-img-diagrams, register side).

14. DE loop (section 2.2.1). Quote:

"…before DE tries a new gene"

Fold: one sentence on the loop order — assess, compare, then breed.

15. Block diagram (section 2.2/2.3). Quote:

"input a systems block diagram here of the Simulation Analysis Pipeline Instrument"

Routed: a new figure request. @fig-img-diagrams mints the figure-map row. The draft takes the pointer when the row lands.

## Routed to seats

- @science-validator — FoS display note (note 3). The wind pair if a row wants it (note 2).

- @aero-validator — the pre-cone read (note 10).

- @fig-img-diagrams — the block-diagram row (note 15). The blade-span source (note 13).

- @user — the renumber cascade question below.

## House-form adjustments the fold carries

These keep house conventions and get named in the fold receipt.

- First person to impersonal. Sites: "We used Differential Evolution", "failure we made".

- Typos fixed: charachterise, geneomes, two possessive forms where "it is" slipped, "gated ,", "neam".

- "Within a minimum factor of safety is 14.9" reads as "with a minimum factor of safety of 14.9". Grammar fix only, no meaning change.

- Capitalization: "Kite Turbine" mid-sentence takes house lowercase "kite turbine".

- "quality control gates" is a form call at fold time. The house term is "gates".

## Structural note — the renumber

The return renumbers "2.3 The evaluator" to "2.2.2" under a retitled 2.2.

The downstream sections keep their numbers in the return (2.4 to 2.6).

The fold holds the local form and leaves the cascade to a structure call. The question goes to the room with this extract.

## Fold status

Not yet folded. The fold lands as draft v0.27 and gives every block and note above its response state.

This file is the per-location checklist for that pass and for the sweeps.

author, 2026-10-13.
