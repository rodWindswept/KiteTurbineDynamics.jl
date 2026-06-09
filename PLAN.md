# PLAN.md — KiteTurbineDynamics.jl v6: Expansion Rotor Modelling

**Provisional paper title:** *"Aerodynamic Expansion Rotors: Overcoming the Torsional
Scaling Limit in Tensile Rotary Power Transmission for Airborne Wind Energy"*

**Start state:** v5 (11.47 kg 10 kW, 79.5 kg 50 kW, DE-optimised rigid TRPT)
**Target state:** v6 — parametric expansion rotor elements, swept campaigns, paper-ready figures
**Reference:** `docs/audit-literature-crosscheck.md` (13 issues), `docs/paper-expansion-rotors-plan.md`
**Wiki:** `concepts/aerodynamic-expansion-rotors.md`, `concepts/torsional-collapse-mechanism.md`

---

# Mission & Strategic Context

## Why This Matters

The TRPT (Tensile Rotary Power Transmission) is the mechanical heart of the Daisy
Kite Turbine — it's what makes continuous rotary ground-gen possible with an entirely
tensile airborne structure. But our own modelling shows it hits a nonlinear scaling
wall: the mass/power ratio worsens from 1.15 kg/kW at 10 kW to 1.59 kg/kW at 50 kW.
At utility scale, this kills the economic case.

The expansion rotor concept breaks this constraint by replacing passive carbon-fibre
compression rings (heavy, dead mass) with actively-lifted blades that spread the
tether line set outward through aerodynamic force during rotation (light, aerodynamic).
If the modelling confirms what the physics suggests, we can restore near-linear
mass/power scaling and open a path to 100+ kW rotary airborne wind energy.

## The Stakes

- **Commercial:** 50 kW is the minimum viable product for the small-wind market.
  If TRPT mass kills the power-to-weight ratio at that scale, the Daisy architecture
  doesn't have a commercial pathway.
- **Academic:** The TRPT scaling cliff has been noted in the literature (Tulloch 2019,
  Wacker 2022) but no one has proposed a mechanism to overcome it. This paper would
  be the first to offer a solution, not just a diagnosis.
- **Patent:** GB2588178 already covers the expandable annulus and tensile spreading
  architecture. Publishing validates the IP with peer-reviewed modelling data.
- **Funding:** A well-modelled solution to the scaling problem strengthens grant
  applications and investor conversations. "Our own simulator identified the problem,
  and our own concept solves it" is a compelling narrative.

## What Success Looks Like

1. A peer-reviewed paper in Wind Energy Science (or equivalent) demonstrating that
   aerodynamic expansion rotors restore near-linear mass/power scaling for TRPT
   systems from 10 kW to at least 50 kW.
2. A v6 release of KTD.jl with expansion rotor modelling, all tests green, all
   audit issues resolved, and reproducible campaign results.
3. Publication-quality figures and a GLMakie dashboard that communicate the concept
   clearly to engineers, investors, and academic reviewers.
4. A parametric design pipeline (Julia + GLMakie or Blender Geometry Nodes) capable
   of generating the architectural diagrams, force-vector schematics, and system
   visualisations needed for the paper and subsequent presentations.

---

# Scientific Rigour Standards

These apply to all phases. No phase is complete until its rigour checks pass.

## Model Transparency

- All physical assumptions documented in source code comments and in the paper
- Every equation in the paper traceable to a specific function in the Julia source
- "Magic numbers" (0.85 efficiency factor, 1.2 DLF, etc.) justified with citations
  or calibration data
- Parameter sensitivity: key results reported with uncertainty ranges from parameter
  sweep ±20%

## Reproducibility

- All campaign results reproducible from committed code + seeded RNG
- Sweep and campaign scripts are standalone — `julia --project=. scripts/run_v6_campaign.jl`
  produces identical CSV output on any machine
- Environment captured: `Manifest.toml` committed, Julia version noted
- If AeroDyn (Windows-only) is a dependency, provide pre-computed lookup tables
  so Linux/CI can run without it

## Validation

- **Internal:** Every new module has unit tests with known analytical solutions
- **Cross-model:** KTD.jl results checked against Tulloch's experimental data
  (Cp 0.15–0.18 range) and Wacker's validated benchmark cases (Daisy 168W, MAR1 364W)
