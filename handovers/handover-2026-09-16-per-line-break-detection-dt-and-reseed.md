# Handover — per-line break detection, the dt fault class, and the L/r 1.5 re-seed (2026-09-16)


> **SUPERSEDED 2026-09-19 — read this before acting on §3, §5 or §7.**
>
> Subsequent work found the **real** root cause of the two acceptance failures, and
> it was **not** `SIZING_FOS_MARGIN`. The closed-form ring load model was **3.7x
> low**: the capacity ratio read exactly 1.000 while the load ratio was 2.1-3.7, and
> the wall clamp was setting every section. Fixed by widening `HELIX_LOAD_FACTOR`
> from 0.32 to a 1.2 envelope and setting `MIN_RING_DO_M = 10 mm`, with
> **`SIZING_FOS_MARGIN` unchanged at 1.3**. Cost: +3.276 kg airborne.
> **Acceptance is reported back to 8/8** (per that session's record; not
> independently re-measured here).
>
> So: **do not inflate the global FoS margin.** §5's recommendation to sweep it was
> the wrong branch, and §7's incomplete sweep is moot. The decision rule in §7
> anticipated this ("if the required margin blows up mass ... inspect the static
> tension multiplier") and that is the branch taken.
>
> `src/trpt_optimization.jl` is **no longer uncommitted** — §3 is resolved; the
> sweepable-margin keyword and P1's tether alignment landed in `7014445`.
>
> Records: `8471dd5` (the fix), `8feeb23` (the record), `cfe67a9` (ACTIVE),
> `DECISIONS.md` [2026-09-16]. The **§8 mistake list, the per-line break-detection
> record (§2 item 4) and the `dt` fault class (§2 item 2) remain valid.**

## 1. How to run things

Julia through the wrapper only — plain `julia --project=.` fails in this sandbox
(`CLAUDE.md`, `AGENTS.md`).

```bash
scripts/ktd-julia test/runtests.jl                 # fast suite, ~3.5 min
scripts/ktd-julia test/acceptance_runtests.jl      # acceptance, ~18 min, 8 files
scripts/ktd-format                                 # JuliaFormatter, Blue
scripts/ktd-julia scratch/<probe>.jl               # any scratch probe
```

`script -q -c "..." scratch/logs/<name>.log` gives live output and survives the
run; Julia buffers stdout otherwise. **`/tmp` is a per-command tmpfs here** — files
written there do not persist between bash calls, and a backgrounded process
started there dies with the call. Put anything durable in the workspace.

## 2. Headline

Four independent threads, all landed or measured:

1. **The taut back line reached `src/`** (`21cf73b`) — bi-linear, tension-only,
   with `EA_back_line` pinned to the 3 mm 707 kN spec after `mass_scale`.
2. **A whole class of `dt` faults was fixed** — the canonical `4e-5` is not stable
   for a fine-meshed build; every test, the ramp scoring path and the trace
   recorder now derive `stable_dt_for_system`. A static guard prevents regression.
3. **The 5 kW campaign re-seeded at L/r 1.5** (`04a31bf`) — the clean floor fix,
   one gene, `P_end` 5.1465 kW, `FoS` 2.599, chain connected.
4. **Rope-break detection was a bay average and is now per line** (`ea78651`),
   with bridle/cyan monitoring and a caller-gated `breaks_enabled` — after
   introducing and then fixing a gate regression (`c38bbf5`).

Test state at handover:

| suite | result |
|---|---|
| Fast (50 files) | **2139 pass / 0 fail / 1 broken**, exit 0 |
| Acceptance (8 files) | **6 pass / 2 fail** — `test_settle_lowk_honest`, `test_physics_path_ode` |

Campaign exit gate needs 8/8 unrebased, so **2 short at this point in the session**. Both were subsequently fixed — see the SUPERSEDED banner above; **8/8 is per `8feeb23`'s record, not re-measured by this author.**

## 3. UNCOMMITTED — read this first

`src/trpt_optimization.jl` is **modified in the working tree and not committed**.

It exposes `SIZING_FOS_MARGIN` (was a `const`, so unsweepable) as a keyword:

```julia
sizing_fos_margin::Float64=SIZING_FOS_MARGIN,
```

with the two `cfg.fos_hard * SIZING_FOS_MARGIN` call sites (now ~`:371` and
`:384`) switched to `cfg.fos_hard * sizing_fos_margin`. Behaviour-preserving by
construction, but **not suite-verified**. Run the fast suite before committing it.

The margin sweep built on it, `scratch/probe_sizing_margin.jl`, produced **no data
rows** — see §7. No margin value is recommended, chosen or applied.

## 4. Committed this session (14 commits)

| commit | what |
|---|---|
| `21cf73b` | bi-linear tension-only back line; EA pinned 707 kN post-`mass_scale` |
| `ae864a6` | every test dt derived + `test/test_dt_guard.jl` |
| `bc5718b` | trust log: dt fault, handoff imbalance, damper finding |
| `57d1850` | ramp scoring path derives dt instead of raw `V11_DT` |
| `e55cccb` | trace recorder derives dt; guard scoped to `test/` |
| `e8d9d16`, `fbb3441`, `a7e50d9`, `a257bf7`, `67f1c3f` | plan/record corrections |
| `04a31bf` | L/r 1.5 re-seed + `test_trpt_realisability` pinned to a fixture |
| `ea78651` | per-line break detection + `breaks_enabled` keyword |
| `c38bbf5` | gate break-detection regression fixed; A5 re-baselined |
| `9915ad4` | canonical 10-D indices in `test_settle_lowk_honest` |

## 5. The two remaining acceptance failures

Both are the **same structural-sizing root cause**, and power/twist are healthy in
both cases:

* `test_settle_lowk_honest.jl` A3 — `P_end > 5.0` and/or `FoS_min > 2.5` fail
  (1 of 3 assertions passes; **which two was never isolated**).
* `test_physics_path_ode.jl` P1 — `status=reject`, `P_mean 5.384 kW`, **`FoS_min
  2.054 < 2.5`**, no twist collapse.

`SIZING_FOS_MARGIN = 1.3` (`src/trpt_optimization.jl:171`) sets the closed-form
target as `fos_hard × margin` = **3.25** so the windowed FEA lands ≥ 2.5. Its own
comment records the calibration was made 2026-09-10 when the settle was
under-twisted; under the full matched twist the ring stress peaks higher and it no
longer reaches the floor.

**Do not lower the 2.5 threshold.** The margin is global — every ring of every
design — so changing it re-baselines ring mass, lifter sizing and every campaign
result.

### Known separate correctness fix

`test/test_physics_path_ode.jl:67-82` builds `CFG` **without**
`tether_diameter`, so it defaults to 0.003 m while `P = params_at_length(L18)` uses
the scaled **0.003651 m**. Stiffer lines transmit higher dynamic tension into the
rings, so any sizing sweep must set `tether_diameter = P.tether_diameter` or it
calibrates against the wrong stiffness. Fix this regardless of the margin outcome.

## 6. Open items, in priority order

1. **Finish the sizing sweep** (§7) and resolve the two acceptance failures.
2. **`CFG.tether_diameter` alignment** in `test_physics_path_ode.jl`.
3. **Sky-anchor balance + back-line trim.** The balance is written and was
   reverted to keep the suite green. Key finding: at the **design** geometry the
   back line sits at its rest sphere by construction, so it is SLACK (0.72 N)
   there; the ruled tautness lives in the **settled** geometry (424 N, anchor
   1.05 cm beyond the sphere). The trim is the field's launch control and is
   **Rod's decision**. Re-applying needs that ruling plus a NaN guard fix.
4. **Static solver** (`ACTIVE.md` item 3) — dynamic relaxation + kinetic damping.
   Still the owner of the last `@test_broken`: the first-frame jerk.
5. **Handoff imbalance.** Settle hands over a state that is not in force balance.
   Measured at the correct dt: hub residual ~47 N, `acc0` 40→717 m/s² over 40 ms,
   worst node a `RopeNode` carrying 36 N shared tension. **Rod's "blades initiated
   stationary" hypothesis is refuted** — all 9 rings are at ω = 12.98347 rad/s,
   uniform.
6. **Damper finding** (`bc5718b`). Moderate constant `lin_damp` (0.3–0.99)
   roughly **halves** the handoff jerk versus the canonical 0.05; ramping down does
   **not** help and `0.999` is worst. The numerical-stability argument for the
   damper is gone (it rested on the dt fault). The `lin_damp` justification row
   stays OPEN.
7. **Wobble gate** (≥120 s, starts after a relax) and the rest of the exit gate.
8. `test_settle_lowk_honest.jl` takes **~13 min** — heavy even for acceptance.

## 7. Where the sizing sweep stands (the interruption)

`scratch/probe_sizing_margin.jl` implements Rod's protocol: tether aligned to
`P.tether_diameter`, margins swept, reporting `FoS_min` + worst ring, airborne
mass and `P_end`, over 5 s and 20 s windows.

**It emitted no rows.** The first version was massively over-costed — 150 k settle
+ 10 s relax + up to 1 M-step windows × 10 points, i.e. hours. It was killed and
reduced (30 k settle, margins 1.3/1.5/1.7, 5 s windows, 8 FoS samples), and that
was still in flight when the session ended. Live log:
`scratch/logs/sizing_sweep2.log`.

**Next step:** size a probe against its step count *before* launching it. Then take
20 s windows only for whichever margin clears 2.5.

Decision rule (Rod): if ~1.45–1.55 clears `FoS_min ≥ 2.5` over 20 s with mass
growth < 2 kg and `P_end ≥ 5.0`, land it, align `CFG.tether_diameter`, and record
the calibration in `DECISIONS.md`. If mass blows up or the 20 s trough does not
close, inspect the static tension multiplier rather than inflating the global FoS
factor.

## 8. Mistakes this session — recorded so they are not repeated

Three of the same shape: **asserting a fact from expectation instead of checking.**

1. **Invented a load-path interaction.** Claimed the taut back line "lifts the sky
   anchor and takes the last 13.5 mm from the cyan". Rod corrected it: the back
   line hangs from the sky anchor down to the ground anchor and can only RESTRAIN
   its rise. The mechanism was wrong; the real cause was an under-converged settle.
2. **Claimed "diameter independence" to justify a fix.** Circular reasoning:
   held ε from one measurement, observed `T ∝ EA ∝ d²`, concluded strain is
   diameter-independent. Wrong — line tension is set by external load, so
   `ε = T/EA ∝ 1/d²`. Thinner lines DO break sooner.
3. **Claimed `get_max_rope_tension` feeds FoS.** It does not; it appears only in
   `sim_frame.jl` for reporting. `FoS_min` comes from ring buckling.
4. **Claimed the gate "reaches the evaluator".** It calls `run_canonical_sim!`
   directly. With the new `breaks_enabled=false` default this **silently disabled
   the gate's break detection** — re-introducing the exact bug A5 guards. Fixed in
   `c38bbf5`; same omission audited at `control_map_hunt.jl` and
   `record_ramp_traces.jl`.
5. **Wrote dead code in a patch.** `(ss2.end_a.is_ring && ss2.end_b.is_ring)` —
   `rope_forces.jl:6` says "both ends are rings" is *never* true for TRPT lines.
   Would have left `broken_lines` unset for the line just detected as broken.
6. **Re-averaged in the fix for averaging.** Summed all 6 bridles into one scalar
   while removing the same defect from the TRPT lines. Now per bridle.
7. **Assumed a baseline without isolating it.** Ran a `git stash` cycle inside one
   command and reported the *current* tree as the baseline (it reproduced to the
   digit). Use a worktree, not a stash in the same call.
8. **Polled a long job with identical calls** instead of waiting or checking the
   log, and **launched probes without costing them**.

**The transferable lesson:** this session's real defects were found by measuring
(`dt` instability, the bay-averaged criterion, the gate omission, the legacy 14-D
indices). Every one of my wrong turns was an assertion I did not check.

## 9. Reading order for the next session

1. `docs/plans/ACTIVE.md` — the single priority list; **Concerns item 0** is the
   break-detection record.
2. This file.
3. `docs/agents/instrument-trust-log.md` — the dt fault row (FIXED), the handoff
   imbalance row (OPEN), the damper row.
4. `docs/agents/physics-topology.md` — required before any geometry/tension work.
5. `DECISIONS.md` last few entries (2026-09-15, 2026-09-16).

Useful skills: `ktd-simulation-workflow`, `diagnosing-bugs`, `tdd`. Note the repo
convention: an ODE-window test belongs in `test/acceptance_runtests.jl`, never in
`runtests.jl`.

## 10. Probes worth keeping (`scratch/`)

| probe | what it shows |
|---|---|
| `diag_ea_and_convergence.jl` | settle horizon vs convergence; the EA chain |
| `diag_kick_decay.jl` | handoff acceleration decay over 40 ms |
| `diag_damping_ramp.jl` | the `lin_damp` sweep and the ramp comparison |
| `diag_thin_tether.jl` | the A5 thin-tether machine's tension/strain |
| `check_anchor_convergence.jl` | back-line tension vs settle length |
| `probe_sizing_margin.jl` | **incomplete** — the sizing sweep (§7) |

## 11. Housekeeping

* `scratch/hermes_probe_*.jl` (4 files) are another agent's, left untracked
  deliberately. Leave them.
* `docs/agents/instrument-trust-log.md` had 12 **pre-existing unmerged** paths
  (`docs/outreach/figures/*`) that a worktree operation disturbed; they were backed
  up to `scratch/unmerged_backup/` and unstaged. They are not in HEAD.
* Both `src/` and `test/` are otherwise clean. One modified file:
  `src/trpt_optimization.jl` (§3).
