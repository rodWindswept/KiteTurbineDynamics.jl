# KTD.jl Community Report — Windswept & Interesting Ltd

**Status:** Draft v1 — for Rod's review
**Date:** 2026-07-05
**Purpose:** Introduce KTD.jl findings to the AWES research community, framed as an invitation to collaborate. Targeted at four groups: Strathclyde, Freiburg, someAWE Labs (Beaupoil), and Oliver Tulloch.

> **Windswept's approach to collaboration** is usually along the lines of: target strategic research collaborators with complementary expertise rather than chasing VC funding; follow a 10-4-1 pipeline (10 contacts → 4 deep engagements → 1 meaningful agreement); quantify what each party brings and gains; and frame the technology as a concrete research opportunity, not a speculative invention.

---

## 1. Executive Summary — What KTD.jl Is

KiteTurbineDynamics.jl is an open-source (MIT) Julia framework for designing and verifying Tensile Rotary Power Transmission (TRPT) kite turbines. It combines differential evolution (DE) optimisation across 14 design variables with full 11-DoF multibody dynamic verification.

**The core finding:** TRPT kite turbines with multi-rotor expansion can achieve 50 kW rated power at airborne masses of 49–58 kg — sub-volumetric mass scaling (α ≈ 0.74–0.90) that emerges from the competition between tension-governed lines, buckling-governed rings, and volumetrically-scaling blades. However, steady-state equilibrium models overpredict power by ~4.2× compared to full dynamic simulation — an order of magnitude larger than the 18–21% overprediction documented for conventional AWE (Kheiri 2018, Leuthold 2019, Carceller Candau 2022).

**What we've built:**

| Component | Status | Key numbers |
|-----------|--------|-------------|
| DE optimiser | Production | V6→V10 campaigns, 60-island, 14-DoF, 600K evaluations |
| Multibody ODE solver | Production | 11-DoF, BEM-coupled v5, inertia relief, per-ring FEA |
| Expansion rotor model | Working | Constant-CL, banked, distributed across TRPT rings |
| Telemetry dashboard | v2 (development) | GLMakie, per-rotor gauges, control-map hunting |
| Test suite | Production | 917 tests in 23 files, Julia 1.12 |
| Coaxial autogyro lift | Separate repo | 4-rotor stacked lift, 149 tests, v1 complete |

**What we haven't built (and where you come in):**

| Gap | Why it matters | Who could help |
|-----|---------------|----------------|
| Mid-fidelity aerodynamics | Constant-CL is low-fidelity. No induction, no Betz limit, no tip losses. QBlade/BEM cross-validation needed. | Strathclyde (QBlade LLFVW expertise) |
| Multi-kite wake interaction | Leuthold's 2019 wake induction model is directly applicable to stacked expansion rotors. Currently unmodelled. | Freiburg (Leuthold, Diehl) |
| Hardware validation | All results are simulation-only. No flight data at 50 kW scale. | someAWE (Beaupoil), Strathclyde |
| Ring buckling vs Dyneema yield | Different failure regimes. Strathclyde models yield; KTD models buckling. Need unified safety framework. | Strathclyde, Tulloch |

---

## 2. Windswept Collaboration Standards

These are the principles under which Windswept engages research partners. They should inform every conversation.

### 2.1 What we look for in a collaboration

1. **Complementary expertise, not capital.** We don't need funding — we need skills, tools, and validation we don't have in-house. QBlade aerodynamics, wake modelling, optimal control, experimental data.

2. **Momentum over perfection.** Early collaborations just need to exist for validation and credibility. A joint conference paper, a cross-validation dataset, a co-supervised student project — these are real outputs that build toward larger agreements.

3. **Quantified non-cash contributions.** We explicitly value a partner's tools, expertise, student time, and lab access. Collaborations are a balanced exchange of resources, not a one-way ask.

