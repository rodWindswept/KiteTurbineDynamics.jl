# Register status: the convergence two panels

**Slug** `convergence`. Status note for the figure row.
**Date** 2026-10-15. **Script commit** `0db99ac`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-002 | The status mix 508 / 301 / 110 / 11. The legend counts | Signed |
| NR-003 | Island 1 final 30.578. The caption tier | Signed |
| NR-004 | Island 2 final 30.637. The caption tier | Signed |
| NR-005 | The campaign winner 27.364 at generation 26. The star and its label | Signed |
| NR-006 | The common seed 36.109. The seed label | Signed |
| NR-036 | The search-objective label form, and the milestones. The y-axis label | Signed |
| NR-054 | The three running-best series. Panel 2 | Signed (science-validator, 2026-10-15) |
| NR-055 | The reject split 96 / 4 / 201, and the label rules. The legend | Signed (science-validator, 2026-10-15) |

The figure draws no other row. The plate carries six row values at the
legend, the seed and the star. The caption tier prints the NR-003 and
NR-004 finals. A counter-read finds them in this note.

The reject labels read in words, with no status codes and no Track
names. The subgroup-C label reads "cause not logged" (NR-055). The
split reads the power floor first: 34 of the 96 also read FoS below
2.5 (NR-055 basis). The foot note states the read order.

## Drawn precision

- The legend counts are integers.
- The seed prints 36.109 at 3 dp (NR-006).
- The winner prints 27.364 at 3 dp (NR-005).
- The axis ticks carry the scale. They are not readouts.

## Checks at GENERATE

All 22 in-script checks pass at `0db99ac`. The record includes the
status mix, the reject split and the parity recompute on all 93 series
rows. `checks.log` holds the full record.

F-REPRO: three runs at the same stamp stay byte-identical across all
five outputs. The three locations are the kit and two scratch outdirs.
The md5 table sits at `scratch/fig_cvp_repro.md5`.

F-LABEL: the self-check passes. The ledger carries every drawn string
(34 strings).

## Output pins (this build)

| Output | md5 |
|---|---|
| convergence.svg | 548102e9bdaf32866b52fd4ebb1da8b5 |
| convergence.pdf | 30e9b1487ae084a08850f934627c11fd |
| convergence.png | 27d10ab8b6fd2e57af2e4a4d9664c372 |
| label-ledger.txt | eeed92b3f544c6ff2c29719995408b6f |
| manifest.json | 54275ed84115cf80f28b1c2e06414cc5 |

## Validator gates

The counter-reads open at the seats: F-VALUE at the aero seat, the
register read at the science seat. A fresh F-VALUE runs at the
sign-off commit. Any render or pin move needs a new pass.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/convergence/convergence.py --script-commit 0db99ac`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the four input records and the
output hashes. Self-check: two consecutive runs stay byte-identical.
The run log sits at `checks.log`.

**Delta** v1 (2026-10-15): created with the kit landing. The build
carries the recorded merge of map row 16 (v47) and the NR-055 label
set.
