# KiteTurbineDynamics.jl — Technical Report

**Multi-Rotor Tensile Rotary Power Transmission for 50 kW Airborne Wind Energy**

Rod Read · Windswept & Interesting Ltd, Stornoway, Scotland · rod@windswept.energy

**Version**: 0.2-draft (supersedes Community Report v0.1, July 2026)
**Status**: RE-BASELINE IN PROGRESS — see §0. Do not cite numbers marked ⟨RB⟩ until the post-settle-fix control map re-run completes.
**Repository**: https://github.com/rodread/KiteTurbineDynamics.jl (MIT License)
**Intended publication**: versioned `docs/` report + Zenodo DOI; figures per `docs/reporting-charts-prd.md` (white background, provenance footer, confidence badge on every figure).

---

## 0. Status of numbers in this report

On 2026-07-04 a simulator integrity audit found that the dynamic settle stage used `p.k_mppt = 614.9` while the simulation used `k_ref = 15.6` (39×), meaning **all dynamic results published before the fix started from a wrong-state settle**. After the fix, the λ=1.0 verification gate moved from 166 to 193 kW (+16%). Consequences for this report:

- Every dynamic number produced before 2026-07-04 is marked **⟨RB⟩** (re-baseline pending) and is superseded pending the control-map re-run.
- Every result in this report is confidence tier **P (provisional — single simulation model, unvalidated)** per the chart standards PRD. There are no tier-H or tier-M results yet. That is not a reason to hide the badge; it is the reason to show it.
- Two findings from the 2026-07-04 session are NEW and post-fix: the λ=0.69 blade-rescaled envelope pass and the ω-dependent transmission-loss result (§3.4).

## 1. Introduction: The TRPT Kite Turbine

### 1.1 What is tensile rotary power transmission?

A conventional horizontal-axis wind turbine places a rotor on a tower and transmits torque down a rigid driveshaft. The tower must resist the overturning moment from rotor thrust — this drives the cubic mass scaling that makes large turbines heavy.

A TRPT kite turbine [1] inverts this architecture. The rotor flies at altitude, and torque is transmitted to the ground through a *tensile* shaft: a rotating polygon of tensioned tethers supported by thin-walled carbon-fibre rings. The rings resist the inward pull of the tethers in hoop compression; the tethers carry tension along the shaft axis. No tower is needed — the entire structure is held aloft by aerodynamic forces.

The shaft serves two functions simultaneously: it transmits torque from the airborne rotor to the ground generator, and its rings provide mounting points for *expansion rotors* — additional banked rotors distributed along the shaft that contribute power and radial spreading force.

This report concerns the **power subsystem** — the TRPT shaft with expansion rotors, operating at ~30° elevation. A separate **lift subsystem** (coaxial autogyro rotors on a kite line, modelled in `CoaxialAutogyroStacking.jl`, operating at 45–55° elevation) provides the axial tension that holds the TRPT aloft. The two subsystems are modelled in separate repositories and are **not yet integrated**; the elevation mismatch is a known risk (§2.4).

### 1.2 Why multi-rotor?

The late Prof. Peter Jamieson provided the foundational scaling argument for multi-rotor TRPT. Splitting a single rotor of radius R into N equal stacked rotors with the same total swept area yields mass ratio M(1) = 0.577 for perfectly equal rotors — a 42% mass saving [3]. Applied to the Windswept RodKite01 geometry, this confirmed multi-rotor TRPT as the correct scaling direction. Note this is a geometric principle, not yet a validated TRPT result.

This insight underpins the KTD.jl architecture: rather than one large rotor, the TRPT shaft carries multiple smaller rotors whose combined swept area produces the target power at lower total mass. The DE optimiser discovers the distribution of rotor sizes, ring positions, bank angles, and tether counts simultaneously.

### 1.3 The lift–power split

The earlier 10 kW Windswept prototype (the "Daisy Kite") used a static lift kite. Dirk van Leersum's 2023 scaling analysis showed the static-kite approach becomes commercially unviable above ~10 kW — lift kite area grows faster than power output [4]. The active lifting approach (coaxial autogyro stack) is intended to eliminate this bottleneck; that claim is itself unvalidated (PCA-2 disk model, 3× solidity mismatch, factor-of-2 error possible).

## 2. The KTD.jl Framework

Two computational stages:

1. **Differential evolution (DE) optimisation** across up to 14 design variables — 60-island parallel population, BEM-coupled force models, multi-gate constraint system.
2. **Full 11-DoF multibody dynamic verification** — ODE solver with per-ring finite element analysis, inertia relief for free-floating rings, individual rotor power accounting.

### 2.1 Design variables