- **Limit cases:** Expansion rotor model must degenerate correctly:
  - N_expansion = 0 → identical results to v5 rigid TRPT (backward compatibility)
  - bridle_angle = 0 → no radial force (pure axial lift, like a standard kite)
  - v_wind = 0 → expansion still works via ω² term (shaft-driven rotation)
- **Physical bounds:** CT ≤ 1.0 (momentum theory), Cp ≤ 16/27 (Betz), FoS ≥ 1.0

## Peer Review Readiness

- All figures include error bars or confidence intervals where data permits
- Comparison to at least two independent benchmarks (Tulloch, Wacker)
- Limitations section in paper is honest and specific — not boilerplate
- Code and data available under open license (MIT for code, CC-BY for data)

---

# Software Requirements

## Functional Requirements

### FR1 — Expansion rotor modelling
The simulator must model N expansion rotors at arbitrary ring positions in the TRPT stack.
Each expansion rotor applies outward radial force to the tether attachment points as a
function of shaft angular velocity ω, wind speed v, bridle angle, and blade geometry.

### FR2 — Effective radius feedback
The effective TRPT radius at each expansion station must feed into: torsional FoS
computation, beam buckling analysis, rope attachment-point geometry in the next
ODE timestep, and telemetry/logging.

### FR3 — Parasitic power accounting
The simulator must track power consumed by expansion rotors (τ_drag × ω) and report
it as a fraction of rated power. This must be available both in-simulation and in
post-processed campaign outputs.

### FR4 — Backward compatibility
Setting N_expansion = 0 must produce identical results to v5. Existing test suite
(11 suites, ~48 s) must continue to pass without modification.

### FR5 — Campaign automation
A single script must run the full parameter sweep and DE optimisation campaign,
producing CSV output consumable by the figure-generation scripts. Campaign must
support checkpointing and resume.

### FR6 — Figure generation
Six publication-quality figures (PDF, 300 dpi) must be generatable from campaign
output via standalone scripts. No manual chart editing.

## Non-Functional Requirements

### NFR1 — Performance
Campaign must complete within 168 hours (7 days) on the available hardware
(currently a single machine). Individual ODE simulations must remain under
~5 minutes for a 30-second physical timespan to keep the campaign tractable.

### NFR2 — Numerical stability
ODE solver must not diverge or produce NaN values for any feasible parameter
combination in the sweep range. Degenerate cases (N_expansion > n_rings, negative
bridle angles) must be caught at configuration time with clear error messages.

### NFR3 — Code quality
All new code must follow existing conventions: SI units, angles in degrees at
API boundary, immutable structs, pure functions where possible. JuliaFormatter
(Blue style) applied before commit. Documentation strings on all exported functions.

### NFR4 — Test coverage
Every new `src/` file must have a corresponding `test/test_<module>.jl` file.
Quality-gate invariants from v5 (forces scale with v², zero wind → tension from
weight only, more rotors → more lift, tension monotonic increasing downward)
must continue to hold with expansion rotors active.

---

# Documentation & Presentation

## Code Documentation

- **Source:** Julia docstrings on all exported functions, with doctest examples
- **Architecture:** `CONTEXT.md` updated with expansion rotor glossary entries,
  new file map, and known limitations
- **Decisions:** `DECISIONS.md` updated with expansion rotor design decisions
  (why bridle_angle as primary control, why driven not autorotating, etc.)
- **Developer guide:** `AGENTS.md` and `CLAUDE.md` updated with new commands,
  test suite additions, and Phase 1-5 task references

## Paper Documentation

- **LaTeX source:** `paper/expansion-rotors.tex` using WES copernicus.cls
- **Figures:** `figures/paper/fig_*.pdf` — six vector figures, one system schematic
- **Data supplement:** `paper/supplement/` — CSV tables of all campaign winners,
  parameter sensitivity analysis, expanded method details
- **Cover letter:** `paper/cover-letter.md` — addressed to WES editor, explaining
  novelty and significance

## Presentation Materials

### Conference slides
- 12-slide deck for AWEC 2025 (if accepted)
- Key visuals: scaling cliff chart, expansion rotor force diagram, campaign winner
  comparison table, GLMakie dashboard screenshot
- Source: `presentations/awec2025/` — Markdown + Marp or reveal.js

