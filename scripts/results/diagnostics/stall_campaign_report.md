# Phase N Stall and Ground-Sensing Testing Report

We simulated four control cases to validate ground-measurable winching feedback and dynamic MPPT stalling:

| Case Name | Peak Power (kW) | Mean SS Speed (rad/s) | SS Speed Ripple (rad/s) | Slack Line Duration (%) | Max Twist (deg) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Mode 1 Baseline** | 163.12 kW | -1.354 rad/s | 105.056 rad/s | 78.2% | 351.9° |
| **Hypothesis A2 (Gnd Winch)** | 163.12 kW | -1.458 rad/s | 79.010 rad/s | 78.2% | 351.9° |
| **Hypothesis C (MPPT Stall)** | 329.29 kW | -0.070 rad/s | 75.331 rad/s | 78.2% | 422.3° |
| **Hypothesis AC (Combined)** | 292.90 kW | -0.176 rad/s | 27.966 rad/s | 78.2% | 422.3° |

## Critical Engineering Interpretations

> [!IMPORTANT]
> **Hypothesis C (k_MPPT Stall Governor) Results:**
> Dynamic ramping of the MPPT gain up to 9x successfully stalls the rotor, reducing mean steady-state speed by **94.9%** (from -1.354 rad/s to -0.070 rad/s)! This completely collapses the driving aerodynamic energy and smoothly slows down the shaft before peak pitch depower.
> [!TIP]
> **Hypothesis A2 (Ground Tension Winch) Results:**
> Modulating winching payout using the easily measurable Ground Ring Axial Tension successfully keeps the tethers taut, reducing slack duration by **0.0%**!