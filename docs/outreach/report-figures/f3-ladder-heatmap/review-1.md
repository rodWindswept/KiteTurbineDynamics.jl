# F3 — review round 1 (2026-08-16)

## Styling
- [x] White background, viridis continuous map, no bands/fills — per ktd-chart-design.
- [x] 2 channels (position + colour) + cell text + one marker glyph — within limit.
- [x] Title, axis labels, colorbar labelled.

## Data accuracy
- [x] Every cell is one row of `ladder_v13.csv` @ 2aad90d (direct pivot, no aggregation).
- [x] Spot-checked vs CSV: 5 kW row 4.58/4.89/4.45/2.25/3.18/1.36; 50 kW row all 0.00.
- [ ] ~~FLAG~~ **RESOLVED (2026-08-16):** not a solver divergence — the regate
      verdict (v13_5kw_len18.0/regate_verdict.md) states it outright: "57%
      above the seed (4.89 kW) at this length". The ladder cell is the
      SEED-CLASS scaled design (r_hub=0.914, n_lines=6, rings=6); the regate
      is the DE-OPTIMISED campaign winner (r_hub=0.702, n_lines=12, rings=5).
      The ladder was ODE too ("ODE ladder sweep (corrected model)").
      Caption must say: ladder = seed-class envelope, not the optimised
      winners.

## Formatting (vision check, round 1)
- [x] Found: extent-based coordinate misalignment — cells off-grid, labels over the
      y-axis, ticks crammed. Fixed by dropping `extent` (index coordinates).
- [x] Round 2 vision check: cells centered, ✗ placed, ticks aligned, contrast ok.
- [ ] Minor (round 3): red ✗ on dark-purple zero cells is lower-contrast — brighten
      to a lighter red on dark cells if Rod wants it stronger.

## Human-in-the-loop
- [x] Rod: please eyeball `figure.png` — envelope story (5-15 kW live, ≥25 kW dead,
     40 m twist wall) and the ✗ glyph style.
- [x] Rod round 2 (2026-08-16): caption feedback — "rung" unexplained, nothing said
     these are simulations, "4.6–4.9 kW at 5 kW" didn't match the row, top rows
     unexplained. Fixed: axis "Rated-power target (kW)"; caption opens "Each cell
     is one baseline design run through the full ODE model — a simulation, not a
     field test"; row values corrected to the CSV (4.58/4.89/4.45/2.25/3.18/1.36
     → "4.4–4.9 kW at 12–21.2 m, then degrades (2.3 kW at 25 m, 1.4 kW at 40 m)");
     ≥25 kW rows explained as the Betz ceiling (19.3 kW on ~40 m²); ✗ defined as
     failed the post-analysis re-gate. Same plain-language pass applied to
     F4/F6/F7 (island/fitness/DE/hub-sanity gate/genomes → introduced/replaced).
     All four re-verified (vision): captions unclipped, no overlaps.
- [x] Rod round 3 (2026-08-17): caption still "messed up — poorly recorded time
     stamps and context swaps". FIRST-PRINCIPLES REWRITE: dropped the F4–F7
     cross-reference (internal figure numbers — context swap), dropped the
     era-stamped fragments from successive patches, one coherent voice, four
     jobs in order: what a cell is (simulation, 30 s @ 11 m/s, axes), the
     envelope (4.6–8.7 kW at 12–18 m; 40 m twist wall, 15 kW cell zero), the
     hatched non-verdicts (never spun — gate start-up limitation), and the
     glyphs (✗ = ran but failed the gate; hatch = no verdict). Verified
     against ladder_v13.csv: 4.58–8.71 kW across 5–15 kW rows at 12–18 m
     (caption "4.6–8.7"); crossed cells at 40 m are exactly 7/10/15 kW rows.
