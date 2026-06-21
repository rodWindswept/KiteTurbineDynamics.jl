# V11 Tapered Tethers — Scope Document

**Date:** 2026-06-20
**Predecessor:** V10 (unified rotor architecture, power-accuracy objective, 76.75 kg)

## 1. Physics Motivation

Tether tension accumulates from hub to ground. Ring 1 (ground) carries the thrust of
all N rings. Ring N (hub) carries only its own rotor's thrust. In the current model,
every tether segment has identical 3 mm Dyneema (SWL = 3,500 N). This over-designs
the upper tethers by up to 10×.

For the V10 winner (n=12, 76.75 kg, FoS=3.5 at ground):
| Ring | Cumulative thrust (N) | Tension per line (N) | Required D (mm) | Current D (mm) | Over-design |
|------|----------------------|---------------------|-----------------|----------------|-------------|
| Ground (1) | ~12,000 | ~1,000 | 3.0 | 3.0 | 1× |
| Mid (5) | ~4,000 | ~333 | 1.7 | 3.0 | 3× |
| Hub (7) | ~2,400 | ~200 | 1.1 | 3.0 | 7× |

## 2. Expected Savings

### Tether mass
Current: 12 lines × 67m × 970 kg/m³ × π(1.5mm)² ≈ 5.5 kg
Tapered (3mm → 1.1mm, quadratic): ~1.8 kg
**Saving: ~3.7 kg** (4.8% of total airborne mass)

### Parasitic drag
Tether line drag ∝ D × L. Upper 50% of tethers at reduced diameter.
Current drag: ~4.5 kW (from V9 analysis)
Tapered drag estimate: ~2.5 kW
**Saving: ~2 kW** (reduces power lost to tether drag by ~45%)

### Total impact
~3.7 kg mass reduction + ~2 kW drag reduction. At 76.75 kg base, this could push
the optimum toward **72-74 kg**.

## 3. Design Variable

Single new continuous variable: `tether_taper` ∈ [0.3, 1.0]

D_i = D_bottom × (1 − t_i × (1 − tether_taper))
where t_i = (z_i − z_ground) / (z_hub − z_ground) ∈ [0, 1]

- tether_taper = 1.0: uniform (current behaviour, backward-compatible)
- tether_taper = 0.3: top tethers at 30% of bottom diameter
- tether_taper = 0.5: top tethers at half diameter

## 4. Per-Segment FoS Check

For each inter-ring segment:
1. Compute cumulative thrust above this segment: T_cum = Σ thrust from ring i+1 to N
2. Tension per line: T_per = T_cum / n_lines
3. Local tether diameter: D_i from taper formula
4. SWL_i = f(D_i) (Dyneema SWL ∝ D² approximately)
5. FoS_i = SWL_i / T_per

Constraint: min(FoS_i) ≥ 3.0 for all segments.

## 5. Implementation

### objective_v11.jl
- Inherits from objective_v10 with one added variable (15 DoF)
- `search_bounds_v11`: adds tether_taper ∈ [0.3, 1.0]
- Per-segment FoS replaces the single global tether FoS gate
- Tether mass computed by integrating D(z)² along the shaft
- Parasitic drag model updated for per-segment diameters

### Structural evaluator
- `evaluate_design` already computes per-ring cumulative_thrust
- New function: `tether_fos_per_segment(cumulative_thrust, n_lines, tether_taper, zs)`
- Returns min FoS across all segments

### Changes from V10
| What | V10 | V11 |
|------|-----|-----|
| Design DoF | 14 | 15 |
| Tether FoS gate | Single global check | Per-segment minimum |
| Tether diameter | Uniform 3mm | Tapered 1-3mm |
| Tether mass | Uniform | Integrated taper |
| Parasitic drag | Uniform | Per-segment |
| New variable | — | tether_taper ∈ [0.3, 1.0] |

## 6. Risks

**SWL model fidelity:** Dyneema SWL for diameters <1.5mm may not follow simple D²
scaling. Small-diameter braided lines have proportionally larger sheath-to-core
ratios. Conservative approach: enforce minimum D ≥ 1.0mm.

**Wear and handling:** Thin tethers (1.1mm) are harder to handle, inspect, and splice.
Enforce minimum D ≥ 1.5mm for practical purposes — this limits tether_taper to
~0.5 (top = 1.5mm, bottom = 3.0mm).

**Known conservative limit:** With D_min = 1.5mm, maximum mass saving is ~2.5 kg
(vs 3.7 kg theoretical).

## 7. Expected V11 Results

Conservative estimate with D_min = 1.5mm:
- Mass: **72-74 kg** (vs 76.75 kg V10, saving ~3 kg)
- Drag: reduced by ~1.5 kW
- n_lines may decrease (fewer, thicker lines vs many, tapered lines trade-off)
- The hexagonal/dodecagon trade-off shifts — taper makes fewer thick lines more
  competitive because the taper ratio can be steeper

## 8. Implementation Order

1. Add `tether_taper` variable to design vector
2. Implement per-segment diameter computation
3. Add per-segment FoS gate (replaces global tether FoS)
4. Update tether mass integrator
5. Update parasitic drag model for per-segment diameters
6. Update search bounds and objective
7. Clear cache + quick test (5 islands)
8. Full campaign launch
9. Dashboard verification
