# Captions: machine power trend

**Slug** `machine-power-trend`. **Status** GENERATE candidate, unseated.
**Date** 2026-10-20.

Companion to `machine-evolution-strip` (figure map row 9). The strip prints
window-end power under each of its seven machines. This plate carries the
shape those seven cards cannot show: the same quantity across 31 generations
on all three islands, against the 5 kW floor.

Values cite NR-062 (window-end power), NR-006 (the seed), NR-005 (the winner)
and NR-002 (the feasible count). The drawing reads the three campaign
telemetry files at data commit `dd3cc6a`. The penalty split reads
`extract-mass.csv` at `ce9c5d8`, decode `3307af6` (NR-066).

## Plain caption

The score charges window-end power, squared, above a 5 kW floor.

The last machines get lighter. Their power comes down with them. Island 3
falls from 5.89 kW at generation 10 to 5.31 kW at the winner.

That fall is 3.480 of the 4.515 kg-eq of penalty the winner sheds. The rest
is beam utilisation, less a small twist cost.

No machine can cross the floor. The score rejects a design below 5 kW, so the
one segment that lies on the line is the tightest pass of the campaign and
not a limit that got close.

## Technical caption (undergrad register, STE-clean form)

The line is a step. The running-best machine changes only when a better
design lands, so the power holds flat between changes. No line interpolates
between generations.

Each generation carries three points, one running-best machine per island.
The plate draws 93 values from 930 recorded designs.

The plate prints four window-end values on the island 3 line. The seed reads
5.86 kW. Generation 6 reads 5.4 kW. Generation 10 reads 5.89 kW. The winner
reads 5.31 kW. Each printed value is one member of the pair NR-062 signs. The
strip cards carry all seven.

The 5 kW rule is a gate and not a datum. The fitness function returns infinity
below the power floor (`objective_v12.jl:143`), and the evaluator passes the
window-end power into that slot (`objective_evaluator.jl:1153`). Of 508 ok
evaluations, none reads below 5.00 and exactly one reads 5.00. The next lowest
reads 5.02. That one machine holds the running-best place from generation 8
to generation 14, and its window end sits below its own window mean. The plate
labels it the tightest pass, one design of 508.

Island 3 peaks at generation 10. The machine is lighter than the seed there
and it still draws more power. The score improves at that step because the
mass falls 4.7955 kg, and the penalty rises 4.1548 kg against it. The
generation 10 penalty, 6.1670 kg, is the largest of the seven.

From generation 10 to generation 26 the machine gets heavier by 0.2328 kg and
the penalty falls 4.5146 kg. The fall splits three ways: over-power 3.4800,
utilisation 1.1682, twist up 0.1336. The over-power charge is
5 x (P_end - 5)^2, so most of that relief is the window-end power coming down
from 5.89 to 5.31.

The plate therefore does not claim that power is independent of the score. The
power path is one of the scored terms, and the last relief comes mostly from
it. The strip caption states the same trade as 0.233 kg of mass for 4.515 kg
of penalty.

No objective curve prints here. The convergence plate (row 16) carries it. No
slope numeral prints, because no register row carries one.

Two decimals on the power are the recorded precision. Generation 6 prints 5.4
as recorded: two significant digits and not a defect.

## Provenance line

Data commit `dd3cc6a` · run `a76c5e9` · era `post-95c385d_wind-authority` ·
rows NR-002, NR-005, NR-006, NR-062 · script commit `a1047a4` · full record: the
figure-provenance appendix, once the plate is seated.

## Seat note (2026-10-20, figures seat)

The plate is a candidate and not a seated figure. `check_appendix_pins.py`
maps nine appendix rows through a fixed kit table. A tenth row would read
UNMAPPED and fail the gate, so this kit carries a manifest and no appendix
row.

Seating needs three changes in one pass: a row in the draft table, the slug
in that kit table, and a re-mint. The strip kit does not move for this plate,
so its pin stays at `ce9c5d8`.

## Correction note (2026-10-20, figures seat)

The first cut of this caption read "the power does not follow the score down"
and "the score improves at that step because the penalties fall". Both
sentences were wrong, and the numbers seat caught them from the same CSV.

- At generation 10 the penalty is the largest of the seven, 6.1670 kg. It
  rises 4.1548 kg against generation 6. The score improves there because the
  mass falls 4.7955 kg.
- From generation 10 to the winner the penalty falls 4.5146 kg, and 3.4800 of
  it is the over-power term as the window-end power comes down. Power is a
  cause of the last relief, not a quantity that held while the score moved
  independently.
- The 5.00 kW reading is a gate, not an observation. No ok evaluation can sit
  below it.

The title now reads "Window-end power drives the over-power penalty", the
gen-10 sentence carries the measured replacement, and the floor segment is
labelled as the tightest pass. The drawing itself did not change.

## Reading rules

- The statistic is the running-best window-end power. It is not a mean over
  generations and not a trend fit.
- A step holds one source machine. The step positions are the seven strip
  generations, so the plate and the cards describe the same machines.
- The power value is the window end, the member the score charges (NR-062).
- Island 3 is the strip island. Islands 1 and 2 give the campaign context and
  supply the count of three at each generation.
- The floor segment is a pass reading, not a near miss.
