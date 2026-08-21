Rod — forward this to the desktop Hermes in Stornoway. It's the data-side work
from the outreach figure review; the laptop side is handling presentation-only
fixes.

---

Hermes — a figure review of `docs/outreach/figures/` was completed 2026-07-16 on
the laptop (full critique: `docs/outreach/figure-review.md`, pull first). The
laptop has no Julia runtime and no campaign CSVs — you have both. Below is what
only you can fix. Do not touch the .tex presentation issues (label collisions,
V10 Tight → V10-Spoke renames, chart merges) — those are being handled on the
laptop; parallel edits will conflict.

## What you have that the repo doesn't

`catalog_corrected_geo.csv` and `kickstart_sweep.csv` are cited in every figure
provenance box but are not in the repo (the 2026-07-13 processes died unsaved —
confirm the files on disk are complete, 51 rows expected for the catalog). CSVs
stay local by convention; your job is to verify against them and export small
derived tables that CAN be committed.

## Task 1 — Resolve the catalog vs wind_sweep discrepancy (highest priority)

The same designs at the same 11 m/s wind carry different published numbers:

| Design | Catalog (fig2, design-cards, scatter) | wind_sweep.csv (chart-power-curve) |
|---|---|---|
| 0.90·k6 | 81 kW, FoS 11.3, 168 rpm | 204 kW, FoS 6.4, 323 rpm |
| 0.95·k4 | 199 kW, FoS 5.2, 257 rpm | 163 kW, FoS 3.9, 288 rpm |
| 1.10·k4 | 297 kW, FoS 2.3, 272 rpm | 297 kW, FoS 5.3, 391 rpm |

Hypothesis: settle multi-equilibrium — catalog settled the low-ω branch, wind
sweep the high-ω branch. For each of the three designs, run both settle paths at
11 m/s with the dual-duration convergence check from
`docs/outreach/gate1-control-map-rerun.md` §3.4 (endpoints from T and 4×T agree
within 0.5 kW and 2% FoS). Deliverables:

1. A table in a new `docs/outreach/equilibrium-reconciliation.md`: design ×
   branch × (ω, P, FoS, converged? y/n), with script + git hash.
2. For 0.90·k6 specifically: export P_aero(ω) and P_gen = 6·ω³ over ω = 0–450
   rpm as a small committable CSV (`figures/data/equilibrium_090k6.csv`). This
   feeds a planned multi-equilibrium explainer chart showing both intersections.

## Task 2 — Re-verify the anomalous wind_sweep FoS values

FoS 30.7 (0.95·k4 @ 13 m/s), 27.4 (1.10·k4 @ 15), 14.0 (1.00·k4 @ 11) coincide
with equilibrium jumps and look non-converged. Re-run those three rows with the
dual-duration check. If they fail it, append a `converged` column to
wind_sweep.csv (it IS tracked) so the power-curve chart can mark them
provisional.

## Task 3 — Export data blocks for the two missing story charts

Both were specced in `docs/outreach/chart-prd.md` but never built; the laptop
will typeset them once you commit the data.

1. **Settle-bug dumbbell** — for every (λ, k) where catalog and kickstart
   disagree, one row: `blade,k,P_catalog,P_kickstart,omega_catalog,omega_kickstart`.
   Known pairs to confirm from your CSVs: 0.85·k2: 4.9→156 kW; 0.85·k14: 18→107;
   0.80·k6: 15→134; 0.80·k4: 0.2→131. Commit as
   `docs/outreach/figures/data/settle_dumbbell.csv`.
2. **fig3 viability heatmap** — the full k × λ grid per chart-prd.md Figure 3
   coordinate map (48 catalog cells + Round 3/4 variants + kickstart overrides).
   Commit as `docs/outreach/figures/data/viability_grid.csv` with columns
   `blade,k,P_kw,pass,source` (source ∈ catalog/kickstart/r3/r4).

## Task 4 — Provenance re-stamp inputs

For each figure the laptop rebuilds, it needs: true git hash of the code state
that produced the catalog (provenance boxes currently say 8cb23f9 — confirm),
and row counts / md5 of the two local CSVs. Put these in
`equilibrium-reconciliation.md` under a "Provenance" heading.

## Sequencing

Task 1 blocks the design-cards and power-curve rework. Tasks 2–3 are
independent. Commit everything to master and note completion in a reply
handover; the laptop resumes .tex work on pull.
