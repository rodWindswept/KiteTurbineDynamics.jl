# PRD: Pitch Depower Control & Campaign V2

## 1. Executive Summary & Objective

The Pitch Depower V1 Campaign swept 768 configurations and revealed critical mechatronic dynamics:
1. **The Decoupling Paradox:** Tether slack drops TRPT torsional stiffness ($GJ \propto T$) to zero, decoupling generator active damping from the flying rotor and inducing violent limit cycles.
2. **MPPT Stall is Dangerous:** Ramping $k_{\text{mppt}}$ up to 9× to stall the rotor increases RMS torque jerk by **3.7×**, making transitions extremely rough.
3. **LPF Damping mode (Mode 2) is highly superior** to Active Torsional Damping (Mode 1) for transition smoothness.
4. **The `lifter_elevation` field in `SystemParams` is a dead parameter** that does not affect the dynamic lift-kite aerodynamics.

To prepare for a high-fidelity commercial sizing campaign, **Pitch Depower V2** requires four core physical pre-conditions to be resolved in the simulator codebase first. Once resolved, the sweep grid will be expanded to include wind speed and use phase-aware metrics.

---

## 2. Drivetrain & Damping Pre-conditions (V2 Pre-requisites)

To ensure the physical realism of the simulation, the following four code modifications must be implemented in the `src/` directory prior to running the V2 campaign:

### 2a. Ground Station Freewheel (No Generator Reversal)
*   **Current Issue:** During backline payout and rotor deceleration, the ground ring angular velocity (`omega_gnd`) occasionally swings negative due to torsional recoil from the unwinding tethers. The standard generator controller lets the generator pull negative torque, physically motorising the TRPT backward.
*   **V2 Requirement:** Modify the generator load law in [src/ring_forces.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/ring_forces.jl) to restrict the generator to a one-way freewheel mechanism:
    $$\tau_{\text{gen}} \ge 0.0 \quad \text{when} \quad \omega_{\text{gnd}} \ge 0.0$$
    The generator must never motorise the shaft backward; if the shaft rebounds, the generator torque must drop to exactly zero, allowing it to freewheel.

### 2b. Decouple Mechanical Brake from Field IMU
*   **Current Issue:** The mechanical brake trigger and tanh constraint in [src/ring_forces.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/ring_forces.jl) are nested inside the Field IMU block:
    ```julia
    if p.kp_elev ≈ 1.0
        if sys.brake_engaged[] || abs(omega_hub) < 1.0
            ...
    ```
    This couples the brake to the active damping flag. If Field IMU is turned OFF, the brake can never engage, creating a severe safety risk in high wind.
*   **V2 Requirement:** Extract the mechanical brake logic so it is completely independent of the Field IMU (`kp_elev`). The brake must monitor the flying rotor hub speed (`omega_hub`) and latch when `omega_hub < 1.0` rad/s, regardless of the active damping setting:
    ```julia
    if sys.brake_engaged[] || abs(omega_hub) < 1.0
        sys.brake_engaged[] = true
        ...
    ```

### 2c. Generator Torque Hard-Cap (3× Rated Torque)
*   **Current Issue:** Drivetrain torque spikes during transient limit cycles occasionally exceed 150,000 N·m in the worst runs, which is physically impossible and would shear the tethers instantly. The current safety clamp uses a scaling law based on rated power but is not strictly bounded.
*   **V2 Requirement:** Implement a strict safety clamp in [src/ring_forces.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/ring_forces.jl) that caps the generator torque at exactly **3× rated torque** ($\tau_{\text{rated}} = P_{\text{rated}} / \omega_{\text{rated}}$) to protect the Dyneema ropes from electromagnetic torque shocks:
    $$\tau_{\text{max\_safe}} = 3.0 \times \frac{P_{\text{rated}}}{\omega_{\text{rated}}}$$
    $$\tau_{\text{gen}} = \text{clamp}(\tau_{\text{gen}}, -\tau_{\text{max\_safe}}, \tau_{\text{max\_safe}})$$

### 2d. Activate `lifter_elevation` as a Live Parameter
*   **Current Issue:** The sweep parameter `lifter_elevation` was copied into `SystemParams` but never read in the forces solver, producing identical outputs across all elevation angles.
*   **V2 Requirement:** Modify `lift_force_steady(dev::RotaryLifterParams, rho, v_wind)` in [src/lift_kite.jl](file:///home/rod/Documents/GitHub/KiteTurbineDynamics.jl/src/lift_kite.jl) to read `p.lifter_elevation` from the system parameters and use it to scale or set the steady-state elevation of the sky anchor, making it a live, physical tuning parameter in the multi-body balance.

---

## 3. V2 Grid Expansion & Parameter Axes

The V2 campaign will expand the sweep grid to capture atmospheric variability and dynamic constraints:

### 3a. New Sweep Axes
1.  **Wind Speed (Missing Variable):** `[6.0, 11.0, 15.0, 20.0]` m/s. This is critical: depower controls optimized for 11 m/s (rated) can fail catastrophically at 20 m/s (storm shutdown) due to high aerodynamic torque.
2.  **Duration:** `[20.0, 30.0, 45.0, 60.0]` s (drop the jerky 10s runs, add a 60s option).
3.  **Active Winch Damping:** `[false, true]`.
4.  **Damping Mode:** `[0 (MPPT), 2 (LPF Speed)]` (drop Mode 1 since LPF proved superior).
5.  **Payout Base:** `[12.0, 15.0, 20.0]` m (tune narrower geometries).
6.  **Lifter Elevation (Live):** `[70.0, 80.0, 90.0]`° (physical sky anchor angles).

---

## 4. Phase-Aware Evaluation & Disqualification Metrics

In V1, runs with physically impossible states (such as a total collapse or sky anchor line tension going negative) were heavily penalized in the composite score. In V2, we will use **Phase-Aware Disqualification** to immediately disqualify runs that exceed physical safety limits:

1.  **Sky Anchor Tension Disqualification:** Any run where the sky anchor tension ($T_{\text{cyan}}$) drops below **$50\text{ N}$** (indicating complete loss of lift support and rotor sag) must be **disqualified** rather than penalized.
2.  **Torsional Collapse Disqualification:** Any run where adjacent rings twist beyond **$0.95\pi$** rad (approaching the Tulloch collapse limit where tethers cross) must be immediately flagged as **infeasible/disqualified**.
3.  **CFRP Buckling Disqualification:** Any run where the Euler buckling FoS of any spacer ring beam drops below **$1.5$** must be disqualified.
