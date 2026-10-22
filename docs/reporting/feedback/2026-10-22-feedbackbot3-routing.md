# FEEDBACKBOT3: room routing v6 (2026-10-22)

**Source** `FEEDBACKBOT3.docx` (the founder review copy, 2026-10-22)
against draft v0.87, data commit `dd3cc6a`, HEAD `2661194`. This record
holds the findings the room checked in the repo. It holds the plan, the
founder calls, and the seat lanes. v6 folds the measured Cp peak,
the n-blind collapse, and the ceiling off-switch. Phases 0 to 2 need
no founder call. Status keys: VERIFIED,
ADJUSTED, FALSIFIED, OPEN, CALL.

## A. The feedback claims, checked in the repo

| ID | Claim | Check | Result |
|---|---|---|---|
| FB-1 | The objective minimises mass. Power is a gate | `objective_v12.jl:89`, `run_v13_5kw_masslift.jl:153,156` (`p_floor_kw = p_ceiling_kw = 5.0`, `penalize_ceiling = false`) | ADJUSTED. The campaign scores `appropriate_mass_fitness`, which charges 5 kg per (kW above 5)^2 on every row; the flag is never read (RF-23). The winner is the lightest machine under that charge, not under mass alone |
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
| RF-11 | The bridle-drag bound. 932 W full line at d 3 mm and C_D 1.2. Two bridles 547 to 684 W. The bound is 1.7 to 2.2 times the whole margin. Present tense: k = 2.24. RF-19 carries the k* rescale | `scratch/av_bridle_drag_bound_2026-10-22.py` |
| RF-12 | The loss exponent. The drag shares the load omega² form. (1+f)x² + x - 2 = 0. P' = P x³. x sits near 1 - f/3. The (1+f)^-1.5 form retired. dQ/dw = 0 describes rising power, not a maximum | `scratch/aw_loss_response_exponent_2026-10-22.py` |
| RF-13 | The survivors. Constant f full line plus eta: 2 (best 34.558 kg-eq, i3 g17, r_hub 3.785). Per-design f: 46 (best 32.079, i3 g15, r_hub 3.838). Worst case: 0. The tie rule rides the 2 dp P_end boundary. Quote the robust ends, not the middle | dd3cc6a telemetry |
| RF-14 | The off-peak caveat. TSR 6.8415 against the measured Cp peak at 4.825. The drag slows the rotor toward the peak, so part of the loss returns. The archive loss is an overestimate | NR-031, NR-032, RF-21 |
| RF-15 | The static solve discriminates. design/op reads 0.565, 0.587, 1.081. The two winners whose warm path collapses hardest miss by about 75%. The fix points at the static solve, not the start protocol. Add the omega_op field. The ratios stay provisional until the island blade_scale values decode. The direction stands. The magnitude does not | `objective_evaluator.jl:798-854` |
| RF-16 | Two couplings. f is lambda-free only while k stays constant. Under k per candidate the drag spread widens. One bridle-geometry ruling buys both the drag term and the root gate | RF-12, RF-4 |
| RF-17 | One evaluation carries three k values. The disc sizes from cp_bem(n_lines, 4.1) with no blade_scale. The static solve charges s² x 2.24. The ODE gets flat 2.24. The decoupling is why the two solvers cross at a point neither validates | `objective_v10.jl:360,548-549`, `run_v13_5kw_masslift.jl:158` |
| RF-18 | k* is measured, and the 6.97 corner is an interpolation artefact. 82 AeroDyn solves put the base-curve peak at Cp 0.31293, lambda 4.8246 against the committed 5.2: the secant across the 4.195 to 5.244 knot gap cuts the peak, and the table reads 2.1% low at 4.8. k*/k reads 3.767 to 3.955, so k* is 8.4 to 8.9. Physical torque x1.87 to 1.97, flip 2.81 to 2.95. The gate's own demand is P_rated/omega, a lambda-only charge x1.418, flip 2.13 at the 5 kW label; both together at a 6.9 kW rating give 2.94. Every flip is prospective: the torsional gate is unreachable from the v13/v14 path (RF-20). Power x1.32 to 1.39, so the gain stands. The falsification reads the same: a fixed-geometry k sweep shows power rising to about 8.4 to 8.9, then turning over. Min FoS 3.180 (i1 g17) is the ring FoS from the window | `.scratch/bem_regression/fine_lambda_2026-10-22/`, `objective_evaluator.jl:262` |
| RF-19 | f = kappa / k. The k* move divides every drag fraction by k*/k, now 3.77 to 3.96. Frozen diameter: credible bound 0.104 to 0.0263-0.0276 (x^3 0.973), full line 0.177 to 0.0448-0.0470 (x^3 0.954). Sized diameter lands below frozen: rho = C_T x lambda / C_P reads 13 to 80 at the archive lambdas, so out-of-plane load governs and f' = (0.298 to 0.321) f. Frozen d is the ceiling; quote it. The drag loss has a closed form: P_del = 1/2 rho A v^3 (C_P - kappa lambda^3 / (1/2 rho A r_tip^3)), kappa geometry-only, so the penalty grows as lambda^3 and the per-row best k moves up 1 to 2% at f 0.104. k_drag* folds into the 8.4 to 8.9 bracket, not a separate column. Absolute power at k* waits on the decode. Part of the drag that empties the archive is the wrong operating point inflating kappa/k. Fixing k re-opens the archive partly while the torque charge re-prices mass. The two cannot brief separately | `bem.jl:109,128` |
| RF-20 | The structural load basis is decoupled from the power basis, twice over. Capacity reads design thrust, frozen at CT x A x v^2 for every machine (CT 0.55). Demand reads the 5.0 kW rating over static-solve omega. Delivered power enters neither. The torsional gate is unreachable from the v13/v14 path: evaluate_windowed and the ramp evaluator never call evaluate_design, objective_v10, mass_total_kg or min_torsional. The archive computes no torsional FoS, so every RF-18 flip is prospective, not applied. power_W is welded: one builder input feeds the rotor sizing and P_rated in the torsional demand, so a 4 kW rung resizes every rotor and moves the rating together. Charging the delivered torque is a Phase 3 wiring item, not a campaign | `trpt_optimization.jl:706-714,850-857,863,866`, `objective_v10.jl:618,720`, `objective_evaluator.jl:262` |
| RF-21 | The C_T/C_P contradiction retires. One BEM solve gives base C_T 0.965 with C_P 0.237 at lambda 6.84: mutually consistent, a_eff 0.755 is deep induction, past the ideal-momentum inverse's range. The real defect is the base table's peak: measured Cp 0.31293 at lambda 4.8246 against the committed 5.2. The ratio surfaces are nearly innocent, about 1% at the peak band because the same chord cancels in numerator and denominator, so they stand. Measured lambda*_n against code cp_bem: n3 4.825/5.20, n4 4.248/4.20, n5 3.776/4.01, n6 3.514/3.44, n7 3.251/3.20, n8 3.042/2.98, n9 2.832/2.81. The code is right for n 4-9 and wrong only at n 3, the winner's row: the one row with no ratio correction over the base curve. Measured C_T at 6.84 runs 0.965 to 1.407 across n 3-9: the 1.02 cap under-reads the bridle load 7% (n4) to 38% (n9). The cap ruling stays OPEN for the SWL gate | `.scratch/bem_regression/fine_lambda_2026-10-22/fine_lambda_bladecount.csv` |
| RF-22 | The ODE flies cp_at_tsr for every row, so n_lines never enters the power coefficient. Measured Cp at the flown lambda 6.8415: 0.237, 0.176, 0.109, 0.033, -0.065, -0.176, -0.295 for n 3-9. n 7-9 have no equilibrium there; n 6 makes 14% of the n 3 power. 251 of 404 ok rows in the live bank-derate campaign are n 6-9. n_lines is an aerodynamic free gene: it moves mass and drag but not power. Two options, no third: teach the ODE the n-surface, or stay n-blind with a fleet k. The first moves the design lambda to 3-4 for n 6-9 and makes the 6.84 operating point unreachable; the second keeps k* fleet-wide 8.4 to 8.9 and n out of k. Prior to Phase 4's per-row k law (call 7) | `bem.jl:107`, `.scratch/bem_regression/fine_lambda_2026-10-22/fine_lambda_bladecount.csv` |
| RF-23 | The objective is not mass-only, and its off-switch is inert. appropriate_mass_fitness charges 5 kg per (kW above ceiling)^2 unconditionally; only v12_fitness reads cfg.penalize_ceiling, which the campaign sets false. The weights carry a PLACEHOLDER label in-source. The archive's maximum 6.32 kW pays 8.71 kg. Honouring the intended mass objective (fit* = fitness minus the ceiling term) re-ranks the 508: the reported winner sits 12th, the top five deliver 6.12 to 6.33 kW, and fit* against power reads r -0.475. The penalty pinned the population at 5.3 to 5.8, not geometry. Option 2 already runs: hard reject below 5.0, zero-width band, quadratic above | `objective_v10.jl:152-154`, `run_v13_5kw_masslift.jl:146-150,156,266` |

