# AeroDyn geometry knobs — what each one means, and which one is our bank

Sources, all read directly:

- the running v5.0.0 input set on the NAS:
  `/mnt/Windswept Energy/_hermes_brain/KNOWLEDGE/aerodyn-v5.0.0/`, files `ad_driver_v5.inp`,
  `ad_blade_MVP.inp`. The quoted phrases in sections 1 to 3 are AeroDyn's OWN inline
  annotations, copied from those files.
- the OpenFAST documentation, AeroDyn input files page (v3.5.3), for the blade-file
  definitions quoted in section 3.
- O. Tulloch, PhD thesis, University of Strathclyde, 2021, text at
  `docs/validation/tulloch-thesis-extract.txt`. Extract line numbers are given for every
  quotation.
- field order and parser behaviour: the `aerodyn-bem` skill,
  `references/aerodyn-v5-input-format.md`.

Written 2026-09-30, corrected the same day. This page answers the question "which AeroDyn
knob carries our bank angle". It does not change any code.

---

## 1. The turbine geometry block

These fields FIX one value for a whole run. They sit in the `----- Turbine(1) Geometry
-----` block, so they cannot be swept across the combined cases.

| knob | AeroDyn's own words | what it is |
|---|---|---|
| `NumBlades(1)` | "Number of blades (-)" | blade count |
| `HubRad(1)` | "Hub radius (m)" | radius of the circle the blade roots sit on |
| `HubHt(1)` | "Hub height (m)" | hub height above the ground |
| `Overhang(1)` | "Overhang (m)" | how far the rotor centre sits downwind of the tower top |
| `ShftTilt(1)` | "Shaft tilt (deg)" | the tilt of the shaft axis away from horizontal |
| `Precone(1)` | "Blade precone (deg)" | coning: the blade angled out of the rotor plane |
| `Twr2Shft(1)` | "Vertical distance from the tower-top to the rotor shaft (m)" | tower-to-shaft offset |

## 2. The motion block

| knob | AeroDyn's own words |
|---|---|
| `NacYaw(1)` | "Yaw angle (about z_t) of the nacelle (deg)" |
| `RotSpeed(1)` | "Rotational speed of rotor in rotor coordinates (rpm)" |
| `BldPitch(1)` | "Blade 1 pitch (deg)" |

`NacYaw` is a fixed per-run value, but the combined-case row carries its own `Yaw` column,
so **yaw CAN be swept per case**.

## 3. The blade file

Column header, verbatim from `ad_blade_MVP.inp`:

```
BlSpn     BlCrvAC    BlSwpAC    BlCrvAng    BlTwist    BlChord    BlAFID
(m)       (m)        (m)        (deg)       (deg)      (m)        (-)
```

Per node. From the OpenFAST documentation:

- **`BlCrvAng`** — "the local angle (in degrees) from the blade-pitch axis of a vector
  normal to the plane of the airfoil, as a result of **blade out-of-plane curvature**
  (when the blade-pitch angle is zero); `BlCrvAng` is **positive downwind**."
- **`BlCrvAC`** — "the local **out-of-plane offset** ... of the aerodynamic center ... normal
  to the blade-pitch axis, as a result of blade curvature; `BlCrvAC` is positive downwind."
- **`BlSwpAC`** — "the local **in-plane offset** ... of the aerodynamic center ... normal to
  the blade-pitch axis, as a result of blade sweep; positive `BlSwpAC` is opposite the
  direction of rotation."
- **`BlSpn`** — spanwise station in metres, measured from the blade root. **It starts at
  zero at the root and cannot go negative.**
- **`BlTwist`** — local twist, degrees.

## 4. Which knob is which job

