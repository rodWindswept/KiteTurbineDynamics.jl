# Register status: the scaling ladder

**Slug** `scaling-ladder`. Status note for the close plate.
**Date** 2026-10-16. **Script commit** `4ebc385`.

## Rows cited

No register row binds this plate. Every drawn element resolves to the
value-claims ledger section 4. No measured value prints and no screen
value prints.

| Element | Class | Binding |
|---|---|---|
| the validated rung, 5 kW | `capability` | the campaign dataset and the register (ledger section 4) |
| the six rungs above, 7 to 50 kW | `target` | `programme target — no repo artifact` (ledger section 4) |

The counter-read boundary: no drawn string carries an NR token. The
claims to verify are the class split and the plain label against the
ledger section 4.

## Drawn precision

- The rung labels print integer kW forms from the code set: 5, 7, 10,
  15, 25, 35, 50.
- No other number prints. The stamps carry the seed commit and the
  script commit.

## Checks at GENERATE

All 14 in-script checks pass at `4ebc385`. The record covers the rung
set from `const RUNGS`, the ledger class split, the plain label, the
two committed-blob checks, and the guard checks: no register-row
token, no cost or carbon token, no proof-claim token. `checks.log`
holds the full record.

F-REPRO: three runs at the same stamp stay byte-identical across all
five outputs. The three locations are the kit and two scratch outdirs.
The md5 table sits at `scratch/fig_sl_repro.md5`.

F-LABEL: the self-check passes. The ledger carries every drawn string
(19 strings).

## Output pins (this build)

| Output | md5 |
|---|---|
| scaling-ladder.svg | 7e06bcd66f3121de8ae98bcfffce2c19 |
| scaling-ladder.pdf | 8b37e279705796baa6817b7160f21648 |
| scaling-ladder.png | 980095003b092491961b52607f74f2b4 |
| label-ledger.txt | 366986edc98647ca2ca8fe7a9025e263 |
| manifest.json | 10709a9b7b53c136fd3833105b75dc9a |

## Validator gates

The counter-reads read next: @aero-validator (the ledger owner) and
@science-validator. The visual pass by Rod follows. Any render or pin
move needs a fresh pass.

## Reproduce

Command:
`/usr/bin/python3 docs/reporting/figures/scaling-ladder/scaling-ladder.py --script-commit 4ebc385`

Toolchain pin: CPython 3.12.3, matplotlib 3.10.8, numpy 2.4.4
(`/usr/bin/python3`). The manifest pins the two input records and the
output hashes. Self-check: two consecutive runs stay byte-identical.
The run log sits at `checks.log`.

**Delta** v1 (2026-10-16): created with the kit landing. The rungs draw
from the ledger section 4 seed at the class split the room agreed.

**Delta** v2 (2026-10-18): the ledger input pin re-pins (aero
counter-read receipt `88a1027`). The value-claims ledger 3a addendum
moved the ledger blob from `3160aed8…` to `2f169ebe…`. Section 4, the
plate's only drawn region, reads byte-identical to the seed, so a
regenerate at today's HEAD passes all 14 in-script checks and writes
the four plate outputs byte-identical to the shipped bytes. Only the
manifest pin line moves. No plate byte moves.
