# Room response: SV5, NR-042 signed and the margin block (2026-10-13, science-validator)

**Status** This seat signs NR-042 into the register. The SV5 margin block lands with it, for the author and the science-writer. **Seat** science-validator. **Read at** HEAD `a7c4dc2`. Committed bytes plus a fresh knob re-run.

## 1. NR-042: the clearance row, signed

The aero seat answered W7 and proposed the row. This seat signs it under SV5. The register block carries the full basis. The value chain:

- Winner clearance at decode: `5.468123977660059` m (extract log line 11, sha256 `7579e84a...`). Gate floor: `1.5` m (runner `:76`). Margin: `+3.968` m, `3.65` times, `+264.5` per cent.

- This seat re-ran the knob probe at `a7c4dc2`. The output equals the aero run and the earlier `e0b8a92` run, line for line. Log: `scratch/sv_w7_knob_rerun_2026-10-13.log`.

- Both decode forms round to the stored telemetry `5.47` (island 3, generation 26, index 9).

- The F3 note can cite this row for the "≥ 1.5 m" string.

## 2. The SV5 margin block

The gate-margin column takes these figures (SW2d). Every figure comes from a signed row or a proportional derivation. The recipes sit under the table.

| Gate | Winner vs gate | Margin | Row |
|---|---|---|---|
| Power floor | 5.314 vs 5.0 kW | +0.314 kW / +6.28 per cent | NR-008 |
| Structural FoS | 14.972 vs 2.5 | +12.472 / +498.9 per cent, 5.99 times | NR-009 |
| Clearance | 5.468 vs 1.5 m | +3.968 m / +264.5 per cent, 3.65 times | NR-042 |
| S1 twist | 33.95 vs 98.86 deg | +64.913 deg / +65.7 per cent, 2.91 times | NR-022 |
| S1 torque | 396.79 vs 805.01 N·m | +102.9 per cent above unity, 2.03 times | NR-040 |

Recipes:

- Power: `5.314113662272673` (NR-008, P_end) minus `5.0` (runner `:153`). The percent reads the margin over `5.0`.

- FoS: `14.971791422208508` (NR-009) over `2.5` (runner `:155`).

- Clearance: `5.468123977660059` (NR-042) minus `1.5` (runner `:76`).

- Twist: `98.85908296054023` minus `33.94561934829036` (NR-022, S1). S1 carries the least of the five. The other four read 65.047, 65.180, 65.312 and 69.821 deg.

- Torque: `805.0097155967861` over `396.791634149159` (NR-040 recipe, S1).

Checker: `scratch/sv_sv5_margins_check.py` and its log. All quoted forms gate OK from the committed bytes.

## 3. The corrected cells, for section 3.3 (AU9)

Fold these once with the SW2d margin column.

- Clearance outcome: "pass, 5.468 m, margin +3.968 m". The source moves to NR-042. NR-036 keeps the strip scope.

- Power floor outcome: "pass, P_end 5.314 kW". The margin reads on the gate operand: +0.314 kW, +6.28 per cent.

Note for SW2d. The power pair in the plan, +0.309 kW and +6.2 per cent, reads P_mean. The gate reads P_end. The seam passes `P_score` to the scorer (evaluator `:1148`), and `power_stat` is `:tail5`. The corrected pair is +0.314 kW and +6.28 per cent.

## 4. The FoS display note (the aero flag)

The register now carries a display-form note on NR-015. The campaign scorer gates on `fos_hard` and takes no read of `fos_target`. A draft site that prints a plain "2.5" reads the floor. No value moves.

## 5. Evidence

- `scratch/sv_sv5_margins_check.py` and `scratch/sv_sv5_margins_check.log`: every quoted form recomputes from committed bytes.

- `scratch/sv_w7_knob_rerun_2026-10-13.log`: the fresh knob re-run at `a7c4dc2`.

- Register blocks: "Derived row: NR-042" and "Display-form note: the FoS config pair (NR-015)".

---

science-validator, 2026-10-13.
