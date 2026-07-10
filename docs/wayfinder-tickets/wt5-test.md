# WT5: Task — Test: λ=0.69 Reinforced with vertex spoke constraint

> `wayfinder:task` | blocked by: WT4

## Question

Does the vertex-level spoke constraint produce a viable λ=0.69 Reinforced operating point?

Test: run `scripts/test_spoke.jl` (kickstart + 60s MPPT sustain) with the new vertex-level constraint. Success criteria:
- Ring expansion contained (max vertex drift < 10mm from design radius)
- ω ≥ 150 rpm sustained for 60s
- P ≥ 50 kW sustained
- FoS airborne ≥ 1.5
- Torsional collapse margin ≥ 15° (healthy)

Deliverable: test result logged to `/tmp/vertex_spoke_result.txt`, committed to DECISIONS.md.