4. **"Big slice of a small pie."** We're building the TRPT research community. Sharing credit, co-authorship, and open-source access to KTD.jl for a footprint in the AWES literature almost always beats keeping everything proprietary and never reaching critical mass.

5. **Treat rejection as information.** If a potential collaborator isn't interested, we learn why and adjust. We don't stay stuck with one hesitant partner — there are others.

### 2.2 What we offer

- **Open-source access** to the only DE-optimised, ODE-verified multi-rotor TRPT simulator in existence
- **Co-authorship** on papers cross-validating KTD.jl against other tools (QBlade, AWEbox)
- **Joint grant applications** — KTD.jl provides the simulation backbone; partners provide the specialised expertise
- **Student projects** — well-scoped, achievable MSc/PhD projects with clear deliverables (see §6)
- **Hardware perspective** — Rod Read has built and flown TRPT systems at 1–10 kW; simulation grounded in field experience

### 2.3 What we're asking for

- **No cash.** Zero. Collaborations are in-kind exchanges of expertise and tool access.
- **Time-bounded commitments.** A joint paper, a cross-validation study, a student project — not open-ended.
- **Honest technical feedback.** We want our model's limitations identified by people with complementary tools.

---

## 3. Target 1: University of Strathclyde — Wind Energy & Control Centre

### 3.1 Who they are

| Person | Role | Relevant work | Connection to Windswept |
|--------|------|---------------|------------------------|
| **Dr. Hong Yue** | Senior Lecturer, group lead | TRPT modelling, control, co-supervisor of Tulloch/Chen/Amjad | Co-author on Tulloch 2023 (Energies), Chen 2024 (ICAC), Chen AWEC2026 |
| **Ziwei Chen** | PhD researcher | Power efficiency analysis of TRPT, aero-structural coupled model, tangent stiffness stability criterion | Co-author with Rod on ICAC 2024, AWEC2026 poster |
| **Muhammad Amjad** | PhD researcher (PETRONAS-sponsored) | TRPT scalability analysis, QBlade LLFVW aerodynamics, parametric sweeps | AWEC2026 poster |
| **Prof. James Carroll** | Professor, Amjad's co-supervisor | Wind energy systems, reliability | Supervising Amjad |

> **Note:** The late **Prof. Peter Jamieson** (passed away 2026) provided the foundational multi-rotor scaling analysis that underpins KTD.jl's architecture. His derivation that splitting one rotor into N equal stacked rotors yields M = 0.577 (42% mass saving) was applied directly to the RodKite01 geometry and confirmed multi-rotor TRPT as the correct scaling direction. His work continues to guide our approach, and we cite it with gratitude.

### 3.2 What they've built

**Chen's coupled aero-structural model (AWEC 2026):**
- Steady-state TRPT efficiency analysis at 1.5 kW and 12 kW
- Key finding: 86.33% transmission efficiency across 4–15 m/s
- Key finding: top TRPT segment carries 89% of total torque loss
- Key finding: optimal TSR shifts down when transmission loss is considered
- Key finding: stable operation requires positive tangent stiffness (determines minimum axial force)

**Amjad's scalability framework (AWEC 2026):**
- QBlade LLFVW rotor aerodynamics at 34° elevation, 5–15 m/s
- Steady-state torque transmission model (12-section TRPT)
- Parametric sweeps: tether count (3–12), diameter (1–3 mm), ring radius (0.1–2×), section length (0.1–1×)
- Key finding: TRPT upscaling is transmission-limited, not rotor-limited
- Key finding: "wide-and-short" geometric prescription (radial expansion, minimal longitudinal extension)
- Key finding: multi-rotor shown as conceptual only — not modelled quantitatively
- Key finding: -17% to +21% torque loss range (parasitic drag dominates at low wind)

**Jamieson's multi-rotor scaling:**
- Theoretical derivation: splitting one rotor into N equal stacked rotors gives M = 0.577 (42% mass saving)
- Applied to RodKite01 geometry — confirms multi-rotor TRPT is the right scaling direction