- **Structural**: hub ring radius, ring outer diameter, wall thickness ratio (t/D), segment target length, bottom ring radius, line count
- **Rotor**: expansion rotor count, bank angle, tip-speed-ratio scaling factors (λᵢ), rotor radius scaling factors
- **Constraints**: ground clearance, ring buckling FoS ≥ 1.5, collapse margin (δα* − |Δα| > 0), bank ≤ 25°, tip speed ≤ 120 m/s

### 2.2 Verification strategy

Every DE campaign optimum is verified by a 60-second dynamic simulation at design wind speed (11 m/s), computing per-ring forces, per-rotor power, shaft speed, and structural FoS at 1 Hz. A design that passes static gates but fails dynamic verification is flagged **dynamically dead** — a category that includes the V10 Tight winner (49.2 kg static, structural failure within 60 s of dynamic simulation).

Verification revealed the static equilibrium solver under-predicts dynamic k_mppt by ~3.3×, causing DE campaigns to optimise for loads substantially lower than dynamic operation produces. Documented in `DECISIONS.md`.

### 2.3 Campaign history

| Version | Best mass (kg) | n_lines | n_exp | Key feature |
|---|---|---|---|---|
| V6.0 | 184.8 | 8 | 1 | Octagon baseline, 6/11 params on bounds |
| V6.2 (corrected) | 74.2 | 12 | 1 | sin formula, cos^2.65, coupled knuckle mass |
| V9.0 | 44.5 | 8 | 9 | Dynamic ω solve, 59/60 feasible |
| V10 (unified) | 76.8 | 14 | 4 | 8 gates, unified rotor model |
| V10 Tight | 49.2† | 12 | 4 | k_mppt ∝ λ², ring-mapping fixes |
| V10 Reinforced | 60.8 | 12 | 4 | +30% r_bottom, FoS 7.18 at 15 m/s ⟨RB⟩ |

† Dynamically dead. All masses **exclude expansion rotor mass** (§2.4, item 6) and pre-date the m_blade λ² scaling fix of 2026-07-04.

### 2.4 Known limitations

Disclosed openly because they define where collaboration is needed:

1. **Constant-C_L expansion rotor model.** No angle-of-attack dependence, no induction, no Betz limit, no tip losses — the model cannot stall. BEM or lifting-line cross-validation is the highest-priority gap.
2. **No wake interaction between rotors.** Downstream rotors see freestream wind. Leuthold's axisymmetric wake induction model [7] directly addresses this.
3. **Static solver under-predicts dynamic k_mppt by ~3.3×.** Campaigns compensate with k_mppt_safety = 3.0; root cause (lossless torque propagation in the equilibrium solver) requires a dynamic-aware objective.
4. **30° elevation mismatch with autogyro lift** (45–55° sweet spot). Integration risk identified, not yet modelled.
5. **Blade mass is provisional** (constant-thickness skin, ∝ λ²). No structural blade design.
6. **Expansion rotor mass not computed** — builder sets it to zero; all mass totals exclude this contribution.
7. **(New, 2026-07-04)** Settle/sim k_mppt mismatch invalidated all pre-fix dynamic results (§0); five simulator integrity bugs found and fixed or flagged in one audit session. The audit itself is documented in `DECISIONS.md` and retained deliberately — tier-X history is part of the integrity story.

## 3. Key Findings

### 3.1 The static–dynamic gap ⟨RB⟩

The most significant pre-audit finding: systematic overprediction of power by steady-state equilibrium models versus full multibody dynamics. AWE literature documents 18–21% overprediction for conventional configurations [12, 7, 13]. At the V10 Tight design point, the static solver predicted 50 kW; the pre-fix dynamic ODE produced 12.1 kW — a factor of 4.1×.

**⟨RB⟩ This headline number is under re-baseline.** The 12.1 kW dynamic figure was produced with the broken settle (§0), which is known to have produced partial-convergence artifacts (the λ=1.0 gate moved 166 → 193 kW after the fix, +16%). The gap is expected to persist qualitatively — the two proposed mechanisms (inter-ring torsional losses absent from the equilibrium solver, and angle-of-attack variation under shaft twist) are real — but the magnitude (4.1× vs something smaller) must not be cited until the re-run lands. Earlier drafts stated 4.2× in the abstract and 4.1× in the body; the discrepancy is itself an argument for the consistency-stamp standard now in force.

The gap, whatever its post-fix magnitude, is not a failure of KTD.jl — it is the simulator's primary finding. No published TRPT model has quantified it.

### 3.2 Left-flank architecture

Control-map hunting across 5–15 m/s revealed two operating regimes for a given k_mppt:

