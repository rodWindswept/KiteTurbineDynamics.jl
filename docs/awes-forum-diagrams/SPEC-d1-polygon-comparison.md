# Diagram d1 — Generator-Ready Specification (v4 — space-budgeted)

## Space budget
- Paper: 36×28cm (widened from 26 to fit expanded findings box)
- Scale: 0.82
- Findings box: x∈[−15,15], y∈[−8.5,−15.5], width 30cm→24.6cm real, height 7cm→5.7cm real
- Font: `\footnotesize` (8pt, 3.75mm/line) → 15 lines available
- Text width: 28cm → ~85 chars/line at 8pt
- Narrative: 765 chars → 9 lines → FITS with 6 lines margin

## The story
71% mass reduction (259→74 kg) from three coupled factors, NOT just polygon change:
1. Coupled knuckle mass exposed true cost of thick beams
2. Expansion rotor consolidation: 3 rotors → 1 rotor
3. Corrected physics: tan→sin, cos³→cos²·⁶⁵

## Output files
- Source: `docs/awes-forum-diagrams/diagram1-polygon-v4.tex`
- Render: `docs/awes-forum-diagrams/d1-polygon-comparison.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=28cm,margin=0.5cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.82]
```

## Title area (y positive = up from center)
- Main: `\Huge\bfseries` at (0, 9.5) — "The Polygon Flip: Why {\color{green!50!black}12} Lines Beat {\color{blue!60!black}8}"
- Sub: `\large` at (0, 8.5) — "Beam-only scaling says fewer lines are lighter. The DE optimiser found the opposite — 71% mass reduction."

## Left panel: V6 Baseline (blue)
- Scope: `xshift=-9.5cm, yshift=0.5cm`
- Box: `(-4.5,-6.5)` to `(4.5,4.0)`, `fill=blue!3`
- Title: `\bfseries\Large blue!60!black` at (0, 3.4) — "V6 Baseline"
- Sub: `\Large\bfseries blue!60!black` at (0, 2.7) — "8-line octagon"
- Octagon: r=2.5, vertices at 22.5°+k×45°, `blue!70!black, line width=1.3pt`
- Vertices: `red!60!black` circles r=3.5pt
- Stats at (0, −2.3): `\footnotesize` — "Mass: 259 kg  |  Do: 118 mm", "Per-beam: N/8, 8 knuckles", "3 expansion rotors at intermediate rings"
- Trig at (0, −3.8): `\small blue!50!black` — "sin(π/8)=0.383  |  n·sin(π/n)=2.86"
- Note at (0, −5.3): `\footnotesize\itshape blue!40!black` — "Thick beams (118 mm): need 3 expansion\\rotors to share high per-beam load"

## Transition arrow
- `\draw[->, line width=5pt, >=stealth, green!50!black] (-4.0,1.0) -- (4.0,1.0)`
- `\bfseries\Huge green!50!black` at (0, 2.2): "−71%"
- `\large green!50!black` at (0, 1.4): "259 kg → 74 kg"

## Right panel: V6.2 Optimum (green)
- Scope: `xshift=9.5cm, yshift=0.5cm`
- Box: `(-4.5,-6.5)` to `(4.5,4.0)`, `fill=green!3`
- Title: `\bfseries\Large green!50!black` at (0, 3.4) — "V6.2 Optimum"
- Sub: `\Large\bfseries green!50!black` at (0, 2.7) — "12-line dodecagon"
- Dodecagon: r=2.5, vertices at 15°+k×30°, `green!50!black, line width=0.8pt`
- Vertices: `red!60!black` circles r=2.5pt
- Stats at (0, −2.3): `\footnotesize` — "Mass: 74 kg  |  Do: 95 mm", "Per-beam: N/12, 33% lower", "1 expansion rotor at hub only"
- Trig at (0, −3.8): `\small green!50!black` — "sin(π/12)=0.259  |  n·sin(π/n)=6.10"
- Note at (0, −5.3): `\footnotesize\itshape green!40!black` — "Thin beams (95 mm): single hub expansion\\rotor suffices — straight shaft"

## Findings box (BELOW both panels)
- Frame: `\fill[black!4, draw=gray!40, rounded corners=8pt] (-15.0,-8.5) rectangle (15.0,-15.5)`
- Title at (0, −7.5): `\bfseries\large black!60` — "What this reveals about the TRPT scaling problem:"
- Body at (0, −12.0) with `\footnotesize, align=left, black!65, text width=28cm`:
  "Three factors drove the 71\% mass reduction (259$\rightarrow$74 kg), not just the polygon change:\\\\[3pt]
  \\textbf{1. Coupled knuckle mass:} The old model used fixed 0.005 kg knuckles regardless of beam diameter. The corrected model derives knuckle mass from beam geometry — 118 mm beams cost far more in knuckle weight than 95 mm beams, exposing the true cost of the V6 baseline.\\\\[3pt]
  \\textbf{2. Expansion rotor consolidation:} V6 needed 3 expansion rotors at intermediate rings to share the high per-beam load (N/8 compression). At n=12, per-beam compression drops to N/12 — 4$\times$ lower — so a single hub expansion rotor is sufficient. Going from 3 rotors to 1 saves substantial blade and hardware mass.\\\\[3pt]
  \\textbf{3. Corrected physics:} The tan$\rightarrow$sin polygon force correction and cos$^3\rightarrow$cos$^{2.65}$ elevation correction eliminated artificial safety margins that had hidden the true structural cost."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram1-polygon-v4.tex
# Assert: 1 page, 0 errors

pdftoppm -png -r 300 diagram1-polygon-v4.pdf d1-polygon-comparison
mv d1-polygon-comparison-1.png d1-polygon-comparison.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d1-polygon-comparison.png')
arr = np.array(img); nw = (arr < 240).any(axis=2).sum(); tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500, f'Too narrow: {img.size[0]}'
assert 100*nw/tot > 1.5, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

# Text completeness checks — every key sentence must end properly
pdftotext diagram1-polygon-v4.pdf - | grep -q 'Coupled knuckle' && echo 'Factor 1 OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q 'Expansion rotor consolidation' && echo 'Factor 2 OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q 'Corrected physics' && echo 'Factor 3 OK'
# Verify text isn't truncated — check for terminal punctuation
pdftotext diagram1-polygon-v4.pdf - | grep -q 'structural cost\.' && echo 'Text complete OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q '259.*kg' && echo 'Left stats OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q '74.*kg' && echo 'Right stats OK'
```
