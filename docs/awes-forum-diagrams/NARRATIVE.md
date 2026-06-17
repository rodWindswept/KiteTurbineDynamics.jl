# V6.2 Physics Narrative — What Actually Changed

## The three corrections (from awes-forum-v62-report.md and code)

### 1. Polygon force resolution: tan → sin
The structural model was using tan(π/n) instead of sin(π/n) to resolve polygon vertex forces into beam compression. For an n-gon under radial load, the correct formula is C = F_v / (2·sin(π/n)). The tan formula understates compression by cos(π/n) — this artificially favoured low line counts because it made beams look stronger than they really are at low n.

### 2. Coupled knuckle mass
Knuckle mass was an independent variable (lower bound 0.005 kg) — completely decoupled from beam diameter. A 126 mm beam and a 50 mm beam got the same knuckle. Replaced with geometry-coupled model where knuckle mass derives from beam Do and wall thickness. For 95 mm beams at n=12, this gives ~0.10 kg per knuckle instead of 0.005 kg.

### 3. Elevation power exponent: cos³ → cos²·⁶⁵
Corrected across the codebase after BEM table regeneration.

## The sequence of events (d1 narrative)

1. **V6 baseline** (pre-correction, narrow bounds n∈[3,8]):
   - tan formula made beams look stronger than reality at low n
   - Fixed light knuckles (0.005 kg) didn't penalise thick beams
   - Optimizer converged to n=8, 259 kg, n_exp=3
   - Three expansion rotors needed at intermediate rings to handle high per-beam compression

2. **V6.2 corrections** (sin formula, coupled knuckles, widened bounds n∈[3,12]):
   - Correct sin formula: beam compression is actually higher than the tan formula said
   - Coupled knuckles: thicker beams cost more in knuckle mass (0.10 vs 0.005 kg)
   - Widened n bounds let the optimizer try n=12
   - At n=12: per-beam compression drops to N/12 (4× lower than n=3)
   - Thinner beams (95 mm vs 118 mm) → lighter knuckles
   - Single expansion rotor at hub is sufficient (n_exp=1 vs 3)
   - Result: 74.17 kg, a 71% reduction from V6 baseline

3. **Why the reduction is so large**:
   - Not just the polygon change (n=8→12 alone saves modest beam mass)
   - Major factors: (a) coupled knuckle mass model exposed the true cost of thick beams, (b) single expansion rotor instead of three, (c) corrected physics eliminated artificial safety margin

## The β sign flip (d2 narrative)

The density profile β controls ring spacing: β>0 = bottom-heavy, β<0 = top-bias.

**Why β was +0.76 in the old regime:**
- Low n (n=3 or n=8) means high per-beam compression
- Cumulative compression peaks at the bottom ring
- Rings must be tightly packed at the bottom to resist buckling
- The optimizer learned: put rings where the load is → β>0

**Why β is −0.13 in the corrected regime:**
- High n (n=12) means per-beam compression is 4× lower
- Buckling demand is relaxed everywhere — rings don't NEED to cluster at the bottom
- The expansion rotor at the hub provides radial force that increases r_eff
- Rings near the hub benefit more from this radial force (it weakens down the shaft)
- With buckling no longer the bottleneck, the optimizer shifts rings toward the hub
- The effect is MILD (−0.13 is a small negative, not a strong inversion)

**Important caveat:** Single-parameter β sweeps fail because the optimum is a constraint intersection. The β value of −0.1286 is optimal ONLY when co-optimized with n=12, n_exp=1, r_hub=5.4m, etc. Changing β by even 0.0001 makes the design infeasible because all 11 parameters are tightly coupled.

## The mass budget (d3 narrative)

The beam-only formula is n·sin(π/n). This gives only a 1.20× penalty from n=3 to n=12 — the beam ring itself is barely heavier with more lines. So why did the old campaign at n=8 produce 259 kg?

The mass budget at the V6.2 optimum (n=12, 74.17 kg):
- Beam mass: ~46.7 kg (from Phase 2.4 calculation for 9 rings at n=12)
- Knuckle mass: 12 knuckles × 0.10 kg × 9 rings ≈ 10.8 kg
- Tether mass: 12 lines × 67m × Dyneema density ≈ 1.4 kg
- Expansion rotor: 1 rotor × 12 blades (n_blades = n_lines) + hub hardware
  (exact mass TBC — blade mass inherited from main BEM rotor mould)
- These are approximate — the exact breakdown requires running the full structural evaluation

Compare to V6 baseline at n=8:
- Beam mass: thicker beams (118 mm vs 95 mm), more rings with expansion stations
- Knuckle mass: more knuckles, but artificially light (0.005 kg each)
- Tether mass: 8 lines instead of 12 (slightly lighter)
- Expansion rotors: 3 rotors instead of 1 (much heavier — each adds blades + hardware)

The massive reduction (259→74) is dominated by: (a) going from 3 expansion rotors to 1, (b) coupled knuckle mass model revealing true knuckle cost, (c) thinner beams at n=12.

## The constraint tightness (d4 narrative)

The V6.2 optimum is NOT a broad valley. It's a needle in a constraint haystack:
- 58/60 DE islands independently converged to the same 70-75 kg region
- Changing any single parameter by >1% produces infeasible designs (~1e6 kg penalty)
- Even β=-0.12857 (matching to 5 decimal places) fails — only the full 17-decimal campaign value works
- This means the optimum sits at an intersection of multiple constraints (FoS_beam ≥ 1.8, FoS_torsion ≥ 1.5, ground radius ≤ 5m, etc.)

The "top bias" (β<0) is real — the optimizer converged there — but it's not a smooth valley you can sweep. It's the specific point in 11-dimensional space where all constraints are simultaneously satisfied with minimum mass. The old "mistake" (tan formula) happened to produce β=+0.76 because it changed which constraint was binding.

## Expansion rotor blade count (2026-06-17 finding)

A significant correction from the latest review: expansion rotor blade count is
n_blades = n_lines — one blade per polygon vertex — NOT 3 as previously assumed.
The expansion blades use the same mould as the main BEM rotor (identical span,
chord, and count) and are banked downward. Only n_exp and bank_angle are free
parameters.

This matters for the expansion station economics:
- At n=12: single expansion rotor carries 12 blades
- Old V6 at n=8: 3 rotors × 8 blades = 24 expansion blades total
- V6.2 at n=12: 1 rotor × 12 blades = 12 expansion blades total (half as many)
- Despite fewer total blades, the hub rotor's larger radius and higher per-blade
  loading provide sufficient radial spreading

Additionally, expansion blade span was not a free parameter — the optimizer
could not try shorter/longer blades. Whether a dedicated shorter expansion blade
could provide the needed force at lower mass/drag is an unexplored 12th degree
of freedom.

## Bank angle safety (2026-06-17 finding)

The bank angle converged to 45° — the upper search bound — but this was found
with bounds [0, 60]°. During pitch depower, the apparent wind shifts and at 45°
the blades risk back-winding. The bound should be capped at **35°** for safety.
A campaign re-run with bank ∈ [0, 35]° is required. The current 45° optimum
may not survive a safety-limited re-optimisation.
