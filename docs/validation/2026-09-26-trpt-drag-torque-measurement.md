# T3 measurement: the tether drag torque at the operating point

**Date:** 2026-09-26
**Probe:** `.scratch/trpt_drag_balance.jl`. Read-only. No physics changes in the probe.
**Proposal it serves:** `docs/plans/2026-09-26-trpt-drag-torque-fix.md`, test T3.

## Provenance (the five required items)

| Item | Value |
|---|---|
| git hash | 24b3a93 (the drag-torque fix is in the tree; the drag torque is a property of the state, so the number holds either side of the fix) |
| seed | the live campaign seed: 5 kW, 18.8 m, 13 rings, 6 lines, taper 0.575 m to 2.4 m, tether 3.651 mm |
| wind | the settle-case wind, from `build_case(nothing, nothing)` |
| drag coefficient | tether 1.0, tube 1.2 |
| spin rate | 13.452 rad/s, uniform, spread 0.00e+00 |
| settle horizon | `n_op = 150_000` steps, 6 s simulated |

## Result

| Quantity | Value |
|---|---|
| tip speed at the 2.4 m ring | 32.3 m/s |
| rotor torque | +290.663 N·m |
| **tether drag torque** | **−21.903 N·m** |
| drag power | −0.295 kW |
| drag as a fraction of the rotor torque | 7.5 % |

Per-ring split, ground to top, in N·m. Rings 1 to 8 sit at 0.575 m and give 0.05 to 0.05
each. Ring 9 gives 0.27. Ring 10 at 1.175 m gives 4.31. Rings 11 and 12 at 2.4 m give
13.61 and 7.36. The topmost ring reads +4.08.

The loss sits in the large-radius sections, which is what the source says.

## Two independent checks on the number

**The scaling law.** A section's drag torque scales with the radius cubed and with the
section length. Drag force scales with tip speed squared and with length. The moment arm
scales with radius. So the torque scales with radius cubed times length.

Between a 0.575 m bay (0.886 m long) and a 2.4 m bay (3.6 m long) the ratio is 295. The
measurement gives 272 between rings 10 and 12. The measured quantity carries the drag
signature, not some other torque.

**The printed anchor, scaled.** The source gives 4.9 N·m at coefficient 1.2 for TRPT#4: a
10.31 m TRPT with a 1.52 m hub. At coefficient 1.0 that is 4.1 N·m. Scale it by radius
cubed, 2.4 over 1.52, and by length, 18.8 over 10.31. That gives 29.4 N·m for our seed.

We measure 21.9 N·m, which is 25 percent low. Finding F11 predicts exactly this. The
ring-end sub-segments use the ring centre velocity, so they run at half speed and their
drag is a quarter of its value. The same finding predicts 29 to 35 N·m once that is
fixed. So the measurement and the anchor agree inside the known defect.

## What this settles

- **The steady-state bound holds.** The drag torque is 7.5 percent of the rotor torque,
  far below it.
- **The review claim of 3.6 kW is refuted.** The measured drag power is 0.295 kW, twelve
  times smaller. An earlier estimate of ours, 306 N·m, is also refuted.
- **The drag torque is real and modest.** It will move the operating point when the fix
  applies it, and the move will be small.

## Method limits, stated

The probe isolates the drag by calling the rope kernel twice on the same state: once as it
is, and once with every node translational velocity zeroed. The elastic tension term
depends on positions only, so it cancels. The rope damping term does not, so a little of
it rides along in the difference.

The still call is not small. It reads 415.8 N·m, which is the transmitted torque of the
settled state. So the drag torque is the difference between two large numbers, and a few
percent of noise would be a few N·m. The two checks above say the result is sound. Even
so, the promoted acceptance test must measure the drag moment directly, per sub-segment at
the ring attachment radius, and avoid the cancellation.

## Next

1. Promote the probe into `test/acceptance_runtests.jl` with the direct per-sub-segment
   measurement, the bound as an assertion, and this number as the recorded baseline.
2. Finding F11 needs its own proposal. Its acceptance test is the anchor comparison:
   after it, the drag torque should read 29 to 35 N·m at this operating point.
