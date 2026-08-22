# Domain Knowledge for Agents — KiteTurbineDynamics.jl

**Purpose:** Give any AI agent or human collaborator arriving fresh the minimum context needed to work productively in this repository.

## Quick Start

1. **Read these first:** `CONTEXT.md` (physics glossary) → `DECISIONS.md` (design rationale) → `CLAUDE.md` (dev commands)
2. **Run the test suite:** `julia --project=. test/runtests.jl` (see `test/runtests.jl` for the current set). Never commit with failures.
3. **Launch a dashboard:** `julia --project=. scripts/interactive_dashboard.jl --v10`
4. **Understand the physics:** Every tether, bridle, and line must transmit force only in TENSION. Slack = failure.

## Repository Map

| What | Where | Why |
|------|-------|-----|
| Physics & decisions | `CONTEXT.md`, `DECISIONS.md` | Understand the TRPT, campaign history, design choices |
| Dev commands | `CLAUDE.md`, `AGENTS.md` | Build, test, lint, run campaigns |
| Source code | `src/` | 39 Julia files — entry at `src/KiteTurbineDynamics.jl` |
| Test suite | `test/` | see `test/runtests.jl` |
| Campaign scripts | `scripts/` | DE optimisers, analysis, rendering |
| Campaign results | `scripts/results/` | V2 through V10 Tight, CSVs and JSONs |
| Reports | `docs/reports/`, `archive/reports/` | .docx and .md reports |
| Plans | `docs/plans/` | Implementation plans for each campaign phase |
| Architecture decisions | `docs/adr/` | Recorded design rationale |
| Diagrams | `docs/awes-forum-diagrams/` | Specs, generated PNGs, PCA landscapes |
| Porto 2026 | `docs/porto-2026/` | Collaboration map, citation lineage, paper outline |
| Video | `.video/`, `docs/awes-forum-diagrams/video-interpretation/` | Explainer video project |
| Agent handoffs | `handovers/` | Session-to-session handoff documents |
| Inventory | `PROJECT_ROOM.md`, `01_source_inventory.md` | Navigate the repo |

## Physics Fundamentals (TL;DR)

- **TRPT** = Tensile Rotary Power Transmission. A shaft of tethers and rings that transmits rotor torque to the ground generator.
- **Rings** are compression beams in a polygon. More sides = less compression per beam, but more knuckles and tethers.
- **Expansion rotors** are aerodynamic blades on the rings that generate radial force, spreading the tethers outward to increase effective ring radius. Same blade as generating rotor — just banked.
- **Force-first:** Blade lift → resolve through bank angle → radial force injected into structural solver.
- **Tension-only:** Every line/bridle/tether must be in tension. Negative cumulative thrust on any ring = infeasible design.
- **k_mppt:** Generator control coefficient. MUST scale with λ² in the equilibrium solver (commit `1c86b69`).
- **Ring mapping:** Hub ring is position 1, counting down the shaft. Ring index = n_rings − mask_pos + 1. Fixed +2 offset (commit `71ea694`).
- **Static-vs-dynamic gap (RESOLVED 2026-08-12):** The historical gap (static solver predicts 50 kW; ODE shows ~12 kW / stalls at ω≈−0.2) was traced to hardcoded ζ=1.5 rope damping + the tension rectifier in `rope_forces.jl`, producing a DC reverse-torque bias. With ζ=0.05 (`SystemParams.zeta`), the ODE sustains power and matches BEM predictions. See DECISIONS.md [2026-08-12].

## Current Campaign State

| Campaign | Best Mass | Rotors | Key Finding |
|----------|-----------|--------|-------------|
| V6.3 | 52.6 kg ⚠ | 6 expansion | Many small fans beat one big one. **⚠ Dynamically impossible** — parasitic drag 14,277× aero power. Maths artefact, not a real design. |
| V10 | 76.75 kg | 1 | PCA decoupling, two-basin trap, slenderness gate |
| **V10 Tight (RETRACTED)** | 49.2 kg | 4 | centre-constraint spokes artificially stiff — retracted 2026-07-13 |
| **5 kW validated base (2026-08-22)** | — | 1 (hub) | Honest-window evaluator (relax 10 + window 40), unified λ³ blade-mass law (m_ref 0.420 kg), main rotor modelled once (hub double-model removed), k=2.24, 18.8 m. **DE CAMPAIGN RUNNING** (`scripts/run_v13_5kw_masslift.jl`, mass_min, FoS 2.5, P floor 5 kW). Seed sustains 8.0 kW on 60 m². See `handover-2026-08-22-validated-5kw-campaign-launched.md`. |

Pre-2026-08-22 5 kW winners are VOID (50 kW blade mass, wrong-length machine,
hub double-model). See `docs/validation/physics-validation-ledger.md` for what
is believed and why.

## What the Optimizer Is Telling Us

- **5 parameters at upper bounds** — the DE wants more design freedom than we gave it
- **Multi-rotor designs need positive incentive** — gate fixes alone don't change the basin attractor
- **Static solver is not enough** — need dynamic verification to catch slack/infeasible designs
- **λ gradient < 7** required to reach Basin A (optimum); higher gradients trap designs in Basin B

## External Resources

### Knowledge Pipeline (K1)
- **Workspace:** `/home/rodbot/Documents/kites/` — extraction scripts, data, model
- **Knowledge graph:** `/home/rodbot/Documents/kites/awes_graph/awes_unified.graph.json` — 7,048 nodes, 9,775 edges (540 academic + 45 industry, 586 individual graph files)
- **Paper texts:** `/home/rodbot/Documents/kites/awes_texts/` (540 markdown files)
- **Industry texts:** `/home/rodbot/Documents/kites/industry_texts/` (45 markdown files)
- **K1 model:** `/home/rodbot/Documents/kites/models/agents-k1/` — 4B, RTX A4500 GPU, single-doc mode preferred
- **Pipeline scripts:** `/home/rodbot/Documents/kites/scripts/` — 16 Python scripts
- **Phase results:** Phase 1 (collab map), Phase 3 (citation lineage), Phase 3b (web validation) — all complete
- **Crons:** ALL PAUSED as of 2026-06-23. Do not restart without explicit direction.
- **Session record:** `docs/reports/knowledge-pipeline-sprint.md`
- **graphanything CLI:** BROKEN — use direct API calls via `k1_ingest.py`

### Related Repos
- **TRPTSim:** `/home/rodbot/Documents/GitHub/TRPTSim/` — TRPT airborne wind energy simulator
- **TetherDragODESolver:** `/home/rodbot/Documents/GitHub/TetherDragODESolver/` — Tether drag ODE (Tveide)
- **CoaxialAutogyroStacking.jl:** `/home/rodbot/Documents/GitHub/CoaxialAutogyroStacking.jl/` — Autogyro lift model
- **10kW Prototype:** `/home/rodbot/Documents/GitHub/10kWKiteTurbine/` — Physical prototype docs

## Conventions

- **SI units** everywhere; angles in degrees at API boundary
- **JuliaFormatter** (Blue style) before committing
- **New src/ file** → add `include()` and `export` in `src/KiteTurbineDynamics.jl` → wire test in `test/runtests.jl`
- **Physics findings** → record in `DECISIONS.md`
- **Implementation plans** → write to `docs/plans/YYYY-MM-DD-description.md` before coding
- **Report generation** → idempotent scripts in `scripts/`, output to `docs/awes-forum-diagrams/`
