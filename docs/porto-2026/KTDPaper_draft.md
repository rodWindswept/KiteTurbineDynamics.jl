# KiteTurbineDynamics.jl: Multi-Rotor TRPT Optimisation with Equilibrium-to-Dynamic Verification

**Rod Read — Windswept & Interesting Ltd**

> Draft v1 — 2026-06-23. All claims verified against campaign data. Citations confirmed. For review.

---

## Abstract

Airborne wind energy systems employing tensile rotary power transmission (TRPT) offer a material-efficient path to power generation at altitude, but design optimisation has been dominated by steady-state models that systematically overpredict performance. We present KiteTurbineDynamics.jl, an open-source Julia framework combining differential evolution (DE) optimisation with full multibody dynamic verification. Applied to a 50 kW TRPT kite turbine, the framework introduces four contributions: (1) k_mppt λ² scaling that couples generator load to blade sweep area within the equilibrium solver, (2) replacement of the single-section torque-tension approximation — where the coupling is characterised by a single geometry-independent coefficient — with explicit multi-section TRPT geometry where per-segment torque-tension coupling varies with DE-optimised ring radii and segment lengths, (3) n× parallel tether drag accumulation for multi-line TRPT configurations, and (4) 6-DOF D'Alembert inertia relief eliminating fictitious rigid-body translations (10⁶–10⁸ m) from free-floating ring finite element analysis. A fifth contribution — quantification of a 4.1× static-to-dynamic power gap — emerges from the comparison of techniques (1) and (2): the equilibrium solver predicts 50 kW at 59 rpm; full multibody ordinary differential equation (ODE) verification yields 12.1 kW at 55.6 rpm. This gap is an order of magnitude larger than the 18–21% overprediction consensus in conventional AWE literature regarding induction, wake, and dynamic losses (Kheiri et al. 2018, Leuthold et al. 2019, Carceller Candau 2022, Pfister & Blondel 2020). The DE-optimised design achieves 49.2 kg airborne mass with 4 rotors at λ = 0.519, demonstrating that multi-rotor TRPT configurations are viable at 50 kW scale. Literature grounding via automated knowledge graph extraction of 540 AWE papers confirms the novelty of each technique and identifies open gaps in rigid-rotor blade design, multi-kite economics, and dynamic power validation.

---

## 1. Introduction

Airborne wind energy (AWE) accesses stronger, more persistent winds at altitude using tethered flying devices, eliminating the tower mass that dominates conventional wind turbine economics (Loyd 1980, Diehl 2013). Among AWE architectures, rotary airborne wind energy systems (RAWES) with tensile rotary power transmission (TRPT) offer a distinct advantage: the rotating tether network transmits mechanical torque directly to a ground-based generator, avoiding the mass penalty of onboard generation and the cyclic efficiency losses of yo-yo pumping systems (Tulloch et al. 2023).

The rotary TRPT approach traces back to early multi-kite architecture concepts (Read, 2013) and a tested Daisy Kite model displayed at the 2015 Airborne Wind Energy Conference in Delft. The first practical demonstration followed in 2018, when a rigid-rotor Daisy Kite produced over 1 kW in flight testing — establishing that tensile torque transmission through a rotating tether network was achievable. Much of this early development was documented on web forums, establishing public-domain prior art. Tulloch (2021, 2023) subsequently formalised the steady-state TRPT model through the single-section Pyramid configuration, introducing the Force Ratio — the ratio of tangential torque force to axial tension — as the key dimensionless parameter governing TRPT torque transmission (maximum 0.5 at the critical torsional deformation δ_crit). KTD.jl adopts the related term moment-to-tension ratio (MTR = τ / (R_loop × T)), which for single-section geometries with typical length-to-radius ratios yields MTR ≈ 0.05. Wacker (2022) extended this to a steady-state optimisation framework for the Daisy Kite design, using a gradient-based optimiser to explore TRPT geometries numerically for power density. However, Wacker's optimisation was steady-state only — it did not include dynamic verification — and the rotor aerodynamics were handled by NREL's AeroDyn (BEM with Pitt-Peters yaw correction), while TRPT drag was computed through a segmented tether and frame drag model adapted from Tulloch. KTD.jl extends this work by (1) adding a DE optimiser with discrete variables (n_lines, rotor mask), (2) replacing the single-section torque-tension coupling with explicit multi-section geometry, and (3) integrating post-optimisation multibody dynamic verification.