| our feature | AeroDyn knob | how close |
|---|---|---|
| **elevation** — the whole shaft tilted away from horizontal | **`ShftTilt`** | exact, and this is what Tulloch used |
| **bank** — the blade angled out of the ring plane, rigid and uniform along the span | **`Precone`** | the only knob of this kind. See section 6. |
| a blade **curved** along its span, out of plane | `BlCrvAng` + `BlCrvAC` | a different shape. Our blade is straight; this one bends. |
| a blade **swept** within its own plane | `BlSwpAC` | a different feature again |
| **yaw** misalignment of the rotor axis from the inflow | `NacYaw`, or the case `Yaw` column | the modelling datum for the elevation. See section 5. |

**So `ShftTilt` is where the elevation goes, and `Precone` is the banking knob.** Writing
a bank angle into `ShftTilt` tilts the whole shaft, which is the elevation. Those are
different things. That is why the earlier note that "the bank is a shaft tilt" was wrong.

## 5. Tulloch's own justification — the elevation angle IS modelled as yaw

This is the part Rod recalled. It is in the thesis, stated directly, and it is the reason
the repo's elevation treatment exists at all.

**The analogy, stated as the modelling datum** (extract lines 8474 to 8482):

> "due to the required elevation angle for rotary AWES, β, the rotor is tilted/pitched
> down into the oncoming flow. This causes a misalignment between the rotor plane and the
> wind vector. **This is analogous to a yawed wind turbine** as the resulting misalignment
> of the rotor plane and the wind vector causes similar effects. **The modelling of yawed
> HAWT's is used as a datum for modelling the rotor aerodynamics of rotary AWES.**"

**The elevation power law, from actuator disc theory on a yawed rotor** (extract lines
8544 to 8558):

> "applying actuator disc theory to a yawed rotor results in a reduced power output
> equivalent to **cos³β**, where β is the misalignment between the rotors axis of rotation
> and the wind vector. **An elevation angle of 30° results in a 35% reduction** in the
> rotors power output. Noura et al. [114] show that this approximation for the power
> reduction of a yawed turbine provides reliable results through comparison with
> experimental data."

His equation (4.1) at that point reads `P = ½ ρ Vw³ A Cp cos³β`.

**The validity envelope for BEM, expressed in elevation angles** (extract lines 8716 to
8724):

> "the use of BEM to represent the rotor aerodynamics of rotary AWES is **only suitable
> for low elevation angles of 30° or less, for wind speeds of less than 14 m/s and for tip
> speed ratios of less than 7**. [122] highlights the advantages of using a dynamic stall
> model, it is therefore **necessary that the BEM code used to model the rotary AWES rotor
> aerodynamics includes one of the available dynamic stall models**."

**Why the limit exists** (extract lines 8610 to 8700): as the rotor plane is yawed, the flow
over the blades becomes three dimensional, which contradicts BEM's assumption that each
blade section is independent. Yaw also gives the rotor an asymmetric flow field, so the
apparent wind at any one section varies with time, which can produce dynamic stall. Steady
two-dimensional lift and drag coefficients then give unreliable results.

**The direction of use matters.** Tulloch borrows the yaw literature to justify and bound
the ELEVATION treatment. Geometrically he still puts the elevation into `ShftTilt`. His own
driver file, reproduced in the thesis (extract lines 18199 to 18213), reads `HubRad 1.16`,
`HubHt 4.5`, `Overhang 0`, **`ShftTilt 25`**, **`Precone 0`**, and its combined-case row is
`WndSpeed ShearExp RotSpd Pitch Yaw dT Tmax` with `Yaw` at 0.

**So both statements hold, and they do not conflict.** `ShftTilt` carries the elevation
geometrically. Yaw is the modelling analogy, and it supplies the power law, the validity
envelope, and the reason a dynamic-stall model is mandatory.

## 6. Can AeroDyn represent a ring-anchored banked blade?

**Earlier in this same document I claimed it could not, and that claim was wrong.** I
argued that `BlSpn ≥ 0` cannot express the inboard 30 per cent of a ring-anchored blade.
Tulloch's own input contradicts me.

