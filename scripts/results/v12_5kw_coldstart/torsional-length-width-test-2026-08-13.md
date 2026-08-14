# Torsional FoS: Length vs Width Isolation Test — 2026-08-13

Provenance note. Corrects a misleading claim made during the ladder FoS
sweep (diag_fos_ladder.jl).

## Provenance

- **Script:** `scripts/diag_tors_length_width.jl`
- **Date:** 2026-08-13
- **Formula tested:** τ_cap = T_total × r_min² / √(L_seg² + 2·r_min²)
  (trpt_optimization.jl:396); tfos = τ_cap / tau_above
- **Controlled inputs:** T_total = 2000 N, tau_above = 100 Nm, held constant;
  only geometry varied.

## Results

| Test | Sweep | Tors FoS | Direction |
|------|-------|----------|-----------|
| A | Length 15→60 m, 8 rings, r_min=1.0 fixed | 8.52 → 2.62 | Longer = weaker (~1/L) |
| B | Width r_min 0.6→2.0 m, length 30m fixed | 1.87 → 17.03 | Wider = stronger (~r²) |
| C | Short 15 m vs long 30 m, same rings/width | 8.52 vs 4.99 | Shorter wins 1.7× |

## Conclusion

Rod is correct: for the same number of rings, a **wider, shorter** shaft has
higher torsional FoS than a skinny long one.

The earlier ladder table (diag_fos_ladder.jl) showed tors FoS rising with
power (0.31 → 3.49) — that rise is driven by T_total scaling ~linearly with
P while tether length grows only ~√P. The thrust gain dominates the length
penalty. It does NOT mean "longer shafts are stronger" — the opposite is
true at any fixed power.

## Design implication for the 7kW rung

To raise torsional FoS at low power, the levers are (in order of potency):
1. Shorter segments — more rings (target_Lr ↓) or shorter tether
2. Wider rings — r_min² term; r_bottom ↑ toward r_hub
3. More lines — n_lines ↑ (per-line torque ↓)
4. More axial tension — lift device (T_lift ≈ 0.65 × thrust at 5 kW)
