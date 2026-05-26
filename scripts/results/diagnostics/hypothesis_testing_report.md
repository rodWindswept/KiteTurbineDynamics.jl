# Phase N Hypothesis Testing Summary Report

We simulated four control cases to validate the impact of structural tensioning on the Tulloch limit cycles and torsional decoupling.

**Key metric**: `T_top_avg` is the average tension in the topmost TRPT segment (sky-anchor → hub). This is the physical load carried by the lift line — NOT the aerodynamic capability. During pitch depower, this MUST remain ≥ baseline (operational level) to keep the hub elevated and tethers taut.

| Case Name | Peak Power (kW) | SS Speed Ripple (rad/s) | Slack (%) | Max Twist (°) | T_top baseline (N) | T_top min (N) | Lift Slack (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Mode 1 Baseline** | 563.0 | 76.73 | 78.1% | 367° | 1817 N | ❌ 0 N | 58.2% |
| **Hypothesis A (Winch Bias)** | 141.6 | 4.39 | 73.8% | 381° | 1817 N | ❌ 0 N | 28.1% |
| **Hypothesis B (40% Clamp)** | 210.8 | 66.10 | 78.1% | 345° | 1817 N | ❌ 0 N | 51.1% |
| **Hypothesis AB (Combined)** | 162.3 | 0.73 | 73.8% | 371° | 1817 N | ❌ 0 N | 26.8% |

## Lift Line Tension Compliance

> [!IMPORTANT]
> **Lift Line Safety Criterion**: T_top_avg must remain ≥ baseline (operational level) throughout depower.
> The lifter kite (rotary or fixed) MUST maintain full operational tension to keep bridles taut,
> tethers preloaded (GJ > 0), and the sky anchor elevated. If T_top < 50 N the hub is unsupported.
> ✅ = maintained ≥ 90% baseline  |  ⚠️ = dipped to 50–90%  |  ❌ = dropped below 50%


## Critical Validation Insights

> [!TIP]
> **Hypothesis A (Proportional Winch Retarder) Results:**
> Payout rate modulated by T_min tension feedback (50-step cadence = 2ms response).
> Lift slack (T_top < 50N) changed by **30.2%** vs baseline.
> Speed ripple: 76.73 → 4.39 rad/s.
> [!IMPORTANT]
> **Hypothesis B (40% Generator Clamp) Results:**
> Minimum elevation braking clamp at 40% keeps shaft tensioned via generator load.
> Peak power spike changed by **62.6%**.
> T_top min: 0 N.
> [!CAUTION]
> **Combined Hypothesis AB:**
> Speed ripple: 0.73 rad/s (baseline: 76.73). T_top min: 0 N. Lift slack: 26.8%.
> This combination achieves the smoothest rotor deceleration with the best lift line tension retention.