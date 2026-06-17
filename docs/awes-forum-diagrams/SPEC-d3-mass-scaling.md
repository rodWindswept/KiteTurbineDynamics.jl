# Diagram d3 — Generator-Ready Specification

## Output files
- Source: `docs/awes-forum-diagrams/diagram3-mass-scaling-v4.tex`
- Render: `docs/awes-forum-diagrams/d3-mass-scaling.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=18cm,margin=0.5cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.85]
```

## Title area
- Main: `\bfseries\Huge` at (11.5, 13.5) — "Why the Optimiser Chose n=12: Beam Formula vs System Reality"
- Subtitle: `\large` at (11.5, 12.7) — "The beam-only formula (n·sin(π/n)) gives only 1.20× penalty at n=12 — coupled knuckle savings dominate."

## Left panel: Beam-Only Model (red-tinted)
- Scope: `shift={(0,0)}`
- Background: `\fill[red!3, rounded corners=6pt] (-0.5,-2.0) rectangle (9.0,11.2)`
- Title: `\bfseries\Large red!60!black` at (4.25, 10.6) — "Beam-Mass-Only Model"
- Subtitle: `\small red!50!black` at (4.25, 10.1) — "m ∝ n·sin(π/n) — verified from code"

### Bars (CORRECTED values — n·sin(π/n), NOT n·√sin)
Each bar: width 1.1, centered at x=1.2 + i×1.6 for i=0..4
Height = value × 3.0 (to fill the panel)

| n  | value | height | x-center | label |
|----|-------|--------|----------|-------|
| 3  | 1.000 | 3.00   | 1.2      | 1.00× |
| 6  | 1.155 | 3.47   | 2.8      | 1.15× |
| 8  | 1.178 | 3.53   | 4.4      | 1.18× |
| 10 | 1.189 | 3.57   | 6.0      | 1.19× |
| 12 | 1.195 | 3.58   | 7.6      | 1.20× |

CRITICAL: These values come from n·sin(π/n), verified in Phase 2.4.
The old n·√sin(π/n) values (1.00, 1.52, 1.77, 1.99, 2.19) are WRONG.

- Bar color: `red!40`
- Label color: `red!70!black`, `\footnotesize`
- X-axis: `\draw[->, thick] (0.5,1.5) -- (9.2,1.5)` with label "$n$"
- X ticks at each bar center, `\footnotesize`
- Y-axis: `\footnotesize, rotate=90` at (0.0, 5.0) — "Normalised beam mass"
- Annotation: `\small\bfseries red!70!black` at (2.8, 8.0) — "n=3 lightest (but only by 20%)"
  with arrow to n=3 bar

## Transition
- Arrow: `\draw[->, line width=4pt, >=stealth, magenta!60] (9.4, 5.5) -- (11.0, 5.5)`
- Label: `\bfseries\small` at (10.2, 6.8) — "Coupled system effects"

## Right panel: System Result (blue-tinted)
- Scope: `shift={(11.5,0)}`
- Background: `\fill[blue!2, rounded corners=6pt] (-0.5,-2.0) rectangle (11.5,11.2)`
- Title: `\bfseries\Large blue!60!black` at (5.5, 10.6) — "V6.2 Campaign Result"
- Subtitle: `\small blue!50!black` at (5.5, 10.1) — "DE optimizer, 60 islands × 10,000 iterations"

### Single optimum marker (not a curve)
- Large green filled circle at (6.0, 5.0), radius 8pt
- Label: `\bfseries\Large green!50!black` — "74.17 kg"
- Sub-label: `\small` — "n = 12"

### Convergence context
- `\small` at (5.5, 7.5): "58/60 islands converged to 70–75 kg"
- `\small` at (5.5, 6.5): "Optimum: n=12, β=−0.13, n_exp=1"

### Mechanism box
- `\footnotesize, fill=white, draw=blue!20, rounded corners=3pt` at (5.5, 2.5):
  "Why n=12 wins despite beam penalty:"
  "1. Beam formula gives only 1.20× at n=12"
  "2. Thinner beams → smaller coupled knuckles"
  "3. Tether↑ and rotor↑ penalties are modest"
  "→ System optimum at n=12"

### Constraint disclosure
- `\tiny black!40` at (5.5, -0.5): "Note: single-parameter sweeps infeasible — optimum sits at a sharp constraint intersection"

## Bottom summary
- Background: `\fill[black!3, rounded corners=6pt] (-0.5,-2.8) rectangle (23.0,-1.8)`
- Text at (11.2, -2.3): `\small\bfseries` — "Beam-only (n·sin(π/n)): 1.20× penalty at n=12. Coupled knuckle savings dominate. 58/60 DE islands converge to 70–75 kg at n=12."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram3-mass-scaling-v4.tex
# Zero Error lines

pdftoppm -png -r 300 diagram3-mass-scaling-v4.pdf d3-mass-scaling
mv d3-mass-scaling-1.png d3-mass-scaling.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d3-mass-scaling.png')
arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500, 'Too narrow'
assert 100*nw/tot > 2.0, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'n·sin' && echo 'Formula OK'
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q '1.20' && echo 'Values OK'
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q '74.17' && echo 'Optimum OK'
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q '58/60' && echo 'Convergence OK'
# Must NOT contain old wrong formula:
! pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'n.*sqrt.*sin' && echo 'Old formula absent OK'
```
