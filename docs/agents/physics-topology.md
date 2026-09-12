# Physics Topology — KTD.jl

**Mandatory read before any geometry, tension, load-path or rotor-model work.**
This page exists because the same class of mistake has been repeated across
sessions: re-deriving the structure *from expectation* instead of from the
recorded design. The topology below is the design. Do not re-derive it without
new measured evidence and Rod's agreement.

Last updated: 2026-09-12.

---

## 1. What is fixed and what floats

**Only two things touch the ground:**

1. the **ground ring** (bottom of the TRPT, free to rotate — this is the PTO end), and
2. the **backline ground anchor**.

**Everything above the ground ring is airborne and free to move.** The sky hook,
the lift bearing, the main rotor and every intermediate ring are all floating. The
TRPT column is **not** a rigid shaft: it is a **tensegrity** structure whose form
follows the tension balance. The rings holding the lines out against over-rotation
is what preserves torque transmission.

Because nothing overhead is anchored, there is no "ground truth" position for the
airborne assembly. Its operating position is wherever the tension balance puts it,
and it is pulled lower toward the ground station than the zero-twist design
position.

---

## 2. The lift chain — four separate links, four different names

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

Terminology is load-bearing here. **"Bridle" is the bearing→rotor link;
"cyan line" is the sky-anchor→bearing link.** They are never the same line, and
their tensions are different quantities. In `DECISIONS.md` the bridles are called
the **gold bridles**; the dashboard draws them gold (`dashboard_v2.jl:288`).

Do **not** write "bridles (cyan lines)". Do **not** write bare "the line" when you
mean one of these four.

---

## 3. The load path: the lift chain carries the main rotor

The topmost rotor is **the main rotor**. Everything below it is the transmission
for that rotor's torque. Any rotor below may additionally be an expansion rotor,
adding further torque and thrust.

The pull-up path is:

```
   lifter kite  ->  lift line  ->  sky anchor  ->  cyan line  ->  lift bearing
                ->  bridles    ->  MAIN ROTOR (topmost ring)
```

The main rotor is held up by **two** contributions acting together:

1. the **lift chain**, arriving through the taut bridles, and
2. its own **autogyro thrust**.

Both act up-shaft against the transmission's tension. **The lift is applied
throughout operation**, not only at spin-up: the lifter is sized to deliver a
**1.5 × airborne-weight vertical component** at the lift bearing, consistently.
Field sequence (Rod): the topmost kite is launched first, it lifts the whole rig
and pulls it into a tensile state, then the system is allowed to spin up.

