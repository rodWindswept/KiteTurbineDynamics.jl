# Register status: ring utilisation

**Slug** `ring-utilisation`. Status note for the figure rows.
**Date** 2026-10-08.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-021 | The ring check at the winner operating point. Interaction, axial share, bending share and ring FoS per checked ring | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |
| NR-015 | The operating point config: FoS gate 2.5/2.5 (a plain 2.5 reads the floor), with the capture settings | Signed (science-validator, 2026-10-08) |
| NR-060 | The R5 net-tension basis, caption only. The badge label carries no separate value | Signed (science-validator, 2026-10-18) |

The plate draws the NR-021 values and the NR-015 gate line. The caption
cites NR-060 for the R5 tension basis. The plate draws no NR-060 value.

## Drawn precision

FoS readouts at 0.001, nearest integer above 1e4. The R5 readout reads
326,974, against the row value 326974.1011237028. The topmost ring readout reads
15.033, against the row value 15.032534020684876. NR-009 carries the
window minimum (14.972) at another instant. The figure draws the capture
values only.

The campaign gate draws at utilisation 0.40, the reciprocal of FoS 2.5
(NR-015). The derivation is the plate's own FoS-to-utilisation
reciprocal, the same mechanic as the ring readouts.

The axis reads linear from zero to the unit value at the re-cut. The ring
values do not move.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/ring-utilisation/ring-utilisation.py --script-commit e3d664c`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the input extract and the output
hashes. Self-check: two consecutive runs stay byte-identical.

**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption
cites NR-015 for the gate sentence. No render moves.

**Delta** v2 (2026-10-14): the 3.5 render deltas. The log axis, the
single-bar form and the caption updates land. The readouts stand at the
drawn precision. Script commit `671ab96`.

**Delta** v3 (2026-10-14): the round-5 caption dedupe. The plain tier
reads one takeaway sentence, and the tiers no longer repeat one claim.
No render moves.
**Delta** v4 (2026-10-14): the hub-name retirement (round-6 comment 1).
The top ring label reads "R6 (top)"; the caption and record phrases
take the top forms. Script commit `1af63fc`. No drawn value moves.

**Delta** v5 (2026-10-18): the FEEDBACKBOT1 re-cut. The axis reads
linear, the campaign gate draws at 0.40 (NR-015), R5 reads a tension
badge with the combined readout, and the cited-row set gains NR-015
(drawn) and NR-060 (caption). Script commit `e3d664c`. No ring value moves.
The F-VALUE re-check keys on the new render.
