# Phase D: TRPT Design Envelope (Corrected)

**Date:** 2026-07-13
**Status:** In verification — V10 Reinforced re-tested with per-vertex spoke springs
**Prior version:** `9b71488` (retracted — centre constraint FoS inflated)

## Correction notice

The previous Phase D report (commit `9b71488`) claimed V10 Reinforced as the sole
viable design with P=301 kW and FoS=2.26. These numbers were derived from the
centre-constraint spoke model which artificially stiffened ring centres onto the
shaft axis. The per-vertex Dyneema spring model (correct, physically realistic
tension-only spokes) produces different structural dynamics.

**All Phase D numbers are provisional until the full re-verification sweep completes.**

## V10 Reinforced re-test (per-vertex spokes)

Tested at 11 m/s, per-vertex spoke springs, `settle_to_operational_state` init,
30s MPPT sustain at each k.

| k | ω (rpm) | P (kW) | Ring FoS | Rings failing (/22) |
|---|---------|--------|----------|---------------------|
| 2.0 | 274 | 8 | 0.31 | 3 |
| 4.0 | 310 | 81 | 0.06 | 4 |
| 6.0 | 198 | 43 | 0.19 | 19 |
| 8.0 | 208 | 105 | 0.12 | 19 |
| 10.0 | 98 | 13 | 0.12 | 11 |
| 14.0 | 13 | 0 | 1.09 | 3 |
| 18.0 | 15 | 0 | 1.02 | 3 |
| 22.0 | 16 | 1 | 0.58 | 10 |

Best operating point: k=8, P=105 kW, FoS=0.12. **Not viable.**

## Pending

- Missing-rotor test: V10 Reinforced with all 4 expansion rotors (not dropping lowest)
- Lighter-tether re-verification with per-vertex spokes
- Full re-audit of all Phase D table entries

## Key lesson

The centre constraint model (projecting ring centres onto shaft axis) suppressed
centrifugal ring drift, giving unrealistically high FoS values. The per-vertex
spring model allows rings to find their natural equilibrium, revealing the true
structural margin. This is a good physics correction — the old numbers were
wrong, not the new ones.

## Next steps

1. Complete missing-rotor test
2. Re-verify all 9 designs with per-vertex spokes
3. If no design is viable: report honestly, identify structural innovation needed
4. If designs emerge viable: update Phase D table, proceed to Phase E
