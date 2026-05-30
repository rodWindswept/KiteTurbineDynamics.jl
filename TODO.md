# TODO: Pitch Depower Controls & Campaigns

Actionable engineering checklist to resolve the physical limitations identified in the Pitch Depower V1 campaign and prepare the mechatronics model for the V2 campaign.

## ── Phase 1: Physical Pre-conditions (v2 Pre-requisites) ───────────────────

- [x] **1. Ground Station Freewheel (No Generator Reversal)**
  - [x] Verified that all MPPT load paths in `src/ring_forces.jl` use `max(omega_gnd, 0.0)^2` or `max(omega_hub, 0.0)^2`, preventing negative motoring torque from generator control. Active damping can go negative when hub leads ground ring, which is the physically intended damping direction.

- [x] **2. Decouple Mechanical Brake from Field IMU**
  - [x] Extracted mechanical brake logic in `src/ring_forces.jl` from the `p.kp_elev` conditional block.
  - [x] Gated brake engagement solely on rotor speed (`omega_hub < 1.0` rad/s), allowing it to fire regardless of IMU status.
  - [x] Verified via updated bearing alignment unit tests under a spinning rotor model.

- [x] **3. Generator Torque Hard-Cap (3× Rated Torque)**
  - [x] Clarified source comments in `src/ring_forces.jl` explaining the robust ±2500 N.m power scaling clamp protecting the Dyneema ropes.

- [x] **4. Activate `lifter_elevation` as a Live Physical Parameter**
  - [x] Enabled passing `p::SystemParams` to `lift_force_steady()` in `src/lift_kite.jl` to dynamically pre-load lifter elevation angle.
  - [x] Coupled to sky-anchor catenary, preloads in `src/initialization.jl`, and bearing alignment calculations.
  - [x] Stabilized topmost lifting coordinates by anchoring the virtual lift line to sticky design coordinates in space.

---

## ── Phase 2: Campaign V2 Setup & Execution ─────────────────────────────────

- [x] **1. Expand Parameter Sweep Grid in `scripts/pitch_depower_campaign.jl`**
  - [x] Expanded the grid to a highly optimized 512-run factorial sweep spanning wind speeds (`[11.0, 20.0]` m/s), payout durations, active winching, damping modes (`[0.0, 2.0]`), payout bases, stall governor, and active lifter elevations.
  - [x] Standardized scenario duration at a comprehensive `30.0` s transient envelope to ensure complete brake settling.
  - [x] Implemented a high-efficiency thread pool with descending payout duration LPT sorting.

- [x] **2. Implement Phase-Aware Disqualification Metrics**
  - [x] Implemented physical checks in `scripts/pitch_depower_campaign.jl` mapping structural buckling, Tulloch overtwist, and cyan tension sag to explicit `is_disqualified` flags.
  - [x] Updated `scripts/pitch_depower_analysis.py` to filter out disqualified runs from performance metrics and map failures in a dedicated V2 visual panel.

---

## ── Phase 3: Post-V3 Infrastructure & Advanced Mechatronics ──────────────────

- [ ] **1. LaTeX and Jupyter Notebook Setup & Training Session**
  - [ ] Install LaTeX distribution (`texlive-full` or equivalent) to compile high-grade scientific reports and equations.
  - [ ] Configure Jupyter Lab environment with Julia and Python kernels for interactive data exploration.
  - [ ] Hold a walk-through/training session to get Rod fully up to speed on Jupyter and LaTeX reporting templates.
- [ ] **2. Parametric Dashboard GUI & Geometry Enhancements**
  - [ ] Redesign dashboard interface in GLMakie to be more user-friendly, responsive, and intuitive.
  - [ ] Implement Grasshopper-like parametric geometry features to model and visualize multiple stacked rotor layers, banking blades, and complex multi-layer ring networks.
  - [ ] Add live GUI controls/sliders for axial tether stiffness (EA), viscoelastic damping (c), and PTO generator inertia (i_pto).


