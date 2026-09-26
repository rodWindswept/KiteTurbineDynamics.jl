# Proposal: a BEM evaluation for every expansion rotor

**Date:** 2026-09-26. **Status:** for a ruling by the owner. No physics change until approval.

**The ruling this implements:** each expansion rotor needs its own BEM evaluation. Each one
provides thrust, drives torque, and expands its ring radially in tension.

## 1. Why

The expansion rotor aerodynamics are the largest unanchored model in this repo. The source file
states the gap at `src/expansion_rotor.jl:65-67`:

> Validation gap: these are textbook values, not CFD or wind-tunnel data specific to the TRPT blade
> planform. AeroDyn BEM sweep or XFOIL run at Re 2x10^6 with the actual chord and AR would be the
> authoritative source.

Three constants carry the gap. `EXP_CL_DESIGN` sets the lift. `EXP_CD0_DESIGN` sets the profile
drag. `EXP_K_INDUCED` sets the induced loss. They apply to every expansion rotor at once. The main
rotor does not share the gap. Its power coefficient comes from the AeroDyn v5.0.0 tables in
`src/aerodynamics.jl`.

F13 gives the size of the consequence. At the settled state the screening path predicts 5.695 kW of
drive from the two expansion rotors. The dynamics predict 2.010 kW. That factor of 2.833 is
unresolved. One of its two candidate causes is the polar.

## 2. What already exists

| Item | Location or value |
|---|---|
| AeroDyn driver | `/home/rodbot/bin/aerodyn_driver`, built 2026-06-10 |
| Combined case driver | `ad_driver3.8.inp`, in the NAS AeroDyn folder |
| Primary input | `ad_primary_MVP.inp` |
| Airfoil polar | `ad_airfoil_Rigid.inp`, NACA4412, 147 points, Re 250k |
| Main rotor blade | `ad_blade_MVP.inp`: 31 nodes, span 3.0 m, chord 0.500 m, zero twist |
| Pipeline | the `aerodyn-bem` skill, `references/bem-table-pipeline.md` |
| Existing result | peak Cp 0.3087 at lambda 5.2, and Cp 0.2955 at the design lambda 4.1 |

The driver file shows three separate geometry knobs. `ShftTilt` tilts the whole shaft. `Precone`
cones the whole blade away from the rotor plane. `BlCrvAng` curves one blade along its span. Run
all three, because a banked tip is not the same shape as a coned blade.

## 3. The cases

### 3.1 A regression on the main rotor

Reproduce the known table first. Use three blades, span 3.0 m, chord 0.500 m, hub radius 1.0 m,
pitch 3 degrees, bank 0, and lambda 1.0 to 8.0. Set `ShftTilt` to 0, because the tables are
coefficients at 0 degrees of elevation. The acceptance value is a peak Cp within 2 per cent of
0.3087 at lambda 5.2. This run proves the pipeline on this machine.

### 3.2 One case per expansion rotor

Read the geometry from `sys.expansion_rotors`. Do not type it by hand.

| Field | Source | Live seed, ring 11 | Live seed, ring 12 |
|---|---|---|---|
| blade count | `n_lines` | 6 | 6 |
| inner radius | ring radius plus `blade_hub_radius` | 2.400 minus 0.298, so 2.102 m | 2.400 minus 0.325, so 2.075 m |
| outer radius | ring radius plus `blade_tip_radius` | 2.400 plus 0.696, so 3.096 m | 2.400 plus 0.759, so 3.159 m |
| chord | `blade_chord` | read at build time | read at build time |
| bank | `bank_angle_deg` | 0.00 degrees | 0.00 degrees |

The offsets are signed. Each one is an offset from the ring radius. The 2026-08-24 geometry audit
set that convention.

### 3.3 A bank sweep over two values

The live seed carries 0.00 degrees of bank. The real design does not.
`docs/V10_TIGHT_DASHBOARD.txt` carries bank_top 32 degrees and bank_bottom 35 degrees.

