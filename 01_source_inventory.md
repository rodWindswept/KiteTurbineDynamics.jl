# Source Inventory — KiteTurbineDynamics.jl

**Generated:** 2026-06-16
**Status:** Living document — update when files are added, renamed, or superseded

Every file in the repository (excluding `.git/`, `.julia/`, generated artifacts like `.png`/`.pdf`/`.csv`/`.log`/`.aux`, and build outputs). Source files only.

## Reading the table

| Column | Meaning |
|--------|---------|
| **Path** | Location relative to repo root |
| **Type** | `.jl` = Julia source, `.jl` test = test file, `.md` = documentation, `.docx` = report, `.sh` = shell script, `.py` = Python, `.toml` = config |
| **Date** | Last modification (from filesystem) |
| **Authority** | Apparent author or origin: `human` = Rod-authored, `agent` = AI-generated, `derived` = generated from other sources, `unknown` = unclear provenance |
| **Limitations** | What this file does NOT cover, or known issues |
| **Status** | `current` = actively used, `superseded` = replaced by newer version, `stale` = not maintained, `orphan` = not wired into any workflow, `placeholder` = approximate model |

---

## Root — Project Governance & Entry Points (post-cleanup)

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `AGENTS.md` | .md | Jun 3 | human | Cross-tool entry point; references CLAUDE.md for fuller detail | current |
| `CLAUDE.md` | .md | Jun 3 | human | Claude-specific conventions; references CONTEXT.md, DECISIONS.md | current |
| `CONTEXT.md` | .md | Jun 3 | human | Domain glossary and physics background | current |
| `DECISIONS.md` | .md | Jun 3 | human | Design decisions and campaign history; ~47KB, very detailed | current |
| `PLAN.md` | .md | Jun 16 | agent | Development plan; 54KB; references Phases 0–2.5 | current |
| `README.md` | .md | Jun 3 | human | Project overview; 45KB | current |
| `LICENSE` | text | Jun 3 | human | MIT | current |
| `CITATION.cff` | .cff | Jun 3 | human | Citation metadata | current |
| `Project.toml` | .toml | Jun 16 | derived | Julia project deps; modified this session (added ArgParse) | current |
| `Manifest.toml` | .toml | Jun 16 | derived | Julia dependency resolution; machine-specific | current |
| `.JuliaFormatter.toml` | .toml | Jun 3 | human | Blue style config | current |
| `.gitignore` | config | Jun 3 | human | Git ignore rules | current |
| `NOTES_LIFT_KITE.md` | .md | Jun 3 | human | 16KB; lift kite design notes | current |
| `NOTES_MPPT_TWIST.md` | .md | Jun 3 | human | 6.5KB; MPPT twist notes | current |
| `TODO.md` | .md | Jun 3 | human | Task list | current |
| `TODO_ADVANCED_VISUALS.md` | .md | Jun 3 | human | Visual roadmap | current |
| `RECAP.md` | .md | Jun 3 | human | Session recap | stale |
| `RESTART_INSTRUCTIONS.md` | .md | Jun 3 | human | 7.4KB; how to restart campaigns | current |

## Root — Shell Scripts

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `run_all.sh` | .sh | Jun 3 | human | Run all simulations | current |
| `run_all_sims.sh` | .sh | Jun 3 | human | Variant | unknown |
| `run_pitch_depower_overnight.sh` | .sh | Jun 3 | human | Overnight batch | current |
| `run_pitch_depower_v4.sh` | .sh | Jun 3 | human | v4 batch | superseded |
| `run_pitch_depower_v5_safe.sh` | .sh | Jun 3 | human | v5 safe batch | current |

## docs/reports/ — Reports & Session Artifacts

