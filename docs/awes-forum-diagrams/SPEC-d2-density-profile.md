# Diagram d2 — Generator-Ready Specification

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
- Subtitle: `\large` at (0, 5.1) — "β controls ring spacing: β>0 = bottom-heavy, β<0 = top-bias. The optimizer freely chooses β ∈ [−0.8, +0.8]."

## Left panel: n=3, β=+0.76 (orange)
- Scope: `xshift=-8.5cm, yshift=-0.1cm`
- Background: `\fill[orange!3, rounded corners=6pt] (-5.0,-6.5) rectangle (5.0,4.5)`
- Title: `\bfseries\Large orange!60!black` at (0, 3.9) — "n = 3, β = +0.76"
- Subtitle: `\small orange!50!black` at (0, 3.3) — "β>0: rings cluster at bottom"
- Shaft axis: `\draw[gray!40, line width=1pt] (0,-5.0) -- (0,2.8)`

### Ring geometry (CRITICAL: largest at top, smallest at bottom)
Ring spacing uses power law: t = i/9 for i=0..9, tbias = t^(1-0.76) = t^0.24
- y-position: yy = 2.8 − tbias × 7.2  (top=2.8, bottom=-4.4)
- Ring radius: rr = 2.5 − tbias × 2.15  (top=2.5, bottom=0.35)
- Line width: thick = 0.4 + tbias × 1.8  (thick at bottom where load is high)
- Each ring is a triangle (n=3): vertices at 90°, 210°, 330° around (0, yy)
- Color: `orange!70!black`

Verification: bottom ring (i=9, t=1) has rr=0.35 (smallest), top ring (i=0, t=0) has rr=2.5 (largest)

- Ground line: `\draw[thick, black!50] (-4.0,-4.5) -- (4.0,-4.5)`
- Ground label: `\footnotesize` at (0,-4.9) — "ground (smallest ring)"

### Annotations (must not overlap rings)
- `\small\bfseries orange!70!black` at (3.8, 1.5) — "Large rings at top (hub)"
- `\small\bfseries orange!70!black` at (3.8, -2.5) — "Small rings tightly packed at bottom — high compression"
- Both with `fill=white, fill opacity=0.9, rounded corners=3pt`

### Stats box
- `\footnotesize` at (0, -5.8): "Per-beam compression: N/3 — very high", "β=+0.76: Rings cluster at bottom where cumulative load peaks."

## Center transition
- Arrow: `\draw[->, line width=4pt, >=stealth, green!50!black] (-2.5,0) -- (2.5,0)`
- Label: `\bfseries\Large` — "n=3 → n=12"
- Below: `\small` — "β sign flips from +0.76 to −0.13"

## Right panel: n=12, β=−0.13 (blue)
- Scope: `xshift=8.5cm, yshift=-0.1cm`
- Background: `\fill[blue!2, rounded corners=6pt] (-5.0,-6.5) rectangle (5.0,4.5)`
- Title: `\bfseries\Large blue!60!black` at (0, 3.9) — "n = 12, β = −0.13"
- Subtitle: `\small blue!50!black` at (0, 3.3) — "β<0: mild top-bias — sign inverted"
- Shaft axis: `\draw[gray!40, line width=1pt] (0,-5.0) -- (0,2.8)`

### Ring geometry
t = i/8 for i=0..8, tbias = t^(1−(−0.13)) = t^1.13 (mild top-bias)
- yy = 2.8 − tbias × 7.2
- rr = 2.3 − tbias × 1.6  (top=2.3, bottom=0.7)
- 12-gon rings: `blue!50!black, line width=0.55pt`, vertices at 15° + k×30°
- Ground line at y=-4.5, label "ground (smallest ring)"

Verification: bottom ring (i=8, t=1) has rr=0.7, top ring (i=0, t=0) has rr=2.3

### Annotations
- `\small\bfseries blue!60!black` at (4.2, 1.5): "Large rings at top (hub)"
- `\small\bfseries blue!60!black` at (4.2, -2.5): "Small rings at bottom — nearly uniform spacing"

### Stats box
- `\footnotesize` at (0, -5.8): "Per-beam compression: N/12 — 4× lower than n=3", "β=−0.13: Compression so low that beam taper (thin near hub) now dominates — rings drift slightly toward top where beams are thinnest."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram2-density-v4.tex
# Zero Error lines

pdftoppm -png -r 300 diagram2-density-v4.pdf d2-density-profile
mv d2-density-profile-1.png d2-density-profile.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d2-density-profile.png')
arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
tot = arr.shape[0]*arr.shape[1]
assert img.size[0] > 3500, 'Too narrow'
assert 100*nw/tot > 2.0, f'Content too sparse: {100*nw/tot:.1f}%'
print(f'OK: {img.size}, {100*nw/tot:.1f}% non-white')
"

pdftotext diagram2-density-v4.pdf - | grep -q 'Density Profile' && echo 'Title OK'
pdftotext diagram2-density-v4.pdf - | grep -q 'smallest ring' && echo 'Ring labels OK'
pdftotext diagram2-density-v4.pdf - | grep -q 'beam taper' && echo 'Stats OK'
```
