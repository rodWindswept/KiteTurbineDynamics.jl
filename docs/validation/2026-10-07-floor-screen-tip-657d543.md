# Floor screen at the joined tip 657d543: the fold class clears under the threaded decode

Author: science-validator. Date: 2026-10-07.

Tree: `657d543` (origin/bank-derate-cos2p65, the joined tip after D4 and the
projection threading). Probe: `scratch/sv_probe_floor_657d543.jl`.
Log: `.julia_depot/logs/sv_probe_floor_657d543.log`, exit 0. Source dirt:
clean. Evaluator md5: `f7d5470865b84aeb726683a612a94c67`. Static only. No ODE.

The probe repeats the construction of the `dddd776`/`793137a` cert
(`2026-10-06-floor-charge-static-cert.md`). Rows: the three trio genomes, the
fold control, and the fold n = 3..9 family. The cfg mirrors the campaign
(p_floor_kw 5.0, bar 4.0 kW).

## Verdict

- The landed floor charge no longer filters the fold class at this tip. The
  S2 fold reads **4.6218 kW** against the **4.0 kW** bar. All eleven rows
  clear. The S2 fold clears by +0.6218 kW.
- The movement since the cert is the projection threading (`b835ebc`). The
  threaded decode resizes each machine by `1/sqrt(f)`, so each screen row
  rises. The fold row moved from 3.6757 to 4.6218 kW, a factor of 1.2574.
- The certified reading "the fold class sits under the bar for n = 3..8" is
  a pre-threading reading. The joined tip supersedes it.
- The fold passes under the charge as landed. A return to the as-coded
  charge would only raise the reading further. The launcher pick is not
  pinched by the screen in either direction.

## Rows (kW)

| row | cert `dddd776` | tip `657d543` | vs bar 4.0 |
|---|---|---|---|
| trio r1.24 b1.00 | 4.2195 | 5.1687 | +1.1687 |
| trio r1.30 b1.00 | 4.4116 | 5.4011 | +1.4011 |
| trio r1.28 b0.95 | 4.1183 | 5.0401 | +1.0401 |
| CTRL / FAM n=3 | 3.6757 | 4.6218 | +0.6218 |
| FAM n=4 | 3.5248 | 4.4296 | +0.4296 |
| FAM n=5 | 3.5361 | 4.4441 | +0.4441 |
| FAM n=6 | 3.6258 | 4.5582 | +0.5582 |
| FAM n=7 | 3.7617 | 4.7314 | +0.7314 |
| FAM n=8 | 3.9316 | 4.9482 | +0.9482 |
| FAM n=9 | 4.1319 | 5.2038 | +1.2038 |

Checks:

- Identity: `coded == basis * cos(elev)^1.65 * cosd(bank)^1.65`. Max
  relative error 2.2e-16 over the eleven rows.
- Fold-line check: `seed_genome(5.0) == S2_FOLD_SEED` true, and
  `max|seed_genome(5.0) - x_fold|` 0.0. The `x_fold` construction is the
  winner CSV with `x[1] = 4.32` and `x[9] = 1.0`, the same construction the
  cert used.
- The pre-registered target column dates from before the threading. This
  readout does not re-assert it.

## Consequence

- The screen does not block the fold seed or any fold-family row at the tip.
  The N9 and R124 companion genomes stay on the record as matched-charge
  coverage. The fold no longer needs them to pass.
- The block recorded this morning against fold-derived re-reads (the
  certified 3.6757 reading) does not hold at this tip. The clamp-release
  read, 6.7951 kW on the old clamp and 6.87 to 6.89 kW as the post-D4
  estimate, can be re-flown for a live row when the room wants it.

## Evidence

- Probe: `scratch/sv_probe_floor_657d543.jl`. It is the cert probe with the
  stale target column dropped.
- Log: `.julia_depot/logs/sv_probe_floor_657d543.log`, exit 0, tree
  `657d543`, src clean. The run used a clean detached worktree at the tip,
  removed after the run.
