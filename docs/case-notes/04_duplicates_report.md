# Duplicates Report — KiteTurbineDynamics.jl

**Generated:** 2026-06-16
**Status:** Open — duplicates identified, NOT resolved

This document identifies suspected duplicate files and version families in the repository. The policy is: **do not silently delete or merge duplicates.** Doing so risks combining old and new assumptions to produce incorrect conclusions. All resolution decisions belong to the project owner.

---

## D1: AWES Forum Report — 6 Versions Across 2 Formats ✅ RESOLVED

**Resolution (2026-06-16):**
- v1–v3 .docx archived to `archive/reports/`
- v4 .docx moved to `docs/reports/`
- Corrected .md rewrite is canonical at `docs/awes-forum-diagrams/awes-forum-v62-report.md`
- Duplicate `docs/awes-forum-v62-report.md` deleted

**Files:**
- `TRPT_AWE_Forum_Report.docx` (v1, 443KB)
- `TRPT_AWE_Forum_Report_v2.docx` (v2, 1.3MB)
- `TRPT_AWE_Forum_Report_v3.docx` (v3, 2.1MB)
- `TRPT_AWE_Forum_Report_v4.docx` (v4, 493KB)
- `docs/TRPT_AWE_Forum_Report_v4.md` (markdown of v4)
- `docs/awes-forum-diagrams/awes-forum-v62-report.md` (corrected rewrite, this session)
- `docs/awes-forum-v62-report.md` (possible duplicate/copy)

**Version family:** v1 → v2 → v3 → v4 → corrected rewrite (v6.2). The v1–v4 .docx files contain the old tan-formula results (58 kg, n=3). The corrected .md file contains the sin-formula results (74 kg, n=12).

**Risk of silent deduplication:** If v1–v4 .docx files are deleted, the provenance of the 58 kg claim is lost. If the corrected .md file is accidentally replaced with an older version, the corrected physics would be lost.

**Recommendation:**
1. Keep all .docx versions for provenance. Move to `archive/reports/`.
2. Choose ONE canonical location for the current report: `docs/awes-forum-diagrams/awes-forum-v62-report.md`.
3. Delete `docs/awes-forum-v62-report.md` (the copy at the wrong path).
4. Add a header to old .docx files' extracted markdown noting they are superseded.

---

## D2: V6 Campaign Results — 9 Directories for 2 Power Levels

**Files:**
```
scripts/results/v6_campaign/                    — unknown vintage
scripts/results/v6_campaign_10kw/               — V6 (pre-widened bounds)
scripts/results/v6_campaign_10kw_old_20260614/   — archived old run
scripts/results/v6_campaign_10kw_stale/          — explicitly stale
scripts/results/v6_campaign_50kw/                — V6 (pre-widened bounds)
scripts/results/v6_campaign_50kw_old/            — archived old run
scripts/results/v6_campaign_50kw_stale/          — explicitly stale
scripts/results/v6_campaign_50kw_v2_stale/       — another stale variant
scripts/results/v6_2_campaign_10kw/              — V6.2 (widened bounds, current?)
scripts/results/v6_2_campaign_50kw/              — V6.2 (corrected physics, CURRENT)
```

**Version family:** Campaign versions evolved: V6 (original bounds) → V6 (widened bounds) → V6.2 (corrected physics). The `_old` and `_stale` directories appear to be manual archives of runs that produced different results.

**Risk of silent deduplication:** The `v6_campaign_50kw` directory contains the 179 kg result (pre-widened bounds). If merged with `v6_2_campaign_50kw` (74 kg), the results would contradict. The directory naming partially encodes the version but is not systematic.

**Recommendation:**
1. Keep `v6_2_campaign_50kw/` as the ONLY current directory.
2. Move all others to `scripts/results/_archive/` with a README explaining what each contains.
3. Standardize naming: `{model_version}_campaign_{power}kw/` (e.g., `v6_2_campaign_50kw`).

---

