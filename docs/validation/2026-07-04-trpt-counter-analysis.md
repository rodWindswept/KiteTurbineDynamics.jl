# TRPT Counter-Analysis: Why the Video's Scaling Thesis Does Not Apply

**Status**: Rigorous companion to `scaling-claims-assessment.md`
**Date**: 2026-07-04 (revised 2026-07-04 with Dirk comparison and critical audit)
**Author**: Hermes Agent with Rod Read
**Context**: Response to "New Energy — Airborne Wind Energy" by think garage (YouTube, 12:37), which argues that AWE scale-up inevitably fails due to cube-square mass scaling and cyclic KE/PE losses.

**Critical audit note**: Every quantitative claim below has been re-examined with the same scrutiny applied to the video. Where data is simulation-only, unvalidated by hardware, or derived from a single design point, this is explicitly flagged. The Makani lesson — designed mass 919 kg, built mass 1,731 kg (Sommerfeld et al. 2022) — is the standard we must hold ourselves to.

---

## Executive Summary

The YouTube video by "think garage" presents a well-sourced critique of **single-kite cyclic airborne wind energy** (yo-yo and flygen architectures). Its best-supported claims — soft kite cube-square scaling, rigid flygen worse-than-cube-square scaling (Makani M600, κ = 3.23) — are confirmed by published literature (Sommerfeld et al. 2022, Joshi et al. 2025). However, the video's central theoretical argument (PE ∝ A², KE ∝ A², AE ∝ A^(5/4) → inevitable negative capacity factor at scale) is a **category error** when applied to the TRPT architecture, for reasons detailed below.

**Important scope limitation**: The TRPT (Tensile Rotary Power Transmission) is the power-generating subsystem — the rotating ring of rotors transmitting torque to ground via a tensile shaft. The **lift subsystem** (coaxial autogyro stack, modelled in CoaxialAutogyroStacking.jl) is a separate system that holds the TRPT aloft. The analysis below applies to the TRPT power subsystem; the lift subsystem has its own scaling characteristics that must be independently validated. The video's concerns about lift kite scaling may partially apply to the coaxial autogyro lifters and this remains an open verification item.

---

## 1. No Cyclic PE↔KE Exchange in the Power Subsystem

### The video's argument (transcript + on-screen):

> "The law of conservation of energy determines the effect of gravity on the loop in the form of the exchange of potential energy and kinetic energy. When reaching the maximum kite speed on the descent, the kite has to be slowed down by removing kinetic energy. This energy has to be paid back later on the climb."

### Why this does not apply to the TRPT power subsystem:

The TRPT rotors rotate continuously at approximately constant altitude. There is no climb/descent cycle, no PE↔KE exchange, and no "kinetic energy payback" phase.

