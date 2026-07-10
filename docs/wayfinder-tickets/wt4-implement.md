# WT4: Task — Implement vertex-level constraint in ring_forces.jl

> `wayfinder:task` | blocks: WT5 | blocked by: WT2, WT3

## Question

Implement the chosen constraint model (from WT3) using vertex positions (from WT2) in `constrain_spokes!`. This is the implementation, not the test.

Requirements:
- Modify `constrain_spokes!` to operate on per-ring vertices using center + α + R + perp1/perp2
- Per-ring floating center = average of vertex positions (where spokes converge)
- Constraint force/position applied to ring center nodes (or vertex nodes if new nodes are added)
- Respect spoke tension-only physics (only resist outward motion, not inward)
- Preserve shaft-parallel DOF for rings

Deliverable: updated `src/ring_forces.jl` with `constrain_spokes!` rewritten.
