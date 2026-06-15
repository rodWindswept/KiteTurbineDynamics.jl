# V6 Campaign Analysis — Key Findings & Blind Spots

**Date:** 2026-06-15
**Branch:** v6-force-first
**Context:** DE-optimised 11-DoF expansion-rotor TRPT designs at 10kW and 50kW,
supplemented by 5,000-sample LHS cartography sweeps.

---

## Final Optimised Designs

| Parameter | 10kW | 50kW |
|-----------|------|------|
| Total airborne mass | 23.87 kg | 259.44 kg |
| Structural mass | ~20 kg | 241.0 kg |
| r_hub | 1.60 m | 7.47 m |
| r_bottom | 1.49 m | 5.00 m (bound!) |
| n_rings | 19 | 6 |
| n_lines | 8 | 8 |
| Do_top | 34.8 mm | 112.4 mm |
| t_over_D | 0.02 | 0.02 |
| Do_scale_exp | 0.49 | 0.46 |
| n_expansion | 0 | 0 |
| Buckling FoS | 1.80 | 2.36 |
| Torsional FoS | 1.50 | **1.50** (binding) |
| BEM rotor radius | 4.14 m | 9.26 m |
| Mass/power | 2.39 kg/kW | 5.19 kg/kW |

**Mass scaling:** 259.44 / 23.87 = 10.87× for 5× power → mass ∝ P^1.37.
Matches the empirical exponent from `mass_scale(1.35)`.

---

## LHS Cartography — Correlation Analysis

### 10kW (22/5000 feasible = 0.4%)

**Feasible region is razor-thin:**
- r_hub: [1.65, 2.32] m
- r_bottom: [1.36, 1.50] m (MUST be near the 1.5m max)
- n_lines: [7, 8] (almost exclusively 8-line designs)
- n_rings: [18, 22]

**Mass correlations (feasible designs):**
| Variable | Correlation | Interpretation |
|----------|------------|----------------|
| Do_top_m | +0.80 | Bigger beams → heavier (dominant) |
| min_fos | +0.81 | Over-engineered → heavier |
| t_over_D | +0.60 | Thicker walls → heavier |
| n_rings | −0.28 | More rings → lighter (shorter segments reduce buckling demand) |
| n_expansion | −0.10 | Expansion rotors slightly reduce mass (weak signal) |

### 50kW (502/5000 feasible = 10.0%)

**Feasible region is wider but still constrained:**
- r_hub: [7.21, 10.79] m
- r_bottom: [2.95, 5.00] m (needs ≥ 3m ground ring)
- n_lines: [3, 8]
- n_rings: [7, 22]

**Mass correlations (feasible designs):**
| Variable | Correlation | Interpretation |
|----------|------------|----------------|
| Do_top_m | +0.54 | Beam sizing still matters |
| n_rings | +0.44 | More rings → heavier (opposite of 10kW!) |
| t_over_D | +0.46 | Wall thickness |
| target_Lr | −0.43 | Smaller L/r → lighter (shorter ring spacing reduces demand) |
| r_bottom_m | −0.14 | Wider ground ring → slightly lighter (torsional benefit) |
| min_torsional_fos | +0.26 | Over-designed for torsion → heavier |

**Key reversal:** At 10kW, more rings reduce mass (shorter segments → less buckling demand → thinner beams). At 50kW, more rings INCREASE mass — the torsional constraint dominates, and additional rings add weight without helping the ground-adjacent segments where torsion is worst.

---

## Blind Spots & Open Questions

### 1. Why don't expansion rotors help?
The LHS data shows feasible designs with n_expansion=1–6 at both power levels, but the DE optimiser always drops them. The structural benefit of ring spreading (F_radial reduces ring compression) is real but doesn't outweigh the added mass. Questions:
- Would expansion rotors help at 100kW+ where the mass penalty is proportionally smaller?
- Does the force-first model capture the full benefit? The current model applies F_radial as a load reduction — is there a geometric benefit (larger effective radius) that's not modelled?
- Are we modelling the expansion rotor aerodynamic forces correctly at scale?

### 2. The r_bottom bound is saturated
Both designs hit the ground ring upper bound (1.5m for 10kW, 5.0m for 50kW). The DE wants wider ground rings. This suggests:
- Transport constraints (flatbed trailer = 1.5m) are the binding commercial constraint at 10kW
- At 50kW, different transport methods might be viable (wider trailer, site assembly)
- What's the mass reduction if we remove the ground ring constraint entirely?

### 3. The feasible region is pathologically narrow at 10kW
Only 0.4% of random designs are feasible. The DE found 23.87 kg through guided search, but the LHS best (random sampling) was 136.9 kg — 5.7× worse. This means the DE is doing real optimisation work, not just random sampling. But it also means small changes to the model or bounds could dramatically change what's feasible.

### 4. Torsional collapse is the binding constraint at 50kW
τ_FoS = 1.50 exactly at the requirement. Buckling FoS = 2.36 (well above). The design is torsion-limited. This confirms the paper's thesis: the TRPT scaling wall IS a torsional problem.

### 5. Mass scaling is consistent but non-linear
Mass ∝ P^1.37 means the mass/power ratio worsens from 2.39 kg/kW (10kW) to 5.19 kg/kW (50kW). At 100kW, this would be ~11 kg/kW — the economic case degrades. This is exactly what the expansion rotor concept was meant to fix, but it's not working at these scales.

### 6. What about multi-rotor generation?
If every ring carries a generating rotor (not just the hub ring), the thrust is distributed along the shaft rather than concentrated at the hub. This could change the structural loading pattern. The test is running now (scripts/test_multi_rotor.jl).

### 7. The BEM rotor sizing uses n_lines as blade count
The CP/CT lookup uses `design.n_lines` (number of TRPT tension lines) as the blade count. This conflates structural topology with aerodynamics. A 3-line TRPT with 3 aerodynamic blades vs 3 lines with 8 blades would have different rotor sizes. We should decouple these.

### 8. The penalty barrier fix might mask a deeper problem
The +1e6 absolute barrier (feasible always beats infeasible) fixed the DE's preference for penalty designs at 50kW. But the fact that feasible designs are so rare (10% at 50kW, 0.4% at 10kW) suggests the design space itself might be too constrained. Are our FoS requirements (1.8 buckling, 1.5 torsion) appropriate for a first-pass optimisation?

---

## Campaign Methodology Lessons

1. **DE with collapse-reseed = multi-start local search.** The population collapses within ~100 iterations regardless of mutation parameters. My fixes (collapse detection + aggressive reseed + stagnation break) convert this into an effective exploration strategy: ~720 random starts across 60 islands, each rapidly converging to a local minimum.

2. **The penalty landscape is tricky.** At 10kW, +100 bias was enough (feasible ~24 kg < penalty ~107 kg). At 50kW, feasible ~260 kg > penalty ~157 kg without the barrier. Power-dependent penalty scaling would be more robust.

3. **LHS cartography is essential for interpretation.** The DE gives a single number; the LHS sweep shows the full feasible region, correlations, and how narrow the path to feasibility actually is.

---

## Figures Generated

- `scripts/results/design_overlay.png` — overlaid 10kW (red) + 50kW (green) TRPT towers
- `scripts/results/v6_cartography_10kw.csv` — 5,000-sample LHS sweep
- `scripts/results/v6_cartography_50kw.csv` — 5,000-sample LHS sweep
