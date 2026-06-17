# Diagram d3 — Generator-Ready Specification (v4 — space-budgeted)

## Space budget
- Paper: 36×20cm, scale=0.82 → effective 29.5×16.4cm
- Right panel: 11.5 tikz units wide → 9.4cm real
- 3-factor explanation box: at (5.5, 3.5), text width ~7cm → ~30 chars/line at `\footnotesize`
- Text: 251 chars → 9 lines, box height ~4cm → 10 lines available → FITS
- Bottom summary: 23cm wide, 1 line, fits

## The story
Beam formula (n·sin(π/n)) gives only 1.20× penalty at n=12. The beam ring alone is barely heavier. The real mass drivers are: (1) knuckle coupling — thinner beams → smaller knuckles, (2) expansion rotor consolidation — 3 rotors → 1 rotor. The beam formula is the smallest factor; the coupled system effects dominate.

## Output files
- Source: `docs/awes-forum-diagrams/diagram3-mass-scaling-v4.tex`
- Render: `docs/awes-forum-diagrams/d3-mass-scaling.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=20cm,margin=0.5cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.82]
```

## Title
- `\bfseries\Huge` at (11.5, 14.0): "Why n=12 Wins: Beam Formula vs System Reality"
- `\large` at (11.5, 13.0): "Beam formula (n·sin(π/n)): only 1.20× penalty. Knuckle coupling + expansion rotor consolidation dominate."

## Left panel: Beam-Only Model (red)
- Scope: `shift={(0,0)}`, frame: `fill=red!3, (-0.5,-2.0) rectangle (9.0,11.5)`
- Title: `\bfseries\Large red!60!black` at (4.25, 10.9) — "Beam-Mass-Only Model"
- Sub: `\small red!50!black` at (4.25, 10.3) — "m ∝ n·sin(π/n) — verified from structural code"

### Bars (CORRECTED n·sin, NOT n·√sin)
| n  | val   | bar ht | x-ctr | label |
|----|-------|--------|-------|-------|
| 3  | 1.000 | 3.00   | 1.2   | 1.00× |
| 6  | 1.155 | 3.47   | 2.8   | 1.15× |
| 8  | 1.178 | 3.53   | 4.4   | 1.18× |
| 10 | 1.189 | 3.57   | 6.0   | 1.19× |
| 12 | 1.195 | 3.58   | 7.6   | 1.20× |

- Bar width: 1.1, centered, `fill=red!40`
- Labels: `\footnotesize red!70!black`
- X-axis: `\draw[->, thick] (0.5,1.5) -- (9.2,1.5)`, label "$n$", ticks at bar centers
- Y-axis: `\footnotesize, rotate=90` — "Normalised beam mass"
- Annotation at (2.8, 8.5): `\small\bfseries red!70!black, fill=white, draw=red!30` — "n=3 lightest\\ (but only by 20%)"
- Arrow to n=3 bar

## Transition
- Arrow: `\draw[->, line width=4pt, >=stealth, magenta!60] (9.4, 5.5) -- (11.0, 5.5)`
- Label: `\bfseries\small magenta!60` — "Coupled system effects dominate"

## Right panel: System Reality (blue)
- Scope: `shift={(11.5,0)}`, frame: `fill=blue!2, (-0.5,-2.0) rectangle (11.5,11.5)`
- Title: `\bfseries\Large blue!60!black` at (5.5, 10.9) — "V6.2 Campaign Result"
- Sub: `\small blue!50!black` at (5.5, 10.3) — "DE optimiser, 60 islands × 10,000 iterations"

### Optimum marker
- Large green filled circle at (6.0, 7.5), r=8pt, with green ring r=10pt
- Label `\bfseries\Large green!50!black`: "74.17 kg at n=12"
- Convergence: `\small blue!70!black` at (5.5, 6.5) — "58/60 islands converged to 70–75 kg"

### Three-factor narrative box
- At (5.5, 3.5) `\footnotesize, fill=white, draw=blue!20, rounded corners=3pt, inner sep=4pt, text width=9cm`:
  "\\textbf{Why n=12 wins despite 1.20× beam penalty:}\\\\[2pt]
  \\textbf{1. Knuckle coupling:} Thinner beams (95 vs 118 mm)\\\\
  \\quad $\\rightarrow$ dramatically smaller knuckle hardware.\\\\[2pt]
  \\textbf{2. Rotor consolidation:} n=12 needs 1 hub rotor;\\\\
  \\quad V6 at n=8 needed 3. Each rotor adds blades + drag.\\\\[2pt]
  \\textbf{3. Beam formula:} Only 1.20× penalty — the\\\\
  \\quad knuckle and rotor savings overwhelm it."

### Constraint note
- `\tiny black!40` at (5.5, -0.8): "Single-parameter sweeps infeasible — optimum is a constraint intersection"

## Bottom summary
- Bar: `\fill[black!3, rounded corners=6pt] (-0.5,-3.0) rectangle (23.0,-2.0)`
- `\small\bfseries` at (11.2, -2.5): "Beam-only (n·sin): 1.20× penalty. Knuckle coupling + expansion rotor consolidation (3→1) dominate. 58/60 islands converge to 74.17 kg at n=12."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram3-mass-scaling-v4.tex
pdftoppm -png -r 300 diagram3-mass-scaling-v4.pdf d3-mass-scaling
mv d3-mass-scaling-1.png d3-mass-scaling.png
python3 -c "from PIL import Image; import numpy as np; img=Image.open('d3-mass-scaling.png'); arr=np.array(img); nw=(arr<240).any(axis=2).sum(); assert img.size[0]>3500 and 100*nw/(arr.shape[0]*arr.shape[1])>2.0; print('OK')"
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'Rotor consolidation' && echo 'Narrative OK'
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'Knuckle coupling' && echo 'Factor 1 OK'
! pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'sqrt.*sin' && echo 'Old formula absent OK'
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q '74\.17' && echo 'Optimum value OK'
```
