# Captions: machine power trend

**Slug** `machine-power-trend`. **Status** GENERATE candidate, unseated.
**Date** 2026-10-20.

Companion to `machine-evolution-strip` (figure map row 9). The strip prints
window-end power under each of its seven machines.

This plate carries the shape those seven cards cannot show. It draws the same
quantity across 31 generations on all three islands, against the 5 kW floor.
The founder ordered it on 2026-10-20 ("both if it is easy enough").

Values cite NR-062 (window-end power), NR-006 (the seed) and NR-005 (the
winner). The drawing reads the three campaign telemetry files at data commit
`dd3cc6a`.

## Plain caption

The generator duty barely moves.

Each island keeps a best machine as the search runs. That machine holds its
window-end power above the 5 kW floor for all 31 generations.

The island 3 score falls from 36.109 to 27.364 kg-eq over the same
generations. The power does not follow the score down.

## Technical caption (undergrad register, STE-clean form)

The line is a step. The running-best machine changes only when a better
design lands, so the power holds flat between changes. No line interpolates
between generations.

Each generation carries three points, one running-best machine per island.
The plate draws 93 values from 930 recorded designs.

The plate prints four window-end values on the island 3 line. The seed reads
5.86 kW. Generation 6 reads 5.4 kW. Generation 10 reads 5.89 kW. The winner
reads 5.31 kW.

Each printed value is one member of the pair NR-062 signs. The strip cards
carry all seven, at 5.86, 5.4, 5.89, 5.78, 5.76, 5.52 and 5.31 kW.

Island 3 peaks at generation 10. The machine is lighter than the seed there
and it still draws more power. The score improves at that step because the
penalties fall. The power then steps down to 5.31 kW at generation 26.

The dashed rule is the 5 kW floor. It is a constraint and not a datum.
Island 1 sits on the floor from generation 8 to generation 14. That is a
recorded value and not a drawn limit, and it is open for the numbers seat to
read.

No objective curve prints here. The convergence plate (row 16) carries it. No
slope numeral prints, because no register row carries one.

Two decimals on the power are the recorded precision. Generation 6 prints 5.4
as recorded: two significant digits and not a defect.

## Provenance line

Data commit `dd3cc6a` · run `a76c5e9` · era `post-95c385d_wind-authority` ·
rows NR-005, NR-006, NR-062 · script commit `7c680d8` · full record: the
figure-provenance appendix, once the plate is seated.

## Seat note (2026-10-20, figures seat)

The plate is a candidate and not a seated figure. `check_appendix_pins.py`
maps nine appendix rows through a fixed kit table. A tenth row would read
UNMAPPED and fail the gate, so this kit carries a manifest and no appendix
row.

Seating needs three changes in one pass: a row in the draft table, the slug
in that kit table, and a re-mint. The strip kit does not move for this plate,
so its pin stays at `ce9c5d8` and the pending re-mint is unaffected.

## Reading rules

- The statistic is the running-best window-end power. It is not a mean over
  generations and not a trend fit.
- A step holds one source machine. The step positions are the seven strip
  generations, so the plate and the cards describe the same machines.
- The power value is the window end, the member the score charges (NR-062).
- Island 3 is the strip island. Islands 1 and 2 give the campaign context and
  supply the count of three at each generation.