- **Right flank** (high k, low ω): high generator torque, low speed. Dynamic reachability challenges, poor collapse margin.
- **Left flank** (low k, high ω): low generator torque, high speed. The bisection naturally converges here. ⟨RB⟩ The pre-fix claim "FoS ≥ 2.5 while absorbing 3.4× rated capture at 15 m/s" derives from the superseded 172.7 kW control map and awaits re-run.

Architectural decision (2026-06-30): **design for left-flank overspeed** — size blades so P_min ≤ P_rated on the left flank, size rings for thrust, enforce tip speed ≤ 120 m/s for acoustic compliance [14].

### 3.3 Mass scaling

The system-level mass scaling exponent α ≈ 0.74–0.90 emerges from three competing mechanisms, not a single law:

- **Lines** (tension-governed): mass ∝ force ∝ P. Linear.
- **Rings** (buckling-governed, Euler column): mass ∝ P_cr·r²/EI. Sub-volumetric, sensitive to ring diameter.
- **Blades** (volumetric): mass ∝ A^{3/2}. Cubic, but blades contribute <5% of airborne mass.

**Caveats stated plainly**: α is computed from **two design points** (10 kW, 50 kW), excludes expansion rotor mass, and carries zero hardware validation. The Makani precedent (designed 919 kg, built 1,731 kg — 1.88×) is the standard we hold ourselves to: simulation-only mass claims carry limited weight until a hardware demonstration exists.

### 3.4 Post-audit findings (2026-07-04, tier P, post-settle-fix)

1. **Blade-rescaled envelope pass.** A λ=0.69 blade-rescaled V10 Tight (k_mppt = 7.4, from k(λ) = k₀·λ²·[r_mean(λ)/r_mean(1)]³) meets **P ≥ 50 kW and FoS ≥ 1.5 across 5–15 m/s** — 168 kW / FoS 2.51 at 15 m/s under unregulated MPPT (conservative), where the published V10 Tight failed at FoS 1.36. Low-wind power follows ~v³ below rated. This lifts the previous binding constraint.
2. **Transmission loss scales with shaft speed, not aero power.** Across eight runs spanning two designs and 194–303 rpm, loss fits c·ω³ with a design-independent coefficient c ≈ 2.2–2.9 W/(rad/s)³ (consistent with quadratic aerodynamic drag torque on the rotating shaft). Loss fraction rises as blades shrink (13% → ~25%) because generator k falls with λ² while shaft drag does not. Mechanism attribution ongoing; numerical damping (lin_damp) excluded as the source. Low-wind deficit suggests a small additional constant-torque term; two-term fit pending.
3. **Blade-only scaling law.** Static aero power follows λ² at fixed ring radius; the correct k_mppt schedule is neither λ² nor λ⁵ alone but k₀·λ²·(r_mean ratio)³, because blade radii are offsets from the ring radius, not the shaft axis.

## 4. Comparison with Prior and Parallel Work

### 4.1 University of Strathclyde — Wind Energy & Control Centre

The most complete published TRPT modelling framework, in close collaboration with Windswept.

**Chen et al. (AWEC 2026)** [5]: coupled aero-structural steady-state model for TRPT power efficiency. 86.33% transmission efficiency across 4–15 m/s; 89% of torque loss concentrated in the top TRPT segment; optimal TSR shifts downward when transmission loss is considered; stable operation requires positive tangent stiffness (minimum axial force bound).

**Amjad et al. (AWEC 2026)** [6]: TRPT scalability framework using QBlade LLFVW. TRPT upscaling is transmission-limited, not rotor-limited; parametric sweeps yield a "wide-and-short" geometric prescription; multi-rotor identified as future work.

**Relationship to KTD.jl**: the Strathclyde models are steady-state. Chen's 86.33% efficiency is the best published TRPT steady-state analysis; KTD.jl's static–dynamic gap is the natural next question — what happens when these configurations run through full multibody dynamics? Amjad's "wide-and-short" geometry is precisely what KTD.jl's DE optimiser independently produces. Note also the convergence between Chen's transmission-loss findings and KTD.jl's ω³ loss result (§3.4.2) — an obvious joint-validation target.

### 4.2 University of Freiburg — Systems Control & Optimization Laboratory

**Leuthold et al. (AWEC 2026)** [9]: rigidly-convected lifting-line vortex model for AWE optimal control; her 2019 wake induction model [7] quantified 18–21% overprediction from neglected induction.

**Diehl, De Schutter & Harzer (AWEC 2026)** [10]: vertical AWE farm concept — 99 dual-wing systems, 50 MW on 7 km²; figure of merit is power density (MW/km²). The free-flying analogue of multi-rotor TRPT vertical stacking. De Schutter is now at TransnetBW (grid-integration perspective).

