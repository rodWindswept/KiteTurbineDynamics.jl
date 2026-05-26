# Implementing Dynamic Tilted Ring Plane Basis and Ground PTO Station Force Tracking

**Status:** Proposed / Ready for next session
**Owner:** Next Agent
**Date:** 22 May 2026

## 1. Context: The Furl Ring Buckling Anomaly

During testing of the **Furl (power-spill)** scenario, a severe anomaly was observed:
At the end of the furl sequence, when the winches have paid out the backline:
- The rotor has bounced back to small negative RPMs.
- Generator power is near zero ($0.01\text{ kW}$).
- The tethers are completely slack.
- **However, the HUD shows the intermediate rings as heavily loaded ($78,234.4\%$ maximum utilization) with all beams drawn in red.**

### The Root Cause: Coordinate System Mismatch

The root cause of this bug is a coordinate system mismatch between the **dynamic ODE simulation** and the **post-processing structural analysis** (`capture_frame` and `analyse_ring`):
1. **Dynamic Basis:** In the ODE solver (`src/rope_forces.jl`) and the 3D visualizer (`src/visualization.jl`), the coordinates of the ring vertices (knuckles) and tether attachments are computed using a **dynamic tilted basis** (`_tilted_ring_basis` in `src/geometry.jl`). When the backline is paid out, the hub rises, changing the shaft's orientation and elevation angle. The dynamic basis correctly tracks this tilt.
2. **Static Basis:** In `src/ring_element_analysis.jl` (`analyse_ring`) and `src/sim_frame.jl` (`capture_frame`), the code reconstructed the tether attachment positions using a **static basis** derived from the static design elevation angle `p.elevation_angle`:
   ```julia
   β = p.elevation_angle
   shaft_dir = [cos(β), 0.0, sin(β)]
   perp1, perp2 = shaft_perp_basis(shaft_dir)
   ```
3. **Fictitious Strains:** Because of this mismatch, when the post-processor tries to compute the lengths of the tether segments to calculate tensions, it places the ring vertices in their static orientations rather than their true, dynamically tilted orientations. This spatial mismatch creates a **massive fictitious elongation** ($\Delta L$) of the reconstructed tethers in the post-processor.
4. **Astronomical Stresses:** This fictitious elongation generates huge spurious tensile forces in `extract_vertex_forces`. The FEA solver is then fed these unbalanced, massive fictitious forces, which deform the ring beams and trigger the astronomical $78,234.4\%$ utilization figures.

---

## 2. Decoupled Buckling & Compression Physics for Top/Bottom Rings

When analyzing buckling/compression limits across the rings, we must decouple the physical reasons for omitting the ground and top rotor rings, and remain highly cautious as many subtle parameters and operating regimes need further investigation.

### A. The Ground PTO Ring (index 1)
- **Status:** Exempt from buckling.
- **Physical Reason:** The ground PTO ring is structurally anchored directly to a rigid mechanical machine frame on the ground. Because of these rigid, continuous boundary conditions, the ring itself is not a free-standing slender column system subject to global structural buckling.
- **Ongoing Work:** While it is excluded from structural buckling analysis, we still need to track the exact forces and moments transmitted to it for foundation and bearing sizing.

### B. The Top/Rotor Ring (index `end`)
- **Status:** Temporarily exempt in current analysis, but subject to active investigation.
- **Physics and Subtleties:** Unlike intermediate rings, the top rotor ring is suspended in flight. However, it experiences two competing radial force distributions:
  1. **Inward Tether Forces:** The downwind TRPT tethers pull inward, creating a net compressive hoop load.
  2. **Outward Expansion Effects:** The spinning rotor blades project forces outward due to two mechanisms:
     - *Mass Centripetal Acceleration:* The mass of the blades rotating at high speed ($m \omega^2 R$) generates an outward centrifugal force distribution pulling the ring radially outward.
     - *Aerodynamic Lift Projection:* The blades are designed with a slight bank angle (outer tip down). This bank angle directs a component of the aerodynamic lift radially outward, acting as an expanding force that helps tension the rotor ring.
- **Nuances and Cautions:** 
  - There is a hypothesis that these outward expansion effects may offset or even exceed the inward tether compression, placing the rotor ring in net hoop tension rather than compression under normal operating conditions.
  - However, **we must not speak in absolute terms**. Under different operating states (e.g. low wind/low RPM transients, high-wind furling, dynamic pitch maneuvers, or highly asymmetric wind shear), the balance of these forces can shift dynamically. 
  - Since the post-processor does not currently model multi-point dynamic blade loads (centrifugal and aerodynamic) acting along the ring circumference, performing a standard buckling check on the rotor ring using only the inward tether forces would trigger false buckling alarms.
  - Therefore, we skip the rotor ring in our current structural post-processor for now. Nailing this physics requires significant parameter checking, full blade load integration, and dynamic validation under varied conditions. This is a long-term research path rather than a solved physical absolute.

### C. Ground Force Tracking
- **Solution:** We will implement a new helper function `ground_station_forces(u, alpha, sys, p, t, wind_fn)` to extract the 3D forces, peak vertex pulls, and net ground moments.

---

## 3. Dashboard GUI Optimization and HUD Collapsible Layout

To enhance usability on small screens and resolve dynamic layout issues, we will optimize the GLMakie dashboard as follows:
1. **Collapsible Grid Sections:** Organize the controls (`ctrl`) and HUD (`hud`) layouts into collapsible panels via a helper function `make_collapsible!`. This will allow the user to toggle sections (such as Configuration, Lift Device, Torque Balance, or Scenarios) open and closed, preventing vertical overflow and detail loss on small screens.
2. **Monospace Telemetry Value Labels:** To resolve visual layout jitter and resizing as numerical values change, all dynamic text labels and slider labels will utilize `:monospace` fonts.
3. **Screen Jump Prevention:** Alarms/Warnings (e.g., torsional collapse, buckling risk, line slack) will use a single space `" "` placeholder when inactive rather than empty strings `""`. This maintains a fixed row height, eliminating vertical layout jumps when alarms trigger.

