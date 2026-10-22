# FEEDBACKBOT3: room routing v3 (2026-10-22)

**Source** `FEEDBACKBOT3.docx` (the founder review copy, 2026-10-22)
against draft v0.87, data commit `dd3cc6a`, HEAD `2661194`. This record
holds the findings the room checked in the repo. It holds the plan, the
founder calls, and the seat lanes. v3 folds the k* torque column, the
three-way k split, and the withdrawn s² mechanism. Phases 0 to 2 need
no founder call. Status keys: VERIFIED, ADJUSTED,
FALSIFIED, OPEN, CALL.

## A. The feedback claims, checked in the repo

| ID | Claim | Check | Result |
|---|---|---|---|
| FB-1 | The objective minimises mass. Power is a gate | `objective_v12.jl:89`, `run_v13_5kw_masslift.jl:153,156` (`p_floor_kw = p_ceiling_kw = 5.0`, `penalize_ceiling = false`) | VERIFIED. The winner is the lightest machine that clears 5.0 kW. It sits at the 6.3rd percentile of the 508 feasible by power |
| FB-2 | Blade roots carry no gate | `trpt_optimization.jl:1106` `min_fos_blade_root = Inf`. No gate reads `CFRP_BLADE_SIGMA_YIELD_MPA` | VERIFIED. Scope shrinks to one bridle model with two outputs. With bridles the root bending drops about 10x (`trpt_optimization.jl:1104-1105`) |
| FB-3 | Bridle drag omitted | `aerodynamics.jl:345-351` records the lumped C_D 2.7 that absorbs the missing bridle lines. That term sits on the shaft lines, not the blade tips. The campaign ran the legacy C_D 1.0 | VERIFIED. The bound reads 932 W full line, 547 to 684 W two bridles, against a +314 W winner margin |
| FB-4 | The 1.07% gap has an open source | `sim_frame.jl:133`. k = 2.24 W/(rad/s)³. 2.24 x 13.3325³ = 5308.63 W. (13.38 / 13.3325)³ = 1.010726 | ADJUSTED. The gap is the register two-decimal omega. Jensen never enters |
| FB-5 | delta-alpha* lacks a derivation and ignores n_lines and min radius | `src/trpt_twist_limit.jl` (Tulloch 4.34, Case A/B, Fig 5.25 checks). S1 98.859083 degrees reproduces to 6 dp | FALSIFIED on two of three counts. The real defect is the draft silence. Phase 0 doc fix |
| FB-6 | The bow has no asymptotic bound | `scratch/av_b21_bow_bound_check.log` (2026-10-20). Asymptote 0.837 m against the 1.5 m floor | FALSIFIED. The number exists but sits unsigned. Phase 1 sign-off |
| FB-7 | The warm-path fix sits unverified | `NR-013 ext2` (register line 1932, signed). All three winners reject. FoS 0.154 / 0.439 / 0.593 | ADJUSTED. The fix verifies negative. The draft Next Step 1 must go |

## B. What the room found that the feedback missed

