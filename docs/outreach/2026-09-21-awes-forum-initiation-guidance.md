# AWES Forum & Technical Reporting — Initiation Guidance & Prompts

When you start your fresh session(s) to prepare the AWES forum release, technical reports, diagrams, or repository guides, copy-paste the exact prompts below.

---

## 1. Prompt for the AWES Forum & Technical Report Session

```markdown
# MISSION: AWES Community Technical Report, Guides & Forum Release

You are tasked with communicating the findings, physical models, and codebase of KiteTurbineDynamics.jl (KTD.jl) to the Airborne Wind Energy Systems (AWES) community (researchers, engineers, and practitioners on the AWES forum and windswept.energy).

The goal is to make the repository work accessible, transparent, and reproducible through:
1. An open, honest AWES Forum Technical Post with compelling data and diagrams.
2. A standalone, citable Technical Report / Guide documenting the 5 kW TRPT proof, model physics, failure modes, and lessons learned.
3. Accessible "Getting Started" guides for running the simulator and the interactive 3D visualizer.

### Baseline Status & Repo State
- Origin/master is at commit `18e9ec4` (synchronized across laptop and desktop).
- Settle validity: 9/9 PASS (`test/test_settle_validity.jl`).
- Fast unit suite: 2149 / 2149 PASS (`test/runtests.jl`).
- Acceptance suite: All ODE acceptance tests PASS (Gate v13, Settle Drag Alignment, Rope Break).
- Active Workstream: `ACTIVE.md` Item 4 ("Explore the 5 kW design space") is OPENED; 3-island DE campaign is active under `physlift`.

### Essential Domain & Physics Context (DO NOT RE-DERIVE)
1. What is TRPT? Tensile Rotary Power Transmission. A high-speed, lightweight tensegrity driveshaft composed of rings and Dyneema tethers that transmits rotor torque to a ground generator via torsional displacement (Δα).
2. The 4-Link Lift Chain (never conflate these lines):
   - LIFT KITE: holds position in air mass, lift-only.
   - LIFT LINE: viscoelastic tether, c = 200 N·s/m, crosswind symmetry Y=0.
   - SKY ANCHOR: 3-way floating knot; connected to ground via elastic BACK LINE (altitude limiter).
   - CYAN LINE: carries TRPT axial tension from sky anchor to lift bearing.
   - LIFT BEARING: swivel riding shaft axis; holds the GOLD BRIDLES cone (apex angle ~31°).
   - MAIN ROTOR: topmost ring of the TRPT.
3. The Landed Lifter Boundary Physics (HEAD `18e9ec4`):
   - Crosswind Aerodynamic Symmetry (Y_kite = 0): Eliminates the legacy lateral teleportation bug where the kite twitched 1:1 with the 300g sky anchor knot. Restores natural lateral pendulum restoring stiffness (k_perp = T_lift / L_line).
   - Along-Line Viscoelastic Tether Damping (c_lift = 200.0 N·s/m): Plucking/vibrating the tether dissipates energy into Dyneema friction and apparent wind rather than acting as an undamped trampoline.
   - Low-Frequency Catenary Drift (tau_relax = 20.0 s): Relieves downwind catenary stretch back to nominal tether length over slow timescales, preventing artificial Dyneema tension escalation at steady state.
   - Settle Invariance: At static equilibrium / settle (v ≈ 0), T_dyn ≡ T_lift, preserving preloads and the 2×2 sky anchor force balance bit-for-bit.
4. The Wobble Gate & The Long-Horizon Blind Spot:
   - A short 20–30 s power gate is a blind spot: ill-conditioned machines (like the 3-line v13 winner) look healthy at 20 s but self-excite into violent ~0.01 Hz shaft limit cycles beyond t ≈ 60 s.
   - The exit gate mandates a ≥120 s post-relax window checking FoS trough ≥ 2.5 and no sustained TRPT line slack (>0.8 s).
   - The 5 kW seed machine is rock-solid: second-half hub p2p variation is just 8 mm, FoS trough 12.64, top-bay flutter collapsed by 95% (1.85 N p2p), and bridle cyclic slack is a benign once-per-revolution geometric dip (0.22 s).

### Editorial Rules & Guidelines
- Radical candor on failures: Openly present what failed, why our initial assumptions were wrong, how instrumentation caught it, and how the physical formulation resolved it.
- Single source of truth: Every single number quoted in text must match a committed CSV or script output in the repository.
- Stop-slop prose: Clear, plain English, active voice, short sentences, engineering-first. Avoid empty marketing adjectives.
```

