# Phase J — v4 Campaign Results: TRPT Shaft Structural Optimisation

**Date:** 2026-04-25  
**Package:** KiteTurbineDynamics.jl  
**Campaign:** `trpt_opt_v4` (168 h, 60 islands, Differential Evolution)

---

## 1. Background and Motivation

Three progressive optimisation campaigns have refined the minimum-mass design of the TRPT
(Tensile Rotary Power Transmission) shaft — the airborne structural spine of the kite turbine.

| Campaign | Physics version | Beam constraint | Torsional constraint | Taper |
|----------|----------------|-----------------|---------------------|-------|
| v2 | Fixed n_rings, fixed L spacing | ✓ beam FOS ≥ 1.8 | ✗ | Free |
| v3 | Fixed n_rings, geometric spacing | ✓ beam FOS ≥ 1.8 | ✓ torsional FOS ≥ 1.5 | Forced cylindrical |
| **v4** | Constant L/r spacing (geometric series) | ✓ beam FOS ≥ 1.8 | ✓ torsional FOS ≥ 1.5 | **Free** |

The v3 campaign found 15.435 kg but imposed a cylindrical shaft profile (`taper_ratio = 1.0`)
to isolate the effect of adding the torsional constraint. v4 restores taper freedom and
replaces the arbitrary axial-profile family with a physically motivated constant L/r spacing
rule, making ring count and positions derived quantities rather than free variables.

---

## 2. v4 Formulation

### 2.1 Design Variables (9 DoF)

| Variable | Symbol | Bounds | Description |
|----------|--------|--------|-------------|
| `Do_top` | D₀ | 5–120 mm (scaled) | Outer beam diameter at hub ring |
| `t_over_D` | t/D | 0.01–0.05 | Wall thickness ratio |
| `beam_aspect` | b/a | profile-dependent | Ellipticity / airfoil t/c |
| `Do_scale_exp` | α | 0–1 | Taper exponent: D(r) = D₀·(r/r_hub)^α |
| `r_hub` | r_top | 0.8–1.2 × r_rotor | Hub ring radius |
| `r_bottom` | r_bot | 0.3–1.5 m | Ground ring radius |
| `target_Lr` | L/r | 0.4–2.0 | Target slenderness for each shaft segment |
| `knuckle_mass_kg` | m_k | 0.01–0.20 kg | Per-vertex point mass |
| `n_lines` | n | 3–8 (integer) | Polygon sides (ring vertices) |

### 2.2 Constant L/r Ring Spacing

For a linearly tapered shaft from r_hub (top) to r_bottom (ground) over tether length L, the
constant-L/r constraint means each inter-ring segment satisfies:

```
L_seg_i / r_mid_i = target_Lr    (for all i)
```

Under a linear taper, this produces ring radii forming a geometric series:

```
r_i = r_hub · k^i
```

where the ratio k = (2 − α·c) / (2 + α·c), α = (r_hub − r_bottom) / L, c = target_Lr.

Ring count n_rings is derived from when the series reaches r_bottom — it is not a free
variable. This means every shaft design is fully determined by 9 numbers; the spatial ring
layout follows automatically.

**Physical motivation:** constant L/r ensures every segment operates at the same normalised
slenderness, so no segment is wastefully under-loaded relative to its Euler buckling capacity.
This is structurally optimal for a column under axial compression.

### 2.3 Beam Profiles

Three cross-section families were explored:

- **Circular:** thin-walled circular tube; `beam_aspect = 1.0` fixed
- **Elliptical:** thin-walled ellipse; `beam_aspect = b/a ∈ [0.25, 1.0]`
- **Airfoil:** NACA-style; `beam_aspect = t/c ∈ [0.08, 0.20]`

### 2.4 Constraints

| Constraint | Threshold | Enforcement |
|------------|-----------|-------------|
| Beam Euler buckling FOS | ≥ 1.8 | Hard penalty (mass → ∞ if infeasible) |
| Torsional collapse FOS | ≥ 1.5 | Hard penalty |
| Ground ring radius | ≤ 1.5 m | Hard geometric bound |

---

## 3. Campaign Setup

| Parameter | Value |
|-----------|-------|
| Total time budget | 168 h |
| Number of islands | 60 |
| Time per island | ≈ 2.8 h |
| Power configs | 10 kW, 50 kW |
| Beam profiles | Circular, Elliptical, Airfoil |
| Lr initialisation zones | 5 (biased starting populations: [0.4–0.8], [0.7–1.1], …, [1.6–2.0]) |
| Random seeds | 2 |
| Island layout | 2 configs × 3 beams × 5 zones × 2 seeds = 60 |
| DE population | 64 |
| DE mutation factor F | 0.7 |
| DE crossover CR | 0.9 |
| Stall restart threshold | 1 500 generations |
| Evaluations per island | ≈ 1.28 × 10⁸ |

---

## 4. Results

### 4.1 10 kW Winner

All 20 islands with 10 kW circular or elliptical profiles converged to the same design:

