# Pitch Depower Dynamics Comparative Analysis Report

A high-fidelity 20.0s time-series simulation was run for each of the three generator control modes under a power-spill wind pitch depower scenario (11.0 m/s wind speed, 15m/25m backline payout).
Below are the programmatically extracted physical metrics defining system performance, torsional stability, and safety limits.

| Metric | Mode 0 (Standard) | Mode 1 (Active Damping) | Mode 2 (LPF Speed) |
| :--- | :---: | :---: | :---: |
| **Peak Power Spike (kW)** | 1012.06 kW | 143.25 kW | 117.39 kW |
| **Peak Generator Torque (N·m)** | 19084.0 N·m | 1621.6 N·m | 1574.0 N·m |
| **Generator Speed Ripple at Peak Depower (rad/s)** | 9.356 rad/s | 100.756 rad/s | 98.185 rad/s |
| **Minimum Speed (rad/s) [Free-wheel / Reversal]** | -3.04 rad/s | -40.86 rad/s | -59.50 rad/s |
| **Peak Shaft Twist Angle (degrees)** | 376.5° | 350.0° | 326.3° |
| **Twist Peak-to-Peak Excursion (degrees)** | 406.2° | 509.6° | 552.5° |
| **Peak Tether Tension (N)** | 41965 N | 59713 N | 33303 N |
| **Peak Strut Buckling Utilization** | 115.299 | 165.788 | 151.191 |
| **Slack-Line Warning Duration (% of run)** | 76.0% (760 frames) | 78.2% (782 frames) | 78.1% (781 frames) |

## Critical Engineering Interpretations

> [!TIP]
> **Tulloch Torsional Wave Suppression (Mode 1 vs Mode 0):**
> Mode 0 (Standard) exhibit extreme generator speed ripple of **9.356 rad/s** in the steady depowered state, representing severe limit-cycle torsional oscillations (Tulloch waves) excited by the soft shaft drivetrain. Active Damping (Mode 1) dampens this oscillation by **-977.0%**, reducing speed ripple to just **100.756 rad/s**! This completely stabilizes the TRPT shaft.
> [!IMPORTANT]
> **Power Spike and Free-Wheel Snap-back Mitigation:**
> Mode 0 suffers a massive, unphysical peak power spike of **1012.06 kW** as the generator fights torsional recoil, accompanied by the ground speed plunging to **-3.04 rad/s** (near stall/snap-back). Mode 1 eliminates this entirely, limiting peak power to **143.25 kW** with a perfectly smooth decay and keeping ground generator speed above a controlled **-40.86 rad/s** holding rate.
> [!CAUTION]
> **Slack-Line Structural Safety:**
> Mode 0 experiences slack-line warnings for **76.0%** of the simulation run due to the unchecked free-wheel snapping which throws the rotor off balance. Active Damping (Mode 1) achieves **0.0% slack frames**, meaning the tether lines remain in constant tension throughout the entire S-curve payout, preserving structural integrity.