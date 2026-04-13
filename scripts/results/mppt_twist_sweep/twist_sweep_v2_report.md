# MPPT Twist Sweep v2 — Summary Report

Corrected CT-thrust physics | Back line active | Kite sized for 4 m/s launch

## Optimal k_mppt per wind speed

| v_wind (m/s) | Best k_mult | P_kw | Twist (°) | T_max (N) | Δω (rad/s) |
|---|---|---|---|---|---|
| 8 | 1.5× | 4.13 | 475.1 | 467 | -0.0013 |
| 10 | 1.5× | 8.38 | 474.0 | 637 | -0.0026 |
| 11 | 1.5× | 11.28 | 471.8 | 730 | -0.0028 |
| 13 | 1.5× | 18.84 | 467.7 | 956 | -0.0027 |

## Power summary by k_mult

| k_mult | v=8 P(kW) | v=10 P(kW) | v=11 P(kW) | v=13 P(kW) |
|---|---|---|---|---|
| 0.5× | 2.80 | 5.81 | 7.82 | 13.04 |
| 0.75× | 3.44 | 7.08 | 9.51 | 15.85 |
| 1× | 3.82 | 7.83 | 10.52 | 17.54 |
| 1.2× | 4.03 | 8.23 | 11.06 | 18.46 |
| 1.5× | 4.13 | 8.38 | 11.28 | 18.84 |
| 2.5× | 4.04 | 7.79 | 10.36 | 17.17 |
| 4× | 3.31 | 5.55 | 7.43 | 12.07 |

## Wind ramp (7→14 m/s over 150 s)

- P at 14 m/s: 21.09 kW
- Twist at 14 m/s: 361.0°
- Ramp rows: 300
