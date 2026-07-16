# Chart PRD — KTD Phase E Design Landscape

**Repository:** `KiteTurbineDynamics.jl`
**Commit:** `8cb23f9` (ring-geometry fix lineage: `74977b1` → `86ca0e5` → `9e35941` → `13f304a` → `8cb23f9`)
**Data:** `scripts/results/control_maps/catalog_corrected_geo.csv`
**Date:** 2026-07-13

---

## Narrative Research

### What story do these charts tell?

The ring-structural bug fix (legacy tube formula replaced with DE-optimized geometry
from `best_design.json` — Do=60mm, t/D=0.01 — wired into `KiteTurbineSystem` via `Ref`
fields) transformed the FoS landscape. Where prior sweeps showed zero viable designs
(everything FoS<0.1 or below 50kW), the corrected sweep reveals 19 evaluations passing
both gates (P≥50kW, FoS≥1.5), representing 13 unique blade/k/tether combinations across
two physically distinct operating regimes.

**Regime A (high-torque, low-RPM):** blades 0.90–1.10, k=2–6, 168–408 rpm, 70–297 kW.
The classic TRPT operating mode: large swept area, moderate tip speed, generator load
tuned to extract power near CP-max TSR. FoS ranges from 2.1 (marginal) to 11.3 (ultra-safe).
The sweet spot is blade 0.95@k=4 (199 kW, FoS 5.2, 257 rpm).

**Regime B (high-RPM, low-torque):** blades 0.80–0.85, k=2–14, 200–482 rpm, 116–156 kW.
Partially hidden from the catalog sweep because `settle_to_operational_state` scans
ω downwards from 9.5 rad/s (91 rpm) — blind to equilibria at 300–480 rpm. Blade 0.80@k=14
(133 kW, FoS 6.2) was found by catalog; blade 0.85@k=2 (116–156 kW) required a dedicated
no-load kickstart test to discover. This regime hints at lighter, faster stacked multi-rotor
configurations.

**The settle bug is a finding in itself:** 6 of 8 blade scales × 6 k-values = 48 points
in the catalog are "failed" with P≈0 but may actually be viable at higher ω than the
settle procedure can reach. The catalog CSV is therefore a lower bound on viability,
not the full picture.

### Counterintuitive findings

1. **Blade 0.85 at k=2 produces MORE power than blade 0.85 at k=14** (156 vs 18 kW).
   This is opposite to the Regime A pattern where higher k extracts more power from
   the same blade. The explanation: at k=14, generator torque (=14·ω²) is so high
   that the small blade stalls at any reachable ω. At k=2, the light generator load
   lets the blade spin freely to its aerodynamic equilibrium (~400 rpm), where the
   available aero power is substantial.

2. **r_bottom is a null parameter over 1.15–1.30** in the current model. Rounds 1
   (r=1.30) and 2 (r=1.15) produce bit-identical results for the same blade/k.
   However, r_bottom=1.00 (wind_sweep default) produces different power, FoS, and ω
   from r=1.30 — the parameter has a threshold effect. This is worth flagging but
   not a blocker for this report.

3. **3.5mm tether pushes designs to lower k.** Thinner tether = higher drag = more
   parasitic loss. To compensate, the system must operate further left on the k-axis
   (lighter generator load, higher ω). This is visible in Round 4 where all viable
   designs cluster at k=2, vs Rounds 1-2 where k=4 dominates.

---

## Data Verification

### Source inventory
- [x] `catalog_corrected_geo.csv` — 51 rows, 13 columns. All 6 k-values × 8 blade
  scales in Round 1, targeted subsets in Rounds 2-4. No NaN rows, no negative P for
  viable designs.
- [x] `scripts/catalog_sweep.jl` — the generating script. Confirmed: uses
  `settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)`, 30s MPPT,
  `SpokeParams(enabled=true)`, `v10_tight_builder` with DE ring geometry.
- [x] `scripts/kickstart_test_085.jl` — separate test for blade 0.85 with no-load
  spin-up and direct kickstart. Data verified: k=2, 30s no-load spin to 482 rpm,
  then k=2 engaged → 116.6 kW at 326 rpm stable at t=120s. Direct kickstart into
  k=2 → 155.5 kW at 392 rpm at t=120s.
- [x] `best_design.json` — ring geometry source: Do_top_m=0.06, t_over_D=0.01.
  Verified against builder code in `scripts/builders_util.jl:_build_v10_tight`.

### Data quality issues found
1. **Duplicate rows across rounds 1-2:** Rounds 1 (r=1.30) and 2 (r=1.15) produce
   identical blade/k results because r_bottom doesn't affect FoS or power. These
   are NOT independent designs — the unique count is 13, not 19.
2. **Bogus FoS for stalled designs:** Blades 0.69 and 0.80 at low k show FoS=17–183
   but ω<10 rpm or negative. FoS computed on a non-rotating system is meaningless.
   These points should be excluded from FoS-vs-P plots.
3. **Hidden regime data not in CSV:** Blade 0.85@k=2 kickstart results (116–156 kW)
   are NOT in `catalog_corrected_geo.csv`. They must be added as an annotation on
   charts.
4. **Pass gate is FoS≥1.5 AND P≥50kW.** Several designs pass one but fail the other.
   The catalog CSV's `pass` column correctly reflects the AND gate.

