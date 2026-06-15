# Source Inventory — KiteTurbineDynamics.jl

**Prepared:** 2026-05-24  
**Status:** Updated & Verified  
**Purpose:** Foundational catalogue of every file in the workspace. Establishes path, type, date signal, authority, and current/superseded status.

---

## How to read this table

- **Authority** — how reliable the file is as a source of truth: `canonical` (code is law), `derived` (generated from another source), `analytical` (hand-assembled), `intermediate` (working notes), `artefact` (build output).
- **Status** — `current`, `stale`, or `superseded`.
- **Use as** — what role this file plays.

---

## A. Root Branch (master) — Source Code

All 23 source files, `Project.toml`, and `Manifest.toml` are **fully present and verified** on the `master` branch. All tests pass successfully (519/519).

| Path | Type | Date signal | Authority | Status | Use as |
|---|---|---|---|---|---|
| `src/KiteTurbineDynamics.jl` | Julia source | May 2026 | canonical | current | Package entry point |
| `src/aerodynamics.jl` | Julia source | May 2026 | canonical | current | BEM Lookup tables & aerodynamic forces |
| `src/bem.jl` | Julia source | May 2026 | canonical | current | BEM Cp(solidity, TSR) coupling |
| `src/catenary.jl` | Julia source | May 2026 | canonical | current | Backline catenary force solver |
| `src/dynamics.jl` | Julia source | May 2026 | canonical | current | Multi-body system dynamic derivatives |
| `src/economics.jl` | Julia source | May 2026 | canonical | current | LCOE, capital cost, carbon payback |
| `src/geometry.jl` | Julia source | May 2026 | canonical | current | Coordinate rotations and projections |
| `src/initialization.jl` | Julia source | May 2026 | canonical | current | Settle-to-equilibrium solver |
| `src/lift_kite.jl` | Julia source | May 2026 | canonical | current | Autogyro / active lift device model |
| `src/objective_v5.jl` | Julia source | May 2026 | canonical | current | v5 optimization fitness function |
| `src/parameters.jl` | Julia source | May 2026 | canonical | current | Default physical & control parameters |
| `src/ring_element_analysis.jl` | Julia source | May 2026 | canonical | current | Space-frame ring element FEA solver |
| `src/ring_forces.jl` | Julia source | May 2026 | canonical | current | Intermediate spacer ring forces |
| `src/ring_spacing.jl` | Julia source | May 2026 | canonical | current | v4/v5 geometric L/r spacing solver |
| `src/rope_forces.jl` | Julia source | May 2026 | canonical | current | Tether spring-damper force models |
| `src/sim_frame.jl` | Julia source | May 2026 | canonical | current | SimFrame and dashboard data structures |
| `src/simulation.jl` | Julia source | May 2026 | canonical | current | Run simulation loop |
| `src/structural_safety.jl` | Julia source | May 2026 | canonical | current | Ring buckling & stress margin check |
| `src/trpt_axial_profiles.jl` | Julia source | May 2026 | canonical | current | Structural envelope axial profiles |
| `src/trpt_optimization.jl` | Julia source | May 2026 | canonical | current | Sizing optimization algorithms |
| `src/types.jl` | Julia source | May 2026 | canonical | current | Node and Segment type definitions |
| `src/visualization.jl` | Julia source | May 2026 | canonical | current | Interactive GLMakie dashboard rendering |
| `src/wind_profile.jl` | Julia source | May 2026 | canonical | current | Wind shear & turbulence profiles |

---

## B. Root Branch — Documentation

| Path | Type | Date signal | Authority | Status | Use as |
|---|---|---|---|---|---|
| `CLAUDE.md` | Agent config | May 2026 | canonical | current | Agent config and triage (updated) |
| `CONTEXT.md` | Orientation | May 2026 | canonical | current | Domain architecture orientation |
| `DECISIONS.md` | Architectural log | May 2026 | canonical | current | Architectural decisions history |
| `NOTES_LIFT_KITE.md` | Research notes | Apr 2026 | intermediate | partially stale | Lift device analysis context |
| `NOTES_MPPT_TWIST.md` | Research notes | Apr 2026 | intermediate | partially stale | MPPT sweep intent |
| `docs/validation/2026-04-19-report-validation.md` | Validation audit | 2026-04-19 | canonical | current | Authoritative report validity review |
| `docs/dashboard-spec.md` | Spec | Mar 2026 | intermediate | current | Dashboard UI specifications |

