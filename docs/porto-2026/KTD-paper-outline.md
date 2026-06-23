# KTD Paper Outline — Reverse-Ingestion from Knowledge Graph

> **Skeleton for a paper presenting KTD.jl results, grounded in literature via K1 knowledge graph extraction.**
> Target: AWES conference or Wind Energy Science.
> Status: OUTLINE — implementation pending Phase 4 (data anchoring) and Phase 5 (synthesis).

---

## Title Candidates

1. *KiteTurbineDynamics.jl: Multi-Rotor TRPT Optimisation with Equilibrium-to-Dynamic Verification*
2. *Closing the Static-Dynamic Gap in Rotary Airborne Wind Energy: A 4.2× Correction from Full Multibody Simulation*
3. *Scalable Multi-Rotor Airborne Wind Energy: Design Optimisation of Tensile Rotary Power Transmission Systems*

**Recommendation:** Title 1 for breadth, Title 2 for impact.

---

## Figures

---

### Figure 1 — V10 Tight: PCA Design Space Landscape

![V10 Tight PCA landscape](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-tight-landscape.png)

**Figure 1.** Principal component projection of the 14-dimensional KTD.jl design space from the V10 Tight campaign (12 islands × 1,500 iterations, k_mppt ∝ λ² scaling). **Legend:** Each point is a design evaluation. Colour encodes total airborne mass (kg) — dark purple = lightest designs, yellow = heaviest. White dashed lines are iso-mass contours at 50 kg and 65 kg. The yellow diamond (✦) marks the campaign winner at 49.2 kg — 4 rotors, λ = 0.519, r_hub = 2.89 m. PC1 (28.9% variance) captures structural scale (r_hub, Do_top, n_lines); PC2 (20.4% variance) captures configuration choice (λ gradient, bank gradient, rotor mask). Source: KTD.jl `scripts/render_pca_landscape.jl`, V10 Tight campaign.

---

### Figure 2 — Non-Dimensional Physics Atlas

![V10 Tight non-dimensional atlas](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-tight-nondim.png)

**Figure 2.** PCA design space coloured by nine non-dimensional Pi groups, revealing the physical mechanisms behind the 49.2 kg optimum. **Legend — panels left to right, top to bottom:** (1) **Beam Slenderness L_r/D** — segment length to beam diameter ratio; winner achieves ~50, at the structural minimum diameter (Do_top = 0.06 m) and maximum segment length (target_Lr = 3.0 m). (2) **Beam Efficiency (t/D)×(L_r/D)** — column buckling metric; dominated by slenderness since wall thickness t/D = 0.01 is pinned at minimum across all feasible designs. (3) **TRPT Aspect L×n/r_hub** — total polygon perimeter to hub radius; winner at ~13.5, reflecting compact hub (2.89 m) with 13-sided polygon. (4) **Ring Packing L_r/(n×D)** — structural material efficiency per ring; 41% higher than V10v1. (5) **Power Loading P/(½ρ π r_hub² V³)** — rotor disc loading relative to Betz flux; ~2.4× at winner, requiring significant expansion rotor contribution. (6) **Ring Taper (r_hub − r_bottom)/r_hub** — TRPT conicity; shifted from inverted (−0.24 in V10v1) to normal taper (+0.31), driven by multi-rotor thrust distribution. (7) **Rotor Solidity n_blades×c/(2πR)** — blade area per unit disc circumference; tripled from V10v1 (0.05 → 0.15) as k_mppt λ² scaling forces larger blades. (8) **Expansion/Structural Ratio log₁₀** — rotor swept area relative to beam cross-section; decreased from 250× to 32× as compact structure grows relative to expansion. (9) **Mass (kg)** — objective function; white iso-contours at 50 and 65 kg, yellow diamond at 49.2 kg winner. Source: KTD.jl `scripts/render_nondim_atlas.jl`, V10 Tight campaign. Full panel-by-panel explainer: `docs/awes-forum-diagrams/v10-tight-nondim-explainer.md`.

---

### Figure 3 — Island Convergence Paths

![V10 Tight convergence paths](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-tight-paths.png)

**Figure 3.** Four-panel convergence analysis of the V10 Tight DE campaign. **Legend:** (a, top-left) PCA landscape with individual island convergence traces; each coloured path tracks one DE island from initial random population to final optimum. (b, top-right) Mass convergence trace — best mass per generation, showing rapid early descent followed by refinement. (c, bottom-left) Mass-vs-slenderness trade-off with Pareto front. (d, bottom-right) Key findings summary. The convergence pattern confirms the multi-rotor basin is the dominant attractor: 58 of 60 islands converge to the same 49–75 kg region despite independent random initialisation. Source: KTD.jl `scripts/render_convergence_paths.jl`.

