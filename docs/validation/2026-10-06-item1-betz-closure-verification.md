# Item 1 closure: the Betz projection reads green at both live tips (2026-10-06)

Author: science-validator. aero-worker asked for an independent re-read after the
winner-pack regen. This note closes the test and report condition of work-division
§6 item 1 at the revisions below. No `src/` or `test/` writes.

## Revisions pinned

- Fold line `origin/s2-fold-seed`: `0c7c456`. The earlier read was at `613f3de`.
- Bank line `origin/bank-derate-cos2p65`: `a36cfe3` (the regen commit).

## Test evidence

| revision | Betz test | Fast suite |
|---|---|---|
| `613f3de` | 49/49, both case testsets 1/1, exit 0 | 2561/2561, exit 0, 2 m 17 s |
| `a36cfe3` | 49/49, both case testsets 1/1, exit 0 | 2561/2561, exit 0, 2 m 44 s |

The test file is byte-identical at both tips. Its last change is `a82cafd`.
Logs: `.julia_depot/logs/sv_betz_proj_direct_613f3de.log`,
`sv_betz_proj_onetest_613f3de.log`, `sv_fast_suite_613f3de.log`,
`sv_betz_proj_a36cfe3.log`, `sv_fast_suite_a36cfe3.log`.

## The regenerated report reconciles with the §4 pins

| quantity | §4 pin (test literal) | report display (`a36cfe3`) |
|---|---|---|
| r_out | 4.564961043405586 | 4.5650 |
| r_in | 3.521692034600350 | 3.5217 |
| A_axial | 26.504217768378826 | 26.5042 |
| A_ZY | 22.953325894850966 | 22.9533 |

The report shows four decimals. The match holds at that precision.
The contract value A_zn = 22.530872753381963 appears in the testset only.

## Scope notes

- The regen updates all three breakdowns, six figures, and the generator stamp.
  Islands 1 and 2 carry the same regenerated stamp and fresh BETZ BASIS blocks.
- Two live records still carry the old RED state: work-division §6 row 1 and
  test_list rows 2 and 3. Both predate the two pin re-baselines (`5191465` for
  D1 sizing, `a82cafd` for the cp surface).
- The §6 acceptance pass will refresh those rows.
- The bank line lags the fold line in `src/bem.jl` docstring text only (`afc475c`
  retired the "4.1 = the Cp peak" claim). No behaviour delta. The merge resolves it.
- The A_ZY lines carry a dated "pending @aero confirmation" parenthetical from
  2026-10-02. Rod ruled the basis (2026-10-02) and the testset pins it. Numbers
  are unaffected.

STE pass 2026-10-06.