| Parameter | Value |
|-----------|-------|
| **Total shaft mass** | **10.587 kg** |
| Beam profile | Circular (Elliptical identical) |
| Hub ring radius r_hub | 1.600 m |
| Ground ring radius r_bottom | 0.336 m |
| Tether length | 30.0 m |
| Target L/r (target_Lr) | 2.0 |
| Derived n_rings | ≈ 19 |
| Lines (n_lines) | 8 |
| Do_top | 39 mm |
| Taper exponent (Do_scale_exp) | 0.49 |
| Wall ratio (t/D) | 0.020 |
| Beam FOS | 1.80 (at constraint) |
| Torsional FOS | ≥ 1.5 (all islands feasible) |

The 10 kW airfoil group converged to a distinct local minimum at **70.78 kg**, confirming that
airfoil cross-sections are structurally inefficient at this scale.

### 4.2 50 kW Results

| Beam profile | Best mass |
|--------------|-----------|
| Circular     | 79.51 kg  |
| Elliptical   | 79.51 kg  |
| Airfoil      | 749.50 kg |

The 50 kW airfoil penalty (≈9.4× vs circular) is consistent with the 10 kW finding.

### 4.3 Convergence Robustness

Every one of the 10 seeds/variants within the 10 kW circular group returned the same mass
(10.587 kg) to within numerical precision, regardless of initial Lr zone. This is strong
evidence that DE found the global minimum for this configuration.

---

## 5. Campaign Comparison (10 kW)

| Campaign | Best mass | vs v3 | Notes |
|----------|-----------|-------|-------|
| v2 (beam only, taper free) | 2.808 kg | — | Torsionally infeasible; not a valid design |
| v3 (beam + torsion, cylindrical) | 15.435 kg | baseline | Forced cylindrical, 5 rings |
| **v4 (beam + torsion, taper free)** | **10.587 kg** | **−31.4 %** | ≈19 rings, target_Lr = 2.0 |

**Key finding:** restoring taper freedom (Do_scale_exp freed from implied 0.0) saves 4.85 kg
or 31.4 % versus the v3 cylindrical result, under identical structural constraints. The saving
arises because a tapered shaft carries lower torsional load in the narrow lower segments,
reducing the minimum required tube diameter throughout the lower shaft.

The v4 mass (10.587 kg) is 3.77× heavier than the v2 beam-only result (2.808 kg), confirming
that the torsional constraint adds genuine structural mass: approximately 7.8 kg for the 10 kW
design with taper, and 12.6 kg without taper (v3 − v2).

### Comparison with v3 winner spec

| Parameter | v3 winner | v4 winner |
|-----------|-----------|-----------|
| Mass | 15.435 kg | 10.587 kg |
| r_hub | 1.994 m | 1.600 m |
| n_rings | 5 | ≈ 19 |
| Taper | Cylindrical (ratio 1.0) | Tapered (exp 0.49) |
| Beam profile | Circular | Circular |
| Ring spacing | Elliptic axial profile | Constant L/r geometric |
| Torsional FOS | 1.50 (at constraint) | ≥ 1.50 (all feasible) |
| Beam FOS | 1.80 (at constraint) | 1.80 (at constraint) |

Note that the v4 winner has a smaller hub radius (1.6 m vs 2.0 m) and many more rings (≈19 vs
5). The geometry is a long, narrow, sharply tapering structure rather than the v3 short-and-
wide cylindrical shaft.

---

## 6. Figures

| Figure | Description |
|--------|-------------|
| `figures/fig_v4_pareto.png` | Final mass for all 60 islands, grouped by (power config, beam profile), log-scale y-axis. Demonstrates DE convergence robustness within each group. |
| `figures/fig_v2_v3_v4_comparison.png` | Bar chart comparing best 10 kW mass across v2/v3/v4; FOS constraint margins in right panel. |
| `figures/fig_v4_geometry.png` | Side-elevation schematic of the winning v4 shaft: ≈19 rings over 30 m tether, tapering from r_hub=1.6 m to r_bottom=0.34 m. |
| `figures/fig_v4_island_heatmap.png` | 60-cell heatmap (log₁₀ kg) showing all island results; row = config/beam, column = variant/seed. |

---

## 7. Conclusions and Next Steps

1. **Taper restoration is validated:** the 31 % mass reduction vs v3 is robust across all 20
   relevant islands and is not a search artefact.

2. **Constant L/r spacing is the right physical principle:** it ensures every segment is
   structurally efficient, and the derived ring count (≈19) is much higher than v3's 5 rings.
   This has manufacturing implications — 19 ring connections add cost and complexity.

3. **Airfoil profiles are disqualified at 10 kW and 50 kW scale:** both show penalties of
   ≥6× vs circular. Further campaigns should drop the airfoil family.

4. **10 kW structural minimum is credible at 10.587 kg:** but this is a quasi-static
   optimiser result under simplified load assumptions (DLF = 1.2, peak wind 13 m/s at 30°
   elevation). Higher-fidelity FEA validation is required before committing to dimensions.

5. **50 kW path:** 79.5 kg shaft mass at 50 kW implies a shaft:power ratio of 1.59 kg/kW vs
   1.06 kg/kW at 10 kW. Scaling penalty is modest; 50 kW is worth pursuing.
