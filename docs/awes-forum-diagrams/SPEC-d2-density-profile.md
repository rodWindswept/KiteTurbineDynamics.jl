# Diagram d2 Specification: Density Profile Inversion

## Data provenance (VERIFIED)
- β = −0.1286 from V6.2 campaign best_design.json
- Historical β ≈ +0.76 from pre-correction campaign (v5 era, documented in awes-forum-v62-report.md)
- Ring radii follow power-law taper from hub (largest) to ground (smallest)
- Ring spacing formula: z_i ∝ t^(1−β) where t∈[0,1] from hub to ground

## Definition of β (must be explained in diagram)
β controls ring spacing along the TRPT shaft:
- β > 0: rings cluster toward bottom (ground end). Higher per-beam compression at bottom requires tighter spacing for buckling resistance.
- β = 0: uniform spacing. All rings equally spaced.
- β < 0: rings cluster toward top (hub end). When per-beam compression is low everywhere (high n), beam taper (thin near hub) becomes the dominant effect, so rings drift toward the top where beams are structurally weakest.

The optimizer freely chooses β ∈ [−0.8, +0.8]. It converged to −0.13.

## Physics of the sign flip
At low n (n=3): per-beam compression is very high (N/3). Cumulative load peaks at the bottom ring. To prevent buckling, rings must be tightly packed at the bottom. β → +0.76.

At high n (n=12): per-beam compression is 4× lower (N/12). Buckling demand is relaxed everywhere. Beam taper (beams are thinnest near the hub/top) now dominates — rings drift slightly toward the top. β → −0.13.

## Visual layout

### Side-by-side comparison
- LEFT panel (orange-tinted): n=3, β=+0.76. Triangular rings stacked along vertical shaft axis. LARGEST at top (hub), SMALLEST at bottom (ground). Tightly packed at bottom, widely spaced at top.
- CENTER: green arrow with "n=3 → n=12" and "β sign flips from +0.76 to −0.13"
- RIGHT panel (blue-tinted): n=12, β=−0.13. Dodecagonal rings stacked along shaft. LARGEST at top, SMALLEST at bottom. Nearly uniform spacing with mild top-bias.

### Critical: ring radii must be correct
- Top (hub) rings: LARGEST radius (~2.5 units)
- Bottom (ground) rings: SMALLEST radius (~0.35 units)
- Formula: rr = r_max − tbias × (r_max − r_min). Must decrease from top to bottom.
- Ground line at bottom of each shaft labeled "ground (smallest ring)"

### Annotations (compact, not overlapping rings)
- n=3 side: "Cumulative compression peaks at bottom → small rings must be tight here"
- n=12 side: "Low per-beam compression everywhere → beam taper dominates → rings drift toward top"

### Stats box below each shaft
- Per-beam compression ratio
- β value and meaning
- Explicit ring radii at top and bottom
- For n=12: explanation of why β<0

## Design constraints
- article + geometry (paperwidth=36cm, paperheight=20cm)
- Ring radii MUST decrease from top to bottom — verify visually
- Text annotations must NOT overlap ring graphics
- β definition must appear in the title/subtitle area
- Non-white pixels > 2%
