# CLAUDE.md — Developer & Agent Guide

Welcome to the **KiteTurbineDynamics.jl** workspace. This guide contains key entry points, domain documents, and standard execution commands for developers and agent sessions.

## ── Domain Documentation ──────────────────────────────────────────────

This repository uses a single-context domain documentation layout:
* **Core Context**: [CONTEXT.md](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/CONTEXT.md) at the repository root.
* **Design & Optimization Decisions**: [DECISIONS.md](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/DECISIONS.md) at the repository root.
* **Architectural Decisions**:
  * [docs/adr/0001-inertia-relief.md](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/adr/0001-inertia-relief.md) — 6-DOF moment and torsional inertia relief.

## ── Developer Commands ────────────────────────────────────────────────

### Julia Package & Test Commands

* **Activate Environment**: Use `--project=.` or `Pkg.activate(".")` inside the repository.
* **Run Entire Test Suite** (~48 seconds):
  ```bash
  julia --project=. test/runtests.jl
  ```
* **Run a Single Unit Test**:
  ```bash
  julia --project=. test/test_forces.jl
  ```
* **Launch Interactive Telemetry Dashboard** (Makie GUI):
  ```bash
  julia --project=. scripts/interactive_dashboard.jl
  ```

### Physics & Sizing Campaigns

* **Export White-Background System Rendering (GLMakie)**:
  ```bash
  julia --project=. scripts/export_glmakie_render.jl
  ```
* **Run v5 Optimization & Sizing Sweep**:
  ```bash
  julia --project=. scripts/run_v5_campaign.jl
  ```
* **Run MPPT Twist Sweep (v2 Sweep)**:
  ```bash
  julia --project=. scripts/mppt_twist_sweep_v2.jl
  ```

### Python Utilities & Report Patching

All Python tools should be executed using the system Python `/usr/bin/python3` which has pre-installed libraries (like `python-docx`).

* **Regenerate Sizing & Wake Figures**:
  ```bash
  /usr/bin/python3 scripts/reconstruct_lift_kite_figures.py
  /usr/bin/python3 scripts/vortex_expansion_analysis.py
  ```
* **Patch and Verify Engineering Reports** (Cp claims, mass budgets, tension numbers):
  ```bash
  /usr/bin/python3 scripts/patch_docx_reports.py
  ```
* **Insert GLMakie Render into Lift Kite Sizing Report**:
  ```bash
  /usr/bin/python3 scripts/insert_rendering_to_report.py
  ```

## ── Development Guidelines ────────────────────────────────────────────

1. **Keep the Test Suite Green**: Always run the package test suite (`test/runtests.jl`) to verify repository integrity after making changes.
2. **Physics Conservatism**: Ensure all physical calculations conform to the BEM-coupled v2/v5 solver formulations.
3. **Idempotence**: Maintain report patching scripts so they are fully idempotent.