## C. The plan, v3

**Phase 0 - report repair, zero compute.** Strike draft line 982. Fix
"electrical power" (line 333). Reword the winner claims. Render ext2.
Set the child-block scope. Fix the widths.

Extend NR-061. Add the delta-alpha* note and the two-omega note.
Harmonise the rounding. Place the refs. Fill the nomenclature.

**Phase 1 - re-analysis of dd3cc6a, zero simulation.** Sign the 0.837 m
bound. Land the omega-basis row (block 1: k from RotorSpec against 2.24). Land the closure row on the extract
torque. Land the masked PCA and the lever table. Build the convergence
exhibit. Decode the per-design f on the 508 rows, three columns per
row: k = 2.24, k* in the 8.4 to 8.9 bracket with frozen d, and with
sized d. k_drag* folds into the bracket (RF-19).

**Phase 2 - winner diagnostics, minutes of compute.** Toggle gravity,
frame drag and line drag to attribute the bow. Re-read FoS at
t = 200 s. Run the one-point k perturbation at the winner and at the
measured k* 8.4 to 8.9 as a two-point structural re-eval: dP/dk,
dtau/dk, min_torsional_fos, per-ring c, and rho from the tables. Note
min_torsional_fos measures an ungated constraint (RF-20).

**Phase 3 - model and gate code.** The k bookkeeping follows the
call 7 ruling (n-surface or fleet k) plus the anti-collapse gate and
a torque-basis column. One main-rotor bridle
model with two outputs:
the drag term and the bridle SWL gate. The SWL gate names its load
basis and the torsional demand reads delivered torque. The CT cap
ruling lands first (RF-21). The dynamic clearance gate. The
taper clamp hard reject. Discrete x4 and x6.

