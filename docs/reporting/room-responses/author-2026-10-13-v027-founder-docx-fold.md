# Room response: founder docx-return fold, draft v0.27 (2026-10-13, author)

**Status** LANDED. **Seat** author. **Read at** `fae5c2b`.

This pass folds the founder docx return (capture set `c2e2aee`) into the
draft. The front quarter takes the returned forms, abstract to section
2.2. The fifteen notes close as answered, glossed or routed.
No signed value changes value.

## What lands

- Abstract: the common load form, the wind basis (11.01 m/s at 9.41 m,
  NR-032), the 1 dp factor-of-safety form (15.0, NR-009), the segment
  torque margin gloss with the S1 label, the bank derate gloss, and the
  repo clause.

- Section 1: the opening rewrites and splits, the literature order, the
  blade and TRPT rewrites, "characterise them", and the constraints
  pointer.

- Section 2.1: the retitle, the line-spacer and torsional-collapse
  clause, the n_Lines and PTO additions, the blade-scale mechanism, and
  the gene-list descriptions.

- Section 2.2: the retitle, 2.2.1 The gene with the DE fold, and 2.2.2
  The evaluator.

- Tracker: the v0.27 entry, the row-19 request at section 4, and the two
  open asks at section 3.

## Answers carried by the fold

- The load law: one law for the whole set, k 2.24, one constant, one
  source (NR-015).

- The wind basis: one wind, 11.01 m/s at 9.41 m (NR-032; the trace-row
  boundary).

- "Van de Kaa and Kamp": two authors, the form stands
  (`vandekaa2021exploring`).

- "S1": the first of the five segments between the rings (the register
  labels note).

- Tube Do and wall: derived by the sizing solve, not searched. The
  design-space list stands.

## House-form adjustments named

- First person to impersonal, at the two sites.

- Typos fixed: charachterise, geneomes, two possessive forms, one
  spaced comma, and one misspelling in a query.

- "Within a minimum factor of safety is 14.9" reads "The minimum factor
  of safety is 15.0".

- "Kite Turbine" takes house lowercase.

- "quality control gates" folds as "gates", the house term.

## Receipts

- STE gate, draft: 3949 words to 4222, total 5 to 5. No category gains.

- STE gate, tracker: 1663 words to 1785, total 10 to 10.

- Token diff, draft: declared and asserted. Add: 11.01, 9.41, 15.0, 27,
  19, 2.2 x2, 1, 2. Remove: 26, 14.972, 2.3.

- Citation gate: rc=0, 31 cited rows, all signed (42 signed rows).

- Check script: `scratch/au_docx_v027_fold.py`.

## Handoffs

- The plate description rewordings ride the system-anatomy kit text
  (@fig-img-diagrams).

- The AeroDyn pre-cone gloss awaits the @aero-validator read.

- The blade-span dimension waits on its register form
  (@science-validator).

- The 2.2 renumber cascade and the conservative-floor option sit with
  @user. Each reverses in one line.

- The module-map kindred ask (Harris 2.9): this seat holds no objection
  to one schema serving both.

author, 2026-10-13.
