# Agent Handover Directory

Collaborative workspace for agent-to-agent handoff documents. Each file captures the state of a session so a fresh agent can continue the work.

## Conventions

- **Naming:** `handover-YYYY-MM-DD-description.md`
- **Location:** All handover documents live here. Historical copies in `.hermes/` and `docs/handover/` have been consolidated.
- **Format:** See the latest handover for the current template convention.

## Current Handovers

| File | Date | Topic |
|------|------|-------|
| `handover-2026-08-20-model-scaling-daisy-anchor.md` | Aug 20 | **CURRENT** — 50 kW blade-mass/radius/annulus contamination fixed; Daisy anchor saved; mass-minimisation objective (FoS 2.5); 5 kW re-run config assembled; Daisy seed stall = the open task |
| `handover-2026-08-12-5kw-baseline.md` | Aug 12 | 5kW baseline: ODE viability confirmed (2.7 kW), static/ramp evaluator false-negatives diagnosed, torsional FoS power-dependence, V12 cold-start campaign config |
| `handover-2026-08-12-zeta-damping-fix.md` | Aug 12 | ζ=1.5 damping + tension rectifier = reverse torque; ζ promoted to SystemParams (0.05) |
| `handover-2026-08-11-bem-ode-gap.md` | Aug 11 | BEM/ODE gap investigation — SUPERSEDED by ζ fix (see above) |
| `handover-2026-08-11-dt-stability-and-parallelism.md` | Aug 11 | dt stability; orbital damping hypothesis tested & exonerated 2026-08-12 |
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
