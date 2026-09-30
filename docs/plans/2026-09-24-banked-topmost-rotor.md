# Banked topmost expansion rotor: work plan

Date: 2026-09-24. **Status 2026-09-30: built, measured, and REVERTED. The
implementation brakes the machine.** B1-B4 and B7 were built in the working tree.
They were then reverted, and `src/` and `test/` are now byte-identical to HEAD
`1b4d9be`, because B4's second half fails. Section 7 predicted this fault. Section 6
named the measurement that would catch it. That measurement was owed and never ran,
so the acceptance gate caught it instead. Measurements:
`docs/plans/2026-09-30-top-ring-brake-findings.md`. B5 stays deferred behind the
Phase 5 sizing remediation (`docs/plans/2026-09-24-phase5-multirotor-sizing.md`).

## Where the code stands — verified 2026-09-30

| task | state |
|---|---|
| B1 pin, then invert | REVERTED. `test/test_banked_top_rotor.jl` stays in the tree, unregistered |
| B2 owner model | REVERTED. `top_ring_expansion` and `has_top_expansion` are gone |
| B3 weigh it once | REVERTED |
| B4 model it once | **FAILS**. See §11. The gated disc branch plus the deleted hub guard cost 5.46 kW down to 3.43 kW, then to 0.80 kW |
| B5 size it once | DEFERRED behind Phase 5 (see §8) |
| B6 connect it once | REVERTED |
| B7 retire the guards, leave an invariant | REVERTED. The three guards stand, and the measurement says they are correct |
| B8 acceptance | **GREEN at HEAD, 9 of 9, EXIT=0**. The whole suite ran on 2026-09-30 |
| B9 record it | DONE 2026-09-30. `physics-topology.md` §4 carries the brake finding, and the findings note holds the numbers |

