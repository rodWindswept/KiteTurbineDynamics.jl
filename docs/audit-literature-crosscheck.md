# Literature Cross-Check Audit — KiteTurbineDynamics.jl

Generated: 2026-06-08 | Source: Hermes cross-reference of code vs. AWE wiki & academic literature
Status: OPEN — issues requiring resolution, confirmation, or rework

---

## HIGH CONFIDENCE — Action Required

### 1. Two inconsistent BEM models in the same codebase
**Files:** `src/aerodynamics.jl`, `src/bem.jl`
**Severity:** Critical (inconsistent results depending on code path)

The simulator uses two different BEM models in different code paths:

- **ODE dynamics** (`aerodynamics.jl`): AeroDyn BEM lookup tables, NACA4412, 3-blade, Cp peak=0.232 at λ=4.1
- **Sizing/optimisation** (`bem.jl`): `cp_bem(n_lines) = (16/27) * (1 - exp(-n_lines/2)) * 0.85` — Prandtl tip-loss scaled Betz limit

The sizing module computes rotor radius from a Cp that can differ from the Cp the dynamics simulator actually uses. For n_lines=8: bem.jl gives Cp = 0.593 × 0.982 × 0.85 = 0.495 (way above any realistic value), while aerodynamics.jl gives Cp peak ≈ 0.232. This means the sizing significantly undersizes rotors relative to what the dynamics actually need.

**Academic basis:**
- Tulloch et al. (2022): experimentally validated Cp ≈ 0.15–0.18 for Daisy prototypes
- Pfister & Blondel (2020): numerical BEM + M&S inflow recommended as minimum fidelity
- The `bem.jl` model is a Betz-limit approximation with no blade geometry — it cannot capture real rotor performance

**Recommendation:** Replace `bem.jl` with the aerodynamics.jl lookup tables, or derive a Cp(n_lines) surface from AeroDyn sweeps across blade counts.

---

### 2. CT monotonically increasing — physically unusual for wind turbine rotors
**File:** `src/aerodynamics.jl:102-175`
**Severity:** High (may indicate invalid BEM extrapolation)

The CT lookup table rises monotonically from 0 at λ=0 to 0.782 at λ=8 and is clamped at that value. Standard wind turbine BEM shows CT peaking then declining at high TSR as the rotor enters the turbulent wake state or propeller brake state. A rotor that never reaches a CT maximum is physically questionable.

At λ=8 with CT=0.782, the rotor is in an extreme high-thrust regime. The Glauert high-thrust correction (Burton §3.6.3) typically limits CT to ~1.0 via the empirical CT1=1.816 relationship. The code's CT values approaching 0.8 at high λ may be physically valid for this specific rotor but need validation.

**Academic basis:**
- Burton Wind Energy Handbook §3.6.3: Glauert CT correction with CT1=1.816
- Pfister & Blondel (2020): closed-form BEM breaks down at TSR > 6 for α=90°
- The BEM table source (Rotor_TRTP_Sizing_Iteration2.xlsx) should be checked for high-λ validity

**Recommendation:** Validate CT(λ>6) against AeroDyn outputs with the high-thrust correction enabled. Consider adding Glauert correction or capping CT at physically-justified maxima.

---

### 3. cos²(elev) and cos³(elev) factors on thrust and power
**File:** `src/ring_forces.jl:121-132`
**Severity:** High (possible double-counting of elevation effects)

```julia
thrust_mag = 0.5 * rho * v² * A * ct_at_tsr(λ) * cos(elev)^2    # line 123
P_aero     = 0.5 * rho * v³ * A * cp_at_tsr(λ) * cos(elev)^3    # line 131
```

The AeroDyn BEM tables were generated at a fixed 20° elevation angle (per the aerodynamics.jl header). If the BEM simulations already include elevation effects in their CT/Cp outputs, then applying additional cos²/cos³ factors double-counts the elevation dependency. If the BEM was run with the rotor axis aligned to the wind (0° yaw), then the factors may be valid — but the header says "20° elevation angle."

Additional concern: the wind used in these calculations is `v_wind = wind_fn(hub_pos, t)` which is the 3D wind vector at the hub position. The magnitude `v_hub_mag = norm(v_wind)` includes all three components. If the wind vector has a vertical component, the elevation projection interacts with it in ways that may not be captured by simple cos(elev) scaling.

**Recommendation:** Verify whether the AeroDyn BEM tables already include elevation/yaw effects. If they do, remove the cos²/cos³ factors. If they don't, document the projection and validate against off-axis BEM runs.

---

## MEDIUM CONFIDENCE — Investigation Needed

### 4. PCA-2 data duplicated and same issues as CoaxialAutogyroStacking.jl
**File:** `src/lift_kite.jl:363-368`
**Severity:** Medium (same geometry-agnostic issues flagged in coaxial audit)

