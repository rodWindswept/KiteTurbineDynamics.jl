# Floor-charge landing — verification at both live tips (2026-10-06)

Author: software-validator. Independent of the runs by @software-worker.

## Revision pinned

- `origin/s2-fold-seed` = **dddd776** (`dddd7760325bbf5b5c6eb9c7f6f0e399603cbcf6`).
- `origin/bank-derate-cos2p65` = **793137a** (`793137af278c60f3748138d131650963edbb1563`).
- Both commits change only `src/objective_evaluator.jl` (+27 / −1).
- The file md5 is `f7d5470865b84aeb726683a612a94c67` at both tips. The diff between the tips for that file is empty.
- The only other `src/` delta between the lines is a `bem.jl` docstring edit. It sits at the base tips too, and it is identical on both lines.
- I re-ran everything in my own clean worktrees: `ktd-svf-fold` at dddd776 and `ktd-svf-bank` at 793137a.

The bank line carries a local label `sw-floor-charge` at the same commit. A sweep of every other seat worktree shows no evaluator dirt. Only the two worker worktrees carry the landing.

## Gates

| Check | Measured | Evidence |
|---|---|---|
| Fast suite at dddd776 | 2561 / 2561, exit 0, 2m19.7s | `swv_fast_suite_fold_dddd776.log` |
| Fast suite at 793137a | 2561 / 2561, exit 0, 2m46.9s | `swv_fast_suite_bank_793137a.log` |
| Probe re-run at both tips | all rows pass, exit 0 | `swv_probe_floor_match_*.log` |
| Betz ceiling pins at both tips | 49/49 + 1/1 + 1/1, exit 0 | `swv_betz_tip_*.log` |
| Arithmetic re-derivation | calc == coded == target | `swv_rederive_floor_match.log` |

## The row match, re-derived

The probe reads the floor helper through the evaluator path, with no ODE work. My re-derivation computes the same value from the raw projected area alone:

`coded = cp * kfac * A_zy * cos(elev)^1.65 * cosd(bank)^1.65`

kfac reads 0.8152375. The elevation factor is 0.788725. The bank factor is 0.971262.

Every row reconciles to the printed four decimals, against the coded column and the recorded target. The fold seed reads 3.6757 kW. n = 9 reads 4.1319 kW. The r-scale rows read 4.2195, 4.4116 and 4.1183 kW. All ten rows match on both tips.

## Basis

The floor screen keeps cp 0.16, the floor-record convention. The sizing and ODE class reads 0.2955, a factor 1.85 above the screen. The bar stays at 4.0 kW. The fold class filters as predicted: n ≤ 8 sits under the bar, and n = 9 with the r-scales clears it.

## Scope

This record covers the software state: refs, file identity, suite totals, the probe reproduction and the arithmetic. The charge-shape guard sits with @aero-validator. The coded-vs-target certification sits with @science-validator. I removed both verification worktrees after the runs.

Logs sit in `.julia_depot/logs/` in the shared depot. The re-derivation script sits in my scratch at `swv_rederive_floor_match.py`. The probe copy in both worktrees matches the main-clone source byte for byte, sha256 `0901500b20c6ac41e84207160619e05d4c0467cd0a921e7adf3486b3921285d2`.
