# Diagram d5 Specification: Expansion Rotor Bank Angle & Pitch Depower Risk

## Status: PENDING DASHBOARD VERIFICATION
Rod will check the interactive dashboard to see what a banked expansion rotor blade actually looks like before we draw this. This spec captures what we know and what we need to verify.

## Purpose
Show the reader two things: (1) how banked expansion rotor blades produce radial spreading force during normal operation, and (2) why pitch depower creates a back-wind collapse risk that the static DE optimizer cannot detect.

## Critical geometry (from Rod's sketch)

### What an expansion rotor IS
The expansion rotor is a complete rotor assembly at a ring position on the TRPT shaft. It consists of:
- A rotor ring (structural ring, analogous to the hub of a kite turbine)
- Blades extending outward from the rotor ring at the bank angle
- The blades are the OUTER PORTION of the rotor — just like normal kite turbine blades, but banked

### Key difference from normal kite turbine rotor
- Normal rotor: blades sweep a FLAT PLANE ANNULUS (a flat disk with a hole)
- Banked expansion rotor: blades sweep a HOLLOW TRUNCATED CONE around the shaft axis

### Wind direction
- Wind is HORIZONTAL (parallel to ground)
- Shaft is at elevation angle (e.g., 30° from horizontal)
- Rotor ring is PERPENDICULAR to shaft
- Blades extend from ring ends at bank angle (e.g., 45° from the ring plane)

### From the side view (what the diagram must show)
1. Ground line (horizontal)
2. Shaft axis (angled up at elevation angle, e.g., 30°)
3. Rotor ring (short line perpendicular to shaft at a ring position)
4. Blades extending from both ends of the ring at the bank angle
5. Wind arrow (HORIZONTAL, from left to right)
6. Bank angle arc (showing the angle between the ring plane and the blade)

## Normal operation panel
- Shaft at nominal elevation (30°)
- Wind horizontal from left
- Rotor ring perpendicular to shaft
- Blades extend from ring at 45° bank
- Dashed arc showing the cone sweep
- Force decomposition: wind hits blade → lift → resolves into F_r (radial, outward, spreads ring) + F_a (axial, shaft compression)
- Label: "Stable: F_r spreads ring outward"

## Pitch depower panel
- Shaft tilted up to higher elevation (50°, backline winched out)
- Wind STILL horizontal from left (wind doesn't change — the kite attitude changes)
- Rotor ring and blades have the SAME mechanical orientation relative to shaft
- But because shaft tilted up, the apparent wind direction relative to blade changes
- Wind now hits blades from above → lift reverses → F_r pulls INWARD
- Label: "Collapsing: F_r reverses, pulls inward"
- Warning: "BACK-WIND"

## Force sub-diagrams
Each panel should include a small force vector diagram showing:
- Apparent wind direction
- Lift vector
- Decomposition into F_r (radial) and F_a (axial)
- Normal panel: F_r outward (green/stable)
- Depower panel: F_r inward (red/collapsing)

## Bottom warning bar
"Static DE optimiser cannot detect transient back-wind collapse — dynamic ODE validation required."
"Mitigation: lower bank angle (20–30°), symmetric airfoils, conservative prototyping until validated"

## What needs dashboard verification
1. Are the blades attached to a rotor ring, or directly to the ring node?
2. What is the exact bank angle? Is it measured from the ring plane or from the shaft?
3. Does the blade sweep a truncated cone, or is it a different geometry?
4. At pitch depower, does the apparent wind actually reverse on the blades?
5. What does the expansion rotor look like from the side in the GLMakie dashboard?

## Design constraints (once verified)
- article + geometry class
- Wind must be HORIZONTAL
- Rotor ring must be shown as a structural element (not just a hub point)
- Blades must extend from ring ends
- Cone sweep shown as dashed arc
- Colors: green for shaft, magenta for rotor/blades, blue for wind (normal), red for wind (back-wind)
