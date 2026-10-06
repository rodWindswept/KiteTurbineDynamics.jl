# Floor-charge static cert: coded == target at both live tips (2026-10-06)

Author: science-validator. Static certification of the landed floor charge (`betz_cp_floor_kw`, `src/objective_evaluator.jl`) against the pre-registered target column. Tips: fold `dddd776`, bank `d24d4ce`. No ODE run.

## Verdict

- All eleven rows match. Coded equals the pre-registered target at four decimal places. Largest gap 4.65e-05 kW.
- The charge identity holds to 2.2e-16 relative: `coded == basis * cos(elev)^1.65 * cosd(bank)^1.65`.
- The basis column stays as recorded before the landing. Largest gap 5.0e-05 kW.
- Both tips read identical rows. `src/objective_evaluator.jl` md5 `f7d5470865b84aeb726683a612a94c67` at both tips.
- Fold-line check: `seed_genome(5.0) == S2_FOLD_SEED`. The winner-CSV construction equals it with 0.0 difference.

## The rows (kW)

| case | coded | target | gap | vs bar 4.0 |
|---|---|---|---|---|
| trio r1.24 b1.00 | 4.2195 | 4.2195 | -0.00003 | PASS (+0.2195) |
| trio r1.30 b1.00 | 4.4116 | 4.4116 | -0.00001 | PASS (+0.4116) |
| trio r1.28 b0.95 | 4.1183 | 4.1183 | +0.00004 | PASS (+0.1183) |
| CTRL S2 fold n=3 | 3.6757 | 3.6757 | -0.00004 | under (-0.3243) |
| FAM n=3 | 3.6757 | 3.6757 | -0.00004 | under (-0.3243) |
| FAM n=4 | 3.5248 | 3.5248 | -0.00005 | under (-0.4752) |
| FAM n=5 | 3.5361 | 3.5361 | -0.00002 | under (-0.4639) |
| FAM n=6 | 3.6258 | 3.6258 | -0.00005 | under (-0.3742) |
| FAM n=7 | 3.7617 | 3.7617 | -0.00001 | under (-0.2383) |
| FAM n=8 | 3.9316 | 3.9316 | +0.00004 | under (-0.0684) |
| FAM n=9 | 4.1319 | 4.1319 | -0.00004 | PASS (+0.1319) |

Bar stays at 4.0 kW. The fold class sits under it for n=3..8. n=9 clears. The trio rows clear.

## Scope

- The cert covers the single-rotor class in play. The aero-worker audit (2026-10-06) flagged the expansion-annuli charge shape for a guard-note close-out.
- The floor shape lives in scratch probes only. A static pin beside the §6 tests rides the test-list refresh, claimed by software-worker.

## Evidence

- Probe `scratch/sv_cert_floor_match.jl`, sha256 `9ee1644261628fe11d58ca04b2976988f4e3c5ee2385b3b349fbf02a0a3eece7`.
- Logs `sv_cert_floor_match_fold_dddd776.log` and `sv_cert_floor_match_bank_d24d4ce.log` under `.julia_depot/logs/`.
- Each run used a clean detached worktree at the tip under test. Both runs printed src dirt clean.

## Rerun

- `bash scripts/ktd-julia scratch/sv_cert_floor_match.jl` from a worktree at the tip under test.