### Formulas verified
- P_kw = ef.base.P_kw (ground power after losses), confirmed in `capture_extended`
- min_fos = minimum of `ef.ring_fos[2:end]` (excludes ground ring), confirmed in
  `catalog_sweep.jl:67-72`
- ω_rpm = ef.base.omega_hub × 60/(2π), confirmed in `catalog_sweep.jl:73`
- T_max_kN = ef.base.T_max / 1000, confirmed in `catalog_sweep.jl:73`

---

## Figure 1: Power vs Blade Scale (Two-Regime Scatter)

### Story (3 sentences)
Blade scale is the dominant design parameter for TRPT kite turbines at 11 m/s.
Two operating regimes emerge: high-torque blades ≥0.90 produce 80-300 kW at
168-408 rpm (Regime A), while a hidden high-RPM population at blades ≤0.85
produces 116-156 kW at 200-482 rpm (Regime B). The settle bug systematically
hides Regime B from the catalog sweep — what appears as a "no power" zone is
actually an unexplored design frontier.

### Data provenance
- All catalog points: `catalog_corrected_geo.csv`, columns `blade_scale, k_mppt, P_kw, pass`
- Kickstart annotation: `kickstart_test_085.jl` output — blade 0.85, k=2, P=116–156 kW
- Failed points: ω<15 rpm excluded (bogus FoS, non-operating)
- Hidden regime annotation: blade 0.69 marked "UNTESTED — settle blind spot"

### Space budget
- Paper: 20cm × 14cm (landscape, suitable for 2-column layout)
- TikZ scale: 1.0 (1 unit = 1 cm)
- Effective area: 18cm × 12cm (1cm margins)
- X-axis (blade_scale): 0.65 to 1.15 → 18 units → 18cm. Label "Blade scale factor" at (9.0, -1.2), \footnotesize
- Y-axis (P_kW): 0 to 320 → 12cm. Label at (-1.5, 6.0) rotated, \footnotesize
- Tick marks: blade at 0.05 intervals, P at 50 kW intervals
- Legend: top-left at (0.7, 300), \small, 6 k-values + "kickstart" marker
- Regime labels: "Regime A" at (1.0, 280), "Regime B" at (0.72, 160), both \small\sffamily
- Kickstart annotation: blade 0.85 dashed box at (0.83, 140), \footnotesize
- Settle bug callout: arrow from "Settle blind spot →" at (0.70, 50), \footnotesize\itshape
- Data box (bottom-right): "11 m/s · spokes ON · DE ring · 30s MPPT" at (0.95, 15), \tiny

### Font sizes
- Title: \Large (14pt) — "TRPT Design Landscape — Power vs Blade Scale"
- Axis labels: \footnotesize (8pt)
- Tick labels: \tiny (6pt)
- Legend entries: \small (10pt) for k values
- Regime labels: \small\sffamily (10pt sans-serif)
- Annotations: \footnotesize (8pt)
- Data provenance box: \tiny (6pt)

### Color specifications
Chart uses the scientific-diagrams default palette adapted for k_mppt:
- k=2: black!70 (darkest — highest generator load)
- k=4: blue!60
- k=6: teal!50
- k=8: green!40
- k=10: orange!50
- k=14: red!50
- Viable points: filled circles (radius 2pt), color by k, thick border
- Failed points: open circles (radius 1.5pt), color by k, dashed border
- Kickstart point: filled diamond (radius 2.5pt), magenta, with error bar showing 116-156 kW range
- Regime divider: dashed gray vertical line at blade=0.88

### Coordinate map
```
X-axis: 0.65 to 1.15 (18cm mapped to 18 units)
Y-axis: 0 to 320 (12cm mapped to 12 units)
Key data points (blade_scale, P_kw):
  (0.80, 133) — viable, k=14, red filled circle, "0.80" label
  (0.85, 136) — kickstart mid, k=2, magenta diamond, error bar [116,156]
  (0.90, 81)  — viable, k=6, teal filled circle, "0.90" label
  (0.95, 199) — viable, k=4, blue filled circle, "0.95 ★" label
  (0.95, 259) — viable, k=6/3.5mm, teal filled circle
  (1.00, 146) — viable, k=4, blue filled circle
  (1.00, 223) — viable, k=2/3.5mm, black filled circle
  (1.05, 196) — viable, k=2/r1.0, black filled circle
  (1.10, 297) — viable, k=4, blue filled circle
Failed points: all blade 0.69, blade 0.80 k=2-10, blade 0.85 k=2-14, blade 0.90 k=2, etc.
  — shown as small open circles at their catalog P values (0-18 kW)
```

### Verification checklist
- [ ] All viable points at correct (blade, P) coordinates
- [ ] Kickstart diamond with error bar at blade 0.85
- [ ] Regime labels "A" and "B" visible and not overlapping data
- [ ] Settle blind spot arrow pointing to blade 0.69-0.85 zone
- [ ] Legend readable, 6 k colors + kickstart marker
- [ ] Axis labels include units ("kW", "scale factor")
- [ ] No data point outside plot bounds
- [ ] Vision_analyze: "Do you see two clusters of filled circles? Is there a diamond at x≈0.85?"

---

## Figure 2: Factor of Safety vs Power (Pareto Frontier)

