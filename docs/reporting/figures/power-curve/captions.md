# Captions: power curve

**Slug** `power-curve`. **Status** GENERATE candidate, unseated.
**Date** 2026-10-20.

One fixed machine across sixteen hub winds. The strip (row 9) prints seven
machines at one wind each. This plate prints one machine at sixteen winds,
which is the only reading in the set that tests a design outside its own
working point.

Plate: `power-curve.png`. Script: `power-curve.py`. Spec: `SPEC.md` v3.

## Plain caption

The machine is tested at sixteen wind speeds. Below 5 kW the design is
rejected and the power is still measured, so the lower half of the line is a
reading and not a gap. The floor is crossed between the 10.5 and 11.0 m/s
points. Above it the power rises to 9.8 kW at the top of the sweep.

The sweep ends are choices. The machine was not tested past them.

## Technical caption (undergrad register, STE-clean form)

One genome, sixteen evaluations. The wind is the hub wind at 9.41 m. The
sweep reads 6.5 to 13.5 m/s in 0.5 steps, plus the campaign's own point at
11.0097 m/s.

The machine does not move. The decoded mass reads 25.698 kg on all sixteen
rows (NR-066), and the rated wind holds at 11.0. The rating is part of the
machine: the decode and the beam sizing both read it, so a sweep that moved
the rating would draw sixteen different machines.

The gain is fixed at 2.24, the campaign's own gain. The identity row
reproduces the recorded result: fitness 27.363541266349 against the recorded
27.3635412663488, and window-end power 5.314 kW against 5.31 kW recorded.

Two points ran twice: the identity wind and 13.5 m/s. Both repeats print the
same value at the six decimals the file records, so both spreads read zero
and the sweep is deterministic.

Nine rows sit below the floor. The evaluator rejects them and keeps the
measured power, so 1.09 to 4.61 kW draws as open markers. Seven rows score.
The lowest scoring power is 5.30 kW at 11.0 m/s.

The window-end power is the statistic the score charges. Above 11 m/s the
score rises because the over-power charge, 5 x (P_end - 5)^2, prices the
power the machine actually makes. No rated-power cap binds anywhere in the
sweep: the commanded torque at 13.5 m/s is 0.39 of the cap.

The design point is not an optimum on these numbers. The 11.0 m/s point
scores 27.3181 and the 11.0097 m/s point scores 27.3635. The plate therefore
makes no claim about an optimum. It draws the response.

The 5 kW floor is a gate and not a target. The Betz ceiling, the floor and
the over-power charge all evaluate at the design rating of 11.0 m/s, so the
ceiling drawn for a point flown at 13.5 m/s would not be its bound.

No fit draws here, and no line extends past the swept ends. The x-axis is
metric, so a polyline through the evaluated points is honest. The ends are
chosen and not machine limits: the 13.5 m/s point passes at FoS 10.6 and
twist 0.44.

## Rows this plate reads

NR-070 signs the sixteen window-end powers, with their window means, FoS and
twist. NR-071 signs the score pair at 11.0 and 11.0097 m/s and the identity
reproduction. NR-072 signs the nine and seven split. NR-066 signs the winner
mass. NR-046 signs the objective seam: the 5.0 kW floor and the 5.0 per kW
squared charge. NR-015 signs the operating point: gain 2.24, the window chain
and the 18.8 m length.

## Provenance line

Sweep CSV md5 `a4e535af18da220a473db963c45ceb76`, 16 winds plus two settle
repeats · record commit `8a757f3`, src tree `4dd7e0d9`, probe sha256
`59718a02` · rows NR-015, NR-046, NR-066, NR-070, NR-071, NR-072 · script
commit `4bb45c9`.

## Seat note

The plate is a candidate, unseated, and carries no appendix row. Seating
adds a draft table row, the slug in the kit table, and a re-mint.