*Moved from root 2026-06-16. Original .docx reports plus session .md artifacts.*

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/reports/TRPT_AWE_Forum_Report_v4.docx` | .docx | Jun 3 | human | v4; 493KB; last .docx before .md rewrite | superseded by .md |
| `docs/reports/TRPT_Optimisation_Monograph.docx` | .docx | Jun 3 | human | 18KB | current |
| `docs/reports/TRPT_Optimisation_Report_v5.docx` | .docx | Jun 3 | human | 22KB | current |
| `docs/reports/TRPT_Design_Cartography_Report.docx` | .docx | Jun 3 | human | 1.9MB | current |
| `docs/reports/TRPT_Conical_Stack_Analysis.docx` | .docx | Jun 3 | human | 1.4MB | current |
| `docs/reports/TRPT_Dynamics_Report.docx` | .docx | Jun 3 | human | 1.3MB | current |
| `docs/reports/TRPT_Ring_Scalability_Report.docx` | .docx | Jun 3 | human | 871KB | current |
| `docs/reports/TRPT_Stacked_Rotor_Analysis.docx` | .docx | Jun 3 | human | 626KB | current |
| `docs/reports/TRPT_Lift_Device_Analysis.docx` | .docx | Jun 3 | human | 961KB | current |
| `docs/reports/TRPT_FreeBeta_Report.docx` | .docx | Jun 3 | human | 940KB | current |
| `docs/reports/TRPT_Twist_Analysis.docx` | .docx | Jun 3 | human | 438KB | current |
| `docs/reports/TRPT_KiteTurbine_Potential.docx` | .docx | Jun 3 | human | 433KB | current |
| `docs/reports/TRPT_Sizing_Optimization_Report.docx` | .docx | Jun 3 | human | 40KB | current |
| `docs/reports/Lift_Kite_Sizing_Report.docx` | .docx | Jun 3 | human | 1.1MB | current |
| `docs/reports/KTD_Novelty_and_Prior_Art_Review.docx` | .docx | Jun 3 | human | 21KB | current |
| `docs/reports/CRITIQUE_pitch_depower_campaigns.md` | .md | Jun 16 | agent | 23KB; campaign critique | current |
| `docs/reports/STATUS-2026-06-13-worktrees-and-staging.md` | .md | Jun 13 | agent | 16KB; worktree status | current |
| `docs/reports/pitch_depower_developer_report.md` | .md | Jun 16 | agent | 7.3KB | current |

## archive/reports/ — Superseded .docx Reports

| Path | Type | Date | Authority | Why archived |
|------|------|------|-----------|-------------|
| `archive/reports/TRPT_AWE_Forum_Report.docx` | .docx | Jun 3 | human | v1 — superseded by v4 + .md rewrite |
| `archive/reports/TRPT_AWE_Forum_Report_v2.docx` | .docx | Jun 3 | human | v2 — superseded |
| `archive/reports/TRPT_AWE_Forum_Report_v3.docx` | .docx | Jun 3 | human | v3 — superseded |

## handovers/ — Agent Handoff Documents

*Consolidated from `.hermes/`, root, and `docs/handover/` on 2026-06-16. Single canonical location for all agent-to-agent handoff documents.*

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `handovers/handover-2026-06-16.md` | .md | Jun 16 | agent | This session's comprehensive handoff | current |
| `handovers/handover-2026-06-14.md` | .md | Jun 14 | agent | Expansion rotor refactor summary | current |
| `handovers/handover-2026-05-28-pitch-depower-session.md` | .md | May 28 | agent | Pitch depower diagnostics | current |
| `handovers/handover-2026-05-26.md` | .md | May 26 | agent | | stale |
| `handovers/handover-2026-05-25.md` | .md | May 25 | agent | | stale |
| `handovers/handover-2026-05-18.md` | .md | May 18 | agent | | stale |
| `handovers/handover-2026-05-12.md` | .md | May 12 | agent | | stale |
| `handovers/handover-2026-05-11.md` | .md | May 11 | agent | | stale |
| `handovers/handover-2026-05-09.md` | .md | May 9 | agent | Early session handover | stale |
| `handovers/HANDOFF_pitch_depower_campaign.md` | .md | Jun 16 | agent | Pitch depower campaign handoff | current |
| `handovers/HANDOFF_pitch_depower_campaign_v3.md` | .md | Jun 16 | agent | v3 | superseded |

## scratch/ — Debugging & Ad-Hoc Scripts

*16 orphan test files moved from root 2026-06-16. Authorship unclear — these are debugging scripts, not formal tests. None are wired into `test/runtests.jl`.*

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `scratch/test_furl_state.jl` | .jl | Jun 3 | unknown | ad-hoc debugging | orphan |
| `scratch/test_furl_state_new.jl` | .jl | Jun 3 | unknown | Variant of above | orphan |
| `scratch/test_twist_shift.jl` | .jl | Jun 3 | unknown | ad-hoc | orphan |
| `scratch/test_twist_shift2.jl` | .jl | Jun 3 | unknown | Variant | orphan |
| `scratch/test_twist_shift3.jl` | .jl | Jun 3 | unknown | Variant | orphan |
| *(11 more — see full listing in scratch/)* | | | | | |

## scripts/results/_logs/ — Campaign Logs

*21 log files moved from root 2026-06-16.* All are derived stdout captures from campaign runs. Co-located with results for traceability. See `scripts/results/_logs/` for full listing.

## src/ — Julia Source (28 files)

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `src/KiteTurbineDynamics.jl` | .jl | Jun 12 | human | Module entry; 4.9KB; includes all other src files | current |
| `src/types.jl` | .jl | Jun 12 | human | Core type definitions; 6.0KB | current |
| `src/parameters.jl` | .jl | Jun 12 | human | System parameter sets; 21KB; defines params_10kw, params_v5_50kw, etc. | current |
| `src/aerodynamics.jl` | .jl | Jun 12 | human | BEM lookup tables, tether drag; 9.2KB | current |
| `src/bem.jl` | .jl | Jun 12 | agent | BEM module; 6.3KB; solidity exponent k=0.7 is PLACEHOLDER (line 75) | placeholder |
| `src/dynamics.jl` | .jl | Jun 12 | human | Multi-body ODE system; 7.0KB | current |
| `src/initialization.jl` | .jl | Jun 16 | mixed | Initial conditions and settling; 39KB; cos³→cos²·⁶⁵ fix applied this session | current |
| `src/simulation.jl` | .jl | Jun 16 | mixed | Simulation runner; 22KB | current |
| `src/sim_frame.jl` | .jl | Jun 16 | mixed | Frame capture/post-processing; 14KB; cos³→cos²·⁶⁵ fix applied | current |
| `src/ring_forces.jl` | .jl | Jun 16 | mixed | Rotor aero, generator MPPT, torsional damping; 19KB | current |
| `src/rope_forces.jl` | .jl | Jun 12 | human | Tether force computation; 8.9KB | current |
| `src/ring_element_analysis.jl` | .jl | Jun 16 | mixed | Ring FEA with beam-column interaction; 24KB | current |
| `src/ring_spacing.jl` | .jl | Jun 16 | mixed | v4 ring spacing (constant L/r); 17KB; TRPTDesignV4 struct; knuckle mass removed this session | current |
| `src/trpt_optimization.jl` | .jl | Jun 16 | mixed | TRPT structural evaluation; 29KB; knuckle_mass_at_ring() added, tan→sin fix applied | current |
| `src/trpt_axial_profiles.jl` | .jl | Jun 16 | mixed | v2 axial profile designs; 14KB; tan→sin in comments fixed | current |
| `src/objective_v5.jl` | .jl | Jun 12 | human | v5 BEM-coupled objective; 1.6KB; thin wrapper around v4 | current |
| `src/objective_v6.jl` | .jl | Jun 16 | mixed | v6.2 expansion rotor objective; 14KB; TRPT_V6_DIM=11 updated this session | current |
| `src/expansion_rotor.jl` | .jl | Jun 16 | mixed | Expansion rotor physics; 9.7KB; tan→sin fix applied to geometry_factor | current |
| `src/expansion_stack.jl` | .jl | Jun 16 | mixed | Expansion rotor stack config; 7.5KB | current |
| `src/expansion_analysis.jl` | .jl | Jun 16 | mixed | Expansion analysis utilities; 7.1KB | current |
| `src/lift_kite.jl` | .jl | Jun 12 | human | Lift kite models; 27KB; PCA-2 data duplicated from CoaxialAutogyroStacking | current |
| `src/spacer_ring_design.jl` | .jl | Jun 12 | human | Beam cross-section properties; 9.5KB | current |
| `src/structural_safety.jl` | .jl | Jun 12 | human | ODE-level structural monitoring; 5.7KB; references ring_element_analysis | current |
| `src/catenary.jl` | .jl | Jun 12 | human | Catenary calculations; 6.6KB | current |
| `src/geometry.jl` | .jl | Jun 12 | human | Geometric utilities; 2.6KB | current |
| `src/economics.jl` | .jl | Jun 12 | human | LCOE and mass costing; 15KB; hardcoded knuckle_mass_each=0.015 | current |
| `src/wind_profile.jl` | .jl | Jun 12 | human | Wind profile models; 4.6KB | current |
| `src/visualization.jl` | .jl | Jun 16 | mixed | Dashboard and plotting; 86KB; largest source file | current |

## test/ — Test Suite (27 files)

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `test/runtests.jl` | .jl test | Jun 10 | human | Test runner; includes all test files | current |
| `test/test_ring_spacing_v4.jl` | .jl test | Jun 16 | agent | v4 ring spacing tests; 8.9KB; updated for no-knuckle constructor this session | current |
| `test/test_trpt_axial_profiles.jl` | .jl test | Jun 16 | agent | v2 axial profile tests; 4.6KB; updated knuckle assertion this session | current |
| `test/test_expansion_rotor.jl` | .jl test | Jun 16 | agent | 4.0KB | current |
| `test/test_expansion_stack.jl` | .jl test | Jun 16 | agent | 4.3KB | current |
| `test/test_expansion_analysis.jl` | .jl test | Jun 16 | agent | 3.8KB | current |
| `test/test_bem_unified.jl` | .jl test | Jun 10 | agent | 3.4KB | current |
| `test/test_aerodynamics.jl` | .jl test | Jun 10 | agent | 474B | current |
| `test/test_ring_element_analysis.jl` | .jl test | Jun 3 | agent | 9.6KB | current |
| `test/test_spacer_ring_design.jl` | .jl test | Jun 3 | agent | 4.9KB | current |
| `test/test_metric_consistency.jl` | .jl test | Jun 3 | agent | 4.8KB | current |
| `test/test_bearing_alignment.jl` | .jl test | Jun 3 | human | 19KB; computationally heavy (ODE simulation) | current |
| `test/test_pitch_depower_control_campaign.jl` | .jl test | Jun 3 | human | 20KB | current |
| `test/test_stall_control_campaign.jl` | .jl test | Jun 3 | human | 16KB | current |
| `test/test_pitch_depower_sequence.jl` | .jl test | Jun 3 | human | 2.4KB | current |
| `test/test_dashboard_smoke.jl` | .jl test | Jun 3 | human | 1.7KB | current |
| `test/test_dynamics.jl` | .jl test | Jun 3 | human | 352B | current |
| `test/test_emergent_torsion.jl` | .jl test | Jun 3 | human | 1.1KB | current |
| `test/test_geometry.jl` | .jl test | Jun 3 | human | 1.4KB | current |
| `test/test_parameters.jl` | .jl test | Jun 3 | human | 191B | current |
| `test/test_power.jl` | .jl test | Jun 3 | human | 1.1KB | current |
| `test/test_ring_forces.jl` | .jl test | Jun 3 | human | 1.3KB | current |
| `test/test_rope_forces.jl` | .jl test | Jun 3 | human | 785B | current |
| `test/test_rope_sag.jl` | .jl test | Jun 3 | human | 1.6KB | current |
| `test/test_static_equilibrium.jl` | .jl test | Jun 3 | human | 831B | current |
| `test/test_types.jl` | .jl test | Jun 3 | human | 1.8KB | current |
| `test/verify_initialization_consistency.jl` | .jl test | Jun 3 | human | 4.0KB; verification script | current |
| `test/verify_simulation_consistency.jl` | .jl test | Jun 3 | human | 2.0KB; verification script | current |

## scripts/ — Campaign & Analysis Scripts (selected)

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `scripts/run_v6_campaign.jl` | .jl | Jun 16 | agent | V6.2 DE campaign runner; 18KB; updated for 11-DoF this session | current |
| `scripts/run_v5_campaign.jl` | .jl | Jun 3 | human | v5 campaign | superseded |
| `scripts/run_v4_campaign.jl` | .jl | Jun 3 | human | v4 campaign | superseded |
| `scripts/run_v5_safe_campaign.jl` | .jl | Jun 3 | human | v5 safe variant | superseded |
| `scripts/run_v6_cartography.jl` | .jl | Jun 3 | agent | v6 design space mapping | current |
| `scripts/run_v2_overnight_campaign.sh` | .sh | Jun 3 | human | v2 overnight batch | superseded |
| `scripts/run_trpt_optimization.jl` | .jl | Jun 3 | human | Original TRPT optimiser; 18KB | superseded |
| `scripts/run_trpt_optimization_v2.jl` | .jl | Jun 3 | human | v2 optimiser; 20KB | superseded |
| `scripts/run_trpt_baseline.jl` | .jl | Jun 3 | human | Baseline design | current |
| `scripts/run_expansion_sweep.jl` | .jl | Jun 3 | human | Expansion parameter sweep | current |
| `scripts/run_expansion_op_sweep.jl` | .jl | Jun 3 | human | Operating point sweep | current |
| `scripts/run_lhs_cartography.jl` | .jl | Jun 3 | human | LHS design space sampling | current |
| `scripts/pitch_depower_campaign.jl` | .jl | Jun 16 | human | Original pitch depower; 14KB | superseded |
| `scripts/pitch_depower_campaign_v3.jl` | .jl | Jun 3 | human | v3; 14KB | superseded |
| `scripts/pitch_depower_campaign_v4.jl` | .jl | Jun 16 | human | v4; 16KB | superseded |
| `scripts/pitch_depower_campaign_v5_safe.jl` | .jl | Jun 16 | human | v5 safe; 19KB | current |
| `scripts/generate_d4.py` | .py | Jun 16 | agent | Generates d4 optimization landscape from campaign CSV | current |
| `scripts/generate_rich_figures.py` | .py | Jun 3 | agent | Rich figure generation | current |
| `scripts/generate_v2_report.py` | .py | Jun 3 | agent | 1941 lines | current |
| `scripts/generate_v3_report.py` | .py | Jun 3 | agent | | current |
| `scripts/generate_v4_figures.py` | .py | Jun 3 | agent | | current |
| `scripts/generate_v5_report.py` | .py | Jun 3 | agent | | current |

## docs/ — Documentation (excluding diagrams/case-notes)

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/awes-forum-v62-report.md` | .md | Jun 16 | agent | Rewritten forum report (corrected physics); ~1100 words | current |
| `docs/awes-forum-diagrams/awes-forum-v62-report.md` | .md | Jun 16 | agent | Copy of above in diagrams folder | duplicate |
| `docs/TRPT_AWE_Forum_Report_v4.md` | .md | Jun 3 | agent | Markdown version of v4 .docx report | superseded |
| `docs/TRPT_Optimisation_Monograph.md` | .md | Jun 3 | agent | Markdown version of monograph | current |
| `docs/case-notes/2026-06-16-tan-vs-sin-polygon-resolution.md` | .md | Jun 16 | agent | Tan→sin discovery and fix | current |
| `docs/case-notes/2026-06-16-solidity-exponent-sensitivity.md` | .md | Jun 16 | agent | Solidity exponent uncertainty | current |
| `docs/audit-literature-crosscheck.md` | .md | Jun 8 | agent | 13 KTD.jl + 11 Coaxial gaps identified | current |
| `docs/v6-campaign-analysis-20260615.md` | .md | Jun 15 | agent | V6 campaign analysis | current |
| `docs/adr/0001-inertia-relief.md` | .md | Jun 3 | human | Architecture decision record | current |
| `docs/agents/domain.md` | .md | Jun 3 | human | Domain knowledge for agents | current |
| `docs/agents/issue-tracker.md` | .md | Jun 3 | human | Issue tracking conventions | current |
| `docs/agents/triage-labels.md` | .md | Jun 3 | human | Triage label definitions | current |
| `docs/dashboard-redesign-dispatch.md` | .md | Jun 3 | agent | Dashboard redesign plan | current |
| `docs/dashboard-redesign-mockup.html` | .html | Jun 3 | agent | Dashboard mockup | current |
| `docs/dashboard-redesign-options.html` | .html | Jun 3 | agent | Dashboard options | current |
| `docs/dashboard-spec.md` | .md | Jun 3 | agent | Dashboard specification | current |
| `docs/paper-expansion-rotors-plan.md` | .md | Jun 3 | agent | Expansion rotors paper plan | current |
| `docs/pitch_depower_campaign_v1_review.md` | .md | Jun 3 | agent | Campaign review | current |
| `docs/pitch_depower_v2_prd.md` | .md | Jun 3 | agent | PRD | current |
| `docs/phase_j_results.md` | .md | Jun 3 | agent | Phase J results | current |
| `docs/phase_k_analysis.md` | .md | Jun 3 | agent | Phase K analysis | current |
| `docs/phase_m_v5_analysis.md` | .md | Jun 3 | agent | Phase M v5 analysis | current |
| `docs/phase_n_pitch_depower_diagnostics.md` | .md | Jun 3 | agent | Phase N diagnostics | current |
| `docs/phase_o_v4_pitch_depower_report.md` | .md | Jun 3 | agent | Phase O report | current |
| `docs/plans/` (14 files) | .md | Mar–Jun | mixed | Historical development plans; all superceded by PLAN.md | stale |
| `docs/validation/2026-04-19-report-validation.md` | .md | Apr 19 | agent | Report validation | current |
| `docs/make.jl` | .jl | Jun 3 | human | Documentation build script | current |
| `docs/Project.toml` | .toml | Jun 3 | derived | Docs environment | current |
| `docs/src/api.md` | .md | Jun 3 | human | API documentation | current |
| `docs/src/index.md` | .md | Jun 3 | human | Docs index | current |

