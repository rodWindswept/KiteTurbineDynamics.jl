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

- [WT1](docs/wayfinder-tickets/wt1-resolution.md) — **Tulloch δα* is invariant to constraint method.** Collapse threshold depends only on design constants (r, L), never runtime state. Center constraint kills power by preventing rings from reaching any |Δα| (dynamic reachability failure, not geometric). Vertex constraint preserves torsional coupling — twist angles α evolve freely, tether geometry correct. No changes needed to `init_geometry!`, `min_collapse_margin`, or collapse formulas.
- **WT2** — `ring_vertex_positions()` and `spoke_drift()` functions added to `src/ring_forces.jl`. Test script at `scripts/test_vertex_spoke.jl`. Vertex positions match design radius with 0.0mm drift when rings on-axis. Uses `shaft_perp_basis()` (not `_tilted_ring_basis` — that has TILT_SCALE=0.1 visual amplification for dashboard, would break physics).
- **WT3** — Per-vertex spring force selected. Sum vertex forces at ring center (no new ODE nodes). Center floats naturally — asymmetric aero forces cause small center drift, which is physically correct. Tension-only (F_j = k * max(r_j - R, 0)). Uses existing k_spoke ≈ 3.9 MN/m per ring; mm-scale vertex drift should be integrable by explicit Euler.

## Not yet specified

- Per-vertex projection vs per-vertex spring force: which numerical approach?

## Out of scope

- Kickstart control ramp tuning (separate map)
- Full Gate 2 hunt for λ=0.69 Reinforced (execution, not decision)
- Phase D charts (data-dependent, ready to run)
- Community report, site-value map (Phase E-F)
