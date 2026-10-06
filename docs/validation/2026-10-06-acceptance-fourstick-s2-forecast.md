# 2026-10-06: Acceptance four-stick forecast for the S2 fold seed at 613f3de

Author: aero-worker. Tree: 613f3de on s2-fold-seed.
Probe: scratch/aw_acceptance_fourstick_s2.jl.
Log: scratch/aw_acceptance_fourstick_s2_613f3de.log (exit 0).

## What this probe measures

The old winner failed four acceptance checks. The 2026-10-01 inventory lists them:
A1, B6a, B6c, D. This probe measures the same four checks for the S2 fold seed.
It uses the exact harness of each test file. The constructions come verbatim from
test_gate_v13.jl, test_evaluator_v13.jl, and test_settle_drag_alignment.jl at 613f3de.

Operating point: k = 2.24 (honest), cold start, L = 18.8 m.

The probe edits no test file. It forecasts the repointed suite. It does not run that suite.

## The numbers

| stick | harness | value | assert | verdict |
|---|---|---|---|---|
| A1 | gate_design: settle 60 s/30k, relax 10 s, window 30 s | P_gen 5.579 kW, w_gnd 13.555 rad/s, clearance 5.67 m, crossed false, twist 0.354, no break | ok == true | PASS |
| B6a | run_eval: cold start, relax 5 s, window 20 s, tail5 | status ok, FoS_min 5.622 | :ok and FoS >= 2.5 | PASS |
| B6c | same eval | P_mean 5.348 kW | >= 5.0 | PASS |
| B6b | gate state hub tip | 72.71 m/s, tip_ok true | < 100 m/s | PASS |
| D | settle 30k + 20 s canonical | Pf = k·ωf³/1000 = 5.516 kW, ωf 13.504 rad/s | >= 5.0 | PASS |
| A (gap) | same leg | gap 0.265 | < 0.80 | PASS |

Margins over the 5.0 floor: A1 +11.6 %, B6c +7.0 %, D +10.3 %.
The old winner at ee6c64f read -2.2 %, -6.4 %, -3.7 % on the same three sticks.

## Sensitivity leg: the 14-D clamp in test_settle_drag_alignment.jl

The build_from_genome function in that file still clamps xr[8] and xr[10].
These are legacy 14-D indexes. On the 10-D seed this clamp rounds bank_bottom
from 7.183 degrees to 7.0.

This probe runs both legs: with and without the legacy clamp. Both results match
to the printed digit (Pf 5.515744929 in both legs). Mechanism: the S2 seed decodes
to ONE active rotor. A single-rotor build does not materialise bank_bottom.
So the clamp is inert for this seed.

The clamp stays a latent bug for any multi-rotor 10-D seed. The repoint must add
the 10-D branch before it points the file at the seed. The new branch mirrors the
xr[4] and xr[6] clamp in run_eval.

## What this forecast decides and does not decide

It does decide this: the winner repoint (§6 item 2) closes green at the fold tip.
Every check the old winner failed now clears with margin. Each measurement uses
the harness of its test file.

It does not decide these: this is a forecast, not a run of the edited test files.
The repoint itself remains open. It covers three winner paths, two analysis scripts,
and the clamp fix. The acceptance inventory record assigns the repoint to
software-validator.

One ruling can still flip this forecast. The B6 status=ok result passes the current
P_available floor gate. That gate uses the cos¹ charge. The S2 floor basis reads
4.80 against the 4.0 bar. A ruling with the cos^2.65-matched charge (about 3.78)
would hard-reject the seed in the evaluator. The Cp-convention ruling stays a no-op
at n = 3. After a82cafd, cp_bem(3, λ) equals cp_at_tsr(λ).

## Evidence on disk

scratch/aw_acceptance_fourstick_s2.jl: the probe. This record commits it alongside.
scratch/aw_acceptance_fourstick_s2_613f3de.log: full console log, exit 0.
