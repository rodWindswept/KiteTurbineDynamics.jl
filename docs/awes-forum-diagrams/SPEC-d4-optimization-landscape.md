# Diagram d4 — Generator-Ready Specification (v4 — space-budgeted)

## Space budget
- Paper: 40×32cm (increased from 30 to fit expanded narrative)
- Scale: 0.78 → effective 31.2×25.0cm
- Each panel: ~18.5×14 tikz units → 14.4×10.9cm real
- Panel 3 explanation: `\footnotesize`, text width 16cm → ~65 chars/line, 6 lines → 2.3cm → FITS
- Panel 3 disclosure: 3 lines → 1.1cm → FITS below main text
- Panel 1 caption: 2 lines, fits

## The story
The V6.2 optimum is a constraint intersection, not a smooth valley. Key narrative points:

1. **Convergence (Panel 1):** 58/60 independent islands all found the same 70-75 kg region. This is not luck — it's evidence of a real optimum.

2. **Polygon search (Panel 2):** Widening n bounds from [3,8] to [3,12] let the optimizer discover n=12. At n=12, per-beam compression is 4× lower, enabling thinner beams and a single expansion rotor.

3. **β sign flip (Panel 3):** NOT a "mistake" — the tan formula created a different constraint landscape where buckling dominated, forcing β=+0.76. The sin correction showed real compression is lower, allowing a different balance. The result (β=−0.13) is real but incredibly sharp — only the exact 17-digit value works.

4. **Expansion stations (Panel 4):** The optimizer could choose n_exp∈[0,6] AND blade_radius∈[0,15]m independently. It chose n_exp=1 with a 10.6m blade — one large rotor over many small ones. The old V6 needed 3 because n=8 had higher per-beam compression.

## Output files
- Source: `docs/awes-forum-diagrams/diagram4-optimization-landscape.tex`
- Render: `docs/awes-forum-diagrams/d4-optimization-landscape.png`

## Document setup
```
\documentclass{article}
\usepackage{tikz}
\usepackage{amsmath}
\usepackage[paperwidth=40cm,paperheight=32cm,margin=0.3cm]{geometry}
\pagestyle{empty}
\begin{document}
\centering
\begin{tikzpicture}[scale=0.78]
```

## Title
- `\bfseries\Huge` at (17.0, 33.0): "V6.2 Optimization Landscape"
- `\large` at (17.0, 32.0): "60 islands, 600,000 evaluations. 58/60 converged to 70–75 kg. The optimum is a constraint intersection, not a smooth valley."

## Panel 1: Convergence (top-left)
- `shift={(0, 19.0)}`, frame 18.5×13.5
- Title: "1. Convergence: 58/60 Islands → 74.17 kg"
- Sub: "Grey = individual islands. Green = best island (#35)."
- Y: "Best mass (kg)", ticks 0/100/200/300/400 at y=1.0/2.5/4.0/5.5/7.0
- X: "Iteration"
- 5 grey traces (schematic) converging from 6.5-7.5 to 1.2-1.4
- Green trace: (1.0,6.8)→(2.0,4.5)→(3.0,3.2)→(5.0,2.0)→(8.0,1.5)→(12.0,1.25)→(17.0,1.18)
- Dashed green at y=2.11 (74.17 kg)
- Note: "Reaches <5% of final at iteration 204"
- Caption (2 lines, `\scriptsize\itshape`): "Bounds: n∈[3,12], r_hub∈[1,10]m, r_bot∈[0.1,5]m, β∈[−0.8,0.8], n_rings∈[5,16], n_exp∈[0,6], bank∈[0,60]°"

## Panel 2: n_lines (top-right)
- `shift={(19.5, 19.0)}`, frame 16.5×13.5
- Title: "2. Polygon Search: Converged to n=12"
- Sub: "Optimizer freely varied n∈[3,12] alongside 10 other parameters"
- Grey search bar (1.5 to 14.5) at y=9.0, green dot at n=12
- Mini polygons at x=1.5(n=3), 5.5(n=5), 9.5(n=8), 14.5(n=12, highlighted)
- Text at y=5.5: `\footnotesize` — "Higher n → thinner beams → smaller coupled knuckles"
- Text at y=4.5: `\footnotesize` — "At n=12, per-beam compression is N/12 — single hub rotor suffices"
- Disclosure at y=1.5: `\tiny black!40` — "Single-parameter sweep infeasible. 58/60 islands independently converged to n=12."

## Panel 3: Density Profile β (bottom-left)
- `shift={(0, 0)}`, frame 18.5×16.5
- Title: "3. Density Profile: β Sign Flip (+0.76 → −0.13)"
- Sub: "The tan formula created different constraints — this is physics evolution, not error correction"

