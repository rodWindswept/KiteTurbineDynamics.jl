# Diagram d4 Specification: V6.2 Optimization Landscape

## Purpose
Show the reader HOW the DE optimizer found the 74.17 kg optimum — not just WHAT it found. The four panels together tell the story: wide bounds allowed escape from the V6 constraint ceiling (panel 1), increasing n_lines systematically reduced mass (panel 2), the density profile β sign flipped after physics corrections (panel 3), and a single expansion rotor was optimal (panel 4). Each panel must include what was varied, what bounds were used, and what the result means.

## Data provenance

### Campaign setup
- Algorithm: Differential Evolution, 60 islands × 10,000 iterations = 600,000 evaluations
- Free parameters: n_lines [3,12], n_rings [5,16], density_profile (β) [−0.8,+0.8], n_expansion [0,6], r_hub [1,10]m, r_bot [0.1,5]m, Do_top [0.01,0.2]m, blade_tip_radius [0,15]m, bank_angle [0,60]°, t_over_D [0.005,0.05], aspect_ratio [0.5,5.0], Do_scale_exp [0.1,1.0]
- This is from the actual best_design.json and campaign script parameters

### What we DON'T have
- The convergence history CSV only tracks mass, not individual parameter values per iteration. Panel 1 (convergence traces) and Panel 3 (β sweep curve) are schematic/qualitative — they show the CONCEPT based on known physics and optimizer behavior, not exact per-iteration data.
- We do NOT have separate per-n campaign runs. Panel 2 (n_lines vs mass) shows the qualitative trend — mass decreases with n — but the exact mass values at n=3,6,8,10 are approximate. Only n=12 has a confirmed campaign result (74.17 kg).
- Panel 3 (β sweep): the optimizer varied β freely. The curve shape showing a minimum at β≈−0.13 is based on the known best value. We don't have a full β sensitivity sweep.
- Panel 4 (n_exp): same — we know n_exp=1 is best, but don't have exact masses at n_exp=2,3,etc.

### HONESTY REQUIREMENT
Each panel must disclose what is confirmed campaign data vs what is qualitative/schematic. The caption text must distinguish: "Solid line = confirmed trend, dashed = schematic based on known optimum."

## What the optimizer actually tried
- YES, the optimizer tried shorter expansion blades on more rings. blade_tip_radius [0,15]m and n_expansion [0,6] were independent free parameters. The optimizer could choose n_exp=3 with small blades or n_exp=1 with a large blade. It converged to n_exp=1 with blade_tip_radius=10.6m — one large expansion rotor at the hub ring.
- bank_angle [0,60]° was also free. The optimum landed at 45°.
- n_rings was [5,16]; optimum at 9 rings.

## Visual layout: 2×2 grid of panels

### Panel 1: Convergence History (top-left)
- Axes: Best mass (kg) vs Iteration
- Multiple thin grey lines = individual island trajectories (schematic)
- One thick green line = best island's trajectory (island #35)
- Horizontal dashed line at 74.17 kg
- Caption: "60 islands × 10,000 iterations. Grey traces = individual islands (schematic). Green = best island trajectory. Each island explores a different region of parameter space, with periodic migration sharing best solutions."
- Bounds listed: n∈[3,12], r_hub∈[1,10]m, r_bot∈[0.1,5]m, β∈[−0.8,0.8], n_rings∈[5,16], n_exp∈[0,6]

### Panel 2: n_lines Sensitivity (top-right)
- Axes: Best mass (kg) vs n (lines)
- Curve: decreasing monotonically from n=3 to n=12
- Green circle at n=12 = 74.17 kg
- Mini polygon icons on x-axis (triangle at n=3, octagon at n=8, dodecagon at n=12)
- Caption: "Trend is qualitative — only n=12 has a confirmed campaign run. The monotonic decrease is supported by physics: more lines → thinner beams → smaller coupled knuckles → lower total mass."

### Panel 3: Density Profile β (bottom-left)
- Axes: Mass (kg) vs β (density profile)
- Two curves: red dashed = pre-correction physics (tan formula, minimum at β≈+0.76), blue solid = corrected physics (sin formula, minimum at β≈−0.13)
- Green circle at β=−0.13 = 74.17 kg
- Arrow from old optimum to new: "correction shifted optimum"
- Mini stack icons on x-axis showing: top-bias (β<0, rings near top), uniform (β=0), bottom-heavy (β>0, rings near bottom)
- Caption: "β controls ring spacing along shaft. The tan→sin and cos³→cos²·⁶⁵ corrections halved the buckling demand, making the old bottom-heavy profile (β=+0.76) suboptimal. The optimizer freely explored β∈[−0.8,+0.8] and converged to −0.13."

### Panel 4: n_expansion Sensitivity (bottom-right)
- Axes: Mass (kg) vs n_expansion (number of expansion stations)
- Curve: n_exp=0 is heavy (no radial spreading), n_exp=1 is minimum (74.17 kg), n_exp>1 increases mass
- Data points at n_exp=0 through 6 with approximate masses
- Annotation: "Each extra station adds: 3 blades × ~1.5 kg + knuckle hardware + parasitic drag penalty"
- Mini icons on x-axis: circles representing rotors at ring positions
- n_exp=0 included FOR COMPARISON — shows that having NO expansion is worse than having one
- Caption: "Expansion rotors sit at ring positions on the shaft (not at the main power rotor). n_exp=0 (no expansion) is heavier than n_exp=1 — a single expansion station at the hub provides enough radial force without the mass penalty of multiple stations. The optimizer varied blade_tip_radius [0,15]m independently, so it could try short blades on many rings or one large blade. It chose one large blade."

## Design constraints
- article + geometry, no standalone
- All four panels must be fully visible without cropping
- Each panel must have a descriptive caption explaining bounds, assumptions, and data confidence
- The physics correction must be named explicitly: tan→sin, cos³→cos²·⁶⁵, coupled knuckle mass model
- Honesty markers: distinguish confirmed data from schematic/qualitative trends
