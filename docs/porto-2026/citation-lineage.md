# Porto 2026 — Citation Lineage

> **For each core KTD technique: what to cite, what you extend, what you contradict.**
> K1 graph analysis (Phase 3) + web validation (Phase 3b).
> Ready to hand to collaborators or defend in technical discussion.

---

## 1. k_mppt λ² Scaling

**What it is:** Generator load scaled by blade sweep area — k_mppt_eff = k_mppt × λ². Prevents the DE optimizer from converging to λ → 0 (zero blade speed, zero power). Couples MPPT to the equilibrium solver at the rotor scale.

**Origin:** Loyd (1980) — established P ∝ v³·Cp for crosswind kites. Did not include tether drag.

**Extends:** Diehl (2013) — AWE power fundamentals. Standard wind turbine MPPT theory.

**Novelty:** MPPT with blade-area coupling to an equilibrium solver. No existing paper models k_mppt as a function of rotor blade scale within a TRPT system.

**Gap:** 16 findings in the K1 graph reference "induction factor" and "power coefficient" but none link generator load to blade sweep area. Web search confirms no prior art.

**Risk:** Low. Standard MPPT for conventional wind assumes fixed rotor area — this adaptation is novel for TRPT.

**To cite:** Loyd (1980), Diehl (2013)

---

## 2. TRPT Torque-Tension Coupling — Beyond Single-Section MTR

**What it is:** In single-section TRPT (Pyramid concept, Tulloch 2023), the moment-to-tension ratio MTR ≈ 0.05 provides a simplified coupling coefficient: moment = MTR × looping_radius × shaft_tension. KTD.jl replaces this with explicit multi-section TRPT geometry — per-segment torque-tension coupling is computed from DE-optimised ring radii (r_hub, r_bottom, density_profile) and segment lengths (target_Lr) via the full TRPT deformation equations (Wacker eq 4.1, Tulloch 2023 §4).

**Origin:** MTR concept — Tulloch et al. (2023) "A Tensile Rotary Airborne Wind Energy System" — Energies 16(6):2610. Pyramid single-section derivation (Tallak/Dirk). Tulloch PhD thesis (2021, University of Strathclyde).

**Extends:** Tulloch's single-section analytical MTR to a full multi-section geometric treatment where the DE indirectly varies per-segment coupling through ring geometry. Rather than fixing MTR ≈ 0.05, the optimiser varies r_hub (2.89 m), target_Lr (3.0 m), r_bottom (2.0 m), and density_profile (−0.11) — the equivalent per-section moment-to-tension relationship shifts as a consequence.

**K1 matches:** 8 TRPT papers, 4 specific findings, 8 methods in the unified graph. Tulloch's TRPT paper is the central node connecting most subsequent TRPT research.

**Novelty:** Replacing the single-section MTR analytical simplification with explicit multi-section TRPT geometry in a DE optimisation loop. The equivalent per-section coupling varies with ring count, taper, and segment length — implicit in the geometry rather than explicit as a free parameter.

**Gap:** No existing paper applies multi-section TRPT geometry within DE optimisation. Wacker (2022) optimises steady-state geometry but does not vary ring count or segment lengths in a multi-section TRPT.

**To cite:** Tulloch et al. (2023), Tulloch PhD (2021), Wacker (2022)

---

## 3. Tether Drag ¼ Coefficient

**What it is:** The classical result that tether drag contributes ~¼ of the total system drag in crosswind AWE. Validated by Tveide's TetherDragODESolver for TRPT configurations.

**Origin:** Loyd (1980) — excluded tether drag entirely from the original derivation.

**Validated by:** Tveide TetherDragODESolver — confirms the ¼ assumption for single-tether AWE.

**Extends:** Applies the ¼ coefficient to TRPT multi-tether configurations (n parallel lines). The ¼ coefficient holds, but the n× scaling (drag accumulated over multiple parallel tethers) is a new contribution.

**K1 matches:** 1 paper specifically on tether drag, 4 related findings, 2 methods. This is a thin area — most AWE papers treat tether drag as a secondary effect.

**Novelty:** n× parallel tether drag accumulation in TRPT systems.

**To cite:** Loyd (1980), Tveide TetherDragODESolver

---

## 4. Ring-Mapping +2 Offset