---

### Figure 4 — Campaign Mass Evolution: V6 to V10 Tight

![V9 campaign convergence](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v9-convergence.png)

**Figure 4.** Mass reduction across KTD.jl campaign versions (V6 → V10 Tight). **Legend:** Each curve shows best airborne mass (kg) vs. DE evaluations for a single campaign configuration. Key transitions: V6 baseline (259 kg, n=8, 3 expansion rotors, pre-physics corrections) → V6.2 (74.17 kg, n=12, 1 expansion rotor, sin formula + coupled knuckle mass) → V9 (44.52 kg, dynamic ω solver, 3 bounds screaming) → V10 (76.75 kg, unified rotors, 8 gates) → V10 Tight (49.20 kg, 4 rotors, k_mppt λ² + ring-mapping fixes). The 36% mass reduction from V10 to V10 Tight (76.75 → 49.20 kg) was achieved entirely through DE algorithm corrections (ring-mapping and k_mppt scaling), with no changes to the physical model. Source: KTD.jl campaign result CSVs.

---

### Figure 5 — Parameter Convergence: Five Bounds Screaming

![V10 Tight parameter mass](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-tight-param-mass.png)

**Figure 5.** Per-parameter convergence behaviour for the V10 Tight campaign, showing which design variables hit their search bounds. **Legend:** Each panel shows the distribution of a single parameter across all island final populations. **Five parameters are screaming at their bounds:** Do_top at minimum (0.06 m, structural floor), t_over_D at minimum (0.01, manufacturing limit), target_Lr at maximum (3.0 m, geometric constraint), r_bottom at minimum (2.0 m, ground clearance), λ_bottom at minimum (0.10). These bounds define the current structural envelope — the true global optimum lies outside, suggesting wider bounds would find designs below 49 kg. Source: KTD.jl `scripts/render_param_convergence.jl`.

---

### Figure 6 — Non-Dimensional Comparison: V10v1 vs V10 Tight

| Pi Group | V10v1 (76.75 kg) | V10 Tight (49.20 kg) | Δ | Driver |
|----------|-------------------|---------------------|---|--------|
| Slenderness L_r/D | 39.1 | ~50 | +28% | Do_top at min, L_r at max |
| TRPT Aspect L·n/r_hub | ~11.5 | ~13.5 | +17% | Compact hub, more lines |
| Power Loading | 1.43 | ~2.4 | +68% | Smaller hub needs expansion power |
| Ring Taper | −0.24 (inverted) | +0.31 (normal) | flip | Multi-rotor thrust distribution |
| Solidity | 0.052 | 0.15 | +188% | k_mppt λ² forces larger blades |
| Exp/Struct | 250× | 32× | −87% | Compact structure vs expansion |

**Table 1.** Non-dimensional comparison between V10v1 (single-rotor optimum) and V10 Tight (multi-rotor optimum after ring-mapping and k_mppt fixes). Values from `docs/awes-forum-diagrams/v10-tight-nondim-explainer.md`.

---

## Generated Figures (all complete)

The following figures have been generated and verified. Source `.tex` and rendered `.pdf`/`.png` files are in `docs/porto-2026/`.

1. **Figure G1 — System schematic** — TRPT kite turbine assembly: lifter kite, ring polygon, expansion rotors, TRPT tethers, ground generator. `fig-system-schematic.pdf` ✓
2. **Figure G2 — Static-vs-dynamic gap bar chart** — 50 kW (static equilibrium) vs 12 kW (dynamic ODE) vs 18–21% literature. `fig-power-gap.pdf` ✓
3. **Figure G3 — Ring-mapping topology diagram** — Intermediate ring i → system ring i+1 with ground (ring 1) and hub (ring n+2) offsets. Commit 71ea694. `fig-ring-mapping.pdf` ✓

### Figure 4 — Literature Grounding Map

![KTD Literature Grounding Map](/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/porto-2026/fig-lit-map-1.png)

**Figure 4.** K1 literature grounding map showing the 6 KTD techniques and their citation lineage. **Legend:** Central red node = KTD.jl with 6 techniques. Blue technique nodes radiate outward, each connected to published paper nodes (black rectangles) via labelled edges indicating relationship type (origin, extends, validates, context). The ring-mapping technique (bottom-left) is internal architecture with no citation — shown with dashed border. The K1 Knowledge Graph stats box at bottom centre confirms the underlying graph scale: 7,048 nodes, 9,775 edges, 540 academic + 45 industry papers, 586 individual graph files. Source: K1 knowledge graph extraction pipeline; full citation lineage in `docs/porto-2026/citation-lineage.md`.

