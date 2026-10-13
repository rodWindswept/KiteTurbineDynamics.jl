# Feedback round 2: author seat plan

**Date drafted:** 2026-10-13

**Seat:** `@author` (draft prose, structure, folds)

**Source:** `docs/reporting/feedback/feedback-on-report2.md`, landed 2026-10-12 23:10, 18 parts.

**Instruction:** the user asked every seat to read the complete set of recommendations and prepare plans for its own parts. Save the plans for execution.

## Coverage

I read all 18 parts of the feedback document.

This plan covers the drafting work for this seat.

The parts: 1, 2, 5, 6.1, 6.3, 8, 9, 10 and 11.2.
Further parts: 11.4, 12, 14, 15, 16 Priority 4 and 17.

A map at the end lists the parts that sit with other seats.

## Already landed from this seat (context, not new work)

- The window sweep: draft v0.24 (`9ab7dd4`). The remaining seven old window-term instances read "measurement window".

- The section 3.3 order pass: draft v0.25 (`99d09a1`). Order only. No token moves.

- The SW1 score-term fold: draft v0.26 (`d91b93b`). Five prose sites take "kg-equivalent". Physical mass keeps "kg".

- Two section 3.3 gate cells routed here by the register review of the plates. They fold with the margin column (AU9).

## Work items

### AU1. The front summary (parts 1, 12 and 17)

Part 17 calls this the single biggest improvement. Part 1 adds the findings bullets, and part 12 adds the limits paragraph.

- Work: one front block after the abstract and keywords. It carries the summary, five or six findings bullets, and the limits paragraph.
- Grounds: the register already signs every cited row (NR-001, NR-002, NR-005, NR-006, NR-008, NR-009, NR-018, NR-021, NR-022, NR-040).
- Acceptance: the STE gate holds, the token diff lists the added numerals, and the citation gate stays green.

- Readiness: ready to draft. The placement takes a room bounce.

### AU2. The claim and evidence matrix (part 2)

The feedback asks for the eight-row matrix in the introduction or an early appendix.

- Work: this seat drafts the matrix from the feedback table.
- Deps: `@science-validator` audits it (SV2). The model-boundaries row cross-refs the A-table IDs from AU4.

- Readiness: draft now. The audit follows.

### AU3. The wording set (parts 6.1, 6.2 and 14)

One pass, one sweep. The targets:

- Section 2.1: the polygon sentence takes the active-rotor form (6.1, 14.5).
- Section 3.3: the blade-scale slots sentence and the bank slots sentence (6.1, 14.6, 14.7).
- Part 14.1: the "development-history chapter" phrase in the section 3.3 era note.
- Part 14.2: the two Daisy anchor sentences (section 2.3 and section 5). The pending form holds until the Daisy rows sign.

- Part 14.4: the seed line keeps the v0.26 form. The pass adds the fixed-seed policy sentence, checked against the runner.
- Part 14.8: the wind bullet gains the gust and turbulence exclusion.

- Part 6.2: the FoS phrase deepening rides section 2.3. This seat drafts the fuller form and requests the aero seat read.
- Part 14.3: the presumption line takes the A1 cross-ref. It lands with AU4.

- Readiness: near-ready. The NR-011 cites stay. The runner check gates the 14.4 addition.

### AU4. The boundaries block (parts 5 and 11.4)

Part 5 collects the assumptions in one table (A1 to A7). Proposed home: a new subsection 1.3, "Scope and assumptions".

Part 11.4 turns the section 4.3 boundaries into a risk register. The rows carry the current treatment, the impact, and the next action.

- Cross-links: part 14.3 cites A1. The A6 wording tracks the W5 fix or drop branch. The blade row cites PRD 0006:147.

- Readiness: draft-ready. The section 4.3 rows need a source check against the pinned boundaries text. The placement takes a room bounce.

### AU5. The campaign table extension (part 6.3)

The section 2.4 table gains the DE parameters.

- The seed policy pins to the runner (`scripts/run_v13_5kw_masslift.jl`).
- Cells without a signed base stay out or carry the pending note. New signed values route to `@science-validator`.

- Readiness: gated on the runner and register source pull.

### AU6. The pending sections (parts 8, 9, 10 and 16 Priority 4)

Sections 3.4, 3.5 and 3.6 take provisional content now, with honest pending notes.

- Section 3.4: the rename to "Winner margin evidence" lands (option A). The option B paragraph lands with the margin numbers at SV5.
- Section 3.5: the evolution narrative lands, with the read-with-convergence note and the Phase 3 pending line.
- Section 3.6: the six provisional implications land. The power margin bullet takes the SV5 operand form.

- The draft status box drops each section from its pending list as the content lands. The 16 Priority 4 renames land with the same pass.
- Readiness: partly gated on SV5 and the landscape phases.

### AU7. The discussion folds (parts 11.2 and 11.3)

- Part 11.2: the ledger table lands from SW3a. This seat keeps the narrative after it. The k-alignment values (1.94 and 5.18 kW) stay held until rows sign.

- Part 11.3: the era map placement call sits here. Proposed: beside the section 3.3 era note. The era names take the register header forms. A name with no glossary row routes to Track D.

- Readiness: gated on SW3a and SW3b.

### AU8. The structure pass (parts 15 and 16 Priority 5)

Part 15 proposes a fuller section structure. Adoption moves in stages. Each subsection lands with its own item (2.7 wind, 2.8 reproducibility, the 3.4 sub-parts). A full renumber waits for a room review pass.

Part 16 Priority 5: the v0.16 split already carries most of the build record separation. The residual items go with the structure review.

### AU9. The section 3.3 gate cells (register review routing)

Two cells wait for their bases.

- The Clearance line cites the coming clearance row (W7).
- The power-floor outcome reads "pass, P_end 5.314 kW".

- One writer: the cells fold once with the SW2d margin column.

- Readiness: gated on W7 and SV5.

## Part map (not this seat)

- `@science-writer`: parts 3, 4, 7, 11.2 (the table), 11.3 (the map), and the sweeps.

- `@aero-validator`: W1 to W8. The wind profile, the fidelity tables, the trace, the scoping.

- `@science-validator`: SV1 to SV8. The shares, the audits, the signing.

- `@fig-img-diagrams`: part 13 and 16 Priority 3. The plates and the caption forms.

- `@hermes`: routing.

## Order for 2026-10-13

1. AU1: the front summary. The feedback top item.

2. AU3: the wording set. Small and ready.

3. AU2: the matrix draft for the SV2 audit.

4. AU6: the pending sections, behind SV5.

5. AU4: the boundaries block.

6. AU5: the campaign table, behind the source pull.

7. AU9: the gate cells, behind W7 and SV5.

8. AU7: the discussion folds, behind SW3.

9. AU8: the structure review.

## Guards

- No signed value changes value. No figure moves.

- Cite signed rows only. A new value waits for its row.

- Held values stay held. The k-alignment pair and the clearance margin keep their gates.

- The STE gate runs at `--fail-above 2.0` on every commit.

- Narrow commits. One file, one writer. Receipts land in the room responses folder.

author, 2026-10-13.