### 3.3 What KTD.jl brings to Strathclyde

**1. The static-dynamic gap quantification.**
Chen's model claims 86.33% steady-state efficiency. KTD.jl found that steady-state equilibrium overpredicts power by 4.2× compared to full multibody dynamics at 50 kW. This is not a contradiction of Chen's work — it's the next question. *"Your steady-state model is the best TRPT efficiency analysis in the literature. What happens when we run the same configuration through full multibody dynamics?"* A joint paper cross-validating Strathclyde's steady-state model against KTD's ODE solver at matched power scales would be the first multi-fidelity TRPT validation ever published.

**2. Multi-rotor optimisation.**
Amjad's poster shows a conceptual render of multi-rotor TRPT and calls it future work. KTD.jl has DE-optimised 4-rotor configurations at 49–58 kg airborne mass. *"You identified multi-rotor as the scaling path. We've built the optimiser. Let's feed your QBlade aerodynamics into our DE framework."*

**3. Jamieson scaling validation.**
Jamieson's M = 0.577 prediction (42% saving for equal rotors) can be tested directly against KTD.jl's DE campaign data. The V10 Tight winner uses 4 unequal rotors — the DE found k ≠ 1 because unequal rotors (small ones for thrust distribution) beat the equal-rotor theoretical optimum. *"Your scaling law predicts 42% saving. The DE found a 36% saving with unequal rotors. That's a publishable validation."*

**4. Beyond Dyneema yield.**
Strathclyde's TRPT model constrains tension to Dyneema's 3.5 GPa yield. KTD.jl models Euler buckling of thin-walled CF rings — a different failure mode that dominates at the ground-end rings where accumulated tension is highest. *"Your yield criterion and our buckling criterion define the two boundaries of the TRPT failure envelope. Let's map the full envelope."*

### 3.4 Proposed next step

**Joint paper:** "Multi-fidelity validation of TRPT kite turbine performance: steady-state vs. multibody dynamics at 12–50 kW." Strathclyde contributes QBlade aerodynamics + steady-state TRPT model. Windswept contributes KTD.jl ODE solver + DE optimisation. Joint analysis of the static-dynamic gap. Target: Wind Energy Science or AWEC 2027.

**Student exchange:** Co-supervise an MSc project applying QBlade to KTD.jl's expansion rotor geometries. Windswept provides the design vectors; Strathclyde provides the aerodynamic analysis.

---

## 4. Target 2: University of Freiburg — Systems Control & Optimization Laboratory

### 4.1 Who they are

| Person | Role | Relevant work | Connection to KTD |
|--------|------|---------------|-------------------|
| **Prof. Moritz Diehl** | Lab director, gave Plenary Talk at AWEC2026 | AWE power fundamentals, multi-wing AWE, **vertical AWE farms** (99 dual-wing systems stacked at different altitudes, 50 MW, 7 km² — AWEC2026 with De Schutter & Harzer) | Cited in KTD.jl paper; vertical stacking is the central concept in both his work and KTD's multi-rotor TRPT |
| **Rachel Leuthold** | PhD researcher (active), co-editor of AWEC2026 proceedings | **Rigidly-convected lifting-line vortex model** for AWE optimal control (AWEC2026, with Crawford, Gros, Diehl); wake induction model for axisymmetric multi-kite systems (2019) | Her core question — "how hard is it to fly the optimal trajectory in a real, momentum-conserving flow?" — is the academic framing of KTD's 4.2× static-dynamic gap |
| **Dr. Jochem De Schutter** | Now at TransnetBW GmbH (German grid operator) | Vertical wind farms, AWEbox framework, stacked multi-kite optimal control (PhD 2024 under Diehl) | Industry perspective on AWES grid integration; his vertical farm concept directly parallels multi-rotor TRPT |
| **Jakob Harzer** | PhD researcher | Multi-Wing AWE experimental prototype (Maverix VTOL), co-author on vertical farm and multi-wing papers | Building the first dual-wing flight hardware |

