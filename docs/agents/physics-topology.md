# Physics Topology: KTD.jl

**Mandatory read before any geometry, tension, load-path or rotor-model work.**
This page exists because sessions repeat the same class of mistake. They
re-derive the structure *from expectation* instead of from the recorded design.

The topology below is the design. Do not re-derive it without new measured
evidence and agreement from Rod.

Last updated: 2026-09-12.

---

## 1. What stays fixed and what floats

**Only two things touch the ground:**

1. the **ground ring** (bottom of the TRPT, free to rotate, and the PTO end), and
2. the **backline ground anchor**.

**Everything above the ground ring is airborne and free to move.** The sky hook,
the lift bearing, the main rotor and every intermediate ring all float. The TRPT
column is **not** a rigid shaft: it is a **tensegrity** structure whose form
follows the tension balance.

The rings holding the lines out against over-rotation is what preserves torque
transmission.

Because the airborne assembly has no anchor overhead, there is no "ground truth"
position for it. Its operating position is wherever the tension balance puts it,
and the tension balance pulls it lower toward the ground station than the
zero-twist design position.

---

## 2. The lift chain: four separate links, four different names

```
   LIFT KITE  .......................................... launched first; lift only
        |                                                (no torque, no drive)
        |  LIFT LINE            (1 line)
        |  kite <-> sky anchor
        v
   SKY HOOK / SKY ANCHOR  .............................. three-way knot
        ^                    (SkyAnchorNode)
        |  BACKLINE             (1 line, catenary)
        |  sky anchor <-> backline ground anchor
        |  **partially elasticated in the field**: takes up slack, stays in
        |  light tension, and only tightens hard once pulled to the dyneema
        |  length. Its job is to LIMIT ALTITUDE, not to carry the rotor.
        |
        |  CYAN LINE             (1 line)
        |  sky anchor <-> lift bearing  <-- the TRPT load
        v
   LIFT BEARING  ....................................... (BearingNode)
        |                     swivel; rides the shaft axis
        |  BRIDLES               (n_lines lines, e.g. 6)
        |  lift bearing <-> main-rotor attachment vertices
        v
   MAIN ROTOR  ......................................... TOPMOST ring of the TRPT
```

Terminology is load-bearing here. **"Bridle" is the bearing→rotor link. The
"cyan line" is the sky-anchor→bearing link.** They are never the same line, and
their tensions are different quantities. `DECISIONS.md` calls the bridles the
**gold bridles**. The dashboard draws them gold (`dashboard_v2.jl:288`).

Do **not** write "bridles (cyan lines)". Do **not** write bare "the line" when you
mean one of these four.

---

## 3. The load path: the lift chain carries the main rotor

The topmost rotor is **the main rotor**. Everything below it is the transmission
for the torque of that rotor. Any rotor below may also be an expansion rotor and
add further torque and thrust.

The pull-up path is:

```
   lifter kite  ->  lift line  ->  sky anchor  ->  cyan line  ->  lift bearing
                ->  bridles    ->  MAIN ROTOR (topmost ring)
```

**Two** contributions act together to support the main rotor:

1. the **lift chain**, arriving through the taut bridles, and
2. its own **autogyro thrust**.

Both act up-shaft against the tension of the transmission. **The lift acts
throughout operation**, not only at spin-up: the lifter delivers a
**1.5 × airborne-weight vertical component** at the lift bearing, consistently.
Field sequence (Rod): the topmost kite launches first, it lifts the whole rig
and pulls it into a tensile state, then the system starts to turn.

