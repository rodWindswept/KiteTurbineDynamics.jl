# RESTART INSTRUCTIONS — 2026-04-20

## Current state: MASTER IS CLEAN — START NEW WORK HERE

Branch: `master` (PR #1 merged 2026-04-20)  
Last meaningful commit: `91fca38` — "Resolve T_line discrepancy and update hub excursion tables"

All 8 TRPT reports are validated and current. No outstanding report fixes.

---

## What was completed (sessions 2026-04-19 → 2026-04-20)

Full cross-validation of all 8 TRPT `.docx` reports against the simulator.  
Full findings: `docs/validation/2026-04-19-report-validation.md`

| Report | Action taken |
|--------|-------------|
| `TRPT_Dynamics_Report.docx` | Regenerated via `scripts/produce_report.py` |
| `TRPT_FreeBeta_Report.docx` | Regenerated via `scripts/produce_free_beta_report.py` |
| `TRPT_KiteTurbine_Potential.docx` | Regenerated via `scripts/produce_kite_turbine_potential_report.py` |
| `TRPT_Twist_Analysis.docx` | Regenerated via new `scripts/produce_twist_report.py` — Cp fixed 0.43→0.232 |
| `TRPT_Ring_Scalability_Report.docx` | Corrigendum added — T_line 2333N was pre-CT-correction; current ~820N |
| `TRPT_Lift_Device_Analysis.docx` | Hub excursion tables updated from 60s turbulent runs (I=15%) |
| `TRPT_Stacked_Rotor_Analysis.docx` | Centrifugal load corrigendum applied (blade CoM 3.8m not 3.0m) |
| `TRPT_Conical_Stack_Analysis.docx` | Physics cross-verified; /tmp script loss noted (low priority) |

**Key findings from validation:**
- Peak Cp = **0.232** (not 0.43 as claimed in old Twist Analysis)
- Optimal MPPT gain is **k×1.5 = 16.5 N·m·s²/rad²** (base k=11 is sub-optimal)
- Tether tension at rated: **T_max ≈ 820 N** per line (not 2333 N — old value was pre-Cp-fix)
- RotaryLifter with default params (LM=0.28) underperforms SingleKite in turbulence;
  physical mechanism confirmed in steady wind

---

## Next work: Phase B

Three items to specify and execute. The user went AFK — read this section carefully before
starting any of them.

### B1 — Diagram configuration issues
- The user mentioned issues with current diagrams but did not detail them before going AFK
- **Do not start this until the user explains what the issues are**

### B2 — TRPT sizing optimisation routine
- Build a systematic optimisation over TRPT geometry parameters
- Goal: maximise P/m_airborne (or P at target system cost) across (R, L, β, n_lines)
- Likely approach: script in `scripts/` reading existing `params_10kw()` as baseline
- **Needs design discussion with user before implementation**

### B3 — Line tension investigation
- Investigate a specific line tension result (user has a particular result in mind)
- May connect to the T_line=2333N → 820N finding from the validation session
- **Needs user to specify which result and what the question is**

---

## Key files

| File | Purpose |
|------|---------|
| `docs/validation/2026-04-19-report-validation.md` | Full cross-check findings for all 8 reports |
| `scripts/produce_twist_report.py` | Generator for TRPT_Twist_Analysis.docx (new this session) |
| `scripts/results/mppt_twist_sweep/twist_sweep_v2_summary.csv` | 28-row settled MPPT data |
| `scripts/results/lift_kite/long_summary.csv` | Hub excursion data (60s, I=15%) |
| `src/aerodynamics.jl` | BEM table: peak Cp=0.232 at λ=4.0–4.1, CT(4.1)=0.548 |
| `src/parameters.jl` | Canonical `params_10kw()` — all reports reference this |
| `src/structural_safety.jl` | DO_SCALE conservative (calibrated pre-CT-correction); see comment |

## Simulator quick reference

```
params_10kw(): R=5m, L=30m, β=30°, n_lines=5, n_rings=14, Cp=0.22, k_mppt=11.0
Optimal k_mppt (from sweep): 16.5 N·m·s²/rad²
Hub altitude: 30×sin(30°) = 15 m
Peak Cp: 0.232 at λ=4.0–4.1 (AeroDyn BEM NACA4412 3-blade)
T_max at rated (k=1.0, v=11): ~820 N per line
T_max at optimal (k=1.5, v=11): ~730 N per line
```
