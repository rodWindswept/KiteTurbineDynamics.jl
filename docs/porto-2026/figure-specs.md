# Figure Generation Specs — Porto 2026 Paper

> **Method:** SPEC-first → TikZ/PGF → tikz_lint.py → pdflatex → pdftoppm → vision verify → iterate
> **Target:** 4 publication-quality figures for the KTD paper outline
> **Output:** PDF vector graphics, embeddable in combined paper PDF

---

## Figure G1: TRPT Kite Turbine — System Schematic

**Purpose:** Assembly diagram showing all major components of a multi-rotor TRPT kite turbine in operational configuration.

**What to show:**
- Lifter kite (top, soft single-skin, providing uplift tension)
- TRPT shaft (tapered polygon rings connected by tethers, 4–6 rings visible)
- Hub rotor (topmost ring, 3–4 rigid blades, generating rotor)
- Expansion rotors (lower rings, banked blades, radial force generation)
- Ground station (bottom, generator + anchor, elevated)
- Elevation angle β shown (~25° from horizontal)
- Wind direction arrow (left to right, downwind-facing assembly)
- Scale indicator: "~50 kW class, airborne mass 49.2 kg"
- Labels: lifter kite, hub rotor, expansion rotor, ring polygon, TRPT tether, ground generator, anchor

**Style:** Dark-themed technical schematic (matching KTD.jl dashboard aesthetic). Clean vector lines, no fills except for wind arrow. Monospace labels. Dimensions in metres where appropriate.

**Reference:** Wacker 2022 Figure 3.1 (Daisy Kite design), Tulloch 2023 Figure 1.

**Verification criteria:**
- [ ] All 7 labelled components visible
- [ ] Elevation angle clearly indicated
- [ ] Multi-rotor stacking visible (at least 2 rotors at different heights)
- [ ] TRPT tether pattern shows polygon-to-polygon connections
- [ ] Ground station shows generator + anchor
- [ ] Wind direction consistent with downwind operation
- [ ] Rendering check: no overlapping labels, readable at A4 width

---

## Figure G2: Static-vs-Dynamic Power Gap — Bar Chart

**Purpose:** Quantify the 4.2× discrepancy between static equilibrium prediction and dynamic multibody verification for the V10 Tight optimum.

**Data:**
| Method | Power (kW) | Source |
|--------|-----------|--------|
| Static equilibrium solver | 50 | V10 Tight equilibrium |
| Dynamic multibody ODE | 12 | V10 Tight ODE verification |
| Kheiri et al. 2018 (induction) | — (21% overestimate) | Literature |
| Carceller Candau 2022 (inflow) | — (18% overestimate) | Literature |
| Pfister & Blondel 2020 (BEM vs vortex) | — (varies) | Literature |

**What to show:**
- Grouped bar chart: two bars (Static: 50 kW, Dynamic: 12 kW)
- Horizontal reference lines for literature overprediction ranges (18–21%)
- Annotation: "4.2× gap" with arrow between static and dynamic bars
- Y-axis: Power (kW), 0–60 range
- X-axis: labelled "Equilibrium Solver" and "Multibody ODE"
- Caption note: "V10 Tight optimum at 49.2 kg, 4 rotors, λ = 0.519, 59 rpm static / 56 rpm dynamic"
- Error/uncertainty indication on literature bars (18–21% range)

**Style:** Clean scientific bar chart. Dark background optional. High contrast bars. Source data footnote.

**Verification criteria:**
- [ ] Static bar at 50, dynamic bar at 12
- [ ] 4.2× annotation present and correctly positioned
- [ ] Literature reference lines at correct values
- [ ] All axes labelled with units
- [ ] Caption includes key parameters
- [ ] Rendering check: bars distinguishable in grayscale

---

## Figure G3: Ring-Mapping Topology — +2 Offset Diagram

**Purpose:** Explain the internal architectural fix that maps intermediate rings (DE design variables) to system rings (multibody solver positions).

**What to show:**
- Two parallel columns:
  - Left column: "Intermediate Rings" (i = 1, 2, 3, ..., n)
  - Right column: "System Rings" (1, 2, 3, ..., n+2)
- Arrows showing mapping: intermediate i → system i+1
- Additional rings at top and bottom:
  - System ring 1 = Ground ring (added below)
  - System ring n+2 = Hub ring (added above, carries generating rotor)
- Shaft axis line connecting all rings
- Annotations: "Ground adds ring 1", "Hub adds ring n+2"
- Commit reference: "71ea694"

**Style:** Clean linear flow diagram. Two columns with horizontal mapping arrows. System rings wider than intermediate rings to show expansion. Ring symbols as small circles on a vertical shaft line.

**Verification criteria:**
- [ ] +2 offset clearly shown (intermediate 1 maps to system 2)
- [ ] Ground ring (system 1) shown as added below
- [ ] Hub ring (system n+2) shown as added above
- [ ] Mapping arrows unambiguous
- [ ] Commit reference present
- [ ] Rendering check: readable at 0.5× column width

---

## Figure G4: K1 Literature Grounding Map

**Purpose:** Show how the 6 KTD techniques connect to the existing AWE literature via the K1 knowledge graph.

**What to show:**
- Central node: "KTD.jl — 6 Techniques"
- 6 technique nodes radiating outward (k_mppt λ², TRPT MTR, Tether drag ¼, Ring-mapping, 6-DOF IR, 4.2× Gap)
- Each technique connected to its citation papers (from citation-lineage.md)
- Paper nodes sized by K1 graph edge count (more connected = larger)
- Technique nodes connected to each other where they interact (e.g., k_mppt + ring-mapping both enabled multi-rotor)
- Edge labels: "extends", "contradicts", "validates"
- Graph stats box: "7,048 nodes, 9,775 edges, 540 academic + 45 industry papers"
- Research density inset: small bar chart showing topic distribution

**Style:** Force-directed or radial layout. Clean node-link diagram. Colour-coded by technique. Dark background acceptable for conference slides.

**Verification criteria:**
- [ ] All 6 techniques shown with correct citation connections
- [ ] Citation papers match citation-lineage.md references
- [ ] Graph stats box present and accurate
- [ ] Edge types distinguishable
- [ ] Rendering check: all labels readable, no overlapping edges
