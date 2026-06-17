# Diagram d3 Specification: Mass Scaling — Why n=12 Wins

## Data provenance

### Beam-only formula (VERIFIED — Phase 2.4)
The beam-mass-only scaling is **n·sin(π/n)**, derived directly from:
- Beam mass = n × (CFRP mass per meter) × (beam length)
- Beam length = 2r·sin(π/n) for an n-gon of radius r
- Therefore mass ∝ n·sin(π/n)

Verified values (normalized to n=3):
- n=3: 1.000×  (3·sin(60°) = 2.598)
- n=6: 1.155×  (6·sin(30°) = 3.000)
- n=8: 1.178×  (8·sin(22.5°) = 3.061)
- n=12: 1.195× (12·sin(15°) = 3.105)

The beam-only penalty from n=3 to n=12 is only **1.20×** — much smaller than previously claimed.

CRITICAL: The old formula n·√sin(π/n) was WRONG (it gave 2.19×). That formula cannot be derived from any beam model. DO NOT USE IT.

### System optimum (VERIFIED — campaign)
- n=12, mass=74.17 kg from V6.2 corrected campaign
- 58/60 islands converged to 70-75 kg
- Source: `scripts/results/v6_2_campaign_50kw/best_design.json`

### What we CANNOT show
- Smooth system mass curve vs n — single-parameter sweeps are IMPOSSIBLE because the optimum sits at a sharp constraint intersection. Changing any parameter by >1% makes the design infeasible (~1e6 kg penalty).
- This is itself a finding: the V6.2 optimum is not a broad valley but a needle in a constraint haystack. The DE optimizer found a point that 58/60 independent searches converged to.

## Visual layout

### Split design: left = beam-only model, right = system result
- LEFT panel (red-tinted): "Beam-Mass-Only Model" — bar chart
  - 5 bars at n=3,6,8,10,12 with CORRECT values: 1.00×, 1.15×, 1.18×, 1.19×, 1.20×
  - Formula: m_ring ∝ n·sin(π/n)
  - Y-axis: "Normalised beam mass"
  - Annotation: "Beam-only penalty: only 1.20× from n=3 to n=12"

- CENTER: magenta arrow: "Coupled system effects dominate"

- RIGHT panel (blue-tinted): "V6.2 Campaign Result"
  - Show a single prominent data point at n=12, mass=74.17 kg
  - Text: "DE optimizer, 60 islands × 10,000 iterations"
  - Text: "58/60 islands converged to 70-75 kg"
  - Text: "Optimum: n=12, β=−0.13, n_exp=1"
  - Small annotation: "Single-parameter sweeps infeasible — design space is tightly constrained"

### Bottom summary
"Beam-only scaling (n·sin(π/n)) gives only 1.20× penalty at n=12. Coupled knuckle mass dominates — thinner beams enable dramatically smaller knuckles. The DE optimizer finds the system minimum at n=12, 74.17 kg, with 58/60 islands converging to the same narrow feasible region."

## Design constraints
- article + geometry (paperwidth=36cm, paperheight=18cm)
- Left bar values MUST use n·sin(π/n), NOT n·√sin(π/n)
- Right panel shows a single optimum point with convergence context
- Title must not be cropped
- Non-white pixels > 2%
