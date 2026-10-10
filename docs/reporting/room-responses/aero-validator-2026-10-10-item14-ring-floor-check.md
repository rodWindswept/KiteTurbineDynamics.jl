# Room response: item 1.4, ring floors and the R5 read (2026-10-10, aero-validator)

Scope: division item 1.4, owner this seat, deliverable the ring table, gate
science-validator (`docs/reporting/2026-10-10-harris-review-work-division.md:20`).
Inputs: review section 1.4 (66ec6a6), the aero-worker read-only pass
(floor check left open), NR-021, and the pair-extract capture.

**Verdict. No ring sits at the OD floor. R2 to R5 sit at the wall floor.**
**The sizing FoS target binds at every airborne ring, so the search cannot
thin these tubes further. The draft reads of 15 to 35 are rated-load reads
of the same tubes. R5 carries no compression at the operating point.**

## Ring table

Machine: bankderate2 island-3 winner, 18.8 m, 3 lines, 6 rings.

Tube data: `scratch/av_probe_ring_floor_check.jl`, log under
`.julia_depot/logs/av_probe_ring_floor_check.log`.
Rated values: NR-021, pair-extract capture, final step.

| ring | section | Do mm | t mm | t/D | OD floor | wall floor | sizing N | sizing FoS | rated util | rated FoS |
|---|---|---|---|---|---|---|---|---|---|---|
| R1 | ground datum | 46.256 | 2.544 | 0.055 | no | no | 0 | n/a | not checked | not checked |
| R2 | cylinder | 14.925 | 2.000 | 0.134 | no | yes | 761.9 | 3.25 | 0.03324 | 30.09 |
| R3 | cylinder | 14.925 | 2.000 | 0.134 | no | yes | 761.9 | 3.25 | 0.03354 | 29.81 |
| R4 | cylinder | 14.925 | 2.000 | 0.134 | no | yes | 761.9 | 3.25 | 0.02838 | 35.24 |
| R5 | cylinder top | 13.383 | 2.000 | 0.149 | no | yes | 524.1 | 3.25 | 3.1e-6 | 326,974 |
| R6 | hub | 46.256 | 2.544 | 0.055 | no | no | 1131.3 | 3.25 | 0.06652 | 15.03 |

Units: Do and t in mm, forces in newtons. The rated util column carries
the combined interaction value from NR-021.

## What binds

Since R7 (2026-09-10), the beam is not a search gene. The evaluator
solves the tube from the rotor stack for each candidate
(`objective_evaluator.jl:751`, `size_beams_closed_form`).

The solve target is Euler FoS 3.25. That is the 2.5 campaign floor times
the 1.3 sizing margin (`SIZING_FOS_MARGIN`, `trpt_optimization.jl:199`).
The solve meets the target at R2 to R6. The probe prints 3.250 at every
one of those rings.

Two floors sit under the solve.

The OD floor is inert here. A re-solve with the floor lowered to 1e-9 m
returns identical sections at every ring, delta 0.000 mm. The 10 mm value
rests on a measured basis (`trpt_optimization.jl:217` comment: 6 mm fails
the 2.5 floor, 8 mm clears by 0.8 per cent, 10 mm is the lightest with
real headroom).

The wall floor is active on R2 to R5. The pinned ratio would give
0.82 mm at R2 and 0.74 mm at R5, both under the 2 mm floor
(`MIN_TUBE_WALL_M`, `trpt_optimization.jl:32`). So the wall of those
rings is a manufacturing minimum.

The wall floor sets the wall only. The diameter still solves to the FoS
target, so the ring FoS is not a manufacturing minimum.

## Why the rated reads show 15 to 35

The solver sizes against a fault envelope. The line tension carries a
1.2 margin (`TENSION_LOAD_MARGIN`, `trpt_optimization.jl:176`). The
helix charge is 1.2 times the line tension (`HELIX_LOAD_FACTOR`,
`trpt_optimization.jl:169`). The target then carries the 2.5 and the 1.3.

The upshot: the sizing charge at R2 is 761.9 N against a rated 82.3 N,
a factor of 9.26. The rated FoS is the target times that factor:
3.25 x 9.26 = 30.1. The recorded value is 30.09. The small difference is
the bending share.

R3, R4 and R6 close the same way: 9.17x to 29.81, 10.84x to 35.24, and
4.63x to 15.03.

R6 is the hub. Its solve uses the worse of the rated load and the peak
case (`T_peak`, zero speed, `trpt_optimization.jl:270`).

So the 15 to 35 band is the envelope-to-rated load ratio. It is not a
second binding constraint.

## R5

Requested: one sentence on why R5 reads 326,974. The body should write
"> 10^5 (effectively unloaded)" per the review.

Suggested reader sentence:

> R5 reads FoS above 10^5 because the axial check counts compression
> only, and R5 carries none. R5 is the top ring of the constant-radius
> run, where the widening segment above pulls it outward. Only a small
> bending share remains (3.1e-6 on the interaction scale).

Evidence. The utilisation function clamps the axial term with
`max(N, 0.0) / N_crit` (`ring_element_analysis.jl:297`). The capture
reads util_axial 0.0 and util_bending 3.06e-6 at R5.

The sizing probe shows the outward pull directly. The sizing charge at R5
is 524.1 N against 761.9 N for a pure helix value, because the kink term
of the cone above subtracts about 412 N.

## Row and text actions

Register: NR-021 keeps its values. Proposed note amend for the register
editor, gate science-validator.

> R2 to R5 sit at the 2 mm wall floor. No ring sits at the 10 mm OD
> floor. The solve meets its Euler FoS target 3.25 at every airborne
> ring. R5 carries no compression at the operating point, so the body
> writes "> 10^5 (effectively unloaded)".

Draft text, author pass: name the two floors, quote the 3.25 basis, and
keep three significant figures ("FoS 15.0", "FoS 30.1").

## Receipts

- Probe: `scratch/av_probe_ring_floor_check.jl`. Log:
  `.julia_depot/logs/av_probe_ring_floor_check.log`.
- Identity certificate against the capture. Clearance 5.468123977660062 m
  against 5.468123977660059 m. Stable dt exact at 2.8987873697672758e-5 s.
  The built ring Do vector equals the sized vector, max delta 0.0.
- Constants and lines: `trpt_optimization.jl:32, 169, 176, 199, 217,
  270, 297, 470, 482`. Utilisation: `ring_element_analysis.jl:294-300`.
  Build path: `objective_evaluator.jl:751, 759`. Ring read:
  `types.jl:243`.
- NR-021. `docs/reporting/figures/pair-extract/extract-winner-operating-point.csv`.

Aero-validator, 2026-10-10.
