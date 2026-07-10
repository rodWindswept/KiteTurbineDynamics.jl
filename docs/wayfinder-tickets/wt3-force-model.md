# WT3: Grilling — Force model: projection vs spring for vertex constraint

> `wayfinder:grilling` | blocked by: WT1

## Question

Should `constrain_spokes!` use a hard projection (snap vertex back to design position each step) or a spring force model (F = -k * (r_current - r_design) applied at ring centers from vertex displacement sums)?

The hard center constraint works (zero drift) but kills torsional coupling. The spring force didn't work numerically (10mm/step drift, 3.9 MN/m too stiff for explicit Euler). Where does vertex-level sit in this trade-off?

Grill Rod on: whether spokes are rigid enough for hard projection at vertex level, or if a softer spring model with per-ring damping is preferred. Consider: does vertex-level projection preserve polygon geometry and torsional stiffness?

Deliverable: decision recorded in DECISIONS.md.