`start_mode` as a required keyword. The mode-selector guard. The dead
constants.

**Phase 4 - one new campaign, after the founder calls.** The load law
(the k* decision at 2.24 against 8.4 to 8.9 measured), the objective
form and the gene masking land first. The floor reads
delivered power. The design target is about 6.5 kW shaft. Zero of 930
archived evaluations sit there. Calls 1, 3 and the k law form one
decision surface: the SWL load basis, the diameter rule and the
rating. The charges multiply: x1.418 on the gate, x1.87 to 1.97
physical, 2.94 together at a 6.9 kW rating.
Founder input (queued): the k* bracket is 8.4 to 8.9 measured, not
6.97. It stays a no-drag starting point; drag moves it up 1 to 2%
(RF-19). The founder's earlier k sweep showed the flanks: the speed
climbs out of band at low k, and the torque rises at high k. That
sweep ran without drag, so it ran fast. The load-law call waits on the
k sweep run again with drag, not on the no-drag arithmetic. Call 7
(RF-22) comes first: it decides whether k varies per row at all.

## D. The founder calls

1. The power basis. Shaft or delivered. Under the two-bridle bound the
   winner reads about 4.5 kW. The lightest feasible machine under the
   same bound reads 34.6 kg-eq (constant f) to 32.1 (per design),
   against the winner 27.4. This call also sets the structural
   charge: x1.380 at 6.9 kW shaft.
   Founder input (queued): every power label reads mechanical.
   Delivered means the PTO at the shaft bottom. No electrical term.
   The floor opens to 4 kW when the bridle drag lands in the count.
   Each label states its stage: rotor, ring shaft, or PTO.
   Note: a 4 kW floor has two implementations. p_floor_kw = 4.0 alone
   is a re-score: 45 to 46 rows sit in the 4 to 5 kW band, 38 to 39
   clean, each at fitness 1.0e9 because the mass model never ran below
   the floor. power_W = 4000 is a new machine: it resizes every rotor
   (r scales as sqrt P, x0.894) and moves P_rated in the torsional
   demand. The two are welded (RF-20).
2. The objective form. A power value term, a banded ceiling penalty,
   or keep it and reword every claim. This call lands before any
   campaign. The floor must read as delivered power.
   Plain English: the objective today charges 5 kg per (kW above 5)^2
   on every row, and the flag that would switch the charge off is
   never read (RF-23). Option 1, a power value term: the score is mass minus
   the worth of the power. A machine heavier but stronger can win. The
   measure becomes mass per watt, which matches the company
   carbon-per-kWh claim. Option 2, a banded penalty: keep mass-only,
   but add a penalty that grows with distance from a band. Hard reject
   below 5 kW, a penalty that falls as power rises above it, none in
   the band, a small penalty above the ceiling. The founder's
   "penalize under 5 and over 5" reads as this option. Option 3: keep
   it and reword every power claim. The floor reads delivered power
   either way.
   New from the repo: option 2 already runs. One config edit,
   p_floor_kw = 4.0 and p_ceiling_kw = 6.5, gives the band the founder
   described. Honour the intended mass objective and the reported
   winner falls to 12th of 508; the top five deliver 6.12 to 6.33 kW.
   This weakens the case for a new power value term: the recovery
   needs no new objective and no new simulation.
