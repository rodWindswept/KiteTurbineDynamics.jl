# RESTART INSTRUCTIONS — 2026-04-20

## Current state: ALL VALIDATION TASKS COMPLETE — READY TO MERGE

Branch: `claude/peaceful-pascal`  
Last commit: `91fca38` — "Resolve T_line discrepancy and update hub excursion tables"

---

## What was done (2026-04-19 → 2026-04-20)

All 8 TRPT reports have been fully validated and updated.
See complete findings in: `docs/validation/2026-04-19-report-validation.md`

### This session (2026-04-20) completed:

1. **TRPT_Twist_Analysis.docx** — regenerated via new `scripts/produce_twist_report.py`
   - Corrected critical error: Cp was claimed as 0.43, correct value is 0.232
   - Updated full 28-row settled-state table from twist_sweep_v2_summary.csv
   - Documents optimal gain finding: k×1.5 (k_mppt=16.5) is better than base k=11
   - Commit: `3fd0bba`

2. **TRPT_Ring_Scalability_Report.docx** — corrigendum added
   - T_line=2333N confirmed as pre-CT-correction artifact (commit fd02e39, 2026-03-26)
   - Current T_max ≈ 820 N per line at rated; DO_SCALE kept conservative
   - Ring mass budget of 9.6 kg was over-estimate; correct ~5.7 kg matches DRR 5.6 kg
   - `structural_safety.jl` comment updated with origin and known conservatism
   - Commit: `91fca38`

3. **TRPT_Lift_Device_Analysis.docx** — hub excursion tables updated
   - §4.3 (short steady run): SingleKite 2.33 mm, RotaryLifter 0.63 mm
   - §4.4 (60s turbulent I=15%): SingleKite 69mm, RotaryLifter 88mm (1.28× worse)
   - Key insight: RotaryLifter default params undersized (LM=0.28); mechanism confirmed
     to work in steady wind but turbulent performance requires proper sizing
   - 3 narrative paragraphs + Key Findings box + comparison table updated
   - Commit: `91fca38`

---

## Report status summary (2026-04-20)

| Report | Status |
|--------|--------|
| `TRPT_Dynamics_Report.docx` | ✅ Regenerated current |
| `TRPT_FreeBeta_Report.docx` | ✅ Regenerated current |
| `TRPT_KiteTurbine_Potential.docx` | ✅ Regenerated current |
| `TRPT_Lift_Device_Analysis.docx` | ✅ Tables updated (60s turbulent data) |
| `TRPT_Twist_Analysis.docx` | ✅ Regenerated via produce_twist_report.py (Cp fixed) |
| `TRPT_Ring_Scalability_Report.docx` | ✅ Corrigendum added (T_line clarified) |
| `TRPT_Stacked_Rotor_Analysis.docx` | ✅ Corrigendum applied (prev session) |
| `TRPT_Conical_Stack_Analysis.docx` | ✅ Physics verified; /tmp scripts noted as lost (low priority) |

---

## Phase B: New work to specify (before user goes AFK)

The user wants to queue and thoroughly specify the following before leaving for a week:

### B1: Diagram configuration issues
- Discuss issues with the current diagram generation (make_diagrams.py or other)
- [Needs user input to describe what the issues are]

### B2: TRPT sizing optimization routine
- Set up a systematic optimization routine for TRPT geometry
- e.g., optimize R, L, n_lines, β for maximum P/m or P at target cost
- [Needs design discussion with user]

### B3: Line tension investigation
- Investigate a specific line tension result (details TBD from user)
- May relate to the T_line findings in this session

---

## Key files

| File | Purpose |
|------|---------|
| `docs/validation/2026-04-19-report-validation.md` | Full cross-check findings |
| `scripts/produce_twist_report.py` | NEW — Twist Analysis generator |
| `scripts/results/mppt_twist_sweep/twist_sweep_v2_summary.csv` | Current settled MPPT data |
| `scripts/results/lift_kite/long_summary.csv` | Current hub excursion data (60s, I=15%) |
| `src/aerodynamics.jl` | BEM table: peak Cp=0.232 at λ=4.0–4.1 |
| `src/parameters.jl` | Canonical params_10kw() |
| `src/structural_safety.jl` | DO_SCALE note: conservative, calibrated pre-CT-correction |
