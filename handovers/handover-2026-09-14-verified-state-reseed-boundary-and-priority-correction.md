# Handover: the verified state, the re-seed boundary, and a priority correction (2026-09-14)

**Written by:** the agent session that ran on the working tree left by the
2026-09-13 session.

**Status of the tree:** dirty and **uncommitted**, exactly as the 2026-09-13
session left it, plus the changes of this session. `HEAD` is `86217d7`, 29 commits
ahead of `origin/master`, nothing pushed (a standing choice by Rod). No commit was
made by this session.

**One-paragraph summary.** This session set out to diagnose one failing test,
found the failing test did not exist, and instead found and fixed two real code
defects: a silently-clamped torsional limit and a hardcoded number standing in
for the operating speed of another design. It then built a permanent test guard for
both, restated a guard assertion to the ruling by Rod, and in doing so took the fast
test suite from a non-zero exit to a clean zero exit. That clean exit is what
blocked the commit. It then went looking for a replacement campaign seed, found a
viable one, and could not land it, because putting it in disconnects the lift chain.
Finally it re-read the priority list of the 2026-09-12 handover and discovered it
was busy with the **last** item on that list while the **first two** remain
undone. The seed hunt should stop. The honest position is recorded below,
including three wrong conclusions this session reached and then corrected.

---

## 1. How to run things here

Unchanged from the 2026-09-13 handover, and restated because it is easy to get
wrong:

```bash
scripts/ktd-julia test/runtests.jl              # fast suite, ~4 min
scripts/ktd-julia test/acceptance_runtests.jl   # acceptance, 8 files, ~18 min
scripts/ktd-julia scratch/<probe>.jl            # any probe
scripts/ktd-format
```

Plain `julia --project=.` fails in this sandbox (it needs the stacked package
depot, so see `CLAUDE.md`). `/tmp` does not persist between shell calls, so write
logs to `.julia_depot/logs/`.

**A new instrument fault, found and verified this session.** The command
`CLAUDE.md` recommends for live suite output,

```bash
script -q -c "scripts/ktd-julia test/runtests.jl" /dev/null
```

**always returns exit code 0, even when the suite fails.** This was verified in
isolation: `script -q -c "exit 3" /dev/null; echo $?` prints `0`, while
`bash -c 'exit 3'` prints `3`. So a red suite looks green if you read the exit
code. Read the `Test Summary` line or the `ERROR: LoadError: Some tests did not
pass` line in the log instead. This is recorded in
`docs/agents/instrument-trust-log.md`. However, `CLAUDE.md` itself still
recommends the masking form and has **not** been corrected.

---

## 2. Test suite state: the headline

| suite | before this session | after this session |
|---|---|---|
| fast unit suite | 2086 pass, 0 fail, **2 errored**, 3 broken | **2108 pass, 0 fail, 0 errored, 3 broken** |
| fast suite exit code | non-zero | **0 (verified by running without `script`)** |
| acceptance suite | 4 of 8 files failing | 4 of 8 files failing, **the same 4, on the same assertions** |

The fast suite reported "0 failed" while it exited non-zero, because two
assertions were marked "expected to fail" (`@test_broken`) and had started
passing. Julia counts that as an error, not a pass. Those two are now resolved
(see §4), which is what makes the tree committable.

The three assertions still marked "expected to fail" are genuinely still
failing, and they are the settle-is-not-an-equilibrium problem:

| assertion | file | measured | target |
|---|---|---|---|
| hub axial force residual | `test/test_settle_validity.jl` | 188.2 N | under 50 N |
| sky-anchor axial force residual | same | −82.6 N | under 50 N |
| largest node acceleration at the first frame | same | 12122 m/s² (about 1236 g) | under 10 g |

---

## 3. What the 2026-09-13 handover said, and what was actually true

The handover at `handovers/handover-2026-09-13-lift-chain-and-realisability.md`
reported the fast suite as red with two failures in
`test/test_settle_preload_consistency.jl`, and asked its reader (this session) to
diagnose the one at line 107.

**Neither failure existed.** Running the suite on the tree as found gave
2086 pass / 0 failed / 2 errored / 3 broken, and the two preload tests **passed**.
The figures in the handover came from an intermediate state of
`src/initialization.jl` that no longer existed in the tree. Specifically:

- The assertion at line 79 (`err < 0.15`) is in a loop over two designs. Measured
  errors on the tree as found: campaign seed **1.0e-6**, four-line/three-rotor
  **0.0229**.
- **Line 107 is not the four-line/three-rotor case.** It is the
  "known tilt limitation" test block, which calls the six-line/one-rotor design.
  Its measured error is **0.1315** against its 0.60 threshold. The figure of
  114.0 quoted in the handover does not reproduce on any design.

This matters beyond bookkeeping: the instruction in the handover was to spend a
session diagnosing a failure that was not there.

---

## 4. What was fixed this session, and how it was verified

### 4.1 The code silently clamped the torsional limit

**What the code did.** One function in `src/initialization.jl` decided where to
place each ring so the transmission lines hold the right tension and the right
twist. To do that it solved

```
sin(needed twist angle) = (torque to carry x line chord length) /
                          (number of lines x line tension x radius x radius)
```

A value above 1 has no solution. It means the segment physically cannot carry
that torque at that tension. The code wrote
`asin(clamp(value, -1, 1))`, so a value above 1 silently became exactly 90
degrees. That is the forbidden "silent truncation" pattern written down in
`docs/agents/physics-topology.md` section 6.

**What it caused.** Measured with `scratch/diag_twist_origin.jl`:

| design | segments over the limit | needed twist per segment | total wound up |
|---|---|---|---|
| four lines, three rotors | 1 to 4 | exactly 90° each | 360°, one full turn |
| six lines, one rotor | 1 to 12 | exactly 90° each | 1080°, three full turns |

The ring placement and the settled state came out **identical**
(`alpha placed == alpha settled` exactly), so the initialiser did this,
not the simulation relaxing afterwards. Every guard passed anyway, because the
line tensions are still self-consistent at whatever twist was chosen, and the
twist check in the test (`twist > 30 degrees`) is satisfied by 90.

**What was changed.** The change rebuilt the function as a public seam called
`trpt_matched_place` in `src/initialization.jl`. It now returns, for every
segment, the torque that segment must carry, the most it could carry, and the
ratio between them (named `demand`). A `demand` above 1 **raises an error**
naming the segment, the torque, the tension and the ceiling. There is one
opt-out argument, `raise_on_unrealisable=false`, used only by the test guard so
it can measure an over-limit design instead of merely observing the error.

**Verified:** the new guard `test/test_trpt_realisability.jl` (26 assertions)
reproduces, exactly, the independently measured table in the 2026-09-13
handover: the binding segment is number 4, its required twist ratio is 0.983, the angle is
79.4 degrees, and segments 7 and 8 carry 329.9 and 238.2 newton-metres.

### 4.2 A design constant stood in for the speed of another machine

**What the code did.** `src/initialization.jl` computed the rotor thrust at the
operating speed with the line:

```julia
omega = omega_eq > 0.0 ? omega_eq : 12.983466
```

The number `12.983466` is the **equilibrium speed of the campaign seed itself,
in radians per second**. So when a caller did not pass a speed, the function
silently substituted the speed of the seed. A speed of zero (a stationary rotor,
which is a legitimate physical state) could not be expressed at all.

**What it caused.** The test that checks the settled line tension against the
intended preload called that function without a speed. So it compared a state
settled at one speed against a preload computed at the speed of the seed. Measured
with `scratch/diag_preload_reference.jl`:

| design | settled speed | error against the test reference | error against its own speed |
|---|---|---|---|
| campaign seed | 12.983466 | 1.0e-6 | 1.0e-6 |
| four lines, three rotors | 13.3995 | 0.0229 | **0.0** |
| six lines, one rotor | 11.3988 | 0.1315 | **0.0** |

The seed agreed only because the substituted number *was* the speed of the seed.

**What was changed.** The fallback went away. The function now uses the speed
that the caller passes in, and `ct_at_tsr(0.0) == 0.0` makes a stationary rotor
mean zero thrust. The preload test now settles first and evaluates its reference
at the speed the settle actually used. Its threshold is now **0.001**, tightened
from 0.15 and 0.60, and it passes with large margin. The honest error is 0.0.

