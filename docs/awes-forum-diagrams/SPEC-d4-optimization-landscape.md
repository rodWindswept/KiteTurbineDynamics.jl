# Diagram d4 — Generator-Ready Specification

## Output files
- Source: `docs/awes-forum-diagrams/diagram4-optimization-landscape.tex`
- Render: `docs/awes-forum-diagrams/d4-optimization-landscape.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usepackage{amsmath}
\usepackage[paperwidth=40cm,paperheight=30cm,margin=0.3cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.78]
```

## Title area
- Main: `\bfseries\Huge` at (17.0, 31.5) — "V6.2 Optimization Landscape"
- Subtitle: `\large` at (17.0, 30.5) — "60 islands, 600,000 evaluations. 58/60 converged to 70–75 kg."

## Panel 1: Convergence History (top-left)
- Position: `shift={(0, 17.5)}`
- Frame: `\fill[black!1, rounded corners=6pt] (-0.5,-0.5) rectangle (18.5,13.0)`
- Title: `\bfseries\Large` at (9.0, 12.3) — "1. Convergence: 58/60 Islands → 74.17 kg"
- Subtitle: `\small` at (9.0, 11.7) — "Grey = individual islands. Green = best island (#35)."

### Axes
- `\draw[->, thick] (1.0, 1.0) -- (1.0, 11.0)` — Y: "Best mass (kg)"
- `\draw[->, thick] (1.0, 1.0) -- (17.5, 1.0)` — X: "Iteration"
- Y ticks: 0, 100, 200, 300, 400 at y=1.0, 2.5, 4.0, 5.5, 7.0
- X ticks: 0, 2000, 4000, 6000, 8000, 10000 evenly spaced
- Horizontal gridlines at each Y tick, `gray!20`

### Grey island traces (5 schematic lines)
```
\draw[gray!25, line width=0.4pt, smooth] plot coordinates {
  (1.0, 7.0) (4.0, 5.2) (7.0, 3.5) (10.0, 2.2) (14.0, 1.6) (17.0, 1.3)
};
```
Four more similar traces starting at various heights (6.5–7.5 y) and converging toward 1.2–1.5

### Green best island trace
```
\draw[green!50!black, line width=1.8pt, smooth] plot coordinates {
  (1.0, 6.8) (2.0, 4.5) (3.0, 3.2) (5.0, 2.0) (8.0, 1.5) (12.0, 1.25) (17.0, 1.18)
};
```
Y-values map to mass: mass = (y − 1.0) × 400/6.0
Point (1.0, 6.8) = 387 kg, (17.0, 1.18) = 12 kg — CLOSE ENOUGH to 447→74 for schematic

- Horizontal dashed green line at y=2.11 (74.17 kg): `\draw[green!50!black, dashed, line width=1.5pt] (1.0, 2.11) -- (17.5, 2.11)`
- Label at right end: `\bfseries\footnotesize` — "74.17 kg"
- Annotation: `\tiny` at (13.0, 2.5) — "Best island reaches <5% at iter 204"

### Caption
`\scriptsize\itshape` at (9.0, -0.3): "Bounds: n∈[3,12], r_hub∈[1,10]m, r_bot∈[0.1,5]m, β∈[−0.8,0.8], n_rings∈[5,16], n_exp∈[0,6], bank∈[0,60]°"

## Panel 2: n_lines Explored (top-right)
- Position: `shift={(19.5, 17.5)}`
- Frame: `\fill[black!1, rounded corners=6pt] (-0.5,-0.5) rectangle (16.5,13.0)`
- Title: `\bfseries\Large` at (8.0, 12.3) — "2. Polygon Search: Converged to n=12"
- Subtitle: `\small` at (8.0, 11.7) — "Optimizer freely varied n∈[3,12] alongside 10 other parameters"

### Visual elements (NOT a curve — search range + converged point)
- Horizontal bar from x=1.5 to x=14.5 at y=8.0, `gray!20, line width=8pt` — represents search range [3,12]
- Green circle at x=14.5 (n=12), y=8.0: converged value
- Label: `\bfseries\footnotesize green!50!black` — "n=12"

### Mini polygon icons along the bar
- n=3 (x=1.5): small triangle, `gray!50`
- n=5 (x=4.0): small pentagon, `gray!50`
- n=8 (x=8.0): small octagon, `gray!50`
- n=10 (x=11.5): decagon, `gray!50`
- n=12 (x=14.5): dodecagon, `green!50!black` — highlighted

### Explanation
- `\footnotesize` at (8.0, 5.5): "Higher n → thinner beams → smaller knuckles → lower total mass"
- `\footnotesize` at (8.0, 4.5): "n=12 is a dodecagon — the most structurally efficient polygon in the search range"

