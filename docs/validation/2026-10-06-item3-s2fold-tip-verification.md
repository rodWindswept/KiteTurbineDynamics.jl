# Item 3 at the fold tip: S2 cold reproduction and the r_hub box re-verified at 613f3de

Author: software-validator (2026-10-06). Revisions: origin/s2-fold-seed = 613f3de. Reproduction record = a82cafd. Main checkout = ae7951a.

## Verdict

- **The item-3 cold re-measure exists and reproduces.** I re-ran the independent reproduction script `sv_a82cafd_s2.jl` from science-validator (2026-10-05). The copy matches the source byte for byte, sha256 `76f6cc57ec3f61f0ae561321a1964677b05d4dc61d5a9084ed0d9c36a1fee006`. The run used a clean detached worktree at 613f3de.

- **The `tight_bounds` re-centre already sits on the live line.** Commit bd5114e folds the 5 kW rung to the S2 class. It opens the r_hub box to [0.7, 7.776] m. I re-ran the bounds probe `av_probe_s2fold_bounds.jl` at 613f3de. The probe prints ALL PASSED: `seed_genome(5.0) == S2_FOLD_SEED` true, box [0.7, 7.776], blades [0.2, 1.0].

- `scripts/compute_seeds.jl` holds this content with no change from bd5114e through 613f3de. The only `src/` file difference between a82cafd and 613f3de is a comment revision in `src/bem.jl` (afc475c).

- Item 3 therefore has no measurement or code work left at the fold tip. The remaining campaign blockers sit outside item 3: the two open rulings, the §6 acceptance items, and the master merge.

## The reproduction numbers

| case | P_end (kW) | FoS | twist ratio | status |
|------|-----------|-----|-------------|--------|
| n = 3 | 5.3691 | 5.4067 | 0.3603 | ok, stationary |
| n = 6 | 5.1695 | 13.6597 | 0.3654 | ok, stationary |
| n = 9 | 5.3142 | 9.9155 | 0.3176 | ok, stationary |

The recorded copy and the re-run copy agree on every data row. The header differs only by the tree reference: `sv_s2_repro_a82cafd/s2_repro.csv` (a82cafd) against `.julia_depot/logs/sv_s2_repro_rerun_613f3de.csv` (613f3de).

## Evidence on disk

- `.julia_depot/logs/sv_s2_repro_rerun_613f3de.log`: re-run console log, exit 0, tree 613f3de.
- `.julia_depot/logs/sv_probe_s2fold_bounds_rerun_613f3de.log`: bounds probe re-run, ALL PASSED.

Rerun commands, from a clean worktree at 613f3de:

```bash
KTD_CS=$PWD/scripts/compute_seeds.jl scripts/ktd-julia scratch/av_probe_s2fold_bounds.jl
scripts/ktd-julia scratch/sv_a82cafd_s2.jl
```

## Scope

This record covers item 3 only. It moves no ruling. It does not merge the fold line into master. I removed the verification worktree after the runs.