Sessions have missed this consequence repeatedly: **if the bridles are slack, the
lift chain is structurally decoupled from the rotor.** That is a named failure mode,
not a benign state. See `DECISIONS.md:1806-1822` ("12/13 bridles slack, tension
chain broken") and `:2108-2120` ("the gold bridles go completely slack (Tension =
0.0 N) ... structurally decouples the ground generator from the airborne rotor").

**Rule: every line above the ground ring must be in tension at the design
operating point, in the steady state. Treat *sustained* slack there as a defect to
diagnose, never as a resting state to accept.** Transient slack is expected —
lines cannot push, and a gust, a lull or a control transient will briefly unload
one, so a single-frame snapshot is not evidence about tautness. Step the loop.

### 3.1 Bridle geometry: shallow at the APEX

The bridles are **all the same fixed length**. We fix that length once before
launch, and it is long enough to form a **shallow-angled cone** so they tend
*less* to crush the rotor ring.

Naming the angles matters, because they invert each other:

- **apex angle**: between the bridle lines, at the lift bearing. **Shallow**
  (small) is the design intent.

- **angle from the shaft axis**: the same line measured from the axis. Also small
  when the apex is shallow.

- **angle at the ring plane**: the complement. **Large** when the apex is
  shallow.

A shallower apex means the lines are more **aligned with the axis**, so the same
tension produces **less radial compression** on the ring, and enough banking can
make the ring **tensile rather than compressed**.

The bridle cone is fixed by ONE design input — its half-angle — measured on the
5 kW / 18.8 m seed (2026-09-13):

| quantity | value |
|---|---|
| bridle cone half-angle (from the shaft axis) | 31° |
| angle at the ring plane | 59° |
| ring radius at the main rotor (seed) | 2.4 m |

Everything else is **DERIVED from the top-ring radius** (2026-09-14, Rod — the
offset must never be a prespecified number):

    bearing_offset(r_top) = r_top / tan(31°)     (= 3.99 m at 2.4 m radius)
    bridle 3D length      = r_top / sin(31°)     (= 4.66 m at 2.4 m radius)

The bearing sits at the apex of the cone, one cyan-line length below the sky
anchor.  The old `bearing_offset = 6.0` (and later `BEARING_OFFSET_DESIGN = 3.99`)
were single numbers standing in for this radius-dependent geometry, and both are
removed.  The single authority in code is
`bridle_bearing_offset(r_top)` in `src/initialization.jl`.

### 3.2 The back line is an altitude limiter, not a load path

In the field the backline was partially elasticated (elastic sewn into the dyneema
at several points): it takes up slack to stay tidy and only tightens hard once
pulled to the dyneema length. It exists to **restrict the altitude of the sky
hook**, not to carry the machine.

The code models it as a rigid catenary that is tension-only (`ring_forces.jl`).
Its design rest length is built from the sky-anchor design position (tether length
+ the DERIVED bearing offset + cyan length).  It sat ~1 m slack under the old 6.0
reference and ~0 under the derived offset.

**RULED (Rod, 2026-09-15): the back line is TAUT at the design point and carries
residual vertical tension.** The sky anchor must be in balance, and the lift line
over-lifts (1.5 × airborne weight vertical), so the surplus has somewhere to go. A
deliberate design-point slack allowance is therefore **rejected** — this closes the
open question previously recorded here. The elastic is what makes it
altitude-limiting: the back line is soft through the climb and engages when the
machine reaches its target elevation (normally 30°). It may go slack in operation
when wind or lift drops — an off-design transient, not the design point.

**It also has two safety jobs** (Rod, 2026-09-15): it **contains the machine if the
TRPT breaks** — the anchored back line is what stops the lift line dragging the
machinery away, or components flying free — and it **carries the machine while
raising and lowering it in tension**, for deployment, recovery, and high-wind /
high-altitude stalling. Its design load is therefore the worst of {design point,
hoisting, break containment, high-wind handling} — **not** the steady design
tension. None of those cases is quantified yet. See `docs/lift/README.md`.

A taut back line is not itself a defect; what must hold is that the lift reaches
the rotor via sky hook → cyan → bearing → bridle cone.

Do not treat a slack backline as evidence that the chain is broken, and
do not treat a taut backline as evidence that it carries the rotor.

---

## 4. Rotor models: every rotor may be a banked-blade expansion rotor

| term | meaning |
|---|---|
| **main rotor** | the topmost rotor, historically called the "hub rotor" (`RotorSpec`, `sys.rotor`). |
| **expansion rotor** | a banked-blade rotor on a TRPT ring. It generates radial force (spreading the tethers) plus its own axial thrust and torque. |
| **hub** | avoid this word for the rotor, and say **main rotor** if you mean the topmost rotor. |

**Rule (Rod 2026-09-12): you may configure any rotor as a banked-blade expansion
rotor, including the topmost/main rotor. All rotors should support it.**

**Model selection (Rod 2026-09-12): when the topmost rotor carries banked blades,
the banked-blade expansion model REPLACES the cp/ct disc model at that ring.**
Never apply both models to the same annulus.

That error was the original defect (2026-08-22), and it caused the hub exclusion.
The correct resolution is **replace, not exclude**.

This supersedes the 2026-08-22 hub exclusion, which `CONTEXT.md` still records as
current and code still enforces. Known consequences to handle when changing it:

- `expansion_params_from_rotors` (`builders_util.jl:90`) silently `continue`s on
  the top ring. That is a **silent no-op**, not an error. The same guard appears
  again at `ring_forces.jl:263` (`er.ring_idx == hub_ri && continue`).

- Code hardcodes the main-rotor thrust at `hub_gid` (`ring_forces.jl:215`), so the
  cp/ct model is not currently per-ring.

- `expansion_airborne_mass` books the main rotor as `p.n_blades · p.m_blade`
  **plus** the sum of expansion assemblies (`expansion_analysis.jl:59-62`). We
  must not charge a banked top rotor twice.

---

## 5. Pre-flight checklist

Run this **before** any geometry, tension, load-path or rotor-model derivation.
Every item corresponds to a mistake that cost a session.

1. **Which rotor is which?** Name the topmost rotor the **main rotor**. State
   which rings carry rotors and which model governs each ring.

2. **Is every line above the ground ring taut?** Check cyan, bridles and backline
   tensions at the operating point. Zero tension on the bridles means the lift
   chain has no connection to the rotor. That is the finding, not a detail.

3. **Is this constant measured, derived, or a placeholder?** Trace it to its
   source. `cyan_L0 = 5.0` is a cut rope length (a fixed physical input).
   `bearing_offset` and the bridle rest length are **DERIVED** from the top-ring
   radius via `bridle_bearing_offset(r_top) = r_top / tan(31°)`. `1.5 ×` is the
   lifter sizing margin.

4. **Which frame are you measuring an angle in?** Apex, shaft-axis and ring-plane
   angles are complements of each other. State the frame explicitly.

5. **Did you include the thrust of EVERY rotor?** On the seed the main rotor is
   only ~15 % of the total axial thrust (309 N of 2044 N). The two expansion
   rotors contribute ~85 %. A single-rotor budget is wrong.

6. **Sign and dimension check on any closed form.** Substitute units. A formula
   that yields Newtons where torque must act is a bug. Then check it against an
   independently computed value.

7. **Does a guard silently no-op?** Search for `continue`, `clamp`, `max(0.0, …)`
   and fallback branches on the path that you touch. Silent truncation has
   produced at least three separate defects.

8. **Was the mechanism re-derived, or remembered?** If you are about to "simplify"
   the load path, the ring model or the geometry, stop and read this page.

---

## 6. Silent truncations: forbidden pattern

Every one of these returned a plausible-looking value instead of raising:

| where | behaviour | consequence |
|---|---|---|
| `initialization.jl` `trpt_matched_place` | returns the **untwisted** placement (`Δα = 0`, `L_ax = chord0`, i.e. zero strain) when `τ_carry ≤ 0` | a dead preload knob, `df/dT ≡ 0`. The segment silently carries no preload. **STILL OPEN (2026-09-13)** |
| `initialization.jl` `trpt_matched_place` | `asin(clamp(sinΔα, -1, 1))` returned **90°** when the requested torque was unreachable | silently saturated twist. **FIXED 2026-09-13**. It now RAISES. `test/test_trpt_realisability.jl` guards it. Measured before the fix: 4 segments × 90° (a full turn) at 4 lines/3 rotors, 12 × 90° (three turns) at 6 lines/1 rotor |
| `initialization.jl:961` `lift_chain_design` | `ω = omega_eq > 0 ? omega_eq : 12.983466`, the **equilibrium ω of the campaign seed** | a fallback. The code evaluated each preload at the speed of a foreign design. Then `ω = 0` was unrepresentable. **FIXED 2026-09-13**. It uses the ω of the caller |
| `builders_util.jl:90` | top-ring rotor silently dropped from the expansion mapping | the code cannot express that configuration |
| `ring_forces.jl:263` | the code silently discards the belief that the main rotor is an expansion rotor | requires human luck to notice |

When a physical precondition cannot be met, **raise**. Do not clamp, skip, or fall
back to a default.

---

## 7. Measurement traps

- **`capture_extended(...).segment_twist_deg` WRAPS** into (−180°, 180°]
  (`sim_frame.jl:414`). A segment wound past 90° reads as a small angle. Read the
  stored `u[6N+1 : 6N+Nr]` α block when the twist is large.

- **The hub axial residual is a whole-machine diagnostic.** If the lift chain has
  no connection or the airborne assembly has not settled, that residual measures a
  non-equilibrium artefact, not a preload error.

- **The ω that the settle returns may not be `ω_eq`.** The settle pins `ω_eq` in
  its loop, but observers have seen the returned state at a different ω. Always
  read ω back from the state before quoting a torque `k·ω²`.

- **`len_damp`/bridle damping**: the airborne translational modes carry little
  damping. The lift chain can go slack↔taut repeatedly. A single-frame snapshot is
  not evidence about tautness. Step the loop.

- **`sub_segs.length_0` is the 3D chord**, not the axial gap (see
  `domain.md` gotchas).

## 8. Reference

- `docs/plans/2026-05-12-sky-anchor-node.md`: the three-way balance of the sky anchor.

- `docs/plans/2026-09-10-shaft-windup-workstream.md:209`: the lift-line audit
  table (sky anchor → cyan → bearing → bridles → hub). It carries a SUPERSEDED
  banner for other sections. This row remains accurate.

- `DECISIONS.md:1776-1779`, `:1806-1822`, `:2108-2120`: the slack-bridle
  decoupling failure mode, recorded three times.

- `docs/agents/instrument-trust-log.md`: instrument fault ledger and sanity bounds.
