# FEEDBACKBOT3: room routing v1 (2026-10-22)

**Source** `FEEDBACKBOT3.docx` (the founder review copy, 2026-10-22)
against draft v0.87, data commit `dd3cc6a`, HEAD `2661194`. This record
holds the round-1 findings the room checked in the repo. It holds the
plan v2 phases, the founder calls, and the seat lanes. Status keys:
VERIFIED, ADJUSTED, FALSIFIED, OPEN, CALL.

## A. The feedback claims, checked in the repo

| ID | Claim | Check | Result |
|---|---|---|---|
| FB-1 | The objective minimises mass. Power is a gate | `objective_v12.jl:89`, `run_v13_5kw_masslift.jl:153,156` (`p_floor_kw = p_ceiling_kw = 5.0`, `penalize_ceiling = false`) | VERIFIED. The winner is the lightest machine that clears 5.0 kW. It sits at the 6.3rd percentile of the 508 feasible by power |
| FB-2 | Blade roots carry no gate | `trpt_optimization.jl:1106` `min_fos_blade_root = Inf`. No gate reads `CFRP_BLADE_SIGMA_YIELD_MPA` | VERIFIED |
| FB-3 | Bridle drag omitted | the bridle loops read `expansion_blade_geo` only | VERIFIED |
| FB-4 | The 1.07% gap has an open source | `sim_frame.jl:133`. k = 2.24 W/(rad/s)³. 2.24 x 13.3325³ = 5308.63 W. (13.38 / 13.3325)³ = 1.010726 | ADJUSTED. The gap is the register two-decimal omega. Jensen never enters |
| FB-5 | delta-alpha* lacks a derivation and ignores n_lines and min radius | `src/trpt_twist_limit.jl` (Tulloch 4.34, Case A/B, Fig 5.25 checks). S1 98.859083 degrees reproduces to 6 dp | FALSIFIED on two of three counts. The real defect is the draft silence. Phase 0 doc fix |
| FB-6 | The bow has no asymptotic bound | `scratch/av_b21_bow_bound_check.log` (2026-10-20). Asymptote 0.837 m against the 1.5 m floor | FALSIFIED. The number exists but sits unsigned. Phase 1 sign-off |
| FB-7 | The warm-path fix sits unverified | `NR-013 ext2` (register line 1932, signed). All three winners reject. FoS 0.154 / 0.439 / 0.593 | ADJUSTED. The fix verifies negative. The draft Next Step 1 must go |

## B. What the room found that the feedback missed

| ID | Find | Site |
|---|---|---|
| RF-1 | P_kw is shaft power at the PTO input. No drivetrain model exists | `sim_frame.jl:133` |
| RF-2 | Two omegas describe one machine. omega_eq 10.16982 against the ODE 13.31 to 13.33. Factor 1.311, unsigned | NR-016, NR-029, NR-030 |
| RF-3 | The k-sweep reads the pick as under-loaded. 7.998 kW at k 2.24 against 8.951 kW at 4.0, minus 10.7%. The plateau k 4 to 9 sits flat at 0.040% | NR-041 |
| RF-4 | The k law is closed form. k proportional to s times r^5. The s² term in the code is deliberate ballast. Without it blade_scale collapses to zero. The fix needs an anti-collapse gate | `objective_v10.jl:540` |
| RF-5 | Masked PCA. PC2 17.3 to 12.0%. PC1 22.4 to 24.6%. 739 of 930 carry two dead genes. x1 reads rho(P_mean) -0.78 against rho(fitness) +0.07 | dd3cc6a telemetry |
| RF-6 | NR-061 covers 201 rejects. The 11 twist rejects sit outside every class | telemetry |
| RF-7 | The cone census signs 22 degrees as-implemented. At the 11-degree reading 98 of 506 exceed the shaft. `taper_start_z` clamps silently instead of rejecting | `objective_v10.jl:260-262` |
| RF-8 | `round(beta_rate_max)` selects the control mode. `imu_reliable` reads a reserved gain. `start_mode` defaults :warm | `ring_forces.jl:109`, `objective_evaluator.jl:695` |
| RF-9 | The extractor misses `NR-013 ext2`. The child blocks never entered scope. The Status column clips | `build_draft_pdf.py:245-262` |
| RF-10 | The 212 FoS = Inf rows are the rejection placeholder. They are not the blade-root stub | telemetry |

## C. The plan, v2

**Phase 0 - report repair, zero compute.** Strike draft line 982. Fix
"electrical power" (line 333). Reword the winner claims. Render ext2.
Set the child-block scope. Fix the widths.

Extend NR-061. Add the delta-alpha* note and the two-omega note.
Harmonise the rounding. Place the refs. Fill the nomenclature.

**Phase 1 - re-analysis of dd3cc6a, zero simulation.** Sign the 0.837 m
bound. Land the omega-basis row. Land the closure row on the extract
torque. Land the masked PCA and the lever table. Build the convergence
exhibit.

**Phase 2 - winner diagnostics, minutes of compute.** Toggle gravity,
frame drag and line drag to attribute the bow. Re-read FoS at
t = 200 s. Bound the bridle drag.

**Phase 3 - model and gate code.** k proportional to s times r^5 plus
the anti-collapse gate. The blade-root gate. The dynamic clearance
gate. The taper clamp hard reject. Discrete x4 and x6.

`start_mode` as a required keyword. The mode-selector guard. The dead
constants.

**Phase 4 - one new campaign, after the founder calls.** The load law,
the objective form and the gene masking land first.

## D. The founder calls

1. The power basis. Shaft or delivered. At eta 0.94 the winner reads
   4.990 kW and 36 of 508 rows leave the set.
2. The objective form. A power value term, a banded ceiling penalty,
   or keep it and reword every claim.
3. The cone convention. Half-angle or full-apex. The taper clamp
   reject lands either way.
4. The appendix scope. Carry the child blocks or cite them.
5. The scratch keep rule. Signed rows cite probe logs inside the
   953 MB.

## E. The seats

- @aero-validator: blade-root gate, bridle-drag bound, 1P and
  torsional-frequency check.
- @science-validator: k law and anti-collapse gate, omega rows, masked
  PCA, lever table, delta-alpha* note.
- @aero-worker: 0.837 m bound sign-off, NR-061 extension, t = 200 s FoS.
- @software-validator: extractor grammar and widths, ext2 render,
  start_mode, discrete genes, hygiene sweep.
- @hermes: this routing record and the plan tracker.

## In plain English

The room checked the feedback against the repo. Two of its claims
fell. The twist-limit derivation exists. The bow already holds a bound
in our own logs.

The real finds sit deeper. The objective presses the winner onto the
power floor by construction. The reported kilowatts carry no
drivetrain. The settle solve predicts a speed a third below the one
the ODE holds.

Five calls wait for the founder. Nothing computes until the load-law,
objective and masking rulings land.
