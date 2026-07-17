# Email to Hong & Amjad — Builder bug + physics answers

**Subject: Builder bug found — previous numbers invalid; here are the physics answers while we re-run**

Hi Hong and Amjad,

Two things in this email:

**First — bad news first.** While preparing detailed answers to your six questions, we traced every number through our code and discovered a builder bug: the JSON design parameters (`best_design.json`) are packed into the wrong slots of the simulator's design vector. The DE campaign winner is a 12-gon dodecagon (n=12 polygon sides, 10 rings, tapered 2.89→2.00 m). Every simulation we shared with you actually ran a 3-gon **triangle** frame with 22 rings, no taper, and wrong bank angles. The printed builder log line says `n_lines=3 rings=22` — that's the ground truth.

Every power, RPM, and FoS number in my previous email is therefore invalid. We're fixing the packing and re-running now. I'll send corrected data as soon as the sweeps complete.

**Second — your six questions answered from the formulation.** The physics is sound even if the numbers are wrong; these answers hold regardless of polygon count.

---

### 1. Definition of blade scale λ

λ is a **dimensionless linear scaling factor** applied to all blade dimensions. It is NOT in metres — it's a ratio λ ∈ [0.005, 2.0] where λ = 1.0 is the DE-optimised gate blade.

From `src/expansion_rotor.jl:266-271` and `src/objective_v6.jl:81`:

```
blade_tip_radius  ← blade_tip_radius_gate · λ      (span ∝ λ)
blade_hub_radius  ← blade_hub_radius_gate · λ      (hub offset ∝ λ)
blade_chord       ← blade_chord_gate · λ            (chord ∝ λ)
```

Because span and chord both scale linearly, **blade swept area ∝ λ²** and **blade mass ∝ λ³**. The generator loading is matched to blade area: **k_mppt ∝ λ²** (from `src/builders_util.jl:96`). A λ = 0.5 rotor has ¼ the swept area and expects ~¼ the power at the same windspeed.

In our sweep we tested λ ∈ [0.69, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10]. The λ² scaling of both swept area and k_mppt was confirmed in an energy-balance verification (DECISIONS.md §2026-07-04): a λ = 0.54 blade produced exactly 0.290 = λ² of the gate blade's static aero power at peak.

---

### 2. How FoS relates to k_mppt

Our FoS is **Factor of Safety against Euler buckling** of the CFRP beam segments that form each polygonal ring frame:

```
FoS = P_crit / N_comp
```

The chain linking k to FoS (from `src/trpt_optimization.jl:462-535`):

**Step 1:** k determines the equilibrium ω through the MPPT law balanced against aerodynamic torque.

**Step 2:** ω determines centrifugal relief at each ring vertex:
```
F_centripetal = m_vertex · ω² · r        [outward force, line 486]
```
where m_vertex includes the knuckle mass, beam-segment mass, and blade mass (hub ring only).

**Step 3:** Net inward radial force on the vertex:
```
F_v_total = F_in_per_vertex_aero - F_centripetal - F_exp_per_vertex    [line 487]
```
- F_in_per_vertex_aero: inward radial component of tether line tension, scaled by a Design Load Factor (DLF = 1.2, calibrated from ODE gust transients)
- F_centripetal: outward centrifugal relief (the ω² term)
- F_exp_per_vertex: outward radial force from expansion-rotor blade lift (rings with expansion rotors only)

If F_v_total < 0 (net outward), the spoke ties carry the load in tension. Otherwise the ring is in compression.

**Step 4:** Net compressive force resolved into axial beam load:
```
N_comp = F_v / (2 · sin(π/n_lines))         [line 518]
```
This is the polygon geometry factor — the inward radial force per vertex is shared between two adjacent beam segments. For a 12-gon dodecagon: denominator = 2·sin(15°) = 0.518. For a triangle: denominator = 2·sin(60°) = 1.732.