---

## C. Root Branch — Word Reports (.docx)

| Path | Type | Authority | Validation Status | Corrected Status |
|---|---|---|---|---|
| `TRPT_Ring_Scalability_Report.docx` | Word | analytical | Stale rated tension (2333 N instead of 820 N) | **Patched** (corrected tension & ring mass) |
| `TRPT_Lift_Device_Analysis.docx` | Word | analytical | Stale hub excursion tables in §4.3/4.4 | **Patched** (current excursion stats) |
| `TRPT_Twist_Analysis.docx` | Word | analytical | ❌ Peak Cp=0.43 claim is wrong (should be 0.232) | **Patched** (corrected Cp & updated §3.1) |
| `TRPT_Conical_Stack_Analysis.docx` | Word | analytical | Physics correct; missing `/tmp` source script | **Current** (reproducible script added) |
| `TRPT_Stacked_Rotor_Analysis.docx` | Word | analytical | Blades CoM corrigendum applied | **Current** |
| `Lift_Kite_Sizing_Report.docx` | Word | analytical | Content correct; missing `/tmp` script | **Current** (reproducible script added) |
| `TRPT_Dynamics_Report.docx` | Word | analytical | Script-generated | **Current** |
| `TRPT_FreeBeta_Report.docx` | Word | analytical | Script-generated | **Current** |
| `TRPT_KiteTurbine_Potential.docx` | Word | analytical | Script-generated | **Current** |

---

## D. Root Branch — Scripts

| Path | Type | Authority | Status | Use as |
|---|---|---|---|---|
| `scripts/interactive_dashboard.jl` | Julia script | canonical | current | Interactive GLMakie simulation UI |
| `scripts/calibrate_dlf.jl` | Julia script | canonical | current | Design Load Factor calibration |
| `scripts/torsional_collapse_check.jl` | Julia script | canonical | current | Tulloch torsional collapse checking |
| `scripts/cold_start_collapse.jl` | Julia script | canonical | current | Run cold-start launch collapse |
| `scripts/mppt_twist_sweep_v2.jl` | Julia script | canonical | current | MPPT twist sweep v2 (authoritative) |
| `scripts/run_v5_safe_campaign.jl` | Julia script | canonical | current | v5-safe optimization campaign script |
| `scripts/produce_awes_forum_report.py` | Python script | canonical | current | Assembles AWES Forum report |
| `scripts/reconstruct_lift_kite_sizing.jl` | Julia script | canonical | NEW | Sizing figures generator (restored) |
| `scripts/vortex_expansion_analysis.jl` | Julia script | canonical | NEW | Conical stack expansion script (restored) |

---

## E. Root Branch — Results Data

| Path | Type | Authority | Status | Use as |
|---|---|---|---|---|
| `scripts/results/lift_kite/long_summary.csv` | CSV | derived | current | Authoritative hub excursion metrics |
| `scripts/results/lift_kite/simdata.js` | JS | derived | current | Interactive dashboard data |
| `scripts/results/mppt_twist_sweep/twist_sweep_v2_summary.csv` | CSV | derived | current | Authoritative MPPT sweep data |
| `scripts/results/trpt_opt_v5/campaign_status.md` | MD | derived | current | v5 11.47 kg optimization winner summary |

---

## F. Agent Worktrees & Obsolete Branches

**All 8 physical agent worktrees have been pruned and deleted.**  
**All 50 obsolete local `claude/*` branches have been successfully deleted.**

The `master` branch is verified as the sole, advanced, authoritative source of truth.

---

*End of Source Inventory (Updated 2026-05-24)*
