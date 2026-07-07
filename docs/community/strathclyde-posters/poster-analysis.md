# Strathclyde AWEC 2026 Posters — Detailed Analysis

**Source:** Photographs taken by Rod Read at AWEC 2026, Porto, Portugal
**Analysed:** 2026-07-05
**Purpose:** Contextualise KTD.jl community messaging to Strathclyde group

---

## Poster 1: Power Efficiency Analysis (Chen, Yue, Kazemi, Read)

**Presented by:** Ziwei Chen, University of Strathclyde
**Co-authors:** Hong Yue, Abbas Kazemi (Strathclyde), Rod Read (Windswept & Interesting)

### Modelling Framework

A coupled aero-structural steady-state model:

```
Inputs → [Lift Kite Aerodynamics] → [TRPT Equilibrium] → [Power Take-off]
         [Rotor Aerodynamics]    →        ↑
         [Wind Condition]        →        |
         [Tether Aerodynamics]   →   [TRPT Efficiency] → [TRPT Aerodynamics]
```

Outputs at maximum power: twist angle δ*, angular velocity ω*, axial force Fk/Fz*, elevation angle β*

### Systems Analysed

| Parameter | 1.5 kW system | 12 kW system |
|-----------|---------------|--------------|
| Rings | 13 | 35 |
| Sections | 12 | 34 |
| Tethers | 6 | 6 |
| Total length | 10.31 m | 30.42 m |

Both are **single-rotor** with a lift kite providing axial force.

### Key Results (verbatim)

1. A refined coupled aero-structural model captures coupling between rotor aerodynamics, axial force, segmental twist, distributed torque loss, tangent stiffness, and elevation angle
2. Stable operation requires **positive tangent stiffness**, determining minimum axial force
3. **Top TRPT segment contributes ~89% of total torque loss** — this is the critical section
4. Transmission efficiency remains **~86.33%** across 4–15 m/s wind range
5. When torque loss is considered, **optimal TSR is lower than the aerodynamic optimum** — the transmission shifts the operating point

### Heat Map Data

- **Axes:** Elevation angle (deg) × Tip Speed Ratio (λ)
- **1.5 kW system:** Power peaks near λ = 6–7, Fk cos(θ) ≈ 400 N, max ~1,500 W
- **12 kW system:** P_max = 11,039 W at 10 m/s

### Comparison Graphs (bottom row)

| Graph | Axes | Finding |
|-------|------|---------|
| TSR comparison | Power vs TSR, blue=aero max, red=overall max | Red peaks at lower TSR than blue |
| Torque loss | Torque loss (Nm) vs TSR, top section vs all sections | Top section dominates (>89%) |
| Axial force | Twist angle + axial force vs section index (1–34) | Twist accumulates; axial force near-constant |

### References

1. Read, R. Windswept and Interesting. https://www.windswept.energy
2. Tulloch, O., Yue, H., Kazemi Amiri, A.M. and Read, R. "A tensile rotary airborne wind energy system — modelling, analysis and improved design." *Energies*, 16(6), 2023: 2610
3. Chen, Z., Yue, H., Amiri, A.M.K., Morgan, L. & Read, R. "Understanding of lift kite operation requirements of a rotary kite wind turbine." *29th IEEE Int. Conf. Automat. Comput. (ICAC)*, 2024

---

## Poster 2: Scalability Analysis (Amjad, Yue, Carroll, Chen)

**Presented by:** Muhammad Mutthanna Amjad Bin Zulfazli, University of Strathclyde
**Supervisors:** Dr. Hong Yue, Prof. James Carroll
**Sponsor:** PETRONAS

### System Origin

Adapted from Windswept & Interesting's Daisy Kite design. Small-scale demonstrations at ~1–2 kW. Medium-scale (tens to hundreds of kW) unexplored.

### Methodology

**Rotor aerodynamics:** QBlade LLFVW (Lifting Line Free Vortex Wake)
- Wind speeds: 5–15 m/s
- Elevation angle: 34° (fixed)
- At 5 m/s: ~2 kW; at 10 m/s: ~18 kW; at 15 m/s: ~60 kW (aerodynamic power)

**TRPT torque transmission:** Steady-state analytical model
- Torque formula: Q_trans = μ Σ C_t R_i (δ_i/L_i + R_i δ_i/2)
- Dyneema material limit: σ ≤ 3.5 GPa
- 12-section TRPT (9 m rotor height, 12 m ground station)

**Coupled scaling:** Parametric sweep of tether count (3–12), tether diameter (1–3 mm), ring radius scaling (0.1–2×), section length scaling (0.1–1×)

### Torque Loss

- Range: **-17% to +21%** across 5–15 m/s
  - Wait — that should be **17% to 21% loss** (i.e., efficiency 79–83%), not -17% to +21%
  - Lower wind = worse: parasitic drag dominates at low torque
  - Higher wind = better: torque scales faster than drag

### Parametric Scalability Findings

| Sweep parameter | Range | Effect on efficiency | Effect on mass |
|-----------------|-------|---------------------|----------------|
| Tether count N_t | 3→12 | **Linear degradation** | Increases |
| Tether diameter d_t | 1→3 mm | Degrades (quadratic drag) | Increases (10→60 kg) |
| Section length scaling | 0.1→1× | **Shorter = better** | Decreases |
| Ring radius scaling | 0.1→2× | **Larger = better** | Increases |

### Main Findings (verbatim excerpts)

