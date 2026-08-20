# Plan — Genome Chooser (filter → cards → 3D) for the Form Browser

Status: PROPOSED for implementation
Date: 2026-08-20
Owner: Hermes (lead) · Worker: software-worker · Gate: software-validator
Extends: `scripts/view_campaign_genomes.jl` (committed `ca601a8`)
Reference plan: `docs/plans/2026-08-20-genome-form-browser.md`

## Goal

Replace prev/next-only navigation with a filter → cards → pick flow:
range sliders over the decoded physical parameters, a card grid of the
matching genomes, click a card to view it in 3D with its scores, plus a
"highlights" panel of standout and trend-exemplifying designs.

## Input (changed)

Accept a results DIRECTORY (or several CSV paths), not one CSV. Concatenate
every `*/telemetry.csv` under it. Each CSV carries its own `tether` column, so
length becomes a filterable dimension. Default: `scripts/results/`, scanning
for `v13_5kw_len*/telemetry.csv`. Single-CSV mode must still work.

## Filter panel

Range sliders over the DECODED physical parameters:

- r_hub, r_bot (m)
- n_lines (int)
- n_active (int)
- lam_top, lam_bot (λ)
- bank_top, bank_bot (deg)
- tether / length (m)
- density_profile

Each slider is a min–max range. A row matches when ALL active sliders contain
the row's value (AND-combination). Slider ranges auto-populate from the actual
min/max of that parameter across the loaded set — never hardcoded. A live
counter shows the number of matching rows.

`density_profile` is NOT a CSV column. It comes from decoding each row's
`x1..x14` via `design_from_vector_v10`. Decode all rows once at load into a
cached table (the decode is pure geometry — no ODE, no physics). Per-row
length: `params_at_length(row.tether)`, exactly as the runner does.

## Cards

The matching rows render as a card grid (stat tiles — not live 3D thumbnails,
which are too heavy for ~20 cards). Each card shows: fingerprint short id,
P_mean, FoS, fitness, status, n_lines / n_rings / n_active, r_hub, tether.
Click a card → load that row into the 3D viewport + score panel (existing).

## Highlights panel

A mode `Menu` (or equivalent) with four selectable sets:

1. **Standouts (score extremes)** — overall winner (min fitness), highest FoS,
   highest P_mean, best clearance. Always the default mode.
2. **Pareto front** — non-dominated designs across the objectives
   fitness (minimise), FoS (maximise), P_mean (maximise).
3. **Per-dimension extremes** — for each significant dimension, the design at
   the min and at the max of that dimension.
4. **Cluster representatives** — k designs, one nearest each cluster centroid,
   via k-means (pure Julia) on standardised decoded params; k default 5.

Each highlighted design renders as a card in the same grid style; clicking it
loads it into the 3D viewport.

## Layout

GLMakie has no GridLayout scrollbar and 10 sliders + cards + 3D will not fit
one 1400×850 window. Use the multi-window pattern (see
`glmakie-desktop-dashboard` skill): a chooser window (filters + cards +
highlights) and a viewport window (3D + score panel). Selecting a card updates
the viewport window via an Observable. Or use collapsible sections if a single
window is workable. Do not hardcode row heights that clip.

## Acceptance tests (validator gates)

Existing AC1–AC7 still apply (compile; no 15-dim/k-in-genome; geometry decode;
PNG artifact; nav; panel==CSV; no physics/CSV change).

New:
- AC8 — Filter correctness: for a single-slider set (e.g. n_lines==6), the
  match set equals the CSV rows with n_lines==6; multi-slider sets AND-combine
  correctly (verified numerically, not visually).
- AC9 — Live match count equals the true number of matching rows.
- AC10 — Slider ranges equal the observed min/max of each decoded param across
  the loaded set (no hardcoded bounds).
- AC11 — Multi-CSV: loading a directory concatenates all three lengths; the
  combined row count equals the sum of per-CSV row counts; tether values are
  18.0 / 21.2 / 25.0 as appropriate.
- AC12 — Card selection loads the correct row (select card → loaded fingerprint
  == that row's x1..x14).
- AC13 — Standouts: the returned winner == argmin(fitness), highest FoS ==
  argmax(FoS), etc., each verifiable against the CSV.
- AC14 — Pareto front: returned set is non-dominated (no member is dominated by
  another in all three objectives), verified programmatically.
- AC15 — Per-dimension extremes: min/max design per dimension == CSV argmin/argmax.
- AC16 — Cluster reps: returns k distinct valid rows, k default 5 (exact
  clustering not asserted — only validity + distinctness + count).
- AC17 — density_profile filtering works though it is not a CSV column (a known
  row's decoded density_profile equals its slider-filtered membership).

## Constraints

- Pure read + render. No evaluate_windowed, no ODE build, no CSV write, no
  src/ physics change.
- Reuse the existing decode + render from view_campaign_genomes.jl; do not fork
  a second decode path.
- SI units; angles in degrees. Blue style.
- Standout/trend logic must be deterministic and reproducible (fixed seed for
  k-means).

## Definition of done

AC1–AC17 pass, PNG artifact produced, headless modes (`--selfcheck`,
`--nav-check`, `--png`) still work, and the interactive chooser runs without
error. No commit (leave in working tree; lead merges after gate).