### 4.2 What they've built

**Leuthold's wake modelling programme (2017 → 2026):**
- **2026 (AWEC):** Rigidly-convected lifting-line vortex model that can be embedded in optimal control problems — answers "how hard is it to actually fly the OCP-optimal trajectory when wake effects are included?"
- **2019:** Engineering wake induction model for axisymmetric multi-kite AWE systems — quantified 18–21% overprediction from neglected induction
- **2017:** Induction in optimal control of multiple-kite AWE systems (IFAC, with Gros & Diehl)
- Her research programme directly addresses the gap between simplified models and real flow physics — the same gap KTD quantifies for TRPT

**Diehl's vertical AWE farm concept (AWEC2026, with De Schutter & Harzer):**
- Dual-wing systems stacked at different altitudes in assigned flight cylinders
- **50 MW from 99 small systems on 7 km²** — power density PD as the key design metric
- Trade-off: narrow flight cylinders → high PD but lower Loyd-efficiency (visualised as Pareto front)
- This is the free-flying analogue of KTD's multi-rotor TRPT: vertical stacking to increase power per footprint

**De Schutter's AWEbox framework (PhD 2024):**
- Open-source optimal control for single- and multi-aircraft AWE
- Used in Leuthold's AWEC2026 paper to solve tracking OCPs with wake models
- Now at TransnetBW — brings grid operator perspective on AWES feasibility

**Harzer's Maverix experimental programme (AWEC2026):**
- VTOL flight system for dual-wing experiments
- Phased: untethered → single tethered → dual-wing → power generation
- Collaboration between UFR (trajectories) and RWTH Aachen (flight tests)

### 4.3 What KTD.jl brings to Freiburg

**1. Vertical stacking: same concept, different engineering.**
Diehl's vertical farm stacks 99 free-flying dual-wing systems. KTD stacks 4 expansion rotors on rotating rings. CoaxialAutogyroStacking stacks 4 autogyro rotors on a single kite line. All three are solving the same physics problem — distributing aerodynamic load across vertically-stacked elements — with different mechanical constraints. *"You're optimising power density PD for free-flying vertical farms. We're optimising mass for rotating-ring vertical stacks. The scaling laws might be the same — let's find out."*

**2. Leuthold's wake model is the tool KTD needs.**
KTD's expansion rotors form a geometrically fixed axisymmetric array — the wake pattern is deterministic (unlike free-flying kites). Leuthold's rigidly-convected vortex model was designed for exactly this: embedding a mid-fidelity wake in an otherwise fast optimisation loop. *"Your rigidly-convected model was built for optimal control of multi-kite systems. Our expansion rotor array has a fixed geometry — the convection pattern is even simpler. What portion of our 4.2× static-dynamic gap does your wake model explain?"*

**3. The static-dynamic gap maps onto Leuthold's research question.**
Her AWEC2026 paper asks: "how difficult is it to fly the optimal trajectory found without a wake model, in a real momentum-conserving flow?" KTD asks the same question for TRPT: "how different is the dynamic equilibrium from the steady-state prediction?" The 4.2× gap is the TRPT-specific answer. *"Your paper frames the wake-model-omission problem for free-flying kites. We've quantified it for rotating-ring TRPT. The comparison would tell us how much of our gap is wake-induced vs. transmission-induced."*

**4. De Schutter's grid operator perspective.**
De Schutter at TransnetBW has moved from optimal control to grid integration. His vertical farm paper frames AWES in terms of power density per km² — the metric that matters to grid operators. *"Your 50 MW vertical farm paper is the clearest AWES grid-integration framing in the literature. KTD's multi-rotor TRPT achieves vertical stacking mechanically rather than via flight control. What grid-integration requirements should we design for?"*

