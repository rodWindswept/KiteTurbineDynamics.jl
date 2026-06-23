# Project Room — KiteTurbineDynamics.jl

**Created:** 2026-06-16 · **Updated:** 2026-06-23 (Phase 1–3b, Porto prep, audit Pass 1–2 applied)

Systematic inventory of the repository. These files live at the repo root so any agent arriving fresh sees them immediately.

## Structure

| File | Purpose | Status |
|------|---------|--------|
| `01_source_inventory.md` | Every file logged with path, type, date, authority, limitations, and status | Updated 2026-06-22 |
| `02_conflict_log.md` | 8 conflicts surfaced for review | **NOT YET CREATED** — referenced but missing |
| `03_missing_context.md` | 10 gaps identified | **NOT YET CREATED** — referenced but missing |
| `04_duplicates_report.md` | Version families identified (4 resolved, 5 open) | Created 2026-06-22 |
| `PROJECT_ROOM.md` | This file | Updated 2026-06-22 |

## What's New Since June 16

### V10 Campaign Era (June 20-22, 2026)
- **`src/objective_v10.jl`** — Full V10 objective with rotor masks, tension gate, slenderness gate, k_mppt λ² scaling
- **`src/headless_verify.jl`** — Structural verification gate + k_mppt scan for dynamic validation
- **`scripts/run_v10_campaign.jl`** — V10 DE campaign runner (60 islands, 14 DoF)
- **`scripts/interactive_dashboard.jl`** — GLMakie dashboard for visual physics verification
- **7 launch scripts** (`launch_v10*.sh`) for different campaign configurations
- **15+ render/export scripts** for non-dimensional atlas, parameter pairs, 3D landscapes
- **Campaign results**: `scripts/results/v10_campaign_50kw/` (310K evaluations, 76.75 kg) and `v10_campaign_50kw_old/` (parameter traces)
- **`docs/awes-forum-diagrams/v10-nondimensional-atlas.md`** — Non-dimensional π-group analysis
- **`docs/awes-forum-diagrams/v10-traced-paths.md`** — Island convergence path analysis
- **`docs/awes-forum-diagrams/v10-tight-diagrams.md`** — V10 Tight results (49.2 kg, 4 rotors)
- **`docs/reports/v10-tight-analysis.md`** — V10 Tight campaign report
- **`references/rotor-sizing-problem.md`** — Rotor sizing physics reference
- **5 new plans** in `docs/plans/` covering V9 dynamic equilibrium, V10 constraints, V11 tapered tethers

### Key Physics Fixes (Committed)
| Commit | What | Impact |
|--------|------|--------|
| `71ea694` | Ring-mapping +2 offset corrected | Rotors now placed on correct rings |
| `1c86b69` | k_mppt scales with λ² in equilibrium solver | Multi-rotor designs become viable |
| `2078ad8` | Headless verify gates + k_mppt slider fix | Dashboard range 1:2000 |
| `9def0df` | Rotor clamp removed + tension-distribution gate | Allows rotors on lower rings |
| `3c9ad82` | Hub-rotor mask filter (60→19 masks) | Eliminates hub-less designs |

### Video Production
- **`.video/`** — 4-minute explainer video project for AWEC 2026 / collaborators
- **`docs/awes-forum-diagrams/video-interpretation/`** — Updated transcript with V10 Tight results, tension gate, static-vs-dynamic gap, Agents-K1

### Agents-K1 Knowledge Pipeline (Updated Jun 23)
- **540 academic papers + 45 industry documents** ingested — **7,048 nodes, 9,775 edges** in unified graph (586 individual graph files, 878 paper nodes)
- **Phase 1 (collaboration map)** complete — identified 10 priority researchers, research density gaps, W&I's unique multi-kite/farm lane
- **Phase 3 (citation lineage)** complete — 6 KTD techniques grounded in literature with per-technique citation maps
- **Phase 3b (web validation)** complete — all 3 high-risk claims validated clean (Moore CSR ≠ inertia relief; Wacker ≠ ring-mapping; 4.2× gap is TRPT-unique)
- **All 3 crons paused** 2026-06-23 — ingestion complete, GPU freed for Porto preparation
- **`/home/rod/Documents/kites/`** — extraction workspace (scripts, graphs, model). Project room at KTD.jl root
- **Porto materials:** `docs/porto-2026/collaboration-map.md`, `citation-lineage.md`, `KTD-paper-outline.md`
- **Session record:** `docs/reports/knowledge-pipeline-sprint.md`
- **Handover:** `handovers/handover-2026-06-23-knowledge-pipeline.md`

### Files Referenced But Not Yet Created
- `02_conflict_log.md` — 8 conflicts need documentation
- `03_missing_context.md` — 10 gaps need documentation

## Key Numbers (Current — June 22, 2026)

| Metric | Value | Source |
|--------|-------|--------|
| Best airborne mass | **49.2 kg** | V10 Tight campaign |
| Best single-rotor mass | 76.75 kg | V10 campaign |
| Rotor count (V10 Tight) | 4 | V10 Tight optimum |
| Tip-speed ratio | λ = 0.519 | V10 Tight |
| Static power prediction | 50 kW | Equilibrium solver |
| Dynamic power actual | 12 kW | Full multibody ODE |
| Parameters at bounds | 5 | bank_angle, n_exp, n_lines, λ_top, λ_bottom |
| Parameters total | 14 | V10 design vector |
| Campaign evaluations | 310,000 | V10 convergence_history.csv |
| Papers in KG | 540 academic + 45 industry | Agents-K1 |
| Graph nodes | 7,048 | awes_unified.graph.json |
| Graph edges | 9,775 | awes_unified.graph.json |
| Individual graph files | 586 | awes_graph/ |
| Paper nodes in graph | 878 | awes_unified.graph.json |
| TRPT researchers identified | 8 | K1 graph |
| KTD techniques grounded | 6 | Phase 3 + 3b |
| Web-validated claims | 3/3 clean | Phase 3b |
| Test suite | 917 tests | `test/runtests.jl` |

## Remaining Cleanup (unchanged from June 16)

- Rename `pitch_depower_campaign_v5_safe.jl` → `pitch_depower_campaign.jl`
- Archive old campaign result directories (D2, D8, D9)
- Archive old pitch depower scripts (D4)
- Archive old report generation scripts (D7)
- Add "SUPERSEDED" headers to old .md reports
- Create `02_conflict_log.md` and `03_missing_context.md`
- Resolve 8 conflicts (C1–C8)
- Address 10 missing context items (M1–M10)

## Usage

These documents are living references. When files are added, renamed, superseded, or deleted, update the relevant inventory, close resolved conflicts, and mark gaps as filled.

Do NOT use these documents to make automated changes. All resolution decisions (archiving, deleting, merging) must be made by the project owner.
