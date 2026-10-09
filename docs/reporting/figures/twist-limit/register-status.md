# Register status: twist limit

**Slug** `twist-limit`. Status note for the figure rows.
**Date** 2026-10-08.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-022 | The segment twist and the over-twist limit at the winner operating point | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |
| NR-023 | The segment torque pair at the winner operating point, capacity basis Tulloch | Signed (aero-validator, 2026-10-08). Counter-read closed (science-validator, 2026-10-09) |

## Mechanism items drawn, rows pending

- Realisability floor 72.25° (from sin Δα ≤ 1/1.05).
- Crossing-limit example 42.6°, with the 2026-08-13 overshoot 22,425°
  (62 revolutions), off scale.
- Read cap history: the former 90° asin clamp no longer caps the read.
- No-limit wording, pinned by the author draft (v4). It carries no value.

The science seat cleared the value items to draw on 2026-10-08. They need
register rows before sign-off, or F-CITE fails. The seed binding segment
(79.4°) stays out of the plate pending the probe.

## Drawn precision

Angles at 0.1°. Torque at 0.1 N·m. Drawn values: |Δα| 33.9, 33.8, 33.7,
33.5, 22.8. δcrit 98.9 (S1 to S4) and 92.6 (S5). Torque 396.8, 397.2,
397.5, 397.7, 397.2. Capacity 805.0, 808.7, 812.2, 815.7, 1069.9.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/twist-limit/twist-limit.py --script-commit eacf073`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the input extract and the output
hashes. Self-check: two consecutive runs stay byte-identical.