### 4.4 Proposed next step

**Joint paper or workshop:** "Wake induction in multi-rotor TRPT: applying Leuthold's rigidly-convected vortex model to KTD.jl expansion rotor arrays." Freiburg contributes the wake model + awebox framework; Windswept contributes the fixed-geometry TRPT rotor array as a test case.

**Possible student project:** Apply Leuthold's multiple-wake vortex lattice method to KTD.jl's banked expansion rotor configurations. The fixed-geometry TRPT wake is a simpler test case than free-flying multi-kite — ideal for an MSc thesis. Co-supervised by Diehl's group and Read.

---

## 5. Target 3: Christof Beaupoil — someAWE Labs

### 5.1 Who he is

| Detail | Info |
|--------|------|
| **Role** | Engineer, someAWE Labs S.L., Alicante, Spain |
| **Relevant work** | Autogyro pumping mode rotary AWE system — design and control of a servo flap cyclic pitch actuated rotor (AWEC2026) |
| **Hardware** | Functional demonstrator with swash plate, active rotation compensator, Kaman-style servo flaps |
| **Connection to KTD** | Closest thing to a flying rotary AWE hardware platform — different architecture (pumping mode autogyro vs. TRPT ring rotor) but same family |

### 5.2 What he's built

- Complete rotary AWE system design: autogyro with cyclic and collective pitch via swash plate
- Servo flap (Kaman flap) actuation on rotor blades — eliminates pitch links at the hub
- Linear model of blade-flap dynamics identified from measurement data
- Feed-forward controller computing flap actuation for cyclic pitch
- Cooperation with University of Freiburg on control system
- **This is the most advanced rotary AWE hardware in the world** — actual flight hardware with instrumented control

### 5.3 What KTD.jl brings to Christof

**1. Scaling roadmap for his architecture.**
Christof's demonstrator is at small scale. KTD.jl has quantified the scaling path from 1 kW to 50 kW. CoaxialAutogyroStacking has swept the autogyro design space (rotor radius, stack count, tilt profile, wind speed) producing Pareto fronts of anchor tension vs. mass efficiency. *"Your servo flap system works at demonstrator scale. Here's what the loads, masses, and power levels look like at 50 kW, sized for your autogyro rotor diameter. Our parameter sweep says R=3m, N=4 produces 5 kN at 8 m/s — how does that compare to what you measure?"*

**2. Swashplate and cyclic pitch — same mechanism, different application.**
Christof's system uses cyclic pitch via swashplate to create the pumping cycle (alternating lift and glide phases). CoaxialAutogyroStacking uses collective pitch via swashplate for steady lift control (three throttle states: launch, cruise, lift-to-stall). Both need a functioning swashplate on an autorotating rotor. *"You've solved the swashplate-on-autogyro problem with active rotation compensation. Our stacked design needs the same mechanism but for steady collective pitch across 4 rotors. What did you learn about bearing life, wear patterns, and control authority?"*

**3. Servo flaps vs. pushrods — the Kaman approach.**
Christof's servo flap actuation eliminates pitch links at the hub — the flap's aerodynamic moment twists the blade. This is inherently simpler than traditional pushrod swashplates, especially for stacked rotors where mechanical linkages between units would be complex. *"Your Kaman flap approach removes the need for pitch links. For a stacked configuration with 4 independent rotors, that could be the enabling technology — no mechanical linkage between units. Have you characterised the flap's bandwidth and authority limits?"*

**4. Flight data as model validation.**
KTD.jl's ODE solver produces time-series predictions. CoaxialAutogyroStacking produces steady-state force curves. Christof has instrumented flight data from an actual flying autogyro. *"We have two models predicting autogyro lift. You have measurements. The cross-validation benefits all of us — we calibrate our models, you get performance predictions at scales you haven't flown yet."*

### 5.4 Proposed next step

