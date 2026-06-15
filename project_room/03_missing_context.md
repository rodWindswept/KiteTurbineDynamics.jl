# Missing Context List — KiteTurbineDynamics.jl

**Prepared:** 2026-05-24  
**Status:** Updated & Resolved  
**Purpose:** Every absent file, missing decision, unsupported number, and broken reference has been catalogued and audited.

---

## 1. Resolved Gaps and Missing Files

### 1.1 `CONTEXT.md` & `docs/adr/`
* **Status:** **FULLY RESOLVED**
* **Finding:** Both `CONTEXT.md` and the `docs/adr/` directory (with `0001-inertia-relief.md`) exist and are fully tracked on the `master` branch. The initial audit's claim that they were missing was incorrect.

### 1.2 `docs/agents/` Directory
* **Status:** **FULLY RESOLVED**
* **Finding:** The `docs/agents/` directory is fully present on `master` and contains the tracked markdown files `domain.md`, `issue-tracker.md`, and `triage-labels.md`. The initial audit's claim that they were missing was incorrect.

### 1.3 `scripts/calibrate_dlf.jl`
* **Status:** **FULLY RESOLVED**
* **Finding:** The Design Load Factor calibration script is fully present and tracked in `scripts/calibrate_dlf.jl` on the `master` branch.

### 1.4 Lost `/tmp/` Sizing and Wake Scripts
* **Status:** **FULLY RESOLVED**
* **Action taken:** Reconstructed the figure generation and wake expansion scripts:
  * `scripts/reconstruct_lift_kite_figures.py`: Programmatically regenerates `fig2_dynamic_pressure.png`, `fig3_force_balance.png`, `fig4_rotary_lifter.png`, and `fig5_tension_comparison.png` in `figures/`.
  * `scripts/vortex_expansion_analysis.py`: Calculates wind shear and TSR-matched rotor sizing, models Jensen wake expansion, exports `vortex_summary.json` to results, and plots the conical stack geometry to `figures/fig_conical_stack_geometry.png`.
* **Result:** Re-established complete reproducibility for `Lift_Kite_Sizing_Report.docx` and `TRPT_Conical_Stack_Analysis.docx`.

### 1.5 Stale Research Notes
* **Status:** **FULLY RESOLVED**
* **Action taken:** Overwrote the stale tables and optimal MPPT claims in `NOTES_MPPT_TWIST.md` and the TBD values in `NOTES_LIFT_KITE.md` with the authoritative, physics-verified v2 sweep and `long_summary.csv` results.

### 1.6 Report Discrepancies and Physics Errors
* **Status:** **FULLY RESOLVED**
* **Action taken:** Programmatically corrected the $C_p = 0.43 \rightarrow 0.232$ errors, the $2333\text{ N} \rightarrow 820\text{ N}$ tension figures, the over-designed ring mass budgets, and the stale hub excursion statistics directly in the three `.docx` files using a Python patching script.

---

## 2. Long-Term Modeling Gaps (For Future Research)

These items represent future modeling improvements rather than missing context for the current codebase:

### 2.1 Multi-Element Back-Line Model
* **Context:** The back-line is currently modeled as a single spring-damper. Implementing $5+$ back-line nodes (similar to the TRPT shaft sub-segments) would allow for Dyneema line sag under low wind, enabling high-fidelity collapse simulations.
* **Status:** Open research item (Phase N+1).

### 2.2 Stacked Kite Aerodynamic Shadowing
* **Context:** The stacked kite options (`Stack×3` and `Stack×5`) assume zero wake shielding. Future aerodynamic work should implement a spacing model to ensure upwind kites do not starve downwind kites of wind pressure.
* **Status:** Open research item.

---

*End of Missing Context List (Updated 2026-05-24)*
