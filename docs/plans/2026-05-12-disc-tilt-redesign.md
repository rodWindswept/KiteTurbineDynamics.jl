# Disc-tilt redesign — visible rotor pitch + TRPT propagation

**Status:** ON HOLD. DO NOT EXECUTE THIS PLAN WITHOUT Rod giving explicit approval. Tilt physics is currently disabled (2026-05-11).
**Owner:** Rod
**Predecessor handover:** `docs/plans/2026-05-10-handover.md`

## Goal

The simulator must show the rotor disc pitching during furl (and in response to
asymmetric load) and propagate that pitch down the TRPT — visibly, in the
dashboard, and consistently with the physics. This is essential for explaining
power spill, for partner conversations about furl behaviour, and for spotting
torsional collapse precursors that present as rotor-plane wobble.

## Why tilt is disabled right now

Phase-2b tried "TRPT sub-segments use a tilted ring-plane basis; bridles use
the shaft basis" (`commit 5e59ef6`, refined through `8f95b27`). The handover
on 2026-05-10 documented three live symptoms that did not go away with mass,
damping, or pre-settle tweaks:

1. Bridle gold lines visibly uneven, with pulsed shaking at the top in
   rotation.
2. Frame-1 snap toward the generator.
3. Bearing launching downwind ~4 s into a 20 s furl.

Diagnosis on 2026-05-11 traced (1) and (3) primarily to a basis split. With
the tilted/shaft hybrid in `src/rope_forces.jl`, the same hub `RingNode` —
same `α`, same `R` — presented one set of vertex positions to the upper TRPT
sub-segment and a *different* rotated set to the bridles. Force/torque on the
hub centre summed over two non-coincident point sets, and the dashboard
(`src/visualization.jl:_perp_fn` shaft / `_rope_line_pts`→`_tilted_ring_basis`
tilted) rendered the same split, so the gold bridles and TRPT lines drifted
against each other every step.

(2) had a separate root cause: the settle stage ran in still air, so frame 1
saw a step-input of wind + lift on a zero-velocity bearing. Fixed 2026-05-11
by passing `wind_fn` through `settle_to_operational_state` →
`settle_to_equilibrium`, plus switching the torque-chain bisection to use the
settled hub direction rather than the design `[cos β, 0, sin β]`.

The earlier feedback-loop attempts (`458333`, `ea088c3`) blew up in 77 steps
because tilt → bridle geometry → bridle force → ring centre offset → tilt
formed a positive-gain loop. `8f95b27` cut that loop by making tilt one-way
(bearing → tilt → TRPT only), which is what introduced the basis split this
plan needs to undo.

## Constraints any redesign must satisfy

- **One basis per ring per step.** TRPT, bridles, hub polygon render, and
  intermediate ring render all reference the same in-plane vertex positions
  for a given `α`. No "TRPT sees one ring, bridles see another."
- **No tilt → bridle → tilt feedback.** Either the bridle geometry is
  invariant under tilt (so its force vector cannot drive tilt back), or the
  loop is opened with a real low-pass filter sized below the lowest mechanical
  mode that physics is allowed to resolve.
- **Tilt visible in dashboard.** The hub ring polygon, the TRPT lines into
  it, and (ideally) the bridles must visibly pitch when the rotor pitches —
  not just the tether geometry inside the rope segments.
- **No double-counting of bearing tension.** The bridle network already
  distributes bearing pull to the hub vertices. A tilt model that *also*
  applies bearing offset as a hub-centre lateral force is double-counting.

## Approach options

### Option A — Bridles in the tilted basis, with explicit pitch dynamics

Move both TRPT and bridle attachment computation into the tilted basis. The
hub ring becomes a single rigid body with three rotational DOF (`α` plus a
2-axis pitch). Pitch is integrated with its own inertia and damping, driven by
the net non-shaft moment from the bridle + TRPT tension network. No feedback
filter needed because pitch has real inertia.

- Pro: physically consistent, stable, single basis everywhere.
- Pro: tilt is genuinely *emergent* from the tension network, not a
  bearing-offset proxy.
- Con: adds 2 DOF per ring (or just the hub) to the ODE state — needs
  inertia-tensor numbers, pitch damping calibration, and probably a
  rebalanced explicit-Euler `dt`.
- Con: settle stage needs to drive the new pitch DOF to equilibrium; the
  torque-chain bisection in `settle_to_operational_state` would have to
  iterate over (`α`, pitch_x, pitch_y) per ring instead of just `α`.

### Option B — Quasi-static tilt from bridle-tension network, single basis

Compute the hub disc orientation each step from the bridle force imbalance
projected onto the perpendicular-to-shaft plane (essentially what `ea088c3`
attempted), but apply that orientation to **both** TRPT and bridle attachment
positions — no split. Open the feedback loop with a low-pass filter on the
tilt orientation (already provisioned in `src/types.jl:88` —
`TILT_SMOOTH = 0.995`). Filter time constant must be slower than the bridle
ring-down time (~50 ms with current damping).

- Pro: no new DOF; the existing single-basis architecture stays.
- Pro: tilt is responsive but smoothed, so the loop can't resonate.
- Con: filter is a tuning knob with stability implications; needs sweep.
- Con: the bridle-as-tilt-driver path is genuinely a feedback path — a
  low-pass filter buys margin but does not remove the eigenmode. If we
  push damping or `TILT_SMOOTH` wrong, it returns.

### Option C — Geometric tilt from bearing offset, single basis