### 4.3 The design preload gained a realisability margin

Measured on the tree as found, several designs sat within about three percent of
the torsional limit, and three were past it:

| design | required twist ratio |
|---|---|
| the seed used by `test/test_physics_path_ode.jl` and `test/test_evaluator_v13.jl` | 1.0325 |
| the two-rotor seed in `test/test_jtheta_no_reversal.jl` | 1.0332 |
| the honest-gain seed in `test/test_settle_lowk_honest.jl` | 1.0366 |
| the campaign seed | 0.983 (only 1.7 percent clear) |

A shortfall that consistent across independent designs points at the preload
being systematically low, not at several unrelated bad designs. Two named
constants now control a floor enforcement in `design_axial_preload`:

- `TRPT_REALISABILITY_TENSION_MARGIN = 1.05`: the tension the preload must hold
  above the floor.
- `TRPT_REALISABILITY_MAX_PRELOAD_FACTOR = 1.5`: the largest factor the top
  tension may reach before the code refuses the design instead.

Measured effect (`scratch/diag_preload_enforcement.jl`): campaign seed raises its
top tension by 3.2 percent. The four-line/three-rotor design raises it by 28.6
percent. The six-line/one-rotor design raises it by 14.5 percent. The bound
matters: the code refuses a genome 35 times past the limit rather than silently
rescuing it with a 37-times preload.

### 4.4 The gate did not handle that error, but the evaluator did

`src/objective_evaluator.jl` lines 631 to 638 already wrap the settle in a
`try`/`catch` and turn a failure into a rejected design. `scripts/ode_gate_v13.jl`
did not, so the re-gate step of the campaign would have crashed on an unbeatable
winner instead of reporting it rejected. That file now catches the error and
returns the same rejected verdict (`ok=false`, empty trace).

### 4.5 This session restated the guard assertion to the ruling by Rod

`test/test_settle_validity.jl` asserted `bridle > 0.25 * lift_requirement`. The
2026-09-13 handover (section 7, item 2) records the ruling by Rod that this encodes a
superseded rule and must be **replaced, not deleted**: the lines that must stay
taut are the **lift line** (kite to sky anchor) and the **cyan line** (sky anchor
to lift bearing). The **bridle cone and the transmission lines may slack**.

The assertion now measures and checks those two lines. Measured on the current
seed: lift line **459.0 N**, cyan line **452.3 N**, bridle total 525.7 N
(recorded in the log, not asserted).

**One judgement call to confirm.** The back line is deliberately *not* asserted
taut. `docs/agents/physics-topology.md` section 3.2 and the 2026-09-13 handover
section 4 both state it is an **altitude limiter, not a load path**, and is slack
at the design point by design. Asserting it taut would re-introduce the modelling
error that made the preload in the plan look unachievable. If Rod meant it
literally, this is a one-line change.

This session promoted the bearing axial force residual assertion (−4.38 N against
a 50 N target) from "expected to fail" to a real assertion, since it now holds.

---

## 5. The commit-blocking question, answered

The fast suite previously exited non-zero **because two assertions were marked
"expected to fail" while passing**, not because anything was broken. With those
resolved, the suite reports **2108 passed, 0 failed, 0 errored, 3 broken** and
exits 0. Verified by running the wrapper directly (not through `script`, which
masks the code) and reading `TRUE_EXIT=0`.

---

## 6. The seed hunt, and why it must stop

### 6.1 What the record says about the seed

The 2026-09-12 handover
(`handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md`)
section 9 lists the open work **in priority order**:

1. **Finish the static solver.** Constrain the step to near-constant line length.
   "Then the settle becomes a real equilibrium solve and V2/V3/V6 should start
   passing. The guard will say so."
2. **Re-derive the load split** between the lift chain and the transmission. "The
   bridles carry **about 123 N, not the about 431 N** the preload formula assumes,
   so the `+ T_cyan` term is right in direction and wrong in magnitude."
3. A bearing damping decision.
4. Implement the banked main rotor.
5. **Re-derive loads, then `SIZING_FOS_MARGIN`, then the window, and only then the
   seed question.** It adds, in bold: *"Do not re-baseline the red acceptance
   tests. They pin a real safety signal."* And: *"Only after this can anyone say
   whether a new campaign seed is needed."*
