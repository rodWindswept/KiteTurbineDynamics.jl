# WT3 Resolution: Force Model — Per-Vertex Spring

> Resolved 2026-07-10 | `wayfinder:grilling` resolved
> Rod: "Per-vertex spring force sounds more realistic"

## Decision

**Per-vertex spring force**, applied at ring center from resolved vertex displacements.

## Rationale

1. **Spring force preserves natural dynamics.** Each Dyneema spoke is a physical spring, not a rigid bar. Per-vertex spring allows small elastic drift (mm-scale) while restoring equilibrium. Hard projection would over-constrain — same class of error as center projection but at vertex level.

2. **Center drift is a feature, not a bug.** When aero forces are asymmetric (as they will be — wind gradient, rotation), vertices on the windward side see different loading than leeward. The ring center SHOULD respond by drifting slightly, finding the equilibrium where spoke forces balance the asymmetric load. The previous center constraint prevented this entirely.

3. **Force resolution: vertices → ring center.** Compute per-vertex spring force `F_j = k_spoke * max(r_j - R_design, 0) * (-radial_dir_j)`. Sum all vertex forces and torques on the ring, apply net force to ring center node, torque to ring twist. No new ODE nodes needed.

4. **Spring constant tuning.** Keep the existing 3.9 MN/m per ring (3 spokes in parallel, 7mm Dyneema, 3m span). This proved too stiff for explicit Euler at center level because drift was measured in meters. At vertex level, drift should be mm-scale (estimated from centrifugal loading), so the same spring constant should integrate fine.

## Implementation plan (feeds WT4)

```julia
function constrain_spokes!(u, sys, N, Nr, p)
    shaft = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    k = p.n_lines * 100e9 * π * 0.007^2 / 4 / R  # per-ring stiffness
    for each ring:
        for each vertex j:
            pos = attachment_point(center, R, α, j, n_lines, perp1, perp2)
            r = norm(pos - dot(pos, shaft) * shaft)  # radial distance
            if r > R_design:  # tension only
                F = k/n_lines * (r - R_design) * radial_unit_vec
                net_force[center] += F
        apply net_force to ring center
end
```

- Per-vertex springs, tension-only
- Forces summed at ring center
- Ring center free to drift (Tulloch coupling preserved)
- No new ODE nodes

## Implications

- WT4 can proceed with spring implementation
- No changes to collapse formulas (WT1 confirmed)
- Vertex position function ready (WT2)
- Need to verify mm-scale drift is achievable (WT5 will test)
