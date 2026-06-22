# Domain Knowledge for Agents — KiteTurbineDynamics.jl

**Purpose:** Give any AI agent or human collaborator arriving fresh the minimum context needed to work productively in this repository.

## Quick Start

1. **Read these first:** `CONTEXT.md` (physics glossary) → `DECISIONS.md` (design rationale) → `CLAUDE.md` (dev commands)
2. **Run the test suite:** `julia --project=. test/runtests.jl` (~3 min, 917 tests). Never commit with failures.
3. **Launch a dashboard:** `julia --project=. scripts/interactive_dashboard.jl --v10`
4. **Understand the physics:** Every tether, bridle, and line must transmit force only in TENSION. Slack = failure.

## Repository Map

| What | Where | Why |
|------|-------|-----|
| Physics & decisions | `CONTEXT.md`, `DECISIONS.md` | Understand the TRPT, campaign history, design choices |
| Dev commands | `CLAUDE.md`, `AGENTS.md` | Build, test, lint, run campaigns |
| Source code | `src/` | 28 Julia files — entry at `src/KiteTurbineDynamics.jl` |
| Test suite | `test/` | 27 test files, 917 tests |
| Campaign scripts | `scripts/` | DE optimisers, analysis, rendering |
| Campaign results | `scripts/results/` | V2 through V10 Tight, CSVs and JSONs |
| Reports | `docs/reports/`, `archive/reports/` | .docx and .md reports |
| Plans | `docs/plans/` | Implementation plans for each campaign phase |
| Architecture decisions | `docs/adr/` | Recorded design rationale |
| Diagrams | `docs/awes-forum-diagrams/` | Specs, generated PNGs, PCA landscapes |
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
- **Static-vs-dynamic gap:** Static equilibrium solver predicts 50 kW; full multibody ODE shows ~12 kW. Gap exists because static solver's 1D power balance ignores torque transmission through TRPT.

## Current Campaign State

| Campaign | Best Mass | Rotors | Key Finding |
|----------|-----------|--------|-------------|
| V6.3 | 52.6 kg | 6 expansion | Many small fans beat one big one |
| V10 | 76.75 kg | 1 | PCA decoupling, two-basin trap, slenderness gate |
| **V10 Tight** | **49.2 kg** | **4** | k_mppt fix + ring-mapping fix unlocked multi-rotor |

## What the Optimizer Is Telling Us

- **5 parameters at upper bounds** — the DE wants more design freedom than we gave it
- **Multi-rotor designs need positive incentive** — gate fixes alone don't change the basin attractor
- **Static solver is not enough** — need dynamic verification to catch slack/infeasible designs
- **λ gradient < 7** required to reach Basin A (optimum); higher gradients trap designs in Basin B

## External Resources

- **Agents-K1:** `/home/rod/Documents/kites/agents-k1/` — Scholar knowledge graph framework
- **AWES Knowledge Graph:** `/home/rod/Documents/kites/awes_graph/` — 540 papers, 7,401 nodes
- **AWES Paper Corpus:** `/home/rod/Documents/kites/investigation/` — 540 PDFs
- **KTD Paper Pipeline:** `/home/rod/Documents/kites/ktd_paper_graph/` — Reverse ingestion → paper draft
- **TRPTSim:** `/home/rod/Documents/GitHub/TRPTSim/` — TRPT airborne wind energy simulator
- **10kW Prototype:** `/home/rod/Documents/GitHub/10kWKiteTurbine/` — Physical prototype docs

## Conventions

- **SI units** everywhere; angles in degrees at API boundary
- **JuliaFormatter** (Blue style) before committing
- **New src/ file** → add `include()` and `export` in `src/KiteTurbineDynamics.jl` → wire test in `test/runtests.jl`
- **Physics findings** → record in `DECISIONS.md`
- **Implementation plans** → write to `docs/plans/YYYY-MM-DD-description.md` before coding
- **Report generation** → idempotent scripts in `scripts/`, output to `docs/awes-forum-diagrams/`