6. Two unexplained items.
7. Test-suite hygiene.

**This session worked on item 5 while items 1 and 2 remain undone.** That is the
priority correction. The seed hunt was premature by the own ordering of the
record, and it measured its candidates against a configuration whose load split
has not been validated.

The same section 5 of that handover predicts the outcome this session measured:
"the corrected preload is *lower*, so the beams are under-sized and FoS should
move *up*." The viable candidate found this session measured a structural factor
of safety of **3.59 against a 2.5 target**, which is 44 percent over, and that is
what the prediction implies.

### 6.2 The viable candidate found, and then reverted

Searched with `scratch/spec_seed_candidate.jl`, three screening rounds through
the campaign evaluator, confirmed at the full 30-second window:

```
genome = [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]
```

Decoded: 6 lines, 3 rotors, 8 rings, topmost ring radius 2.6 m.

| check | result |
|---|---|
| evaluator verdict | ok |
| sustained power | 5.07 kW (5.04 kW mean) |
| structural factor of safety | 3.59 |
| twist past the crossing limit | no |
| line break | no |
| required twist ratio | 0.789 (comfortably inside the limit) |

It keeps the three-rotor/six-line arrangement Rod asked for, and it is
mid-range on nine of its ten genes. The tenth is the rotor count, which sits at
its upper bound of 3. That is unavoidable because the range is only 1 to 3, and 3
is the deliberate choice so that multi-rotor behaviour is exercised.

**Bank angle was isolated and found incidental** (`scratch/spec_seed_candidate.jl`,
third round): 0, 11 and 22 degrees all give a viable machine: 5.01, 5.013 and
5.023 kW. The safety factors are 3.60, 3.59 and 3.54. The required twist ratios
are 0.795, 0.789 and 0.771. The viability comes from the 2.6 m radius and the 0.8
blade scale, not from banking. So the choice between 0 and 11 degrees is purely
about whether banked-blade expansion behaviour should be switched on, which is a
call for Rod and is not a trade-off.

**DECIDED 2026-09-14 (Rod): bank = 11 degrees.** His reasoning, recorded in his
own terms: the effect on the rest of the rotor and turbine behaviour should be
fairly minimal. The choice is only whether the blades fly an annulus exactly in
the plane of rotation, or whether their flown path is a truncated cone, which
slightly alters the thrust direction. So the bank angles of the candidate are
settled at 11 degrees and that question is closed.

### 6.3 Why it could not land

Putting that candidate in as the seed **disconnects the lift chain**. Measured in
`test/test_settle_validity.jl`:

| | current seed | candidate |
|---|---|---|
| bridle total tension | 525.7 N | **0.000 N** |
| lift requirement | 431.3 N | 607.0 N |
| sky-anchor axial force residual | −82.6 N | **+505.8 N** |

Traced with `scratch/diag_reseed_chain.jl` through each stage of the settle:

| stage | current seed | candidate |
|---|---|---|
| design split: cyan tension | 350.1 N | 493.3 N |
| design split: bridle tension | 67.8 N per line | 97.8 N per line |
| design bridle gap | 4.6562 m | 4.7624 m |
| bridle rest length cut to | 4.6556 m | 4.7614 m |
| **after the operational settle** | bridle 525.7 N, cyan 5.0045 m | **bridle 0.0 N, cyan 4.7675 m** |

Everything up to and including the placement is correct for the candidate: the
design split is healthy and the bridles are cut with the right preload strain.
The failure is in the operational settle, and the tell is the **cyan line: 4.7675
metres against its own rest length of 5.0 metres.** It is 0.23 m shorter than
slack. The lift bearing is in the right place (offset 3.9864 m against the design
3.99 m), so it is the **sky anchor that has dropped**, and the only thing holding
it up is the lift line.

This session **reverted** the seed change. `scripts/compute_seeds.jl` now differs from
`HEAD` by nine inserted comment lines only, which record the candidate and this
boundary where the next reader will look.

### 6.4 The lift-line switch was measured, and it is NOT the cause

An earlier draft of this section proposed the **hard on/off switch on the lift
line** as the cause: `src/ring_forces.jl` applies the lift force only while the
kite is at least 99 percent of the line length from the sky anchor, and applies
**zero** otherwise. That proposal is **falsified** by measurement, and the
measurement gives a better answer.