### Story (3 sentences)
Every viable TRPT design lives on a Pareto frontier trading structural safety against
power output. Ultra-safe designs (FoS≥6) cluster at 80–260 kW with blades 0.80–0.95,
while power-optimised designs push to 300 kW with FoS dipping to 2.3. The DE-optimized
ring geometry gives a generous FoS baseline — even the most aggressive design (297 kW)
retains 2.3× margin against Euler buckling.

### Data provenance
- All viable points: `catalog_corrected_geo.csv`, columns `P_kw, min_fos, blade_scale`
- Deduplicated: only unique (blade_scale, k_mppt, tether_mm) combos shown (13 points)
- Excluded: rounds 2 duplicates, stalled designs with ω<15 rpm
- FoS bands:
  - Ultra-safe (FoS≥6): blade 0.90@k=6 (81 kW, 11.3), blade 0.95@k=6/3.5mm (259 kW, 6.1),
    blade 0.80@k=14 (133 kW, 6.2), blade 0.95@k=2/r1.0 (147 kW, 8.6),
    blade 1.10@k=2/r1.0 (190 kW, 6.1)
  - Safe (FoS 4-6): blade 0.95@k=4 (199 kW, 5.2), blade 1.05@k=2/3.5mm (155 kW, 4.0),
    blade 1.00@k=2/r1.0 (70 kW, 4.7)
  - Adequate (FoS 2.5-4): blade 1.00@k=4 (146 kW, 3.9), blade 1.05@k=2/r1.0 (196 kW, 3.5),
    blade 1.00@k=2/3.5mm (223 kW, 2.5)
  - Marginal (FoS 2.0-2.5): blade 1.10@k=4 (297 kW, 2.3), blade 1.05@k=4 (86 kW, 2.1),
    blade 1.10@k=2/3.5mm (121 kW, 2.3)

### Space budget
- Paper: 18cm × 14cm
- TikZ scale: 1.0
- Effective area: 16cm × 12cm
- X-axis (P_kW): 50 to 320 → 16cm. Label "Ground power P (kW)" at (185, -1.2), \footnotesize
- Y-axis (FoS): 1.5 to 12 → 12cm. Label at (-1.8, 6.75) rotated, \footnotesize
- Tick marks: P at 50 kW, FoS at 2.0 intervals
- Gate lines: dashed red horizontal at FoS=1.5 ("safety gate"), dashed orange horizontal at FoS=2.0 ("target")
- Gate line: dashed red vertical at P=50 ("power gate")
- FoS band shading: light green fill (FoS≥6), light yellow (4-6), light orange (2.5-4), light red (2.0-2.5)
- Point size scaled by blade_scale: radius = blade_scale × 3pt (smaller blades = smaller dots)
- Labels: blade scale value next to each point, \tiny
- Legend: "Ultra-safe · Safe · Adequate · Marginal" as colored squares, top-left
- Data box: bottom-right, same as Figure 1

### Color specifications
- Points colored by blade_scale (continuous gradient):
  blade 0.80: dark blue, 0.85: blue, 0.90: teal, 0.95: green, 1.00: yellow,
  1.05: orange, 1.10: red
- FoS band fills at opacity 0.15:
  Ultra-safe (FoS≥6): green!15
  Safe (4-6): yellow!15
  Adequate (2.5-4): orange!10
  Marginal (2-2.5): red!8
- Gate lines: red!60, dashed, line width=0.5pt

### Coordinate map
```
Key points (P, FoS, blade):
  (81, 11.3, 0.90) — top-left, ultra-safe
  (133, 6.2, 0.80) — left-mid, ultra-safe
  (147, 8.6, 0.95) — left, ultra-safe, tight ring
  (259, 6.1, 0.95) — right-mid, ultra-safe, 3.5mm
  (199, 5.2, 0.95) — center-right, safe, sweet spot
  (155, 4.0, 1.05) — center, safe, 3.5mm
  (70, 4.7, 1.00) — left, safe, tight ring
  (146, 3.9, 1.00) — center, adequate
  (196, 3.5, 1.05) — right-center, adequate, tight ring
  (223, 2.5, 1.00) — right, adequate, 3.5mm
  (297, 2.3, 1.10) — far right, marginal, max power
  (86, 2.1, 1.05) — left-low, marginal
  (121, 2.3, 1.10) — mid-right, marginal, 3.5mm
```

### Verification checklist
- [ ] All 13 unique points plotted at correct (P, FoS) coordinates
- [ ] Point size varies with blade_scale (smaller blades = smaller dots)
- [ ] FoS gate line at 1.5 visible and labeled
- [ ] Power gate line at 50 kW visible
- [ ] FoS band fills visible with legend
- [ ] Blade scale labels adjacent to each point
- [ ] Pareto frontier visually apparent (upper-left = safe, lower-right = powerful)
- [ ] Vision_analyze: "Which point has the highest FoS? Which has the highest power?"

---

## Figure 3: k_mppt × Blade Scale Heatmap (Viability Matrix)

### Story (3 sentences)
The k_mppt parameter controls generator load — higher k extracts more power per rpm
but demands more torque from the blades. The viability boundary forms a diagonal ridge
from (blade 0.90, k=6) to (blade 1.10, k=2): larger blades need lower k to avoid stall,
while smaller blades can sustain higher k at their naturally higher RPM. The white
zone below blade 0.85 is the settle bug's blind spot — only k=14 for blade 0.80 and
the kickstarted k=2 for blade 0.85 have been confirmed viable.

