# Proposal: the TRPT drag torque does not reach the shaft

**Date:** 2026-09-26
**Status:** Proposed. Awaiting Rod. No code changed.
**Ruling behind it:** Ruling 4 of 2026-09-26. Rod: "let's read and check the code first".
**Place in the order:** step one and step two of 4, 3, 1, 2, then the settling benchmark.

## Terms

| Term | Meaning |
|---|---|
| TRPT | Tensile Rotary Power Transmission. The tension-torsion drive between rings. |
| ring node | A rigid ring. Its state holds a centre position and a spin angle. |
| spin degree of freedom | The ring angle about the shaft axis. |
| moment arm | The vector from the ring centre to the point where a force acts. |
| moment | The turning effect of a force. Here we use its part along the shaft. |
| CD | Drag coefficient. A non-dimensional number in the drag force. |
| TSR | Tip speed ratio. Blade tip speed divided by wind speed. |
| segment | The tether set between two adjacent rings. Also called a bay. |
| steady state | The condition where the spin rate stops changing with time. |

## 1. The defect

The ring spin equation reads one input. It reads the torque accumulator.

    src/dynamics.jl:189      du[6N + Nr + ri] = torques[ri] / I_z

A force enters the translational equation only.

    src/dynamics.jl:179      du[bv:(bv + 2)] .= forces[i] ./ m

So a force in `forces[]` cannot reach the spin equation. Two drag sources write to
`forces` and never to `torques`:

| Source | Site | Action |
|---|---|---|
| Tether drag | `src/rope_forces.jl:444-447` | halves the drag, adds each half to a node force |
| Ring tube drag | `src/dynamics.jl:140-144` | adds the beam drag to the ring centre force |

The same function applies the moment for the tether tension force.

    src/rope_forces.jl:458-466    tau_a = (r_a x F_vec) . shaft_dir      torques[ri_a] += tau_a

So the code holds the pattern and applies it to one force type only. No drag torque
appears anywhere else in the tree. The only `tau_drag` is the expansion rotor blade drag
at `src/expansion_rotor.jl:391`. That is a different subsystem.

## 2. Why it matters

The ring centre sits on the shaft axis. A tangential force applied at the centre does no
work on the rotation. So the drag cannot slow the shaft. Its energy goes into the
ring-centre translational mode and into the rope nodes instead.

Two consequences:

1. The TRPT does not resist rotation by its own drag. Steady state spin and power are too
   high.
2. The screen and the ODE disagree. `src/initialization.jl:971` computes the drag power
   analytically, and the objective uses it. The ODE does not apply the torque.

Two sources exist in the code, and only one of them is a defect. The tether uses
`TETHER_DRAG_CD = 1.0` (`src/aerodynamics.jl:335`). The ring tube uses `TUBE_DRAG_CD =
1.2` (`src/aerodynamics.jl:343`).

The ring tube is not a defect, and it is not a torque source either. The tube axis lies
on the circumference, and the spin flow lies on the circumference. So the tube slides
lengthwise through the air, and the spin flow makes no cross-flow drag. The code takes
the part of the relative velocity perpendicular to the beam axis
(`src/dynamics.jl:136-138`). That part is near zero for the spin. The printed model
neglects the ring drag for the same reason (printed page 219). So the missing torque is
the tether drag alone.

The size is not measured. A review claimed 3.6 kW. Nobody verified that number. The
printed anchors are 4.9 N·m at CD 1.2 and 9.9 N·m at CD 2.7 on the Daisy's TRPT#4,
printed page 218.

## 3. The fix

One site. It adds the moment for the force the code already applies.

Site 1, `src/rope_forces.jl`, inside the existing ring-end block. That block already
computes the moment arm `r_a`. Reuse it.

    tau_drag = (r_a x hdrag) . shaft_dir
    torques[ri_a] += tau_drag

**Site 2 is not needed.** The ring tube slides lengthwise, so its spin drag is small, and
the printed model neglects the ring drag as well. See section 2. The measurement in
section 5 tests this claim rather than assuming it.

