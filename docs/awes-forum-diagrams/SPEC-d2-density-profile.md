# Diagram d2 — Generator-Ready Specification (v4 — space-budgeted)

## Space budget
- Paper: 36×20cm, scale=0.88 → effective 31.7×17.6cm
- Each panel: 10cm wide → 8.8cm real, height ~11cm → 9.7cm real
- Stats boxes at y=-5.8: `\footnotesize`, ~4 lines max, fits easily
- Annotations at x=3.8-4.2: ~3cm from ring edge, fine

## The story
β flipped from +0.76 (bottom-heavy, n=3) to −0.13 (mild top-bias, n=12) because:
1. At n=12, per-beam compression drops 4× — buckling is no longer the bottleneck
2. The hub expansion rotor provides radial force F_radial that strengthens nearby rings more than distant ones (force weakens down the shaft)
3. Rings drift slightly toward the hub where r_eff is largest
4. The effect is MILD (β=−0.13 is barely different from uniform β=0)

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

## Title
- `\bfseries\Huge` at (0, 5.8): "Why the Density Profile Inverted: From Bottom-Heavy to Top-Biased"
- `\large black!50` at (0, 5.1): "β controls ring spacing: β>0 = bottom-heavy, β<0 = top-bias. At n=12, buckling relaxes — expansion rotor force gradient favours mild top-bias."

## Left panel: n=3, β=+0.76 (orange)
- Scope: `xshift=-8.5cm, yshift=-0.1cm`
- Frame: `fill=orange!3, (-5.0,-6.5) rectangle (5.0,4.5)`
- Title at (0, 3.9) `\bfseries\Large orange!60!black`: "n = 3, β = +0.76"
- Sub at (0, 3.3) `\small orange!50!black`: "High compression forces rings to cluster at bottom"

### Ring geometry (VERIFIED: largest at top, smallest at bottom)
- Shaft: `\draw[gray!40, line width=1pt] (0,-5.0) -- (0,2.8)`
- Loop i=0..9: t=i/9, tbias=t^0.24, yy=2.8−tbias×7.2, rr=2.5−tbias×2.15, thick=0.4+tbias×1.8
- Bottom ring (i=9): rr=0.35 ✓, Top ring (i=0): rr=2.5 ✓
- Ground: `\draw[thick, black!50] (-4.0,-4.5) -- (4.0,-4.5)`, label "ground (smallest ring)"
- Annotations: "Large rings at top (hub)" at (3.8, 1.5), "Small rings tightly packed at bottom" at (3.8, -2.5)

### Narrative stats box
- At (0, -5.8) `\footnotesize, fill=white, draw=gray!20, rounded corners=3pt, inner sep=4pt`:
  "Per-beam compression: N/3 — very high.\\\
  \\textbf{β=+0.76:} Rings cluster at bottom where cumulative load peaks.\\\
  Without expansion rotors at n=3, buckling at the base\\\
  is the binding constraint — rings MUST be tight here."

## Center transition
- Arrow: `\draw[->, line width=4pt, >=stealth, green!50!black] (-2.5,0) -- (2.5,0)`
- Label: `\bfseries\Large` — "n=3 → n=12"
- Below `\small`: "β sign flips from +0.76 to −0.13"
- Below that `\footnotesize green!50!black`: "Per-beam compression drops 4×.\\Expansion rotor radial force favours hub."

## Right panel: n=12, β=−0.13 (blue)
- Scope: `xshift=8.5cm, yshift=-0.1cm`
- Frame: `fill=blue!2, (-5.0,-6.5) rectangle (5.0,4.5)`
- Title at (0, 3.9) `\bfseries\Large blue!60!black`: "n = 12, β = −0.13"
- Sub at (0, 3.3) `\small blue!50!black`: "Low compression — expansion rotor force gradient favours top"

### Ring geometry
- Loop i=0..8: t=i/8, tbias=t^1.13, yy=2.8−tbias×7.2, rr=2.3−tbias×1.6
- Bottom (i=8): rr=0.7 ✓, Top (i=0): rr=2.3 ✓
- 12-gon rings: `blue!50!black, line width=0.55pt`, vertices at 15°+k×30°
- Ground line and label same as left
- Annotations at (4.2, 1.5) and (4.2, -2.5)

### Narrative stats box
- At (0, -5.8) `\footnotesize, fill=white, draw=gray!20, rounded corners=3pt, inner sep=4pt`:
  "Per-beam compression: N/12 — 4× lower than n=3.\\\
  \\textbf{β=−0.13:} Buckling is no longer the binding constraint.\\\
  The hub expansion rotor provides radial force (F_radial)\\\\
  that strengthens nearby rings more than distant ones —\\\
  rings drift slightly toward the hub where r_eff is largest."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram2-density-v4.tex
# Assert: 1 page, 0 errors

pdftoppm -png -r 300 diagram2-density-v4.pdf d2-density-profile
mv d2-density-profile-1.png d2-density-profile.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d2-density-profile.png')
arr = np.array(img); nw = (arr < 240).any(axis=2).sum()
assert img.size[0] > 3500 and 100*nw/(arr.shape[0]*arr.shape[1]) > 2.0, 'FAIL'
print(f'OK: {img.size}, {100*nw/(arr.shape[0]*arr.shape[1]):.1f}%')
"

pdftotext diagram2-density-v4.pdf - | grep -q 'expansion rotor' && echo 'Narrative OK'
pdftotext diagram2-density-v4.pdf - | grep -q 'r_eff' && echo 'Physics detail OK'
pdftotext diagram2-density-v4.pdf - | grep -q 'smallest ring' && echo 'Ground labels OK'
pdftotext diagram2-density-v4.pdf - | grep -q 'binding constraint' && echo 'Stats narrative OK'
```
