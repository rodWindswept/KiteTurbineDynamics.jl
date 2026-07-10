# Vertex-Level Spoke Constraint

> **wayfinder:map** — track decisions, not deliverables. Open tickets are on the tracker.
> `label:wayfinder:map`

## Destination

A working vertex-level radial spoke constraint (`constrain_spokes!`) that preserves Tulloch torsional coupling — preventing ring expansion without killing the polygon geometry that makes the TRPT transmit power.

Success looks like: λ=0.69 Reinforced with spokes running at 50+ kW sustained for 60s, FoS airborne ≥ 1.5, rings on-axis, torsional collapse margin healthy.

## Notes

- **Skills every session**: `ktd-hunt`, `ktd-structural-checks`, `ktd-rig-topology`
- **Reference**: `src/ring_forces.jl` (hard center constraint — kills torsional coupling), `src/ring_element_analysis.jl` (per-vertex FEA), `src/geometry.jl:47` (`_tilted_ring_basis`), Tulloch PhD, `docs/rig-topology.md`
- **Current state**: `constrain_spokes!` projects ring centers onto shaft axis → zero drift but collapses MPPT sustain (torsional stiffness gone)
- **Physical model**: spokes are Dyneema lines, tension-only, from each vertex to its ring's floating center. Vertex position = center + R·(cos(α+2πj/n)·perp1 + sin(α+2πj/n)·perp2)

## Decisions so far

_None yet._

## Not yet specified

- Per-vertex projection vs per-vertex spring force: which numerical approach?
- Apply forces to ring center nodes (from vertex displacements) or add new ODE vertex nodes?
- Tulloch collapse criterion: how does vertex constraint change the geometric collapse margin?
- Pluto visualiser: spoke line rendering from vertex positions?
- Does the kickstart control need re-tuning after vertex-level constraint?
- Should `constrain_spokes!` replace or supplement the existing ring-center hard constraint?

## Out of scope

- Kickstart control ramp tuning (separate map)
- Full Gate 2 hunt for λ=0.69 Reinforced (execution, not decision)
- Phase D charts (data-dependent, ready to run)
- Community report, site-value map (Phase E-F)
