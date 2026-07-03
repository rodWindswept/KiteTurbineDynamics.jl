# AWES Forum Diagrams — Context & Regeneration

Diagrams for the AWES Forum report, V6.2→V10 campaign analysis, and non-dimensional
atlas. Generated from TikZ/LaTeX sources and Python GLMakie renders.

## Regeneration

Every diagram has a **source** (`.tex` or Python script) and a **spec** (`.md`).
To regenerate at full resolution:

```bash
# TikZ diagrams: compile the .tex source
cd docs/awes-forum-diagrams
pdflatex diagram1-polygon-v4.tex
pdftoppm -png -r 300 diagram1-polygon-v4.pdf diagram1-polygon-v4

# GLMakie diagrams: run the render script from repo root
julia --project=. scripts/render_*.jl
```

## Diagram Inventory

### Diagrams d1–d5: AWES Forum Report (V6.2 era)

These five diagrams form the core narrative of the June 2026 forum report, showing
the V6.2 optimisation results and the design-space landscape at 50 kW.

| Diagram | Source | Spec | What it shows | Why it matters |
|---------|--------|------|---------------|----------------|
| **d1 — Polygon comparison** | `diagram1-polygon-v4.tex` | `SPEC-d1-polygon-comparison.md` | Triangle(3) vs pentagon(5) vs dodecagon(12) ring geometries; trade-off between fewer lines (lighter) and more lines (stronger) | Shows why V6.2 settled on n=12 — the structural benefit of more lines outweighs the mass cost |
| **d2 — Density profile** | `diagram2-density-v4.tex` | `SPEC-d2-density-profile.md` | Variable-density ring spacing (β parameter): how biasing rings toward the bottom changes structural mass distribution | The density profile parameter lets the optimiser concentrate rings where compression is highest |
| **d3 — Mass scaling** | `diagram3-mass-scaling-v4.tex` | `SPEC-d3-mass-scaling.md` | Airborne mass vs power from 1 kW to 100 kW; historical campaign progression V2→V6.2 | Shows the empirical mass ∝ P^1.35 scaling law and each campaign's contribution |
| **d4 — Optimisation landscape** | `diagram4-optimization-landscape.tex` | `SPEC-d4-optimization-landscape.md` | 4-panel trade-off landscape: n_lines, density profile, n_expansion, and stacked TRPT comparison | Visualises the multi-dimensional constraint cliffs the optimiser navigates |
| **d5 — Bank angle & expansion** | `diagram5-bank-angle-expansion-v5.tex` | `SPEC-d5-bank-angle-expansion.md` | Expansion rotor bank angle geometry: blade tip clearance, back-wind constraint, geometric derivation of the 25° limit | Shows why bank angle was tightened from 45°→35°→25° and the physics behind it |

### Convergence & Campaign Diagnostics (d6–d7, V6.5→V9)

| Diagram | Source | What it shows | Why it matters |
|---------|--------|---------------|----------------|
| **d6 — Convergence cascade** | `d6-convergence-cascade.tex` | Island-by-island convergence across 60 DE islands; which islands found the global basin vs got stuck | Reveals population collapse, constraint cliff detection, and the multi-start DE strategy |
| **d7 — Parameter convergence** | `d7-param-convergence.tex` | How individual design parameters converge across DE iterations | Identifies which parameters are tightly constrained and which are free |

### V10 Non-Dimensional Atlas (June 2026)

Generated via GLMakie headless render pipeline. 14-DoF design space, unified rotors.

| Diagram | Source | What it shows |
|---------|--------|---------------|
| `v10-parameter-atlas.png` | `v10-nondimensional-atlas.md` | Full 14-parameter panel grid showing feasible region boundaries |
| `v10-panel-*.png` (11 panels) | GLMakie render | Individual parameter slices: n-lines, target-Lr, bank, rotor count, radii, t-over-D, mass, lambda |
| `v10-parameter-pairs.png` | GLMakie | 2D scatter matrix of parameter correlations |
| `v10-3d-landscape.png` | GLMakie | 3D mass landscape over two key parameters |
| `v10-landscape.png` | GLMakie | 2D heatmap of feasible mass landscape |
| `v10-traced-paths.png` | `v10-traced-paths.md` | Island convergence paths through the parameter space |
| `v10-tight-atlas.png` | `v10-tight-diagrams.md` | V10 Tight (49.2 kg) parameter atlas — **dynamically dead** |
| `v10-tight-nondim.png` | `v10-tight-nondim-explainer.md` | Non-dimensional analysis of why V10 Tight fails dynamically |

### Superseded Diagrams

| Diagram | Superseded by | Reason |
|---------|--------------|--------|
| `d6-convergence-cascade-2.png` | `d6-convergence-cascade.png` | Earlier version with different colour scheme |
| `diagram5-bank-angle-expansion-v3-2.png`, `v4.png` | `diagram5-bank-angle-expansion-v5.png` | Iterative refinement of bank angle geometry (superseded angles: 45°, 35°) |
| `diagram1-polygon-v4.png` through `diagram4-optimization-landscape.png` | d1–d4 v4 versions above | v4 numbering; content identical to d1–d4 |

## Key Narrative

See `NARRATIVE.md` for the full physics narrative connecting these diagrams into a
coherent story: the tan→sin correction, the dodecagon breakthrough at 74 kg, the
parasitic drag discovery that invalidated V6.3–V6.5, and the V10 unified-rotor
architecture. See `awes-forum-v62-report.md` for the corrected forum report text.

## Future Regeneration

To regenerate these diagrams for a new campaign (e.g., V11 or beyond):

1. Update the campaign result JSON paths in the render scripts
2. Recompile the TikZ sources with updated data values
3. Run the GLMakie render pipeline
4. The `.tex` and `.md` spec files are the permanent source of truth — the PNGs are
   cached renders that can always be regenerated at higher resolution
