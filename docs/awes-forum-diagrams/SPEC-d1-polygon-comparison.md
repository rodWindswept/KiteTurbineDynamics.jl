# Diagram d1 Specification: The Polygon Flip

## Data provenance (VERIFIED)
- V6 baseline campaign: n=8 lines, 259 kg, Do=118 mm, n_exp=3
- V6.2 corrected campaign: n=12 lines, 74.17 kg, Do=95 mm, n_exp=1
- Both masses from actual DE campaign runs, not estimates
- Source: `scripts/results/v6_2_campaign_50kw/best_design.json`

## What this diagram must convey
The optimizer's choice of n=12 over n=8 is a genuine system-level discovery:
- Beam-only intuition says fewer lines = lighter (each beam carries more load but there are fewer of them)
- BUT in a coupled system, more lines → thinner beams → smaller knuckles → lower total mass
- The polygonal geometry (8-gon vs 12-gon) is the visual anchor — the reader sees the shapes and immediately grasps the comparison

## Visual layout

### Two-panel split with central transition arrow
- LEFT panel (blue-tinted): "V6 Baseline — 8-line octagon"
- CENTER: large green arrow with "−71%" and "259 kg → 74 kg"  
- RIGHT panel (green-tinted): "V6.2 Optimum — 12-line dodecagon"
- BELOW both: findings box explaining the counterintuitive result

### Left panel contents
1. Title: "V6 Baseline" with subtitle "8-line octagon"
2. Octagon drawn in thick blue lines (representing thick 118 mm beams), red circles at vertices (knuckles)
3. Stats: Mass=259 kg, Do=118 mm, N/8 per-beam compression, 8 knuckles×0.11 kg
4. Trig annotation: sin(π/8)=0.383
5. Note: "Thick beams — expansion rotors needed at intermediate rings to share load"

### Right panel contents  
1. Title: "V6.2 Optimum" with subtitle "12-line dodecagon"
2. Dodecagon drawn in thin green lines (representing thin 95 mm beams), red circles at vertices
3. Stats: Mass=74 kg, Do=95 mm, N/12 per-beam (33% lower), 12 knuckles×0.10 kg
4. Trig annotation: sin(π/12)=0.259
5. Note: "Thin beams handle compression locally — hub-only expansion rotor, straight shaft"

### Findings box (full width below both panels)
Title: "What this reveals about the TRPT scaling problem"
Body: "The beam-mass-only scaling formula (n·sin(π/n)) increases by only 1.20× from n=3 to n=12. The naive beam-only intuition is correct in direction but dramatically understates the coupled system effect: thinner beams enable smaller knuckles, and knuckle mass savings dominate. The DE optimizer evaluates the full coupled design space — beams, knuckles, tethers, rotor — and finds the global minimum at n=12, not n=3 or n=8. This is a system-level inversion of a component-level intuition."

## Design constraints
- Document class: article with geometry package (paperwidth=36cm, paperheight=24cm)
- Both polygons must be fully visible, equal prominence
- Stats boxes positioned below polygons — NO text overlapping polygon lines
- Color scheme: blue=baseline/V6, green=optimum/V6.2, red=vertices
- All formulas in LaTeX math mode
- Verify: non-white pixels > 2%, title fully visible, no text cut off