The `lift_force_steady` for `RotaryLifterParams` embeds a copy of the PCA-2 table rather than importing from `CoaxialAutogyroStacking.jl`. It inherits all the same issues: applied to arbitrary rotor geometry regardless of blade count, chord, or solidity.

Additional issues specific to this usage:
- `elevation_factor = clamp(CL_blade / 1.2, 0.25, 2.5)` scales CL linearly
- `cd_disk = cd0 * elevation_factor^2` — CD scales with CL² (induced drag approximation)
- The factor 1.2 as reference CL is uncalibrated against PCA-2 data
- The CD ∝ CL² scaling is a rough induced-drag heuristic

**Recommendation:** Import PCA-2 data from CoaxialAutogyroStacking.jl. Add validation of the elevation_factor scaling against the rotary lifter's actual blade geometry via BEM.

---

### 5. Cp ≈ 0.22 vs. Tulloch's experimentally validated Cp ≈ 0.15–0.18
**Severity:** Medium (47% higher than experimental)

The code uses AeroDyn BEM with NACA4412 giving Cp peak ≈ 0.232. Tulloch et al. (2022) optimised the Daisy prototype from Cp=0.15 to Cp=0.18 (see TRPT Modelling Framework table). The code's Cp is 29% above Tulloch's optimized value and 55% above the original value.

The code acknowledges: "strip theory not validated above n=6 lines." The NACA4412 is also a different airfoil from Tulloch's HQ Symphony Beach III 1.3 kite + NACA4412 foam blades.

**Academic basis:**
- Tulloch et al. (2022): Table shows original Cp=0.15, optimized Cp=0.18
- Pfister & Blondel (2020): closed-form BEM significantly overpredicts torque

**Recommendation:** Either validate the NACA4412 BEM tables against experimental data, or adopt Tulloch's measured Cp values with a calibrated correction factor.

---

### 6. Elevation angle fixed at 30° — literature suggests 18.5°
**File:** `src/parameters.jl`, `CONTEXT.md`
**Severity:** Medium (suboptimal operating point)

CONTEXT.md: "Elevation angle β fixed at 30°: not a design variable in v2–v5 campaigns. Cold-start and lift-kite analysis suggest optimum near β ≈ 26°. v6 should free β."

Tulloch et al. (2022) multi-parameter optimisation found **18.5°** as optimal steady-state elevation for a 190m TRPT at TSR=3.5. The 30° fixed value may be significantly suboptimal — higher elevation means more tether weight to support and different aerodynamic operating conditions.

**Recommendation:** Free β in the optimiser or validate the 30° choice against Tulloch's findings.

---

### 7. No cyclic/dynamic loading in structural sizing
**Severity:** Medium (known limitation)

All campaigns size against a peak static load envelope at 25 m/s. Cyclic 1P/2P tether tension, S-N fatigue, and dynamic torsional loading are not modelled. This is explicitly documented but represents a significant gap between the simulator and real operational loads.

**Academic basis:**
- Burton Wind Energy Handbook: 1P/2P loading from wind shear, tower shadow, yaw
- Tulloch (2021): TRPT dynamics with measured field data show significant cyclic loading
- Dyneema cyclic fatigue is the primary lifetime limiter for TRPT (per PORT concept page)

**Recommendation:** Add dynamic load cases to the sizing campaign. Implement rainflow counting + Miner's rule for fatigue life estimation.

---

### 8. Tether drag model: CD=1.0, no torsional deformation effects
**File:** `src/aerodynamics.jl:229-270`
**Severity:** Low-Medium

`tether_drag_force` uses CD=1.0 for Dyneema cylinders and computes drag perpendicular to the segment. This is better than CoaxialAutogyroStacking's model (uses correct crossflow component), but:
- Tulloch's improved model includes torsional deformation effects (11% vs 17% loss, 89% vs 83% efficiency)
- Tulloch found torsional deformation can be neglected for initial steady-state analysis with small error
- CD=1.0 is appropriate for Re~10³–10⁴ but Re varies along the TRPT

**Recommendation:** Current model is adequate for v1. Note Tulloch's 89% efficiency benchmark for validation.

---

## DISCUSSION POINTS — Design Decisions to Confirm

### 9. Rotary lifter omega_fixed departs from autorotation physics
**File:** `src/lift_kite.jl:140-143`

The rotary lifter uses `omega_fixed` — held constant by control, not computed from autorotation equilibrium. This is an intentional design choice to achieve tension insensitivity (ωr >> v means v_app nearly constant). However, it means the lifter is not autorotating in the physical sense — it's being driven to maintain constant RPM.

**Question for review:** Is the power required to maintain ω_fixed accounted for? If the lifter requires power input to maintain RPM, this should subtract from net system power.

---

### 10. Passive kite stall threshold at 2 m/s
**File:** `src/ring_forces.jl:215-220`

