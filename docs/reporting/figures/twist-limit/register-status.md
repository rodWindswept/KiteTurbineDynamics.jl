# Register status: twist limit

**Slug** `twist-limit`. Status note for the figure rows.
**Date** 2026-10-08.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-022 | The segment twist and the over-twist limit at the winner operating point | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |
| NR-023 | The segment torque pair at the winner operating point, capacity basis Tulloch | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |
| NR-040 | The winner segment torque margins: S1 2.0288 (quote 2.03) governs, S5 2.6938 | Signed (science-validator, 2026-10-12) |
| NR-052 | The torsional-stability FoS hard constraint 1.5. The panel-B gate marks draw it | Signed (science-validator, 2026-10-15) |
| NR-053 | The realisability floor 72.25° and the crossing limit δα*. The panel-A floor line and the caption cite it | Signed (science-validator, 2026-10-15) |

The floor row signed after the 3.5 render, so the drawn floor line gains
its cite at this re-cut. The four method notes left the canvas for the
technical caption at this re-cut. The no-limit wording carries no value.

## Drawn precision

Angles at 0.1°. Torque at 0.1 N·m. Drawn values: |Δα| 33.9, 33.8, 33.7,
33.5, 22.8. δcrit 98.9 (S1 to S4) and 92.6 (S5). Torque 396.8, 397.2,
397.5, 397.7, 397.2. Capacity 805.0, 808.7, 812.2, 815.7, 1069.9.

The panel-B gate marks draw at capacity / 1.5 (NR-052): 536.7, 539.1,
541.5, 543.8, 713.3. The positions derive in-plate from the signed
constant. No numeral draws at the marks.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/twist-limit/twist-limit.py --script-commit e3d664c`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the input extract and the output
hashes. Self-check: two consecutive runs stay byte-identical.

**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption
cites NR-040 for the least torque margin. No render moves.

**Delta** v2 (2026-10-14): the 3.5 render deltas. The two changelog
notes leave; the δcrit labels re-space; the title and labels measure
against the binding limit. Script commit `671ab96`.

**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier
reads one takeaway sentence, and the tiers no longer repeat one claim.
No render moves.
**Delta** v4 (2026-10-14): the hub-name retirement (round-6 comment 1).
The top ring label reads "R6 (top)" and the subtitle reads "ground to
top". Script commit `1af63fc`. No drawn value moves.

**Delta** v5 (2026-10-18): the FEEDBACKBOT1 re-cut. Panel B draws the
FoS 1.5 gate marks (NR-052), the four method notes leave the canvas for
the technical caption, and the cited-row set gains NR-052 and NR-053.
Script commit `e3d664c`. No drawn value moves. The F-VALUE re-check keys on
the new render.
