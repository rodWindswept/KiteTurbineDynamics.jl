# F4 — review round 1 (2026-08-16)

## Styling
- [x] 1×3 small multiples, shared y, white background, 3 island colours.
- [x] ≤3 channels (position + colour + line) — within limit.

## Data accuracy
- [x] Every trace = `convergence.csv` rows (island, iteration, fitness) —
      direct plot, no aggregation. 90 rows per length.
- [x] Endpoints verified vs CSV tails: 18 m −6.220986, 21.2 m −6.664121,
      25 m −7.307390.
- [x] **Round-1 catch: fitness sign.** The DE minimises (`argmin(costs)` in
      run_v12_5kw_v3.jl; rejects score 1e9). The first label said
      "higher = better" — WRONG. Fixed to "lower = better, rejects = 1e9
      off-scale". (The traces decrease toward the plateau because the DE
      minimises a penalty-form objective.)
- [x] Panel 3 gen-1 spike (island 1, >1.0) squashed the shared y-range —
      fixed with ylim (−8.6, −2.5).

## Formatting
- [x] Legend in panel 1 only, lines converge onto shared plateaus
      (overlap at the plateau is the convergence story).
- [ ] Round-2 vision check on the regenerated PNG (pending).

## Human-in-the-loop
- [ ] Rod: eyeball `figure.png` — plateau values −6.22/−6.66/−7.31 and the
      "lower = better" axis note.