**Visit Alicante (planned October 2026).** Rod to travel to someAWE Labs in Alicante, share the KTD.jl simulation results in person, and discuss cross-validation opportunities face-to-face. Christof is a hardware builder — the most productive format is a workshop, not an email thread.

**Ongoing collaboration:** Cross-validation of KTD.jl's autogyro lift model against someAWE's flight data. Joint AWEC 2027 presentation comparing simulated vs. measured rotary AWE performance.

---

## 6. Target 4: Oliver Tulloch — TRPT Inventor

### 6.1 Who he is

| Detail | Info |
|--------|------|
| **Role** | TRPT originator, former Strathclyde PhD (2021) |
| **PhD thesis** | "Tensile Rotary Power Transmission Design" — 309 pages, foundational TRPT model |
| **Key publications** | Tulloch et al. 2023 (Energies): TRPT modelling, analysis and improved design |
| **Connection to Windswept** | Co-author with Rod on the foundational TRPT paper; Rod supervised/supported the PhD; Ollie's spring-disc TRPT model is the ancestor of KTD.jl |
| **Current status** | Working in offshore wind — optimising legacy wind farm operations on the UK mainland. No longer active in AWE research, but remains the foundational figure in TRPT. |

### 6.2 What he built

- Single-section MTR (moment-to-tension ratio) concept: M ≈ 0.05
- Spring-disc TRPT model (Matlab) — ancestor of KTD.jl's multibody dynamics
- Steady-state TRPT torque transmission analysis
- Tether drag model
- Experimental validation at small scale (Daisy Kite, ~1 kW)
- δα* collapse criterion (critical twist angle for TRPT instability)

### 6.3 What KTD.jl brings to Ollie

**1. His model, extended.**
Ollie's single-section MTR ≈ 0.05 assumes uniform torque-tension coupling. KTD.jl computes per-section coupling from explicit ring geometry — the moment-to-tension relationship varies along a tapered ring profile. *"Your MTR = 0.05 is the canonical value. Our DE optimiser finds effective MTR varying from 0.03 to 0.08 across sections. Your model generalises — here's how."*

**2. Multi-rotor extension.**
Ollie's thesis analysed single-rotor TRPT. KTD.jl extends to 4 rotors with Jamieson scaling. *"You built the single-rotor model. We've extended it to multi-rotor. The physics still traces back to your spring-disc formulation."*

**3. The δα* collapse criterion in dynamic context.**
Ollie's δα* defines the twist angle at which TRPT stiffness goes to zero. KTD.jl's collapse_margin (δα* − |Δα|) implements this in dynamic simulation — healthy at 42–47° on the left flank. *"Your collapse criterion works. We've verified it dynamically across the 5–15 m/s envelope."*

**4. Attribution and legacy.**
The KTD.jl paper cites Tulloch 2023 as the foundational TRPT reference. Every paper we publish reinforces the citation count on his work. *"We're building on your foundation. We want to make sure the community knows that."*

### 6.4 Proposed next step

**Send him the community report** with a personal note. He may not be active in AWE research anymore, but he deserves to see what's been built on his work. If he's interested: co-authorship on the KTD paper, with his section being the "From Tulloch's spring-disc to KTD's multibody: model evolution" narrative.

---

## 7. Funding Opportunities for Collaborative TRPT Research

Windswept maintains a regularly-updated grant research pipeline (weekly cron, latest: 5 July 2026). Several current opportunities are well-suited to collaborative TRPT research with academic partners. All figures in GBP equivalents where applicable.

### 7.1 Top consortium-ready opportunities