`settle_to_operational_state` takes its relaxation length as a parameter, so
calling it with growing values walks through the *same* settle with no
re-implementation and no physics change. Measured with
`scratch/diag_lift_line_switch.jl` (log `dsh_lift_line_switch.log`):

| relaxation steps | control: sky offset | control: bridle | candidate: sky offset | candidate: bridle |
|---|---|---|---|---|
| 0 | 8.99 | 406.9 N | 8.99 | 587.1 N |
| 500 | 8.993 | 428.1 N | 8.9941 | 612.9 N |
| 1000 | 8.99 | 443.4 N | 8.9882 | 646.1 N |
| 2000 | **8.9381** | **525.7 N** | **8.7352** | **0.0 N** |

In every row of both machines the kite-to-sky-anchor distance is about **8.99 m**
against a threshold of `0.99 x 25 m = 24.75 m`. So **the lift line is switched
off throughout the settle for both machines**, and the chain of the control is
nevertheless taut at 525.7 N. The lift line is therefore not what holds this
chain up, and the switch is not the cause of the failure of the candidate.

**What the measurement does show** is that the chain of the candidate is healthy and
*strengthening* up to 1000 relaxation steps (bridle 646 N), and then **collapses
between 1000 and 2000 steps**: the sky anchor drops 0.25 m and the bridle tension
goes to zero. The control also drifts at 2000 (8.99 to 8.9381) but holds.

So the failure of the candidate is a **late divergence in the relaxation**, not
an early drop-out. That is exactly the problem the 2026-09-12 handover names: the
settle *places* the machine and runs a short relaxation. It does not solve for
equilibrium. Record item 1 is therefore not merely the next task in principle.
It is the thing that blocks this re-seed, and this session reached it by
measurement rather than by argument. The seed must wait for it.

### 6.5 A re-seed is not blocked by the design constants (a wrong conclusion, corrected)

An earlier conclusion this session, that the lift-chain design constants are tied
to the old 2.4 m radius and must be re-derived for any new radius, is **wrong**.
This session corrected it by measurement in
`scratch/derive_lift_chain_constants.jl`, which settles each design naturally and
reads where the chain comes to rest:

| | current seed (r_hub 2.4 m) | candidate (r_hub 2.6 m) |
|---|---|---|
| settled lift-bearing offset | 3.9898 m | 3.9897 m |
| settled cyan length | 5.0027 m | 5.0037 m |
| bridle total tension after that settle | 315.9 N | 430.2 N |

The method reproduces the recorded 3.99 m for the current seed, so it is
trustworthy, and the two values agree to four decimal places. The reason is
physical: the lift bearing hangs one cyan-line length below the sky anchor, and
the lift chain sets the height of the sky anchor, so the **radius does not enter**.
Also note the chain of the candidate is **taut** (430.2 N) after that settle, and
it is healthier than the chain of the current seed.

So a new seed does not require re-deriving those constants. The real defect in
them is different, and it is the point that Rod raised. See §7.

---

## 7. The duplicated-constant problem Rod raised

The objection from Rod: a number that is only correct for one specific case,
written into the code, is exactly what the code standards warn against. We need
the design point specified in a **size-independent** way and validated as such.

**The measurement above agrees with the first half of that**: the numbers are not
in fact size-dependent. The problem is that they are **replicated**, and that
their provenance is a one-off hand measurement.

`BEARING_OFFSET_DESIGN = 3.99` and `CYAN_L0_DESIGN = 5.0` are referenced in
**15 places across 5 files**:

| file | how many | what for |
|---|---|---|
| `src/initialization.jl` | 10 | the constant definitions, the system builder, the design split, the ring placement, and two default arguments |
| `src/geometry.jl` | 1 | a design lift-bearing position for the ring-plane tilt |
| `src/ring_forces.jl` | 2 | the design length of the back line |
| `src/dynamics.jl` | 1 | a design lift-bearing position for the ring-plane tilt |
| `src/visualization.jl` | 1 | drawing (its comment says "5.0 must match initialization.jl") |

Two further problems of the same class:

