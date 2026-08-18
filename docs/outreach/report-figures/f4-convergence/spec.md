# F4 — Convergence curves: 3 islands × 30 generations, three TRPT lengths

## Narrative

Each 5 kW campaign ran 3 islands × 30 generations of differential
evolution. This figure shows the best-fitness-per-iteration trace for the
three winning lengths (18.0, 21.2, 25.0 m) — the optimizer converging onto
the v13 landscape. All three reach a plateau; the plateau itself is the
design envelope's edge, and the regate step (F5 cards, F8 table) is what
turns a converged fitness into a verified machine.

## Data verification

- Sources: `scripts/results/v13_5kw_len{18.0,21.2,25.0}/convergence.csv`
  (90 rows each: island, iteration, fitness), committed with the campaign
  winners (ec44148, ed284b7, 28b7a57).
- Fitness is the v12 objective, MINIMISED by the DE (`argmin(costs)` in
  run_v12_5kw_v3.jl); rejected designs score 1e9 (off-scale). Lower = better.
  Plot raw values; note the convention in the caption.
- Plateau values: 18 m −6.2210, 21.2 m −6.6641, 25 m −7.3074 (island 3,
  gen 30).
- Round-1 check: confirm every trace endpoint against the CSV tail.

## Design spec

- 1×3 small multiples (one per length), shared y range.
- One line per island (3 colours, consistent across panels), no markers.
- Axes: x = generation (1-30), y = fitness (negative, higher up).
- White background; panel titles "18.0 m", "21.2 m", "25.0 m".
- Caption: convergence plateaus; fitness convention; provenance boxes
  (CSV @ commit).
