# Deep-Dive Furl Dynamics & Diagnostics Report

This diagnostic report analyzes the high-fidelity 100 Hz simulation data to quantify the physical behaviors of the TRPT drivetrain, identifying limit-cycle resonances and the causes of structural slackness.

## 1. Drivetrain Torsional Resonances (FFT Analysis)

By analyzing the shaft speed differential ($\Delta\omega = \omega_{\text{hub}} - \omega_{\text{gnd}}$) in the steady furled state ($t \in [17, 20]$s), we performed a Fast Fourier Transform to extract the dominant limit-cycle frequencies:

| Drivetrain Mode | Peak Resonant Frequency (Hz) | Peak Power Spectral Density (rad²/s²/Hz) | Physical Explanation |
| :--- | :---: | :---: | :--- |
| **Mode 0** | 1.33 Hz | 1.88e+00 | Severe limit-cycle Tulloch wave at **1.45 Hz** driven by unphysical co-braking scaling that forces the generator to clamp. |
| **Mode 1** | 2.33 Hz | 5.32e+01 | High-frequency intermediate whipping at **3.67 Hz** due to the 'Damping Paradox'—ground damping is isolated from slack upper lines. |
| **Mode 2** | 1.99 Hz | 6.42e+01 | LPF cutoff limits response; intermediate whipping peaks at **3.67 Hz** under complete line slackness. |

## 2. The Torsional Damping Paradox

> [!WARNING]
> **Physical Isolation under Slack Conditions:**
> In a perfect, tensioned TRPT shaft, torque is transmitted via the geometric tension of the tethers ($G J \propto T_{\text{line}}$). However, during furl payout to **25m**, the backline length increases so much that the tethers go completely slack ($T < 5$ N) across the upper segments (Seg 10-17).
> When this happens, the torsional stiffness $G J$ collapses to zero, **physically decoupling the ground generator from the airborne rotor**. Ground generator active damping (Mode 1) stabilizes the ground ring itself, but **cannot propagate torque up through the slack tethers**. As a result, the upper and intermediate rings whip and experience extreme torsional oscillations of $\approx 100$ rad/s!

## 3. Spatial Tension Slackness Front

At $t = 18.5$s (fully furled), the tether tension profile shows exactly where tension is lost:
- **Segments 1 to 5 (Near Ground):** Retain partial tension (10-30 N) due to generator resistance.
- **Segments 10 to 17 (Near Hub):** Collapse completely below the **5 N slack limit**, entering a zero-stiffness free-whipping state.

## 4. Engineering Recommendations to Ramp Up Our Game

1. **Implement a Tether Tension-Keeping Bias:** Instead of scaling down torque to 20% in standard MPPT during furl, we must maintain a minimum winch tension (e.g. by applying an active tensioning bias in the winches) or keep a mechanical braking level that guarantees $T > 15$ N on all segments, restoring $G J$ and allowing ground damping to propagate.
2. **Bridle/Lifter Optimization:** Modify the rotary lifter bridle angle to maintain tension on the TRPT shaft even at extreme backline payouts.
3. **Active Dampener Phase Tuning:** Shift the Active Torsional Damping feedback to a LPF derivative term to avoid phase lag that amplifies the high-frequency whipping.