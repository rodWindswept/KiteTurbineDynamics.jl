# FEEDBACKBOT1: builder routing (2026-10-18)

**Source** `scratch/report-pdf-build/FEEDBACKBOT1.docx` (the review copy
from the founder). This record is the builder seat slice. It captures
every builder-side note with its disposition. Status keys: LANDED,
OPEN, OTHER-SEAT.

## A. Builder items, landed

| ID | Item | Disposition |
|---|---|---|
| B-1 | Table typography. 8 pt sans face, hair borders, shaded header row, no row split across pages | LANDED |
| B-2 | PDF route. The table CSS sits in `scripts/build_draft_pdf.py` and lands in `draft.css` | LANDED |
| B-3 | DOCX route. The pass re-skins the pandoc Table style in the reference doc | LANDED |

The rebuild verified all 11 DOCX tables on the bordered 8 pt style. The
commit is `7ca7dbe`. No prose, figure, or register byte moved.

## B. Builder items, open

| ID | Item | Disposition | Gate |
|---|---|---|---|
| B-10 | Heading hierarchy. Section headings render at body size. Add distinct heading styles | OPEN | the reference-doc styles |
| B-11 | Title page and document-control header box. It names the author, the seat, the org, the version, and the date | OPEN | the author supplies the names |
| B-12 | Display equations. The objective function and the load law render as numbered equations, not code | OPEN | the author writes the display forms |
| B-13 | Register appendix. Collapse the Status column to one note that all rows carry a sign-off | OPEN | the 61 rows verified signed |
| B-14 | Register appendix. Widen the Source column | OPEN | none |
| B-15 | Register appendix. Group the flat rows into thematic sub-tables | OPEN | none |
| B-16 | Register appendix. Add a note that the uncited rows stay out on purpose | OPEN | the uncited set |

The register appendix items (B-13 to B-16) ride the register template in
the builder. The next rebuild picks them up. The "cite the manifest
once" ask already landed. The figure hashes cite the kit manifests. The
register full precision cites `register-manifest.md`.

## C. Register display, landed at other seats

The founder asked to round the register and drop the long strings. Two
seats landed it. It prints here so the capture is complete.

- The aero seat, commit `d498ab9`. NR-021, NR-022, NR-023 and NR-024
  round to four significant digits. NR-022 reads |Δα| and δ_crit.
- The science seat, commit `33dfe32`. Nineteen rows round to four
  significant digits. The fitness rows read kg-equivalent. NR-053 reads
  δα*.

The full precision and the probe sha256 moved to
`docs/reporting/register-manifest.md`.

## D. Uncaptured notes, now routed

Two substantive notes in the review had no seat. They route here.

| ID | Item | Disposition |
|---|---|---|
| B-20 | Section 2 omits the decoder and gate math | OTHER-SEAT |
| B-21 | Section 3.3 steady-state claim versus the shaft-bow drift | OTHER-SEAT |

B-20 covers the r_rotor sizing formula, the ring-count decode, the
twist-ratio and P_score definitions, and the full hard-gate list. The
author writes them. The science seat confirms the register rows carry
them.

B-21 asks why the shaft bow keeps drifting after speed and power
settle. It also asks the report to confirm the bow stays bounded above
the 1.5 m clearance. The aero seat verifies from NR-059. The author
clarifies the prose.

## In plain English

The table styling landed. The builder work left is the page hierarchy
and the register appendix shape. Two review notes had no owner. One asks
the report to state the decoder and gate math. The other asks why the
shaft bow keeps drifting. They route to the author and the two
validator seats.
