# Video Production: Windswept Kite Turbine — Current State & Invitation

**Last updated:** 2026-06-22 — scope updated to reflect V10 Tight results and Agents-K1 pipeline.

## Project Files

1. **[SCRIPT_NARRATIVE.md](SCRIPT_NARRATIVE.md)** — The second-by-second voiceover script, visual directives, overlay designs, and SFX cues. **This is the authoritative transcript.**
2. **[ANIMATION_SPEC.md](ANIMATION_SPEC.md)** — Technical specs for rendering data sweeps, 3D model overlays, and math visualization formulas.
3. **[README.md](README.md)** — This project overview.

## What Changed

The original 3-minute script was written in the V6.2/V6.3/V10 era with the expansion rotor narrative. Since then:

| Development | Impact on Script |
|-------------|-----------------|
| **V10 Tight: 49.2 kg** | Replaces 76.75 kg as the headline result. 35% mass reduction. 4 rotors. |
| **k_mppt λ² fix** | Explains HOW multi-rotor became viable — generator control coefficient must scale with tip-speed ratio squared |
| **Ring-mapping +2 offset** | Second correction that unlocked correct rotor placement |
| **Static-vs-dynamic gap** | Honest acknowledgment that static solver predicts 50 kW but dynamic shows 12 kW — the real engineering challenge |
| **5 parameters at bounds** | The optimizer is screaming for more design freedom — this is the scientific signal |
| **Tension-only constraint** | Hard physics gate: every line, bridle, and tether must transmit force only in tension |
| **Agents-K1** | 540 AWES papers ingested into a scholar knowledge graph — 7,401 nodes, queryable |
| **Commercial framing** | Shifted from "here's our research" to "here's an open research programme — come build it with us" |

## Audience & Purpose

- **Primary**: AWEC 2026 attendees, potential collaborators, industry partners
- **Secondary**: Engineers, researchers, investors who understand that lightweight airborne systems are the future of wind energy
- **Goal**: Demonstrate scientific rigor, honest self-criticism, and an open invitation to collaborate

## Production Design System (unchanged)

### Visual & Graphic Style
- **Backgrounds**: Deep matte charcoal/black gradients (`#0B0C10` to `#1F2833`) with subtle glowing gridlines representing the optimization search space.
- **Color Coding**:
  - **Global Optimum (Basin A / V10 Tight)**: Electric Cyan (`#66FCF1`)
  - **Local Attractors (Basin B / Divergent Paths)**: Crimson Red (`#FF0055`)
  - **Intermediates / Exploration Paths**: Amber Gold (`#FFAA00`)
  - **Dynamic Force Overlays**: Electric Blue for compression, Neon Red/Orange for tension
- **Typography**: Inter or Roboto Mono for numerical readouts, parameter values, and formula overlays.
- **Camera Movement**: Cinematic slow 3D orbits, synchronized snap-zooms into data clusters.

### Tooling
- **3D Geometry**: Blender or FreeCAD for TRPT geometry renders
- **Data Animation**: Manim CE or Makie.jl for PCA paths, convergence plots, contour sweeps
- **Editing**: DaVinci Resolve or Premiere Pro for compositing