**What it is:** Internal architectural fix. Intermediate ring i maps to system ring i+1. Ground adds ring 1, hub adds ring n+2. Corrects rotors being placed on wrong rings in the multibody model.

**Origin:** No published prior art. Specific to KiteTurbineDynamics.jl architecture.

**Wacker (2022) check:** Wacker's MSc thesis uses a flat 1-indexed frame list (Rrot, R2, ..., Rgen). His coordinate transforms (Section 3.1) are spatial, not index-mapping. No ring-mapping precedent in Wacker.

**Novelty:** Internal implementation detail — no publication credit, but critical for model correctness.

**Status:** Document as a design decision, not a publication claim.

**To cite:** N/A (internal architecture). Document in KTD.jl DECISIONS.md.

---

## 5. 6-DOF Inertia Relief

**What it is:** Full 6-DOF D'Alembert equilibration (translational + torsional + out-of-plane moment) for free-floating ring FEA. Cancels fictitious rigid-body modes that otherwise corrupt the structural solution.

**Origin:** Standard 3-DOF translational inertia relief, well-established in NASTRAN/ANSYS (NASA, 1995).

**Moore CSR check (2026-06-23):** Mark Moore's Centrifugally Stiffened Rotor (NASA, 2014) uses spherical joints connecting rotor-wings to a stationary hub — constrained multibody dynamics, not free-floating FEA. No overlap with 6-DOF inertia relief.

**Extends:** To full 6-DOF — adding torsional and out-of-plane moment equilibration beyond standard 3-DOF.

**Novelty:** Application to free-floating ring structures in AWE. Not previously done. This eliminates fictitious rigid-body translations (which otherwise reach 10⁶–10⁸ m with soft ground springs) and recovers true elastic beam deformations that were previously lost in floating-point roundoff noise.

**Risk:** Low. Inertia relief is standard FEA technique — the novelty is in the application, not the method. Frame as "extends standard FEA practice to free-floating AWE ring structures."

**To cite:** NASA TM-1995-13233 (inertia relief fundamentals), Moore (2014) for rotating tensegrity context

---

## 6. Static-vs-Dynamic Power Gap (4.2×)

**What it is:** 50 kW static equilibrium prediction → 12 kW dynamic multibody actual. A 4.2× overprediction from the equilibrium solver that cannot capture torque transmission dynamics through the TRPT.

**Extends:**
- Kheiri et al. (2018) — induction factor effects in crosswind kite power limits (extended actuator disc theory)
- Carceller Candau (2022, MSc thesis) — 18% power overestimation from neglected dynamic inflow effects on rotorcraft AWES
- Pfister & Blondel (2020) — BEM vs. free-vortex wake methods for thrust/power coefficients at inclined rotor discs

**Novelty:** The KTD gap is 4.2× (420%) — an order of magnitude larger than literature consensus of 18–21%. This is TRPT-specific and unresolved. While 124 findings in the K1 graph reference power and 9 discuss equilibrium, none quantify the static-vs-dynamic gap for rotary AWE.

**Web validation:** No prior art found. Wacker (2022) only does steady-state optimisation — explicitly excludes dynamic effects. This is your strongest publishable claim.

**Gap:** The gap exists, is quantified, and is unresolved. Future work: close the gap with full dynamic equilibrium solver.

**To cite:** Kheiri et al. (2018), Carceller Candau (2022), Pfister & Blondel (2020), Wacker (2022)

---

## Quick Reference Card

| Technique | Cite | Extends | Contradicts | Web-Validated |
|-----------|------|---------|-------------|---------------|
| k_mppt λ² | Loyd 1980, Diehl 2013 | Standard MPPT | Fixed-area MPPT | ✓ Clean |
| TRPT coupling | Tulloch 2023, 2021, Wacker 2022 | Single-section MTR → multi-section geometry | Fixed-MTR design | ✓ Clean |
| Tether drag ¼ | Loyd 1980, Tveide | Multi-tether scaling | Full drag models | ✓ Clean |
| Ring-mapping | Internal | — | Direct index mapping | N/A (internal) |
| 6-DOF inertia relief | NASA 1995, Moore 2014 | Standard 3-DOF IR | Node-pinning | ✓ Clean (Moore ≠ IR) |
| 4.2× power gap | Kheiri 2018, Carceller Candau 2022 | 18-21% literature | Static power models | ✓ Clean (unique to TRPT) |
