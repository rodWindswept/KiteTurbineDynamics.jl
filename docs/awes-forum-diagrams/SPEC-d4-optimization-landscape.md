# Diagram d4 Specification: V6.2 Optimization Landscape

## Data provenance

### What we HAVE (VERIFIED)
- Convergence history: 600,000 evaluations, 60 islands × 10,000 iterations
- 58/60 islands converged to 70-75 kg (Phase 1 analysis)
- Best island (#35): started at 447 kg, reached within 5% of final at iteration 204
- Campaign bounds: n∈[3,12], β∈[−0.8,+0.8], n_exp∈[0,6], r_hub∈[1,10]m, r_bot∈[0.1,5]m, n_rings∈[5,16], bank_angle∈[0,60]°
- Optimum: n=12, β=−0.1286, n_exp=1, r_hub=5.40m, r_bot=1.05m, Do=94.9mm, n_rings=9, bank=45°

### What we CANNOT show (Phase 2.1-2.3 finding)
- Smooth single-parameter sensitivity curves — IMPOSSIBLE. The optimum sits at a sharp constraint intersection. Changing any parameter by >1% produces infeasible designs (~1e6 kg penalty from FoS violations).
- This constraint tightness IS the story: the V6.2 optimum is a needle in a haystack that 58/60 independent searches found. This is stronger evidence than a smooth valley would be.

### What the optimizer actually varied
- n_expansion [0,6] AND blade_tip_radius [0,15]m were independent free parameters. The optimizer could choose many rings with short blades or one ring with a long blade. It chose n_exp=1 with blade_tip_radius=10.6m.
- bank_angle [0,60]° was free. It converged to 45°.
- n_rings [5,16] was free. It converged to 9.

## Visual layout: 4-panel grid

### Panel 1: Convergence History (top-left)
Title: "1. Convergence: 60 Islands → 74.17 kg"
- Axes: Best mass (kg) vs Iteration
- Y-axis: 0-400 kg (log-ish scale to show the steep descent)
- Multiple thin grey lines = individual island trajectories (schematic representation)
- One thick green line = best island (#35): 447→74.17 kg
- Horizontal dashed green line at 74.17 kg
- Annotation: "Best island reaches <5% of final at iteration 204"
- Legend: "Grey = individual islands. Green = island #35 (best)."
- Caption: "60 islands × 10,000 iterations = 600,000 evaluations. 58/60 islands converged to 70-75 kg."
- Bounds footnote: n∈[3,12], r_hub∈[1,10]m, β∈[−0.8,0.8], n_rings∈[5,16], n_exp∈[0,6]

### Panel 2: n_lines Explored (top-right)
Title: "2. Polygon Search: n_lines"
- Show the optimizer's search RANGE: n∈[3,12] with a visual indicator
- Mark the converged value: n=12 (dodecagon)
- Mini polygon icons: triangle (n=3), pentagon (n=5), octagon (n=8), dodecagon (n=12)
- Text: "Converged to n=12. Higher n → thinner beams → smaller knuckles."
- DISCLOSURE: "Single-parameter sweep infeasible — optimum is a constraint intersection. The DE explored the full 11-D space."
- Caption: "The optimizer varied n freely in [3,12] alongside all other parameters. It converged to n=12 — a dodecagon."

### Panel 3: Density Profile β (bottom-left)
Title: "3. Density Profile: β Sign Flip"
- Show two annotated points, not a curve:
  - Old optimum (pre-correction): β≈+0.76, mass ~100+ kg (bottom-heavy)
  - New optimum (V6.2): β=−0.1286, mass=74.17 kg (mild top-bias)
- Arrow between them: "tan→sin correction shifted optimum"
- Mini stack icons on x-axis: top-bias (β<0), uniform (β=0), bottom-heavy (β>0)
- Text: "β controls ring spacing. β>0 = bottom-heavy, β<0 = top-bias. The corrected physics (tan→sin, cos³→cos²·⁶⁵) shifted the optimum from strong bottom-bias to mild top-bias."
- DISCLOSURE: "Single-parameter β sweep infeasible — even β=−0.13 gives penalty. The constraint intersection locks β to the campaign value."

### Panel 4: n_expansion (bottom-right)
Title: "4. Expansion Stations: n_exp=1 Optimal"
- Show the optimizer's search range: n_exp∈[0,6]
- Mark converged value: n_exp=1
- Annotate: "The optimizer could choose n_exp=0..6 AND vary blade_tip_radius [0,15]m independently. It converged to n_exp=1 with blade_tip_radius=10.6m — one large expansion rotor at the hub ring."
- Mini icons: circles representing rotors at ring positions
- n_exp=0 shown for context: "n_exp=0 (no expansion) is heavier — some radial spreading is needed"
- DISCLOSURE: "Single-parameter n_exp sweep infeasible. The optimizer freely explored n_exp∈[0,6]."
- Caption: "Expansion rotors sit at ring positions on the shaft (not at the main power rotor). The optimizer chose one large rotor over multiple small ones."

## Design constraints
- article + geometry (paperwidth=38cm, paperheight=28cm)
- All 4 panels must be visible without cropping
- Each panel must have a disclosure about what IS and ISN'T confirmed data
- Colors: green=optimum/converged, grey=schematic/other islands, red=pre-correction
- Non-white pixels > 2%
