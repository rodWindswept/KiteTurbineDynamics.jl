# WT1: Research — Tulloch collapse criterion and vertex constraint interaction

> `wayfinder:research` | blocks: WT2, WT3

## Question

How does constraining vertices (not ring centers) affect the Tulloch geometric collapse criterion? Does vertex-level radial constraint change the collapse margin calculation, or does it purely add radial stiffness without affecting the torsional buckling mode?

Read: Tulloch PhD thesis sections on collapse criterion, `src/ring_forces.jl` collapse margin calculation, and the existing `constrain_spokes!` code.

Deliverable: markdown summary of how vertex constraint interacts with torsional collapse, any expected changes to collapse margin values.
