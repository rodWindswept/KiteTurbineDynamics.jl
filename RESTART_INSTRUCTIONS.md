# RESTART_INSTRUCTIONS.md

## Current state (2026-04-22)

**v3 campaign is complete.** All 60 islands (2 configs × 3 beams × 5 axials × 2 seeds)
have finished.  Results are in `scripts/results/trpt_opt_v3/`.

**What v3 added over v2:** The Tulloch torsional collapse criterion is now a hard
feasibility gate alongside Euler buckling:
- Euler FOS ≥ 1.8 (survival, 25 m/s, DLF=1.2) — unchanged from v2
- Torsional FOS ≥ 1.5 (rated torque, Tulloch criterion) — NEW in v3

**Key v3 results:**
- All 60 designs converged to taper_ratio = 1.0 (cylindrical shaft)
- 10 kW winner: 15.44 kg (was 2.81 kg in v2, +449 %)
- 50 kW winner: 145.88 kg (was 19.22 kg in v2, +659 %)
- 54/60 v2 designs were physically infeasible (torsional collapse)
- Mean mass increase across all 60 configs: +304 %
- Phase I section added to TRPT_Design_Cartography_Report.docx

**Cartography figures** in `scripts/results/trpt_opt_v3/cartography/`:
- `fig_v2_vs_v3_mass_comparison.png` — grouped bar chart
- `fig_v3_geometry_shift.png` — taper and r_hub scatter
- `fig_v3_winner_glmakie.png` — GLMakie render of 10 kW winner

---

## Next step: v4 — Variable ring spacing with constant L/r

**Hypothesis:** The cylindrical constraint (taper=1.0) means all rings have the same
radius but they can have variable spacing along the shaft axis.  The optimiser should
explore non-uniform ring spacing (denser near the top where the torque peaks, sparser
near the bottom) while maintaining a constant L/r ratio (tether length to ring radius)
across all rings.  This may reduce mass by concentrating material where it is most
needed.

**v4 design variables to add:**
- `ring_spacing_profile` — parameterised by 1–3 shape parameters (e.g. exponential,
  linear, or fixed-fraction distribution of axial spacings), similar to the axial
  taper profiles in v2/v3
- `L_over_r` ratio — currently fixed by `tether_length / r_hub`; allow it to vary
  as an optimisation variable (within physical bounds)
- Keep `taper_ratio = 1.0` fixed (cylindrical, as enforced by v3 physics)

**Constraints unchanged:** Euler FOS ≥ 1.8 + Torsional FOS ≥ 1.5 at all rings.

**Starting point for v4:**
```bash
# 1. Copy run_trpt_optimization_v3.jl → run_trpt_optimization_v4.jl
# 2. Add ring_spacing_profile to TRPTDesignV2 (or create TRPTDesignV4)
# 3. Fix taper=1.0 in design struct
# 4. Add L_over_r as a free variable (bounds: 0.3–1.5 typical range)
# 5. Launch 60 islands as before
julia --project=. scripts/launch_v4_campaign.sh
```

---

## Reproducing v3 results

All results are committed.  To regenerate the comparison figures:
```bash
python3 scripts/produce_v3_comparison_report.py
julia --project=. scripts/render_v3_winner.jl
python3 scripts/append_phase_i_section.py   # re-appends Phase I to docx
```

To verify torsional FOS of all v3 winners:
```bash
julia --project=. -e "
using KiteTurbineDynamics; using CSV, DataFrames
v3_dir = \"scripts/results/trpt_opt_v3\"
for d in sort(readdir(v3_dir; join=true))
    isfile(joinpath(d, \"elite_archive.csv\")) || continue
    df = CSV.read(joinpath(d, \"elite_archive.csv\"), DataFrame)
    isempty(df) && continue
    println(basename(d), \"  tFOS=\", round(df[1, :torsional_fos]; digits=4))
end
"
```

---

## Code reference

| File | Purpose |
|------|---------|
| `src/trpt_axial_profiles.jl` | `evaluate_design(TRPTDesignV2)` — torsional check |
| `src/trpt_optimization.jl` | `EvalResult` struct — torsional_fos_min field |
| `scripts/run_trpt_optimization_v3.jl` | v3 DE optimiser |
| `scripts/produce_v3_comparison_report.py` | v2 vs v3 comparison figures |
| `scripts/append_phase_i_section.py` | Appends Phase I section to docx |
| `scripts/render_v3_winner.jl` | GLMakie render of v3 winner |
| `DECISIONS.md` | Full torsional criterion derivation + physics rationale |
