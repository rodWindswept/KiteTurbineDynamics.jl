# Ladder re-run census, 2026-10-20

This census re-runs the 42-cell ladder from `scripts/ode_ladder_v13.jl` at HEAD
581d33f. The re-run uses the current gate and the current seed path. The class
column in the shipped CSV records the gate signature, not the wall time.

## Anchor

- HEAD: 581d33ff963adebb62647b77529bf4022748b03c
- Gate: `scripts/ode_gate_v13.jl` md5 bb517061306dbef959136277d6d32d91
- Seeds: `scripts/compute_seeds.jl` md5 6ac23be55036153997b0804c4028eb85

- Ladder: `scripts/ode_ladder_v13.jl` md5 250a41d04e1f66f78f133c25c15d82c8
- Data: `scripts/results/ladder_v13_rerun_2026-10-20.csv` md5 74408ea185deb9a9920f755d6395ec45
- Wall: 2677.4 s for 42 cells. No cell raised.

## Census

Seven cells pass. The pass column is gate acceptance at the design point.
It is not a power criterion. The gate floor is 5.0 kW for every rung.

| rung kW | pass cells | lengths that pass | power range kW |
|---|---|---|---|
| 5 | 6 of 6 | 12, 18, 21.2, 25, 30, 40 | 5.57 to 6.42 |
| 7 | 1 of 6 | 18 | 8.33 |
| 10 to 50 | 0 of 30 | none | n/a |

Thirty-five cells fail, in three classes by gate signature.

- cliff, 20: the settle refused the design point. `trpt_matched_place` raised
  past the torsional realisability cliff.
- stall, 14: the settle completed. The machine parks at w_gnd 0.46 to 0.85 rad/s.
- clearance, 1: the 7 kW cell at 12 m. It reads 10.71 kW and fails the ground check.

## Two failure mechanisms

Stall cells. `mass_scale` scales k_mppt by the power ratio to the 2.5 power
(`src/parameters.jl` line 630). The sweep reads 8.23 at 7 kW and 1122.63 at
50 kW.

The demand k times w squared loads the rotor past the aero torque it can
make. The rotor is Betz undersized at every rung above 5 kW. At the 25 kW rung
the swept area is 25.6 m2 and the Betz ceiling reads 17.5 kW at 12.35 m/s.

That ceiling is 0.70 of the rated power. The ratio runs 0.44 at 7 kW to 0.81
at 50 kW.

Cliff cells. The raise lands on the decoded seed geometry. At the 50 kW rung
the demanded torque reads 4.16 MN m at 638 N per line.

That needs sin delta alpha 313 at 13 lines and a 1.60 m attachment radius. The
raise dates from 2026-09-13 and postdates the old CSV.

## The standing correction governs

`docs/plans/retrospective-2026-08-17.md` section 4 withdrew the old DENIED
verdict. It reads that the stall is a cold-start artifact of the gate at
scale.

The cells carry no physics verdict of their own. The ladder can only say
UNPROVEN at and above 25 kW by this gate.

Two named preconditions remain unlanded at HEAD. The gate still uses the fixed
scaled k_mppt. The ramp controller in `objective_evaluator_ramp.jl` never runs
from the gate.

The high-rung seeds never grew their swept area. The value r_hub stays pinned
at 2.4 m above 5 kW.

## No-delta rule

The old CSV and the re-run share no seed. The value r_hub differs at every rung.

| rung kW | 5 | 7 | 10 | 15 | 25 | 35 | 50 |
|---|---|---|---|---|---|---|---|
| old r_hub m | 0.914 | 1.081 | 1.292 | 1.582 | 2.043 | 2.417 | 2.889 |
| new r_hub m | 4.32 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 | 2.4 |

The 5 kW seed is the S2 fold. The others keep the Daisy-up form with r_hub
pinned. Zero of the verdict changes is design attributable.

The old CSV is a citable prior. It is not a plottable population. No plate
draws old squares beside new squares.

## Plate claims

The plate may print a failure census. The honest claim reads as follows. The
current gate certifies the 5 kW class and one 7 kW cell. Every rung above that
reads unproven by this gate, by stall or cliff reject.

The plate prints no DENIED wording and no power sorted reading. No numeral
prints until the numbers register signs the rows.

STE pass 2026-10-20: no numbers or findings changed after the lint pass.
