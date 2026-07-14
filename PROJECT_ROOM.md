# Project Room — KiteTurbineDynamics.jl

**Created:** 2026-06-16 · **Updated:** 2026-07-14 (codebase audit applied)

Systematic inventory of the repository. Root-level files so any agent sees them immediately.

## Root documents

| File | Purpose | Status |
|------|---------|--------|
| `AGENTS.md` | Cross-tool agent conventions (Hermes, Codex, OpenCode) | Active |
| `CLAUDE.md` | Claude-specific commands and workflows | Active |
| `README.md` | Human entry point, architecture overview | Active |
| `CONTEXT.md` | Domain vocabulary, architecture, campaigns, source map | Active |
| `DECISIONS.md` | Running design decision log | Active |
| `CHANGELOG.md` | User-facing version history | Active |
| `CONTRIBUTING.md` | Contribution guidelines | Active |
| `PROJECT_ROOM.md` | This file — repo inventory | Active |
| `TODO_ADVANCED_VISUALS.md` | Forward-looking visual evidence wishlist | Active |
| `docs/case-notes/01_source_inventory.md` | File-level inventory with metadata | Moved from root |
| `docs/case-notes/02_conflict_log.md` | Surfaced conflicts for review | Moved from root |
| `docs/case-notes/03_missing_context.md` | Identified context gaps | Moved from root |
| `docs/case-notes/04_duplicates_report.md` | Version families, resolved + open | Moved from root |
| `docs/archive/` | Superseded docs (PLAN.md, RESTART_INSTRUCTIONS.md, TODO.md) | Archived |
| `docs/RECAP.md` | 5 engineering breakthrough narratives | Active |
| `handovers/` | Agent handoff documents (`handover-YYYY-MM-DD[-topic].md`) | Active |

## Source layout

```
src/
├── KiteTurbineDynamics.jl     Package entry; all includes + exports
├── builders_util.jl           V10 system builders (promoted from scripts/ Jul 14)
├── control_map_hunt.jl        ControlMapHunt module (promoted from scripts/ Jul 14)
├── types.jl, parameters.jl    Core types and parameter sets
├── aerodynamics.jl, bem.jl    BEM aerodynamics + solidity model
├── wind_profile.jl            Wind shear + turbulence
├── geometry.jl, initialization.jl
├── rope_forces.jl, ring_forces.jl, dynamics.jl   ODE core
├── simulation.jl, sim_frame.jl, sim_runner.jl     Simulation runners
├── structural_safety.jl, ring_element_analysis.jl  FEA + FoS
├── lift_kite.jl               Lift device type hierarchy
├── expansion_rotor.jl, expansion_stack.jl, expansion_analysis.jl
├── ring_spacing.jl, trpt_axial_profiles.jl        TRPT geometry
├── trpt_optimization.jl       DE evaluator
├── objective_v6.jl, objective_v10.jl              Campaign objectives
├── soft_ramp_controller.jl    k_mppt auto-ramp state machine
├── visualization.jl, dashboard_panels.jl, dashboard_v2.jl   GLMakie dashboards
├── spacer_ring_design.jl, catenary.jl, economics.jl
scripts/
├── launchers/                  Shell scripts for campaigns + dashboards
├── diagnostics/                verify_*.jl, campaign test runners (moved from test/)
├── hunt_kmppt_bisect.jl        Shim → src/control_map_hunt.jl
├── builders_util.jl            Shim → src/builders_util.jl
├── wind_sweep.jl, catalog_sweep.jl, crossover_sweep.jl   Current sweeps
├── power_curve_quick.jl        Quick power curve generator
├── interactive_dashboard.jl    GLMakie launcher
├── run_v*_campaign.jl          DE campaign runners
├── results/                    Simulation output CSVs (campaign CSVs now tracked)
test/
├── runtests.jl                 24 test suites wired
├── test_*.jl                   24 unit test files
docs/
├── adr/                        Architecture Decision Records
├── agents/                     Issue tracker, triage labels, domain reference
├── awes-forum-diagrams/        Diagram specs + generated PNGs
├── case-notes/                 Audit inventories, physics corrections
├── community/                  Community report + Strathclyde posters
├── handover/                   (empty — consolidated into handovers/)
├── outreach/                   Phase E design landscape charts + figures
├── plans/                      Implementation plans per phase
├── porto-2026/                 AWEC 2026 Porto paper materials
├── reports/                    Analysis reports
├── wayfinder-tickets/          WT1–WT5 resolution docs
```

## Campaign History

| Version | Power | Mass | n_lines | n_exp | Status | Date |
|---------|-------|------|---------|-------|--------|------|
| V6.0 | 50 kW | 184.84 kg | 8 | 1 | Octagon baseline | Jun 15 |
| V6.1 | 50 kW | 179.27 kg | 8 | 1 | +tension stiffening | Jun 15 |
| V6.2 | 50 kW | 74.17 kg | 12 | 1 | Corrected physics (tan→sin, cos²·⁶⁵) | Jun 17 |
| V6.3 | 50 kW | 52.61 kg ⚠ | 7 | 6 | Dynamically impossible | Jun 18 |
| V6.7 | 50 kW | 54.91 kg | 9 | 14 | Relaxed drag | Jun 22 |
| V8.0 | 50 kW | 58.41 kg | 9 | 3 | Per-component physics | Jun 24 |
| V9.0 | 50 kW | 44.52 kg | 8 | 9 | Dynamic ω solve | Jun 27 |
| V10 | 50 kW | 76.75 kg | 14 | 4 | Unified rotors, 8 gates | Jun 29 |
| V10 Tight | 50 kW | 49.20 kg ⚠ | 12 | 4 | Centre-constraint spoke bug — retracted | Jun 29 |
| V10 Tight (corrected) | 50 kW | — | — | — | Per-vertex spokes — Phase D/E active | Jul 13 |

## Current work (July 2026)

- **Phase E design landscape** — 13 viable V10 Tight designs, 5-figure chart set for community report
- **Per-vertex spoke springs** — physically correct tension-only model replacing centre-constraint
- **Power curves** — real simulation data at 5–15 m/s for 6 designs (`wind_sweep.csv`)
- **Codebase audit** — items 1–3, 6, 8, 13–14, 17 applied (Jul 14)

## Usage

These documents are living references. Update the relevant inventory when files change. All resolution decisions (archiving, deleting, merging) must be made by the project owner.
