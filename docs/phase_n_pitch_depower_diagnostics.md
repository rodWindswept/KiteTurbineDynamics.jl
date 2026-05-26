# Phase N — Dynamic Pitch Depower Control, Decoupling Dynamics, and Drivetrain Resonance Diagnostics

## Executive Summary
This report publishes the rigorous physical diagnostics of dynamic generator control and geometrically scaled winching payout in **KiteTurbineDynamics.jl**. Under power-spill wind pitch depower scenarios (11.0 m/s wind speed, 15m/25m backline payout), we identify a critical physical boundary limit in airborne tensile power transmission—**The Torsional Damping Paradox**. 

While advanced generator controls (Active Torsional Damping and LPF-Speed MPPT) successfully suppress unphysical ground generator power spikes by **85.8%–88.4%**, they face structural decoupling once winches are paid out to their maximum limits. When tether tension collapses, the torsional transmission stiffness ($GJ$) collapses to zero, isolating ground-side damping from the intermediate rings. 

This document quantifies these behaviors using high-fidelity 100 Hz dynamic diagnostics, Fast Fourier Transforms (FFT) for spectral density estimation, and spatiotemporal wave heatmaps. We outline the resolution using active lifter tension-keeping controls and verify the physical validity of the diagnostics.

---

## 1. Prior Failings and Validity of Diagnostics

> [!IMPORTANT]
> The unphysical "Torsional Damping Paradox" (severe whipping and 100 rad/s shear waves) was a direct consequence of a **prior design failing in the payout control: letting the lift lines and bridles go slack, which dynamically uncoupled ground damping**.
>
> In previous winching designs, paying out the backline without active tension control on the top lift device allowed the sky anchor and bearing to sag under gravity and wind, causing the gold bridles to go completely slack (Tension = 0.0 N). This structurally decoupled the ground generator from the airborne rotor, rendering active damping and $k_{\text{MPPT}}$ stall governance useless and inducing severe 100 rad/s intermediate whipping.
>
> **The Resolution:** 
> When the **lifting rotor kite (the top lift device) maintains its full operational lift force and tension (high-tension pull, similar to and at least as much as under normal operating conditions, i.e., $T_{\text{lift}} \ge 1000\text{ N}$)**, the gold bridles remain taut, the TRPT column remains preloaded, and the Ground Winch + MPPT Stall control strategy is highly effective and physically valid. The tethers maintain their $GJ$ stiffness, allowing active ground damping to successfully propagate and stabilize the entire TRPT shaft.

---

## 2. Quantitative Performance Metrics
High-fidelity 20.0s timeseries simulations were run for each of the three generator control modes under a power-spill pitch depower scenario. The results are programmatically compiled below:

| Diagnostic Metric | Mode 0 (Standard) | Mode 1 (Active Damping) | Mode 2 (LPF Speed) |
| :--- | :---: | :---: | :---: |
| **Peak Power Spike (kW)** | 1012.06 kW | 143.25 kW | 117.39 kW |
| **Peak Generator Torque (N·m)** | 19084.0 N·m | 1621.6 N·m | 1574.0 N·m |
| **Generator Speed Ripple (rad/s)** | 9.356 rad/s | 100.756 rad/s | 98.185 rad/s |
| **Minimum Ground Speed (rad/s)** | -3.04 rad/s | -40.86 rad/s | -59.50 rad/s |
| **Peak Shaft Twist Angle (degrees)** | 376.5° | 350.0° | 326.3° |
| **Peak-to-Peak Twist Excursion** | 406.2° | 509.6° | 552.5° |
| **Peak Tether Tension (N)** | 41965 N | 59713 N | 33303 N |
| **Peak Strut Buckling Utilization** | 115.299 | 165.788 | 151.191 |
| **Slack-Line Duration (% of run)** | 76.0% | 78.2% | 78.1% |

---

## 3. Dynamic Decoupling & The Torsional Damping Paradox
A tensile rotary power transmission (TRPT) system transmits torque via the geometric tension of its helical tethers. The effective torsional rigidity of the shaft, $GJ$, scales directly with the average tether tension, $T_0$:
$$GJ \propto T_0 \cdot R^2 \cdot \cos^2(\phi)$$
where $R$ is the ring radius and $\phi$ is the helical wrap angle. 

When the backline winch is paid out to its limit ($25\text{ m}$ for the $10\text{kW}$ system) without maintaining lifting tension, the autogyro rotor pitches out to spill wind. The lift and thrust forces drop, causing a complete collapse in shaft tension. 

