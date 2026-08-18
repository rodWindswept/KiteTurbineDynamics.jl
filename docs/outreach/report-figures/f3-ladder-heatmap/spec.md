# F3 — Ladder heatmap: delivered power across rungs × TRPT lengths

## Narrative

The 5 kW proof is one rung on a ladder. This figure shows the whole ladder in
one view: seven rated-power rungs (5-50 kW) × six TRPT lengths (12-40 m), 42
designs, each run through the v13 evaluator at its own length. The colour is
what the design actually delivered at the ground ring (P_gen, kW). The
headline is the envelope boundary: the 5-15 kW rungs deliver power, the
≥25 kW rungs deliver ~0 W at every length — not a numerics failure but a
swept-area limit (Betz ceiling ≈ 19.3 kW at the ~40 m² of swept area the
v13 scaling allows; see retrospective §4). A second wall is visible inside
the envelope: at 40 m the 7-15 kW cells stall or twist-cross (twist_ratio
0.84-1.82) — the "twist wall" at long chains.

## Data verification (source inventory)

- Source: `scripts/results/ladder_v13.csv` — 43 lines (42 cells + header),
  committed at `2aad90d` ("Ladder verdict: seed-class design viable 5-15kW,
  DENIED >=25kW (Betz-undersized)"). Present in the repo at the report
  commit — provenance box cites this path + hash.
- Columns used: `kw` (rung), `L` (m), `P_gen_kW` (delivered at ground ring),
  `verdict` (re-gate viability), `twist_ratio`, `crossed`.
- Round-1 data check to run: the 5 kW × 18 m cell reads P_gen = 4.89 kW
  while the regate verdict (`regate_verdict.md`, commit `ec44148`) reports
  7.68 kW at the ground ring for the same length — flag the metric
  difference (ladder P_gen vs regate P) in review round 1; do not paper
  over it in the caption.

## Design spec

- Kind: heatmap (matplotlib, white background, 300 dpi PNG + PDF).
- Axes: x = TRPT length (12, 18, 21.2, 25, 30, 40 m); y = rated rung
  (5, 7, 10, 15, 25, 35, 50 kW).
- Colour: single continuous map (viridis) on P_gen_kW, colorbar labelled
  "P_gen at ground ring (kW)". No bands, no fills, no shape encodings.
- Cell annotation: P_gen value, 2 significant figures; `✗` glyph over cells
  with verdict=false. Two visual channels + text = within the limit.
- Labels: rung axis "Rated power rung (kW)", length axis "TRPT length (m)".
- Caption (in the LaTeX): envelope 5-15 kW; ≥25 kW denied by swept area
  (Betz ceiling 19.3 kW @ ~40 m²); twist wall at 40 m (twist_ratio 0.84-1.82
  in the 7-15 kW row, crossed=true at 7/10/15×40).
- Provenance box: ladder_v13.csv @ 2aad90d.