His Daisy model sets `HubRad` to 1.16 m (soft) or 1.22 m (rigid) — **below the 1.52 m ring
radius** — and runs `BlSpn` from 0 to about 1.0 m, root to tip. So the blade root sits
**inboard** of the ring, and the blade crosses the ring partway along its span. That is
exactly our 70 outboard / 30 inboard split.

**The recipe is therefore: put the blade's inner tip radius into `HubRad`, and let the ring
fall partway along the span.** AeroDyn never needs to know the ring exists. Tulloch says
outright how he handles the open centre (extract lines 8488 to 8495):

> "the rotors of rotary AWES often have open centres ... therefore the centre of the rotor
> is unfilled. This means that the length of the wings used within rotary AWES can be far
> smaller than the radius of the rotor. **Within this analysis this open centre is
> accounted for based on existing models of HAWT blade roots.**"

What remains genuinely open is the **bank**, not the ring:

1. **Does `Precone` give the same shape as our bank?** Precone offsets each spanwise
   station out of the rotor plane by an amount proportional to its distance from the hub,
   pivoting at the blade root. Our bank is a straight blade mounted at an angle to the ring
   plane. **The shapes appear to agree.** But the pivot is the root in AeroDyn and the ring
   in our model, and AeroDyn's sign convention is "positive downwind". This needs a reading
   of AeroDyn's precone geometry, not an assumption.
2. **`Precone` cannot be swept.** It is a turbine-geometry field, one value per run, while
   `Yaw`, `RotSpd`, `Pitch` and `HWndSpeed` are combined-case columns. **A bank sweep needs
   one driver run per bank angle.** Workable, but a different shape of sweep from the
   existing tables, and it must be planned for.

## 7. What the repo uses today

`src/aerodynamics.jl` holds Cp(λ) and CT(λ) from the AeroDyn v5.0.0 quasi-steady BEM sweep
of **2026-06-10, at 0° elevation**. That sweep ran 24 cases: three elevations by eight
tip-speed ratios, at 11 m/s. The elevation effect is then applied separately in the ODE, as
a `cos²·⁰` thrust factor and a **`cos²·⁶⁵`** power factor.

Two things to note against the thesis:

- **The geometry is consistent with Tulloch.** He put the elevation into `ShftTilt` as
  well. The repo's elevation sweep is that same move.
- **The exponent is not.** Tulloch's actuator-disc result for a misaligned rotor is
  **cos³β**. The repo's power exponent is **2.65**. At 30° that is 0.6495 against 0.6831 —
  the repo's figure is about 5 per cent more optimistic. The repo's exponent came from a
  BEM sweep and Tulloch's from actuator disc theory, and Tulloch calls the actuator disc
  result "an initial estimate". The difference is defensible, but it is not recorded
  anywhere and it should be.

Also note for any banked run: `ad_driver_v5.inp` sets `NumBlades(1)` to 3, and the repo's
expansion rotors take one blade per line (6 at six lines). The count must change.

## 8. Open, for Rod's ruling

1. **Does `Precone` reproduce our bank?** The shapes appear to agree; the pivot and the
   sign convention need checking against AeroDyn's own geometry definition. If it does not,
   `BlCrvAng` and `BlCrvAC` are the curved-blade alternatives, and a bespoke model is the
   last resort.
2. **The exponent.** Keep the BEM-derived `cos²·⁶⁵`, or move to Tulloch's actuator-disc
   `cos³`? Either way the choice gets written down, because today it is not.
3. **The dynamic-stall requirement.** Tulloch states that a BEM code modelling a rotary
   AWES rotor *must* include a dynamic stall model. The current AeroDyn settings run
   `UA_Mod = 3`, which is unsteady aero, but nobody has checked it against his
   Beddoes-Leishman finding. **This is on the critical path for any expansion-rotor table.**
4. **The tip speed ratio limit.** Tulloch's envelope is TSR below 7 and wind below 14 m/s.
   The repo's left-flank design point sits near TSR 4 to 5, so it is inside the envelope,
   but nobody has asserted it.

**No expansion-rotor table is generated until items 1 and 3 are settled.**
