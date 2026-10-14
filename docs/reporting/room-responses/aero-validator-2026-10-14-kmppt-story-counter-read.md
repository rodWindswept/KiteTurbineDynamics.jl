# Room response: k = 2.24 story counter-read (2026-10-14, aero-validator)

The story-check from aero-worker (`3b8e099`) landed this afternoon. This
note is the counter-read from the aero-validator seat. It verifies the
claims in that check against the sources, adds one finding from the
structural sizing record, and flags two fold details. Read at draft v0.36.

## Verified

- The six sweep rows match `scripts/results/k_sweep_daisy_5kw.csv` value
  for value. P_mean / omega_final / FoS read: k 0.5 reject 3.485 / 19.137
  / 51.8. k 1.0 5.451 / 17.636 / 47.8. k 1.5 6.782 / 16.590 / 42.8.
  k 1.94 7.560 / 15.797 / 40.1. k 2.24 7.998 / 15.344 / 36.4.
  k 3.0 8.886 / 14.420 / 24.3.

- The tip-speed ceiling gate reads as cited. `TIP_SPEED_CEILING_MPS =
  100.0` sits at `src/objective_evaluator.jl:103`.

- The runner-comment claims verify at `scripts/run_v13_5kw_masslift.jl`:
  the 3.55 anchor (lines 116, 168), the k = 1.0 row at omega 17.6 and
  tip 85 m/s (lines 163-164), and the 5.39 anchor chosen on the broken
  machine (lines 165-168).

- The over-power penalty form verifies at `src/objective_v12.jl:114`:
  `W_OVERPOWER_KG_PER_KW2 = 5.0`, kg per (excess kW) squared, quadratic
  above the ceiling (lines 132, 152-154). That fold rides the objective
  read already open at the science-validator seat.

- The draft state claims hold at v0.36. The operating-point block carries
  the light-end and heavy-end sentences. No k table, no MPPT term, and
  the line-739 bracket still marks the missing rows.

## Addition: the sizing side of the same story

One more finding from varying the level sits in the structural record.
DECISIONS [2026-09-06] sizes the beam on a bounded generator load step at
nominal k x 2, measured on the hub segment. The low-wind lull is benign
under the load law, and the load step is the only state that raises the
torque while the tension is low. The same entry refuses k easing as the
high-wind substitute: the rotor spins up to twist 87.9 degrees against
the 78.8 degree limit. This pair belongs beside the two-side safety block
the story-check proposes.

## Flags

- Row minting: name the omega column. The sweep CSV carries omega_eq as
  0.0 on every row (cold path). The settled value reads in omega_final.
  A row that cites omega_eq prints zero.

- Era fit: the earlier MPPT x twist sweeps (`docs/NOTES_MPPT_TWIST.md`
  and the v1 and v2 CSVs under `scripts/results/mppt_twist_sweep/`) hold
  the same study on earlier machines, including a destructive-load cliff
  at 4x. The room decides whether the fold cites that era or stays with
  this campaign.

Relayed only. Nothing edited beyond this file. aero-validator
