# WT1 Resolution: Tulloch Collapse and Vertex Constraint Interaction

> Resolved 2026-07-10 | `wayfinder:research` resolved

## Primary Findings

### 1. δα* (collapse threshold) is invariant to constraint method

The Tulloch geometric collapse criterion:

```
δα* = 2·arcsin(L / √(2(L² + 2r²)))
```

depends **only** on:
- **r** — ring radius, a design constant stored in `RingNode.radius`
- **L** — segment tether length, approximated as `p.tether_length / (Nr − 1)`

**δα* does NOT depend on ring center radial position.** Neither the current center-projection constraint nor a vertex-level constraint changes this value. The `init_geometry!` function (`soft_ramp_controller.jl:146-163`) confirms this: it reads `node_a.radius` and `node_b.radius` from `sys.nodes` (design constants), never from runtime state.

### 2. The runtime collapse margin uses δα* as an immutable threshold

The margin is computed by `min_collapse_margin()` (`soft_ramp_controller.jl:174-195`):

```
margin_i = δα*_i − |Δα_i|   (radians, converted to °)
```

Where `Δα_i` is the principal-value relative twist between adjacent ring i and i+1, read from the state vector `α`. The δα* values are pre-computed once and never change. **The collapse threshold is a fixed cliff — it doesn't move with ring center position.**

### 3. Why center constraint kills torsional stiffness (it's not about δα*)

The current `constrain_spokes!` (`ring_forces.jl:501-537`) **does not change the collapse threshold**. What it does is destroy the system's ability to **reach and sustain** twist angles (|Δα|).

**Mechanism:**

1. `constrain_spokes!` projects each ring center onto the shaft axis after every timestep (`ring_pos .= proj`), and zeros radial velocity
2. This removes the radial degree of freedom — rings cannot expand, contract, or tilt under load
3. The spoke spring (`ring_forces.jl:275-296`) applies radial restoring forces based on center displacement, but the hard constraint overwrites whatever position the spring achieved
4. Without radial dynamic response, rings can't find their equilibrium configuration under aerodynamic loading
5. Δα values oscillate near zero or fail to build up → zero torsional stiffness → zero power

**The problem is dynamic reachability, not geometric correctness.** The collapse cliff stays put; the system just never gets close enough for it to matter.

### 4. Vertex-level constraint preserves torsional coupling

With per-vertex radial constraint:

- Each polygon vertex is constrained to its design radial distance from the shaft axis
- Vertex position = center + R·(cos(α+2πj/n)·perp1 + sin(α+2πj/n)·perp2)
- The ring **center** (average of vertices) can still float, tilt, and respond dynamically
- Individual vertices stay at correct distances → correct inter-ring tether attachment geometry
- The torsional torque formula τ = n_lines × T × r² × sin(δα)/chord(δα) depends on vertex-to-vertex geometry, which is preserved
- The damping formula in `ring_forces.jl:340-363` uses `Δα = mod(α[ri_b] − α[ri_a] + π, 2π) − π` and ring radii — none of this breaks

**Torsional coupling is preserved because:**
- Twist angles α still evolve freely (vertex constraint doesn't touch α)
- Vertex positions maintain correct polygon geometry for tether attachment
- Ring centers can drift slightly as needed for equilibrium (constrained indirectly through vertex positions)
- The `rope_forces.jl` solver computes tensions from attachment-point distances, which remain correct

### 5. What actually changes

| Aspect | Center constraint | Vertex constraint |
|--------|------------------|-------------------|
| δα* value | Unchanged | Unchanged |
| Collapse margin calculation | Unchanged | Unchanged |
| Torsional torque formula | Unchanged | Unchanged |
| Ring twist α dynamics | Suppressed (can't equilibrate) | Preserved |
| Ring radial response | Blocked completely | Allowed (center floats, vertices constrained) |
| Ring tilt | Blocked | Allowed |
| Tether attachment geometry | Correct but center-locked | Correct and dynamically responsive |
| Power transmission | Killed (rings can't twist) | Preserved |

## Sources

| Source | Lines | What it shows |
|--------|-------|---------------|
| `src/soft_ramp_controller.jl:146-163` | `init_geometry!` | δα* depends only on design constants (r, L) |
| `src/soft_ramp_controller.jl:174-195` | `min_collapse_margin` | Margin = δα* − \|Δα\|, δα* fixed |
| `src/ring_forces.jl:321-336` | Tulloch curve docstring | δα* = 2·arcsin(L/√(2(L²+2r²))) |
| `src/ring_forces.jl:501-537` | `constrain_spokes!` | Projects centers to shaft axis, zeros radial vel |
| `src/ring_forces.jl:275-296` | Spoke spring | k_spoke restoring force, overridden by constraint |
| `src/ring_forces.jl:340-363` | Inter-ring damping | Uses Δα from state vector, ring radii from design |
| `src/geometry.jl:22-33` | `attachment_point` | Vertex = center + R·(cos(φ)·perp1 + sin(φ)·perp2) |
| `src/ring_element_analysis.jl:308-358` | `extract_vertex_forces` | Vertex positions from calling `attachment_point(ctr, R, α, j, …)` |
| `docs/rig-topology.md:72-83` | Radial spoke ties | Vertex-to-center spoke model, tension-only |

## Operational Answer

**Q: Does constraining vertices instead of ring centers change the collapse margin?**

**A: No.** The Tulloch collapse threshold δα* is a geometric invariant depending only on ring radius r and tether segment length L — both design constants. The collapse margin calculation (δα* − |Δα|) is structurally identical regardless of constraint method. The threshold value does not move.

**Q: Does vertex radial constraint preserve torsional coupling?**

**A: Yes.** Vertex constraint preserves the polygon geometry that produces torsional coupling (vertex positions via `attachment_point`), while allowing the ring center to float dynamically. The twist angles α evolve freely, and the tether attachment geometry remains correct. Ring centers can find equilibrium positions driven by spoke spring forces and aerodynamic loads, rather than being slammed to the axis every timestep.

**Q: So what actually needs to be fixed?**

**A:** The constraint target, not the collapse criterion. `constrain_spokes!` should constrain **vertex positions** (each vertex to its design radial distance from shaft axis) instead of **ring center positions** (center to shaft axis). The collapse margin code, δα* pre-computation, and torsional coupling formulas need no changes.

## Implications for WT2 (implementation)

The implementation task (WT2) should:
1. Replace `constrain_spokes!` center projection with per-vertex radial constraint
2. For each ring vertex j: compute design position from `attachment_point(ctr_design, R, α_design, j, n_lines, perp1, perp2)` where `ctr_design` is the shaft-axis point at the ring's design axial coordinate
3. Constrain the radial component of the actual vertex position to match the design radial position
4. Apply corresponding velocity constraint (zero radial vertex velocity component)
5. No changes to `init_geometry!`, `min_collapse_margin`, or any collapse-related code
