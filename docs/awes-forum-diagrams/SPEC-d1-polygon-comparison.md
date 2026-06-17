# Diagram d1 Specification: The Polygon Flip

## Purpose
Convince the reader that the optimizer's choice of n=12 (dodecagon) over n=8 (octagon) is a genuine system-level discovery, not a bug or parameter artefact. This is the "headline" diagram — it must be immediately graspable by an engineer skimming the report.

## Audience
AWES forum attendees — academic and industry AWE researchers who understand TRPT concepts but may not know this specific optimizer. Assume familiarity with polygon rings, beam compression, and knuckle hardware.

## Data sources
- V6 baseline: n=8, mass=259 kg, Do=118 mm, n_exp=3 (the old design that needed expansion rotors at multiple rings)
- V6.2 corrected campaign: n=12, mass=74.17 kg, Do=95 mm, n_exp=1 (single expansion rotor at hub, straight shaft)
- Beam-only formula: m ∝ n·√sin(π/n) — mathematically exact, computed values shown on both sides
- The 71% mass reduction (259→74 kg) comes directly from the two campaign results

## Visual layout

### Two-panel split with central arrow
- LEFT panel: blue-tinted, shows the V6 Baseline 8-line octagon
- CENTER: large green arrow with "−71%" and "259 kg → 74 kg"
- RIGHT panel: green-tinted, shows the V6.2 Optimum 12-line dodecagon
- Both panels must be fully visible, equal width, no cropping of either polygon

### Each panel contains
1. Title ("V6 Baseline" / "V6.2 Optimum") with line count
2. The polygon drawn as a line diagram with red node circles at vertices. Octagon uses thick blue lines (thick beams). Dodecagon uses thinner green lines (thin beams, more of them).
3. Stats box: Mass (kg), Do (mm), per-beam compression fraction, knuckle count × mass, tether count × length
4. Trig values: sin(π/n) value and n·√sin(π/n) scaling factor
5. One-line italic annotation explaining the expansion rotor implication: octagon side says "Thick beams: expansion rotors needed at intermediate rings to share load"; dodecagon side says "Thin beams handle compression locally: hub-only expansion rotor, straight shaft"

### Below both panels: Findings box
A full-width gray box containing:
- Title: "What this reveals about the TRPT scaling problem"
- Body: Explains that beam-only model is monotonically increasing (n=12 costs 2.19× more beam mass than n=3, 1.27× more than n=8), BUT the coupled system reverses this. Thinner beams enable smaller knuckles, and knuckle mass scales with beam diameter. The tether and rotor solidity penalties are modest. The DE optimizer evaluates the full coupled design space and finds the global minimum at n=12. This is a system-level inversion of a component-level intuition.

## Design constraints
- Document class: article with geometry package (not standalone — it's proven unreliable)
- Paper: wide enough to show both polygons side by side with arrow between them and findings box below without any cropping (test with pdftoppm -r 300 then verify non-white pixels > 1.5%)
- Colors: blue for baseline/V6, green for optimum/V6.2, red for polygon nodes
- Text must use LaTeX math mode for all formulas ($\sin(\pi/n)$, $n\sqrt{\sin(\pi/n)}$, etc.)
- No text overlapping polygon lines — stats boxes must be positioned below the polygon area
- The polygons themselves should be roughly 5cm in radius (TikZ coordinate units) to be visible

## Verification checklist
1. Both polygons fully visible with all vertices and edges
2. Arrow centered between panels
3. Statistics legible on both sides
4. Findings box fully readable, no text cut off at right margin
5. The 71% and 2.19× numbers are mathematically consistent
6. Color scheme distinguishes baseline from optimum clearly
