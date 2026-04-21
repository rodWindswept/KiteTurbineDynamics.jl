# Session Notes — 2026-04-01
## What was done / What is pending

---

## Done this session

### Report
- Written full scientific report: `Lift_Kite_Sizing_Report.docx` (692 kB)
- Generated 5 matplotlib figures, saved to `figures/`:
  - `fig1_system_architecture.png` — side elevation schematic (β, α, hub, lift line, kite)
  - `fig2_dynamic_pressure.png` — q vs v parabola showing the 35.6× cut-in/storm ratio
  - `fig3_force_balance.png` — 3-force hub equilibrium, two-panel (normal + near-failure)
  - `fig4_rotary_lifter.png` — apparent wind vector triangle + governor v_app plateau chart
  - `fig5_tension_comparison.png` — all options tension vs wind speed, governor knee visible
- Report and figures correctly published to `/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/`
- Report generation scripts saved to `/tmp/gen_figures.py` and `/tmp/gen_report_correct.py`
  - **⚠ These are in /tmp and will be lost on reboot — copy to repo before next session**

### Path
- Confirmed the live working repo is `KiteTurbineDynamics.jl` (has GitHub remote)
- `TRPTKiteTurbineJulia2` on `/mnt/RodsData/` has no remote — treat as archive only

---

## NOT YET done — highest priority next session

### 1. Port code changes from TRPTKiteTurbineJulia2 → KiteTurbineDynamics.jl

All physics and visualisation work from the previous session was written into
`/mnt/RodsData/GitHub/TRPTKiteTurbineJulia2/` and has **not** been ported to this repo.
Files that need updating:

| File | What to port |
|------|-------------|
| `src/geometry.jl` | Add `lift_kite_geometry()` function (physics-derived kite angle from v_hub and shaft_dir) |
| `src/visualization.jl` | Replace static bearing offset with `lift_kite_geometry()` call; add `lift_kite_obs` reactive observable |
| `test/test_geometry.jl` | Add 19 new tests for `lift_kite_geometry` (hub position, angle vs wind, azimuth tracking) |
| `scripts/` | Add `run_gust_limited.jl` (3-state ODE + Hann-window gust) |
| `scripts/` | Add `run_turbulent_limited.jl` (3-state ODE + IEC 61400-1 Class A turbulence) |
| `README.md` | Update clone URL, add new scripts to table, update test count |

Reference: all the above already exists and is working in TRPTKiteTurbineJulia2.
Source path: `/mnt/RodsData/GitHub/TRPTKiteTurbineJulia2/`

### 2. Save report generation scripts to repo

Copy out of /tmp before reboot:
- `/tmp/gen_figures.py` → `scripts/gen_report_figures.py`
- `/tmp/gen_report_correct.py` → `scripts/gen_report.py`

### 3. Missing §8 Conclusions figure (Julia GLMakie render)

The report has a placeholder note in §8:
> "A Julia GLMakie render of the installed geometry will be added in a subsequent revision."

Plan:
- Add a white-background export function to `scripts/interactive_dashboard.jl`
  (set `fig.scene.backgroundcolor[] = :white`, hide UI panels, call `save("export.png", fig.scene)`)
- Run at rated conditions (V=11 m/s, β=30°) — screenshot already taken, geometry confirmed correct
- Load PNG into matplotlib, overlay labels (β, α, hub annotation, lift line label, dimension callouts)
- Embed in §8 of the report and regenerate docx

### 4. Git commit

Nothing in this repo has been committed since the reports and figures were added.
Files to stage:
```
figures/
Lift_Kite_Sizing_Report.docx
docs/plans/2026-04-01-session-notes-pending-work.md
(+ all ported code files once done)
```

---

## Key numbers for reference

| Parameter | Value |
|-----------|-------|
| Airborne mass | 17.6 kg → W = 172.6 N |
| T_required at cut-in | 217 N (α=70°, β=23°) |
| Rotary lifter recommendation | 3 m², λ=4, τ=k·ω² governor |
| Cut-in margin (3 m²) | ×1.7 |
| Storm tension (3 m²) | 3.4 kN |
| Depower ratio (rotary) | ÷9× vs ÷41–68× for static |
| Lift line SWL | 5 kN (4 mm Dyneema SK75) |