**Relationship**: both groups distribute aerodynamic load across vertically-stacked elements under different mechanical constraints. KTD's fixed-geometry axisymmetric wake is a simpler validation case for Leuthold's model than free-flying multi-kite; the static–dynamic gap is a direct data point for her research question.

### 4.3 someAWE Labs — Christof Beaupoil

The most advanced rotary AWE hardware currently flying [11]: autogyro pumping-mode with swashplate, active rotation compensation, Kaman-style servo flaps for cyclic pitch (no pitch links at the hub), in cooperation with Freiburg. Closest flying analogue to the autogyro lift subsystem; his servo-flap approach may remove mechanical linkages between stacked units.

### 4.4 Dr. Oliver Tulloch — TRPT inventor

Tulloch's thesis [2] and Energies paper [1] established the foundational TRPT model: single-section moment-to-tension ratio (MTR ≈ 0.05), spring-disc dynamic formulation, δα* collapse criterion. All of KTD.jl's physics traces to this work. KTD.jl extends the single-section MTR to per-section coupling from explicit ring geometry; δα* is implemented dynamically as `collapse_margin = δα* − |Δα|`, verified healthy at 42–47° on the left flank. Dr. Tulloch now works in offshore wind; his contribution is cited with gratitude and respect.

## 5. Conclusion

TRPT kite turbines with multi-rotor expansion represent a material-efficient path to utility-relevant airborne wind energy. KTD.jl has quantified an achievable mass range (49–61 kg airborne at 50 kW, tier P, expansion-rotor mass excluded), identified the static–dynamic gap as the critical modelling challenge ⟨RB⟩, established left-flank overspeed as the operating architecture, and — post-audit — demonstrated a blade-rescaled design meeting power and safety criteria across the full wind envelope in simulation.

The remaining gaps — mid-fidelity aerodynamics, wake interaction, hardware validation, dynamic-aware optimisation — map directly onto the expertise of the groups discussed in §4. Collaboration briefs are issued separately. The simulator is open-source, the test suite is green, and the decisions are documented. The next step is a conversation.

## References

[1] Tulloch, O., Yue, H., Kazemi Amiri, A.M. and Read, R. (2023). A tensile rotary airborne wind energy system — modelling, analysis and improved design. *Energies*, 16(6), 2610.
[2] Tulloch, O. (2021). *Tensile Rotary Power Transmission Design*. PhD Thesis, University of Strathclyde.
[3] Jamieson, P. (2020). Top-level rotor optimisations using actuator disk theory. *Wind Energy Science*, 5, 807–818.
[4] van Leersum, D. (2023). TRPT scaling analysis — internal report for Windswept & Interesting Ltd. Unpublished.
[5] Chen, Z., Yue, H., Kazemi, A. and Read, R. (2026). Power efficiency analysis of a rotary kite airborne wind energy system. *Proc. AWEC 2026*, Porto.
[6] Amjad Zulfazli, M.M., Yue, H., Carroll, J. and Chen, Z. (2026). Scalability analysis of a rotary kite AWE system with tensile rotary power transmission. *Proc. AWEC 2026*, Porto.
[7] Leuthold, R., Crawford, C., Gros, S. and Diehl, M. (2019). Engineering wake induction model for axisymmetric multi-kite AWE systems. *Wake Conference 2019*.
[8] Leuthold, R., Gros, S. and Diehl, M. (2017). Induction in optimal control of multiple-kite AWE systems. *IFAC-PapersOnLine*, 50(1), 153–158.
[9] Leuthold, R., Crawford, C., Gros, S. and Diehl, M. (2026). Trajectory tracking in AWE optimal control with a rigidly-convected, lifting-line vortex model. *Proc. AWEC 2026*, Porto.
[10] Diehl, M., Harzer, J. and De Schutter, J. (2026). Vertical airborne wind energy farms based on dual-wing systems. *Proc. AWEC 2026*, Porto.
[11] Beaupoil, C. and Weyel, F. (2026). Autogyro pumping mode rotary AWE system — design and control of a servo flap cyclic pitch actuated rotor. *Proc. AWEC 2026*, Porto.
[12] Kheiri, M., Bourgault, F. and Iosilevskii, G. (2018). Power limit and its governing factors for crosswind kite systems. *Journal of Aircraft*, 55(4), 1534–1548.
[13] Carceller Candau, J. (2022). Dynamic analysis of a rotary airborne wind energy system. MSc Thesis, Universitat Politècnica de Catalunya.
[14] Read, R. (2026). KiteTurbineDynamics.jl — DECISIONS.md (architectural decision log). https://github.com/rodread/KiteTurbineDynamics.jl
[15] Harzer, J., Polkläser, K.S., Diehl, M. and Moormann, D. (2026). Multi-wing AWE research project: goals and progress. *Proc. AWEC 2026*, Porto.
