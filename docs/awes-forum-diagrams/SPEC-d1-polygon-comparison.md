# Diagram d1 — Generator-Ready Specification

## Output files
- Source: `docs/awes-forum-diagrams/diagram1-polygon-v4.tex`
- Render: `docs/awes-forum-diagrams/d1-polygon-comparison.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=24cm,margin=0.5cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.85]
```

## Title area (tikz coordinates, y positive = up)
- Main title: `\Huge\bfseries` at (0, 8.5) — "The Polygon Flip: Why 12 Lines Beat 8"
  - "12" in `green!50!black`, "8" in `blue!60!black`
- Subtitle: `\large` at (0, 7.7) — "Beam-only scaling says fewer lines are lighter. The DE optimiser found the opposite."

## Left panel: Octagon (blue-tinted)
- Scope: `xshift=-9.5cm, yshift=0.5cm`
- Background: `\fill[blue!3, rounded corners=6pt] (-4.5,-6.0) rectangle (4.5,4.0)`
- Title: `\bfseries\Large` at (0, 3.4) — "V6 Baseline"
- Subtitle: `\Large\bfseries` at (0, 2.7) — "8-line octagon"
- Octagon: radius 2.5, 8 vertices at 22.5° + k×45°, `blue!70!black, line width=1.3pt`
- Vertices: `red!60!black` filled circles, radius 3.5pt
- Stats box at (0, -2.3): `\footnotesize` — "Mass: 259 kg    Do: 118 mm", "Per-beam: N/8, 8 knuckles × 0.11 kg = 0.88 kg"
- Trig line at (0, -3.8): `\small blue!50!black` — "sin(π/8)=0.383    n·sin(π/n)=2.86"
- Note at (0, -5.1): `\footnotesize\itshape blue!40!black` — "Thick beams: expansion rotors needed at intermediate rings to share load"

## Transition arrow
- Arrow: `\draw[->, line width=5pt, >=stealth, green!50!black] (-4.0, 1.0) -- (4.0, 1.0)`
- Label above: `\bfseries\Huge` at (0, 2.2) — "−71%"
- Label below: `\large` at (0, 1.4) — "259 kg → 74 kg"

## Right panel: Dodecagon (green-tinted)
- Scope: `xshift=9.5cm, yshift=0.5cm`
- Background: `\fill[green!3, rounded corners=6pt] (-4.5,-6.0) rectangle (4.5,4.0)`
- Title: `\bfseries\Large` at (0, 3.4) — "V6.2 Optimum"
- Subtitle: `\Large\bfseries` at (0, 2.7) — "12-line dodecagon"
- Dodecagon: radius 2.5, 12 vertices at 15° + k×30°, `green!50!black, line width=0.8pt`
- Vertices: `red!60!black` filled circles, radius 2.5pt
- Stats box at (0, -2.3): `\footnotesize` — "Mass: 74 kg    Do: 95 mm", "Per-beam: N/12, 33% lower, 12 knuckles × 0.10 kg = 1.20 kg"
- Trig line at (0, -3.8): `\small green!50!black` — "sin(π/12)=0.259    n·sin(π/n)=6.10"
- Note at (0, -5.1): `\footnotesize\itshape green!40!black` — "Thin beams handle compression locally: hub-only expansion rotor, straight shaft"

## Findings box (full width, below both panels)
- Background: `\fill[black!4, draw=gray!40, rounded corners=8pt] (-15.0,-8.0) rectangle (15.0,-12.5)`
- Title at (0, -7.2): `\bfseries\large` — "What this reveals about the TRPT scaling problem:"
- Body at (0, -10.0): `\small, text width=28cm` — "The beam-mass-only formula (n·sin(π/n)) increases by only 1.20× from n=3 to n=12 — far less than intuition suggests. Thinner beams at higher n enable dramatically smaller knuckle hardware. The DE optimiser evaluates the full coupled design space — beams, knuckles, tethers, rotor sizing, ring count, density profile, expansion stations — and finds the global minimum at n=12, not n=3 or n=8. This is a system-level inversion of a component-level intuition."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram1-polygon-v4.tex
# Must produce: Output written on diagram1-polygon-v4.pdf (1 page)
# Zero LaTeX Error lines in .log

pdftoppm -png -r 300 diagram1-polygon-v4.pdf d1-polygon-comparison
mv d1-polygon-comparison-1.png d1-polygon-comparison.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d1-polygon-comparison.png')
arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500, 'Too narrow'
assert 100*nw/tot > 1.5, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

pdftotext diagram1-polygon-v4.pdf - | grep -q 'Polygon Flip' && echo 'Title OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q '259 kg' && echo 'Left stats OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q '74 kg' && echo 'Right stats OK'
pdftotext diagram1-polygon-v4.pdf - | grep -q 'system-level inversion' && echo 'Findings box OK'
```
