# SPEC-d6-convergence-cascade — V6 DE Optimizer Convergence

## The story (1-3 sentences)

A differential evolution optimizer finds the TRPT kite turbine optimum in two distinct phases: a cascade phase (iterations 1–12) where mass plunges from 102 kg to 23 kg in four dramatic jumps, and a refinement phase (iterations 12–100) that yields only 5.5 kg more improvement at exponentially diminishing returns. The lesson for campaign design: 50 iterations captures >98% of the achievable mass reduction — running longer buys micrograms, not kilograms.

## Data provenance

| Data point | Source | Status |
|---|---|---|
| Mass vs iteration | `v6_campaign/convergence_history.csv` (100 rows) | VERIFIED — parsed from campaign output |
| Phase boundaries | Visual inspection of mass deltas: ≥5kg drop → cascade; <1kg → refinement; <0.1kg → asymptote | SCHEMATIC — phase labels are interpretive |
| Parameter annotations | Not available in this data — per-iteration parameter traces were not logged | ABSENT — noted in diagram |
| Final mass 17.37 kg | Row 100 of convergence CSV | VERIFIED |

## Space budget

Paper: 18cm × 12cm, margin=0.5cm → effective 17cm × 11cm
TikZ scale: 1.0

**Title area:** y∈[10.0, 11.5], height=1.5cm
Font: \Large (5.5mm/line) → 2.7 lines available
Title text: "DE Optimizer Convergence: The Cascade Pattern" (~45 chars)
At \Large ~2.5 chars/cm → ~18 cm needed → use \large instead for ~18 chars/cm → 2.5cm → fits

**Plot area:** x∈[2.0, 17.0], y∈[2.0, 9.5]
x-axis: Iteration (0–100), 15cm wide
y-axis: Mass (kg, 0–110), 7.5cm tall

**Annotation boxes (3):**
Box 1 (cascade): x∈[2.5, 8.5], y∈[7.5, 9.0], Font \footnotesize
Box 2 (refinement): x∈[8.5, 14.5], y∈[3.0, 3.5], Font \footnotesize
Box 3 (asymptote): x∈[14.5, 17.0], y∈[2.0, 2.5], Font \footnotesize

## Exact layout

### Background elements
- Grid: light gray, dashed
- Phase regions: semi-transparent fills
  - Cascade (teal, iter 1–12): \fill[teal!10] (2.0,2.0) rectangle (3.8,9.5);
  - Refinement (amber, iter 12–50): \fill[amber!10] (3.8,2.0) rectangle (9.5,9.5);
  - Asymptote (gray, iter 50–100): \fill[gray!10] (9.5,2.0) rectangle (17.0,9.5);

### Data curve
- Solid blue line, 1.5pt, connecting all 100 data points
- x = 2.0 + (iteration/100) * 15.0
- y = 2.0 + (mass_kg/110) * 7.5

### Phase boundary markers
- Vertical dashed lines at iter=12 and iter=50
- Labels at top of plot: "Iter 12" and "Iter 50"

### Annotations
- Title: \Large\bfseries at (9.5, 11.0) — "DE Convergence: Cascade then Refinement"
- Cascade box at (5.5, 9.0): \footnotesize — "CASCADE: 4 drops in 12 iterations\n102→51→31→23 kg (78% reduction)"
- Refinement box at (11.5, 6.5): \footnotesize — "REFINEMENT: 38 iterations\n23→17.5 kg (5.5 kg saved)"
- Asymptote box at (15.0, 3.5): \footnotesize — "ASYMPTOTE: 50 iterations\n17.5→17.37 kg (0.13 kg)"
- Key insight at bottom right (15.0, 1.5): \tiny — "50 iterations captures >98%\nof achievable reduction"

### Axis labels
- x-axis: "Iteration" at (9.5, 1.5), \small
- y-axis: "Mass (kg)" rotated, at (0.8, 5.75), \small
- x ticks: 0, 20, 40, 60, 80, 100
- y ticks: 0, 20, 40, 60, 80, 100

## Verification commands
```bash
pdflatex -interaction=nonstopmode d6-convergence-cascade.tex
grep -c 'Error' d6-convergence-cascade.log  # Must be 0
pdfinfo d6-convergence-cascade.pdf | grep Pages  # Must be 1
pdftoppm -png -r 300 d6-convergence-cascade.pdf d6-convergence-cascade
mv d6-convergence-cascade-1.png d6-convergence-cascade.png
python3 -c "
from PIL import Image; import numpy as np
img = Image.open('d6-convergence-cascade.png'); arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
pct = 100*nw/(arr.shape[0]*arr.shape[1])
print(f'{img.size}, content={pct:.1f}%')
assert pct > 1.5, f'Too sparse: {pct:.1f}%'
"
pdftotext d6-convergence-cascade.pdf - | grep -q 'CASCADE'
pdftotext d6-convergence-cascade.pdf - | grep -q 'REFINEMENT'
pdftotext d6-convergence-cascade.pdf - | grep -q 'reduction'
```
