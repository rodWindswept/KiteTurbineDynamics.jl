# Diagram d5 — Generator-Ready Specification

## Status
**AWAITING DASHBOARD VERIFICATION.** Rod will check the interactive GLMakie dashboard to see what banked expansion rotor blades look like before generation proceeds. This spec provides exact coordinates for generation once geometry is confirmed.

## Output files (when generated)
- Source: `docs/awes-forum-diagrams/diagram5-bank-angle-expansion.tex`
- Render: `docs/awes-forum-diagrams/d5-bank-angle-expansion.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=28cm,margin=0.3cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.85]
```

## Title area
- `\bfseries\Huge` at (15.0, 21.5) — "Expansion Rotor Bank Angle & Pitch Depower Risk"

## Left panel: Normal Operation
- Scope: `shift={(0, 1.5)}`
- Frame: `\fill[black!1, rounded corners=6pt] (-0.5,-0.5) rectangle (14.5,19.0)`
- Title: `\bfseries\Large` at (7.0, 18.3) — "Normal Operation: Rotor Spreading"

### Geometry (CRITICAL — to be verified in dashboard)
- Ground: `\draw[brown!60!black, line width=4pt] (0.5, 0.2) -- (13.5, 0.2)`, labeled "ground"
- Shaft: `\draw[green!50!black, line width=1.2pt] (2.0, 0.2) -- (11.5, 5.7)`, labeled "shaft 30°"
  - Direction vector: (cos30°, sin30°) = (0.866, 0.5)
- Rotor ring centre: (6.0, 2.5) on shaft
  - Perpendicular direction: (−sin30°, cos30°) = (−0.5, 0.866)
  - Ring endpoints: (5.55, 1.72) to (6.45, 3.28), length ~0.93
  - Color: `magenta, line width=1.8pt`, labeled "rotor ring"
- Upper blade: from ring top (6.45, 3.28) to (4.85, 4.20) — banked outward ~45°
  - Color: `magenta, line width=2.5pt`
- Lower blade: from ring bottom (5.55, 1.72) to (5.85, −0.50) — banked outward ~45°
  - Color: `magenta, line width=2.5pt`
- Bank angle arc: `\draw[->, red!60, line width=1pt] (6.2, 3.7) arc (120:60:0.8)`
  - Label: `\small red!60` — "bank 45°"
- Cone sweep: `\draw[magenta!30, line width=0.6pt, densely dashed] (5.85, −0.5) arc (−70:60:2.8 and 1.3)`
- Wind: `\draw[->, blue!50, line width=3pt] (0.3, 5.0) -- (4.0, 2.5)`, labeled "wind"
  - **WIND MUST BE HORIZONTAL. Y-coordinates of start and end must be equal.**
  - CORRECT: (0.3, 3.0) -- (4.0, 3.0) — both y=3.0
- Callout: `\node[fill=cyan!10, draw=cyan!50!black, rounded corners=3pt]` at (3.3, 4.6) — "expansion rotor blade"
  - Arrow pointing to upper blade tip

### Force diagram (compact, bottom-left)
- Scope: `shift={(1.5, -3.0)}`
- Title: `\bfseries\small` — "Blade forces (normal):"
- Wind vector: from left to origin
- Lift vector: up-right from origin
- F_r (radial): vertical component, dashed, labeled "F_r outward"
- F_a (axial): horizontal component, dashed, labeled "F_a"
- Status: `\bfseries green!50!black` — "Stable: F_r spreads ring"

## Right panel: Pitch Depower
- Scope: `shift={(17, 1.5)}`
- Frame: `\fill[red!2, rounded corners=6pt] (-0.5,-0.5) rectangle (14.5,19.0)`
- Title: `\bfseries\Large red!50!black` at (7.0, 18.3) — "Pitch Depower: Back-Wind Risk"

### Geometry (same mechanical structure, different shaft angle)
- Ground: same as left panel
- Shaft at 50°: `\draw[green!50!black, line width=1.2pt] (2.0, 0.2) -- (9.0, 8.5)`, labeled "shaft 50°"
  - Direction: (cos50°, sin50°) = (0.643, 0.766)
- Rotor ring centre: (5.0, 3.8) on shaft
  - Perpendicular: (−0.766, 0.643) → endpoints (4.5, 3.1) to (5.5, 4.5)
  - Same color, same label as left
- Blades: same mechanical geometry relative to shaft
  - Upper: from (5.5, 4.5) to (3.7, 5.3)
  - Lower: from (4.5, 3.1) to (4.7, 1.0)
- Wind: **STILL HORIZONTAL** — `\draw[->, red!60, line width=3pt] (1.0, 6.5) -- (3.5, 6.5)`
  - Both y=6.5 — horizontal
  - Label: "wind" at (0.5, 7.0)
- BACK-WIND warning: `\bfseries\small red!70` at (9.5, 3.5) — "BACK-WIND"
- Cone sweep: dashed arc from lower blade tip

### Reversed force diagram
- Scope: `shift={(1.5, -3.0)}`
- Title: `\bfseries\small red!50!black` — "Blade forces (back-wind):"
- Wind from above-right
- Lift reversed: pointing down-left
- F_r: downward (inward), dashed, labeled "F_r inward"
- Status: `\bfseries red!70!black` — "Collapsing: F_r reverses"

## Bottom warning bar
- `\fill[red!6, draw=red!40!black, line width=1.2pt, rounded corners=4pt] (-0.5, -4.0) rectangle (31.5, -2.5)`
- `\bfseries\small red!50!black` at (15.5, -3.0): "Static DE optimiser cannot detect transient back-wind collapse — dynamic ODE validation required."
- `\tiny black!50` at (15.5, -3.5): "Mitigation: lower bank angle (20–30°), symmetric airfoils, conservative prototyping"

## CRITICAL: Wind direction verification
The wind arrow must be HORIZONTAL in both panels:
```
Left:  \draw[->, blue!50] (0.3, 3.0) -- (4.0, 3.0);  // both y=3.0
Right: \draw[->, red!60] (1.0, 6.5) -- (3.5, 6.5);   // both y=6.5
```

## Verification (when generated)
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram5-bank-angle-expansion.tex
# Zero Error lines, 1 page

pdftoppm -png -r 300 diagram5-bank-angle-expansion.pdf d5-bank-angle-expansion
mv d5-bank-angle-expansion-1.png d5-bank-angle-expansion.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d5-bank-angle-expansion.png')
arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500, 'Too narrow'
assert 100*nw/tot > 1.5, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

pdftotext diagram5-bank-angle-expansion.pdf - | grep -q 'Expansion Rotor' && echo 'Title OK'
pdftotext diagram5-bank-angle-expansion.pdf - | grep -q 'BACK-WIND' && echo 'Warning OK'
pdftotext diagram5-bank-angle-expansion.pdf - | grep -q 'dynamic ODE' && echo 'Footer OK'
```
