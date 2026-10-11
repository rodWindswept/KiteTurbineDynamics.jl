# Room response: item 1.3, torsion and the 2.5 gate (2026-10-11, software-validator)

Scope: the morning list of the lead shows this open item:
"torsion-under-the-2.5-gate (software-validator)". The Harris review §1.3
asks one question. Is torsional capacity under the 2.5 FoS gate. If it is
not, why is that acceptable.

**Result: torsion is not under the 2.5 gate in the implemented record.
Torsional capacity and twist have their own hard criteria. The winner
passes both. This seat signs the software side of item 1.3.** One policy
flag follows.

## What the 2.5 gate covers

- The campaign config sets `fos_target = 2.5, fos_hard = 2.5`
  (`scripts/run_v13_5kw_masslift.jl:155`). This follows the ruling of
  [2026-08-20] (FoS floor = minimum 2.5, DECISIONS.md). That ruling
  re-enabled the static structural gates ("gate 13") at 2.5.
- In the evaluator the value 2.5 (`fos_req`) gates beam buckling and
  tether tension (Gates 2 and 4, `src/objective_v10.jl`).

## The hard criteria of torsion, as implemented

- **Torsional collapse FoS >= 1.5.** The constant is
  `OPT_TORSION_FOS_REQUIRED = 1.5 # Tulloch torsional stability FOS
  (hard constraint)` (`src/trpt_optimization.jl:39`). The code enforces
  it per segment (`:872-882`). The evaluator uses the same 1.5 as the
  Gate 3 penalty reference (`src/objective_v10.jl:629`).
- **Geometric realisability.** No segment goes past its twist limit. The
  evaluator rejects such a state (torsional collapse detector,
  `src/objective_evaluator.jl:913, 1018`). The binding floor is 72.25
  degrees from sin(dalpha) <= 1/1.05 (DECISIONS.md:809).
- The capacity law is `trpt_torque_capacity_axial`
  (`src/trpt_twist_limit.jl:140`), Tulloch. It takes the axial force
  from the same state as the demand (NR-023 pairing).

## The winner against these criteria

- NR-023: the torque demand on S1 to S4 is 396.8 to 397.7 N·m. The
  capacity is 805.0 to 815.7 N·m. The margin is 2.03 to 2.05. That is
  1.35 times the 1.5 hard floor.
- NR-022: the twist is 33.9 degrees. The realisability floor is 72.25
  degrees. The margin is 2.13. Against dcrit (98.9 degrees) it is 2.92.
  The realisability floor is the binding limit of the three.
- The minimum margin over the table of the review is **2.03, segment
  torque, S1**. The abstract and the conclusion must quote this value,
  not NR-009 (14.972) alone.

## Why this is acceptable, and the gust point

- The value 1.5 is the hard constraint of Tulloch torsional stability.
  The raise to 2.5 was policy for the static structural metric. The same
  ruling records that the metric is uncalibrated and that the floor is
  policy, not certification. Torsion kept its own criterion from v6
  through v10.
- Gusts: the demand (tau = k.omega^2) and the tension-driven capacity
  both come from the same state. NR-023 measures the pair at one instant
  by construction. No speed-excursion probe is in the record. If the
  forum wants the number, it goes on the probe plan.

## Draft wording for the author

The phrase "FoS gate of 2.5 on 2.5" is unreadable. Those values are
`fos_target` and `fos_hard`. Write the per-class statement. FoS >= 2.5
on the structural members and the lines. Torsional collapse FoS >= 1.5.
Twist within the realisability floor.

## Policy flag

The ruling of [2026-08-20] says "all points we measure". The
implementation keeps torsion at 1.5. If the forum wants 2.5 to include
torsion, Rod must confirm this. As run, no code and no row enforces 2.5
on torsion.

Register note: if the draft states the torsion criteria (1.5, sin <=
1/1.05), they need register rows before the F-CITE gate.

This seat checked the positions at `bank-derate-cos2p65` HEAD `264a008`.
The row values are at data_commit `dd3cc6a`.

Software-validator, 2026-10-11.