Keep the Phase-2b "tilt comes from bearing offset perpendicular to shaft"
formula (it is one-way and stable). But apply the resulting tilted basis to
**both** TRPT and bridles — same ring, one basis. The bridle force vector
then changes when tilt changes, which closes a feedback loop *through the
bearing position*: tilt rotates bridle attachment points → bridle force vector
rotates → bearing acceleration changes → bearing offset changes → tilt changes.
This is the loop `8f95b27` was avoiding.

- Pro: single basis, minimal code change from current state.
- Con: re-opens exactly the loop we cut. Needs the same filter treatment as
  Option B, plus careful bearing-mass / bridle-damping sizing to keep the
  loop sub-critical.

### Recommendation

**Option A** is the right destination. It removes the conceptual hack
("bearing offset proxies for disc pitch") and gives a real rotational DOF
that we will need anyway for cyclic-pitch and gust-response work in v6.
Option B is a safe interim if Option A is too large a change to ship before
the next partner demo.

## Plan

### Phase 1 — interim (Option B), ~1 day

1. `src/dynamics.jl`: replace the disabled tilt stub with a tilt
   computation derived from the per-ring net non-shaft torque accumulated
   in `compute_rope_forces!` (already projected against `shaft_dir`; the
   perpendicular component is what we want).
2. `src/types.jl`: confirm `DISC_TILT_COMPLIANCE = 2.5e-7` and
   `TILT_SMOOTH = 0.995` are good for current bridle damping. If
   `BRIDLE_C_DAMP=500 N·s/m` (init.jl:137) gives ~50 ms ring-down, set
   `TILT_SMOOTH` for τ_filter ≥ 200 ms (≥ 4× the loop time).
3. `src/rope_forces.jl`: drop the `is_bridle` split. Both branches use the
   tilted basis from `sys.ring_tilt_axis`.
4. `src/geometry.jl:_tilted_ring_basis`: stays as-is (already reads
   `ring_tilt_axis` with shaft fallback).
5. `src/visualization.jl`: `_perp_fn` switches from
   `shaft_perp_basis(normalize(hub_pos))` to `_tilted_ring_basis(...)`. Then
   bridles, hub polygon, intermediate rings all render in the same tilted
   frame as TRPT.
6. Smoke test: 20 s furl scenario at `v=11 m/s`. Expect visible rotor pitch
   ~5–15° during furl, no bearing run-away, no >2× tension excursions vs
   pre-tilt baseline.
7. Sweep `TILT_SMOOTH ∈ {0.99, 0.995, 0.998}` and
   `DISC_TILT_COMPLIANCE ∈ {1e-7, 2.5e-7, 5e-7}` to confirm operating point
   has > 6 dB stability margin (no oscillation when stepping payout).

### Phase 2 — full pitch DOF (Option A), ~1 week

1. `src/types.jl`: extend `RingNode` (or just the hub) with two pitch DOF
   (`pitch_x`, `pitch_y`) and matching inertia. Update `state_size`.
2. `src/dynamics.jl`: integrate pitch under net non-shaft moment from
   `compute_rope_forces!`. Apply pitch damping sized to ζ ≈ 0.7.
3. `src/rope_forces.jl`: use a single tilted basis derived from the
   integrated pitch state. Bridles included.
4. `src/initialization.jl:settle_to_operational_state`: extend the
   torque-chain bisection from 1-D (`α`) to 3-D (`α`, `pitch_x`, `pitch_y`)
   per ring. Or solve `α` first, then settle pitch with a damped sub-loop.
5. `src/visualization.jl`: use the integrated pitch state for `_perp_fn`
   and `_tilted_ring_basis`. Add a HUD readout for hub pitch angle (deg).
6. Tests: extend `tests/test_dynamics.jl` with a static-asymmetric-load
   case that pitches the hub to a known angle within 5 % of the analytic
   moment-balance prediction.
7. Validation: re-run the v5 furl scenario; compare rotor pitch trace and
   power-spill curve against the geometric-only baseline. Pitch and spill
   should agree within ~10 % at steady state.

## Out of scope for both phases

- Cyclic pitch control input (deferred to v6, per `CONTEXT.md`).
- Per-ring pitch (intermediate rings stay flat to the local tether
  geometry — only hub pitch is integrated).
- Aero-coupled pitch moment from blade thrust asymmetry (separate item;
  needs strip-theory upgrade in `src/aerodynamics.jl`).

## Validation criteria for either approach

A redesign is successful when, in the dashboard:

- Bridle gold lines stay visibly even at all rotation angles in steady state.
- Hub ring polygon and TRPT line endpoints share the same vertices at every
  frame (no drift between renders).
- A 20 s furl scenario shows monotonic rotor pitch rise, monotonic power
  decay, and no bearing run-away.
- Tension peaks during furl stay within 1.5× the pre-furl steady-state
  peaks.
- All 376 existing tests pass; new pitch-balance test passes.

## Files touched per phase

| Phase | File | Change |
|-------|------|--------|
| 1 | src/dynamics.jl | Replace stub with quasi-static tilt + LP filter |
| 1 | src/rope_forces.jl | Drop is_bridle basis split |
| 1 | src/visualization.jl | `_perp_fn` → `_tilted_ring_basis` |
| 1 | src/types.jl | Tune `DISC_TILT_COMPLIANCE`, `TILT_SMOOTH` |
| 2 | src/types.jl | Add pitch DOF to hub RingNode |
| 2 | src/dynamics.jl | Integrate pitch DOF |
| 2 | src/rope_forces.jl | Single basis from integrated pitch |
| 2 | src/initialization.jl | Extend bisection to (α, pitch) |
| 2 | src/visualization.jl | Render integrated pitch |
| 2 | tests/test_dynamics.jl | Static-asymmetric-load pitch test |
