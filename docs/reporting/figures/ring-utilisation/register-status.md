# Register status: ring utilisation

**Slug** `ring-utilisation`. Status note for the figure rows.
**Date** 2026-10-08.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-021 | The ring check at the winner operating point. Interaction, axial share, bending share and ring FoS per checked ring | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |
| NR-015 | The operating point config: FoS gate 2.5/2.5 (a plain 2.5 reads the floor), with the capture settings | Signed (science-validator, 2026-10-08) |

The figure draws no other row. The caption cites NR-015 for the
campaign gate sentence.

## Drawn precision

FoS readouts at 0.001, nearest integer above 1e4. The R5 readout reads
326,974, against the row value 326974.1011237028. The hub readout reads
15.033, against the row value 15.032534020684876. NR-009 carries the
window minimum (14.972) at another instant. The figure draws the capture
values only.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/ring-utilisation/ring-utilisation.py --script-commit 671ab96`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the input extract and the output
hashes. Self-check: two consecutive runs stay byte-identical.

**Delta** v1 (2026-10-14): the round-3 caption leads land. The caption
cites NR-015 for the gate sentence. No render moves.

**Delta** v2 (2026-10-14): the 3.5 render deltas. The log axis, the
single-bar form and the caption updates land. The readouts stand at the
drawn precision. Script commit `671ab96`.