| ID | Find | Site |
|---|---|---|
| RF-1 | P_kw is shaft power at the PTO input. No drivetrain model exists | `sim_frame.jl:133` |
| RF-2 | Two omegas describe one machine. omega_settle 10.16982 against the ODE 13.31 to 13.33. Factor 1.311. The defect is the NR-016 label, not the number | NR-016, NR-029, NR-030 |
| RF-3 | The k-sweep reads the pick as under-loaded. 7.998 kW at k 2.24 against 8.951 kW at 4.0, minus 10.7%. The plateau k 4 to 9 sits flat at 0.040% | NR-041 |
| RF-4 | No fleet-wide s exponent exists. Span and chord scale in s. The annulus is linear in span. r_tip carries its own s. The s² term is deliberate ballast: without it blade_scale collapses to zero. The ballast lands on solidity, not the stated swept-area reason. The carried k proportional to s times r^5 form was never a code quantity. The law becomes exact per-row bookkeeping from the RotorSpec fields the code already builds. k = 1/2 rho A C_P(lambda, sigma) r_tip^3 / lambda^3. The fix needs an anti-collapse gate | `objective_v10.jl:360,365-366,374,377,540,548-549` |
| RF-5 | Masked PCA. PC2 17.3 to 12.0%. PC1 22.4 to 24.6%. 739 of 930 carry two dead genes. x1 reads rho(P_mean) -0.78 against rho(fitness) +0.07 | dd3cc6a telemetry |
| RF-6 | NR-061 covers 201 rejects. The 11 twist rejects sit outside every class | telemetry |
| RF-7 | The cone census signs 22 degrees as-implemented. At the 11-degree reading 98 of 506 exceed the shaft. `taper_start_z` clamps silently instead of rejecting | `objective_v10.jl:260-262` |
| RF-8 | `round(beta_rate_max)` selects the control mode. `imu_reliable` reads a reserved gain. `start_mode` defaults :warm | `ring_forces.jl:109`, `objective_evaluator.jl:695` |
| RF-9 | The extractor misses `NR-013 ext2`. The child blocks never entered scope. The Status column clips | `build_draft_pdf.py:245-262` |
| RF-10 | The 212 FoS = Inf rows are the rejection placeholder. They are not the blade-root stub | telemetry |
| RF-11 | The bridle-drag bound. 932 W full line at d 3 mm and C_D 1.2. Two bridles 547 to 684 W. The bound is 1.7 to 2.2 times the whole margin | `scratch/av_bridle_drag_bound_2026-10-22.py` |
| RF-12 | The loss exponent. The drag shares the load omega² form. (1+f)x² + x - 2 = 0. P' = P x³. x sits near 1 - f/3. The (1+f)^-1.5 form retired. dQ/dw = 0 describes rising power, not a maximum | `scratch/aw_loss_response_exponent_2026-10-22.py` |
| RF-13 | The survivors. Constant f full line plus eta: 2 (best 34.558 kg-eq, i3 g17, r_hub 3.785). Per-design f: 46 (best 32.079, i3 g15, r_hub 3.838). Worst case: 0. The tie rule rides the 2 dp P_end boundary. Quote the robust ends, not the middle | dd3cc6a telemetry |
| RF-14 | The off-peak caveat. TSR 6.8415 against the Cp peak at 5.2. The drag slows the rotor toward the peak, so part of the loss returns. The archive loss is an overestimate | NR-031, NR-032 |
| RF-15 | The static solve discriminates. design/op reads 0.565, 0.587, 1.081. The two winners whose warm path collapses hardest miss by about 75%. The fix points at the static solve, not the start protocol. Add the omega_op field. The ratios stay provisional until the island blade_scale values decode. The direction stands. The magnitude does not | `objective_evaluator.jl:798-854` |
| RF-16 | Two couplings. f is lambda-free only while k stays constant. Under k per candidate the drag spread widens. One bridle-geometry ruling buys both the drag term and the root gate | RF-12, RF-4 |
| RF-17 | One evaluation carries three k values. The disc sizes from cp_bem(n_lines, 4.1) with no blade_scale. The static solve charges s² x 2.24. The ODE gets flat 2.24. The decoupling is why the two solvers cross at a point neither validates | `objective_v10.jl:360,548-549`, `run_v13_5kw_masslift.jl:158` |
| RF-18 | k* sits the machine at the Cp peak. k*/k_now = C_P(5.2)/5.2^3 / C_P(6.8415)/6.8415^3 = 3.114. k* reads 6.97 against the 2.24 the ODE gets. The move buys +37% power and charges +80% torque. Omega 13.33 to 10.13. Tau 397 to 715 N·m. P 5.31 to 7.26 kW. Every torque-sized structural line re-prices. The falsification: a fixed-geometry k sweep shows power rising to about 7, then turning over. Torque rises the whole way. Power still rising at 7 means the C_P curve is not the curve the ODE flies | NR-031, NR-032, `objective_evaluator.jl` |

## C. The plan, v2