## D3: Handoff/Handover Documents — 12 Files Across 3 Locations ✅ RESOLVED

**Resolution (2026-06-16):** Consolidated to single canonical location `handovers/` with README. Root copies deleted. `.hermes/` copies remain but `handovers/` is canonical.

**Files:**
- `.hermes/handover-2026-05-09.md`
- `.hermes/handover-2026-05-11.md`
- `.hermes/handover-2026-05-12.md`
- `.hermes/handover-2026-06-14.md`
- `.hermes/handover-2026-06-16.md` (this session)
- `handover-2026-05-12.md` (root — possible duplicate of .hermes version)
- `handover-2026-05-18.md`
- `handover-2026-05-25.md`
- `handover-2026-05-26.md`
- `HANDOFF_pitch_depower_campaign.md`
- `HANDOFF_pitch_depower_campaign_v3.md`
- `docs/handover/2026-05-28-pitch-depower-session.md`

**Version family:** Multiple naming conventions (HANDOFF vs handover), multiple locations (.hermes/, root, docs/handover/), overlapping dates. The May 12 handover exists in TWO locations — are they the same file?

**Risk of silent deduplication:** Merging handoff documents from different dates could combine instructions from different model versions. The May 12 duplicate could diverge if only one copy is updated.

**Recommendation:**
1. Consolidate to ONE location: `.hermes/` (agent-native, already used).
2. Compare `handover-2026-05-12.md` with `.hermes/handover-2026-05-12.md` — if identical, delete the root copy.
3. Move `docs/handover/` content to `.hermes/`.
4. Standardize naming: `handover-YYYY-MM-DD-description.md`.

---

## D4: Pitch Depower Campaign Scripts — 4 Versions

**Files:**
- `scripts/pitch_depower_campaign.jl` (original)
- `scripts/pitch_depower_campaign_v3.jl`
- `scripts/pitch_depower_campaign_v4.jl`
- `scripts/pitch_depower_campaign_v5_safe.jl` (current)
- `scripts/pitch_depower_analysis.py` (original)
- `scripts/pitch_depower_analysis_v4.py`
- `scripts/pitch_depower_analysis_v5_safe.py` (current)
- `run_pitch_depower_overnight.sh`
- `run_pitch_depower_v4.sh`
- `run_pitch_depower_v5_safe.sh` (current)

**Version family:** Campaigns evolved through v1 → v3 → v4 → v5_safe. The "safe" variant appears to be the current production version. Analysis scripts track the same versions.

**Risk of silent deduplication:** The v3 and v4 scripts may have different control logic or parameter bounds. Running an old script against the current model could produce misleading results.

**Recommendation:**
1. Keep v5_safe as current. Move v3 and v4 to `scripts/_archive/`.
2. Keep the original (v1) as reference for the first implementation.
3. Standardize: the current script should NOT have a version suffix — rename `pitch_depower_campaign_v5_safe.jl` to `pitch_depower_campaign.jl` and archive the old one.

---

## D5: Orphan Test Files — 16 Files at Repo Root ✅ RESOLVED

**Resolution (2026-06-16):** Moved to `scratch/`. Not deleted — variant pairs preserved.

**Files:**
- `test_analytic_settle.jl`
- `test_circle_intersect.jl`
- `test_forces.jl`
- `test_furl_noboost.jl`
- `test_furl_state.jl` / `test_furl_state_new.jl` (variant pair)
- `test_furl_z.jl`
- `test_lift_force.jl` / `test_lift_force2.jl` (variant pair)
- `test_scenarios.jl`
- `test_settle_param.jl` / `test_settle_real.jl` (variant pair)
- `test_twist_contract.jl`
- `test_twist_shift.jl` / `test_twist_shift2.jl` / `test_twist_shift3.jl` (three variants)

**Version family:** Multiple variant pairs (state vs state_new, shift vs shift2 vs shift3, lift_force vs lift_force2) suggest iterative debugging. These are ad-hoc scripts, not formal tests. None are wired into `test/runtests.jl`.

