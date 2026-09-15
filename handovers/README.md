# Agent Handover Directory

Collaborative workspace for agent-to-agent handoff documents. Each file captures the state of a session so a fresh agent can continue the work.

## Conventions

- **Naming:** `handover-YYYY-MM-DD-description.md`
- **Location:** All handover documents live here. This directory consolidated historical copies from `.hermes/` and `docs/handover/`.
- **Format:** See the latest handover for the current template convention.

## Current Handovers

| File | Date | Topic |
|------|------|-------|
| `handover-2026-09-14-verified-state-reseed-boundary-and-priority-correction.md` | Sep 14 | **CURRENT**: the fast suite now exits **0** (2108 pass / 0 fail / 0 errored / 3 broken). That exit code blocked the commit. We verified it by running without `script`, which **masks exit codes**. We found and fixed two real defects. The torsional limit was **silently clamped**. `asin(clamp(...))` placed multi-turn wind-ups (4×90° and 12×90°) in the *placement*, not by relaxation. A **hardcoded borrowed speed** (`12.983466`, the ω of the seed) caused a defect. The preload test then compared a settled state against a foreign design. New guard `test/test_trpt_realisability.jl` (26 assertions) reproduces the Sep-13 table. It shows binding seg 4, sin Δα 0.983, 79.4°, τ 329.9/238.2. V3 **restated** to the ruling from Rod. The lift line (459.0 N) and cyan line (452.3 N) are mandatory-taut. The bridle cone and TRPT may slack. The back-line is **not** asserted (altitude limiter). **Correction: the Sep-13 §2 "2 reds" did not exist.** Both preload tests pass. Line 107 is the 6-line/1-rotor block (not 4/3), and 114.0 reproduces nowhere. So **§11 step 3 was void**. Acceptance stays at **4 of 8 failing**. The assertions match the pre-change baseline (measured by reverting the edits from this session). A viable re-seed candidate was **found, measured, then reverted**: `[2.6, 0.5751, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]`. Evaluator ok, 5.07 kW, FoS 3.59, twist demand 0.789. It gave 9 of 10 genes mid-range, and bank angle was immaterial (0/11/22° all viable). We reverted it because it **disconnects the lift chain**. The bridle reads 525.7 → 0.000 N. The cyan line sits at 4.7675 m against its 5.0 m rest length. The sky residual is +505.8 N. The design constants are **not** radius-dependent (3.9898 vs 3.9897 m). That corrects an earlier claim. ~~**CORRECTED 2026-09-14:** the offset IS radius-dependent — `bearing_offset = r_top / tan(31°)` (3.994 m at 2.4 m, 4.327 m at 2.6 m). The probe settled from a builder that had already placed the bearing at the hardcoded 3.99 m, so it read 3.99 for every radius.~~ **Priority correction: this session worked record item 5 (the seed). Items 1 (static solver) and 2 (load split) remain undone.** We stopped the seed hunt. Untested hypothesis for the chain drop-out: the 0.99·L hard on/off switch in the lift line. ~~**CORRECTED 2026-09-14:** the switch never opens — `sys.kite_pos` is held at exactly the line length every step — so it was never the cause; the cause was the back-line rest length (`6.0 → 3.99` in `ring_forces.jl`), and the "measurement" in §6.4 read the hub ring, not the kite.~~ Also raised: `BEARING_OFFSET_DESIGN`/`CYAN_L0_DESIGN` appear at **15 sites in 5 files** plus a bare literal |
| `handover-2026-09-13-lift-chain-and-realisability.md` | Sep 13 | **§2 and §11 step 3 CORRECTED 2026-09-14** (see the entry above). The lift chain was **disconnected by a length error, not a force error**. The bridles were cut to 6.4622 m (for a 6.0 m bearing offset). That is 1.80 m too long against a 4.658 m gap. The lift line was taut and its gate open, so re-aiming the lift could never have fixed it. We fixed the tree (design point **3.99 m**, section-balance preload, bridles cut for preload, chain placed at design geometry). The chain now engages. The bearing sits 3.990 m above the rotor. The bridles read 68.6 to 106.7 N, and the cone is 31.0°/59.0°. The plan §2.4.1 "unrealisable preload" blocker was **an artefact** of a taut backline. Slack (its real role) gives T_top 1344.7 N against the 1274.5 N floor. Realisability is **tight**: binding segment 4 at Δα = 79.4°, 10.6° from the cliff. The `capture_extended.segment_torque` tool was **wrong by up to 2.6×** (uniform L_seg, mean radius²), now **fixed**. It also shows torque **increases downward** (238 → 330 → 378 N·m by rotor injection at rings 7/8/9). That closes the "segments 7 to 8 under-carry" open item. The ~~**Tree DIRTY and RED** (2 fails in `test_settle_preload_consistency.jl`)~~ note is **WRONG**, corrected 2026-09-14. Both preload tests pass on the tree as found (2086 pass / 0 fail / 2 errored / 3 broken). The 2 errors are "Unexpected Pass". The next task is Phase 1b, the static equilibrium solve. The ring plane is not a physical DOF. **DECIDED 2026-09-13: vertex-node rings, per-ring (§6a), which is the next implementation task** |
| `handover-2026-09-12-settle-rebuild-bow-and-static-solver.md` | Sep 12 | **SUPERSEDED** by Sep 13. Its §5 static-solver harness and §6 harness-bug catalogue remain valid. The **~1.5 m "bow"** is a rigid-tilt estimate, not a solved catenary. Sep 13 §4 refutes its "unrealisable preload" conclusion. Settle rebuild: headline **the shaft BOWS ~4.7° / ~1.5 m**. That bow comes from the 124 N gravity component perpendicular to the 30° axis. We confirmed it against the real machine, which reframes the settle as "find where a hanging column sits". The lift chain is **disconnected**. The bridles read 0.0000 N. The rest length is 6.462198 m against the 4.658 m the geometry wants. A resting state **does exist**. The **backline is the altitude limiter** taking the 143 N lift surplus. The **axial balance closes** (+66.6 → −0.32 N), and the lateral is the slow mode. The `test/test_settle_validity.jl` guard landed (2 pass / 5 `@test_broken`). Static-solver harness fixed and verified (QR + per-DOF scaling, never form `J'J`), but the solve **does not converge**. Diagnosis: the bow is a large geometric **line reorientation**, not a translation. A global sideways ring motion is stiff (3.5e5 N/m). 29 commits ahead, unpushed |
| `handover-2026-09-12-session-state-and-preload-rootcause.md` | Sep 12 | **SUPERSEDED** by the above, except §2 (canonical Julia invocation). Session-state triage: all WIP committed. We verified the dead-knob root cause from Claude |
| `handover-2026-09-11-settle-ode-coherence.md` | Sep 11 | settle↔ODE coherence fixed (matched-place twist+axial solve). We corrected the wind-up root cause: axial preload, not frame softness. Acceptance 5/8: the corrected state does **not** stall. It exposes a **real FoS shortfall** (seed 1.31 to 2.31 vs a 2.5 floor). Do not re-baseline. **§1/§2 superseded 2026-09-12**. §3 to §9 still valid |
| `handover-2026-09-10-r7-complete.md` | Sep 10 | R7 to R10 + R11 deliverables complete. The (then-misdiagnosed) settle gap blocked the short campaign |
| `handover-2026-09-07-closed-form-beam-sizing.md` | Sep 07 | "shed structure" plan inverted (true FoS ≈ 1.2, under-strength). We proposed a closed-form beam-sizing architecture (REV 2). Orientation/off-by-one fixes landed, and we added `solve_ring_Do`. The load case is the generator load step. We deferred feather |
| `handover-2026-08-21-daisy-anchored-5kw-campaign.md` | Aug 21 | Gate aligned to the Daisy anchor. Gate 1c blade mass fixed. Smoke passed at 18.8 |
| `handover-2026-08-20-model-scaling-daisy-anchor.md` | Aug 20 | 50 kW blade-mass/radius/annulus contamination fixed. Daisy anchor saved. Mass-minimisation objective (FoS 2.5). 5 kW re-run config assembled. Daisy seed stall = the open task |
| `handover-2026-08-12-5kw-baseline.md` | Aug 12 | 5kW baseline: ODE viability confirmed (2.7 kW), static/ramp evaluator false-negatives diagnosed, torsional FoS power-dependence, V12 cold-start campaign config |
| `handover-2026-08-12-zeta-damping-fix.md` | Aug 12 | ζ=1.5 damping + tension rectifier = reverse torque. ζ promoted to SystemParams (0.05) |
| `handover-2026-08-11-bem-ode-gap.md` | Aug 11 | BEM/ODE gap investigation. SUPERSEDED by the ζ fix (see above) |
| `handover-2026-08-11-dt-stability-and-parallelism.md` | Aug 11 | dt stability. Orbital damping hypothesis tested and exonerated 2026-08-12 |
| `handover-2026-08-11-calibration-session.md` | Aug 11 | Calibration session notes |
| `handover-2026-08-09-evaluator-consolidation.md` | Aug 9 | Evaluator consolidation (V12 windowed family) |
| `findings-2026-08-07-phase-a-v2-de-audit.md` | Aug 7 | Phase A v2 DE audit findings |
| `handover-2026-08-07-audit-fixes.md` | Aug 7 | Audit fixes |
| `handover-2026-08-06-lift-margin-expansion-drag.md` | Aug 6 | Lift margin + expansion drag |
| `handover-2026-08-05-stationarity-audit.md` | Aug 5 | Stationarity audit |
| `handover-2026-08-04-session.md` | Aug 4 | Session record |
| `handover-2026-07-25-phase-a-instrument-audit.md` | Jul 25 | Phase A instrument audit |
| `handover-2026-07-25-pre-relaunch-blockers.md` | Jul 25 | Pre-relaunch blockers |
| `handover-2026-07-23-feasibility-first-desktop.md` | Jul 23 | Feasibility-first campaign (desktop) |
| `handover-2026-07-23-feasibility-first-local-manager.md` | Jul 23 | Feasibility-first campaign (local manager) |
| `handover-2026-07-23-feasibility-first-stornoway.md` | Jul 23 | Feasibility-first campaign (Stornoway) |
| `handover-2026-07-14-audit.md` | Jul 14 | Audit |
| `handover-2026-07-16-figure-data-fixes.md` | Jul 16 | Outreach figure review: data-side fixes |
| `gate2-restart-2026-07-07.md` | Jul 7 | Gate 2 restart |
| `handover-2026-07-06-prd0006.md` | Jul 6 | PRD 0006 |
| `handover-2026-07-01-dashboard-v2-refinements.md` | Jul 1 | Dashboard v2 cockpit refinements |
| `handover-2026-06-30-dashboard.md` | Jun 30 | Dashboard v2 design intent |
| `handover-2026-06-27-soft-ramp.md` | Jun 27 | Soft ramp controller |
| `handover-2026-06-23-knowledge-pipeline.md` | Jun 23 | Knowledge pipeline |
| `handover-2026-06-17.md` | Jun 17 | Session record |
| `handover-2026-06-16.md` | Jun 16 | V6.2 corrected physics campaign |
| `handover-2026-06-14-pitch-depower-v3.md` | Jun 14 | Pitch depower v3 (superseded) |
| `handover-2026-06-14.md` | Jun 14 | Expansion rotor refactor |
| `handover-2026-05-28-pitch-depower-session.md` | May 28 | Pitch depower diagnostics |
| `handover-2026-05-28-pitch-depower.md` | May 28 | Pitch depower |
| `handover-2026-05-26.md` | May 26 | Session record |
| `handover-2026-05-25-pitch-depower-campaign.md` | May 25 | Pitch depower campaign |
| `handover-2026-05-25.md` | May 25 | Session record |
| `handover-2026-05-18.md` | May 18 | Session record |
| `handover-2026-05-12.md` | May 12 | Session record |
| `handover-2026-05-11.md` | May 11 | Session record |
| `handover-2026-05-10.md` | May 10 | Session record |
| `handover-2026-05-09.md` | May 9 | Session record |
| `HANDOFF_pitch_depower_campaign.md` | Jun 16 | Pitch depower campaign |
| `HANDOFF_pitch_depower_campaign_v3.md` | Jun 16 | v3 (superseded) |

## Usage

When ending a session, write a handover document here. Reference existing artifacts (PRDs, plans, ADRs, issues, commits) by path rather than duplicating content. Include suggested skills for the next agent to load.
