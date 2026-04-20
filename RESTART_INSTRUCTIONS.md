# RESTART INSTRUCTIONS — 2026-04-20

## Current state: VALIDATION COMPLETE

Branch: `claude/peaceful-pascal`  
Last commit: `88e1aa4` — "Validate 8 TRPT reports against current simulator; regenerate 3 scriptable reports"

---

## What was done this session (2026-04-19)

All major validation work is complete. See full findings in:
`docs/validation/2026-04-19-report-validation.md`

**Regenerated and committed:**
- `TRPT_Dynamics_Report.docx` ✓ current
- `TRPT_FreeBeta_Report.docx` ✓ current
- `TRPT_KiteTurbine_Potential.docx` ✓ current (6 new charts in scripts/results/potential/charts/)
- All figures re-generated (make_diagrams, plot_hub_excursion, plot_mppt_sweep, plot_mppt_individual)

**Validated but NOT regenerated (hand-assembled, no generator script):**
- `TRPT_Lift_Device_Analysis.docx` — parameters correct; §4 simulation tables stale
- `TRPT_Twist_Analysis.docx` — **has a critical error: claims Cp≈0.43, code is 0.232**; all table data stale
- `TRPT_Ring_Scalability_Report.docx` — structural constants correct; T_line=2333N claim uncertain
- `TRPT_Stacked_Rotor_Analysis.docx` — correct, corrigendum applied
- `TRPT_Conical_Stack_Analysis.docx` — physics correct; /tmp source scripts lost

---

## Remaining work (if continuing)

### High priority

1. **Fix `TRPT_Twist_Analysis.docx` §2.1** — change "peak Cp ≈ 0.43" to "peak Cp ≈ 0.232"
   - Need to either re-generate the whole report (requires a new produce_twist_report.py script)
   - Or hand-edit just the docx (but that loses regenerability)
   - The table data in §3.1 is also stale vs twist_sweep_v2_summary.csv

2. **Clarify T_line=2333N in Ring Scalability report** — current MPPT sweep shows T_max≈820N,
   not 2333N. Need to check if this is a per-line vs total distinction or a genuine change.

### Lower priority

3. **TRPT_Lift_Device_Analysis.docx §4.3/4.4** — update hub excursion tables from long_summary.csv

4. **Recover/recreate conical stack analysis script** — the `/tmp/vortex_expansion_analysis.py`
   cited in TRPT_Conical_Stack_Analysis.docx is gone; recreate as `scripts/conical_stack_analysis.py`

5. **Merge/PR** — branch `claude/peaceful-pascal` is ready to merge when the above are addressed

---

## Key files to know

| File | Purpose |
|------|---------|
| `docs/validation/2026-04-19-report-validation.md` | Full cross-check findings |
| `scripts/results/mppt_twist_sweep/twist_sweep_v2_summary.csv` | Current settled MPPT data |
| `scripts/results/lift_kite/long_summary.csv` | Current hub excursion data |
| `src/aerodynamics.jl` | BEM table: peak Cp=0.232 at λ=4.0–4.1, CT(4.1)=0.548 |
| `src/parameters.jl` | Canonical params_10kw() — all reports should reference these |
