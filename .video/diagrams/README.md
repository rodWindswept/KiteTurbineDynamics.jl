# .video/diagrams/README.md — Diagram Specifications

All diagrams use the Instrument palette: BG=#0A0C10, accent=#39D0D8, ink=#E8EEF6.
Export at 1920×1080 PNG with transparent or near-black background.

---

## 1. trpt_scaling.svg — Mass/Power Scaling Curve

**Source:** `scripts/results/v6_campaign_10kw/convergence_history.csv` + v5 campaign data
**Render:** Manim `Axes` + `LineGraph` or matplotlib

Content:
- X-axis: Power (kW), log scale, 1–100
- Y-axis: Specific mass φ (kg/kW)
- Ideal line: flat dashed (linear scaling)
- TRPT curve: bending upward — annotated with v2, v3, v4, v5, v6 data points
- v6 point highlighted in cyan, below v5

---

## 2. ring_compression.svg — Ring Free Body Diagram

**Render:** Manim or Inkscape SVG

Content:
- Single TRPT ring shown as polygon (octagon for n=8)
- Tether lines from ring above (red, inward) and ring below (blue, outward)
- Net inward force F_in_per_vertex labeled
- Beam segment with compression arrows
- Euler equation overlay: P_crit = π²EI/L²
- Text: "Compression rings = dead mass"

---

## 3. expansion_concept.svg — 3D Expansion Concept

**Render:** GLMakie screenshot from dashboard with annotations, or Blender render

Content:
- Side view of TRPT shaft with rings
- 3 rings near hub highlighted with expansion blades
- Banking angle shown: dashed line from blade tip to next ring down
- Annotation: "bank angle θ — same blade as generating rotor"
- Optional: inset showing blade cross-section (same chord as main rotor)

---

## 4. force_diagram.svg — Apparent Wind & Force Resolution

**Render:** Manim `Arrow` + `MathTex`

Content:
- Ring shown as small circle
- Blade extending outward, banked at angle θ
- Apparent wind vector: v_wind horizontal + ω×r rotational
- Lift vector L_blade perpendicular to apparent wind
- Resolution: F_radial = L×sin(θ) (outward, cyan), F_axial = L×cos(θ) (axial, white)
- Numbers: "v_app = 40.4 m/s", "L_blade = 2,830 N", "F_radial = 4,840 N"

---

## 5. results_bars.svg — Campaign Results Comparison

**Source:** `scripts/results/v6_campaign_10kw/best_design.json` + v5 results
**Render:** Manim `BarChart` or matplotlib

Content:
- Grouped bar chart: v2, v3, v4, v5, v6 shaft mass
- v5: 11.47 kg (grey), v6: 10.97 kg (cyan)
- Annotated: "−4.4%"
- Second panel: parameter saturation — n_expansion→6, bank→45°, n_lines→8
- Callout: "Optimiser wants MORE expansion"