| # | Grant | Agency | Max Award | Deadline | Relevance to TRPT collaboration |
|---|-------|--------|-----------|----------|-------------------------------|
| 1 | **EIC Accelerator Open** | European Innovation Council | €2.5M grant + up to €10M equity | 2 Sep / 4 Nov 2026 | HIGH — commercialisation of TRPT technology. Requires TRL 5+ demonstration. |
| 2 | **Horizon Europe: Wind Energy SET Plan (D3-03)** | European Commission | €80M total call / ~€400K FSTP Stage 1 | 15 Sep 2026 | HIGH — specifically for wind energy technology development. FSTP mechanism designed for SMEs in academic consortia. |
| 3 | **CETPartnership Joint Call 2026** | CETPartnership (EU) | Variable (national pots, total €100M+) | Pre-proposal: 8 Oct 2026 | MEDIUM-HIGH — 11 call modules including advanced renewable energy. Requires 3+ country consortium. UK eligible via UKRI. |
| 4 | **UK–Switzerland CR&D Round 3** | Innovate UK + Innosuisse | £3M total | 3 Sep 2026 | MEDIUM-HIGH — bilateral UK-Swiss innovation. Less relevant unless a Swiss partner is identified. |
| 5 | **EU Innovation Fund — SME Call** | DG CLIMA (EU) | TBC (est. £2–7.5M) | H2 2026 (2 cut-off dates) | MEDIUM — newly confirmed dedicated SME instrument. Simplified application. |

### 7.2 Most relevant for each collaboration target

| Target | Best-fit grant | Why |
|--------|---------------|-----|
| **Strathclyde** | Horizon Europe D3-03 | UK university + UK SME consortium. Strathclyde leads academic side; Windswept as industry partner. FSTP mechanism ideal. |
| **Freiburg** | CETPartnership Joint Call 2026 | Germany + UK + third country consortium. Diehl's group has extensive EU funding experience. |
| **someAWE (Beaupoil)** | EIC Accelerator or EU Innovation Fund SME | Spain + UK SME consortium. Hardware-focused, TRL demonstration. |
| **All together** | Horizon Europe D3-03 | Multi-partner wind energy call. Windswept as coordinator or partner; universities as academic leads. |

### 7.3 What funding would enable

- **Dedicated researcher time** — a postdoc or PhD student focused on QBlade-to-KTD cross-validation, rather than fitting it around existing workloads
- **Hardware validation** — instrumented TRPT test rig at a university lab, generating the flight data all models currently lack
- **Travel and workshop costs** — regular in-person working sessions (Alicante, Glasgow, Freiburg)
- **Open-source development** — dedicated Julia developer time for the BEM-coupled aerodynamics module, closing the highest-priority model limitation

> **Note:** All grant figures are from the 5 July 2026 weekly scan. Deadlines are subject to change. The full grant research pipeline with 17 tracked opportunities is maintained on the Windswept drive at `02_Funding/Grant Research/`. A Horizon Europe D3-03 application for the September 2026 deadline would require consortium formation within ~4 weeks.

---

## 8. What We're Asking For — Summary

| Correspondent | Ask | What we offer in return | Timeframe |
|---------------|-----|------------------------|-----------|
| **Strathclyde** | QBlade cross-validation of KTD expansion rotor aero; co-authored joint paper on static-dynamic gap | Open-source KTD.jl access, DE design vectors, co-authorship | 3–6 months |
| **Freiburg (Diehl/Leuthold)** | Apply Leuthold's wake induction model to KTD expansion rotor array; multi-wing comparison study | TRPT geometry data, multi-rotor DE results, co-authorship | 3–6 months |
| **Christof Beaupoil** | Flight data for cross-validation; hardware reality check on our mass estimates. **Planned: visit Alicante October 2026.** | Scaling roadmap to 50 kW, autogyro lift model validation | Ongoing |
| **Oliver Tulloch** | Permission/acknowledgement; option for co-authorship | Citation reinforcement, model lineage narrative | As available |

All asks are **zero-cash, in-kind exchanges.** Each is scoped to a concrete deliverable (paper, dataset, or student project). **Where appropriate, joint grant applications (see §7) can fund dedicated research time — we are ready to lead or join consortium bids.**

---