**The three guards stand.** The 2026-09-30 measurement confirms them, so none is retired
(see §11). The third, `builders_util.jl` inside `build_phantom_triangle`, is a
**deliberate faithful rebuild of the pre-fix system** (see that function's own header)
and must KEEP the hub exclusion. It is not a guard to retire. Do not "fix" it: its
output is pinned bit-identical to the phantom that all the Strathclyde-shared results
describe.

Rod's ruling of 2026-09-24: a banked blade rotor on the TOP ring must be legal,
and the code must account, connect and size it exactly once. This plan retires the
top-ring exclusion and replaces it with a stated rule. **The ruling stands. The
implementation is blocked by measurement.**

## 1. Goal

A genome whose topmost rotor carries banked blades must build, run, and score.
The top rotor must be modelled once, weighed once, sized once, and connected once.
Today the optimiser cannot express that machine at all.

## 2. Why the exclusion exists

On 2026-08-22 the code refused to let the topmost rotor carry banked blades. One
bug modelled the same annulus twice: once as a `cp`/`ct` disc at
`src/ring_forces.jl:193-232`, and once as an expansion rotor. At high solidity the
expansion induction term became a brake. The 5 kW seed ran away to
omega = -0.6 rad/s. The recorded repair was to exclude the top rotor from the
expansion list.

The repair was a guard, not a model. It removed a legal design from the search
space. It also hid the real question, which is which model owns the annulus.

## 3. The rule to implement

When the topmost rotor carries banked blades, the banked (expansion) model
REPLACES the disc model at that ring. Never both. Never neither.

That single sentence is the invariant. Every task below serves it.

## 4. The sites, measured on 2026-09-24

| # | site | what it does today | what it must do |
|---|---|---|---|
| 1 | `src/builders_util.jl:91` and `:297` | `rotor.ring_idx == n_rings && continue`, twice, with no message. Drops the top rotor from `expansion_params_from_rotors` | Map the top rotor when it carries banked blades. Mark it as the ring's owner model |
| 2 | `src/ring_forces.jl:261` | `er.ring_idx == hub_ri && continue`. A third silent skip, defending the same annulus | Arbitrate between the two models. Skip the DISC model when the banked model owns the ring |
| 3 | `src/ring_forces.jl:193-232` | The disc model. Thrust from `main_rotor_swept_area` and `ct_at_tsr` at `:201`. Torque from `cp_at_tsr`. The reverse branch uses `chord = 0.113 · sys.rotor.radius` at `:226` and `R_eff = 0.70 · R_o` | Run only when the disc model owns the top ring |
| 4 | `src/initialization.jl:217-231` | The top ring node takes `mass = m_rotor` at `:228` and `inertia_z = m_rotor · rotor_radius^2` at `:217`. The expansion loop at `:225` then adds `er.mass` and `expansion_rotor_inertia` to the SAME node when `er.ring_idx == s + 1` | Charge one rotor per ring. A banked top rotor must not be charged twice |
| 5 | `src/expansion_analysis.jl:62,68` | `m_blades = p.n_blades · p.m_blade` plus `m_expansion = Σ er.mass`. `n_blade_nodes = p.n_blades + Σ er.n_blades` | Count the top rotor once in the airborne-mass budget and in the knuckle count |
| 6 | `src/objective_v10.jl:369,372` | The top rotor span solves from the disc radius, and the chord follows it at `:372`. Phase 5 task T4 replaces both | One sizing owner per rotor. A banked rotor sizes from the banked law, not from the disc Cp |

Site 4 is the one that already fires in the harmless direction. The loop at
`src/initialization.jl:225` tests `er.ring_idx == s + 1`, and the top ring index
is `n_seg + 1`. So a banked top rotor WOULD land on the top ring node, and that
node already carries the disc rotor's mass and inertia. The accounting would
double without any error message.

There are three silent guards in total, not two: `builders_util.jl:91`,
`builders_util.jl:297`, and `ring_forces.jl:261`.

## 5. What "once" means

Three accounts must each close, and each needs its own test.

**Sized once.** One annulus, one owner model. The banked model or the disc model.
The rotor's span, chord and blade count come from one source.

**Accounted once.** One blade mass, one rotary inertia, one knuckle set per ring.
The airborne-mass budget must equal the sum of the per-ring values.

**Connected once.** One torque path to the shaft and the twist, one thrust path
to the ring node, one wind factor. No ring may carry two rotor torque paths.

## 6. Tasks

Order is dependency order. Each task starts with a failing test.

**B1. Pin today's behaviour, then invert it.**
Write `test/test_banked_top_rotor.jl`. Decode a genome whose top rotor carries
banked blades. Assert the present outcome first: the top rotor appears in
`sys.expansion_rotors` zero times, and the top ring node weighs the disc rotor
only. Then invert the assertion to the ruled behaviour.
Verify: `scripts/ktd-test-one test_banked_top_rotor`.

**B2. Assign the owner model.**
Add one function that answers a single question: does the banked model own the top
ring. Call it from all three guards. Delete the three guards and replace them with
that arbitration.
Test: for a banked top rotor, `expansion_params_from_rotors` returns the top rotor,
and `ring_forces` skips the disc branch at that ring. For a plain top rotor,
nothing changes.
Verify: `scripts/ktd-test-one test_expansion_rotor` and
`scripts/ktd-test-one test_banked_top_rotor`.

**B3. Weigh it once.**
Fix site 4 and site 5 together, in one commit, because they are the same account.
The top ring node takes the banked assembly mass and inertia INSTEAD of the disc
rotor values. `expansion_airborne_mass` and the knuckle count include the top
rotor once.
Test: the top ring node mass and inertia equal the single-rotor values, not the
sum. The airborne-mass budget equals the sum of the per-ring values.
Verify: `scripts/ktd-test-one test_physics_inertia_mass`,
`scripts/ktd-test-one test_mass_model_2026_09`, and
`scripts/ktd-test-one test_blade_mass_law`.

**B4. Model it once, aerodynamically.**
Route the top rotor through `expansion_rotor_forces` and skip the disc branch. The
alpha/induction model must not brake the machine. This is the fault that created
the rule, so measure it directly.
Test: the banked top rotor produces a positive net torque at the design point. The
machine reaches at least 80 per cent of its plain-rotor omega with the same
genome.
Verify: `scripts/ktd-test-one test_expansion_induction` and
`scripts/ktd-test-one test_banked_top_rotor`.

**B5. Size it once.**
Give the banked top rotor a sizing law. State which model sets its span, its chord
and its blade count. Reuse the Phase 5 span law where the banked model needs an
annulus, and the Phase 5 chord law (`c = 0.2702 · span`) everywhere.
Test: the decoded span, chord and blade count each come from one stated source.
Assert the ring's annulus area against the demanded area.
Verify: `scripts/ktd-test-one test_builders_v10` and
`scripts/ktd-test-one test_bem_unified`.

**B6. Connect it once.**
Check the torque path, the thrust path and the wind factor. The ring node must
receive the banked rotor's net torque, and the multi-rotor de-rate rule must still
reach the top rotor.
Test: the torque applied at the top ring equals the banked rotor's net torque. The
top rotor's wind factor matches the rule from the Phase 5 work.
Verify: `scripts/ktd-test-one test_wind_blocking` and
`scripts/ktd-test-one test_banked_top_rotor`.

**B7. Retire the guards and leave an invariant.**
Delete the three silent no-ops. Add one topology assertion that RAISES on a double
model, in the style of `trpt_matched_place`. A silent skip is the defect class of
`docs/agents/physics-topology.md` section 6.
Test: a hand-built double model raises, and names the ring.

**B8. Acceptance.**
Run the eight slow tests in `test/acceptance_runtests.jl`. Then add one acceptance
case with a banked top rotor, and record the outcome.
Gate: the machine spins up, holds tension, and reaches rated power.

**B9. Record it.**
Update `docs/agents/physics-topology.md` section 4, `DECISIONS.md`, and the trust
log. State the rule, the three accounts, and the measured before-and-after.

## 7. Risks

- **The induction brake.** The original fault. A banked rotor at high solidity can
  brake the stack. Test B4 measures this first, before any sizing work.
- **A silent double charge.** Site 4 charges twice with no message. Test B3 pins it.
- **Two sizing owners.** If the disc law sizes the span and the banked law sizes
  the chord, the rotor is inconsistent. Test B5 forbids it.
- **Scope creep into Phase 5.** This plan must not change the disc-path sizing for
  plain rotors. Test B2 asserts no change there.

## 8. Order and dependency

Blocked by the Phase 5 re-baseline. Reason: Phase 5 changes the span law, the
chord law, the power share and the wind reference. Landing this plan first would
re-baseline twice, and the banked sizing law depends on the Phase 5 span law.

Suggested start: after T7 of the Phase 5 plan reports a green suite.

## 9. Open questions for Rod

1. Is the top rotor's bank angle a separate gene, or must it match the other
   rotors? The record holds one bank angle per expansion rotor today.
2. Does a banked top rotor keep a disc thrust path for the tether tension estimate
   at `src/ring_forces.jl:279`? The banked model makes its own thrust.
3. Which model owns the top rotor's claim on `main_rotor_swept_area`? The lifter
   sizing and the tension estimate both read it.
4. May the top rotor and an intermediate rotor both carry banked blades, or is the
   rule one banked rotor only?

## 10. Definition of done

1. A genome with a banked top rotor decodes, builds, settles and scores.
2. The three accounts close, each with a test.
3. The three silent guards are gone, replaced by a raising invariant.
4. The suite in `test/runtests.jl` is green, and the acceptance suite is green.
5. The record states the rule and the measured numbers.

## 11. Measured 2026-09-30: the brake is real

The implementation was built and measured. It brakes the machine. The full numbers are
in `docs/plans/2026-09-30-top-ring-brake-findings.md`.

The gate `test/test_gate_v13.jl` A1 gates the winner
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/best_vector.csv`. That winner
carries `bank_top = 19.95°` and `bank_bottom = 6.69°`. It is one rotor on ring 6 of 6,
the topmost ring.

| configuration | P_gen_final | w_gnd_final |
|---|---|---|
| HEAD `1b4d9be`, the disc model owns the ring | 5.46 kW | 13.46 rad/s |
| the implementation, hub guard deleted | 3.43 kW | 11.53 rad/s |
| the implementation, disc branch also gated off | 0.80 kW | 7.1 rad/s |
| expectation for a 20° misalignment, `cos^3(19.95) = 0.8306` | 4.54 kW | no run |

B4 asks for at least 80 per cent of the plain-rotor omega. The machine delivers 53 per
cent, and then 53 per cent of that. B4 fails.

Two defects sit in the work, not one. The deleted hub guard alone costs 37 per cent of
the power while the disc model still runs. That is the induction brake of §7. Gating
the disc branch as well removes the rotor's drive entirely.

The expectation says a 20° bank must cost a few tens of per cent of the power. It
cannot cost 86 per cent. The implementation does not measure the machine. It brakes
it, exactly as the 2026-08-22 record says it does.

**B4's second half was the guard, and it was deferred.** Section 7 named the brake as
the first risk. Section 6 asked B4 to measure it before any sizing work. The half that
measures it was marked owed. Keep that half in `test/acceptance_runtests.jl` before any
rebuild of this work, so the next attempt meets the assertion rather than the
acceptance gate.
