# Proposal: the ring-end drag uses the attachment velocity

**Date:** 2026-09-26
**Status:** Proposed. Awaiting Rod. No code changed.
**Finding behind it:** F11 of `docs/validation/trpt-reference/03-repo-findings.md`.
**Place in the order:** after the drag torque fix (Ruling 4, committed `13a676a`), with the
tether drag coefficient setting (Ruling 3).

## Terms

| Term | Meaning |
|---|---|
| ring | A stiffening ring of the TRPT. The lines attach to its rim. |
| sub-segment | One of the twelve pieces the model divides a line into. |
| attachment point | The point on a ring rim where a line meets it. |
| attachment velocity | The speed of that point. It has the ring orbital speed, which is the spin rate times the radius. |
| ring centre velocity | The speed of the ring centre. The repo holds it at zero. |
| moment arm | The perpendicular distance from the shaft axis to the force. |
| drag torque | The moment of the drag force about the shaft axis. |
| shaft | The rotating axis that carries torque from the rotors to the ground ring. |

## 1. The defect

The rope kernel reads the velocity of each node from the state. For a node on a ring, the
state holds the velocity of the ring centre. The repo convention holds those velocities at
zero. See `test/test_settle_validity.jl:165-169`.

The centre of a spinning ring can indeed stand still. The rim cannot. Every attachment
point sweeps the air at the orbital speed, which is the spin rate times the radius. On the
2.4 m rings of the live seed, at 13.45 rad/s, that is 32 m/s.

The kernel never adds that term. The tube drag does add it. See `src/dynamics.jl:125`,
which uses the full rotational velocity of the ring, then projects it against the beam
axis.

So the sub-segments at a ring end read a fraction of their true drag. The record says about
a quarter of it.

## 2. The evidence

Two independent numbers point the same way.

1. The scaled printed anchor. The source measures 4.9 N·m on TRPT#4. Scaled to the live
   seed, that is 29.4 N·m. The model reads 21.9 N·m with the older probe and 22.8 N·m with
   the promoted test. The model sits about 25 percent low.
2. The radial distribution. Rings 10 to 12 hold 113 percent of the net drag. Those are the
   2.4 m rings, where the missing orbital term is largest.

A 25 percent shortfall is exactly what a missing fraction of the end drag looks like.

## 3. The fix

Add the orbital term to the velocity of a node that sits on a ring.

    v_attachment = v_centre + omega_ring * r_attachment

Two details make this cheap.

- The kernel already computes the moment arm for each end, at `src/rope_forces.jl:455`.
  The moment arm and the orbital term use the same vector.
- The kernel already receives the state. The ring spin rate is in it, in the omega block,
  at `u[6N + Nr + ri]`. No signature change is needed.

## 3a. The concrete shape, read from the code on 2026-09-26

1. `va` and `vb` are VIEWS into the state, at `src/rope_forces.jl:394-395`. They hold the
   ring centre velocity, which the repo holds at zero. They cannot be written to.
2. Preallocate two 3-vectors beside the existing scratch, `va_eff` and `vb_eff`. Fill each
   one with `v_centre + omega_ri * cross(shaft_dir, r_end)`.
3. `r_end` is `p_end - centre`. The code already forms it at lines 455 and 486, but the drag
   block reads the end velocities at about line 423, BEFORE those moment arms exist. The
   offset must therefore be formed earlier.
4. Point the drag's `v_mid` at the two effective vectors instead of at the views.
5. Leave the moment-arm block alone. It already uses the attachment vector.

The order matters. Form the offsets before the drag block, then reuse them for the moment
arms, so the two stay consistent by construction. The ground ring has no spin, so its term
vanishes and the ground attachment cannot be disturbed.

## 4. The sites

- `src/rope_forces.jl:394-395` builds the end node velocities. This is the fix site.
- `src/initialization.jl:971` computes the screen drag power from the same velocities. It
  needs the same correction, or the screen and the ODE disagree again.
- `src/objective_v6.jl` computes its own segment drag. Check it in the same pass.

## 5. Tests, written first

T1. A unit test with a ring at rest and a spin rate on the ring. The end sub-segment drag
moment must reflect the orbital speed, not the centre speed.

T2. The whole-seed measurement. The drag torque must move from 22.77 N·m into the 29 to
35 N·m band. The promoted acceptance test already spans that band, so it stays green. This
is the point of the bracket in check D3.

T3. Check D1 and D2 of `test/test_trpt_drag_torque_balance.jl` still hold. The drag must
still oppose the rotation, and it must still stay below the rotor torque.

## 6. What the fix changes, and the one re-baseline

The drag torque rises by roughly a third. The steady spin therefore falls a little more.

**The R3 band is already re-baselined for this fix.** On 2026-09-26 the drag torque fix
moved the seed from 14.09 rad/s to 13.97 rad/s, so the band moved to 12.7 to 15.2. That
floor covers the predicted shift of this fix, which is a few tenths more. No second change
is needed. Tighten the band once this fix lands.

## 7. Risks

- The drag torque grows, so the rotor torque bound comes closer. The measured 7.8 percent
  leaves a wide margin. The fix should take it to about 10 percent.
- The same quarter-drag error may sit in the objective and in the screen. Section 4 lists
  both. Leave one of them uncorrected, and the screens and the ODE disagree again.
- A ring spin rate of zero removes the term. The ground ring has no spin, so the fix must
  not disturb the ground ring attachment.

## 8. What must not change

- The tether drag form. A tether is a cylinder in cross-flow.
- The ring beam projection in the ODE. `src/dynamics.jl:136-138` is correct.
- The printed anchors. They stay as the oracle in the reference library.
