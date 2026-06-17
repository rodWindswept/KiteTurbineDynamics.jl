# Diagram d2 Specification: Density Profile Inversion

## Purpose
Explain why the density profile parameter β flipped sign from +0.76 (bottom-heavy, V6 baseline at n=3) to −0.13 (mild top-bias, V6.2 optimum at n=12). This is the most counterintuitive result — the reader must understand that β is not an arbitrary tuning knob but emerges from the physics of beam compression vs beam taper.

## Definition of β
β is the ring spacing power-law exponent. Ring positions along the shaft are distributed as z_i ∝ t^(1−β) where t ∈ [0,1] parameterizes position from hub (t=0) to ground (t=1).

- β > 0: rings cluster toward the bottom (ground end). At β=+0.76, t^(1−0.76) = t^0.24 — heavily bottom-biased.
- β = 0: uniform spacing. t^1 = t — linear distribution.
- β < 0: rings cluster toward the top (hub end). At β=−0.13, t^(1+0.13) = t^1.13 — mild top-bias.

The optimizer freely chooses β in [−0.8, +0.8] for every candidate design.

## Physics of the sign flip
At low n (n=3): per-beam compression is very high (N/3). Cumulative load peaks at the bottom ring, which must resist the full weight + tension of everything above it. To prevent buckling, rings must be tightly spaced at the bottom where the load is highest. Hence β → large positive.

At high n (n=12): per-beam compression is 4× lower (N/12). The buckling demand is relaxed everywhere. Now the dominant effect is beam taper — beams are thinnest near the hub (top). Rings drift slightly toward the top where the beams are structurally weakest, providing extra local support. Hence β → small negative.

## Data sources
- V6.2 corrected campaign: best β = −0.1286... ≈ −0.13
- V6 pre-correction: β ≈ +0.76 (not from the corrected campaign, but documented as the regime before the tan→sin + cos³→cos²·⁶⁵ corrections)
- The β values are direct optimizer outputs — the DE algorithm tried values across [−0.8, +0.8] and converged to these

## Visual layout

### Side-by-side comparison
- LEFT panel: orange-tinted, n=3, β=+0.76. Shows triangular rings (n=3 polygon) stacked along a vertical shaft axis. Rings are LARGEST at top (hub, radius ~2.5), SMALLEST at bottom (ground, radius ~0.35). They are tightly packed at the bottom, widely spaced at the top.
- CENTER: green arrow with "n=3 → n=12" and "β sign flips from +0.76 to −0.13"
- RIGHT panel: blue-tinted, n=12, β=−0.13. Shows dodecagonal rings stacked along shaft. Again LARGEST at top, SMALLEST at bottom. Nearly uniform spacing with mild top-bias.

### Critical visual requirement: ring radii
- Top (hub) rings must be visibly LARGER than bottom rings in BOTH panels. The TRPT geometry has the hub at the largest radius and the ground ring at the smallest.
- Bottom rings should be small and clearly labeled "ground (smallest ring)"
- The ring radius formula: rr = r_max − tbias × (r_max − r_min). Must decrease from top to bottom.

### Ground line
- A thick line at the bottom of each shaft labeled "ground"

### Annotation
- On n=3 side: an arrow showing compression peaking at the bottom, with text "Cumulative compression peaks at bottom ring → small rings must be tight here"
- On n=12 side: an arrow showing low compression everywhere, with text "Low per-beam compression everywhere → density demand vanishes — sign inverts"

### Stats boxes (below each shaft)
- Per-beam compression ratio (N/3 vs N/12)
- The β value and what it means
- Bottom ring radius and top ring radius explicitly stated
- For n=12: explanation of why β<0: "Compression so low that beam taper (thin at hub) now dominates over load — rings drift slightly toward the top where beams are thinnest"

## Design constraints
- Document class: article with geometry (proven reliable)
- Paper wide enough for both panels side by side with arrow between
- Text annotations must not overlap ring graphics
- Ring radii must be computed from a formula that explicitly decreases from top to bottom
- Verify with pixel check: non-white > 2%
