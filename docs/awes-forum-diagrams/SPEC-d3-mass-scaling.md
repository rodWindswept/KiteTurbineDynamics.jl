# Diagram d3 — Generator-Ready Specification (v3 — narrative-driven)

## The story this diagram tells
The beam-only formula (n·sin(π/n)) gives only a 1.20× penalty from n=3 to n=12. If beams were the whole story, n=3 would be lightest — but only by 20%. The real mass reduction from 259 kg (V6, n=8) to 74 kg (V6.2, n=12) comes from three coupled effects:

1. **Beam thinning:** At n=12, per-beam compression drops to N/12, allowing Do=95mm beams instead of Do=118mm at n=8. The beam formula says this alone is a 1.20× penalty — beams are heavier, but barely.
2. **Knuckle coupling:** Thinner beams (95 vs 118 mm) enable dramatically smaller knuckle hardware. Knuckle mass scales with beam diameter — this is where the real savings come from. The old model with fixed-light knuckles (0.005 kg) hid this effect.
3. **Expansion rotor consolidation:** V6 at n=8 needed 3 expansion rotors at intermediate rings. V6.2 at n=12 needs only 1 hub expansion rotor. Each expansion rotor adds 3 blades + hub hardware + parasitic drag. Going from 3 to 1 is the largest single mass saving.

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

## Title area
- Main: `\bfseries\Huge` at (11.5, 14.0) — "Why n=12 Wins: Beam Formula vs System Reality"
- Subtitle: `\large` at (11.5, 13.1) — "The beam-only formula (n·sin(π/n)) gives only 1.20× penalty at n=12. Coupled knuckles + expansion rotor consolidation dominate."

## Left panel: Beam-Only Model
- Scope: `shift={(0,0)}`
- Background: `\fill[red!3, rounded corners=6pt] (-0.5,-2.0) rectangle (9.0,11.5)`
- Title: `\bfseries\Large red!60!black` at (4.25, 10.9) — "Beam-Mass-Only Model"
- Subtitle: `\small red!50!black` at (4.25, 10.3) — "m ∝ n·sin(π/n) — verified from code"

### Bars (CORRECTED: n·sin, NOT n·√sin)
| n  | value | height | x-center | label |
|----|-------|--------|----------|-------|
| 3  | 1.000 | 3.00   | 1.2      | 1.00× |
| 6  | 1.155 | 3.47   | 2.8      | 1.15× |
| 8  | 1.178 | 3.53   | 4.4      | 1.18× |
| 10 | 1.189 | 3.57   | 6.0      | 1.19× |
| 12 | 1.195 | 3.58   | 7.6      | 1.20× |

- Bar color: `red!40`, label: `\footnotesize red!70!black`
- X-axis label: "$n$", Y-axis: "Normalised beam mass"
- Annotation at (2.8, 8.5): "n=3 lightest (but only by 20%)"

## Transition
- Arrow: `\draw[->, line width=4pt, >=stealth, magenta!60] (9.4, 5.5) -- (11.0, 5.5)`
- Label: "Coupled system effects dominate"

## Right panel: What Actually Happens
- Scope: `shift={(11.5,0)}`
- Background: `\fill[blue!2, rounded corners=6pt] (-0.5,-2.0) rectangle (11.5,11.5)`
- Title: `\bfseries\Large blue!60!black` at (5.5, 10.9) — "V6.2 Campaign Result"
- Subtitle: `\small blue!50!black` at (5.5, 10.3) — "DE optimiser, 60 islands × 10,000 iterations"

### Optimum marker
- Large green circle at (6.0, 7.0), label: `\bfseries\Large` — "74.17 kg at n=12"
- Convergence: "58/60 islands converged to 70–75 kg"

### Three-factor explanation box
- `\footnotesize, fill=white, draw=blue!20, rounded corners=3pt` at (5.5, 3.5):
  "\\textbf{Why n=12 wins despite 1.20× beam penalty:}\\\\[2pt]
  \\textbf{1. Knuckle coupling:} Thinner beams (95 vs 118 mm) $\\rightarrow$ smaller knuckles.\\\\[2pt]
  \\textbf{2. Expansion rotor consolidation:} n=12 needs 1 hub rotor; n=8 needed 3.\\\\[2pt]
  \\textbf{3. Beam formula:} Only 1.20× penalty — knuckle savings overwhelm it."

### Constraint note
- `\tiny black!40` at (5.5, -0.8): "Single-parameter sweeps infeasible — optimum is a constraint intersection"

## Bottom summary
- `\fill[black!3, rounded corners=6pt] (-0.5,-3.0) rectangle (23.0,-2.0)`
- Text: "Beam-only: 1.20× penalty. Knuckle coupling + expansion rotor consolidation (3→1) dominate. 58/60 islands converge to 74.17 kg at n=12."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram3-mass-scaling-v4.tex
pdftoppm -png -r 300 diagram3-mass-scaling-v4.pdf d3-mass-scaling
mv d3-mass-scaling-1.png d3-mass-scaling.png
python3 -c "from PIL import Image; import numpy as np; img=Image.open('d3-mass-scaling.png'); arr=np.array(img); nw=(arr<240).any(axis=2).sum(); assert img.size[0]>3500 and 100*nw/(arr.shape[0]*arr.shape[1])>2.0; print('OK')"
pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'expansion rotor' && echo 'Narrative OK'
! pdftotext diagram3-mass-scaling-v4.pdf - | grep -q 'sqrt.*sin' && echo 'Old formula absent OK'
```
