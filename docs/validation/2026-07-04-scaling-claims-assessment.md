# Assessment: AWE Scaling Claims from "New Energy - Airborne Wind Energy" (think garage)

**Status**: Structured literature verification against published AWE research
**Date**: 2026-07-04
**Note**: The YouTube video transcript could not be retrieved (YouTube consent wall + channel unavailable via API). Claims assessed are as described in the task brief.

---

## Claim 1: Wing loading ∝ A^(1/2) → Turn radius ∝ A^(1/2) → Height ∝ A^(1/2) → Velocity ∝ A^(1/4)

### Assessment: MATHEMATICALLY CORRECT FOR CUBE-SQUARE REGIME, BUT OVER-SIMPLIFIED

**Derivation logic:**
- If mass scales as m ∝ A^(3/2) (cube-square law), then wing loading = m/A ∝ A^(1/2) ✓
- Turn radius scales with wingspan ∝ A^(1/2) (geometrically consistent) ✓
- From lift = weight equilibrium: (1/2)ρv²A·C_L = mg, so v² ∝ mg/A ∝ A^(3/2)/A = A^(1/2), giving v ∝ A^(1/4) ✓
- Height ∝ A^(1/2) — this relationship is less rigorously derived; it appears to follow from geometric scaling of the flight window

**Literature support and caveats:**

1. **Sommerfeld et al. (2022)** — confirms mass scaling exponents κ are the key uncertainty. Literature values range from κ = 2.2–2.6 (optimistic, positive scaling) to κ = 3.0 (geometric) to κ = 3.23 (actual M600 built mass). The video assumes κ = 1.5 (m ∝ A^(3/2)) for soft kites and implicitly κ = 3 for rigid, which is within the range of observed values.

2. **Joshi et al. (2024, 2025)** — the Delft MDAO framework models wing area, aspect ratio, wing loading, and tether stress as independent design variables. They find that specific power (kW/m² of wing area) *increases* with rated power for LCoE-optimized systems (from 5 kW/m² at 100 kW to 12.5 kW/m² at 2000 kW), which contradicts the simple v ∝ A^(1/4) power density argument. This is because larger systems are designed with higher wing loading (Table 10, Joshi et al. 2025).

3. **Loyd (1980)** — the foundational crosswind power equation P = (2/27)·ρ·A·(C_L³/C_D²)·V³ shows power ∝ A (not A^(5/4)). The power harvesting factor ζ is independent of scale to first order, depending only on aerodynamic efficiency.

**Verdict**: The mathematical chain is internally consistent given the assumption m ∝ A^(3/2), but the literature shows that optimal AWE design *does not hold wing loading constant* across scales — larger systems are designed with higher wing loading, partially defeating the velocity reduction predicted by pure geometric scaling.

---

## Claim 2: PE ∝ A², KE ∝ A², AE ∝ A^(5/4)

### Assessment: CORRECT DERIVATION GIVEN THE ASSUMPTIONS, BUT AE SCALING IS CONTESTED

**Derivation logic:**
- PE = mgh ∝ A^(3/2) · A^(1/2) = A² (assuming h ∝ A^(1/2)) ✓
- KE = (1/2)mv² ∝ A^(3/2) · A^(1/2) = A² (assuming v ∝ A^(1/4)) ✓
- AE (aerodynamic power) ∝ A^(5/4) — this is a non-standard claim vs. Loyd's P ∝ A

**Literature evidence:**

1. **Loyd (1980) crosswind power**: P = (2/27)·ρ·A·(C_L³/C_D²)·V³ → P ∝ A (linear). Loyd explicitly argues that crosswind kites "should scale nicely to machines much larger than windmills" (Loyd 2010 AWEC presentation).

2. **Joshi et al. (2025)**: Their actual LCoE-optimized results show wing-area specific power INCREASING with rated power (5→12.5 kW/m² from 100→2000 kW). The power-harvesting factor ζ shows "diminishing marginal gain" with increasing wing area (Figure 19), but it does NOT go negative. Capacity factor decreases monotonically (from ~0.55 at 100 kW to ~0.30 at 2000 kW) but never reaches zero.

3. **Sommerfeld et al. (2022)**: Heavier systems have higher rated wind speeds (10→15 m/s for κ=2.7→3.3), meaning they need stronger winds to achieve rated power. This reduces capacity factor but does not make the system a net consumer.

**Critical nuance**: The video frames AE ∝ A^(5/4) as a fundamental physical law, but the actual Loyd formula gives P ∝ A with a proportionality constant that depends on C_L³/C_D². What the video calls "AE ∝ A^(5/4)" appears to incorporate a degradation factor from structural mass growth. This is better understood through Sommerfeld's mass-scaling exponent κ framework: if mass grows as m ∝ A^(κ/2) where κ > 3, then gravity losses increase faster than aerodynamic forces, reducing net power. But this is a *design-dependent* outcome, not a physical law.