## Added Since June 16 (V10 Era + Video + Campaigns)

### src/ — New Julia Sources

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `src/objective_v10.jl` | .jl | Jun 21 | human | V10 objective: rotor masks, tension gate, k_mppt λ², 14-DoF; 466 lines | current |
| `src/headless_verify.jl` | .jl | Jun 21 | human | Headless structural verification + k_mppt dynamic scan gate; 205 lines | current |

### Root — Launch Scripts

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `launch_v10.sh` | .sh | Jun 21 | human | V10 baseline launch | current |
| `launch_v10_50kw.sh` | .sh | Jun 21 | human | V10 50kW campaign launch | current |
| `launch_v10_50kw_v2.sh` | .sh | Jun 21 | human | V10 v2 campaign (clamp removed + tension gate) | current |
| `launch_v10_tight.sh` | .sh | Jun 21 | human | V10 Tight campaign (4-rotor, reduced bounds) | current |
| `launch_v10_medium.sh` | .sh | Jun 21 | human | V10 medium configuration | current |
| `launch_v10_quick_0bank.sh` | .sh | Jun 21 | human | V10 quick test with zero bank | current |

### scripts/ — Campaign & Analysis

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `scripts/run_v10_campaign.jl` | .jl | Jun 21 | human | V10 DE campaign runner; 60 islands, 14 DoF, validation gates | current |
| `scripts/interactive_dashboard.jl` | .jl | Jun 21 | human | GLMakie dashboard, k_mppt slider, design overlay | current |
| `scripts/export_v10_atlas_data.jl` | .jl | Jun 21 | agent | Exports non-dimensional π-group data from campaign traces | current |
| `scripts/export_v10_landscape_data.jl` | .jl | Jun 21 | agent | Exports PCA landscape projections | current |
| `scripts/export_v10_tight.jl` | .jl | Jun 22 | agent | V10 Tight data export | current |
| `scripts/render_v10_landscape.py` | .py | Jun 21 | agent | PCA landscape render | current |
| `scripts/render_v10_atlas.py` | .py | Jun 21 | agent | Non-dimensional atlas render (3×3 panel) | current |
| `scripts/render_v10_pairs.py` | .py | Jun 21 | agent | Parameter pairs plot | current |
| `scripts/render_v10_panels.py` | .py | Jun 21 | agent | Individual panel explainer cards | current |
| `scripts/render_v10_3d.py` | .py | Jun 21 | agent | 3D PCA landscape | current |
| `scripts/render_v10_tight_all.py` | .py | Jun 22 | agent | V10 Tight full diagram set | current |
| `scripts/render_v10_tight_landscape.py` | .py | Jun 22 | agent | V10 Tight landscape | current |
| `scripts/render_v10_tight_panels.py` | .py | Jun 22 | agent | V10 Tight panel diagrams | current |
| `scripts/render_v10_tight_param_panels.py` | .py | Jun 22 | agent | V10 Tight parameter panels | current |
| `scripts/plot_v10_landscape.jl` | .jl | Jun 21 | agent | Julia landscape plotter | current |
| `scripts/plot_v10_trajectories.jl` | .jl | Jun 21 | agent | Julia trajectory plotter | current |
| `scripts/analyze_kmppt.jl` | .jl | Jun 21 | agent | k_mppt sensitivity analysis | current |
| `scripts/calibrate_kmppt_v62.jl` | .jl | Jun 21 | agent | k_mppt calibration for v6.2 | current |
| `scripts/sensitivity_sweeps.jl` | .jl | Jun 21 | agent | Parameter sensitivity sweeps | current |
| `scripts/trace_balance.jl` | .jl | Jun 21 | agent | Balance tracing for debugging | current |
| `scripts/trace_tensions.jl` | .jl | Jun 21 | agent | Tension tracing for debugging | current |
| `scripts/validate_v62_dynamic.jl` | .jl | Jun 21 | agent | Dynamic validation of v6.2 designs | current |
| `scripts/verify_beam_mass_formula.jl` | .jl | Jun 21 | agent | Beam mass formula verification | current |

