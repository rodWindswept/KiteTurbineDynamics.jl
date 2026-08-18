# F7 — Failure census: why genomes were rejected across the 5 kW campaigns

## Narrative

Differential evolution evaluates thousands of genomes; most never produce
power. This census shows what the v13 evaluator rejected and why, per TRPT
length: `ok` (survived the window, ~70%), `clearance_reject` (ground
clearance below the 1.5 m gate — the dominant rejection), `reject` (other
evaluator reject: stall/power window/FoS), `reject_twist` (torsional
crossing). The message: the landscape's sharpest edge is ground clearance,
not aero — the optimizer spends most of its search scraping the 1.5 m
minimum-clearance gate, which is exactly the safety constraint a real rig
must respect.

## Data verification

- Sources: `scripts/results/v13_5kw_len{18.0,21.2,25.0}/telemetry.csv`
  (status column; header records window=20.0, min_clearance=1.5), committed
  with the campaign winners.
- Counts (round-1 check against the CSVs):
  len18: 663 ok / 226 clearance_reject / 35 reject / 4 reject_twist (928)
  len21.2: 585 ok / 279 clearance_reject / 54 reject / 10 reject_twist (928)
  len25.0: 673 ok / 151 clearance_reject / 95 reject / 9 reject_twist (928)
- Every bar is a direct count of the status column; no aggregation beyond
  `uniq -c`.

## Design spec

- Grouped horizontal bars: y = length (18.0/21.2/25.0 m), x = count;
  4 status categories per group, fixed colour order, legend.
- Colours: ok = green, clearance_reject = amber, reject = red,
  reject_twist = dark red. White background, no fills beyond the bars.
- Value labels on bars (counts).
- Caption: rejection taxonomy + provenance (telemetry.csv @ ec44148 etc.).