| Feature | Single-Kite Cyclic (video's target) | TRPT Power Subsystem |
|---------|-------------------------------------|----------------------|
| Motion | Figure-8 or circular loops with climb/descent | Continuous rotation at constant altitude |
| PE↔KE exchange | Yes — central to the scaling argument | **No** |
| Power generation | Cyclic (reel-in/out or varying loop power) | Continuous (torque × ω through rotating shaft) |

**Caveat**: The **lift subsystem** (coaxial autogyro stack) is a separate set of rotating wings on a kite line. These autogyro rotors autorotate to generate lift, and may have their own cyclic dynamics. The video's lift kite scaling analysis may be relevant to this subsystem, which is modelled separately in CoaxialAutogyroStacking.jl and is not yet integrated with KTD.jl.

**Source**: KTD.jl `CONTEXT.md` §"Architecture", `DECISIONS.md` §2026-06-30. Tulloch PhD thesis (2021) — TRPT failure modes are torsional collapse (δα* criterion) and ring buckling, not cyclic energy exchange.

---

## 2. TRPT Mass Scaling: Multi-Rotor Advantage, Not "Beating Physics"

### The video's core scaling claim:

The video argues that all AWE systems follow cube-square mass scaling (m ∝ A^(3/2)), making larger systems increasingly heavy. The on-screen data verifies this for SkySails (soft kite) and shows Makani M600 at κ = 3.23 (worse than cube-square).

### The real TRPT efficiency mechanism: Jamieson multi-rotor scaling

The fundamental advantage is **not** that TRPT "beats cube-square" through exotic physics. It is Peter Jamieson's well-established principle: **splitting one large rotor into N smaller rotors of equal total swept area reduces structural mass.** For equal rotors (k=1), the mass ratio is 1/√3 ≈ 0.577 — a 42% mass saving. This is a geometric advantage of distributed load paths, not a violation of scaling laws.

The TRPT exploits this in two ways:
1. **Multiple rotors on one ring** (hub rotor + expansion rotors): Each ring's rotor generates P/N, so the thrust per ring is 1/N of a single-rotor design. Ring buckling load scales with accumulated thrust, which grows more slowly with multiple small rotors than with one large one.
2. **Multiple rings in the shaft**: The tensile shaft is a series of rings connected by tension lines. Each ring sees only the thrust from rotors downstream of it — the load is distributed along the shaft rather than concentrated at one point.

### TRPT mass scaling data (KTD.jl DE campaigns) — WITH CAVEATS:

| Design | Power | Mass | Notes |
|--------|-------|------|-------|
| V6.0 Canonical | 10 kW | 13.64 kg | Baseline. FoS ≥ 28 — massively over-designed for 10 kW |
| V8.0 (corrected drag) | 50 kW | 58.41 kg | 9 rings, 3 expansion rotors. 57/60 feasible |
| V9.0 (dynamic ω solve) | 50 kW | 44.52 kg | 8 rings, 9 expansion rotors. 59/60 feasible, 3 bounds at limit |
| V10 Tight | 50 kW | 49.20 kg | ⚠ **Dynamically dead.** k≈550 hits 50 kW but FoS=0.75. Progressive buckling over 60s |
| V10 (unified rotors) | 50 kW | 76.75 kg | 14 rings, 4 rotors. Structurally robust but not dynamically verified |

**Critical caveats on these numbers:**

1. **Simulation-only, zero hardware validation.** Every mass number above comes from the DE optimizer's structural model. The Makani M600 was designed at 919 kg and built at 1,731 kg — a factor of 1.88×. We have no basis to claim our mass model is more accurate than Makani's was.

2. **Static/dynamic mismatch (factor ~3.3×).** The DE optimizer uses a static equilibrium solver (`solve_equilibrium_self_consistent`) that under-predicts dynamic k_mppt by ~3.3× (DECISIONS.md §2026-06-28). This means the static optimizer evaluates designs at loads ~3× lower than what they'd experience in operation. The V10 Tight result — dynamically dead despite passing static constraints — is direct evidence of this gap.

3. **Two design points only (10 kW and 50 kW).** Computing a "scaling exponent" from two points is statistically meaningless. We cannot claim α ≈ 0.74–0.90 with confidence until we have design points at 100 kW, 250 kW, and 500 kW.

4. **Manufacturing constraints not modelled.** The DE optimizer can specify arbitrarily thin ring walls, arbitrarily small ring diameters, and idealized line terminations. Real hardware has minimum gauge thicknesses, bend radii, connector masses, and assembly tolerances.

5. **Dirk's 2023 analysis provides a reality check.** Dirk van Leersum's pre-KTD.jl TRPT scaling spreadsheet (`scaling table power vs lifter.xlsx`, Sept 2023) estimated 25.7 kg for a 12 kW TRPT (tubes + knuckles only, SF=3, 100 RPM). Scaling this to 50 kW by power ratio gives ~107 kg for TRPT structure alone — before adding blades, generator, or ground station. This is ~2× KTD.jl's full-system estimates. The discrepancy must be resolved before claiming any mass advantage.

**Source**: KTD.jl `CONTEXT.md` §"DE Campaigns", `DECISIONS.md` §§2026-06-28 and 2026-06-30. Dirk van Leersum, `scaling table power vs lifter.xlsx` (2023). Jamieson, P., personal communication — multi-rotor mass scaling derivation recorded in DECISIONS.md §Jamieson scaling law.

---

## 3. Shaft Drag vs Tether Drag — Qualitative Difference, Quantitative Unknown

### The video's claim:

> "The higher wind speeds are negated by more drag from the longer tether and power output remains the same."

### TRPT shaft drag is fundamentally different from crosswind tether drag:

| Property | Crosswind kite tether | TRPT rotating shaft |
|----------|----------------------|---------------------|
| Motion relative to wind | Translating at ~5–8× v_wind | Rotating about axis; apparent wind ~1× v_wind |
| Flow regime | Crossflow (cylinder normal to flow) | Mixed axial/tangential |
| Drag coefficient | Cd ≈ 1.0 (crossflow cylinder) | Cd ≪ 1.0 (axial flow) |

**Quantitative status: UNVALIDATED.** The <2% figure cited in earlier drafts was a first-order estimate using smooth-cylinder axial drag coefficients. The TRPT shaft is not a smooth cylinder — it has rings, lines, knuckles, and rotor attachments creating turbulent wake interactions. No CFD or experimental data exists for TRPT shaft drag. The TetherDragODESolver tool models translating tether drag only.

**What we can say with confidence**: TRPT shaft drag is qualitatively different from and likely lower than crosswind kite tether drag, because the shaft does not translate crosswind at high speed. The quantitative magnitude is unknown and should be treated as a research question, not a settled finding.

---

## 4. Power at All Wind Speeds — With Structural Caveats

### TRPT control map data (2026-06-30):

**Canonical 10 kW** (FoS ≥ 28 — massively over-designed):

| Wind speed | Power | FoS | Caveat |
|------------|-------|-----|--------|
| 5–15 m/s | Positive at all points | ≥ 28 | Not representative of commercial design |

**V10 Tight 50 kW** (structurally failed):

| Wind speed | Power | FoS | Status |
|------------|-------|-----|--------|
| 11 m/s | 172.7 kW (345%) | 2.30 | Passes at this point |
| 13 m/s | 185.1 kW (370%) | 1.64 | Marginal |
| 15 m/s | 178.6 kW (357%) | **1.36** | **Fails** — below hard floor of 1.5 |

**Reinforced V10 50 kW** (+30% bottom ring radii, 4 mm tether):

| Wind speed | Power | FoS | Status |
|------------|-------|-----|--------|
| 11 m/s | 159.5 kW (319%) | 1.97 | Structurally passes |
| 13 m/s | 125.5 kW (251%) | 2.25 | Structurally passes |
| 15 m/s | 110.9 kW (222%) | 7.18 | Structurally passes |

**What this actually shows:**

1. **Power is always positive** — the TRPT has no "net consumer" regime. This is the one claim we can make with high confidence.
2. **The canonical 10 kW is not representative** — its FoS ≥ 28 means it's a proof-of-concept, not an optimized design.
3. **V10 Tight failed structurally** — the design that passed static DE optimization could not survive dynamic operation.
4. **The reinforced V10 passes but is over-bladed** — producing 2–3× rated power. A properly sized 50 kW system (blades reduced until left-flank P ≤ P_rated) has not yet been tested.
5. **No control map exists for a blade-properly-sized 50 kW system.** We don't know whether a design simultaneously satisfying P ≥ 50 kW AND FoS ≥ 1.5 at all winds exists. This is the open question.

**Source**: KTD.jl `docs/reports/2026-06-30-control-map-findings.md`. Control map CSVs at `scripts/results/control_maps/`.

---

## 5. The Real Limiting Physics: Ring Buckling and Torsional Collapse

### The video's scaling chain (applies to crosswind kites):

> Wing loading ∝ A^(1/2) → Turn radius ∝ A^(1/2) → Height ∝ A^(1/2) → Velocity ∝ A^(1/4)

This is valid for crosswind kites where the wing must generate lift to support its own weight plus tether drag in cyclic flight.

### TRPT limiting physics:

1. **Ring buckling (FoS)**: Each ring is a thin-walled hoop under external compressive load from converging tension lines. The ground-end rings see the highest accumulated tension and have the smallest radius (shaft taper). Buckling is the binding constraint for left-flank operation (high thrust, low torque).

2. **Torsional collapse (Tulloch δα* criterion)**: The shaft transmits torque through twist in the helical line geometry. When inter-ring twist angle Δα approaches δα*, the lines lose geometric stiffness and collapse. This is the binding constraint for right-flank operation (high torque, low thrust).

3. **Lift subsystem scaling** (CoaxialAutogyroStacking.jl): The coaxial autogyro rotors that hold the TRPT aloft have their own scaling laws — blade solidity, autorotation RPM, and lift/drag characteristics that are modelled separately. This subsystem has NOT been integrated with KTD.jl and its scaling behaviour at 50 kW+ is unknown.

**Source**: KTD.jl `CONTEXT.md` §"Critical failure mode — torsional collapse", `DECISIONS.md` §2026-06-30. Tulloch PhD thesis (2021).

---

## 6. The Category Error: Single-Kite Cyclic AWE ≠ All AWE

The video critiques **single-kite cyclic AWE** (yo-yo and flygen) using mechanisms that are specific to those architectures. The TRPT has a fundamentally different power generation mechanism (continuous rotation, mechanical shaft transmission) and a separate lift mechanism (coaxial autogyro stack).

The video's analysis framework does not address:
- Multi-rotor load distribution (Jamieson scaling)
- Tensile shaft torque transmission (Tulloch TRPT mechanics)
- Continuous-rotation aerodynamics (no cyclic PE↔KE)
- Separate lift and power subsystems (different scaling laws for each)

The category error is not that the video is wrong about single-kite cyclic AWE — it's that it generalizes those specific failure modes to all airborne wind energy.

---

## 7. What the Video Gets Right — Applied to Ourselves

### Critical lesson 1: Simulation mass estimates are not built mass
Makani designed the M600 at 919 kg. They built it at 1,731 kg — factor of 1.88× (Sommerfeld et al. 2022). KTD.jl's DE optimizer produces mass estimates with zero hardware validation. Until we build and weigh TRPT hardware, all mass claims are provisional.

### Critical lesson 2: Static optimization misses dynamic physics
The V10 Tight design passed all static DE constraints but failed dynamically (FoS=0.75 at operating k_mppt). The static/dynamic k_mppt mismatch (3.3×) means the optimizer may be systematically under-predicting loads.

### Critical lesson 3: Small prototypes are not scaled commercial systems
The canonical 10 kW design (FoS ≥ 28, 13.64 kg) tells us almost nothing about 50 kW viability. The 10 kW system was designed for proof-of-concept, not as a scaled-down commercial unit.

### Critical lesson 4: Unvalidated models produce unvalidated conclusions
The shaft drag estimate (<2%), the mass scaling exponent (α ≈ 0.74–0.90 from two points), the capacity factor claim (all winds positive), and the lift subsystem integration are all based on simulation-only models. The video's critique of SkySails' measurement methodology (single reference wind speed at 200m) applies equally to our unvalidated wind models.

---

## 8. Conclusions — With Uncertainty Explicitly Stated

1. **The video's central mechanism (cyclic PE↔KE exchange) does not apply to the TRPT power subsystem.** Confidence: **High.** This is a qualitative architectural difference, not a quantitative claim.

2. **TRPT benefits from multi-rotor load distribution (Jamieson scaling).** This is a real physical advantage of arraying N smaller rotors rather than one large one. Confidence: **High** for the principle (well-established in wind turbine literature). **Low** for the quantitative magnitude at 50 kW+ scale (simulation-only, no hardware).

3. **TRPT shaft drag is qualitatively lower than crosswind tether drag.** Confidence: **Medium** for the qualitative claim. **None** for any quantitative estimate — no CFD or experimental data exists.

4. **TRPT produces positive power at all tested wind speeds.** Confidence: **High** for the canonical 10 kW and V10 designs tested. **Unknown** for a properly blade-sized 50 kW system — this has not been simulated.

5. **TRPT mass scaling claims (α ≈ 0.74–0.90, 50–71% below cube-square) are PROVISIONAL.** Derived from two simulation-only design points with a known static/dynamic mismatch. Must be validated against: (a) built hardware at any scale, (b) properly blade-sized 50 kW design, (c) designs at 100 kW and 250 kW for multi-point scaling verification, and (d) Dirk's 2023 analysis which suggests ~2× higher TRPT structure mass when manufacturing constraints are included.

6. **The video is a rigorous critique of single-kite cyclic AWE.** Its analytical framework does not address TRPT. But its methodological lessons — validate models against hardware, don't extrapolate from small prototypes, and verify measurement methodology — apply directly to KTD.jl development.

---

## References

1. **Sommerfeld, M., et al.** (2022). "Scaling effects of fixed-wing ground-generation airborne wind energy systems." *Wind Energy Science*, 7, 1847–1868.
2. **Joshi, R., et al.** (2025). "System design and scaling trends in airborne wind energy." *Wind Energy Science*, 10, 695–718.
3. **Echeverri, P., et al.** (2020). *The Energy Kite, Part I.* Makani Technologies.
4. **Loyd, M.L.** (1980). "Crosswind Kite Power." *Journal of Energy*, 4(3), 106–111.
5. **Tulloch, O.** (2021). *PhD Thesis: Structural Analysis of a Tensile Rotary Power Transmission.* University of Strathclyde.
6. **KTD.jl Project Room** — `CONTEXT.md`, `DECISIONS.md`, `docs/reports/2026-06-30-control-map-findings.md`.
7. **van Leersum, D.** (2023). `scaling table power vs lifter.xlsx`, `Windswept scaling charts.xlsx`. Windswept_Energy/10kW Design/MVP working folder/Dirk/.
8. **Jamieson, P.** — Multi-rotor mass scaling derivation. Recorded in KTD.jl DECISIONS.md §Jamieson scaling law.
9. **CoaxialAutogyroStacking.jl** — `~/Documents/GitHub/CoaxialAutogyroStacking.jl/`. Lift subsystem modelling.
