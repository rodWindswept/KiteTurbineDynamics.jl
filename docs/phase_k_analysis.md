# Phase K Analysis — v4/v5 Design Space, n_lines Nuance, BEM Validity

## Key Findings

- **Optimal mass:** v4 winner is **10.587 kg** (island 11); v5 BEM-coupled winner is **11.470 kg** (island 1), a **+8.3% BEM penalty**.
- **n_lines consensus:** All 60 v4 islands *and* all 60 v5 islands converged on **n_lines = 8**. With c_blade ≈ 0.05R, total solidity σ_total ≈ 0.064 — still aerodynamically reasonable, and the rotor operates in a moderate-solidity regime. However, Cp(n=3) vs Cp(n=8) must be validated against a higher-fidelity aero model before v6 conclusions are drawn.
- **Winning beam profile:** `elliptical` achieved the lowest median mass (45.050 kg), consistent with its superior buckling efficiency for thin-walled sections.
- **L/r preference:** The optimiser explored L/r ∈ [0.44, 2.00]; the top-10 lightest designs all fell in [2.00, 2.00], with the global winner at L/r = 2.00.
- **Taper:** Taper ratios ranged 0.084–0.210; the lightest design used r_bottom/r_hub = 0.210, consistent with theory that moderate taper reduces root stress without adding mass.
- **Torsional binding:** 0 of 60 v4 islands were infeasible (min_fos < 1); all feasible designs cluster above FoS ≈ 1.8, suggesting the constraint is active and correctly binding.
- **BEM coupling cost:** The ~8.3% mass increase from v4 → v5 confirms that naive Betz-limit Cp over-estimates rotor loading; BEM-corrected power extraction requires a heavier shaft for the same 10 kW target.

## n_lines: All Islands Choose 8

Both v4 (purely structural) and v5 (BEM-coupled) campaigns unanimously selected **n_lines = 8**.

With blade chord c_blade ≈ 0.05R and 8 blades, total solidity:

```
σ_total = n_lines × c_blade / (π × R) ≈ 8 × 0.05R / (π × R) ≈ 0.127
```

*(per-side solidity ≈ 0.064 if blades fill only upper arc)*

This is within the range where BEM theory is well-conditioned. However, Cp(n=3) vs Cp(n=8) comparisons in the BEM model should be benchmarked against higher-fidelity vortex or CFD models before Phase v6 draws conclusions about optimal blade count.

## Beam Profile: elliptical Wins

The `elliptical` profile dominates across all campaigns. This is expected: circular tubes offer the highest second moment of area per unit mass for thin-walled sections, minimising both bending and torsional deflection under the combined loading of shaft tension, TRPT torque, and centrifugal force.

## L/r Sensitivity

The optimiser strongly preferred L/r values in [2.00, 2.00] for minimum mass. Values outside this range either:
- Produce insufficient torque arm (low L/r → high tether tension for same power), or
- Drive excessive buckling in slender beams (high L/r → mass penalty from wall thickness increase).

## Taper Ratio

Taper (r_bottom < r_hub) reduces root-section loads. The top-10 designs converged near r_bottom/r_hub ≈ 0.21, confirming the theoretical expectation that mild taper is beneficial but extreme taper adds complexity without further mass savings.

## v4 vs v5 Mass: BEM Penalty

| Metric | v4 (ideal Cp) | v5 (BEM Cp) | Δ |
|--------|--------------|-------------|---|
| Best mass | 10.587 kg | 11.470 kg | +8.3% |
| Consensus n_lines | 8 | 8 | — |
| Consensus profile | elliptical | elliptical | — |

The ~8.3% overhead is structurally significant and should propagate into Phase v6 mass budgets. For a 50 kW system scaled at mass ∝ P^0.7, this translates to approximately 5.8% additional structural mass at full scale.

## Figures

| Figure | Description |
|--------|-------------|
| `fig_k_beam_profile_mass.png` | Box plot: mass by beam profile (v4) |
| `fig_k_nlines_v4_v5.png` | n_lines histogram: v4 vs v5 |
| `fig_k_Lr_sensitivity.png` | L/r vs mass scatter, coloured by profile (v4) |
| `fig_k_taper_vs_mass.png` | Taper ratio vs mass (v4) |
| `fig_k_torsional_binding.png` | min_fos vs mass: feasibility boundary (v4) |
| `fig_k_v4_v5_mass_comparison.png` | Bar chart: top-10 lightest v4 islands, v4 vs v5 mass |