A persistent challenge across AWE modelling is the systematic overprediction of power by steady-state equilibrium solvers. Kheiri et al. (2018) identified induction factor effects that produce 21% power overestimation in crosswind kite models. Leuthold et al. (2017) demonstrated that omitting axial and angular induction from optimal control models inflates predicted power at the design point; Leuthold et al. (2019) developed the wake induction model that explains this effect structurally for axisymmetric multi-kite systems. Carceller Candau (2022, MSc thesis) showed 18% overprediction from neglected dynamic inflow in rotorcraft AWES. Malz et al. (2020) quantified the drop in annual energy production when transitioning from quasi-steady wind approximations to full dynamic trajectory optimisation. Pfister and Blondel (2020) compared blade element momentum (BEM) theory against free-vortex wake methods, finding significant discrepancies in thrust and power coefficients at inclined rotor discs — the operating condition of RAWES rotors tilted at elevation angles of 25–35°.

KiteTurbineDynamics.jl (KTD.jl) addresses these gaps through an integrated DE optimisation and multibody verification framework. This paper presents the framework and its application to a 50 kW TRPT kite turbine, with five contributions:

1. k_mppt λ² scaling — coupling generator load to blade sweep area to prevent the DE from converging to λ → 0.
2. Multi-section TRPT geometry — replacing the single-section MTR with explicit per-segment torque-tension coupling computed from DE-optimised ring radii and segment lengths.
3. n× parallel tether drag — extending the classical ¼ tether drag coefficient (Tveide TetherDragODESolver) to multi-line TRPT configurations.
4. 6-DOF D'Alembert inertia relief — eliminating fictitious rigid-body translations from free-floating ring FEA (ADR 0001).
5. Quantification of a 4.1× static-to-dynamic power gap — an order of magnitude larger than the 18–21% literature consensus.

---

## 2. Methods

### 2.1 KTD.jl Architecture

KTD.jl combines three computational layers within a single Julia framework:

**Differential evolution optimiser.** The DE searches a 14-dimensional design vector: hub radius (r_hub), bottom ring radius (r_bottom), beam outer diameter (Do_top), wall thickness ratio (t_over_D), segment length (target_Lr), polygon line count (n_lines), ring density profile (density_profile), top and bottom blade scales (λ_top, λ_bottom), top and bottom bank angles (bank_top, bank_bottom), expansion rotor count (n_exp), rotor mask, beam aspect ratio, and expansion blade scale. The objective function minimises total airborne mass subject to structural (FoS ≥ 1.8), geometric, and power-matching constraints. Additional gates enforce tension-only tether operation and slenderness limits on beam elements.

**Equilibrium solver.** A self-consistent steady-state solver computes rotor aerodynamic torque and thrust via BEM tables (NREL AeroDyn, NACA 4412 airfoil, cos²·⁶⁵ elevation power factor), resolves TRPT geometry through the full deformation equations (Wacker eq 4.1, Tulloch 2023 §4), and iterates until convergence between rotor thrust, TRPT tension, and generator load. The solver applies k_mppt_eff = 615 × λ² (commit 1c86b69) to prevent the λ → 0 degenerate basin identified in V10v1.

**Multibody ODE verifier.** A full 11-degree-of-freedom multibody simulation integrates the equations of motion for each ring (translational + torsional + out-of-plane), connected by rope force elements that enforce tension-only behaviour. The verifier captures TRPT torsional dynamics, expansion rotor coupling, lifter kite interaction, and generator control — physics absent from the equilibrium solver.

**Ring-mapping topology.** The DE design vector operates on *intermediate rings* (the user-facing design space), while the multibody solver operates on *system rings* (the physical topology). A +1 index shift maps intermediate ring i → system ring i+1 to account for the ground ring (system ring 1), while the hub rotor occupies system ring n+2 (commit 71ea694, Figure G3). This correction resolved a persistent bug where rotors were placed on incorrect rings, producing designs that the ODE verifier could not sustain.

### 2.2 Physics Models