Hard-coded `PASSIVE_KITE_STALL_SPEED = 2.0`. Real parafoil kites have more complex low-wind behavior — they don't abruptly stall at a single wind speed. Wind gradient, kite size, and bridle geometry all affect the minimum flying wind speed.

**Recommendation:** Make stall speed a parameter on the kite struct rather than a hardcoded constant. Consider a smooth transition rather than a hard cutoff.

---

### 11. Generator MPPT: τ = k·ω² assumes rotor ω = ground ω
**File:** `src/ring_forces.jl:47-68`

The standard MPPT law uses ω_ground or ω_hub depending on control mode. During transients, rotor ω and ground ω can differ significantly due to TRPT torsional compliance (Tulloch measured first natural frequency ~0.75 Hz). The MPPT law using ground speed while the rotor is at a different speed can produce incorrect generator loading.

**Academic basis:**
- Tulloch et al. (2022): multi-spring dynamic model captures axial tension variation and torsional dynamics
- TRPT spring stiffness: geometric from tensioned tethers, not constant

**Recommendation:** Use rotor (hub) speed for MPPT reference. The current Modes 1/2 with IMU do this; Mode 0 (ground-only) may produce incorrect loading during transients.

---

### 12. Ring hoop Euler vs polygon segment buckling
**File:** `src/structural_safety.jl:4-7`

The code explicitly chooses polygon-segment Euler buckling over ring hoop Euler (P=3EI/R²), noting hoop Euler overestimates P_crit by 5–10×. This is an engineering judgment call — the academic validation is in `TRPT_Ring_Scalability_Report.docx` (not publicly reviewed).

**Recommendation:** Peer-review the polygon buckling model. The 5–10× difference from hoop Euler is large enough to warrant independent verification.

---

### 13. Open-centre rotor: two tips per blade — efficiency penalty not in BEM
**File:** `src/aerodynamics.jl`

Tulloch notes: "Open-centre rotor has two tips per blade — lower aerodynamic efficiency but material savings." The AeroDyn BEM tables may not account for the double-tip penalty of an open-centre rotor (hub void at 0.2R–0.4R). Standard Prandtl tip-loss models only model the outer tip.

**Academic basis:**
- Tulloch et al. (2022): blade inner start at 0.37R gives maximum Cp (balance of swept area vs double-tip penalty)
- Pfister & Blondel (2020): hub void 0.2R used in their model — tip vortex rolling dominates

**Recommendation:** Verify whether the AeroDyn BEM model includes the inner tip. If not, apply a double-tip-loss correction.

---

## SUMMARY TABLE

| # | Issue | Confidence | Severity | Action |
|---|-------|-----------|----------|--------|
| 1 | Two inconsistent BEM models | High | Critical | Unify |
| 2 | CT monotonically increasing | High | High | Validate/constrain |
| 3 | cos²/cos³ double-counting elevation | High | High | Verify |
| 4 | PCA-2 duplication + geometry issues | Medium | Medium | Import + validate |
| 5 | Cp 0.22 vs Tulloch 0.15–0.18 | Medium | Medium | Validate or calibrate |
| 6 | β=30° fixed vs Tulloch 18.5° optimum | Medium | Medium | Free β |
| 7 | No cyclic/fatigue loading | Medium | Medium | Add to sizing |
| 8 | Tether drag CD=1.0, no torsional effects | Low-Med | Low | Validate vs Tulloch |
| 9 | Rotary lifter not autorotating | Discussion | — | Confirm power budget |
| 10 | Hardcoded 2 m/s kite stall | Discussion | — | Parameterize |
| 11 | MPPT uses wrong ω during transients | Discussion | Medium | Use hub ω |
| 12 | Polygon vs hoop Euler 5–10× gap | Discussion | — | Peer review |
| 13 | Double-tip penalty missing from BEM | Discussion | Medium | Verify AeroDyn setup |

---

## References (from wiki)

- Tulloch et al. (2022): TRPT modelling framework — `concepts/trpt-modelling-framework-tulloch2022.md`
- Tulloch (2019): 2nd year review, δ_max < 180° proof — `entities/oliver-tulloch.md`
- Tulloch (2021): Rotary AWE PhD — `raw/papers/tulloch-rotary-awe-phd-2021.md`
- Pfister & Blondel (2020): BEM vs vortex for rotary AWE — `concepts/bem-vs-vortex-rotary-awe.md`
- Wacker (2022–2023): RAWES structural optimisation — `raw/papers/wacker-structural-optimisation-rawes-2022.md`
- PORT concept — `concepts/tensile-rotary-power-transmission.md`
- RotoKite momentum theory — `concepts/rotokite.md`
- Burton Wind Energy Handbook — `entities/burton-wind-energy-handbook.md`
- Dyneema material properties — `concepts/tether-material-properties.md`