### Investor/partner deck
- 8-slide deck focusing on commercial implications
- Mass/power ratio improvement as the headline
- Path to 100 kW+ as the growth narrative
- Source: `presentations/investor/`

### Public communication
- Blog post for windswept-and-interesting.co.uk summarising paper findings
- Twitter/LinkedIn thread with key charts
- Possibly a "The Kid Should See This" style explainer if the visuals are strong enough

## Parametric Design & Graphic Communication

Rod previously used Rhino3D + Grasshopper for architectural kite turbine diagrams.
For this project, we should use an open-source pipeline so that:

1. Diagrams are reproducible from code (no proprietary file formats)
2. Parameter changes automatically update visuals
3. The pipeline can be shared with collaborators and reviewers

### Recommended tools

**Primary: Julia + GLMakie (already in the project)**
- Generate 3D system schematics directly from `KiteTurbineSystem` structs
- Force vector overlays, ring geometry, blade positions all parametric
- Export to PNG/PDF/SVG for paper figures
- Export to GLTF for interactive web viewing
- Script: `scripts/figures/fig_system_schematic.jl`

**Secondary: Blender + Geometry Nodes (for publication-quality renders)**
- Blender is free, open-source, and widely used in scientific visualisation
- Geometry Nodes provide a node-based parametric workflow similar to Grasshopper
- Can import TRPT geometry via Python API or OBJ export from GLMakie
- Generate photorealistic renders for the paper's graphical abstract
- Script: `scripts/export_for_blender.jl` → exports ring positions, radii, and blade
  orientations as a JSON or OBJ file consumable by a Blender Geometry Nodes setup

**Tertiary: p5.js (for interactive web supplementary material)**
- Interactive browser-based 3D viewer of the TRPT + expansion rotors
- Reader can adjust bridle_angle, N_expansion, and wind speed and see the effect
  on effective radius and power output in real time
- Hosted on windswept-and-interesting.co.uk as paper supplementary material
- Based on the existing GLMakie dashboard, exported via `WGLMakie` for web

### Diagram checklist for the paper

| Diagram | Tool | Description |
|---------|------|-------------|
| System architecture comparison | GLMakie | Daisy / Pyramid / Expansion side-by-side with force vectors |
| Expansion rotor close-up | Blender | Single rotor with bridle geometry, lift/drag vectors |
| TRPT stack with N=3 expansion | GLMakie | Full stack showing r_eff at each station |
| φ improvement schematic | GLMakie or TikZ | Before/after segment geometry |
| Force vector decomposition | TikZ (LaTeX) | Lift → radial + axial components |
| Graphical abstract | Blender | Hero image for paper/presentations |

---

# Post-Publication Strategy

## Immediate (0-3 months after publication)

- Post preprint on ResearchGate and arXiv
- Share on AWE Systems Forum (if we can get access / Rod posts manually)
- Send to key contacts: Tallak Tveide, Oliver Tulloch, Jannis Wacker, Mac Gaunaa,
  Roland Schmehl (AWE Book editor), NREL AWE team
- LinkedIn post from Rod's account with key findings
- windswept-and-interesting.co.uk blog post

## Medium-term (3-12 months)

- Present at AWEC 2025 (if paper submitted in time) or AWEC 2026
- Submit follow-up paper with experimental validation (if prototype data available)
- Integrate expansion rotor modelling into the Daisy Kite open-source control
  software (GitHub: rodread/DaisyKiteTurbineControl)
- Use results in grant applications (Innovate UK, Horizon Europe, Scottish Enterprise)
- Update Windswept website technology page with v6 scaling projections

## Long-term (1-3 years)

- Build and test a physical expansion rotor prototype at the Isle of Lewis test site
- Extend KTD.jl to model multi-rotor power extraction + expansion (dual-purpose rotors)
- Explore network topologies: multiple expansion stations, concentric rings,
  asymmetric spreading for yaw control
- Licence or collaborate with other TRPT developers (MAR1, Pyramid) who may benefit
  from the expansion rotor approach

## Data Management

- Campaign data archived on Zenodo with DOI (cited in paper)
- KTD.jl v6 tagged release on GitHub with DOI via Zenodo-GitHub integration
- Raw AeroDyn BEM tables included in repository as CSV (no Windows dependency)
- All figures archived as both PDF (vector) and PNG (raster) at 300 dpi