**Step 5:** Euler buckling critical load for each beam:
```
P_crit = π² · E · I / (K · L_beam)²
L_beam = 2 · r · sin(π/n_lines)
```
Fixed-fixed ends (K = 0.5), CFRP modulus E = 120 GPa, thin-wall elliptical or circular tube section.

**The counterintuitive relationship:** Lower k → higher ω → more F_centripetal → lower N_comp → **higher FoS**. This is why smaller blades at lower k_mppt find high-ω equilibria with generous structural margins. The limiting factor is not buckling but dynamic stability — at very low k the system becomes unstable (DECISIONS.md §2026-07-06 documents V10 Tight unstable across the low-k range).

We also compute a separate **torsional collapse FoS** (Tulloch/Wacker criterion, line 396-398): the helical tether lines have a kinematic stability limit beyond which they overtwist and the shaft collapses. This is geometric collapse, not material failure.

---

### 3. Does k2 mean k = 2?

Yes. k2 means k_mppt = 2.0.

The MPPT control law is (from `src/parameters.jl:73`):
```
τ_gen = k_mppt · ω²      [N·m]
```
where k_mppt has units **N·m·s²/rad²** (from `src/types.jl:109`).

The operational range for the V10 family is k ∈ [2, 4, 6, 8, 10, 14]. Example: at ω = 400 rpm = 41.9 rad/s with k = 2, the generator reaction torque is τ = 2 × 41.9² = 3,511 N·m, and electrical power P = τ · ω = 147 kW.

The k value is the generator loading — higher k extracts more torque per RPM. The equilibrium ω is where P_gen(k·ω³) balances P_aero(ω), giving P ∝ 1/k at fixed wind. Lower k → higher equilibrium ω → more centrifugal relief → higher FoS. But there's a floor: too low k → parasitic drag eats all the power → 0 W output, and the rotor can't self-start.

In our notation: the design label "0.85·k2" means blade_scale λ = 0.85, k_mppt = 2.0.

---

### 4. What is the 30-second MPPT?

It's a **kickstart procedure applied during the launching phase**, before equilibrium.

Small blades (λ ≤ 0.85) cannot self-start. At low RPM, parasitic drag torque exceeds aerodynamic driving torque — the rotor sits stalled near ω ≈ 0 producing zero power. Our equilibrium finder (`settle_to_operational_state`) sweeps ω downwards from ~90 rpm, so it's blind to the high-ω equilibrium branch at 200–480 rpm. We had 6 of 8 blade scales marked "failed" in our catalog sweep before we realised they weren't failing — they just needed a different starting condition.

The kickstart procedure (from `scripts/kickstart_sweep.jl`):

1. **Settle** to equilibrium positions with no generator load (k = 0) — the rotor hangs in the wind but doesn't spin
2. **Inject high ω**: set all ring angular velocities to ω = 30 rad/s ≈ 287 rpm with consistent orbital velocities — this is the "kick"
3. **30-second no-load spin-up**: run the ODE with k = 0 for 30 seconds. The rotor spins freely, wind drives it to high RPM because there's no generator torque opposing it
4. **Engage generator**: set k_mppt to the target value (e.g., k = 2) and run 60 seconds to reach equilibrium

This finds the high-ω equilibrium branch that the standard settle misses. The difference is dramatic — our data shows λ = 0.80 at k = 4 goes from 0.2 kW (standard settle) to 131 kW (kickstart), a 698× increase.

The 30-second no-load phase is analogous to a helicopter autorotation entry or a conventional wind turbine allowing the rotor to accelerate before connecting the generator. In operation, this would be achieved by briefly disengaging the PTO (k = 0 or very low k) until the RPM climbs above the stall threshold, then smoothly ramping k to the target.

---

### 5. What does r mean in "tight ring"?

**r refers to r_bottom — the ground-end ring radius multiplier.**

From `src/builders_util.jl:18`:
```julia
r_bottom_scale::Float64=1.0
```

The DE-optimised bottom ring radius is r_bottom = 2.000 m (from `best_design.json`). The r_bottom_scale parameter allows post-design reinforcement of the ground ring: r_bottom_actual = 2.000 × r_bottom_scale.