Both the fix and the tension path project the moment on the shaft axis.

Keep the drag moment out of `seg_tau_a`. That accumulator feeds the C1 torque clamp, and
it holds the transmitted spring torque only. Drag inside it would corrupt the clamp.

## 4. Tests, written first

T1. Unit, fast. `shaft_moment(r, F, shaft)` returns `(r x F) . shaft`. Check it against a
hand case with a known answer.

T2. Unit, fast. Wiring check. Build a two-ring fixture, give a sub-segment a known
relative velocity, call `compute_rope_forces!`, and assert that `torques` gains the drag
moment. This test fails before the fix. It depends on a synthetic-system fixture. I will
confirm that fixture exists before I write the test.

T3. Acceptance. The balance test, the bound, and the oracle. See section 5.

T4. Acceptance, after Ruling 3 lands. Set the tether drag coefficient to 1.2 and to 2.7 on
a Daisy-equivalent, and check the torque loss against the printed pair: 4.9 N·m at 1.2 and
9.9 N·m at 2.7 on TRPT#4 (printed page 218).

Gates: T1 and T2 go in `test/runtests.jl`. T3 and T4 go in `test/acceptance_runtests.jl`,
because each one needs a steady state.

## 5. The measurement, before any code changes

This probe needs no code change. It reads the present model and reports the missing
amount. Run one steady state on the live campaign seed at fixed wind.

From the final state, recompute the drag torque with the same formulas the code uses:

- tether: sum over sub-segments of `(r_attach x hdrag) . shaft_dir`, for the ring-end shares
- tube: sum over rings and beams of `(r_mid x F_beam) . shaft_dir`

Then compare with the shaft balance. At steady state the rotor torque must equal the
generator torque plus the total drag torque. The model applies no drag torque, so the
residual equals the missing moment.

Three checks come out of the same probe:

1. **The residual** is the missing torque. Record it in N·m, as a fraction of the shaft
   torque, and as power at the steady spin rate. The power figure settles the 3.6 kW
   claim.
2. **The bound.** At steady state the total drag torque must stay below the rotor torque.
   A result that breaks the bound means the measurement is wrong, not that the machine is
   broken. This bound already caught one bad estimate. See the correction record below.
3. **The oracle.** The source gives its own tether drag loss, and Table 5.10 (printed page
   214) compares the drag models. Our missing moment must land near that value for the
   same geometry and the same coefficient. The printed pair is 4.9 N·m at coefficient 1.2
   and 9.9 N·m at 2.7 on TRPT#4.

After the fix, the same probe must show a residual inside the integration tolerance.

### Correction record

An estimate of 2026-09-26 put the missing torque at 306 N·m for the tether and 1051 N·m
for the ring tubes on the live seed at 13.75 rad/s. The tube figure was wrong. It applied
the full tangential velocity against the frontal area, but the tube slides lengthwise, so
its spin flow is not cross-flow. The bound in check 2 falsifies the figure: 1051 N·m
against a 364 N·m shaft torque cannot hold. The tether figure is also crude. It is about
3.8 times high against the printed anchor, most likely because it ignores the torsional
deformation of the twisted tether. Treat both as discarded. The measured value replaces
them.

## 6. Risks

- The ring-centre drift mode loses its drag drive. The dynamics will change. Steady state
  spin and power will fall. Campaign numbers are not comparable across the fix.
- The fix changes physics, so the eight acceptance tests must run before any merge.
- The clamp interaction is the main hazard. See section 3.
- The drag torque must stay below the rotor torque. Assert it in the acceptance test.

## 7. What must not change

- The C1 clamp semantics. It holds the spring torque only.
- The tension path. It is correct, and it is the model for this fix.
- The two drag coefficients. Ruling 3 sets them later, after this fix.

## 8. Recording

The probe results go in `docs/validation/` with five items: the git hash, the seed, the
wind speed, the CD value, and the spin rate. A result without those five items is not
usable.
