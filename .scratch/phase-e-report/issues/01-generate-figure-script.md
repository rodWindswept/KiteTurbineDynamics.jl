# Ticket 1 — Generate Figure Data Script

**What to build:** A single Julia script `scripts/generate_phase_e_figures.jl` that reads named, provenance-stamped datasets and produces 5 self-compiling TikZ `.tex` figure files in `docs/outreach/figures/`. Each figure file must carry a header comment citing the exact data source (CSV path, commit hash, builder name, date).

**Blocked by:** None — can start immediately.

**Datasets referenced** (all read from `scripts/results/control_maps/`):

| Figure | Data source | Content |
|--------|-------------|---------|
| F1 — Design landscape | `phase-d-table.csv` (to be created from Phase D findings) | FoS, ω, P, blade_scale, tether_d, r_bottom for 9 designs |
| F2 — Structural envelope | Same as F1 | FoS vs tether_d, annotated with cascade threshold |
| F3 — Power curve | `gate2_v10_reinforced_maxpower_summary.csv` | P, ω, FoS at 5–15 m/s |
| F4 — Spoke drift | Per-second FoS logs from 3.5mm cascade test | Max vertex drift per ring vs time |
| F5 — Loss model | `gate1_v10_tight_maxpower_summary.csv`, `gate1_v10_reinforced_maxpower_summary.csv` | P_loss, ω for c·ω³ fit |

**Script behaviour:**
- Fails loudly if any expected CSV is missing (exit code 1 with message)
- Each output `.tex` file header: `% Source: <csv_path> @ <commit_hash> — <builder> — <date>`
- TikZ style: match `docs/awes-forum-diagrams/diagram1-polygon-v4.tex` conventions (axis labels, font sizes, colour palette)
- No hardcoded data — reads from CSVs only

**Acceptance criteria:**
- [ ] Script runs `julia --project=. scripts/generate_phase_e_figures.jl` and exits 0
- [ ] Five `.tex` files exist in `docs/outreach/figures/`
- [ ] Each file compiles standalone with `pdflatex`
- [ ] Each file's header comment cites correct data source

**Status:** ready-for-agent