---

# Development Phases

---

## Phase 0 — Audit Resolution (1-2 weeks)

Fix high-confidence issues before adding new physics. Each task includes the
specific file, the change, and the test that must pass before proceeding.

### 0.1 — Unify BEM models

**Files:** `src/aerodynamics.jl`, `src/bem.jl`, `src/trpt_optimization.jl`

**Problem:** `bem.jl` uses `cp_bem(n_lines) = (16/27)*(1-exp(-n_lines/2))*0.85`
(Betz-scaled Prandtl) while `aerodynamics.jl` uses AeroDyn lookup tables
(Cp peak 0.232 at λ=4.1, NACA4412). The sizer undersizes rotors relative
to what the dynamics simulator needs.

**Change:**
1. Run AeroDyn BEM sweeps for n_lines ∈ {3,4,5,6,7,8} at TSR ∈ {3.0..6.0}
2. Fit a `Cp(n_lines, TSR)` surface — store as 2D lookup in `src/bem.jl`
3. Replace `cp_bem(n_lines)` with `cp_bem(n_lines, tsr=4.1)` calling the surface
4. Add `ct_bem(n_lines, tsr)` to match
5. Update `rotor_radius_for_power()` to use the surface
6. All callers in `trpt_optimization.jl` switch to `src/bem.jl` functions
7. Add docstring: "BEM surface from AeroDyn v15, NACA4412, 3-blade baseline,
   Prandtl tip/root corrections. Valid n_lines ≤ 8."

**Test:** `test/test_bem_unified.jl`
```julia
# Cp at n_lines=5, TSR=4.1 should match AeroDyn lookup within 2%
@test abs(cp_bem(5, 4.1) - cp_at_tsr(4.1)) / cp_at_tsr(4.1) < 0.02
# Cp scales correctly: more blades → lower Cp (solidity penalty)
@test cp_bem(8, 4.1) < cp_bem(5, 4.1)
# CT monotonic with n_lines
@test ct_bem(5, 4.1) > 0.45
# Rotor radius self-consistent: sizing with cp_bem reproduces input R
R_test = rotor_radius_for_power(10000.0, 11.0, 5)
R_back = sqrt(10000.0 / (cp_bem(5,4.1) * 0.5*1.225*π*11.0^3))
@test abs(R_test - R_back) / R_back < 0.05
```

**Verification:** Cp values within ±5% of Tulloch's validated 0.15–0.18 range
for Daisy-like geometry (n_lines=5-6, 3-blade). Flag if not.

---

### 0.2 — Validate cos²/cos³ elevation factors

**File:** `src/ring_forces.jl:121-132`

**Problem:** `thrust_mag *= cos(elev)^2` and `P_aero *= cos(elev)^3` may double-count
elevation if the AeroDyn BEM tables (run at 20° elevation) already include tilt effects.

**Change:**
1. Run AeroDyn at three elevation angles: 0° (axial), 20° (design), 40° (extreme)
2. Compare CT and Cp at each angle at TSR=4.1
3. If AeroDyn already captures elevation: remove cos²/cos³, use a single
   `cos(elev_angle)` projection for force direction only
4. If AeroDyn does NOT capture elevation: document that the factors are correct,
   add comment referencing the validation run, and verify factor exponents
   against the three-angle sweep

**Test:** `test/test_elevation_factors.jl`
```julia
# At 0° elevation (rotor axis aligned with wind): thrust ≈ AeroDyn CT output
u0, sys0, p0 = build_test_system(elev=0.0)
compute_ring_forces!(forces, torques, u0, omega, sys0, p0, uniform_wind(11.0), 0.0)
F_axial_0 = norm(forces[hub_gid])
F_bem_0    = 0.5*1.225*11.0^2 * π*R^2 * ct_at_tsr(4.1)
@test abs(F_axial_0 - F_bem_0) / F_bem_0 < 0.10

# At 20° elevation: thrust projection correct
u20, sys20, p20 = build_test_system(elev=deg2rad(20))
compute_ring_forces!(forces, torques, u20, omega, sys20, p20, uniform_wind(11.0), 0.0)
F_along_shaft_20 = dot(forces[hub_gid], shaft_direction)
F_expected_20 = F_bem_0 * cos(deg2rad(20))
@test abs(F_along_shaft_20 - F_expected_20) / F_expected_20 < 0.10
```