- `src/initialization.jl` line 187 has a **bare literal** `CYAN_L0 = 5.0` in the
  system builder. It does not use the named constant at all. Change the constant
  and the builder silently keeps 5.0.
- `src/ring_forces.jl` lines 518 to 519 say it in a comment: *"MUST match
  initialization.jl. Centralising them on `sys` is a future cleanup. For now
  the two values are duplicated with this comment as the link."* A comment is
  the only thing coupling five copies.

The repository already has a place for this class of fault: the
"Duplicate-Representation Audit" in `docs/agents/instrument-trust-log.md`, which
currently lists one entry (the ODE time step appearing in two files). This is the
same fault, five times larger.

**What the record already specifies.** `docs/agents/physics-topology.md` section
3.1 states that `bearing_offset` and the derived bridle rest length are
placeholders and *"the axial design point was never chosen. Treat both as
provisional, and derive them from the taut-chain balance rather than trusting
them."*

The code confirms the way Rod describes the construction: the builder walks
**from the ground up**, through the ground ring, then the transmission rings, then the main
rotor, then the lift bearing above it, then the bridles, then the sky anchor one
cyan-line length above the bearing. So the **cyan line length is a fixed physical
input** (one cut length of rope), and the **lift-bearing offset is the derived
quantity**. That is the size-independent specification, and it is already written
down. It was never implemented.

**Not done this session.** No change was made to these constants, because the
record gives priority to the static solver and the load split, and because Rod asked
for the build logic to be re-read before any refactor.

---

## 8. A contradiction in the record that blocks the load-split work

The two most recent handovers disagree about the back line. This matters because
record item 2 (re-derive the load split) depends on which is true.

- **2026-09-12, section 3 (measured):** *"The backline is the altitude limiter.
  It goes taut by 0.0072 m and takes the 143 N lift surplus (431 N lift vs 288 N
  weight)."* At the 6.0 m bearing offset.
- **2026-09-13, section 4 (measured):** *"The backline is an altitude limiter,
  not a load path, so it **is slack** at the design point. The
  'unrealisable preload' blocker in the plan was an artefact of modelling the
  backline as taut."* At the 3.99 m bearing offset.

Both are measurements, at different offsets. They are not necessarily
inconsistent, but nothing on the record reconciles them, and the load split
cannot be re-derived until they are. This should be settled before item 2 is
attempted.

---

## 9. Other things found and recorded

- `design_preload_from_sky_anchor` in `src/initialization.jl` is exported but has
  **no callers anywhere** in `src`, `test` or `scripts`. It encodes the superseded
  taut-back-line model. It is dead code.
- A remaining silent-truncation defect, **not fixed**: when the torque to carry is
  zero or negative, `trpt_matched_place` returns the *untwisted* placement, in
  which the axial gap equals the untwisted chord and the segment therefore
  carries **no preload at all**. The intended preload is silently dropped.
  Marked STILL OPEN in `docs/agents/physics-topology.md` section 6.
- The `capture_extended` telemetry function reports per-segment twist wrapped into
  the range (−180°, 180°]. A segment wound past 90 degrees therefore reads as a
  small angle. This is how the multi-turn wind-ups in §4.1 stayed invisible. Use
  the stored twist block in the state vector when the twist is large.
  (`src/sim_frame.jl`, recorded in `docs/agents/physics-topology.md` section 7.)
- `scripts/ktd-format` reformats pre-existing unformatted code in both
  `src/initialization.jl` (about 200 lines) and `test/test_settle_validity.jl`
  (about 10 lines). The formatter was therefore **not** run over those files.
  Churn was reverted so the diff stays about logic. The repository is not
  uniformly formatted, and `test/runtests.jl` was already unformatted at `HEAD`.
- Compiler/formatter environment note: the formatter lives in its own environment
  and needs `KTD_PROJECT=.julia_depot/fmt_env scripts/ktd-julia ...` to be invoked
  by hand.

---

## 10. Mistakes this session made, recorded so they are not repeated

1. **Trusted the suite figures in the handover.** It reported two failures that
   did not exist. Run the suite first. It is cheap.
2. **Read line numbers as case identities.** The handover attributed line 107 to
   the four-line/three-rotor design. Line 107 is in a block that uses the
   six-line/one-rotor design. Check which block a line is in.