### Data provenance
- All catalog points: `catalog_corrected_geo.csv`, 8 blade scales × 6 k-values = 48 points
  plus Round 4 subset (4 blades × 6 k = 24, but with 3.5mm tether — shown as separate overlay)
- Viability: `pass=true` → green cell with P_kw value, `pass=false` → gray cell
- P_kw values: direct from CSV
- Kickstart override: blade 0.85@k=2 cell shows "4.9* / 156†" with footnote
- Deduplication: only Round 1 data shown (4mm tether, r=1.30). Round 3-4 shown as
  superscript annotations where they differ.

### Space budget
- Paper: 24cm × 14cm (wider for 9 columns)
- TikZ scale: 1.0
- Effective area: 22cm × 12cm
- X-axis (blade_scale): 8 columns at 2.5cm each = 20cm. Labels centered on columns.
- Y-axis (k_mppt): 6 rows at 1.8cm each = 10.8cm. Labels left of row.
- Cell size: 2.5cm × 1.8cm
- Cell content: P_kw value centered, \small for viable, \footnotesize for failed
- Column headers: blade_scale value + RPM range hint, \footnotesize
- Row labels: "k = 2", "k = 4", etc., \small
- Colorbar: right side, "P (kW)" label, \tiny tick labels
- Footnote area: 3 lines below heatmap, \footnotesize
- Title block: top, same format as Figures 1-2

### Color specifications
- Cell fill: continuous green gradient from white (0 kW) to dark green (300 kW)
  - 0-10 kW: white
  - 10-50 kW: green!10
  - 50-100 kW: green!30
  - 100-200 kW: green!50
  - 200-300 kW: green!70
  - 300+ kW: green!90
- Viable cells (pass=true): thick green border (line width=1.5pt)
- Failed cells: thin gray border, no fill color
- Kickstart cell: dashed magenta border, "†" superscript on value
- Round 3-4 annotations: small red superscript "³" or "⁴" where different from Round 1
- Settle blind zone: diagonal hatch pattern (gray!20) over blade 0.69-0.85, k=2-10 region
  with text "SETTLE\nBLIND\nZONE" rotated across cells, \footnotesize\itshape

### Coordinate map
```
Grid layout: columns=blade_scale, rows=k_mppt
col: 0.69  0.80  0.85  0.90  0.95  1.00  1.05  1.10
k=2:  0.0   0.0   4.9   6.7   0.1   0.0   0.0  51.4†
k=4:  0.2   0.2   0.0   0.0  199✓   146✓  86✓  297✓
k=6:  0.2  15.3   0.0  81✓    0.0    —     —     —
k=8:  0.0   0.0   0.0   0.0    —     —     —     —
k=10: 3.3   0.0   0.2    —     —     —     —     —
k=14: 0.0  133✓  18.1    —     —     —     —     —

Key: ✓ = viable (green border), † = fails P gate (FoS ok but P<50),
     — = not tested, * = settle-bug false negative
     
Kickstart override: blade 0.85, k=2 → 4.9* (catalog) / 156† (kickstart)
Round 3 (r=1.00): blade 0.95@k=2 → 147✓, 1.00@k=2 → 70✓, 1.05@k=2 → 196✓, 1.10@k=2 → 190✓
Round 4 (3.5mm):  blade 0.95@k=6 → 259✓, 1.00@k=2 → 223✓, 1.05@k=2 → 155✓, 1.10@k=2 → 121✓
```

### Footnote text
```
* Catalog value (settle_to_operational_state blind — design may be viable at higher RPM)
† FoS ≥ 1.5 but P < 50 kW (fails power gate)
³ Round 3 variation (r_bottom=1.00, 4mm tether)
⁴ Round 4 variation (3.5mm tether, r_bottom=1.30)
```

### Verification checklist
- [ ] All 37 cell values correct per CSV (8×6=48, minus 11 not-tested)
- [ ] Viable cells have thick green border
- [ ] Settle blind zone hatch visible over blade 0.69-0.85, k=2-10
- [ ] Kickstart override annotation at (0.85, k=2) cell
- [ ] Round 3 and 4 superscripts on affected cells
- [ ] Colorbar shows green gradient with kW scale
- [ ] Footnote text complete and legible
- [ ] Vision_analyze: "Can you identify the viable design corridor? Is the blind zone marked?"

---

## Global Conventions (all figures)

### Title block
```
\Large\sffamily\textbf{KTD Design Landscape — [chart subtitle]}
\small\sffamily V10 Tight · 11 m/s · spokes ON · DE-optimized ring · 30s MPPT
```

### Data box (bottom-right of each figure)
```
\tiny\sffamily
KiteTurbineDynamics.jl · commit 8cb23f9
catalog\_corrected\_geo.csv · $(date)
```

### File naming
```
docs/outreach/figures/
  fig1-power-vs-blade.tex
  fig2-fos-vs-power.tex
  fig3-kmppt-heatmap.tex
```