## 9. Technical Appendix — KTD.jl Quick Reference

### 9.1 Repository

```
https://github.com/rodread/KiteTurbineDynamics.jl
License: MIT
Language: Julia 1.12
Tests: 917 in 23 files (~3 min full suite)
```

### 9.2 Key commands

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
julia --project=. test/runtests.jl           # full test suite
julia --project=. scripts/interactive_dashboard.jl   # GLMakie dashboard
julia --project=. scripts/run_v5_campaign.jl         # DE optimisation campaign
```

### 9.3 Campaign results at a glance

| Version | Power target | Best mass | Key feature |
|---------|-------------|-----------|-------------|
| V6.0 | 50 kW | 184.8 kg | Octagon baseline, 6/11 params on bounds |
| V6.2 (corrected) | 50 kW | 74.2 kg | sin formula, cos²·⁶⁵, coupled knuckle mass |
| V9.0 | 50 kW | 44.5 kg | Dynamic ω solve, 59/60 feasible, 3 bounds screaming |
| V10 Tight | 50 kW | 49.2 kg | 4 rotors, k_mppt λ², ring-mapping fixes ⚠ dynamically dead |
| V10 reinforced | 50 kW | 60.8 kg | +30% r_bottom, structurally viable at 15 m/s FoS 7.18 |

### 9.4 Known model limitations (honest disclosure)

1. **Constant-CL expansion rotor:** No angle-of-attack dependence, no induction, no Betz limit, no tip losses. BEM/LLFVW cross-validation is the top priority.
2. **No wake interaction between rotors:** Leuthold's model directly addresses this gap.
3. **Static solver under-predicts dynamic k_mppt by ~3.3×:** Campaigns use k_mppt_safety=3.0 to compensate, but the root cause is the equilibrium solver's lossless torque assumption.
4. **30° elevation mismatch with autogyro lift:** The lift stack wants 45–55°; the TRPT power stack wants 30°. Integration risk identified, not modelled.
5. **Blade mass is provisional:** Constant-thickness skin assumption (λ²). No structural blade design.
6. **Expansion rotor mass set to 0.0 in builder:** Not yet computed. Mass numbers exclude this contribution.

### 9.5 Supporting repositories

| Repo | Purpose | Status |
|------|---------|--------|
| `CoaxialAutogyroStacking.jl` | Stacked autogyro lift model — pairs with KTD.jl | v1 complete, 149 tests |
| `TRPTSim` | Quick-prototyping TRPT simulator (quasi-static) | Published |
| `TetherDragODESolver` | Tether drag ODE validation (Tveide) | Published |

---

## 10. Document Status

- [x] Rod review — corrections applied 2026-07-05
  - [x] Peter Jamieson noted RIP, contribution cited posthumously
  - [x] AWEbox trajectory optimisation removed — TRPT rotors are centrifugally stiffened
  - [x] Ollie Tulloch status updated — offshore wind optimisation, mainland UK
  - [x] Christof Beaupoil — Alicante visit October 2026 added
  - [x] Funding section added with top 5 consortium-ready opportunities
  - [x] Windswept standards softened to "usually along the lines of"
- [ ] Produce PDF with embedded figures (see below)
- [ ] Attach supporting materials:
  - [ ] V10 Tight PCA landscape (Figure 1 from KTD paper outline)
  - [ ] Static-dynamic gap bar chart (Figure 2)
  - [ ] Campaign mass evolution chart (Figure 4)
  - [ ] Strathclyde poster analysis (`strathclyde-posters/ANALYSIS.md`)
- [ ] Send to Strathclyde (Hong Yue — warm introduction, existing co-authorship)
- [ ] Send to Freiburg (Moritz Diehl — Porto conversation starter as entry point)
- [ ] Send to Christof Beaupoil (direct email — data-forward, not academic)
- [ ] Send to Oliver Tulloch (personal note — attribution and legacy framing)