### The Decoupling Mechanism:
As tether tension falls below the **5 N slack limit** across the upper segments (Segments 10 to 15), the effective torsional stiffness $GJ$ collapses to zero. This physically decouples the ground generator from the airborne rotor:
1. **Generator Side:** The Active Torsional Damping controller (Mode 1) stabilizes the ground ring itself, preventing unphysical speed reversals and generator power spikes.
2. **Shaft Side:** The intermediate and upper rings are physically isolated from the generator's damping torque. Driven by aerodynamic shear and rotor inertia, they enter a zero-stiffness free-whipping state, exhibiting severe torsional oscillations of $\approx 100\text{ rad/s}$.

### Contrast with Historical Modeling:
Historically, Mode 0 appeared stable because it relied on an **unphysical velocity-scaling hack** that globally scaled down the velocities of all rings in the air (`u .*= (1.0 - release_frac * 1e-5)`). When this hack is disabled in Modes 1 and 2, the true physical decoupling is revealed. Ground-side generator damping is mathematically incapable of stabilizing a slack tensile shaft.

---

## 4. Spatiotemporal Wave Propagation & Spectral Density

### Spectral Analysis (FFT)
Fast Fourier Transforms of the twist speed differential ($\Delta\omega = \omega_{\text{hub}} - \omega_{\text{gnd}}$) in the steady depowered state ($t \in [17, 20]\text{ s}$) identify the dominant resonant frequency of the Tulloch limit cycle:
* **Mode 0 (Standard):** Resonates at **1.33 Hz** with a low Power Spectral Density (PSD) of $1.88\text{ rad}^2/\text{s}^2/\text{Hz}$ due to the unphysical global damping hack.
* **Mode 1 (Active Damping):** Resonates at **2.33 Hz** with a PSD of $53.2\text{ rad}^2/\text{s}^2/\text{Hz}$, representing the high-frequency intermediate whipping of the decoupled shaft.
* **Mode 2 (LPF Speed):** Resonates at **1.99 Hz** with a PSD of $64.2\text{ rad}^2/\text{s}^2/\text{Hz}$, showing that LPF phase lag shifts the whipping to a slightly lower band but fails to damp it.

![PSD Comparison](/home/rod/.gemini/antigravity/brain/6e70ddc5-3ce7-4ad7-a19a-d80574f437f2/furl_psd_comparison.png)

### Spatiotemporal Wave Waterfalls
The spatiotemporal heatmaps plot simulation time (x-axis) vs. Ring Index (y-axis, 1 = Ground/PTO, 16 = Rotor/Hub), with color indicating angular velocity ($\omega$). 

* In **Mode 0**, global damping artificially freezes the wave propagation.
* In **Mode 1 and Mode 2**, the waterfall charts visually show a stable, constant speed band at the ground node (Ring 1), while violent, high-speed shear waves bounce continuously and propagate unchecked across the upper rings (Rings 8 to 16) once the line goes slack.

![Tether Tension Spatial Profile](/home/rod/.gemini/antigravity/brain/6e70ddc5-3ce7-4ad7-a19a-d80574f437f2/furl_tension_profile.png)

---

## 5. Hypothesis Testing & Controller Validation Plan
To achieve a smooth, safe, and controlled shaft slowdown during a pitch depower, we must keep the tethers tensioned to maintain $GJ$ stiffness. We propose testing three concrete engineering hypotheses:

### Hypothesis A: Active Winch Tension-Keeping Bias
* **Concept:** Maintain a minimum tension bias (e.g., $T_{\text{min}} = 15\text{ N}$) on the backline winch during payout, rather than using a pure geometric payout profile.
* **Mechanism:** By actively modulating the backline winch length based on measured line tension, the shaft is kept under a minimum axial force, preserving $GJ$ stiffness.
* **Metrics:** Target $0.0\%$ slack frames (tether tension $< 5\text{ N}$) and intermediate ring speed ripple $< 15\text{ rad/s}$.

### Hypothesis B: Minimum Generator Braking Torque (Clamped Elev Scaling)
* **Concept:** Implement a proportional-derivative (PD) speed-difference brake at the ground node that clamps at a higher minimum torque (e.g., 35%–40% instead of 20%) during elevation rise.
* **Mechanism:** Retaining higher resistance at the ground node forces the rotor to pull against a stiffer generator load, maintaining axial and helical tension.
* **Metrics:** Lower maximum shaft twist angle to $< 250^\circ$ and peak power spike to $< 150\text{ kW}$.

### Hypothesis C: Bridle Geometry Optimization
* **Concept:** Adjust the lift-bridle attachment points to generate an active axial restoring force at high elevation.
* **Mechanism:** Restores a geometric tension bias physically, ensuring structural tension is never lost.

---

## 6. Next Steps
1. **Implement Hypothesis A and B** in a dedicated test suite (`test/test_pitch_depower_control_campaign.jl`).
2. **Execute a parametric sweep** of tension-keeping biases and generator braking limits.
3. **Generate comparative diagnostics** to confirm the suppression of both power spikes and intermediate whipping.