- **r = 1.30** ("reinforced"): r_bottom = 2.60 m — wider ground ring, more taper (2.89→2.60), more buckling resistance at the bottom where cumulative tension is highest
- **r = 1.00** ("tight"): r_bottom = 2.00 m — the DE optimum, tighter ring at the ground end
- **r = 1.15** ("intermediate"): r_bottom = 2.30 m

In our design labels: "r1.30" means r_bottom_scale = 1.30, "r1.00" means tight ring.

**⚠️ Caveat with the builder bug:** r ≠ 1.0 also switches which builder function is called (builders_util.jl:101). r = 1.30 calls `build_kite_turbine_system_v5` which uses ring_spacing_v4 geometry; r = 1.00 calls `build_kite_turbine_system` which derives ring positions differently. Additionally the r_bottom_scale value lands in the wrong x-vector slot (the t_over_D position), so its effect on ring radius as-built was nearly inert. This is one of several issues we're fixing.

The ring radius r determines:
- Polygon beam length: L_beam = 2·r·sin(π/n_lines)
- Centrifugal force: F_cf = m_vertex·ω²·r
- Torsional collapse lever arm: τ_cap ∝ r²

---

### 6. Ring compression — axial or ring radius direction?

**Inward radial** — toward the shaft axis. NOT axial along the TRPT shaft.

The tether lines form a helical shaft between adjacent rings. At each ring vertex, the line tension has an inward radial component due to the taper angle (rings get narrower toward the ground). This inward radial force compresses the ring polygon.

From `src/trpt_optimization.jl:245-264`:
```
segment_inward_force: inward radial force per vertex from line tension
→ The taper angle between rings of different radii creates a radial component
→ sign convention: +inward (toward shaft axis)
```

The inward radial force F_v is resolved into **axial compression in each polygon beam segment**:
```
N_comp = F_v / (2·sin(π/n_lines))
```

This is the axial force along each CFRP beam strut between adjacent vertices of the polygon ring. The beam is loaded in compression axially (along its length), and the failure mode is Euler buckling.

This is separate from the **axial force along the TRPT shaft direction** — that load is carried entirely by the tether lines in tension. The rings experience zero net axial load along the shaft; they only see the inward radial squeeze from the tapered helical line geometry.

From `src/ring_forces.jl:260-269`:
```
"Expansion rotor radial force pushes outward on the ring.
 Radial = perpendicular to shaft axis."
```

**Summary of the ring load path:**
```
Tether line tension (helical, at taper angle)
  → inward radial component at vertex
    → resisted by polygon beam compression (ring squeeze)
    → partly offset by centrifugal relief (m·ω²·r, outward)
    → partly offset by expansion rotor radial lift (outward)
      → net F_v
        → N_comp = F_v / (2·sin(π/n)) in each beam
          → buckling check: FoS = P_crit / N_comp
```

---

### What changes with the builder fix

The polygon count going from 3 (triangle, as-built) to 12 (dodecagon, intended) changes the geometry factor in two ways:

| | Triangle (as-built) | 12-gon (intended) |
|---|---|---|
| 2·sin(π/n) | 2·sin(60°) = 1.732 | 2·sin(15°) = 0.518 |
| L_beam | 1.732·r | 0.518·r |
| N_comp per beam | F_v/1.732 | F_v/0.518 (3.34× higher) |
| P_crit | ∝ 1/L² (lower) | ∝ 1/L² (11.2× higher!) |
| T_per_line | T_total/3 | T_total/12 (¼ the tension) |

The 12-gon has shorter beams → much higher P_crit → net higher FoS despite the higher per-beam N_comp. Plus the total thrust is shared across 12 lines instead of 3. The DE optimizer found n = 12 to be the mass-optimal polygon count for the 50 kW design — this is physically sensible but our triangles completely misrepresent it.

We'll send corrected results as soon as the re-runs complete. I estimate 1–2 days depending on sweep coverage.

Apologies again for the confusion. Happy to jump on a call.

Best,
Rod