---

### 0.3 — Validate CT monotonic increase at high λ

**File:** `src/aerodynamics.jl:102-175`

**Problem:** CT rises monotonically 0→0.782 as TSR 0→8. Standard BEM with
Glauert high-thrust correction shows CT peaking then declining.

**Change:**
1. Regenerate AeroDyn BEM table with Glauert correction enabled (Burton §3.6.3,
   CT1 = 1.816) and Buhl correction for CT > CT1
2. Compare new CT(λ) curve against the current table
3. If CT now peaks: replace lookup table, clamp extrapolation to CT peak value
4. If CT still monotonic: document that this rotor never enters turbulent wake
   state within λ≤8, add comment explaining the physical reason
5. Flag TSR values > 8 as potentially unreliable regardless

**Test:** `test/test_ct_bounded.jl`
```julia
for λ in 0.0:0.1:10.0
    @test ct_at_tsr(λ) <= 1.0
end
ct_vals = [ct_at_tsr(λ) for λ in 0.0:0.1:8.0]
max_idx = argmax(ct_vals)
@test max_idx > 5
@test max_idx < length(ct_vals)
```

---

### 0.4 — Import PCA-2 from CoaxialAutogyroStacking.jl

**File:** `src/lift_kite.jl:363-368`

**Change:**
1. Add `CoaxialAutogyroStacking` to Project.toml as a dependency
2. Replace inline table with `using CoaxialAutogyroStacking: pca2_interp`
3. Remove local `pca2_interp` function definition
4. Add comment noting geometry-specific limitation

**Test:** Existing rotary lifter tests must produce identical output.

---

## Phase 1 — Expansion Rotor Element (2-3 weeks)

### 1.1 — New source file: `src/expansion_rotor.jl`

```julia
struct ExpansionRotorParams
    n_blades        :: Int
    blade_radius    :: Float64
    hub_radius      :: Float64
    blade_chord     :: Float64
    CL_blade        :: Float64
    CD0_blade       :: Float64
    k_induced       :: Float64
    bridle_angle_deg:: Float64
    mass            :: Float64
    ring_idx        :: Int
    shaft_coupling  :: Float64
end

function expansion_rotor_forces(er, rho, v_wind, omega_shaft, elevation_deg, r_nominal, T_tether)
    r_mean = (er.blade_radius + er.hub_radius) / 2.0
    v_app  = sqrt(v_wind^2 + (omega_shaft * r_mean)^2)
    span   = er.blade_radius - er.hub_radius
    q      = 0.5 * rho * v_app^2
    L_blade = q * er.blade_chord * span * er.CL_blade
    D_blade = q * er.blade_chord * span * (er.CD0_blade + er.k_induced * er.CL_blade^2)
    bridle_rad = deg2rad(er.bridle_angle_deg)
    F_radial = er.n_blades * L_blade * sin(bridle_rad)
    F_axial  = er.n_blades * L_blade * cos(bridle_rad)
    tau_drag = er.n_blades * D_blade * r_mean
    r_eff    = effective_radius(r_nominal, F_radial, T_tether, 1.0)  # n_lines via system
    omega_rotor = omega_shaft  # simplified: rigid coupling; extend with shaft_coupling later
    return (F_radial, F_axial, tau_drag, r_eff, omega_rotor)
end

function effective_radius(r_nominal, F_radial, T_tether, n_lines)
    if F_radial <= 0.0 || T_tether <= 0.0
        return r_nominal
    end
    geometry_factor = 2.0 * tan(π / n_lines)
    L_seg_estimate = r_nominal * 2.0  # approximate; use actual L_seg in ODE context
    Δr = F_radial * L_seg_estimate / (T_tether * geometry_factor)
    return r_nominal + Δr
end
```

### 1.2 — ODE Integration

In `src/ring_forces.jl`, add expansion rotor force block. In `src/types.jl`,
add `expansion_rotors` and `effective_radii` fields. In `src/rope_forces.jl`,
use effective radius for attachment point geometry when expansion rotor present.

### 1.3 — Test suite

Six tests in `test/test_expansion_rotor.jl`:
1. Zero-wind spreading via ω²
2. Zero bridle angle → no radial force
3. Force scales with v_app²
4. Steeper bridle → more radial force fraction
5. Effective radius computation
6. No force → no spread