| Bank | Purpose |
|---|---|
| 0 degrees | the live seed as built, so the two models compare like for like |
| 32 and 35 degrees | the design intent, so the effect of the bank is measured |

Encode the bank as a linear `BlCrvAng` ramp. Start at 0 degrees at the root and end at the design
value at the tip. That matches the definition the owner gave. The outer tip banks down from the
flat axial tangential plane toward the ground station end. Anhedral acts outward. Confirm the sign
AeroDyn takes in the first run.

### 3.4 The settings

Vary the tip speed ratio from 1.0 to 8.0. Vary the yaw over 0 and the operating value. Hold the
pitch at 3 degrees. Match the 2026-06-10 regeneration. Set `Skew_Mod=1` for Glauert, `BEM_Mod=2`,
and `UA_Mod=0` for quasi-steady. Keep the tip loss and the hub loss on.

## 4. Outputs

| Output | Use |
|---|---|
| `RtAeroCp`, `RtAeroCt`, `RtAeroCq` at each lambda | the per-rotor tables that replace the three constants |
| `RtTSR` | the lambda axis |
| the yaw 0 rows only | the baseline table, per the double-count rule |
| the in-plane or spanwise force | the radial force that loads the radial tethers |

The radial force needs one decision before the run. For a banked rotor the in-plane force at rotor
level cancels across opposed blades. The hoop load is therefore the per-blade spanwise force times
the blade count. That needs the per-node sectional output enabled in the primary file. A cheaper
route is already in the model, which resolves the axial thrust through the bank angle. Take the BEM
route where the output allows it. Publish the thrust-times-bank route as a cross-check.

## 5. What this changes after approval

1. `EXP_CL_DESIGN`, `EXP_CD0_DESIGN` and `EXP_K_INDUCED` become per-rotor BEM lookups. Each lookup
   uses that rotor's own lambda.
2. A per-rotor, per-lambda table lands beside `BEM_CP` and `BEM_CT`.
3. The tests that pin the current constants change with the tables, and they stay.
4. Record the change in the reference library.

## 6. What this does not do

- It does not calibrate the tables down to system level or rig data. The skill rule stands. The
  April-29 anchor is 212 to 227 W at 5 to 8 m/s. That anchor is evidence, not a target.
- It does not reconcile the screening path with the dynamics. That is a separate ruling.
- It does not enable the spoke element, which every campaign leaves off. Section 7 covers that item.

## 7. The linked structural item

`src/ring_forces.jl:343-345` records that the effective radii update went on 2026-06-14. The old
displacement model produced absurdly large radii from realistic blade forces.

The owner has given the reason. The inner tips of the blades are tied together by the radial lines.
Tulloch names the same parts at lines 5113 to 5120. Six radial tethers run from the ring sleeve to
the centre of the rotor. Those tethers hold the blades inward. A displacement model without them
has no stiffness, so it runs away. That is exactly what the removed model did.

The model already carries a radial line. `SpokeParams` at `src/expansion_rotor.jl:513-522` holds a
7 mm SK78 Dyneema line with a safe working load of 19.8 kN. The load comes from a 44.0 kN breaking
load with a 0.90 splice derating and a 0.50 creep, fatigue and UV derating. Its own flag gates a
structural check and a drag torque. Every campaign leaves that flag off, so the radial load has a
home in the code and no home in the run.

That flag gates a check, and not a stiffness. Enabling it would report a pass or a fail on the
line. It would not bound the displacement. A bounded displacement needs the tether stiffness, and
that is the real work.

Tulloch also states the sign at lines 5130 to 5157. The bank and the anhedral of the wings provide
a radial force that expands the ring, and the centrifugal load adds to it. The rotor ring is
net-expanded, and the cone rings are net-compressed.

So the radial force has two destinations. The radial tethers take it in tension, and they bound the
expansion. The ring takes it in hoop tension, by the small expansion the tethers allow. This
proposal implements neither. It records them, so the BEM radial output has a destination.

## 8. Gate

Proposal, then a ruling by the owner, then the runs, then the table change with an acceptance test.
The regression in section 3.1 runs first, because it is the only case with a known answer.