3. **Concluded the lift-chain constants were tied to the old radius.** They are
   not (measured 3.9898 m versus 3.9897 m). Corrected in §6.5.
4. **Wrote a bound that could never refuse.** The first version of the preload
   ceiling checked the *already raised* profile, which by then looked valid, so it
   silently escalated instead of refusing. Found by measurement, fixed.
5. **Wrote a convergence test that could never converge.** The resting point of
   the update step is *exactly* the target, so `worst <= target` never became
   true. The campaign seed stalled for twelve iterations on a one-part-in-10^16
   difference. Fixed by accepting "at or below the target, to numerical
   rounding".
6. **Quoted a twist ratio computed against the wrong reference.** This session
   reported a figure of 0.9326 before it realised the reference speed was wrong.
   The correct value is 1.0709. Measuring the reference first would have prevented
   it.
7. **Worked on the wrong item.** The seed hunt is the last item on the priority
   list in the record, and it measures against an unvalidated load split.
   Corrected in §6.1.

The pattern in 4, 5 and 6 is the same one the 2026-09-13 handover warns about in
its closing paragraph: checking prose rather than asserting the invariant inside
the script. In each case the fix was to measure, and each measurement changed the
conclusion.

---

## 11. Files touched this session

### Source

| file | change |
|---|---|
| `src/initialization.jl` | `_matched_place_twist` became the public `trpt_matched_place` with per-segment realisability figures and an error past the limit. The hardcoded speed fallback went away. `design_axial_preload` now enforces the tension floor with two named constants and takes a wind function |
| `scripts/ode_gate_v13.jl` | the settle is wrapped so an unbuildable design returns a rejected verdict instead of crashing the gate |

### Tests

| file | change |
|---|---|
| `test/test_trpt_realisability.jl` | **new.** 26 assertions. They cover the design split against the table in the handover and the shipped margin. They also cover the refusal of an over-limit design and the stationary-rotor case. Wired into `test/runtests.jl`. |
| `test/settle_case_builders.jl` | **new.** The campaign-seed test cases now have one shared definition, so the settle guards cannot drift apart. |
| `test/test_settle_preload_consistency.jl` | The test settles first and evaluates its reference at the speed of the settle. The threshold is now 0.001. The retired "known tilt limitation" block became an explanatory comment |
| `test/test_settle_validity.jl` | The connection assertion now names the lift line and cyan line. The test gained a cyan-line tension reader. The bearing residual became a real assertion |
| `test/test_rope_break.jl` | records the initialiser refusing the historical genome as satisfying the regression it exists for |
| `test/test_rotor_power_realism.jl` | same, for the freewheel regression |
| `test/runtests.jl` | wires in the new guard file |

### Documentation

| file | change |
|---|---|
| `docs/agents/physics-topology.md` | section 6 ledger: the clamped twist and the hardcoded speed marked FIXED with their guards. The zero-torque no-op marked STILL OPEN |
| `docs/agents/instrument-trust-log.md` | three new fault rows (the clamped twist, the borrowed speed, the exit-code masking). The disconnected-lift-chain row moved from OPEN to fixed with the measured bridle tension. Two new unanchored-parameter rows cover the two new constants |
| `scripts/compute_seeds.jl` | **comment only** (nine lines) recording the re-seed candidate, its measured figures, and why it cannot land |
| `handovers/README.md` | modified by the previous session. See the note in §13 |

### Probes and logs

New probes this session, all self-checking (they raise rather than print if their
own premise fails):

| probe | what it answers |
|---|---|
| `scratch/diag_preload_margins.jl` | the preload error for all three guard designs |
| `scratch/diag_twist_saturation.jl` | the twist demand against the crossing limit, cross-checked against the telemetry torque |
| `scratch/diag_twist_origin.jl` | separates the placed twist from the settled twist |
| `scratch/diag_preload_reference.jl` | the two preload references: the test reference and the settle reference |
| `scratch/diag_preload_enforcement.jl` | every pass of the tension-floor enforcement |
| `scratch/diag_winner_as_seed.jl` | decodes the campaign winner and the seed for comparison |
| `scratch/spec_seed_candidate.jl` | the gene bounds table plus three candidate screening rounds |
| `scratch/derive_lift_chain_constants.jl` | the settled chain geometry for two sizes |
| `scratch/diag_reseed_chain.jl` | the chain at each stage of the settle path |