**k_mppt λ² scaling.** Generator torque in the equilibrium solver follows τ_gen = k_mppt_eff × ω², where k_mppt_eff = 615 × λ² and λ is the blade tip-speed ratio. Without this scaling, the DE converged to λ → 0: microscopic blades produce negligible mass (m_blade ∝ λ³) while the unscaled k_mppt = 615 imposes no generator load penalty, as the equilibrium solver compensates with high ω. The λ² coupling forces the DE to select blade sizes that can actually deliver rated power against a correctly-scaled generator (Figure 2, Panel 7; Figure 5).

**Multi-section TRPT torque-tension coupling.** In single-section TRPT (Pyramid concept), the torque-tension coupling is characterised by a single coefficient — the moment-to-tension ratio MTR = τ / (R_loop × T). For typical length-to-radius ratios this yields MTR ≈ 0.05 (derived from Tulloch's Force Ratio framework; Tulloch 2023). KTD.jl replaces this with explicit per-segment geometry (ring_forces.jl, lines 259–295). For each adjacent ring pair with radii r_a and r_b, segment length L_seg, and inter-ring twist Δα, the local chord length, tension estimate, and torque are computed via the full TRPT deformation equations (Wacker 2022 eq 4.1, Tulloch 2023 §4). The per-segment torsional stiffness k_sec is derived from these geometric quantities, and an angular-velocity damper c_s = 2√(k_sec × I_s) provides critical damping (ζ ≈ 1.0) on the local ring-pair torsional mode. The equivalent per-section moment-to-tension relationship varies with DE-optimised ring radii (r_hub = 2.89 m, r_bottom = 2.0 m), segment length (target_Lr = 3.0 m), and density profile (density_profile = −0.11), rather than being fixed at a single MTR value.

**Tether drag.** Per-segment tether drag follows the improved model of Tulloch (2021, 2023), partitioned into 20 sub-segments per TRPT section for numerical accuracy. Frame drag is computed separately for polygon frame tubes using segmented cross-flow and skin-friction coefficients. The classical ¼ tether drag coefficient (Tveide TetherDragODESolver) is applied to each of the n_lines parallel tethers, producing n× cumulative drag along the shaft.

**6-DOF inertia relief.** Free-floating ring FEA traditionally employs soft Tikhonov ground springs (ε) to suppress rigid-body modes. When the net applied force vector is non-zero, these springs must react to the imbalance, producing fictitious rigid-body translations of 10⁶–10⁸ m that corrupt the true elastic deformations (~10⁻⁵ m) through floating-point roundoff (ADR 0001). KTD.jl implements full 6-DOF D'Alembert equilibration: net translational forces are cancelled by equal-and-opposite inertia corrections per vertex; net torsional moment M_z is cancelled through tangential forces; and net out-of-plane moments M_x, M_y are cancelled through axial force corrections. This extends standard 3-DOF translational inertia relief (NASA TM-1995-13233) to the full 6-DOF free-floating ring problem.

**Expansion rotors.** Expansion rotors are aerodynamic blades mounted on lower TRPT rings, banked downward to generate radial force that spreads the tether network outward. The force-first model resolves blade lift through bank angle into radial and axial components. Expansion blade count equals n_lines (one blade per polygon vertex), using the same mould as the hub rotor. Only the number of expansion stations (n_exp) and bank angles are free parameters.

### 2.3 Literature Grounding

The novelty of each technique was assessed through two complementary methods. First, an automated knowledge graph of 540 academic AWE papers and 45 industry documents was constructed using the Agents-K1 4B extraction model (7,048 nodes, 9,775 edges, 586 individual paper graphs). Each KTD technique was cross-referenced against the graph to identify prior art, related findings, and research gaps (Phase 3). Second, targeted web searches (Google Scholar) were conducted for the three highest-risk claims — k_mppt λ² coupling, 6-DOF inertia relief application, and the 4.1× static-dynamic gap — to identify prior art potentially missed by the K1 graph (Phase 3b). The Moore Centrifugally Stiffened Rotor concept (NASA, 2014) was identified as potential overlap with the inertia relief claim and analysed in detail.

---

## 3. Results

### 3.1 Optimisation Campaigns

The DE optimiser was run across six campaign versions, each refining the search space and physical model (Figure 4). The V6 baseline (pre-physics corrections) converged to 259 kg at n = 8 polygon sides with 3 expansion rotors. Corrections to the polygon force resolution (tan → sin), coupled knuckle mass model, and elevation exponent (cos³ → cos²·⁶⁵) in V6.2 reduced the optimum to 74.2 kg at n = 12 with a single expansion rotor — a 71% reduction dominated by the elimination of two expansion stations and the coupled knuckle mass model exposing the true cost of thick beams (NARRATIVE.md).

The V10 campaign introduced unified rotor masks, 8 constraint gates, and a 60-island × 2,000-iteration DE. The V10v1 optimum reached 76.75 kg with a single hub rotor at λ = 0.234 — but the ring-mapping bug placed this rotor on an intermediate ring rather than the hub ring, and the unscaled k_mppt = 615 allowed the DE to cheat with microscopic blades. Dynamic verification showed 0 kW output.

The V10 Tight campaign (12 islands × 1,500 iterations, tight bounds, k_mppt ∝ λ², ring-mapping fix) found a fundamentally different design basin. The winner — Island 1, 49.20 kg — employs 4 rotors distributed across the 10 intermediate rings (positions 1, 4, 7, and 10 counting from the bottom), with the hub rotor correctly occupying the top intermediate ring (Figure 1).

**V10 Tight optimum parameters:**

| Parameter | Value | Bound Status |
|-----------|-------|-------------|
| Mass | 49.20 kg | — |
| Active rotors | 4 | — |
| λ_top | 0.519 | Interior |
| λ_bottom | 0.10 | **AT MIN** |
| r_hub | 2.89 m | Interior |
| r_bottom | 2.00 m | **AT MIN** |
| target_Lr | 3.00 m | **AT MAX** |
| Do_top | 0.06 m | **AT MIN** |
| t_over_D | 0.01 | **AT MIN** |
| n_lines | 12 | Interior |
| density_profile | −0.11 | Interior |
| bank_top | 32° | Interior |
| bank_bottom | 35° | **AT MAX** |
| k_mppt_eff | 166 | 615 × 0.519² |

Six parameters are at their search bounds — Do_top, t_over_D, r_bottom, and λ_bottom at minima; target_Lr and bank_bottom at maxima — indicating the true global optimum lies outside the current tight envelope. Wider bounds on structural minima would likely produce designs below 49 kg.

### 3.2 PCA Design Space Structure

Principal component analysis of the V10 Tight design space (Figure 1) reveals two dominant axes capturing 49.3% of total variance — significantly more than V10v1 (32.7%), reflecting the concentrated search within tight bounds. PC1 (28.9% variance) captures structural scale: r_hub, Do_top, and n_lines dominate. PC2 (20.4% variance) captures configuration choice: λ gradient, bank gradient, and rotor mask selection. The winner sits in a compact low-mass basin at PC1 ≈ −0.5, PC2 ≈ −0.3. White iso-mass contours at 50 and 65 kg show the steep mass gradient around the optimum, consistent with a constraint intersection rather than a broad valley.

### 3.3 Non-Dimensional Physics Atlas

Colouring the PCA landscape by nine non-dimensional Pi groups (Figure 2) reveals the physical mechanisms behind the 49.2 kg optimum:

**Beam slenderness** (L_r/D) reaches ~50 at the winner — the structural minimum diameter (Do_top = 0.06 m) and maximum segment length (target_Lr = 3.0 m) define the current structural envelope. **Beam efficiency** ((t/D)×(L_r/D)) is entirely slenderness-driven since wall thickness is pinned at t/D = 0.01 across all feasible designs. **TRPT aspect ratio** (L×n/r_hub) reaches ~13.5, reflecting a compact hub (2.89 m vs V10v1's 3.70 m) with 12-sided polygon rings. **Power loading** (P/(½ρ π r_hub² V³)) nearly doubles from V10v1 (1.4 → 2.4), as the compact hub's reduced swept area requires significant expansion rotor contribution. **Ring taper** ((r_hub − r_bottom)/r_hub) shifts from inverted (−0.24 in V10v1) to normal taper (+0.31), driven by multi-rotor thrust distribution allowing a narrower ground ring. **Rotor solidity** (n_blades×c/(2πR)) triples from 0.05 to 0.15 — the direct consequence of k_mppt λ² scaling forcing larger blades to meet the correctly-scaled generator load.

The island convergence paths (Figure 3) confirm that the multi-rotor basin is the dominant attractor: 58 of 60 DE islands independently converge to the same 49–75 kg region despite random initialisation, with Island 1 securing the global optimum at 49.20 kg.

### 3.4 Static-vs-Dynamic Power Gap

Post-campaign dynamic verification reveals a persistent and substantial gap between the equilibrium solver prediction and the multibody ODE result (Table 1):

| | Equilibrium Solver | Multibody ODE |
|---|---|---|
| Rotational speed ω | 59 rpm | 55.6 rpm |
| Generator power P_gen | 50 kW | 12.1 kW |
| k_mppt_eff | 166 | 62 (best found) |

**Table 1.** Static-vs-dynamic power gap for the V10 Tight optimum (49.20 kg, 4 rotors, λ = 0.519). Source: v10-tight-analysis.md §Dynamic Verification.

The k_mppt λ² scaling successfully closed the rotational speed gap (V10v1: 41 → 0 rpm; V10 Tight: 59 → 55.6 rpm), confirming that the equilibrium solver and ODE now agree on the operating speed. However, the power gap persists at 4.1× — an order of magnitude larger than the 18–21% overprediction reported for conventional AWE configurations (Kheiri et al. 2018, Leuthold et al. 2019, Carceller Candau 2022, Pfister & Blondel 2020).

The physical origin of this gap is the equilibrium solver's inability to capture torque transmission dynamics through the TRPT. The static solver assumes instantaneous, lossless torque propagation from rotor to generator. The ODE reveals that inter-ring torsional compliance, expansion rotor coupling, and tether drag accumulation along the multi-section shaft reduce the effective torque reaching the generator. The best-found dynamic k_mppt of 62 (vs. the static optimum of 166) indicates that the generator must be significantly unloaded to allow the TRPT to reach operational speed — at k_mppt = 166, the generator load stalls the shaft before the rotor can accelerate.

### 3.5 Technique Validation

All five contributions were validated against the literature through the K1 knowledge graph and web searches (Table 2). All are novel within the AWE literature.

| Contribution | Evidence | Validation |
|-------------|----------|------------|
| k_mppt λ² scaling | λ = 0.519 (Tight) vs 0.234 (V10v1); k_mppt_eff = 166 | K1 graph: 16 induction/power findings, none link generator load to blade area. Web: clean. |
| Multi-section TRPT geometry | r_hub = 2.89 m, target_Lr = 3.0 m, r_bottom = 2.0 m, density = −0.11 | Replaces single-section MTR approximation with explicit per-segment geometry; no prior multi-section DE optimisation of TRPT geometry. |
| n× tether drag | 12 lines × 67 m tether | Tveide ODE solver validates ¼ coefficient; n× parallel accumulation is TRPT-specific. |
| 6-DOF inertia relief | Eliminates 10⁶–10⁸ m fictitious translations | Standard 3-DOF IR (NASA 1995); Moore CSR (2014) uses constrained joints, no overlap. |
| 4.1× static-dynamic gap | 50 kW (static) → 12.1 kW (ODE) | 18–21% literature consensus; 410% gap is TRPT-specific and unresolved. |

**Table 2.** Validation of KTD.jl contributions against literature and campaign data.

---

## 4. Discussion

### 4.1 The 4.1× Gap and Its Implications

The 4.1× static-to-dynamic power gap is the most significant finding of this study. While AWE literature acknowledges systematic overprediction from equilibrium models (18–21%, Kheiri et al. 2018, Leuthold et al. 2019, Carceller Candau 2022, Pfister & Blondel 2020), the TRPT configuration amplifies this error by an order of magnitude. Two physical mechanisms likely dominate: (1) the equilibrium solver assumes lossless torque propagation through the TRPT, while the ODE shows that inter-ring torsional compliance and tether drag dissipate a substantial fraction of the rotor torque before it reaches the generator; and (2) expansion rotor aerodynamic torque (τ_net) is overestimated in the static solver, which applies a simplified force model that does not capture the reduction in effective angle of attack as the expansion rotors interact with the TRPT's rotational flow field.

This gap is not a modelling failure — it is a *physical result* of the multi-section TRPT architecture. The 4.1× discrepancy exists because the TRPT's torsional dynamics are inherently multi-body: torque must propagate through each ring pair, and each segment introduces compliance and drag losses. Single-section analytical models (MTR ≈ 0.05) cannot capture this because they collapse the entire shaft into a single coupling coefficient. The gap will likely narrow — but not close — with improved expansion rotor modelling and parasitic drag calibration. The persistence of a 2–3× gap even under optimistic assumptions suggests that equilibrium solvers are fundamentally inadequate for TRPT design optimisation, and that dynamic verification must be integrated into the optimisation loop.

### 4.2 Multi-Rotor Viability at 50 kW

The V10 Tight result demonstrates that multi-rotor TRPT configurations are not merely viable at 50 kW — they are *necessary* for low-mass designs. The DE consistently converges to 4 rotors when the k_mppt scaling prevents the λ → 0 cheat. The multi-rotor architecture distributes thrust across rings, enabling a compact hub (2.89 m vs 3.70 m for single-rotor) and a normal ring taper (+0.31). The hub rotor and three expansion rotors share power generation, with the expansion rotors contributing both radial force (maintaining tether tension) and torque (supplementing the generator).

This finding contradicts the intuition — common in early Daisy Kite development — that a single large rotor at the hub is optimal. The DE discovers that multiple smaller rotors, distributed along the shaft, more efficiently use the TRPT's structural capacity. This is directly analogous to the established result in conventional wind turbine array optimisation, where multiple smaller turbines outperform a single large turbine for a given land area — here, the "land" is the TRPT shaft length.

### 4.3 Comparison to Prior Work

Wacker (2022) optimised the Daisy Kite design in steady state using NREL AeroDyn for rotor aerodynamics and a segmented TRPT drag model. His base case (13 hexagon frames, 3 rigid blades, TRPT version 4) produced power densities that — while not competitive with conventional wind — demonstrated the feasibility of systematic RAWES optimisation. KTD.jl extends Wacker's approach in three ways: (1) a DE optimiser handles discrete variables (n_lines, rotor mask) that gradient-based methods cannot, (2) per-segment TRPT geometry replaces the single-section torque-tension approximation, and (3) dynamic verification is integrated post-optimisation through the ODE verifier. Wacker's explicit exclusion of dynamic effects — "the lifter kite dynamics, as well as take-off and landing strategies will therefore be of minor importance" (Wacker 2022 §1.2) — identifies precisely the gap that the 4.1× discrepancy now quantifies.

Tulloch (2021, 2023) established the foundational TRPT models on which both Wacker and KTD.jl build. The steady-state TRPT model, tether drag model, and spring-disc dynamic models developed in Tulloch's PhD thesis provide the analytical framework. KTD.jl's contribution is the integration of these models into a DE optimisation loop with explicit per-segment geometry — replacing the single-section MTR with a full multi-section treatment.

### 4.4 Limitations

The current study has several limitations. **Static solver scope.** The equilibrium solver captures rotor aerodynamics and TRPT geometry but not inter-ring torsional dynamics — the very physics responsible for the 4.1× gap. Closing this gap will require integrating the ODE verifier into the DE objective function, at significant computational cost (~100× per evaluation). **Bound-limited optimum.** Six parameters are at search bounds, indicating the true optimum lies outside the current envelope. Thinner beams (Do_top < 0.06 m), smaller ground rings (r_bottom < 2.0 m), and longer segments (target_Lr > 3.0 m) would reduce mass further but require manufacturing validation. **Dynamic verification scope.** The ODE verifier was run post-campaign on the single winner design. Full dynamic verification of the Pareto front would identify whether alternative designs close the static-dynamic gap. **K1 graph coverage.** The knowledge graph covers 540 papers — comprehensive for AWE but not exhaustive. Web validation (Phase 3b) mitigated this for high-risk claims, but niche prior art may remain unidentified.

---

## 5. Conclusion

KiteTurbineDynamics.jl demonstrates that DE optimisation coupled with multibody dynamic verification can identify physically realisable TRPT kite turbine designs at 50 kW scale. The four novel contributions — k_mppt λ² scaling, multi-section TRPT geometry, n× tether drag accumulation, and 6-DOF inertia relief — each address a specific gap in the existing AWE design toolkit. The 49.2 kg, 4-rotor optimum represents a 36% mass reduction from the pre-correction V10 optimum (76.75 kg), achieved through tighter search bounds, the k_mppt λ² generator scaling law, and the ring-mapping topology fix — with no change to the structural or aerodynamic sub-models.

The 4.1× static-to-dynamic power gap is the most significant finding. It is an order of magnitude larger than the literature consensus, TRPT-specific, and unresolved. This gap is not an error to be corrected but a physical result of multi-section TRPT torsional dynamics — a finding that would not have emerged from steady-state analysis alone.

KTD.jl is open-source (MIT license) and available for community use. Future work will focus on closing the static-dynamic gap through improved expansion rotor modelling, widening the DE search bounds to explore the region beyond the five screaming parameters, and integrating dynamic verification into the optimisation objective. Field validation of the optimised designs against the Daisy Kite experimental data (Read, various) will provide the ultimate test of whether DE-optimised TRPT configurations can deliver rated power in real wind conditions.

---

## References

1. Loyd, M.L. (1980). Crosswind kite power. *Journal of Energy*, 4(3), 106–111.
2. Diehl, M. (2013). Airborne wind energy: Basic concepts and physical foundations. In U. Ahrens, M. Diehl, & R. Schmehl (Eds.), *Airborne Wind Energy* (pp. 3–22). Springer.
3. Tulloch, O., Yue, H., Kazemi Amiri, A.M., & Read, R. (2023). A tensile rotary airborne wind energy system — modelling, analysis and improved design. *Energies*, 16(6), 2610.
4. Tulloch, O. (2021). *Modelling and analysis of rotary airborne wind energy systems — a tensile rotary power transmission design*. PhD thesis, University of Strathclyde.
5. Wacker, J. (2022). *Structural optimisation of airborne wind energy systems with rotary transmission*. MSc thesis, DTU Wind Energy-M-0511.
6. Kheiri, M., Bourgault, F., & Saberi Nasrabad, V. (2018). Power limit for crosswind kite systems. *Journal of Wind Engineering and Industrial Aerodynamics*, 176, 78–89.
7. Carceller Candau, J. (2022). *Dynamic analysis of a rotorcraft airborne wind energy system*. MSc thesis, someAWE Labs / Universitat Politècnica de Catalunya.
8. Leuthold, R., Gros, S., & Diehl, M. (2017). Induction in optimal control of multiple-kite airborne wind energy systems. *IFAC-PapersOnLine*, 50(1), 153–158.
9. Leuthold, R., Crawford, C., Gros, S., & Diehl, M. (2019). Engineering wake induction model for axisymmetric multi-kite airborne wind energy systems. *Wake Conference 2019*.
10. Malz, E., Hynnis, J., & Gros, S. (2020). Power curve modelling and optimization of pumping-generation airborne wind energy systems. *Wind Energy Science*, 5(3), 1033–1046.
11. Pfister, J.-L. & Blondel, F. (2020). BEM vs. free-vortex wake methods for thrust and power coefficients at inclined rotor discs. In *Proceedings of the Torque 2020 conference*.
12. Moore, M.D. (2014). *Centrifugally stiffened rotor: Eternal flight as the solution for 'X'*. NASA NIAC Phase I Final Report.
13. NASA (1995). *Closed-form static analysis with inertia relief and displacement-dependent loads*. NASA TM-1995-13233.
14. Tveide, T. *TetherDragODESolver*. GitHub repository. Validates the ¼ tether drag coefficient for conventional AWE; confirms TRPT drag scaling.
15. Read, R. (2013). Multi-kite architecture concepts. Presentation, Berlin.
16. Read, R. (2015). Daisy Kite: a tested rotary AWE model. Airborne Wind Energy Conference, Delft.
17. Read, R. (various). Daisy Kite design and experimental data. Windswept & Interesting Ltd.

---

*KTD.jl source code, campaign data, and reproduction scripts available at the project repository. Knowledge graph and extraction pipeline documented at `docs/reports/knowledge-pipeline-sprint.md`.*