---

## 4. Telemetry Color Scale Clarification

The HUD colorbar scale goes from `0.0` to `1.0`. 
- This represents **fractional utilization** (where `1.0` maps to `100%` of the critical Euler buckling limit $P_{\text{crit}}$).
- The HUD text labels correctly multiply this fraction by `100.0` to print percentage values (e.g. `80.0%`).
- This representation is completely correct. Once the coordinate basis mismatch is solved, the spurious stresses will disappear, and the utilization values will naturally stay within the safe range (`0.0` to `1.0`), making the visual rendering perfectly intuitive.

---

## 4. Expected Implementation Steps

The next session should perform the following concrete code updates:

### Step 1: Update `analyse_ring` in `src/ring_element_analysis.jl`

Replace the static basis setup in `analyse_ring` (lines 369–371 in `src/ring_element_analysis.jl`):
```julia
    β      = p.elevation_angle
    shaft_dir = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)
```
with the dynamic tilted ring basis:
```julia
    hub_gid   = sys.rotor.node_id
    hub_ri    = (sys.nodes[hub_gid]::RingNode).ring_idx
    perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)
    shaft_dir = cross(perp1, perp2)
```

### Step 2: Update `capture_frame` in `src/sim_frame.jl`

Replace the static basis setup in `capture_frame` (lines 151–153 in `src/sim_frame.jl`):
```julia
    β_s       = p.elevation_angle
    shaft_dir = [cos(β_s), 0.0, sin(β_s)]
    perp1, perp2 = shaft_perp_basis(shaft_dir)
```
with:
```julia
    hub_gid   = sys.rotor.node_id
    hub_ri    = (sys.nodes[hub_gid]::RingNode).ring_idx
    perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)
```
*(This automatically updates both the tether tension loops and the rope sag loops which reference `perp1` and `perp2`.)*

### Step 3: Implement Ground Force Tracking in `src/structural_safety.jl`

Add the following function to `src/structural_safety.jl` to extract ground PTO station loading:
```julia
"""
    ground_station_forces(u, alpha, sys, p, t=0.0, wind_fn=nothing) → NamedTuple

Compute the forces and moments acting on the ground PTO station/ring.
Returns:
- `F_net`: 3D net force vector (N) in global frame acting on the ground station.
- `F_net_mag`: Magnitude of net force (N).
- `F_vertex_max`: Maximum force magnitude on any single ground attachment point (N).
- `F_vertices`: 3×n matrix of individual vertex force vectors (N).
- `M_net`: 3D net moment vector (N·m) about the ground station center.
"""
function ground_station_forces(u      ::AbstractVector,
                               alpha  ::AbstractVector,
                               sys    ::KiteTurbineSystem,
                               p      ::SystemParams,
                               t      ::Float64 = 0.0,
                               wind_fn::Union{Nothing, Function} = nothing)
    hub_gid  = sys.rotor.node_id
    hub_ri   = (sys.nodes[hub_gid]::RingNode).ring_idx
    perp1, perp2 = _tilted_ring_basis(u, sys, hub_gid, hub_ri)

    ring_gid = sys.ring_ids[1]
    node = sys.nodes[ring_gid]::RingNode
    R = node.radius
    α_ring = alpha[1]
    n = p.n_lines

    # Extract vertex forces from the tethers
    F_global = extract_vertex_forces(u, sys, ring_gid, alpha, p, perp1, perp2, t, wind_fn)

    # Compute net force
    F_net = sum(F_global, dims=2)[:]
    F_net_mag = norm(F_net)

    # Compute individual vertex force magnitudes and peak
    F_vertex_mags = [norm(F_global[:, j]) for j in 1:n]
    F_vertex_max = maximum(F_vertex_mags)

    # Compute moments about the center [0,0,0]
    M_net = zeros(3)
    for j in 1:n
        pa = attachment_point([0.0, 0.0, 0.0], R, α_ring, j, n, perp1, perp2)
        M_net .+= cross(pa, F_global[:, j])
    end

    return (
        F_net = F_net,
        F_net_mag = F_net_mag,
        F_vertex_max = F_vertex_max,
        F_vertices = F_global,
        M_net = M_net
    )
end
```

### Step 4: Export the New Function in `src/KiteTurbineDynamics.jl`

Add `ground_station_forces` to the exported names inside `src/KiteTurbineDynamics.jl`.

### Step 5: Implement Automated Verification

In `test/test_ring_element_analysis.jl`, add a new test block verifying that:
1. `ground_station_forces` computes successfully without errors.
2. Under static symmetric settlement, `F_net` points primarily along the shaft axis, and `F_vertex_max` is roughly equal to `TETHER_SWL` times loading scaling.

---

## 5. Gate / Pass Conditions

1. **Furl Scenario Clears:** Open the dashboard and run the **Furl** scenario. At the end of the winching sequence ($t > 8.0\text{ s}$), all struts on the intermediate rings must turn blue/green, indicating low physical loads, and the maximum utilization must sit below $5\%$, clearing the spurious $78,200\%$ anomaly.
2. **Dashboard Performance:** The dynamic basis calculations must run efficiently with zero performance lag on the visualizer frame-rate.
3. **Tests Pass:** `julia --project=. test/runtests.jl` runs completely green.
