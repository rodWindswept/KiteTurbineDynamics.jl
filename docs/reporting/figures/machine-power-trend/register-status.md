# Register status: the machine power trend

**Slug** `machine-power-trend`. Status note for the candidate row.
**Date** 2026-10-20. **Script commit** `a1047a4`.

## Rows cited

| Row | Carries | Status |
|---|---|---|
| NR-002 | The feasible count, 508. The tightest-pass label | Signed |
| NR-005 | The campaign winner 27.364 at generation 26. The sub-line | Signed |
| NR-006 | The common seed 36.109. The sub-line | Signed |
| NR-062 | The window-end power pair. The seven island 3 forms, four of them printed | Signed (science-validator, 2026-10-18) |

The figure draws no other row. The plate prints four power forms (5.86, 5.4,
5.89, 5.31), two objective forms (36.109, 27.364) and one count (508).

Every other numeral is an axis tick or the 5 kW floor label. The floor is a
configuration knob and not a reading.

## Drawn precision

- Power prints two decimals, as recorded. Generation 6 prints 5.4.
- The objective forms print three decimals, as signed.
- No derived numeral prints: no difference, no mean and no slope.

## The floor reading, resolved by the numbers seat

The first cut called this an open read. The numbers seat closed it on
2026-10-20: the 5.00 kW value is a gate reading, not a machine reading.

- `appropriate_mass_fitness` returns `Inf` below `p_floor_kw`
  (`src/objective_v12.jl:143`).
- The evaluator passes `P_end` into that slot under `power_stat = :tail5`
  (`src/objective_evaluator.jl:1153`).
- The campaign sets `p_floor_kw = 5.0` (`scripts/run_v13_5kw_masslift.jl:153`).

The record agrees. Of 508 ok evaluations, none reads below 5.00, exactly one
reads 5.00 and the next lowest reads 5.02. The highest reads 6.33.

So the drawn band is the pass band by construction, and the one segment on the
rule is the tightest pass of the campaign: one design of 508, and its window
end sits below its own window mean. The plate labels it that way.

The plate no longer says the power is held above the floor. That sentence was
the gate speaking.

## Checks at GENERATE

All 18 in-script checks pass. `checks.log` holds the record. Five of them are
the gate checks above, so a change of floor value or a stray sub-floor row
fails the run.

The label check compares the vector text layer against `label-ledger.txt` and
fails on any difference.
