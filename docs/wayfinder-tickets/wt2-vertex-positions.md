# WT2: Prototype — Vertex position computation in ring_forces.jl

> `wayfinder:prototype` | blocks: WT4 | blocked by: WT1

## Question

Can we compute per-vertex positions from existing ODE state (center + alpha + R + perp1/perp2) inside `compute_ring_forces!`? What does the code look like?

Prototype: add a function `vertex_positions(u, sys, ring_gid, p, alpha)` that returns a `3×n_lines` matrix of vertex positions. Print a few at a known ω and wind speed to verify against expectations.

Deliverable: working function in a test script, verified output.