**Quality gate:** All tests pass. Expansion rotor forces match analytical hand-calculation
for v=0, ω=30 rad/s, bridle=10°.

---

## Phase 2 — Stacked Expansion Campaign (2-3 weeks)

### 2.1 — Configuration generator: `src/expansion_stack.jl`

`ExpansionStackConfig` struct with `:alternating`, `:clustered`, `:custom` placement modes.
`build_expansion_stack()` generator function.

### 2.2 — φ improvement tracking: `src/expansion_analysis.jl`

`phi_improvement(sys, p)` — computes φ_nominal vs φ_effective per segment.
`expansion_telemetry_summary(sys, p)` — campaign output record.

### 2.3 — Parameter sweep: `scripts/run_expansion_sweep.jl`

Sweep across: N_expansion ∈ {0,1,2,3,4}, bridle_angle ∈ {5°,10°,15°,20°,25°},
blade_radius ∈ {0.5,1.0,1.5,2.0} m, blade_count ∈ {3,5,8}, power ∈ {10,20,50} kW.
Output: `results/expansion_sweep.csv`

### 2.4 — DE Optimisation Campaign: `scripts/run_v6_campaign.jl`

13 design variables. Objective: minimise total airborne mass. Constraints:
FoS_beam ≥ 1.8, FoS_torsion ≥ 1.5, f_parasitic ≤ 0.20. 60 islands, 168h budget.

### 2.5 — Paper outputs

1. TRPT mass vs power (rigid vs expansion)
2. φ improvement per expansion station
3. Parasitic power trade (contour)
4. System mass breakdown (stacked bar)
5. Mass/power ratio scaling comparison
6. Architecture comparison diagram

---

## Phase 3 — Chart & Figure Production (1 week)

Six standalone scripts in `scripts/figures/`. Each loads campaign CSV, filters
feasible designs, produces PDF+PNG at 300 dpi. GLMakie dashboard updated with
expansion rotor rendering. TikZ force-vector diagram for the paper.

Blender pipeline: `scripts/export_for_blender.jl` exports ring geometry as OBJ.
Blender Geometry Nodes setup reads OBJ, applies materials, renders graphical abstract.

---

## Phase 4 — Paper Drafting (2 weeks)

LaTeX document using WES copernicus.cls. Six sections, ~6500 words.
Co-author outreach to Tveide, Tulloch, Wacker, Gaunaa.

---

## Phase 5 — Review & Submission (1 week)

Pre-submission checklist, supplementary materials, Zenodo archival.
Target: Wind Energy Science (primary), AWEC 2025 (conference fallback).

---

# Dependency Graph

```
Phase 0 ──→ Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5
                                  (figures)    (paper)    (submission)
                                       │
                                  Blender pipeline
                                  (graphical abstract)
```

# Timeline

| Phase | Effort | Dependency |
|-------|--------|------------|
| 0 — Audit fixes | 1-2 weeks | None |
| 1 — Expansion rotor element | 2-3 weeks | Phase 0 |
| 2 — Stacked campaign | 2-3 weeks | Phase 1 |
| 3 — Charts & figures | 1 week | Phase 2 |
| 4 — Paper drafting | 2 weeks | Phase 3 |
| 5 — Review & submission | 1 week | Phase 4 |
| **Total** | **9-12 weeks** | |

# Risks

| Risk | Mitigation |
|------|-----------|
| Expansion rotor unstable under gusts | Aerodynamic damping; transient ODE test before campaign |
| Parasitic power > 20% at all N | Accept higher fraction if mass savings justify |
| 50 kW still has unacceptable mass | Pyramid+expansion hybrid; document as v7 work |
| Blender learning curve slows figure production | Start with GLMakie; Blender as stretch goal |
| Co-author delays | Target AWEC 2025 if journal review extends past deadline |

# Open Decisions

1. Separate vs dual-purpose rotors? (default: separate for v6)
2. Alternating vs clustered placement? (default: alternating)
3. Coupling stiffness? (default: semi-rigid, 500 N·m/rad)
4. Minimum blade count? (default: ≥4, per Carceller 2020)
5. Blender vs pure GLMakie for graphical abstract? (start GLMakie, explore Blender)
