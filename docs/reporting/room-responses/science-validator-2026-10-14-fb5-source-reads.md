# Room response: the feedback round 5 source reads sign: the blade-scale base and the cone-angle basis (2026-10-14, science-validator)

**Status** LANDED. **Seat** science-validator. **Read at** `cd779dd` (tip, local == origin).

The routing lists two source reads as the head of round 5. This seat signs both.
Two derived rows append to the numbers register: NR-049 (the shaft transition
cone, one fixed value) and NR-050 (the blade-scale base). One glance line for
the section 2.5 cold-path statement rides section 4.

## 1. The blade-scale base (founder comment 1)

The ask: the scale multiplies which base size. The answer reads from the decode.

- The decoder sizes each rotor's radius from its share of the rated power at
  the rotor's local wind speed. The site reads `r_rotor_i =
  BEM.rotor_radius_for_power(P_i, v_i, design.n_lines; f=f_i)`
  (`src/objective_v10.jl:360`). The sizing law reads `P = f · Cp · ½ρ · πr² · v³`
  (`src/bem.jl:162`).
- The base blade takes two fixed fractions of that radius. The base span is
  `0.75 × r_rotor`. The base chord is `0.113 × r_rotor`.
- Blade scale multiplies both, linearly. The blade mass follows the span
  cubed: `0.420` kg per blade at a span of 1.0 m.

The winner pair closes the chain. `r_rotor` reads `2.4341173109692225`. The
base span reads `1.8255879832269168`. The scale `0.8213255027884769` takes it
to the signed span `1.4994019682084492` (NR-043). The chord reads
`0.22590989654340632` (quote `0.226 m`).

Signed display form for the section 2.1 clause (folds at @author):

- The clause names the base calculation: the rotor radius the power sizing
  needs for that rotor's share at its local wind speed.
- The two factors print as `0.75` and `0.113`.

## 2. The cone-angle basis (founder comments 2 and 17)

The ask: is the rotor-ring to first-TRPT angle one fixed value. It is.

- One value: `cone_slope_deg = 22.0`. The runner cfg carries the literal
  (`scripts/run_v13_5kw_masslift.jl:172`). Every one of the 930 designs
  decodes with it. It is not a search gene. No sweep script varies it. The
  census reads 41 sites, each a literal 22 or a cfg plumb.
- The decode geometry: the cone length computes as `(r_hub - r_bottom) /
  tan(deg2rad(cone_slope_deg))` (`src/objective_v10.jl:259`). The winner's
  cone reads `9.346660757987` m, from `taper_start_z` `9.453339242013` m up
  to the hub ring.
- One guard for the label. The record F5 resolves the source reading: the
  printed 22 degrees in the Tulloch reference is the apex angle, and its
  per-side slope reads 11.0 degrees
  (`docs/validation/trpt-reference/03-repo-findings.md`). The live tree
  applies 22 as the per-side slope. So the report prints the fixed-value
  fact, and it does not print `Tulloch/Jensen reference` as the basis of the
  22. The aligning code change stays open (WP2d).
- Naming: the report carries the `shaft/TRPT` qualifier (the aero note). The
  three named angles stay apart: the bank slot 22 degrees, the shaft
  transition cone 22 degrees, and the bridle cone half-angle 31 degrees.
- The campaign lead: comments 2 and 16 log the cone angle as unexplored
  design space. The note joins the founder leads.

Signed display form for the section 2.1 and 3.5 sites (folds at @author):

- `The shaft transition cone holds one fixed angle, 22 degrees, by
  construction. It is not a search gene.`
- Plus one lead line for the unexplored space.

## 3. Guards

- The two 22-degree facts never merge. Each sentence names its own origin.
- The number 22 at the cone site is new. It prints with the cone name. The
  bank slot keeps its own sentence.
- No existing value moves. No figure byte moves. The draft takes no edit
  from this seat.
- The decode convention: the evaluated decode passes `v_rated = 11.0`
  (`src/objective_evaluator.jl:721`). The runner standalone clearance decode
  omits it. Third-party reproductions pass `v_rated = 11.0` to read the
  signed radii.

## 4. The section 2.5 cold-path glance

The fold line reads the cold path: `start_mode = :cold` at the runner
(`scripts/run_v13_5kw_masslift.jl:262-264`). The draft already reads `The ODE
path is :cold.` at section 2.5. The aero counter-read covers the pin
(`658e7bb`). The glance reads clean.

## 5. Evidence

- Probe: `scratch/sv_fb5_source_reads_probe.jl` and its log. Decode only, no
  ODE. It reproduces the NR-043 pair to the last digit.
- Checker: `scratch/sv_fb5_source_reads_check.py` and its log. 39 checks, 0
  fail.
- Register: NR-049 and NR-050 append under the amend pattern.

## 6. Handoffs

- @author: the two clauses fold in one pass. The display notes sit at the
  rows. The wave rides the same push as the rest of round 5.
- @science-writer: the sweep 29 basis for the two folds reads at NR-049 and
  NR-050. One guard: the `Tulloch/Jensen reference` phrase stays out of the
  report prose for the cone.
- @aero-validator: the naming note is adopted (`shaft/TRPT`). The two rows
  sit open to your counter-read.
- @hermes: the queue can record the two reads. One routing line needs a flip:
  the map parenthetical `(Tulloch and Jensen reference)` should not print,
  per the F5 reading.
- @user: both answers are yes, and both now carry their numbers. The blade
  scale multiplies a base the sizing sets. The cone angle is one fixed
  value, and it was never searched. It logs as a lead for a next campaign.

---

science-validator, 2026-10-14.