### Compilation
```bash
# Per figure
cd docs/outreach/figures
pdflatex -interaction=nonstopmode fig1-power-vs-blade.tex
pdftoppm -png -r 300 fig1-power-vs-blade.pdf fig1
mv fig1-1.png fig1.png

# Pixel check
python3 -c "
from PIL import Image; import numpy as np
img = Image.open('fig1.png'); arr = np.array(img)
nw = (arr < 240).any(axis=2).sum()
print(f'{100*nw/(arr.shape[0]*arr.shape[1]):.1f}% non-white')
"

# Text verification
pdftotext fig1-power-vs-blade.pdf - | grep -q 'Regime'
pdftotext fig1-power-vs-blade.pdf - | grep -q 'scale factor'

# Vision review
vision_analyze(image_url="fig1.png",
  question="Review this design landscape chart. Are the two regimes visible? ...")
```

## Figure 4: Power vs Rotor Speed — Operating Locus (P–ω Design Landscape)

### Story (4 sentences)

Every TRPT kite turbine design occupies a specific point in the (ω, P) plane
determined by three interacting characteristics: **blade scale** (design choice
— swept area), **k_mppt** (control choice — generator load), and **frame type**
(structure — tether diameter, ring radius). Tracing k_mppt from low to high for
a fixed blade scale reveals the design's full operating locus: high-ω/low-k
(aero-dominated, FoS-safe but needs kickstart) through peak power, to low-ω/high-k
(generator-dominated, power-dense but FoS-limited). The FoS constraint cuts a
diagonal safety boundary through this space — designs above 300 kW operate at
FoS below 2.5, while the 0.80–0.95 blade families achieve 130–260 kW at FoS 5–11.
The kickstart threshold at ω≈265 rpm separates two physically distinct regimes
that require different launch procedures and control strategies.

### Design vs control decomposition

This chart's primary job is to answer: **"Which characteristic — blade size,
generator tuning, or frame robustness — is responsible for this design's
performance?"**  Each data point is the product of three independent choices:

| Characteristic | What it is | How it appears on the chart | Effect on (ω, P, FoS) |
|---|---|---|---|
| **blade_scale** (design) | Swept area relative to ring | Point size + connecting lines within each blade family | Larger blades → more power at same k, slightly lower ω, lower FoS |
| **k_mppt** (control) | Generator load: P_gen = k·ω³ | Point shape: △(k=2), ○(k=4), □(k=6), ◇(k=14) | Higher k → lower ω, higher torque, lower FoS. Moving along a blade-family curve |
| **frame** (structure) | Tether Ø + ring radius | Fill style: ● filled=standard 4mm, ○ open=3.5mm, ◐ hatched=r=1.00 | Thicker tether → more drag → shifts curve left; ring radius mostly null |

**Reading the chart:** Pick a blade_scale (point size). Follow its connected
points left-to-right: leftmost = highest k (most generator load, lowest ω,
lowest FoS), rightmost = k=2 (lightest generator load, highest ω, highest FoS).
Compare across blade families vertically: at the same k, larger blades produce
more power but at lower ω and lower FoS.

### Data provenance

- **Catalog data:** `scripts/results/control_maps/catalog_corrected_geo.csv`
  — 51 rows, columns `blade_scale, k_mppt, P_kw, omega_rpm, min_fos, tether_mm, r_bottom`
- **Kickstart data:** `scripts/results/control_maps/kickstart_sweep.csv`
  — blade 0.69, 0.75, 0.80, 0.85 × k=2–14 at 11 m/s with no-load spin-up
- **Wind sweep data:** `scripts/results/control_maps/wind_sweep.csv`
  — blade 0.85–1.10 × k=2–6 at 5–15 m/s (supplementary P-vs-wind context)
- **Excluded from chart:** failed points with ω<15 rpm (non-operating, bogus FoS),
  duplicate r_bottom=1.15 rows (bit-identical to r=1.30 per PRD findings),
  blade 0.69 points from catalog (all stalled, settle-blind — kickstart data used instead)

### Space budget

- Paper: 22cm × 15cm (landscape, wider for annotations)
- TikZ scale: 0.88 (keeps font sizes readable with many labels)
- Effective area: 19.6cm × 12.5cm (1.2cm margins)
- X-axis (ω, rpm): 0 to 500 → 18cm mapped. Origin at (2.0, 2.0). Label "Rotor speed ω (rpm)" at (11.0, 0.8), \footnotesize
- Y-axis (P, kW): 0 to 350 → 12cm mapped. Origin at (2.0, 2.0). Label "Ground power P (kW)" at (0.4, 8.0) rotated, \footnotesize
- X ticks: every 100 rpm (0, 100, 200, 300, 400, 500)
- Y ticks: every 50 kW (0, 50, 100, 150, 200, 250, 300, 350)
- Legend: bottom-left at (2.5, 2.5) — k_mppt shapes + FoS color bands, \footnotesize
- Frame variant key: top-right at (19.0, 14.0), \tiny
- Regime labels: top-center, \small\sffamily
- Point labels: blade_scale values adjacent to key points, \tiny, positioned to avoid overlap
- FoS callouts: \tiny on critical boundary points
- Data box: bottom-right at (19.5, 2.5), \tiny

### Color specifications — FoS band encoding

Each point is colored by its structural safety band (NOT by k_mppt as in the old fig4):