Consequence that has been missed repeatedly: **if the bridles are slack, the lift
chain is structurally decoupled from the rotor.** That is a named failure mode,
not a benign state — see `DECISIONS.md:1806-1822` ("12/13 bridles slack, tension
chain broken") and `:2108-2120` ("the gold bridles go completely slack (Tension =
0.0 N) ... structurally decouples the ground generator from the airborne rotor").

**Rule: every line above the ground ring must be in tension at the operating
point. Slack is a defect to be diagnosed, never a resting state to be accepted.**

### 3.1 Bridle geometry: shallow at the APEX

The bridles are **all the same fixed length**, set once before launch, long enough
to form a **shallow-angled cone** so they tend *less* to crush the rotor ring.

Naming the angles matters, because they invert each other:

- **apex angle** — between the bridle lines, at the lift bearing. **Shallow**
  (small) is the design intent.
- **angle from the shaft axis** — the same line measured from the axis. Also small
  when the apex is shallow.
- **angle at the ring plane** — the complement. **Large** when the apex is
  shallow.

A shallower apex means the lines are more **aligned with the axis**, so the same
tension produces **less radial compression** on the ring, and enough banking can
make the ring **tensile rather than compressed**.

Measured on the 5 kW / 18.8 m seed, the correct geometry is approximately:

| quantity | value |
|---|---|
| lift-bearing offset from the main rotor (axial) | ~3.99 m |
| ring radius at the main rotor | 2.4 m |
| bridle 3D length | ~4.66 m |
| apex half-angle / angle from shaft axis | ~31° |
| angle at the ring plane | ~59° |

`bearing_offset = 6.0` (`initialization.jl:166`) and the derived bridle rest
length (6.462198 m) are a **placeholder carried over from other tested systems**
(Rod 2026-09-12) — the axial design point was never chosen. Treat both as
provisional, and derive them from the taut-chain balance rather than trusting them.

### 3.2 The back line is not a load path

In the field the backline was partially elasticated (elastic sewn into the dyneema
at several points): it takes up slack to stay tidy and only tightens hard once
pulled to the dyneema length. It exists to **restrict the altitude of the sky
hook**, not to carry the machine.

The code models it as a rigid catenary that is tension-only
(`ring_forces.jl:511-560`), so at some settled positions it reads **slack by ~1 m**
and contributes nothing. If the sky hook rises, the backline goes taut and limits
altitude. Do not treat a slack backline as evidence that the chain is broken, and
do not treat a taut backline as evidence that it carries the rotor.

---

## 4. Rotor models — every rotor may be a banked-blade expansion rotor

| term | meaning |
|---|---|
| **main rotor** | the topmost rotor. Historically called the "hub rotor". `RotorSpec`, `sys.rotor`. |
| **expansion rotor** | a banked-blade rotor on a TRPT ring; generates radial force (spreading the tethers) plus its own axial thrust and torque. |
| **hub** | avoid this word for the rotor. If you mean the topmost rotor, say **main rotor**. |

**Rule (Rod 2026-09-12): any rotor may be configured as a banked-blade expansion
rotor, including the topmost/main rotor. All rotors should be capable of it.**

**Model selection (Rod 2026-09-12): when the topmost rotor carries banked blades,
the banked-blade expansion model REPLACES the cp/ct disc model at that ring.** The
two models must never both be applied to the same annulus — that was the original
defect (2026-08-22) and it is why the hub was excluded. The correct resolution is
**replace, not exclude**.

This supersedes the 2026-08-22 hub exclusion, which is still recorded as current
in `CONTEXT.md` and enforced in code. Known consequences to handle when changing it:

- `expansion_params_from_rotors` (`builders_util.jl:90`) silently `continue`s on
  the top ring — a **silent no-op**, not an error. The same guard is duplicated at
  `ring_forces.jl:263` (`er.ring_idx == hub_ri && continue`).
- The main-rotor thrust is hardcoded at `hub_gid` (`ring_forces.jl:215`), so the
  cp/ct model is not currently per-ring.
- `expansion_airborne_mass` books the main rotor as `p.n_blades · p.m_blade`
  **plus** the sum of expansion assemblies (`expansion_analysis.jl:59-62`). A
  banked top rotor must not be charged twice.

---

## 5. Pre-flight checklist

Run this **before** any geometry, tension, load-path or rotor-model derivation.
Every item corresponds to a mistake that cost a session.

1. **Which rotor is which?** Name the topmost rotor the **main rotor**. State
   which rings carry rotors and which model governs each ring.
2. **Is every line above the ground ring taut?** Check cyan, bridles and backline
   tensions at the operating point. Zero tension on the bridles means the lift
   chain is disconnected — that is the finding, not a detail.
3. **Is this constant measured, derived, or a placeholder?** Trace it to its
   source. `bearing_offset = 6.0`, the bridle rest length and `cyan_L0 = 5.0` are
   placeholders; `1.5 ×` is the lifter sizing margin.
4. **Which frame are you measuring an angle in?** Apex, shaft-axis and ring-plane
   angles are complements of each other. State the frame explicitly.
5. **Did you include EVERY rotor's thrust?** On the seed the main rotor is only
   ~15 % of the total axial thrust (309 N of 2044 N); the two expansion rotors
   contribute ~85 %. A single-rotor budget is wrong.
6. **Sign and dimension check on any closed form.** Substitute units. A formula
   that yields Newtons where torque is required is a bug. Then check it against an
   independently computed value.
7. **Does a guard silently no-op?** Search for `continue`, `clamp`, `max(0.0, …)`
   and fallback branches on the path you are touching. Silent truncation has
   produced at least three separate defects.
8. **Was the mechanism re-derived, or remembered?** If you are about to "simplify"
   the load path, the ring model or the geometry, stop and read this page.

---

## 6. Silent truncations — forbidden pattern

Every one of these returned a plausible-looking value instead of raising:

| where | behaviour | consequence |
|---|---|---|
| `initialization.jl:972` | `_matched_place_twist` returns the **untwisted** placement (`Δα = 0`, `L_ax = chord0`) when `τ_carry ≤ 0` | a dead preload knob, `df/dT ≡ 0` |
| `initialization.jl:987` | `asin(clamp(sinΔα, -1, 1))` returns **90°** when the requested torque is unreachable | silently saturated twist |
| `builders_util.jl:90` | top-ring rotor silently dropped from the expansion mapping | a configuration that cannot be expressed |
| `ring_forces.jl:263` | belief that the main rotor is an expansion rotor is silently discarded | requires human luck to notice |

When a physical precondition cannot be met, **raise**. Do not clamp, skip, or fall
back to a default.

---

## 7. Measurement traps

- **`capture_extended(...).segment_twist_deg` is WRAPPED** into (−180°, 180°]
  (`sim_frame.jl:414`). A segment wound past 90° reads as a small angle. Read the
  stored `u[6N+1 : 6N+Nr]` α block when the twist is large.
- **The hub axial residual is a whole-machine diagnostic.** If the lift chain is
  disconnected or the airborne assembly is not settled, that residual measures a
  non-equilibrium artefact, not a preload error.
- **The settle's returned ω may not be `ω_eq`.** The settle pins `ω_eq` in its
  loop, but the returned state has been observed at a different ω. Always read ω
  back from the state before quoting a torque `k·ω²`.
- **`len_damp`/bridle damping**: the airborne translational modes carry little
  damping; the lift chain can go slack↔taut repeatedly. A single-frame snapshot is
  not evidence about tautness — step the loop.
- **`sub_segs.length_0` is the 3D chord**, not the axial gap (see
  `domain.md` gotchas).

## 8. Reference

- `docs/plans/2026-05-12-sky-anchor-node.md` — the sky anchor's three-way balance.
- `docs/plans/2026-09-10-shaft-windup-workstream.md:209` — the lift-line audit
  table (sky anchor → cyan → bearing → bridles → hub). Carries a SUPERSEDED banner
  for other sections; this row remains accurate.
- `DECISIONS.md:1776-1779`, `:1806-1822`, `:2108-2120` — the slack-bridle
  decoupling failure mode, recorded three times.
- `docs/agents/instrument-trust-log.md` — instrument fault ledger and sanity bounds.