---

## Section Plan

### 1. Introduction
- AWE promise and TRPT advantages (cite: Loyd 1980, Diehl 2013, Tulloch 2023)
- The static-dynamic gap problem (cite: Kheiri 2018, Carceller Candau 2022)
- KTD.jl: an open-source framework for TRPT design optimisation
- Paper contributions: 5 novel techniques + 1 architectural fix, 1 framework, 1 quantified gap

### 2. Methods
#### 2.1 KTD.jl Architecture
- DE optimiser + equilibrium solver + multibody verifier (Fig 1)
- Design vector (14 DoF in V10)
- Ring-mapping topology (+2 offset, commit 71ea694)

#### 2.2 Physics Models
- k_mppt λ² scaling (commit 1c86b69) — Fig 5, Fig 6
- TRPT MTR with shaft_section_mtr()
- Tether drag (Tveide ODE, ¼ coefficient, n× parallel)
- 6-DOF inertia relief for free-floating rings (ADR 0001)
- Expansion rotor model (force-first, bank angle)

#### 2.3 Literature Grounding
- K1 knowledge graph: 540 academic + 45 industry papers, 7,048 nodes, 9,775 edges
- Automated extraction pipeline (session record: `docs/reports/knowledge-pipeline-sprint.md`)
- Citation lineage per technique (citation-lineage.md)

### 3. Results
#### 3.1 Optimisation Campaigns
- V6–V10 campaign history (Fig 4)
- V10 Tight: 49.2 kg, 4 rotors, λ = 0.519 (Fig 1, Fig 2)
- Parameter convergence behaviour (Fig 5)

#### 3.2 Static-vs-Dynamic Gap
- 50 kW (static) → 12 kW (dynamic) = 4.2× (Fig 6, Table 1)
- Comparison to literature: 18–21%
- Physical origin: torque transmission neglect in equilibrium solver

#### 3.3 Technique Validation
- Per-technique evidence from campaign data
- Web-validated novelty (all claims clean)
- Moore CSR check: no inertia relief overlap

### 4. Discussion
- What the 4.2× gap means for TRPT design
- Multi-rotor viability at 50 kW
- Remaining gaps: rigid blade design, 50 kW economics, wake interaction
- Comparison to Wacker (2022): shared Daisy Kite heritage, different approach

### 5. Conclusion
- 5 novel techniques + 1 architectural fix, all literature-grounded
- 4.2× gap is TRPT-specific and unresolved
- KTD.jl is open-source, available for community use
- Future work: close the gap, field validation, blade design optimisation

---

## Citation Map

| Reference | Used For |
|-----------|----------|
| Loyd (1980) | Crosswind power law, tether drag exclusion |
| Diehl (2013) | AWE power fundamentals, drag-mode theorem |
| Tulloch et al. (2023) | TRPT definition, steady-state model, MTR |
| Tulloch PhD (2021) | TRPT dynamics, tether drag model, steady-state analytical model |
| Tveide TetherDragODESolver | ¼ tether drag coefficient validation |
| Kheiri et al. (2018) | Induction factor effects in crosswind kite power limits |
| Carceller Candau (2022, MSc) | 18% power overestimation from neglected dynamic inflow |
| Pfister & Blondel (2020) | BEM vs. free-vortex wake comparison at inclined rotors |
| Wacker (2022) | Daisy Kite steady-state optimisation |
| Moore (2014) | Centrifugally stiffened rotor context |
| NASA TM-1995-13233 | Inertia relief fundamentals |
| Read (various) | Daisy Kite design, experimental data |

---

## Open Questions for Phase 4/5

- [ ] Extract exact MTR values from V10 campaign CSVs
- [ ] Extract λ convergence data for k_mppt claim
- [ ] Generate system schematic (Figure to-be-generated #1)
- [ ] Generate static-vs-dynamic gap bar chart (Figure to-be-generated #2)
- [ ] Generate ring-mapping diagram (Figure to-be-generated #3)
- [ ] Generate literature map from K1 graph (Figure to-be-generated #4)
- [ ] Verify all citations in K1 graph with exact evidence spans
- [ ] Cross-reference Wacker's Daisy Kite parameters against KTD V10 inputs
- [ ] Include CoaxialAutogyroStacking.jl lift model integration
- [ ] Format per target venue (AWES conference template or Wind Energy Science)