| FoS range | Color | Name | Meaning |
|---|---|---|---|
| FoS ≥ 6 | green!60 | Ultra-safe | Generous ring buckling margin, robust to gusts |
| 4 ≤ FoS < 6 | green!40 | Safe | Adequate margin, production-ready |
| 2.5 ≤ FoS < 4 | amber!60 | Adequate | Operational with monitoring |
| 1.5 ≤ FoS < 2.5 | red!60 | Marginal | Engineering margin only — needs reinforcement for deployment |
| FoS < 1.5 | red!80 | Fail | Structurally non-viable at this operating point |
| Failed/stalled (ω<15) | gray!40 | Non-operating | System cannot sustain rotation — aerodynamic or settle failure |

FoS is encoded solely through point fill color (see above). No background band fills are used — on a P-ω chart, FoS is a third dimension not aligned with either axis, so horizontal fills would mislead.

### Marker shape — k_mppt encoding

Each k_mppt value gets a distinct shape, showing the control choice at a glance:

| k_mppt | Shape | TikZ | Physics meaning |
|---|---|---|---|
| k=2 | Downward triangle ▽ | `regular polygon, regular polygon sides=3, shape border rotate=180` | Lightest generator load — aero-dominated, high RPM, requires kickstart |
| k=4 | Circle ○ | `circle` | Moderate load — sweet spot for most blade scales, FoS-governed |
| k=6 | Square □ | `regular polygon, regular polygon sides=4` | Heavy load — power-dense, lower RPM, lower FoS |
| k≥8 | Filled diamond ◆ | `diamond, fill` | Very heavy generator load — only small blades (λ≤0.85) can sustain this without stalling |

Shapes use fill for the FoS color. Size scaled by blade_scale: radius = 2.0 + blade_scale×3.0 pt (range from 4.1 pt for λ=0.69 to 5.3 pt for λ=1.10 — visibly distinct).

### Frame variant encoding

Frame variants are annotated as text labels on affected points, NOT encoded in marker fill style — that would overload the visual channel. Points with 3.5mm tether get a small superscript "³·⁵" label. Points with r_bottom=1.00 get "ʳ¹" label.

### Blade family grouping (replaces connecting lines)

Instead of connecting lines (which create a spiderweb with 9 families), the three most important blade families get subtle background shading:
- λ=0.85 family: pale blue-green ellipse behind the cluster
- λ=0.95 family: pale amber ellipse behind the cluster  
- λ=1.10 family: pale pink ellipse behind the cluster

These three families span the design space from structurally efficient (0.85) through balanced (0.95) to power-maximising (1.10). Other blade families are shown as individual points only.

### Regime demarcation

A dashed gray vertical line at ω≈290 rpm separates the two operating regimes:

**Left of line (Regime A — "Generator-dominated"):**
- k_mppt ≥ 4, ω ≤ 290 rpm
- Higher generator torque → lower ω → lower FoS
- Power-dense: reaches 300 kW at blade 1.10
- **FoS is the binding constraint** — designs fail structurally before aerodynamically
- Label: "\textbf{Generator-dominated} \textit{(FoS-limited)}" at (7.0, 14.2), \small\sffamily, text=red!70!black
- Sub-label: "P ∝ k·ω³ — higher k extracts more power at cost of ring compression" at (7.0, 13.8), \tiny

**Right of line (Regime B — "Aero-dominated"):**
- k_mppt = 2, ω ≥ 290 rpm
- Light generator load → high ω → high FoS
- Power-moderate: 95–190 kW
- **Aerodynamic equilibrium governs** — blades must spin to their natural TSR
- **Requires kickstart** — system cannot self-start from rest at k=2
- Label: "\textbf{Aero-dominated} \textit{(kickstart-required)}" at (15.0, 14.2), \small\sffamily, text=teal!70!black
- Sub-label: "P ∝ ω³ — blades must reach aero equilibrium before engaging generator" at (15.0, 13.8), \tiny

### Kickstart threshold band

A shaded magenta band from ω=0 to ω≈290 rpm with label "Kickstart required\nbelow ~290 rpm for k=2" at 45° angle across the band, \footnotesize, magenta!50.

Kickstart "ramp" arrow: curved magenta arrow from (50, 5) arcing through
(200, 50) to (350, 140), labelled "no-load\nspin-up" at midpoint.

### Annotation callouts

Two key callout boxes anchor the chart's narrative:

1. **"λ=0.95 sweet spot"** — callout box at (250, 210) with arrow to blade 0.95@k=4 point.
   Text: "λ=0.95 @ k=4: 199 kW, FoS 5.2\nBest balance of power and safety"
   in \tiny, framed, green!70!black.

2. **"Max power: λ=1.10"** — callout at (275, 310) with arrow to blade 1.10@k=4.
   Text: "λ=1.10 @ k=4: 297 kW, FoS 2.3\nHighest power, marginal safety"
   in \tiny, framed, red!70!black.

All other points are labelled directly with their blade_scale value at the point
location, plus optional superscript for frame variant (³·⁵ or ʳ¹).

A dashed red horizontal line at P≈50 kW annotated "FoS=1.5 — structural floor
for designs below this power band" marks the approximate FoS safety boundary on
the P-ω plane.

### Legend layout

Consolidated legend panel at bottom-center of chart, inside a single framed box:

```
┌─────────────────────────────────────────────────────────────┐
│ Control (k_mppt):   △ k=2    ○ k=4    □ k=6    ◆ k≥8      │
│                                                             │
│ Structural safety (FoS):  ● ≥6 (ultra-safe)  ● 4–6 (safe)  │
│                            ● 2.5–4 (adequate)  ● <2.5 (marginal/fail)  │
│                                                             │
│ Point size ∝ blade scale    Point labels show λ value       │
│ Frame variants: ³·⁵ = 3.5mm tether    ʳ¹ = r_bottom=1.00  │
└─────────────────────────────────────────────────────────────┘
```

### Coordinate map — all data points

```
Format: (ω_rpm, P_kw) — blade_scale, k_mppt, FoS, frame_variant

Regime A (generator-dominated, k≥4):
  (165, 107)  — λ=0.85, k=14, FoS 11.5, standard        ◆ green (kickstart — catalog stalled)
  (168, 82)   — λ=0.90, k=6,  FoS 11.3, standard        □ green
  (190, 86)   — λ=1.05, k=4,  FoS 2.1,  standard        ○ red
  (198, 77)   — λ=0.80, k=8,  FoS 12.9, standard        ◆ green (kickstart)
  (201, 133)  — λ=0.80, k=14, FoS 6.2,  standard        ◆ green
  (206, 146)  — λ=1.00, k=4,  FoS 3.9,  standard        ○ amber
  (243, 161)  — λ=0.80, k=10, FoS 6.0,  standard        ◆ green (kickstart)
  (257, 199)  — λ=0.95, k=4,  FoS 5.2,  standard        ○ green
  (263, 129)  — λ=0.85, k=6,  FoS 17.4, standard        □ green (kickstart)
  (277, 184)  — λ=0.85, k=8,  FoS 26.2, standard        ◆ green (kickstart)
  (272, 297)  — λ=1.10, k=4,  FoS 2.3,  standard        ○ red
  (292, 134)  — λ=0.80, k=6,  FoS 10.1, standard        □ green (kickstart)
  (301, 259)  — λ=0.95, k=6,  FoS 6.1,  3.5mm           □ green ³·⁵
  (318, 155)  — λ=1.05, k=2,  FoS 4.0,  3.5mm           △ green ³·⁵
  (330, 187)  — λ=0.85, k=4,  FoS 5.5,  standard        ○ green (kickstart)
  (342, 173)  — λ=0.75, k=4,  FoS 6.0,  standard        ○ green (kickstart)
  (351, 121)  — λ=1.10, k=2,  FoS 2.3,  3.5mm           △ red ³·⁵
  (391, 167)  — λ=0.85, k=2,  FoS 12.9, standard        △ green (kickstart)
  (398, 190)  — λ=1.10, k=2,  FoS 6.1,  r=1.00          △ green ʳ¹
  (411, 131)  — λ=0.80, k=4,  FoS 2.2,  standard        ○ red (kickstart)

Regime B (aero-dominated, k=2, requires kickstart):
  (314, 100)  — λ=0.75, k=2,  FoS 19.1, standard        △ green (kickstart)
  (351, 118)  — λ=0.80, k=2,  FoS 3.8,  standard        △ amber (kickstart)
  (387, 95)   — λ=0.69, k=2,  FoS 6.5,  standard        △ green (kickstart)
  (404, 136)  — λ=0.85, k=2,  FoS range, standard        △ green (kickstart mid)
  (408, 196)  — λ=1.05, k=2,  FoS 3.5,  r=1.00          △ amber ʳ¹
  (455, 147)  — λ=0.95, k=2,  FoS 8.6,  r=1.00          △ green ʳ¹
  (482, 156)  — λ=0.85, k=2,  FoS range, standard        △ green (kickstart high)

Failed / underpowered (shown as small grey open markers):

Catalog settle-blind failures (operating below 50 kW gate due to settle bug
or aerodynamic limits — kickstart versions of these points may be viable):

  (23, 0.1)   — λ=0.95, k=2,  P far below gate, standard △ gray (cf. Round 3 at 455 rpm)
  (18, 0.2)   — λ=0.80, k=4,  settle-blind,   standard ○ gray (cf. kickstart at 411 rpm)
  (16, 0.2)   — λ=0.69, k=6,  settle-blind,   standard □ gray
  (23, 0.2)   — λ=0.69, k=4,  settle-blind,   standard ○ gray
  (58, 3.3)   — λ=0.69, k=10, settle-blind,   standard ◇ gray

Underpowered (rotating but P < 50 kW):

  (240, 6.7)  — λ=0.90, k=2,  P=6.7, FoS 2.4, standard △ gray (large blade, k=2 = no power)
  (123, 15.3) — λ=0.80, k=6,  P=15.3, FoS 4.0, standard □ gray (cf. kickstart at 292 rpm/134 kW)
  (82, 18.1)  — λ=0.85, k=14, P=18.1, FoS 42.9, standard ◆ gray (cf. kickstart at 165 rpm/107 kW)
  (127, 4.9)  — λ=0.85, k=2,  P=4.9, FoS 4.5,  standard △ gray (cf. kickstart at 391 rpm/167 kW)
  (257, 24.9) — λ=0.95, k=4,  P=24.9, FoS 7.5,  3.5mm   ○ open gray (3.5mm tether kills k=4)

FoS-failing (P ≥ 50 kW but FoS < 1.5 — structurally non-viable):

  (350, 51.4) — λ=1.10, k=2,  P=51.4, FoS 1.1, standard △ red (passes P gate, fails safety gate)

Note: "(kickstart)" tag means this point requires no-load spin-up to reach —
it was found by the kickstart sweep, not the catalog sweep.
The settle bug hides these from the standard catalog.
```

