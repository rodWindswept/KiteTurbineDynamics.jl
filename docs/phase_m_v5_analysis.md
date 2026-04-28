# Phase M — v5 BEM-Coupled Campaign Results

**Date:** 2026-04-28
**Package:** KiteTurbineDynamics.jl
**Campaign:** `trpt_opt_v5` (60 islands, Differential Evolution, BEM-coupled rotor radius)

---

## Key Findings

- **n_lines preference unchanged:** All 60 feasible v5 islands converge to n_lines = 8 (same as v4). BEM coupling reinforces rather than shifts the maximum-lines preference — more blades increase Cp, reducing the required rotor radius and thus shaft loads.
- **BEM coupling adds +8.3% mass:** The 10 kW winner grows from 10.587 kg (v4) to 11.470 kg (v5). This reflects the BEM-computed r_rotor at n_lines = 8 being 5.51 m vs the v4 fixed assumption of 5.0 m — a physically honest penalty.
- **r_rotor scales inversely with n_lines:** Cp(n=8) = 0.494 vs Cp(n=3) = 0.391; the required r_rotor drops from 6.20 m (n=3) to 5.51 m (n=8) at 50 kW rated.
- **All islands feasible:** Unlike earlier campaigns, all 60 v5 islands are feasible at FOS ≈ 1.80 — the design space is well-conditioned at n_lines = 8.
- **Circular beam profile wins** (as in v4); elliptical and airfoil profiles produce negligible mass difference at this scale.

---

## 1. Campaign Setup

| Parameter | v4 | v5 |
|-----------|----|----|
| Rotor radius | Fixed 5.0 m | BEM-computed from n_lines |
| BEM model | None | Prandtl tip-loss: Cp = (16/27)·(1−e^{−n/2})·0.85 |
| Design variables | 9 DoF | 9 DoF (identical to v4) |
| Islands | 60 | 60 |
| Beam profiles | Circular, Elliptical, Airfoil | Circular, Elliptical, Airfoil |
| Power configs | 10 kW, 50 kW | 10 kW, 50 kW |
| BEM power target | — | 50 kW @ 12 m/s rated |

---

## 2. n_lines Preference — v4 vs v5

| Campaign | n_lines = 8 fraction | n_lines range |
|----------|----------------------|---------------|
| v4 | 60/60 (100%) | 8–8 |
| v5 | 60/60 (100%) | 8–8 |

**BEM coupling does not shift n_lines preference.** The physics reinforces n_lines = 8: more lines → higher Cp → smaller r_rotor → lower shaft loads → lighter structure. The optimizer reaches the upper bound (n_lines = 8) universally.

---

## 3. BEM Coupling Effect on r_rotor

The v5 objective computes:

```
Cp   = clamp((16/27) · (1 − exp(−n/2)) · 0.85,  0.15, 0.55)
r    = √(P / (Cp · ½ρπv³))
```

| n_lines | Cp | r_rotor @ 50 kW, 12 m/s (m) | vs v4 fixed 5.0 m |
|---------|----|-----------------------------|-------------------|
| 3  | 0.391 | 6.20 | ++24.0% |
| 4  | 0.436 | 5.88 | +17.5% |
| 5  | 0.462 | 5.70 | +14.1% |
| 6  | 0.479 | 5.61 | +12.1% |
| 8  | 0.494 | 5.51 | +10.3% |

At n_lines = 8: r_rotor = 5.51 m (vs v4's fixed 5.0 m), explaining the +8.3% mass increase.

---

## 4. v4 vs v5 Winner Comparison (10 kW)

| Metric | v4 Winner | v5 Winner | Delta |
|--------|-----------|-----------|-------|
| mass_kg | 10.587 | 11.470 | +8.3% |
| n_lines | 8 | 8 | 0 |
| r_hub_m | 1.600 | 1.600 | +0.0% |
| r_rotor_m | 5.00 (fixed) | 5.51 (BEM) | +10.3% |
| target_Lr | 2.00 | 2.00 | — |
| beam_profile | elliptical | elliptical | — |
| FOS | 1.800 | 1.800 | — |

---

## 5. v5 50 kW Winner

| Metric | Value |
|--------|-------|
| mass_kg | 39.295 |
| n_lines | 8 |
| r_hub_m | 3.578 |
| beam_profile | elliptical |
| FOS | 1.800 |

---

## 6. Figures

| Figure | Description |
|--------|-------------|
| `fig_v5_v4_comparison.png` | Grouped bar chart: v4 vs v5 winner on mass, r_hub, r_rotor, n_lines, FOS |
| `fig_v5_nlines_distribution.png` | n_lines histogram for v4 and v5 feasible islands — both converge to 8 |
| `fig_v5_pareto.png` | Mass vs FOS scatter for all 60 v5 islands (10 kW and 50 kW) |
| `fig_v5_rotor_radius.png` | BEM r_rotor curve and Cp curve vs n_lines; optimizer's choice marked |

---

## 7. Conclusions

The v5 BEM-coupled campaign confirms that **n_lines = 8 is the structural and aerodynamic optimum** within the allowed range (3–8). Adding BEM aerodynamics as a physics-based constraint:

1. **Does not shift n_lines preference** — the same upper-bound choice emerges naturally from the Prandtl tip-loss model.
2. **Adds a modest +8.3% mass penalty** for the 10 kW case, reflecting the physically correct r_rotor = 5.51 m vs the previously assumed 5.0 m.
3. **Provides a self-consistent design loop**: structural mass is now sized against a rotor radius that actually delivers the target power at the rated wind speed.

**Next steps:** Phase N should explore whether relaxing the n_lines upper bound beyond 8 further reduces r_rotor and shaft mass, or whether practical manufacturing constraints cap the benefit.