**Phase 0 - report repair, zero compute.** Strike draft line 982. Fix
"electrical power" (line 333). Reword the winner claims. Render ext2.
Set the child-block scope. Fix the widths.

Extend NR-061. Add the delta-alpha* note and the two-omega note.
Harmonise the rounding. Place the refs. Fill the nomenclature.

**Phase 1 - re-analysis of dd3cc6a, zero simulation.** Sign the 0.837 m
bound. Land the omega-basis row (block 1: k from RotorSpec against 2.24). Land the closure row on the extract
torque. Land the masked PCA and the lever table. Build the convergence
exhibit. Decode the per-design f on the 508 rows.

**Phase 2 - winner diagnostics, minutes of compute.** Toggle gravity,
frame drag and line drag to attribute the bow. Re-read FoS at
t = 200 s. Run the one-point k perturbation at the winner to read the
ODE local aero slope, reporting dP/dk and dtau/dk.

**Phase 3 - model and gate code.** The per-row k bookkeeping plus the
anti-collapse gate and a torque-basis column. One main-rotor bridle
model with two outputs:
the drag term and the bridle SWL gate. The dynamic clearance gate. The
taper clamp hard reject. Discrete x4 and x6.

`start_mode` as a required keyword. The mode-selector guard. The dead
constants.

**Phase 4 - one new campaign, after the founder calls.** The load law
(the k* decision at 2.24 against 6.97), the objective form and the gene
masking land first. The floor reads
delivered power. The design target is about 6.5 kW shaft. Zero of 930
archived evaluations sit there.

## D. The founder calls

1. The power basis. Shaft or delivered. Under the two-bridle bound the
   winner reads about 4.5 kW, and about 4.2 kW with eta 0.94. The
   lightest feasible machine under the same bound reads 34.6 kg-eq
   (constant f) to 32.1 (per design), against the winner 27.4.
2. The objective form. A power value term, a banded ceiling penalty,
   or keep it and reword every claim. This call lands before any
   campaign. The floor must read as delivered power.
3. The bridle geometry. Anchor fractions, diameter rule, coefficient
   basis. One ruling buys the drag term and the bridle SWL gate.
4. The cone convention. Half-angle or full-apex. The taper clamp
   reject lands either way.
5. The appendix scope. Carry the child blocks or cite them.
6. The scratch keep rule. Signed rows cite probe logs inside the
   953 MB.

## E. The seats

- @aero-validator: per-design f decode (needs no founder call, starts
  now), bridle model proposal, 1P/gust (OPEN, unscored), torsional
  check.
- @science-validator: k law and anti-collapse gate, the k-from-RotorSpec
  check against 2.24 as omega-basis row block 1, masked PCA, lever
  table, delta-alpha* note.
- @aero-worker: 0.837 m bound sign-off, NR-061 extension, the
  loss-exponent row with the tie rule, the k perturbation reporting
  dP/dk and dtau/dk, t = 200 s FoS.
- @software-validator: extractor grammar and widths, ext2 render,
  start_mode, discrete genes, hygiene sweep.
- @hermes: this routing record and the plan tracker.

## In plain English

The room checked the feedback against the repo. Two of its claims
fell. The twist-limit derivation exists. The bow already holds a bound
in our own logs.

The finds that hold run deeper. The objective presses the winner onto
the power floor by construction. The reported kilowatts carry no
drivetrain. The bridle drag alone reads 1.7 to 2.2 times the winner
margin.

The correction round settled the loss form. The right exponent is
P' = P x³, not P (1+f)^-1.5. The archive holds no machine built for
the delivered-power floor, because the objective never paid for power
above it.

The load-constant round adds one number. The constant that sits the
machine at the Cp peak reads 6.97 against the 2.24 in use. That buys
37% power for 80% torque, and every torque-sized line re-prices. One
evaluation carries three k values. The static-solve gap ratios stay
provisional until the blade_scale decode lands.

Six calls wait for the founder. Phases 0 to 2 need no call and run now.
The Phase 1 decode starts on s² with the present flat k. Call 3 gates
Phase 3. Calls 1 and 2 plus the k law gate Phase 4.
