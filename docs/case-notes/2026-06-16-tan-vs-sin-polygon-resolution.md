# Case Note: Polygon Force Resolution — tan vs sin Inconsistency

**Date:** 2026-06-16
**Author:** Hermes Agent (with Rod Read)
**Status:** Open — requires model audit and decision

---

## Summary

The TRPT structural model uses `tan(π/n)` for polygon force resolution in beam
compression calculations, but `sin(π/n)` for the tension-stiffening hoop
tension at the same polygon vertices. The exact polygon statics require
`sin(π/n)` in both cases. This is a consistency issue, not a deliberate
physical distinction between compression and tension.

## Locations affected

| File | Line | Expression | Uses | Should use |
|------|------|-----------|------|------------|
| `trpt_optimization.jl` | 427 | `N_comp = F_v / (2.0 * tan(π / n_float))` | tan | **sin** |
| `trpt_optimization.jl` | 438 | `T_ring = F_exp_per_vertex / (2.0 * sin(π / n_float))` | sin | sin ✓ |
| `expansion_rotor.jl` | 172 | `geometry_factor = 2.0 * tan(π / n_lines)` | tan | **sin** |
| `trpt_axial_profiles.jl` | 34 | `N_comp = (F_inward − F_centripetal) / (2 tan(π/n))` | tan (comment) | sin |

## Physics

For a regular n-gon under radial force F applied at each vertex, force
equilibrium at a vertex involves two structural elements (beams or tethers)
meeting at angle 2π/n. Each element carries axial force S (compression C
or tension T). The radial component of each element's force is S·sin(π/n).

Equilibrium: 2S·sin(π/n) = F → S = F / (2·sin(π/n))

This is symmetric: the geometry of the vertex is identical regardless of
whether F points inward (compression) or outward (tension). The sin(π/n)
projection is the same.

The tan formula would correspond to a radial component of S·tan(π/n),
which has no geometric interpretation for the polygon vertex force polygon.

## Magnitude of error

The tan formula gives S_tan = F/(2·tan) while the correct formula gives
S_sin = F/(2·sin). Ratio: S_tan / S_sin = sin/tan = cos(π/n).

| n | cos(π/n) | Error direction | Beam compression error |
|---|----------|----------------|----------------------|
| 3 | 0.500 | **under-estimate 50%** | Compression is 2× higher than computed |
| 4 | 0.707 | under-estimate 29% | |
| 5 | 0.809 | under-estimate 19% | |
| 6 | 0.866 | under-estimate 13% | |
| 7 | 0.901 | under-estimate 10% | |
| 8 | 0.924 | under-estimate 8% | |
| 12 | 0.966 | under-estimate 3% | |

The error is largest at n=3 (triangles) — the beam compression is twice
what the code currently computes. The FoS against Euler buckling would be
halved for triangular rings if corrected.

## Does this flip any qualitative conclusions?

**No, but it compresses the magnitude.** The code under-estimates beam
compression MORE for triangles (50%) than for octagons (8%). Correcting to
sin would make triangles look WORSE relative to octagons — reducing the
mass advantage. However:

1. The beam-mass effect alone is modest (~1.45×, see corrected report §3.1)
2. The main mass savings come from tethers (2.67×), knuckles (2.67×), and
   rotor sizing — which are independent of this polygon resolution
3. The DE optimizer's preference for n=3 is robust — tether count alone
   provides a 2.67× advantage

**The headline 58 kg result should be re-run with the corrected formula**
before presenting to the AWES forum, to ensure the mass numbers are
physically consistent.

## Corrected formula

Replace all three tan instances with sin:

```julia
# trpt_optimization.jl:427 — beam compression
N_comp = F_v / (2.0 * sin(π / n_float))

# trpt_optimization.jl:438 — already correct, no change needed
T_ring = F_exp_per_vertex / (2.0 * sin(π / n_float))

# expansion_rotor.jl:172 — effective radius geometry factor
geometry_factor = 2.0 * sin(π / n_lines)
```

## Verification plan

1. Apply the sin correction to all three locations.
2. Re-run the V6.2 50 kW DE campaign with corrected formula.
3. Compare mass at convergence vs current 58.19 kg.
4. Check whether n=3 still wins and at what mass.
5. Re-generate the AWES forum diagrams with updated numbers.
6. Update the report if masses change materially.

## Why this wasn't caught earlier

Both the tan and sin formulas produce monotonic functions of n that point
in the same qualitative direction (fewer lines = less mass). The DE
optimizer would have converged to n=3 under either formula. The difference
only becomes visible when comparing absolute mass values across models or
when auditing the physics for publication.

## Related: the sin formula was used correctly for tension stiffening

The tension stiffening formula on line 438 uses sin — this was added later
(June 2026, V6.2 force-first model) by a different author/agent than the
original compression formula. This is likely why the inconsistency exists:
the newer code used the correct derivation while the older code used an
approximation that was never revisited.
