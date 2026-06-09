# Paper Plan: Aerodynamic Expansion Rotors for TRPT Scaling

**Provisional title:** "Aerodynamic Expansion Rotors: Overcoming the Torsional Scaling Limit in Tensile Rotary Power Transmission for Airborne Wind Energy"

**Authors:** Roderick Read (Windswept & Interesting Ltd), [co-authors TBD]
**Patent priority:** GB2588178 (Read, 2019) — expandable annulus and tensile spreading architecture
**Target venues:** Wind Energy Science (primary), AWEC 2025 (conference), Energies (alternative)
**Status:** Concept stage — requires modelling validation

---

## 1. Problem Statement (1-2 pages)

### 1.1 The TRPT scaling cliff
- KTD.jl Differential Evolution results: 10 kW → 11.5 kg, 50 kW → 79.5 kg
- Mass/power ratio worsens from 1.15 to 1.59 kg/kW
- Root cause: Tulloch/Wacker torsional collapse criterion τ_cap = T·r²/√(L²+2r²)
- φ = L/R worsens with altitude → nonlinear penalty

### 1.2 Prior approaches and their limits
- **Daisy rigid rings:** Work at 10 kW scale, mass-prohibitive above ~20 kW
- **Pyramid soft shaft (Tveide):** Eliminates rings but sacrifices altitude
- **Wacker structural optimisation:** 29-variable gradient descent, confirms scaling problem but doesn't solve it

### 1.3 The gap
No existing architecture simultaneously achieves altitude (for wind resource) AND favourable φ (for torque capacity). A new mechanism is needed.

---

## 2. The Expansion Rotor Concept (2-3 pages)

### 2.1 Principle
Replace passive compression ring elements with actively-lifted blades that spread tethers outward through aerodynamic force during TRPT rotation.

### 2.2 Architecture
- Blades coupled to rotating TRPT line set (driven by upper power rotors)
- Outer tips bridled lower toward ground station
- Lift vector includes outward radial component that spreads tether attachment points
- Hollow-hub design (from CoaxialAutogyroStacking.jl) allows rotor to ride on rotating line set

### 2.3 How it changes φ
- r_effective increases (tethers spread wider at expansion station)
- L_effective decreases (expansion rotor breaks long soft section into two shorter ones)
- A stack of N expansion rotors turns one poor-φ segment into N+1 good-φ segments
- φ improvement is multiplicative: double r + halve L → 4× improvement

### 2.4 Comparison to existing architectures
Table: Daisy vs Pyramid vs Expansion Rotors (mass, altitude, φ, scaling behaviour)

---

## 3. Analytical Model (3-4 pages)

### 3.1 Torsional capacity with expansion rotors
Extended Tulloch/Wacker criterion for N expansion stations:
- τ_cap(i) = T_i × r_eff(i)² / √(L_eff(i)² + 2·r_eff(i)²)
- r_eff(i) = r_nominal + Δr_spread(blade_lift, bridle_geometry)
- L_eff(i) = total_shaft_length / (N+1)

### 3.2 Parasitic power model
- Power consumed by expansion rotor: P_parasitic = τ_drag × ω
- τ_drag = N_blades × ½ρ·v_app² × c × CL_design × (drag polar) × r_mean
- Expressed as fraction of upper rotor power: f_parasitic = P_parasitic / P_rated

### 3.3 Net power density
- P_net = P_rated × (1 - f_parasitic × N)
- m_total = m_power_rotor + N × m_expansion_rotor + m_tether + m_PTO
- Pd = P_net / m_total
- Optimise over N, blade geometry, and bridle angle

### 3.4 Scaling prediction
Hypothesis: with expansion rotors, mass/power ratio stays constant or improves with scale (unlike the 1.15→1.59 kg/kW deterioration without them).

---

## 4. Numerical Study (3-4 pages)

### 4.1 Extension to KTD.jl
- Add expansion rotor elements to the multi-body ODE
- Expansion rotor: ring node with aerodynamic blade forces, coupled to TRPT rotation
- Bridle geometry: outer tips lower, lift vector includes radial component
- Parameter sweep: N ∈ {1,2,3,4}, blade pitch, bridle angle

### 4.2 Baseline comparison
- 50 kW system WITHOUT expansion rotors: 79.5 kg, φ = [segment values], FoS = 1.5
- 50 kW system WITH 2 expansion rotors: predicted mass, predicted FoS improvement
- Sweep: at what N does mass/power ratio recover to 10 kW levels?

### 4.3 Optimal expansion rotor count
- Diminishing returns curve: mass vs N
- Cross-over point where parasitic power loss outweighs φ improvement

---

## 5. Discussion (2 pages)

### 5.1 What this enables
- Restores scaling linearity to TRPT systems
- Makes 50-100 kW airborne rotary AWE feasible with acceptable mass
- Opens path to multi-hundred-kW systems through stacked expansion

### 5.2 Limitations and risks
- Blades as flying elements: gust stability, control complexity
- Bridle angles: trade between radial force and unwanted axial thrust
- Tether routing through rotating hubs: mechanical complexity
- Validation gap: no experimental data for this architecture

### 5.3 Comparison to conventional wind
- Where does this put TRPT on the W/kg curve vs. conventional turbines?
- Can it approach or exceed the ~60 W/kg blade-only benchmark at utility scale?

---

## 6. Conclusions (0.5 pages)
- Expansion rotors offer a mechanism to break the TRPT scaling cliff
- Replace passive mass (carbon rings) with active aerodynamics (flown blades)
- Modelling needed to validate the parasitic power trade
- If confirmed, opens path to utility-scale rotary AWE

---

## Work Plan

| Phase | Task | Effort |
|-------|------|--------|
| 1 | Analytical model: extend Tulloch/Wacker for expansion rotors | 1-2 weeks |
| 2 | Implement expansion rotor elements in KTD.jl | 2-3 weeks |
| 3 | Parameter sweep: N, blade geometry, bridle angle | 1 week |
| 4 | Write paper draft | 2 weeks |
| 5 | Review + revisions | 1 week |
| 6 | Submit to WES or AWEC 2025 | — |

## Prerequisites
- KTD.jl v5 campaign results (available)
- CoaxialAutogyroStacking.jl rotor model (available)
- Tulloch/Wacker torsional collapse formulation (available)
- Blade aerodynamic data for expansion rotor design (NACA4412 from AeroDyn BEM)

## Key Figures Needed
1. TRPT mass vs power: with and without expansion rotors (the headline)
2. φ improvement per expansion rotor station
3. Parasitic power fraction vs N
4. Architecture comparison diagram (Daisy / Pyramid / Expansion Rotors)
5. Bridle geometry and force vector diagram
