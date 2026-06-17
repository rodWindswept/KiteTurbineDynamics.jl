# Diagram d5 Specification: Expansion Rotor Bank Angle & Pitch Depower Risk

## Status: PENDING DASHBOARD VERIFICATION
Rod will check the interactive dashboard to see what banked expansion rotor blades actually look like. This spec captures what we know. Do not generate the diagram until verification is complete.

## What this diagram must convey
1. How banked expansion rotor blades produce radial spreading force during normal operation
2. Why pitch depower creates a back-wind collapse risk that the static DE optimizer cannot detect
3. That the bank angle (45° in the V6.2 optimum) is a critical parameter with dynamic stability implications

## Data provenance (VERIFIED)
- Bank angle = 45° from V6.2 campaign best_design.json
- n_expansion = 1, blade_tip_radius = 10.6m
- The optimizer varied bank_angle ∈ [0, 60]° freely and converged to 45°
- The static DE optimizer cannot evaluate dynamic stability — this is a known limitation

## Critical geometry (from Rod's sketch and TRPT physics)

### What an expansion rotor IS
The expansion rotor is a complete rotor assembly at a ring position on the TRPT shaft:
- Rotor ring (structural ring, analogous to the hub of a kite turbine)
- Blades extending outward from the ring at the bank angle
- The blades are the OUTER PORTION of the rotor — like normal kite turbine blades

### Key geometry
- Wind is HORIZONTAL (parallel to ground) — this is critical, Rod corrected this
- Shaft is at elevation angle (30° nominal)
- Rotor ring is PERPENDICULAR to the shaft
- Blades extend from ring ends at bank angle (45° from ring plane)
- The blades sweep a HOLLOW TRUNCATED CONE (unlike normal rotors which sweep a flat annulus)

### Side-view elements
1. Ground line (horizontal, brown)
2. Shaft axis (angled at elevation, green)
3. Rotor ring (short line perpendicular to shaft, magenta)
4. Blades extending from both ring ends at bank angle (magenta, thicker)
5. Wind arrow (HORIZONTAL, blue)
6. Bank angle arc (red, showing angle between ring plane and blade)
7. Dashed arc showing cone sweep (translucent)
8. Callout identifying "expansion rotor blade"

## Two panels

### Left: Normal Operation
- Shaft at 30° elevation
- Wind horizontal from left
- Rotor ring perpendicular to shaft
- Blades extend at 45° bank
- Force diagram: wind → lift → F_r (outward, spreads ring) + F_a (axial)
- Label: "Stable: F_r spreads ring outward" (green)

### Right: Pitch Depower Risk
- Shaft tilted to 50° (backline winched out)
- Wind STILL horizontal from left
- Rotor ring and blades maintain same mechanical orientation relative to shaft
- Apparent wind direction changes → lift reverses → F_r pulls INWARD
- Label: "Collapsing: F_r reverses, pulls inward" (red)
- Warning: "BACK-WIND"

### Bottom warning
"Static DE optimiser cannot detect transient back-wind collapse — dynamic ODE validation required."
"Mitigation: lower bank angle (20–30°), symmetric airfoils, conservative prototyping"

## What needs dashboard verification
1. Are expansion blades attached to a rotor ring? What does it look like from the side?
2. Exact bank angle measurement — from ring plane or from shaft?
3. Does the blade sweep a truncated cone? Verify visually.
4. At pitch depower, what happens to the apparent wind on the blades?
5. Any other geometric details visible only in the 3D dashboard?

## Design constraints (once verified)
- article + geometry (paperwidth=36cm, paperheight=28cm)
- Wind MUST be horizontal
- Rotor ring must be a visible structural element
- Blades must extend from ring ends
- Cone sweep shown as dashed arc
- Colors: brown=ground, green=shaft, magenta=rotor/blades, blue=wind(normal), red=wind(back-wind)