---

## 2. Prompt for Diagram & Data Generation Session

```markdown
# MISSION: Generate Diagrams and Verified Data for the AWES Forum Release

Prepare the three high-impact figures and verified data tables for the AWES forum release:

1. Figure 1: TRPT Architecture & 4-Link Lift Chain Schematic
   - Clearly delineate the 4 lift chain links (Lift Line, Back Line, Cyan Line, Gold Bridle Cone).
   - Contrast the old unphysical boundary (teleporting kite, undamped tension) with the landed physical boundary (crosswind symmetry Y=0, along-line damping c=200 N·s/m, catenary relaxation tau=20 s).
   - Script reference: `scripts/make_diagrams.py` or Matplotlib/TikZ.

2. Figure 2: The 120 s Stabilization Trace (Before vs. After)
   - Compare top-bay tension flutter over 120 s: ~37 N undamped baseline vs. 1.85 N under the landed physical boundary (95% reduction).
   - Show hub lateral bow position locking smoothly into an 8 mm p2p band over the second half of the window.
   - Script reference: Run and plot data from `scratch/verify_canonical_winner_120s.jl`.

3. Figure 3: Evaluator Blind Spot vs. 120 s Wobble Gate
   - Illustrate the discriminator: at t = 30 s both machines appear green and productive (~5.4 kW), but past t = 60–90 s the 3-line winner self-excites into a 3.7 m limit cycle while the seed holds rock-steady.
   - Demonstrates the critical need for long-horizon dynamic verification in airborne tensegrity systems.

4. Formats:
   - Output high-res PNG (300 dpi, white background) and SVG/PDF formats into `figures/report/` or `docs/outreach/report-figures/`.
   - Adhere to `ktd-chart-design` rules: max 3 visual channels, explicit units, clean typography.
```

---

## 3. Verified Headline Performance Data (Reference Table)

Data measured on the canonical 5 kW / 18.8 m seed machine under HEAD `18e9ec4` (120 s full wobble protocol, 240 samples):

| Metric | Measured Value | Requirement / Target | Status |
|---|---|---|---|
| **Electrical Power ($P_{\text{gen}}$)** | **5.396 kW** (p2p 0.014 kW) | $\ge 5.0\text{ kW}$ rated | **PASS** (Rock steady) |
| **Rotor Speed ($\omega$)** | **13.453 rad/s** (~128 RPM, p2p 0.012) | Rated TSR match | **PASS** (Flatline) |
| **Hub Dynamic Bow** | Holds $1.10\text{--}1.16\text{ m}$ (second-half p2p **8 mm**) | Bounded excursion | **PASS** (No lateral drift) |
| **Structural Factor of Safety (FoS)** | **12.64** trough at cycle peak | $\ge 2.5$ safety gate | **PASS** (>5× headroom) |
| **Top-Bay Tension Flutter** | **1.85 N** peak-to-peak | Tame high-frequency chatter | **PASS** (Down 95% from ~37 N) |
| **Cyan Line Tension** | **291.5 N** steady (p2p 5.6 N) | Continuous tension | **PASS** (Zero slack episodes) |
| **Back Line Tension** | **245.6 N** steady | Soft-stop altitude limit | **PASS** (Zero slack episodes) |
| **Line Integrity** | 0 line breaks, SK99 strain $< 0.1\%$ | Strain $< 3.5\%$ | **PASS** (Far below limit) |
| **Bridle Cone Slack** | Cyclic 0.220 s dip (1/rev, ~48% duty) | Expected geometric kinematic dip | **RULED EXPECTED** |

---

## 4. Getting Started & Reproducibility (For External Community)

Include these exact commands in the community guide so anyone can reproduce our results:

1. **Clone and run the fast verification suite (~3 min):**
   ```bash
   git clone https://github.com/rodWindswept/KiteTurbineDynamics.jl.git
   cd KiteTurbineDynamics.jl
   scripts/ktd-julia test/runtests.jl
   ```

2. **Run the 120-second dynamic ODE verification probe:**
   ```bash
   scripts/ktd-julia scratch/verify_canonical_winner_120s.jl
   ```

3. **Launch the interactive 3D Cockpit Dashboard:**
   ```bash
   scripts/ktd-julia scripts/interactive_dashboard_v2.jl
   ```
