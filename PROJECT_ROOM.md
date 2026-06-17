# Project Room — KiteTurbineDynamics.jl

**Created:** 2026-06-16 · **Updated:** 2026-06-16 (post-cleanup, moved to root)

Systematic inventory of the repository. These files live at the repo root so any agent arriving fresh sees them immediately.

## Structure

| File | Purpose | Status |
|------|---------|--------|
| `01_source_inventory.md` | Every file logged with path, type, date, authority, limitations, and status | Updated post-cleanup |
| `02_conflict_log.md` | 8 conflicts surfaced for review | Current |
| `03_missing_context.md` | 10 gaps identified | Current |
| `04_duplicates_report.md` | 9 version families identified (4 resolved, 5 open) | Updated |
| `PROJECT_ROOM.md` | This file | Updated |

## Key Findings

- **6 versions** of the AWES Forum Report existed across .docx and .md formats (resolved)
- **9 directories** of V6 campaign results, only 1 is current
- **16 orphan test files** moved to `scratch/`
- **3 locations** for handoff documents consolidated to `handovers/`
- **8 conflicts** between files, including contradictory mass claims (58 vs 74 kg)
- **10 missing context items**, highest priority: AeroDyn input files and solidity exponent validation

## Cleanup Executed (2026-06-16)

| Action | Files |
|--------|-------|
| Orphan tests → `scratch/` | 16 files |
| Campaign logs → `scripts/results/_logs/` | 21 files |
| Removed duplicate report | `docs/awes-forum-v62-report.md` |
| Consolidated handovers → `handovers/` | 12 docs from 3 locations |
| Archived old reports → `archive/reports/` | Forum report v1–v3 .docx |
| Moved current reports → `docs/reports/` | 15 .docx + 3 .md |
| Removed root duplicates | 6 files |

## Remaining Cleanup (deferred to owner decision)

- Rename `pitch_depower_campaign_v5_safe.jl` → `pitch_depower_campaign.jl`
- Archive old campaign result directories (D2, D8, D9 in duplicates report)
- Archive old pitch depower scripts (D4)
- Archive old report generation scripts (D7)
- Add "SUPERSEDED" headers to old .md reports
- Resolve 8 conflicts (C1–C8 in conflict log)
- Address 10 missing context items (M1–M10)

## Usage

These documents are living references. When files are added, renamed, superseded,
or deleted, update the relevant inventory, close resolved conflicts, and mark
gaps as filled.

Do NOT use these documents to make automated changes. All resolution decisions
(archiving, deleting, merging) must be made by the project owner.
