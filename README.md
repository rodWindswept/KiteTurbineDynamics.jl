# KiteTurbineDynamics.jl

Full multi-body dynamics simulator for a **TRPT kite turbine** — a Tensile Rotary Power Transmission airborne wind energy system developed by [Windswept & Interesting Ltd](https://windswept.energy).

## What it is

Unlike quasi-static TRPT simulators, this package models every tether line individually as a chain of spring-damper rope nodes. Torsional coupling between rings is **emergent** from the helical geometry of those lines — there is no analytical torque formula. This enables simulation of:

- Rope sag and catenary shape under gravity and wind drag
- Line slack → torsional collapse (the key failure mode for TRPT)
- Per-ring polygon column Euler buckling factor of safety (CFRP hollow tube)
- Hub spin-up, MPPT generator load, and power extraction

**System size:** 241 nodes (16 RingNodes + 225 RopeNodes), 1 478-state ODE.

## Design reports

Three companion design reports are included in this repository:

| Report | Contents |
|---|---|
| [TRPT_Ring_Scalability_Report.docx](TRPT_Ring_Scalability_Report.docx) | CFRP ring structural sizing, Do ∝ √R scaling law, mass budget, P/W vs rotor radius (1–5 m) |
| [TRPT_Stacked_Rotor_Analysis.docx](TRPT_Stacked_Rotor_Analysis.docx) | Blade count sweep (n=3–6), rotor stacking (1–3 rotors), wake geometry, hub ring force balance |
| [TRPT_Conical_Stack_Analysis.docx](TRPT_Conical_Stack_Analysis.docx) | Wind shear benefit of stacking, TSR-matched centrifugal radius expansion, conical stack P/W |

Key result: a 3-rotor conical stack (R = 5.0, 5.52, 5.85 m) delivers **44.2 kW at 540 W/kg** — 27% above the single-rotor baseline — through wind shear plus passive centrifugal radius expansion.

## Install

```julia
pkg> add https://github.com/windswept/KiteTurbineDynamics.jl
```

Or from a local clone:

```julia
pkg> dev /path/to/KiteTurbineDynamics.jl
```

## Quick start

```julia
using KiteTurbineDynamics

p        = params_10kw()                     # 10 kW parameter set
sys, u0  = build_kite_turbine_system(p)      # 241 nodes, 300 sub-segments
u_settled = settle_to_equilibrium(sys, u0, p) # gravity sag pre-solve (~0.3 s)

# Custom wind profile
wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# Seed hub angular velocity and run 2 s forward
N, Nr = sys.n_total, sys.n_ring
u_start = copy(u_settled)
u_start[6N + Nr + Nr] = 1.0   # hub omega = 1 rad/s

u_final = simulate(sys, u_start, p, wind_fn; n_steps=50_000, dt=4e-5)
println("Hub ω = ", u_final[6N + Nr + Nr], " rad/s")

# Structural safety check
alpha_vec = u_final[6N+1 : 6N+Nr]
sf = ring_safety_frame(u_final, alpha_vec, sys, p)
for r in sf
    @printf "Ring %2d  FoS = %.2f\n" r.ring_id r.fos
end
```

## GLMakie dashboard

```julia
# scripts/interactive_dashboard.jl — pre-built script
julia --project=. scripts/interactive_dashboard.jl
```

Opens a 3D view with rope node geometry, ring polygons coloured by structural utilisation (blue = safe → red = at limit), a structural HUD, and a frame slider for playback.

## System architecture

```
Ground anchor (fixed)
│
├─ 5 tether lines × 4 sub-segments per inter-ring segment
│    Each segment: ring_A ─ rope_1 ─ rope_2 ─ rope_3 ─ ring_B
│    Torque transmission holds rings in a twisted state; the resulting
│    attachment-point displacement elastically stretches each line — that
│    tension is the physical mechanism of torque propagation down the shaft
│
├─ 14 intermediate rings (intermediate RingNodes)
│
└─ Hub (RingNode) — rotor disc, kite tether attachment
     Kite lift + rotor thrust + MPPT generator load
```

## Blade geometry

TRPT blades are **annular**, not full-disc. Each blade spans from the hub ring to the outer tip:

| Parameter | Value |
|---|---|
| Outer tip radius R | 5.0 m |
| Hub ring radius r_hub | 2.0 m (= 0.4 × R) |
| Blade span | 3.0 m |
| Blade CoM radius r_cm | 3.8 m (r_hub + 0.6 × span) |
| Total blade mass (5 blades) | 11.0 kg |

Aerodynamic Cp and CT coefficients (from AeroDyn BEM, `Rotor_TRTP_Sizing_Iteration2.xlsx`) are normalised to full disc area πR² by convention. The inner hub region (r < 2 m) contributes negligibly at operational TSR (local TSR at r_hub ≈ 1.64), so this normalisation is consistent with the physical swept annulus. CT uses the BEM table — at λ_opt ≈ 4.1, CT ≈ 0.548 (not a fixed constant).

## Structural design basis

Ring frames are regular pentagons of CFRP hollow tubes.
The governing failure mode is **Euler column buckling** of each flat polygon segment (pin-pin),
not ring hoop Euler buckling.  Key design parameters (10 kW, 5-line pentagon):

| Parameter | Value | Source |
|---|---|---|
| Ring tube material | CFRP hollow tube, t/D = 0.05 | TRPT_Ring_Scalability_Report.docx |
| CFRP Young's modulus | 70 GPa (conservative isotropic) | ibid. |
| Column buckling FoS | 3.0 at rated tether tension | ibid. |
| Hub ring D_o × t | ≈ 19.7 mm × 0.99 mm (exact); 20.7 mm report (thin-wall approx.) | ibid. §3 |
| Do scaling law | Do = 13.96 mm/m^0.5 × √R | N_comp constant ∴ I_req ∝ R² ∴ Do ∝ √R |
| Ring mass (14 rings, R=5m) | 9.57 kg (= 0.684 kg/ring) | TRPT_Ring_Scalability_Report.docx |
| Tether tension at rated | ~2333 N/line (elastic stretch) | simulation calibrated |
| Hub ring centrifugal load | ~3402 N outward (11 kg × 9.02² rad/s² × 3.8 m) | TRPT_Stacked_Rotor_Analysis.docx §6 |

Tether tension arises because torque transmission holds adjacent rings in a twisted state,
displacing attachment points and elastically stretching each line beyond its natural length.
The twist and the tension are coupled outputs of the torque balance — not cause and effect.

The hub ring is in **net hoop tension** at rated speed (centrifugal load 3402 N outward exceeds tether inward compression ~750–800 N). Intermediate rings remain compression-governed (Euler buckling).

See [TRPT_Ring_Scalability_Report.docx](TRPT_Ring_Scalability_Report.docx) for the full
scalability analysis across 1–5 m rotor radius (1–50 kW class).

## Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

All 11 test suites pass:
- Parameters, aerodynamics, types, geometry, rope forces, ring forces, ODE smoke
- Static equilibrium (gravity sag), rope sag, emergent torsion, power generation

## Backlog

Planned improvements not yet implemented:

- **Solid-body collision physics** — ring and rotor interpenetration currently possible under severe droop (hub falls through TRPT rings below it during free-fall with no wind). Need contact normals + impulse-based rigid-body response so rings bounce/stack rather than pass through each other.
- Pitch & bank kite control loop (currently elevation angle is fixed at 30°)
- Stacked rotor configurations (multiple turbine stages on one TRPT shaft)
- Expanding / variable-radius rotors
- Launch and retrieval sequence simulation (ramp from ground to operating altitude)
- Turbulent wind field input (von Kármán or Kaimal spectrum)
- Fatigue life estimation from tether tension cycles

## Licence

MIT © 2025 Rod Read / Windswept & Interesting Ltd