**Verdict**: The video's PE/KE derivations are mathematically sound given their assumptions. The AE ∝ A^(5/4) claim is an empirical approximation that captures structural mass penalties. However, the literature shows this is a design challenge, not a fundamental thermodynamic limit — it can be mitigated through high-L/D aerodynamics, lower structural mass fraction, and higher wing loading at larger scales.

---

## Claim 3: Soft kites follow m ∝ A^(3/2) (cube-square) but rigid FLYGEN kites scale worse

### Assessment: STRONGLY SUPPORTED BY PUBLISHED DATA

**Soft kite evidence:**

1. **SkySails verification**: The video's calculation — 30 m²/8 kg → predicted 180 m²: 8·(180/30)^(3/2) = 8·14.7 = 117.6 kg — matches the video's claim of ~118 kg predicted, ~120 kg actual. SkySails' website confirms their systems use kites "of up to 180 m² wind surface area." The soft kite mass follows near-cube-square because fabric mass dominates: surface area ∝ A (fabric area), and the structural framework scales with span ∝ A^(1/2), giving overall m ∝ A^(3/2) for tension-dominated soft structures.

2. **Diehl (2013) and others**: Soft-wing pumping systems show favorable mass scaling because the wing is primarily a tension structure (fabric + bridle lines) with minimal bending stiffness requirements.

**Rigid kite evidence (CRITICAL — directly contradicts soft kite scaling):**

1. **Makani M30 → M600 (actual built data)**: 
   - M30: wing area ~4 m², mass ~60 kg
   - M600 (as-built): wing area = 32.9 m², mass = 1,730.8 kg (Sommerfeld et al. 2022, citing Echeverri et al. 2020 — the Makani Energy Kite report)
   - Cube-square prediction: 60·(32.9/4)^(3/2) = 60·23.7 = 1,422 kg
   - Actual mass: 1,730.8 kg → κ = 3.23 (Sommerfeld et al. 2022, §3.4) ✓ **CONFIRMS the video's claim**: rigid kite mass scaling is *worse* than cube-square
   - M600 design mass was 919 kg, but built mass was 1,730.8 kg — nearly double!

2. **Makani MX2 (next-gen design)**: 54 m² / 1,852 kg → κ = 2.719 relative to AP2 reference, better than M600 but still significantly heavier than soft kites.

3. **Sommerfeld et al. (2022), Figure 3**: Published AWES aircraft masses span κ = 2.2–2.6 (square markers = estimated designs, circle markers = built prototypes). Makani's built M600 (κ = 3.23) falls above this range, confirming negative scaling effects for rigid flygen kites.

4. **Joshi et al. (2025)** mass model: Non-linear data-driven model based on Ampyx Power 20 kW, 150 kW prototypes, and MW-scale design projections. Mass increases with wing area, aspect ratio, and wing loading, with super-linear scaling at large sizes.

**Physics reason for worse rigid scaling**: Rigid wings carry bending moments that scale with span⁴ for a given load distribution. To maintain stiffness-to-weight ratio, wall thickness must increase faster than geometrically. Flygen systems also carry onboard generators, power electronics, and propellers, adding fixed mass overheads that don't scale with wing area.

**Verdict**: Strongly supported. The soft kite cube-square scaling is verified by SkySails data. The rigid kite worse-than-cube-square scaling is verified by Makani's own published technical data (M600 built mass 1,730.8 kg vs. 1,422 kg cube-square prediction). This is one of the most robust findings from the literature.

---

## Claim 4: AWE scale-up inevitably leads to negative capacity factor

### Assessment: QUALIFIED PARTIAL SUPPORT — capacity factor DECLINES but does not go NEGATIVE

**Literature evidence:**

1. **Joshi et al. (2025) — strongest counterevidence against "inevitable":**
   - Capacity factor decreases monotonically from ~0.55 (100 kW) to ~0.30 (2000 kW) in the reference scenario (Figure 17)
   - LCoE minimum at 500 kW, increases for larger systems
   - BUT: even at 2000 kW, capacity factor is ~30% — still positive and commercially viable
   - Sensitivity analysis: with 50% mass reduction, flatter LCoE curve, suggesting technological improvements could push optimum higher
   - Conclusion: "the optimum system size with the minimum LCoE is still 500 kW in all scenarios" but "the optimum might shift towards larger power ratings with extreme technological improvements, such as mass reduction ≥50%"

2. **Sommerfeld et al. (2022)**:
   - Rated power ranges from 145–199 kW (10 m²) to 2000–3400 kW (150 m²)
   - Heaviest mass scaling (κ = 3.3) requires wind speeds of ~15 m/s for rated power vs. ~10 m/s for lightest
   - Annual energy production *increases* with wing area for all mass scalings — it just increases sub-linearly
   - Specific power (kW per m² wing area) decreases at heavier mass scalings but remains positive