### docs/awes-forum-diagrams/ — V10 Diagram Specifications

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/awes-forum-diagrams/v10-nondimensional-atlas.md` | .md | Jun 21 | agent | Non-dimensional atlas narrative | current |
| `docs/awes-forum-diagrams/v10-traced-paths.md` | .md | Jun 21 | agent | Traced convergence paths narrative | current |
| `docs/awes-forum-diagrams/v10-tight-diagrams.md` | .md | Jun 22 | agent | V10 Tight diagram set spec | current |
| `docs/awes-forum-diagrams/v10-tight-nondim-explainer.md` | .md | Jun 22 | agent | V10 Tight non-dimensional explainer | current |
| `docs/awes-forum-diagrams/SPEC-v10-convergence.md` | .md | Jun 21 | agent | V10 convergence diagram spec | current |
| `docs/awes-forum-diagrams/V7_CAMPAIGN_PLAN.md` | .md | Jun 19 | agent | V7 campaign plan | current |

### docs/awes-forum-diagrams/video-interpretation/ — Video Production

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/awes-forum-diagrams/video-interpretation/SCRIPT_NARRATIVE.md` | .md | Jun 22 | agent | 4-min explainer video transcript (V10 Tight era) | current |
| `docs/awes-forum-diagrams/video-interpretation/ANIMATION_SPEC.md` | .md | Jun 22 | agent | Animation specifications and Manim code | current |
| `docs/awes-forum-diagrams/video-interpretation/README.md` | .md | Jun 22 | agent | Video project overview and tooling | current |

