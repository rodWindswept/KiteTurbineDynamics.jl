# SPEC: machine power trend. Window-end power across the search.

**Slug** `machine-power-trend`

**Status** SPEC v1, GENERATE candidate. Companion to `machine-evolution-strip`
(figure map row 9). Not seated in the report appendix.

The founder asked for this chart on 2026-10-20: "power printed under each
machine, or the companion generation-axis chart that carries the trend shape …
both if it is easy enough". The strip carries the first. This plate carries
the second.

**Owner** @figures-images-diagrams. **Content check** @science-validator
(values, the NR-062 column) and @aero-validator (axis, era, physics).
**Reader layer** @author: the caption and the slot.

## The claim

The running-best machine holds window-end power above the 5 kW floor on all
three islands across generations 0 to 30. Island 3 steps from 5.86 kW to
5.31 kW. The score gains of the search do not come from cutting generator
duty.

## The statistic

Window-end power, `P_end`, of each island running-best machine at each
generation. Running-best is the ok row of least recorded fitness with
`gen <= G`. Ties break to the earliest `(gen, idx)`.

## The population and the count at each point

- Source: the three campaign telemetry files, 310 rows each and 930 rows in
  total.
- Population per point: one running-best machine per island. So n = 3 at
  every generation, and 31 points on each line.
- The drawn record holds 93 running-best values (3 islands x 31 generations).
- No new run. No interpolation between generations. The line is a step.

## The drawing

- One panel. x is generation, 0 to 30, in search order. y is window-end power
  in kW, 4.85 to 6.12.
- Three step lines: island 1, island 2 and island 3. Island 3 is heavy,
  because it is the strip island.
- The 5 kW floor draws as a dashed rule and carries the words "5 kW floor".
- The island 3 values step at exactly generations 0, 6, 10, 18, 22, 25 and
  26, the strip panel set. Four of them print, each in the NR-062 form:
  5.86, 5.4, 5.89, 5.31.
- The plate prints no objective curve, no mass curve and no slope numeral.
  The objective curve is the convergence plate (row 16). No derived numeral
  prints: the fall from 5.86 to 5.31 is two signed forms, not a subtraction.

## Register rows

- `NR-062` carries the window-end power forms, signed 2026-10-18. The island
  3 steps read this row.
- `NR-006` carries the seed, 36.109. The sub-line names it.
- `NR-005` carries the winner, 27.364. The sub-line names it.
- The axis ticks and the floor label are calibration, not readings. They
  carry no row.

## Era and stamp

One era: `post-95c385d_wind-authority`. Data commit `dd3cc6a`. Launch
`a76c5e9`. The stamp prints on the plate. No line joins two eras.

## The four checks

1. **Spec first.** This page holds the claim, the statistic, the population,
   the count and the rows.
2. **One era per chart.** One data commit and one era stamp sit on the plate.
3. **The axis states its job.** The x axis names the search order and the
   step rule. The y axis is a constraint axis against the 5 kW floor, the
   example the check gives. The sub-line names the statistic.
4. **Values from one source.** Every drawn value derives from the three
   telemetry files at `dd3cc6a`, pinned by sha256 in the manifest. The four
   printed forms map to NR-062, whose source is the same telemetry at the
   same commit. The generator asserts each form against the file before it
   draws.

## What fails the plate

- A printed form that differs from NR-062.
- A step that does not land on the seven strip generations.
- An island 3 line that leaves the 5.0 to 6.0 kW band.
- A ledger string absent from the vector text layer.