3. **What the literature does NOT show**: No peer-reviewed study finds that AWE systems become "net power consumers" at utility scale. The Joshi et al. and Sommerfeld et al. studies all find that larger systems produce more total energy, just with lower efficiency (capacity factor). The cost of energy increases but energy production remains positive.

4. **What the literature DOES show**: AWE systems face a "kite mass penalty" — part of the aerodynamic force must counter gravity instead of generating power. This penalty grows with size, reducing capacity factor. But the Joshi et al. sensitivity analysis shows this can be mitigated through (a) mass reduction via better materials/manufacturing, (b) higher wing loading at larger scales, (c) improved aerodynamics, and (d) farm-level effects not captured in single-system studies.

**Verdict**: The video's claim that AWE scale-up "inevitably" leads to negative capacity factor is NOT supported by the literature. The literature shows capacity factor *declines* with size (from ~55% to ~30% from 100→2000 kW) but remains positive. LCoE has a minimum at ~500 kW, driven by a combination of capacity factor decline and cost scaling, but does not go to infinity. The video's characterization as "inevitable" overstates the certainty — the Joshi et al. sensitivity analysis explicitly shows the optimum could shift to larger sizes with technological improvements.

---

## Overall Assessment Summary

| Claim | Validity | Strength of Evidence |
|-------|----------|---------------------|
| Wing loading ∝ A^(1/2) → v ∝ A^(1/4) chain | Mathematically sound givens m ∝ A^(3/2), but design optimization changes wing loading with scale | Medium |
| PE ∝ A², KE ∝ A², AE ∝ A^(5/4) | PE/KE correct for m∝A^(3/2); AE exponent is empirical, not fundamental (Loyd gives P∝A) | Mixed |
| Soft kites m∝A^(3/2) — verified | **Strongly supported** — SkySails data confirms (30m²/8kg → 180m²/120kg) | **High** |
| Rigid flygen kites scale worse than cube-square | **Strongly supported** — Makani M600 κ=3.23 vs. cube-square prediction, confirmed by Sommerfeld et al. 2022 | **High** |
| AWE scale-up → negative capacity factor | **Partially supported** — CF declines but remains positive (~30% at 2000 kW); LCoE minimum at ~500 kW but not "inevitable" | Medium |

## Key Literature Sources

1. **Loyd, M.L.** (1980). "Crosswind Kite Power." *Journal of Energy*, 4(3), 106–111. — Foundational crosswind power derivation: P ∝ A.

2. **Sommerfeld, M., Dörenkämper, M., De Schutter, J., & Crawford, C.** (2022). "Scaling effects of fixed-wing ground-generation airborne wind energy systems." *Wind Energy Science*, 7, 1847–1868. — Mass scaling exponents κ=2.7–3.3; Makani M600 κ=3.23; published AWES κ=2.2–2.6.

3. **Joshi, R., von Terzi, D., & Schmehl, R.** (2025). "System design and scaling trends in airborne wind energy demonstrated for a ground-generation concept." *Wind Energy Science*, 10, 695–718. — LCoE minimum at 500 kW; capacity factor declines 55%→30% (100→2000 kW); no benefit to upscaling beyond MW-scale.

4. **Echeverri, P., Fricke, T., Homsy, G., & Tucker, N.** (2020). *The Energy Kite: Selected Results From the Design, Development and Testing of Makani's Airborne Wind Turbines, Part I.* — Makani M600 built mass: 1,730.8 kg at 32.9 m² wing area; design mass was 919 kg.

5. **Joshi, R., Schmehl, R., & Kruijff, M.** (2024). "Power curve modelling and scaling of fixed-wing ground-generation airborne wind energy systems." *Wind Energy Science*, 9, 2195–2215. — Non-linear kite mass model based on wing area, aspect ratio, and wing loading.

6. **Diehl, M.** (2013). "Airborne Wind Energy: Basic Concepts and Physical Foundations." In: Ahrens, U., Diehl, M., Schmehl, R. (eds) *Airborne Wind Energy*. — Power harvesting factor ζ derivation; Loyd crosswind formula framework.

---

## Caveats

- The YouTube video could not be directly transcribed (YouTube consent wall), so claims were assessed as described in the task brief
- The video's conclusions about "inevitable" negative capacity factor are not supported by current literature but the *direction* of the scaling problem (declining capacity factor, increasing structural mass fraction at scale) is real and well-documented
- Farm-level effects (wake, cabling, area constraints) are acknowledged by Joshi et al. as potentially shifting the optimum toward larger individual systems, which single-system studies miss
- The Tulloch thesis (2021) focuses on rotary TRPT systems (Windswept's Daisy Kite), which is a different AWE concept from the soft kite and rigid flygen systems the video primarily discusses
