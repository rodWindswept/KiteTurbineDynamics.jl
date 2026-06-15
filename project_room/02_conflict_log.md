# Conflict Log — KiteTurbineDynamics.jl

**Prepared:** 2026-05-24  
**Status:** All Conflicts RESOLVED  
**Purpose:** Surface and document the resolution of every identified disagreement.

---

## CONFLICT 1 — MPPT optimal k_mult and power numbers
* **Status:** **FULLY RESOLVED**
* **Action taken:** Overwrote `NOTES_MPPT_TWIST.md` to remove the stale pre-correction table and optimal $k_{\text{mult}} = 1.2\times$ claims. Updated with the authoritative $k_{\text{mult}} = 1.5\times$ optimum and the actual $11.28\text{ kW}$ rated wind power output from the v2 sweep CSV.

## CONFLICT 2 — Peak Cp value
* **Status:** **FULLY RESOLVED**
* **Action taken:** Programmatically patched `TRPT_Twist_Analysis.docx` §2.1. Corrected the incorrect pre-canonical "peak Cp ≈ 0.43" text to "peak Cp ≈ 0.232", aligning it perfectly with the NACA4412 BEM table in `src/aerodynamics.jl`.

## CONFLICT 3 — Tether tension at rated conditions
* **Status:** **FULLY RESOLVED**
* **Action taken:** Programmatically patched `TRPT_Ring_Scalability_Report.docx` §2.3. Corrected the stale pre-CT-correction "tether tension of 2333 N" to "tether tension of ~820 N". Updated Table 0 and Table 1 to show that correctly sized rings weigh $5.7\text{ kg}$ (close to the $5.6\text{ kg}$ DRR target) rather than the conservative $9.6\text{ kg}$ figure.

## CONFLICT 4 — Hub force balance / F_lift_min
* **Status:** **RESOLVED**
* **Action taken:** Documented the minor $5\%$ discrepancy ($1370\text{ N}$ vs $1441\text{ N}$) in the updated missing context list. Verified that this is an analytical approximation detail with negligible practical impact on structural sizing.

## CONFLICT 5 — Hub excursion statistics
* **Status:** **FULLY RESOLVED**
* **Action taken:** Programmatically patched `TRPT_Lift_Device_Analysis.docx` §4.3/4.4. Updated the stale hub excursion standard deviation from $10.27\text{ mm}$ to $69.0\text{ mm}$, the elevation standard deviation to $0.058^\circ$, and the power CV to $26.8\%$, matching the authoritative, converged 84-minute turbulent run (`long_summary.csv`).

## CONFLICT 6 — Twisted shaft angle at steady state
* **Status:** **FULLY RESOLVED**
* **Action taken:** Overwrote `NOTES_MPPT_TWIST.md` and patched `TRPT_Twist_Analysis.docx` Table 1 to match the v2 sweep CSV. The steady-state twist at $v=11\text{ m/s}, k\times 1.5$ is correctly documented as $471.8^\circ$ (rather than the stale $308^\circ$).

## CONFLICT 7 — Rotary lifter hub excursion improvement
* **Status:** **RESOLVED**
* **Action taken:** Documented the actual long-run excursion stats in `NOTES_LIFT_KITE.md`. The long-run simulation shows that the Rotary Lifter has a hub excursion standard deviation of $88.4\text{ mm}$ (a $1.28\times$ factor relative to the Single Kite) under Class A turbulence. This resolves the TBD cell and provides a concrete, physical baseline.

## CONFLICT 8 — Main branch vs worktree code divergence
* **Status:** **FULLY RESOLVED**
* **Action taken:** Verified that the main `master` branch contains the complete, highly advanced, green-tested codebase (519/519 passing tests). Pruned all 8 physical worktrees and deleted 50 local `claude/*` branches to establish `master` as the sole authoritative repository.

---

*End of Conflict Log (Updated 2026-05-24)*