Logs are in `.julia_depot/logs/`, prefixed `dsh_`. The ones to read first:
`dsh_exitcode_check.log` (the true suite exit code),
`dsh_validity_restated.log` (the restated guard),
`dsh_spec_seed_candidate.log` and `dsh_spec_seed_round2.log` / `round3.log`
(the seed searches), `dsh_derive_lift_constants.log` and
`dsh_diag_reseed_chain.log` (the re-seed boundary).

The probes from the previous session remain: `scratch/diag_lift_chain.jl`,
`scratch/design_chain_preload.jl`, `scratch/reconcile_realisability.jl`,
`scratch/diag_bow_shape.jl`.

### Read but not modified

`docs/agents/genome-glossary.md` (gene names, ranges and their known exploits),
`docs/agents/domain.md`, `docs/adr/0001-inertia-relief.md`, `CONTEXT.md`,
`DECISIONS.md`, `CLAUDE.md`, `AGENTS.md`,
`docs/plans/2026-09-11-settle-ode-coherence.md`,
`docs/plans/2026-05-09-free-rotor-dynamics.md`,
`docs/plans/2026-05-12-disc-tilt-redesign.md`,
`handovers/handover-2026-09-11-settle-ode-coherence.md`,
`handovers/handover-2026-09-12-session-state-and-preload-rootcause.md`,
`handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md`,
`handovers/handover-2026-09-13-lift-chain-and-realisability.md`.

---

## 12. Where to start next, in order

This follows the 2026-09-12 priority list, not the detour of this session.

1. **Finish the static equilibrium solver** (2026-09-12 handover, section 5 and
   item 1). The settle currently *places* the machine and runs a short relaxation.
   It does not solve for equilibrium. That is why the hub and sky force residuals
   and the first-frame acceleration are still failing. The recorded note is that
   once it lands, "the guard will say so". The three remaining "expected to fail"
   assertions in `test/test_settle_validity.jl` will start passing. Section 5 of
   that handover records the harness as fixed and verified and the solve as not
   converging, with the constraint needed (keep the step on the near-constant line
   length surface).
2. **Reconcile the back-line contradiction in §8** of this document, then
   **re-derive the load split** (item 2): the bridles carry about 123 N against
   the about 431 N the preload formula assumes.
3. Then loads, then `SIZING_FOS_MARGIN`, then the window, **and only then the
   seed question**. The candidate in §6.2 is measured and ready if it is still
   wanted, and it does not need the design constants re-derived.
4. The duplicated-constant specification in §7 is a real piece of work that is
   independent of all of the above and is already specified in
   `physics-topology.md` section 3.1.
5. The bank-angle question is **settled: 11 degrees**, decided by Rod 2026-09-14
   (§6.2). The re-seed candidate is therefore fully specified. It still cannot
   land until item 1 above is done, because its operational settle diverges late
   (§6.4). That is measured, not assumed.

**Do not re-baseline the four red acceptance tests.** The record is explicit that
they pin a real safety signal.

---

## 13. Housekeeping

- The previous session modified `handovers/README.md`, and the file lacks
  entries (the 2026-09-12 handover section 9, item 7 records eight missing). This
  handover should be added to that index.
- The tree is uncommitted by the standing choice of Rod. The fast suite is green
  with a true zero exit, so a commit is now possible from that standpoint. The
  acceptance suite is unchanged at four of eight failing, which is its
  pre-existing state and is what items 1 and 2 are for.
- `docs/agents/instrument-trust-log.md` "Last updated" is 2026-09-13.

**The position, plainly.** The two defects fixed this session were real, are
guarded by tests, and the suite genuinely passes. The seed hunt was premature and
has been stopped and recorded rather than left half-landed. The lift-chain
drop-out that blocked the re-seed is measured and localised to the operational
settle, but its cause is a hypothesis and not yet a fact. The recorded plan is
sound and the next two steps are clear. The distance to a properly settled
operating point derived from the initial geometry and the physical conditions is
short, and nothing found this session contradicts it.