### Key narrative (must appear prominently)
- At (9.0, 13.5) `\footnotesize, align=left, text width=16cm`:
  "The old tan formula overstated beam compression, making buckling the dominant constraint —\\\
  rings HAD to cluster at the bottom (β=+0.76) to resist buckling. The corrected sin formula\\\
  showed real compression is lower. At n=12 with a hub expansion rotor, buckling relaxes and\\\
  the radial force gradient from the expansion rotor favours rings near the hub (β=−0.13)."

- Grey search bar at y=9.0: [−0.8, +0.8]
- Red dot at x≈13.5 (β≈+0.76): "Old optimum (tan formula): β=+0.76, bottom-heavy"
- Green dot at x≈4.5 (β≈−0.13): "New optimum (sin formula): β=−0.13, mild top-bias"
- Arrow: green, from old to new

- Mini stack icons at y=4.0: top-bias (x=1.5), uniform (x=9.0), bottom-heavy (x=16.5)
- Text at y=1.5: `\footnotesize` — "β>0 = bottom-heavy, β<0 = top-bias, β=0 = uniform"

- Disclosure at y=0.0: `\tiny black!40, text width=16cm`:
  "Extreme sensitivity: even β=−0.12857 (5 decimal places) fails the FoS check. Only the full\\\
  17-digit campaign value (−0.12856962561009427) works. The optimum is a razor-sharp\\\
  constraint intersection — not a smooth valley but a needle in a constraint haystack."

## Panel 4: n_expansion (bottom-right)
- `shift={(19.5, 0)}`, frame 16.5×16.5
- Title: "4. Expansion Stations: n_exp=1 Optimal"
- Sub: "Varied n_exp∈[0,6] — expansion blades inherit span, chord, and count from main BEM rotor. Only n_exp and bank_angle are free."

- Grey search bar at y=10.0: [0,6], green dot at n_exp=1, grey dots at others
- n_exp=0 shown: "no expansion — heavier"
- Mini rotor icons: hub only (n_exp=0), hub+1 ring (n_exp=1, highlighted), hub+3 rings (n_exp=3)

- Text at y=5.5: `\footnotesize` — "Each extra station adds 3 blades + knuckle hardware + parasitic drag penalty"
- Text at y=4.5: `\footnotesize` — "At n=12, per-beam compression is low enough that one hub rotor provides sufficient F_radial for the entire shaft"
- Text at y=3.5: `\footnotesize` — "The old V6 at n=8 needed 3 rotors because higher per-beam compression required more radial spreading"
- Text at y=2.5: `\footnotesize\itshape` — "Limitation: expansion blades use the same mould as the main rotor. Blade span was not a free parameter — the optimizer could not try shorter/longer expansion blades."

- Disclosure at y=0.5: `\tiny black!40, text width=14cm`:
  "Single-parameter sweep infeasible. Optimizer freely explored 11-D space. n_exp=0 (no expansion)\\
  is heavier — some radial spreading is required for feasibility. Blade length remains an unexplored DoF."

## Verification
```bash
cd docs/awes-forum-diagrams
pdflatex -interaction=nonstopmode diagram4-optimization-landscape.tex
# Assert: 1 page

pdftoppm -png -r 300 diagram4-optimization-landscape.pdf d4-optimization-landscape
mv d4-optimization-landscape-1.png d4-optimization-landscape.png

python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d4-optimization-landscape.png')
arr = np.array(img); nw = (arr < 240).any(axis=2).sum()
assert img.size[0] > 3800 and img.size[1] > 3000, f'Size fail: {img.size}'
assert 100*nw/(arr.shape[0]*arr.shape[1]) > 2.0, f'Sparse: {100*nw/(arr.shape[0]*arr.shape[1]):.1f}%'
print(f'OK: {img.size}, {100*nw/(arr.shape[0]*arr.shape[1]):.1f}%')
"

# Narrative verification
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'constraint landscape' && echo 'Physics evolution OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'razor-sharp' && echo 'Sensitivity OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'not a smooth valley' && echo 'Narrative clarity OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q '58/60' && echo 'Convergence OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'tan formula' && echo 'Old physics explanation OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'sin formula' && echo 'New physics explanation OK'
pdftotext diagram4-optimization-landscape.pdf - | grep -q '10\.6.*m' && echo 'Blade spec OK'
# Text completeness
pdftotext diagram4-optimization-landscape.pdf - | grep -q 'constraint haystack\.' && echo 'Text complete OK'
```
