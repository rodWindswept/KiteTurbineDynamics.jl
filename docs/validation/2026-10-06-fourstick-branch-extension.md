# The four-stick forecast reproduced, and extended to the matched-charge candidates N9 and r×1.24

Author: science-validator (2026-10-06). Tree: `613f3de` (origin/s2-fold-seed). Probe: `scratch/sv_fourstick_branch.jl`. Log: `.julia_depot/logs/sv_fourstick_branch_613f3de.log` (68 lines, exit 0).

This note reproduces the four-stick acceptance forecast from aero-worker (commit `0c7c456`). It extends the forecast to the two genomes that survive a matched-charge floor screen. The probe edits no test file.

## Verdict

- **The control genome reproduces the delivered log to the printed digit.** Every leg and every column: A1, B6, D and the legacy-clamp leg all match (table 1). The run used my own copy of the instrument in an independent worktree at `613f3de`.

- **N9 clears every stick.** N9 is `S2_FOLD_SEED` with `n_lines` 9. It is the only committed-seed member that stays screen-clean under both charge shapes (floor record `c739348`: 5.394 as coded, 4.254 elevation-matched, 4.132 bank-matched, against the 4.0 kW bar).

- **R124 clears every stick.** R124 is the seed-55c `r×1.24` genome (radii ×1.24, blade 1.0, bank 0). It was flight-verified at 5.266/5.268 kW (`cf574a0`).

- **Either floor-shape ruling now launches on a genome with the full stick set measured**, not forecast. The n = 3 fold covers the as-coded charge. N9 and R124 cover a matched charge.

## Table 1: control parity (S2_FOLD_SEED, n = 3)

| leg | this run | aw log `0c7c456` |
|---|---|---|
| A1 | ok, P_gen 5.5793418079630985 kW, w_gnd 13.555378542834807, clearance 5.673111500084973 m, twist 0.3539783414142518, no break | identical |
| B6 | :ok, P_mean 5.34847513827761 kW, FoS 5.622119122735494 | identical |
| D | Pf 5.515744929382554 kW, w_settle 10.672891015260438, wf 13.503677332357741, gap 0.2652314460111843 | identical |
| D legacy clamp | Pf 5.515744929382554 kW | identical |

## Table 2: the two branch candidates

| stick | assert | N9 | R124 |
|---|---|---|---|
| A1 | ok | ok, P_gen 5.477028072560117 kW, twist 0.3164739371553252 | ok, P_gen 5.473523500183059 kW, twist 0.23144690602523782 |
| B6a | :ok and FoS >= 2.5 | :ok, FoS 10.028812208212758 | :ok, FoS 8.347048282718927 |
| B6c | P_mean >= 5.0 | 5.120997224805211 kW (+2.4 %) | 5.260487582573436 kW (+5.2 %) |
| B6b | tip < 100 m/s | 73.89 m/s | 78.10 m/s |
| D | Pf >= 5.0 | 5.425066265162183 kW (+8.5 %) | 5.409890685293514 kW (+8.2 %) |
| A (gap) | gap < 0.80 | 0.28664394921695335 | 0.3590269590083822 |

Machine identity. N9 builds n_lines 9, rings 9, n_active 1, r_hub 4.32. R124 builds n_lines 3, rings 8, n_active 1, r_hub 4.754994194179981. The span reads 1.4916 m, and the statics log of the re-measure matches. Clearances read 5.558878723642663 m and 5.377840732960138 m.

Both genomes decode one active rotor, so the legacy 14-D clamp stays inert. The control legs prove that.

A1 margins over the 5.0 kW floor read +9.5 per cent on both. The thinnest leg is B6c on N9 at +2.4 per cent.

## Why these two genomes

- The matched charge removes every fold row below n = 8 (elevation shape) or n = 9 (bank shape) from the screen. N9 is the smallest committed-seed move that survives both shapes. It needs no new genome commitment: one gene, `n_lines` 3 to 9, inside the standing box [3, 9].

- R124 is the strongest measured member of the seed-55c class named by the re-measure question from Rod. It stays clear of the screen under both shapes without a line-count move. Bank 0 makes the bank step a no-op.

## Evidence

- Log: `.julia_depot/logs/sv_fourstick_branch_613f3de.log`, exit 0, closing line `SV_FOURSTICK_BRANCH DONE`.

- Probe: `scratch/sv_fourstick_branch.jl`. The constructions come from `scratch/aw_acceptance_fourstick_s2.jl` (`0c7c456`) and the three fold-line test files `test_gate_v13.jl`, `test_evaluator_v13.jl` and `test_settle_drag_alignment.jl`.

- Rerun, from a worktree at `613f3de`: `JULIA_DEPOT_PATH=<main>/.julia_depot:$HOME/.julia scripts/ktd-julia scratch/sv_fourstick_branch.jl`.

## Scope

- No `src/` or `test/` writes. This record extends the forecast. The repoint itself stays open (work-division §6 item 2).

- B6c on N9 is the thinnest margin of the set (+2.4 per cent).

- This run did not cover the seed-55c siblings r×1.30 and r×1.28. They cleared the floor screen thinly (+2.0 per cent and +1.1 per cent headroom in the re-measure).

- R124 sits outside the committed seed line. Landing it as a launcher takes its own fold decision.

STE pass 2026-10-06: no numbers or findings changed.
