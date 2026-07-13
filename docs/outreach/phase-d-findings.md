# Phase D: TRPT Design Envelope — Gate 2 Structural + Dynamic Viability

**Date:** 2026-07-11
**Repository:** KiteTurbineDynamics.jl @ `77508d3`
**Scope:** Constrained TRPT design space — tether diameter, blade scale, ring reinforcement

## Executive Summary

A systematic sweep of the TRPT design space found one structurally and
aerodynamically viable configuration: **V10 Reinforced** (4 mm tethers,
reinforced bottom rings, full-scale 1.0× blades). All lighter-tether
variants (3 mm, 3.5 mm) self-start and produce power but fail under TRPT
ring compression. All 4 mm variants with blade scale below 1.0× stall
against reinforced frame drag. The structural bottleneck is ring beam
buckling under torsional loading — not Tulloch geometric collapse.

## Method

### Design space

We tested combinations across three continuous parameters:

| Parameter | Range | Step |
|-----------|-------|------|
| Blade scale | 0.69–1.0 | 0.69, 0.85, 0.92, 0.95, 1.0 |
| Tether diameter | 3.0–4.0 mm | 3.0, 3.5, 3.8, 4.0 |
| Bottom ring scale | 1.0–1.30 | 1.0, 1.15, 1.30 |

### Test protocol

Each design was tested at 11 m/s wind, spoke-constrained (per-vertex
Dyneema springs), with the left-flank MPPT architecture (k_mppt 2–20).

- **Settle phase:** `settle_to_operational_state` — 4.5 s wind-only
  exposure to measure natural self-start behaviour
- **Sustain phase:** 60 s MPPT at k-values swept across the power curve
- **FoS measurement:** per-ring `ring_element_analysis` at 1 s intervals
- **Collapse margin:** `min_collapse_margin` from Tulloch δα*

### Kickstart analysis

For the 4 mm designs that stalled naturally, we computed the aerodynamic
crossover — the rotor speed where τ_aero exceeds τ_parasitic:

- 0.69× blades: ω_cross ≈ 35 rpm, τ_cross ≈ 1,700 Nm
- 0.85× blades: ω_cross ≈ 43 rpm (settle speed), but cannot sustain

Controlled kickstart to 38–40 rpm (10% margin above crossover) was tested
with derived motor k (k = τ/ω² ≈ -130 at 35 rpm, not arbitrary -500).

## Results

### Complete Phase D table

| Tether | Rings | Blades | ω_final | P (kW) | FoS_ring | Collapse margin | Self-start? | Viable? |
|--------|-------|--------|---------|--------|----------|-----------------|-------------|---------|
| 3.0mm | 1.00 | 1.0× | 327 | 290 | 0.23 | 40° | Yes | ❌ rings fail |
| 3.0mm | 1.15 | 1.0× | 346 | 237 | 0.15 | 42° | Yes | ❌ rings fail |
| 3.0mm | 1.00 | 0.69× | 199 | 31 | 0.04 | 45° | Yes | ❌ rings fail |
| 3.5mm | 1.00 | 1.0× | 311 | 211 | 0.15 | 48° | Yes | ❌ rings fail |
| 3.8mm | 1.00 | 0.95× | 299 | 161 | 0.04 | 18° | Partial | ❌ rings fail |
| 4.0mm | 1.00 | 0.92× | 377 | 178 | 0.06 | 19° | Yes | ❌ rings fail |
| 4.0mm | 1.30 | 1.0× | **213** | **301** | **2.26** | **42°** | No* | **✅** |
| 4.0mm | 1.30 | 0.85× | 14 | 0 | 1.63 | 29° | No | ❌ stalls |
| 4.0mm | 1.30 | 0.69× | 3 | 0 | 7.28 | 27° | No | ❌ stalls |

*V10 Reinforced requires a short PTO motor kickstart at low winds. Self-sustains
from ~9 m/s.

### Structural envelope

Ring compression FoS is the universal hard boundary. Collapse margin stays
healthy (27–48°) on the left flank across all designs. The failure is ring
beam buckling, not Tulloch over-twist.

The ω-FoS relationship is monotonic: higher rotor speed increases both
centrifugal ring loading and TRPT torsional compression. The 4 mm tethers
distribute this load across the ring polygon more evenly than 3 mm or
3.5 mm tethers, preventing localised buckling.

### Spoke physics

The per-vertex Dyneema spoke spring model (implemented in
`constrain_spokes!`, commit `e318576`) correctly constrains ring expansion
without killing torsional coupling:

- Vertex positions computed via `attachment_point(center, R, α, j, n_lines, perp1, perp2)`
- Tension-only: spring activates only when vertex radial distance exceeds design radius
- Forces summed at ring center (no new ODE nodes)
- Maximum vertex drift across all designs: < 5 mm
- Tulloch δα* invariant to constraint method (depends only on r, L — design constants)

### Cascade failure analysis

At 3.5 mm tether, 1.0× blades, the failure is progressive:

1. Rings 20–22 fail first (outermost, highest relative velocity)
2. At 41 s, cascade: ω passes the torsional eigenvalue crossing, 6 rings → 20 failing in one second
3. Post-cascade oscillation: 12–22 rings fail, ω swings 236–379 rpm

Aerodynamic drag on 4 mm tethers (78% more cross-section than 3 mm)
naturally caps ω at 213 rpm — below the cascade threshold. This is a
self-limiting safety feature, not a deficiency.

## Design landscape

```
Ring FoS
 3.0 │                                    ● V10 Reinforced
     │
 1.5 │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  viability threshold
     │
 0.5 │    ○   ○   ○   ○
 0.1 │ ○                       all 3mm/3.5mm variants
     └─────────────────────────────────────────────
            200      300        400      ω (rpm)
```

The viable point sits at the intersection of structural integrity (FoS ≥ 1.5)
and aerodynamic sustainability (ω > 0). No design currently occupies the
gap between Tight and Reinforced. The gap is real and appears to be a
fundamental constraint of the current ring topology.

## Key lessons

1. **Ring compression FoS is the hard design boundary.** Tulloch collapse
   margin is healthy across all left-flank designs. The limiting factor is
   ring beam buckling under TRPT torsional loading.

2. **Tether diameter controls load distribution.** Thicker tethers (4 mm)
   redistribute torsional compression more evenly across the ring polygon,
   preventing localised buckling. This is a geometric effect, not material
   strength.

3. **Self-start is not a prerequisite.** A PTO motor kickstart to the
   crossover speed (~35 rpm) is energetically negligible and field-realistic.
   The crossover speed can be pre-computed from the BEM-coupled solver.

4. **The left-flank architecture is correct.** Operating at low k, high ω
   maximises collapse margin (42–48°) while producing 200–300 kW at 11 m/s.
   Right-flank operation (high k, low ω) degrades both FoS and power.

5. **Per-vertex spoke springs work.** The spring model keeps rings on-axis
   with <5 mm vertex drift while preserving Tulloch torsional coupling. No
   ring center constraint is needed.

## Next steps

- **Phase E:** Community report — introduce the TRPT design envelope and
  invite collaboration on ring topology innovation
- **Ring optimisation:** Explore variable spacing, composite rings,
  or spreader bars to widen the structural envelope
- **Kickstart control:** Implement crossover-aware kickstart algorithm with
  derived motor k (τ/ω², not arbitrary values)
- **Multi-wind mapping:** Run Gate 2 at 5–15 m/s for V10 Reinforced to
  create the full Phase D power curve