3. The bridle geometry. Anchor fractions, diameter rule, coefficient
   basis, and the SWL load basis (design thrust, rating torque, or
   delivered torque). One ruling buys the drag term and the bridle SWL
   gate. The diameter rule sets the exponent of the k coupling. The
   load basis sets which structural charge applies. The CT cap
   ruling precedes this call (RF-21: the cap under-reads 7 to 38% for
   n 4-9).
   Plain English: the bridle is the fan of lines from the rotor ring
   to the torque shaft. It costs power through its own drag and it
   carries the machine load. The anchor fractions set where the lines
   meet the ring. That sets their length and angle. The diameter rule
   sets whether every line keeps one fixed thickness, or grows thicker
   as the load grows. The coefficient basis sets the drag coefficient
   the lines are charged, and the load coefficient the strength check
   reads. One ruling buys the drag term and the SWL gate. The CT
   cap ruling precedes this call.
4. The cone convention. Half-angle or full-apex. The taper clamp
   reject lands either way.
5. The appendix scope. Carry the child blocks or cite them.
6. The scratch keep rule. Signed rows cite probe logs inside the
   953 MB.
7. The ODE coefficient source (RF-22). Teach the ODE the n-surface,
   or stay n-blind with a fleet k. The first moves the design lambda
   to 3 to 4 for n 6-9 and voids the 6.84 operating point for half
   the archive; the second keeps k* fleet-wide 8.4 to 8.9. This is a
   physics-model change: proposal and acceptance tests before code,
   a DECISIONS entry, and it gates Phase 4 before the k law.

Calls 1, 3 and the k law couple through the SWL load basis and the
torque charge. The k* charge (x1.418 on the gate, x1.87 to 1.97
physical) and the floor charge (x1.380) are independent and
multiplicative. Both are payable. Declining the k law keeps the 1.38.
Keeping the 5 kW rating keeps the gate's 1.42. Call 7 gates the k
law before either.

## E. The seats

- @aero-validator: per-design f decode (three columns, k_drag* folded
  into the 8.4 to 8.9 bracket, starts now), the CT cap ruling (RF-21),
  bridle model proposal, 1P/gust (OPEN, unscored), torsional check.
- @science-validator: k law and anti-collapse gate, the k-from-RotorSpec
  check against 2.24 as omega-basis row block 1, masked PCA, lever
  table, delta-alpha* note.
- @aero-worker: 0.837 m bound sign-off, NR-061 extension, the
  loss-exponent row with the tie rule, the k perturbation at the
  measured k* 8.4 to 8.9 as a two-point structural re-eval (dP/dk,
  dtau/dk, min_torsional_fos, per-ring c, rho) — an ungated
  constraint, not the archive's (RF-20), t = 200 s FoS. Keep the
  fine-lambda CSVs in scratch for the citations.
- @software-validator: extractor grammar and widths, ext2 render,
  start_mode, discrete genes, hygiene sweep, the structural pass per
  genome for min_torsional_fos, folded into the two-point re-eval.
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

The measurement round moves the load constant. The Cp peak reads
4.825, not the 5.2 grid corner, so k* reads 8.4 to 8.9 measured. The
power gain stands; the torque charge rises to x1.87 to 1.97 physical,
and the torsional gate charges x1.418 because its demand is rating
over omega. The gate sits outside the campaign path, so every flip
is prospective. The C_T contradiction retires: one BEM solve gives
both, deep in induction. The 1.02 cap under-reads the real thrust 7
to 38% instead.

The n-blind collapse outranks the k law. The ODE flies one
coefficient curve for every row count. At the flown 6.84 the measured
Cp turns negative by n 7, so half the live campaign's ok rows are
charged against a curve they do not fly. n_lines moves mass and drag
but not power. Two options exist: teach the ODE the n-surface, or
keep a fleet k. That ruling is founder call 7.

The objective round lands one surprise. The banded option already
runs: the fitness charges 5 kg per (kW above 5)^2, and the off-switch
is never read. Honour the intended mass objective and the reported
winner sits 12th of 508; the top five deliver 6.12 to 6.33 kW.

Seven calls wait for the founder. Phases 0 to 2 need no call and run
now. The Phase 1 decode uses s² with the present flat k and emits
three f columns per row. Call 3 gates Phase 3. Calls 1 and 2 plus the
k law gate Phase 4. Calls 1, 3 and 4 decide one surface.

The founder input of 2026-10-22 queues four points. The power basis
reads mechanical at the PTO. The floor opens to 4 kW when the drag
lands in the count. The k law waits on the sweep run again with drag,
at the measured k* bracket 8.4 to 8.9. The calls carry plain-English
briefs now. Phases 0 to 2 proceed unchanged.
