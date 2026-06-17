# Diagram d2 — Generator-Ready Specification (v3 — narrative-driven)

## The story this diagram tells
The density profile β flipped from +0.76 (bottom-heavy) to −0.13 (mild top-bias). This happened because:

1. **At n=12, buckling is no longer the bottleneck.** Per-beam compression drops to N/12 — 4× lower than at n=3. The rings no longer NEED to cluster at the bottom for buckling resistance. The old β=+0.76 was driven by the need to pack rings where cumulative compression was highest.

2. **The expansion rotor changes the game.** With n_exp=1 (single hub expansion rotor), radial spreading force F_radial is strongest at the hub and weakens down the shaft. Rings near the hub benefit more from increased effective radius (r_eff ↑ → torsional resistance ↑). This creates a mild incentive to shift rings toward the hub.

3. **The effect is MILD.** β=−0.13 is barely different from uniform spacing (β=0). This is not a dramatic inversion — it's a subtle shift driven by the expansion rotor's radial force gradient.

## Output files
- Source: `docs/awes-forum-diagrams/diagram2-density-v4.tex`
- Render: `docs/awes-forum-diagrams/d2-density-profile.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usetikzlibrary{calc}
\usepackage{amsmath}
\usepackage[paperwidth=36cm,paperheight=20cm,margin=0.3cm]{geometry}
\pagestyle{empty}
\begin{document}
\begin{tikzpicture}[scale=0.88]
```

## Title area
- Main: `\bfseries\Huge` at (0, 5.8) — "Why the Density Profile Inverted: From Bottom-Heavy to Top-Biased"
- Subtitle: `\large` at (0, 5.1) — "β controls ring spacing: β>0 = bottom-heavy, β<0 = top-bias. At n=12, buckling relaxes — expansion rotor force gradient favours mild top-bias."

## Left panel: n=3, β=+0.76
- Scope: `xshift=-8.5cm, yshift=-0.1cm`
- Background: `\fill[orange!3, rounded corners=6pt] (-5.0,-6.5) rectangle (5.0,4.5)`
- Title: `\bfseries\Large orange!60!black` at (0, 3.9) — "n = 3, β = +0.76"
- Subtitle: `\small orange!50!black` at (0, 3.3) — "High compression forces rings to cluster at bottom"

### Ring geometry (same as v2 — verified correct)
Ring spacing: t = i/9, tbias = t^0.24, yy = 2.8 − tbias×7.2, rr = 2.5 − tbias×2.15
- Bottom ring rr=0.35 (smallest), top ring rr=2.5 (largest) ✓

- Ground: `\draw[thick, black!50] (-4.0,-4.5) -- (4.0,-4.5)`, label "ground (smallest ring)"
- Annotation: "Large rings at top (hub)" at (3.8, 1.5), "Small rings tightly packed at bottom" at (3.8, -2.5)
- Stats box: "Per-beam: N/3 — very high. β=+0.76: Rings cluster at bottom where cumulative load peaks. Without expansion rotors at n=3, buckling at the base is the binding constraint."

## Center
- Arrow: `\draw[->, line width=4pt, >=stealth, green!50!black] (-2.5,0) -- (2.5,0)`
- Label: "n=3 → n=12"
- Below: "β sign flips from +0.76 to −0.13"

## Right panel: n=12, β=−0.13
- Scope: `xshift=8.5cm, yshift=-0.1cm`
- Background: `\fill[blue!2, rounded corners=6pt] (-5.0,-6.5) rectangle (5.0,4.5)`
- Title: `\bfseries\Large blue!60!black` at (0, 3.9) — "n = 12, β = −0.13"
- Subtitle: `\small blue!50!black` at (0, 3.3) — "Low compression: expansion rotor force gradient favours mild top-bias"

### Ring geometry
t = i/8, tbias = t^1.13, yy = 2.8 − tbias×7.2, rr = 2.3 − tbias×1.6
- Bottom ring rr=0.7, top ring rr=2.3 ✓

- Ground line, same as left
- Annotation: "Large rings at top (hub)" at (4.2, 1.5), "Small rings at bottom — nearly uniform" at (4.2, -2.5)
- Stats box: "Per-beam: N/12 — 4× lower. β=−0.13: Buckling is no longer the binding constraint. The hub expansion rotor provides radial force that strengthens nearby rings more than distant ones — rings drift slightly toward the hub where r_eff is largest."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram2-density-v4.tex
pdftoppm -png -r 300 diagram2-density-v4.pdf d2-density-profile
mv d2-density-profile-1.png d2-density-profile.png
python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d2-density-profile.png')
arr = np.array(img); nw = (arr < 240).any(axis=2).sum()
assert img.size[0] > 3500 and 100*nw/(arr.shape[0]*arr.shape[1]) > 2.0, 'FAIL'
print('OK')
"
pdftotext diagram2-density-v4.pdf - | grep -q 'expansion rotor' && echo 'Narrative OK'
```