### .video/ — Video Production Assets

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `.video/PLAN.md` | .md | Jun 22 | agent | Video production plan (updated for V10 Tight) | current |
| `.video/script/voiceover.md` | .md | Jun 22 | agent | SUPERSEDED — see video-interpretation/SCRIPT_NARRATIVE.md | superseded |
| `.video/script/timing.csv` | .csv | Jun 22 | agent | Scene timing spreadsheet | current |

### docs/reports/ — New Reports

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/reports/v10-tight-analysis.md` | .md | Jun 22 | agent | V10 Tight campaign analysis (49.2 kg) | current |

### docs/plans/ — New Plans

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `docs/plans/2026-06-19-v9-dynamic-equilibrium-objective.md` | .md | Jun 19 | agent | V9 dynamic equilibrium plan | current |
| `docs/plans/2026-06-20-v10-full-dynamic-constraints.md` | .md | Jun 20 | agent | V10 constraint design plan | current |
| `docs/plans/2026-06-20-v11-tapered-tethers.md` | .md | Jun 20 | agent | V11 tapered tether plan | current |
| `docs/plans/2026-06-21-dynamic-verification-gate.md` | .md | Jun 21 | agent | Dynamic verification gate plan | current |
| `docs/plans/2026-06-21-rotor-position-clamp-tension-gate.md` | .md | Jun 21 | agent | Rotor clamp + tension gate plan | current |

### references/ — New References

| Path | Type | Date | Authority | Limitations | Status |
|------|------|------|-----------|-------------|--------|
| `references/rotor-sizing-problem.md` | .md | Jun 21 | agent | Rotor sizing physics reference | current |
| `references/v9_0-campaign-analysis.md` | .md | Jun 20 | agent | V9 campaign analysis | current |
| `references/v9_0-campaign-10kw-analysis.md` | .md | Jun 20 | agent | V9 10kW analysis | current |
| `references/v9_0-dashboard-verification.md` | .md | Jun 20 | agent | V9 dashboard verification | current |

### External Pipeline (not in repo, but essential context)

| Resource | Path | Description |
|----------|------|-------------|
| Agents-K1 framework | `/home/rod/Documents/kites/agents-k1/` | GraphAnything + K1 4B extraction model |
| AWES knowledge graph | `/home/rod/Documents/kites/awes_graph/` | 540 papers, 7,401 nodes, 6,903 edges |
| AWES paper corpus | `/home/rod/Documents/kites/investigation/` | 540 PDFs |
| KTD paper pipeline | `/home/rod/Documents/kites/ktd_paper_graph/` | Reverse ingestion → paper draft |
| K1 model | `/home/rod/Documents/kites/models/agents-k1/` | 4B parameter extraction model (GPU served) |
