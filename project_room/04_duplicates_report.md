# Duplicates Report — KiteTurbineDynamics.jl

**Prepared:** 2026-05-24  
**Status:** Updated & Resolved  
**Purpose:** Surface and document the resolution of duplicate files and version families.

---

## 1. Resolved Duplication Families

### FAMILY 1 — The Eight Worktree Copies
* **Status:** **FULLY RESOLVED**
* **Action taken:** Ran `git worktree remove --force` on all 8 active worktrees and ran `git worktree prune` to clear their metadata. Deleted the physical `.claude/worktrees/` directory completely.
* **Result:** Eliminated over 800 duplicate source, test, result, and doc files across the workspace, leaving the main `master` branch as the single authoritative workspace.

### FAMILY 2 — TRPT_Dynamics_Report.docx (Worktree duplicates)
* **Status:** **FULLY RESOLVED**
* **Result:** Deleting the worktrees pruned all parallel copies of these reports. The only remaining copies exist at root or in `docs/` and are fully validated.

### FAMILY 6 — README.md (Worktree duplicates)
* **Status:** **FULLY RESOLVED**
* **Result:** Only the main `README.md` at root remains.

### FAMILY 7 — DECISIONS.md (Worktree duplicates)
* **Status:** **FULLY RESOLVED**
* **Result:** Only the main `DECISIONS.md` at root remains.

### FAMILY 8 — RESTART_INSTRUCTIONS.md (Worktree duplicates)
* **Status:** **FULLY RESOLVED**
* **Result:** Only the main `RESTART_INSTRUCTIONS.md` at root remains.

### FAMILY 9 — Session Notes duplicates
* **Status:** **FULLY RESOLVED**
* **Result:** Only the main copies remain.

### FAMILY 10 — Validation Report duplicates
* **Status:** **FULLY RESOLVED**
* **Result:** Only the main copy at `docs/validation/2026-04-19-report-validation.md` remains.

---

## 2. Active Version Families (To Be Managed)

### FAMILY 3 — MPPT Twist Sweep Data (v1 and v2)
* **Type:** Coexistence of old and new simulation data files.
* **Risk:** Stale v1 CSV data (`twist_sweep.csv`, `twist_sweep_summary.csv`, and `sweep.log`) sits next to current v2 data.
* **Recommendation:** Keep v1 files in a dedicated `scripts/results/archived/` subdirectory so they are not picked up by scripts that scan `twist_sweep*.csv`, but preserve them for historical auditability if needed.

### FAMILY 4 — mppt_twist_sweep.jl vs mppt_twist_sweep_v2.jl
* **Type:** Old and new sweep scripts.
* **Risk:** Running the v1 sweep script `mppt_twist_sweep.jl` by mistake would generate stale data.
* **Action planned:** Add a warning header inside the v1 script pointing developers to v2, or move v1 to an archived/ scripts folder.

### FAMILY 5 — Hub Excursion Results (Short vs Long)
* **Type:** Methodological variance.
* **Explanation:** `hub_excursion_summary.csv` represents a short 3-second clean run, whereas `long_summary.csv` represents an 84-minute long turbulent run. These are not "duplicates," but they are different datasets for the same physical metrics.
* **Action planned:** Annotate the README inside `scripts/results/` to explicitly explain the methodology behind both runs, preventing any future confusion.

---

*End of Duplicates Report (Updated 2026-05-24)*
