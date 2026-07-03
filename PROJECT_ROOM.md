# Project Room — KiteTurbineDynamics.jl

**Created:** 2026-06-16 · **Updated:** 2026-07-03 (cleanup audit applied)

Systematic inventory of the repository. These files live at the repo root so any agent arriving fresh sees them immediately.

## Structure

| File | Purpose | Status |
|------|---------|--------|
| `01_source_inventory.md` | Every file logged with path, type, date, authority, limitations, and status | Updated 2026-06-22 |
| `02_conflict_log.md` | 8 conflicts surfaced for review | Created 2026-06-17 |
| `03_missing_context.md` | 10 gaps identified | Created 2026-06-17 |
| `04_duplicates_report.md` | Version families identified (4 resolved, 5 open) | Created 2026-06-22 |
| `PROJECT_ROOM.md` | This file | Updated 2026-07-03 |
| `CONTEXT.md` | Domain vocabulary, architecture, campaigns, source map | Rewritten 2026-07-03 |
| `DECISIONS.md` | 2,252-line running decision log | Current to 2026-07-01 |
| `CHANGELOG.md` | User-facing version changelog | Created 2026-07-03 |

## Campaign History

| Version | Power | Mass | n_lines | n_exp | Status | Date |
|---------|-------|------|---------|-------|--------|------|
| V6.0 | 50 kW | 184.84 kg | 8 | 1 | Octagon baseline | Jun 15 |
| V6.1 | 50 kW | 179.27 kg | 8 | 1 | +tension stiffening | Jun 15 |
| V6.2 | 50 kW | 74.17 kg | 12 | 1 | Corrected physics (tan→sin, cos²·⁶⁵) | Jun 17 |
| V6.3 | 50 kW | 52.61 kg ⚠ | 7 | 6 | Dynamically impossible (no drag model) | Jun 18 |
| V6.6 | 50 kW | none feasible | — | — | Parasitic drag, constraint too tight | Jun 20 |
| V6.7 | 50 kW | 54.91 kg | 9 | 14 | Relaxed drag, streamlined Cd | Jun 22 |
| V8.0 | 50 kW | 58.41 kg | 9 | 3 | Per-component physics | Jun 24 |
| V9.0 | 50 kW | 44.52 kg | 8 | 9 | Dynamic ω solve | Jun 27 |
| V10 | 50 kW | 76.75 kg | 14 | 4 | Unified rotors, 8 gates | Jun 29 |
| V10 Tight | 50 kW | 49.20 kg ⚠ | 12 | 4 | Dynamically dead (FoS=0.75) | Jun 29 |

## What's New Since June 23

### V10 Campaign Era (June 25–July 1)
- **V9 dynamic equilibrium** — 44.52 kg, 59/60 feasible, 3 bounds screaming
- **V10 unified rotors** — 76.75 kg, hub+3 rotors, 8 structural gates
- **V10 Tight** — 49.20 kg ⚠ dynamically dead (k≈550 hits P=50 kW but FoS=0.75)
- **Control-map verification** — 6 wind speeds, V10 over-bladed (3–4× rated), left-flank decision
- **Dashboard v2** — 6-row cockpit refactor with bar charts, rotor dials, tooltips
- **k_mppt bisection hunt** — pre-sweep + two-flank bracketing

### Key Physics Decisions (June 28–30)
- **Left-flank architecture:** Design for overspeed. Size blades for P_min ≤ P_rated.
- **Rigid NACA 4412 chosen** over soft kites (Ct/Cp 2.5 vs 8.3)
- **Collapse margin** adopted as primary monotonic safety indicator
- **Two-flank problem:** Right flank dynamically unreachable (torque, bounce, taper)

### Documentation (June 29–July 3)
- `CONTEXT.md` — fully rewritten for current state
- `CHANGELOG.md` — created from DECISIONS.md milestones
- `docs/reports/2026-06-30-control-map-findings.md` — full verification report
- `docs/plans/2026-06-30-control-first-campaign.md` — campaign architecture
- `docs/porto-2026/` — AWEC 2026 Porto materials

## Remaining Cleanup

- Rename `pitch_depower_campaign_v5_safe.jl` → `pitch_depower_campaign.jl`
- Archive old campaign result directories (D2, D8, D9)
- Archive old pitch depower scripts (D4)
- Archive old report generation scripts (D7)
- Add "SUPERSEDED" headers to old .md reports
- Resolve 8 conflicts (C1–C8) — surfaced in `02_conflict_log.md`
- Address 10 missing context items (M1–M10) — surfaced in `03_missing_context.md`

## Usage

These documents are living references. When files are added, renamed, superseded, or deleted, update the relevant inventory, close resolved conflicts, and mark gaps as filled.

Do NOT use these documents to make automated changes. All resolution decisions (archiving, deleting, merging) must be made by the project owner.