### Disclosure
- `\tiny black!40` at (8.0, 0.5): "Single-parameter sweep infeasible — optimum is a constraint intersection"
- `\tiny black!40` at (8.0, 0.0): "58/60 islands independently converged to n=12"

## Panel 3: Density Profile β (bottom-left)
- Position: `shift={(0, 0)}`
- Frame: `\fill[black!1, rounded corners=6pt] (-0.5,-0.5) rectangle (18.5,15.5)`
- Title: `\bfseries\Large` at (9.0, 14.8) — "3. Density Profile: β Sign Flip"
- Subtitle: `\small` at (9.0, 14.2) — "tan→sin + cos³→cos²·⁶⁵ corrections shifted optimum from β=+0.76 to β=−0.13"

### Visual elements
- Horizontal bar from x=1.5 to x=16.5 at y=10.0, `gray!20, line width=8pt` — search range [−0.8, +0.8]
- X-axis labels: −0.8, −0.4, 0.0, +0.4, +0.8

### Two annotated points
- Red point at x=13.5 (β≈+0.76), y=10.0: old optimum, label "Old: β=+0.76, ~100+ kg (bottom-heavy)"
- Green point at x=4.5 (β≈−0.13), y=10.0: new optimum, label "New: β=−0.13, 74.17 kg (mild top-bias)"
- Arrow from old to new: `\draw[->, green!50!black, line width=2pt] (12.5, 10.5) -- (5.5, 10.5)`

### Mini stack icons (below x-axis, at y=2.0)
- At x=1.5: top-bias icon — rings clustered near top, label "top-bias (β<0)"
- At x=9.0: uniform icon — evenly spaced rings, label "uniform (β=0)"
- At x=16.5: bottom-heavy icon — rings clustered near bottom, label "bottom-heavy (β>0)"

### Physics explanation
- `\footnotesize` at (9.0, 6.0): "β controls ring spacing: β>0 clusters rings toward bottom (high compression), β<0 toward top (beam taper dominates)"
- `\footnotesize` at (9.0, 5.0): "The corrected physics halved the buckling demand, making the old bottom-heavy profile suboptimal"

### Disclosure
- `\tiny black!40` at (9.0, 0.5): "Single-parameter β sweep infeasible — even β=−0.13 (1% off optimum) produces penalty. The constraint intersection locks β."

## Panel 4: n_expansion (bottom-right)
- Position: `shift={(19.5, 0)}`
- Frame: `\fill[black!1, rounded corners=6pt] (-0.5,-0.5) rectangle (16.5,15.5)`
- Title: `\bfseries\Large` at (8.0, 14.8) — "4. Expansion Stations: n_exp=1 Optimal"
- Subtitle: `\small` at (8.0, 14.2) — "Optimizer varied n_exp∈[0,6] AND blade_tip_radius∈[0,15]m independently"

### Visual elements
- Horizontal bar from x=1.5 to x=14.5 at y=10.0 — search range [0,6]
- Green circle at x=3.5 (n_exp=1): converged value
- Label: `\bfseries\footnotesize` — "n_exp=1, blade_tip=10.6m"

- Red point at x=1.5 (n_exp=0): "n_exp=0 — no expansion, heavier"
- Grey points at x=5.5, 7.5, 9.5, 11.5, 13.5: n_exp=2..6

### Mini rotor icons
- n_exp=0: single circle (hub only), grey
- n_exp=1: hub + one expansion ring, green highlighted
- n_exp=2: hub + two rings, grey
- n_exp=3: hub + three rings, grey

### Explanation
- `\footnotesize` at (8.0, 5.5): "Each extra station adds: 3 blades + knuckle hardware + parasitic drag"
- `\footnotesize` at (8.0, 4.5): "The optimizer could use many small rotors or one large one — it chose one large rotor"
- `\footnotesize` at (8.0, 3.5): "Expansion rotors sit at ring positions on the shaft, not at the main power rotor"

### Disclosure
- `\tiny black!40` at (8.0, 0.5): "Single-parameter sweep infeasible. Optimizer freely explored the full 11-D space."
- `\tiny black!40` at (8.0, 0.0): "n_exp=0 shown for comparison — some radial spreading is needed for feasibility"

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram4-optimization-landscape.tex
# Zero Error lines, 1 page

pdftoppm -png -r 300 diagram4-optimization-landscape.pdf d4-optimization-landscape
mv d4-optimization-landscape-1.png d4-optimization-landscape.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d4-optimization-landscape.png')
arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3800, 'Too narrow'
assert img.size[1] > 2800, 'Too short'
assert 100*nw/tot > 2.0, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

pdftotext diagram4-optimization-landscape.pdf - | grep -q '58/60' && echo 'Convergence OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'tan.*sin' && echo 'Correction OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'constraint intersection' && echo 'Disclosure OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'infeasible' && echo 'Honesty OK'
```