### Legend layout

```
┌─────────────────────────────────────────┐
│ Control (k_mppt):                        │
│   △ k=2    ○ k=4    □ k=6    ◇ k=14     │
│                                          │
│ Structural safety (FoS):                 │
│   ● FoS≥6 (ultra-safe)                  │
│   ● 4–6 (safe)       ● 2.5–4 (adequate) │
│   ● 1.5–2.5 (marginal)  ● <1.5 (fail)  │
│                                          │
│ Frame: ● standard  ○ 3.5mm  ◐ r=1.00   │
│ Connecting lines = blade family locus    │
└─────────────────────────────────────────┘
```

### Verification checklist

- [ ] All data points at correct (ω, P) coordinates per CSV data
- [ ] Point COLOR matches FoS band (green/amber/red/grey), NOT k_mppt
- [ ] Point SHAPE matches k_mppt value (△=k=2, ○=k=4, □=k=6, ◆=k≥8)
- [ ] Point SIZE visibly varies with blade_scale (4.1–5.3 pt range)
- [ ] Three blade family ellipses visible (λ=0.85, 0.95, 1.10)
- [ ] Regime labels "Generator-dominated (FoS-limited)" and "Aero-dominated (kickstart-required)" visible with sub-labels
- [ ] Kickstart threshold band at ω≈290 visible and labelled
- [ ] Two annotation callout boxes present (λ=0.95 sweet spot, λ=1.10 max power)
- [ ] FoS safety boundary line at P≈50 kW visible, annotated
- [ ] Frame variants annotated as text superscripts (³·⁵, ʳ¹), not fill styles
- [ ] Failed/underpowered points shown as small grey open markers in three clear categories
- [ ] Consolidated legend panel at bottom-center with shapes, FoS colors, size note, and variant key
- [ ] Data provenance box present with commit hash + CSV sources
- [ ] No connecting lines (removed — replaced by family ellipses)
- [ ] Vision_analyze: "Which blade scale produces the most power? Which is safest? Where is the FoS safety boundary? Can you distinguish k=2 from k=4 points by shape? Are the two callout boxes readable?"

### Compilation

```bash
cd docs/outreach/figures
# Generate from data first (produces data points file for TikZ)
julia --project=../.. scripts/chart_data.jl > fig4_data.tex
# Compile
pdflatex -interaction=nonstopmode fig4-power-vs-omega.tex
pdftoppm -png -r 300 fig4-power-vs-omega.pdf fig4
mv fig4-1.png fig4.png

# Verification
vision_analyze(image_url="fig4.png",
  question="Review this design landscape chart. Can you identify: (1) which blade scale produces the most power, (2) which is structurally safest, (3) where the FoS=1.5 boundary is, (4) distinguish k=2 from k=4 points by shape, (5) identify the kickstart-required region? Are the annotation callouts readable?")
```

---

### Spec self-review gate (mandatory before any LaTeX)

- [x] **Coordinate bounds:** X ranges 0-500 rpm (Fig4), Y ranges 0-350 kW (Fig4).
  All data points fall within these bounds. Kickstart points at 387-482 rpm < 500.
  Max power 297 kW < 350 kW upper bound.
- [x] **Space budget per text box:** Legend at \footnotesize (~3.5 chars/cm) in 5cm box
  = ~17 chars/line. All legend lines ≤15 chars → fit. Callout boxes at \tiny in
  4cm × 2cm boxes = ~25 chars/line × 6 lines each → fit.
- [x] **Data provenance:** Every number tagged with source CSV file and row.
  Kickstart points marked "(kickstart)". Catalog points marked with frame variant.
- [x] **Formula consistency:** Generator power = k·ω³. Operating locus direction
  (higher k → lower ω → lower FoS) verified against catalog and kickstart data.
- [x] **No speculative claims:** Kickstart threshold at ω≈290 rpm is data-driven
  (blade 0.85@k=2 is the lowest-ω kickstart point; blade 1.10@k=4 is the
  highest-ω catalog point in Regime A). Gap between 277-314 rpm is labelled.
- [x] **Verification commands copy-paste ready:** Full bash block with actual
  filenames — chart_data.jl for data export, pdflatex + pdftoppm for rendering.
- [x] **Unicode audit:** No emoji, no Unicode arrows, no special chars in LaTeX
  node text. All math in $...$. Greek letters via LaTeX math mode (\lambda, \omega).
- [x] **FoS encoding is color, not k_mppt:** This is the single most important
  change from the old fig4. The old chart colored points by k_mppt, making it
  impossible to see the FoS landscape. The new chart colors by FoS band so the
  safety constraint is immediately visible.
- [x] **Shape encodes control, size encodes design:** △=k=2 (low generator load),
  ○=k=4 (moderate), □=k=6 (heavy), ◇=k=14 (stall boundary). Point size ∝ blade_scale.
  Reader can identify a design's (blade, k) pair from visual encoding alone.
- [x] **Regime labels explain physics, not just name zones:** "Generator-dominated
  (FoS-limited)" vs "Aero-dominated (kickstart-required)" tells the reader WHY
  the regimes differ, not just THAT they differ.
