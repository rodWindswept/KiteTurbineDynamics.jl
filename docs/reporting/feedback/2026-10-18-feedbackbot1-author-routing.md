# FEEDBACKBOT1: author routing (2026-10-18)

**Source** `scratch/report-pdf-build/FEEDBACKBOT1.docx` (the founder's
review copy) plus the room's routing pass. This record is the author
seat slice. It captures every author-side note with its disposition.
Status keys: LANDED, OPEN, GATED, CALL, OTHER-SEAT.

## A. The display pass (landed)

| ID | Item | Disposition | Gate |
|---|---|---|---|
| A-1 | k-sweep: two tables merge into one 6-row table | LANDED | NR-047 signed |
| A-2 | genome table: x4 and x6 duplicate bounds drop from the Meaning column | LANDED | none |
| A-3 | column widths: gate table, failure ledger, winner table, config table | LANDED | none |
| A-4 | figure provenance: the all-same Era column drops, noted once | LANDED | none |
| A-5 | appendix hash block: replaced by one pointer to the kit manifests | LANDED | all 39 pins verified in the kits first |
| A-6 | k bracket `[2.24 holds a register row...]`: resolves on NR-047 and NR-015 | LANDED | both rows signed |
| A-7 | Daisy bracket: resolves, the close quotes no Daisy value | LANDED | none |

## B. The prose pass (open, with @science-writer)

| ID | Item | Disposition | Gate |
|---|---|---|---|
| A-10 | staccato cadence: group the single-sentence paragraphs into topic paragraphs, front matter to §2.6 | OPEN | prose pass |
| A-11 | abstract and summary near-verbatim: split the roles, scorecard the decision metrics | OPEN | prose pass |
| A-12 | front-matter clutter: provenance box, muted NR tags | OPEN | prose pass |
| A-13 | literature review: two paragraphs, citation keys and years, the gap statement | OPEN | gated on the §7 bibliography build |
| A-14 | jargon moves: §2.3 history notes to §3.3, §4.2 or an appendix. Winner results leave Methods | OPEN | prose pass |
| A-15 | repeated winner metrics: one authoritative table in §3.3, cite it after | OPEN | prose pass |
| A-16 | failure-ledger prose duplication: table plus thematic takeaway | OPEN | prose pass |
| A-17 | claim calibration: "winner" and "viable" language across §1 to §5 | OPEN | prose pass |
| A-18 | §5 close: the self-reference sentence and the Daisy first-use | OPEN | prose pass. The 295-word census holds until the pass runs |
| A-19 | minor wording fixes: the two missing nouns, the ext2 note, the pick shorthand, the operand read, the file paths, the symbol formatting, the generation count | OPEN | prose pass |

## C. Placeholders (open, shared)

| ID | Item | Disposition | Gate |
|---|---|---|---|
| A-20 | §3.4 to §3.6: the levers, the evolution story, design implications | OPEN | gated on the phase landscape extracts and the strip value lists |
| A-21 | §6 Nomenclature: the [PENDING] block | OPEN | gated on the Track D glossary |
| A-22 | §7 References: render `references.bib` as a bibliography | OPEN | gated on the builder bibliography route |

## D. Cross-seat items

| ID | Item | Disposition | Gate |
|---|---|---|---|
| A-30 | inline placement and figure numbers (fig F-23) | OTHER-SEAT | builder and author seats. The figures seat verifies embeds after the rebuild |
| A-31 | inline source strings against plate footers (fig F-24) | OTHER-SEAT | kit manifests are the ground truth |
| A-32 | register appendix: Status column collapse, Source width, thematic grouping, the uncited-rows note | OTHER-SEAT | builder and register seats |
| A-33 | `scaling-ladder`: inline roadmap or scaling-law chart (fig F-22) | CALL | founder call pending. The seated plate holds |
| A-34 | six-class fold: §3.1 and §5 read 29, 3, 3 against the signed 30, 3, 2 | GATED | signed row in the register. The @science-writer consistency pass is the second input. The pre-named fold route stands |

## Working order

1. The display pass lands first (this commit).
2. The prose pass runs with @science-writer: A-10 to A-19 together.
3. A-20 to A-22 unblock as their gates land.
4. A-34 folds when both inputs exist. Nothing above it blocks it.

## In plain English

The review asks for two kinds of author work. The table work landed
today. The prose work is one shared pass with the science writer:
group the short sentences, de-duplicate the front matter, move the
internal history out of Methods, and calibrate the claim language.
The pending sections and the references unblock as their own gates
land. One call still needs the founder: what the scaling ladder
becomes.