**Risk of silent deduplication:** The variant pairs may test different model versions. `test_furl_state.jl` and `test_furl_state_new.jl` may exercise different physics. Merging them would lose the distinction.

**Recommendation:**
1. Move all orphan tests to `scratch/` (they are debugging scripts, not formal tests).
2. For variant pairs, keep only the newest version; delete older variants after confirming the newer one subsumes them.
3. If any contain valuable test logic, extract it into proper `test/` files wired into `runtests.jl`.

---

## D6: Campaign Log Files — 20+ Files at Root

**Files:** 21 `.log` files at repo root including:
- `v6_campaign*.log` (11 files, multiple dates and power levels)
- `campaign_v*.log` (4 files)
- `analysis_v*.log` (3 files)
- `depower_v3.log`, `payout_tension_v3_results.log`, `run_all_sims_v4.log`

**Version family:** These are stdout/stderr captures from campaign runs. The filenames encode date, power level, and version but inconsistently.

**Risk of silent deduplication:** Low — these are output logs, not source. But deleting them loses the ability to audit what a particular campaign run actually produced.

**Recommendation:**
1. Move all log files to `scripts/results/_logs/` or co-locate with their campaign directories.
2. Delete logs from runs that are explicitly superseded (e.g., `v6_campaign_50kw_v3_20260615_0921.log` when the v3 run is stale).

---

## D7: Report Generation Scripts — 4 Versions

**Files:**
- `scripts/generate_v2_report.py` (1941 lines)
- `scripts/generate_v3_report.py`
- `scripts/generate_v4_figures.py`
- `scripts/generate_v5_report.py`

**Version family:** Report generation evolved through v2→v5. Unclear which are still functional with the current model.

**Recommendation:** Move v2–v4 to `scripts/_archive/`. Keep v5 as current. Note that `generate_d4.py` (this session) is a separate concern and should remain alongside the current report generator.

---

## D8: TRPT Optimisation Results — 5 Version Directories

**Files:**
- `scripts/results/trpt_opt/` (original)
- `scripts/results/trpt_opt_v2/`
- `scripts/results/trpt_opt_v3/` (has 50kw subdirectories for each profile type)
- `scripts/results/trpt_opt_v4/`
- `scripts/results/trpt_opt_v5/`

**Version family:** TRPT optimization evolved through v1→v5. The v3 directory is the most granular with per-profile-type subdirectories.

**Recommendation:** Archive v1–v4. Keep v5 as current. The v6 campaigns have their own result directories and are not part of this family.

---

## D9: Pitch Depower Campaign Results — 4 Versions

**Files:**
- `scripts/results/pitch_depower_campaign/`
- `scripts/results/pitch_depower_campaign_v3/`
- `scripts/results/pitch_depower_campaign_v4/`
- `scripts/results/pitch_depower_campaign_v5_safe/`

**Version family:** Tracks the script versions (D4).

**Recommendation:** Archive v1–v4. Keep v5_safe as current.

---

## Summary Table

| ID | Family | Count | Status | Resolution |
|----|--------|-------|--------|------------|
| D1 | AWES Forum Report | 6 versions | ✅ Resolved | v1–v3 archived, .md is canonical |
| D2 | V6 Campaign Results | 9 dirs | Open | Archive stale, keep v6_2 only |
| D3 | Handoff Documents | 12 files | ✅ Resolved | Consolidated to `handovers/` |
| D4 | Pitch Depower Scripts | 10 files | Open | Archive old, rename v5→canonical |
| D5 | Orphan Tests | 16 files | ✅ Resolved | Moved to `scratch/` |
| D6 | Campaign Logs | 21 files | ✅ Resolved | Moved to `scripts/results/_logs/` |
| D7 | Report Scripts | 4 files | Open | Archive v2–v4 |
| D8 | TRPT Opt Results | 5 dirs | Open | Archive v1–v4 |
| D9 | Pitch Depower Results | 4 dirs | Open | Archive v1–v4 |
