# Diagram d1 — Generator-Ready Specification (v3 — narrative-driven)

## The story this diagram tells
The V6.2 optimum (n=12, 74.17 kg) represents a 71% mass reduction from the V6 baseline (n=8, 259 kg). This reduction is NOT primarily from the polygon change (n=8→12). Three factors drove it:

1. **Coupled knuckle mass model** — old model had knuckles at a fixed 0.005 kg regardless of beam diameter. New model derives knuckle mass from beam geometry: thicker beams → heavier knuckles. This exposed the true cost of the V6 baseline's 118 mm beams.
2. **Expansion rotor consolidation** — V6 needed 3 expansion rotors at intermediate rings to share the high per-beam load (N/8 compression). V6.2 at n=12 has 4× lower per-beam compression (N/12), so a single hub expansion rotor suffices. Going from 3 rotors to 1 saves blade and hardware mass.
3. **Corrected physics** — tan→sin (corrected polygon force resolution) and cos³→cos²·⁶⁵ (corrected elevation exponent). The tan formula understated beam compression, making the old design seem safer than it was.

## Output files
- Source: `docs/awes-forum-diagrams/diagram1-polygon-v4.tex`
- Render: `docs/awes-forum-diagrams/d1-polygon-comparison.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=26cm,margin=0.5cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.82]
```

## Title area
- Main: `\Huge\bfseries` at (0, 9.0) — "The Polygon Flip: Why 12 Lines Beat 8"
  - "12" in `green!50!black`, "8" in `blue!60!black`
- Subtitle: `\large` at (0, 8.1) — "Beam-only scaling says fewer lines are lighter. The DE optimiser found the opposite — a 71% mass reduction."

## Left panel: V6 Baseline Octagon
- Scope: `xshift=-9.5cm, yshift=0.5cm`
- Background: `\fill[blue!3, rounded corners=6pt] (-4.5,-6.5) rectangle (4.5,4.0)`
- Title: `\bfseries\Large blue!60!black` at (0, 3.4) — "V6 Baseline"
- Subtitle: `\Large\bfseries blue!60!black` at (0, 2.7) — "8-line octagon"
- Octagon: radius 2.5, 8 vertices, `blue!70!black, line width=1.3pt` (thick = thick beams)
- Vertices: `red!60!black` circles, radius 3.5pt
- Stats at (0, -2.3): `\footnotesize` — "Mass: 259 kg    Do: 118 mm", "Per-beam: N/8, 8 knuckles", "3 expansion rotors at intermediate rings"
- Trig at (0, -3.8): `\small blue!50!black` — "sin(π/8)=0.383    n·sin(π/n)=2.86"
- Note at (0, -5.3): `\footnotesize\itshape blue!40!black, align=center` — "Thick beams (118 mm): need 3 expansion\\rotors to share high per-beam load"

## Transition arrow
- Arrow: `\draw[->, line width=5pt, >=stealth, green!50!black] (-4.0, 1.0) -- (4.0, 1.0)`
- Label above: `\bfseries\Huge green!50!black` at (0, 2.2) — "−71%"
- Label below: `\large green!50!black` at (0, 1.4) — "259 kg → 74 kg"

## Right panel: V6.2 Optimum Dodecagon
- Scope: `xshift=9.5cm, yshift=0.5cm`
- Background: `\fill[green!3, rounded corners=6pt] (-4.5,-6.5) rectangle (4.5,4.0)`
- Title: `\bfseries\Large green!50!black` at (0, 3.4) — "V6.2 Optimum"
- Subtitle: `\Large\bfseries green!50!black` at (0, 2.7) — "12-line dodecagon"
- Dodecagon: radius 2.5, 12 vertices, `green!50!black, line width=0.8pt` (thin = thin beams)
- Vertices: `red!60!black` circles, radius 2.5pt
- Stats at (0, -2.3): `\footnotesize` — "Mass: 74 kg    Do: 95 mm", "Per-beam: N/12, 33% lower", "1 expansion rotor at hub only"
- Trig at (0, -3.8): `\small green!50!black` — "sin(π/12)=0.259    n·sin(π/n)=6.10"
- Note at (0, -5.3): `\footnotesize\itshape green!40!black, align=center` — "Thin beams (95 mm): single hub expansion\\rotor suffices — straight shaft"

## Findings box (below both panels)
- Background: `\fill[black!4, draw=gray!40, rounded corners=8pt] (-15.0,-8.5) rectangle (15.0,-14.0)`
- Title at (0, -7.5): `\bfseries\large black!60` — "What this reveals about the TRPT scaling problem:"
- Body at (0, -11.0) with `\small, text width=28cm`:
  "Three factors drove the 71% mass reduction, not just the polygon change:\\\\[3pt]
  \\textbf{1. Coupled knuckle mass:} Old model used fixed 0.005 kg knuckles regardless of beam diameter. The corrected model derives knuckle mass from beam geometry — 118 mm beams cost far more in knuckle weight than 95 mm beams.\\\\[3pt]
  \\textbf{2. Expansion rotor consolidation:} V6 needed 3 expansion rotors at intermediate rings to share the high per-beam load (N/8). At n=12, per-beam compression drops to N/12 — 4× lower — so a single hub expansion rotor is sufficient. Going from 3 rotors to 1 saves substantial blade and hardware mass.\\\\[3pt]
  \\textbf{3. Corrected physics:} The tan→sin polygon force correction and cos³→cos²·⁶⁵ elevation correction eliminated artificial safety margins that had hidden the true structural cost."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram1-polygon-v4.tex
pdftoppm -png -r 300 diagram1-polygon-v4.pdf d1-polygon-comparison
mv d1-polygon-comparison-1.png d1-polygon-comparison.png
python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d1-polygon-comparison.png')
arr = np.array(img); nw = (arr < 240).any(axis=2).sum(); tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500 and 100*nw/tot > 1.5, f'FAIL: {img.size}, {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}%')
"
pdftotext diagram1-polygon-v4.pdf - | grep -q 'Coupled knuckle' && echo 'Narrative OK'
```