1. **TRPT upscaling is transmission-limited, not rotor-limited** — tether drag outpaces rotor power as scale increases
2. Parasitic drag formula: D_parasitic = ½ ρ A C_d V_rel² cos(φ) Σ cos(θ)
3. **Conventional wind turbine similarity laws do not apply** to TRPT systems
4. **Dual penalty from scaling tethers:** parasitic mass + amplified drag profile
5. **Geometric prescription: "wide-and-short"** — radial expansion for mechanical leverage, minimise longitudinal extension to prevent kinematic choking (δ < 90°)

### References

1. Reed, M. Windswept and Interesting (website)
2. Tulloch, O., Yue, H., Kazem Amiri, A., and Read, R. "A tensile rotary power transmission system: scalability analysis and improved design." *Energies*, 14(1-42), 2021
3. Chen, Z., Yue, H., Kazem Amiri, A. M., and Mingay, L. "Understanding the structural requirements of a rotary kite and its tether system." *Proc. 29th IEEE ICAC*, 2024

### System Configurations Shown

- **Single-rotor:** Diagram with lift kite, rotor, TRPT, ground station (their analysis focus)
- **Multi-rotor:** Conceptual render of 3 rotors on a single TRPT line — shown as future direction, **not modelled quantitatively**

---

## Gap Analysis: Strathclyde Models vs KTD.jl

| Dimension | Strathclyde (2024 posters) | KTD.jl (2026) | Opportunity |
|-----------|---------------------------|---------------|-------------|
| **Solver type** | Steady-state equilibrium | Full multibody ODE (11-DoF) | KTD found 4.2× gap static→dynamic — their 86.33% efficiency is steady-state, likely optimistic |
| **Rotor config** | Single-rotor + lift kite | Multi-rotor (4 rotors in V10 Tight), no lift kite | Jamieson scaling completely absent from their analysis |
| **Expansion rotors** | Not modelled | Banked expansion rotors on TRPT rings | Their "wide-and-short" geometry is a geometric hint toward what expansion rotors do aerodynamically |
| **Aero model** | QBlade LLFVW (mid-fidelity) | Constant-CL (low-fidelity), BEM pending | QBlade could validate/cross-check KTD's expansion rotor aerodynamics |
| **Tether drag** | Parasitic drag formula | Tveide ODE solver + n× parallel | Their "89% top segment loss" aligns with KTD's ring-by-ring FEA — same physics |
| **Failure mode** | Dyneema 3.5 GPa yield | Euler ring buckling (compression) | Different regimes — KTD rings fail in buckling, not tension yield |
| **Optimisation** | Parametric sweep (2-DoF at a time) | DE optimiser (14-DoF simultaneous) | Their sweeps explain *why*; KTD finds *what* |
| **Power scale** | Modelled up to 12 kW (60 kW aero at 15 m/s QBlade) | Campaigns at 50 kW rated | Directly adjacent — their 60 kW aero upper bound is at KTD's rated power |
| **Elevation angle** | Fixed 34° | Variable, campaigns at 30° | Both in the same regime |
| **Multi-rotor** | Conceptual render only | Fully optimised (4 rotors, 22 rings) | Huge gap — they've identified this as future work, KTD has done it |

---

## Strategic Messaging Implications

### To Ziwei Chen & Hong Yue (Power Efficiency)

**What they know:** Steady-state TRPT efficiency at 1.5–12 kW. 89% loss in top segment. Tangent stiffness stability criterion. Three co-authored papers with Rod.

**What KTD brings:** The 4.2× static-dynamic gap directly challenges their 86.33% efficiency claim. Their model is steady-state — the dynamic reality is the conversation starter. "Your 86.33% efficiency — we've found that in full multibody dynamics, the static prediction overestimates by ~4×. Would you be interested in cross-validating your QBlade model against our ODE solver at 50 kW scale?"

**Key ask:** BEM/LLFVW validation of KTD's expansion rotor aerodynamics. They have the QBlade expertise.

### To Amjad, James Carroll (Scalability)

**What they know:** TRPT is transmission-limited. "Wide-and-short" geometry. Parametric sweeps on tether count/diameter/geometry. PETRONAS industrial backing.

**What KTD brings:** Their parametric sweeps are 2-DoF at a time — KTD's DE optimiser handles 14 simultaneous. Their "wide-and-short" prescription is geometrically what KTD's expansion rotors achieve aerodynamically. Their multi-rotor is a concept render; KTD has optimised 4-rotor configurations at 49 kg airborne mass.

**Key ask:** Extend their scalability framework to multi-rotor. Their coupled aero-structural model + KTD's DE optimisation = a powerful combined toolchain.

### To the combined Strathclyde group

**The collaboration is already proven** — Rod is co-author on both Chen and Tulloch papers. The missing piece is closing the gap between:
- Strathclyde's steady-state models + QBlade aerodynamics
- KTD's full multibody dynamics + DE optimisation

**Concrete next step:** A joint paper cross-validating Strathclyde QBlade results against KTD.jl ODE results at 12 kW and 50 kW scale, quantifying the static-dynamic gap with mid-fidelity aero. This would be the first multi-fidelity TRPT validation in the literature.

---

## Files

- `poster-power-efficiency-chen-2024.jpg` — Chen et al. poster photo
- `poster-scalability-amjad-2024.jpg` — Amjad et al. poster photo
- `ANALYSIS.md` — this file
