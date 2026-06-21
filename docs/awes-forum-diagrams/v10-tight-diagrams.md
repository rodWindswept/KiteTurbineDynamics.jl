# V10 Tight Campaign — Diagram Set

Accompanying the analysis report (`docs/reports/v10-tight-analysis.md`).

## Diagram Index

| File | Description |
|------|-------------|
| `v10-tight-landscape.png` | PCA landscape with mass density, iso-contours, winner marker |
| `v10-tight-atlas.png` | 3×3 grid: PCA landscape colored by each of 9 design variables |
| `v10-tight-pairs.png` | 4×3 grid: raw parameter-vs-parameter scatter plots, mass-colored |
| `v10-tight-nondim.png` | 3×3 grid: non-dimensional Pi groups on PCA landscape |
| `v10-tight-paths.png` | 4-panel: PC landscape, convergence trace, mass-vs-slenderness, findings |

## Campaign Summary

- **Run:** `launch_v10_tight.sh` — 12 islands × 1500 iterations, tight bounds
- **Winner:** Island 1, 49.20 kg, 4 rotors, λ=0.519, r_hub=2.89m, ω=59 rpm
- **Key fixes:** Ring-mapping (commit 71ea694), k_mppt λ² scaling (commit 1c86b69)
- **Mass reduction:** 36% vs V10v1 (76.75 → 49.20 kg)
- **Status:** Dynamically dead — static solver predicts 50 kW, ODE shows 12.1 kW (24%)

## Key Observations

1. **Multi-rotor basin emerged** — the k_mppt λ² scaling prevents the λ→0 mass cheat, forcing the DE to explore multi-rotor designs at moderate blade scales.

2. **Five parameters screaming at bounds** — Do_top, t_over_D, r_bottom, target_Lr, and λ_bottom are all at their limits. The true optimum lies outside the tight envelope.

3. **Static-vs-dynamic power gap persists** — the equilibrium solver finds 50 kW at 59 rpm; the ODE settles at 12.1 kW at 55.6 rpm. The k_mppt scaling closed the rpm gap (both around 55-59 rpm) but not the power gap.

4. **Compact hub** — r_hub dropped from 3.70m (V10v1) to 2.89m, enabled by multi-rotor thrust distribution across rings.

## Non-Dimensional Insights

| Pi Group | Winner Value | Interpretation |
|----------|-------------|----------------|
| Slenderness L_r/D | ~50 | Very slender beams (Do_top=0.06, L_r=3.0) |
| TRPT Aspect L·n/r_hub | ~13.5 | Tall, many-sided relative to compact hub |
| Ring Packing L_r/(n·D) | ~3.8 | Densely packed rings |
| Power Loading | ~2.4 | Disc loading ~2.4× Betz-equivalent |
| Exp/Struct log₁₀ | ~1.5 | Expansion rotors dominate structure by ~30× |

Compared to V10v1: slenderness increased (50 vs 39), TRPT aspect increased (13.5 vs 11.5), power loading doubled (2.4 vs 1.4) — all reflecting the shift to a more compact, multi-rotor architecture.
