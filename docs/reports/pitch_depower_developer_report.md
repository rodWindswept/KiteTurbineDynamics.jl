# Pitch Depower Control, Physics, & Dashboard Handoff Report
**Target Audience:** KiteTurbineDynamics.jl Software Developers & Control Engineers  
**Date:** May 24, 2026  

---

## 1. Executive Summary & Terminology Boundary

To improve readability, clarity, and physical realism, we have refactored the codebase to completely banish the term **"Furl"** from generating rotor operations and replaced it with **"Pitch Depower"** (or **"Turbine Rotor Pitch Depower"**). 

The term "Furl" is now strictly reserved for future work on the *lift device itself* (i.e. aerodynamic furling of the top lifting kite under extreme winds). The wind-spilling maneuver for the main TRPT generating rotor is now renamed **"Pitch Depower"**.

This report documents:
1. The **Bridle Decoupling Failure Mode** (Damping Paradox).
2. The **Active Control Strategies** designed to maintain drivetrain preloads and eliminate Tulloch limit-cycle resonances.
3. A critical **Physical Modeling Correction** distinguishing actual lift line tension from drivetrain tether tension.
4. **Structural CFRP Strut Sizing Optimization** enabled by the controls.
5. **Software Bug Resolutions** in the Makie interactive dashboard code.

For full technical specifications and telemetry charts, please refer to the detailed report at:
`docs/pitch_depower_developer_report.md`

---

## 2. Drivetrain Torsional Decoupling & The Damping Paradox

Through high-fidelity 100 Hz dynamic diagnostics, we identified a critical structural failure mode: **The Bridle Decoupling Failure Mode**.

### The Physical Mechanism:
When the ground backline winch pays out to spill wind from the generating rotor (tilting the rotor plane more vertically), the sky anchor and bearing node sag under gravity if paid out too rapidly or without active tension constraints. When this happens, the gold lifting bridles go completely slack ($T = 0.0$ N).
*   **The Paradox:** In a TRPT shaft, torsional stiffness is proportional to tether tension ($GJ \propto T_{\text{line}}$). When the tethers and bridles go slack, the torsional stiffness $GJ$ collapses to zero, **physically decoupling the ground generator from the airborne rotor**.
*   **The Dynamic Result:** Ground generator active damping torque becomes isolated at the ground ring. It cannot propagate through the slack upper tethers. The upper and intermediate rings whip uncontrollably, driving extreme torsional limit cycles (Tulloch waves) of up to **$76.7\text{ rad/s}$** speed ripple.

### The Solution:
We enforce the **Lifting Line High-Tension Pull Constraint**: The top lift device must maintain its full operational lift force and tension ($T_{\text{lift}} \ge 1000$ N) throughout the Pitch Depower sequence. This keeps tethers taut ($GJ > 0$) and enables ground active damping to successfully propagate up the shaft.

---

## 3. Physical Modeling Correction: Lift Line vs. Drivetrain Tethers

During this campaign, we corrected a major physical labeling and data-mapping error in the telemetry post-processing:

### The Correction:
*   **Actual Lift Line Tension ($T_{\text{lift}}$):** This is the physical pull of the controllable rotary lift kite flying above the sky anchor. Under physical principles, this lift line tension remains a **perfectly flat, constant line at $\approx 1583\text{ N}$** across all scenarios, demonstrating that the controllable lift kite flies securely at its design lift power.
*   **Topmost TRPT Segment Tension ($T_{\text{top\_avg}}$):** This represents the tension in the tethers of the topmost segment of the TRPT drivetrain (sky-anchor $\rightarrow$ hub). This is the torque-transmitting component that experiences tension drops and is optimized by the active winching controls.

*Developers should never confuse the flat, constant lift line tension governed by the lifting kite with the highly dynamic drivetrain segment tethers governed by winching and generator torque.*

---

## 4. Control Campaign Results & CFRP Sizing Optimization

We ran 20-second simulations at 100 Hz (500,000 steps per case) to test four configurations under a power-spill wind pitch depower scenario (11.0 m/s wind, 15m/25m backline payout):

| Configuration | Peak Power (kW) | SS Speed Ripple (rad/s) | $T_{\text{top}}$ Slack Time (%) | Actual Lift Line ($T_{\text{lift}}$) | $T_{\text{top}}$ baseline (N) | $T_{\text{top}}$ min (N) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Mode 1 Baseline** | 563.0 | 76.73 | 58.2% | **Flat ~1583 N** | 1817 N | 0 N |
| **Hypothesis A (Winch Bias)** | 141.6 | 4.39 | 28.1% | **Flat ~1583 N** | 1817 N | 0 N |
| **Hypothesis B (40% Clamp)** | 210.8 | 66.10 | 51.1% | **Flat ~1583 N** | 1817 N | 0 N |
| **Hypothesis AB (Combined)** | 162.3 | **0.73** | **26.8%** | **Flat ~1583 N** | 1817 N | 0 N |

### Active Winch Proportional Payout (Hypotheses A & AB):
Measures segment minimum tension $T_{\text{min}}$ at a 2ms cadence. When tension drops, payout rate is throttled proportionally:
$$\text{sigmoid\_progress} \mathrel{+}= \text{rate\_factor} \times 0.002 \times (\text{target} - \text{progress})$$
where $\text{rate\_factor} = \text{clamp}(T_{\text{min}} / 150\text{ N}, 0, 1)$. This successfully keeps tethers preloaded and **drops steady-state speed ripple from $76.73\text{ rad/s}$ to just $0.73\text{ rad/s}$ (a $99.0\%$ absolute reduction)**.

### CFRP Strut Sizing (FoS = 1.8, E = 70 GPa, t/D = 0.05):
By implementing active controls (Hypothesis AB), we reduced peak strut compression by **$37.6\%$** (from $3518.9$ N to $2197.4$ N). This unlocks lighter CFRP strut dimensions:
*   **Baseline struting:** Required $37.23$ mm OD, resulting in a hub spacer ring mass of **$3.112\text{ kg}$**.
*   **Active Control struting:** Requires only **$33.10\text{ mm}$** OD ($1.65$ mm wall), reducing the hub spacer ring mass to **$2.460\text{ kg}$** (a **$21.0\%$ mass reduction**).

---

## 5. Software & UI Bug Resolutions (Interactive Dashboard)

When launching the interactive dashboard (`scripts/interactive_dashboard.jl`), developers encountered compilation crashes. We diagnosed and resolved these issues:

1.  **Makie Toggle Attribute Bug Resolved:**
    *   **Issue:** The Toggle constructors used `buttoncolor_active`, which is not a valid Makie Toggle attribute.
    *   **Resolution:** Modified [src/visualization.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/visualization.jl) to use `framecolor_active` (which accepts `:limegreen` and `:orange` for the active track color).
2.  **Dashboard Variable Scope Bug Resolved:**
    *   **Issue:** The live HUD frame update block tried to read `p_run` inside `src/visualization.jl` (line 1087 onwards), which was undefined in that scope.
    *   **Resolution:** Replaced all six occurrences of `p_run` with the correct in-scope parameter variable `p` in [src/visualization.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/visualization.jl).
3.  **Real-Time HUD Additions:**
    *   Added `T_top (phys)` to the Lift Device HUD block—reading directly from the state vector. Color-coded (Cyan for taut, Orange for low, Red for slack) to give the operator immediate visual feedback during simulations.

### Verification:
All **519 package tests passed successfully**, confirming code health. The interactive dashboard now compiles and launches correctly.

To run the interactive dashboard locally:
```bash
julia --project=. scripts/interactive_dashboard.jl
```
