# Handover — 2026-08-26: crashed-session recovery + resurrected backlog

**From:** recovery session (2026-08-26)
**To:** next session
**State:** recovery landed (commits `828668d`, `fe8ec77`, `e440595`). Fast suite
**1967/1967 green**. Acceptance suite red-by-design (see
`docs/plans/2026-08-22-acceptance-rebaseline.md`). Working tree clean except
generated/void artifacts (`.claude/worktrees`, `scripts/results/preview_genome.png`,
`scripts/results/v13_5kw_masslift_len18.8_rotorcount/` telemetry — VOID, see its `VOID.md`).

## 1. What the crashed session was building toward

The 08-25 → 08-26 session pursued **lighter 5 kW designs on validated
three-section geometry + multi-rotor**. It landed the code but died before
validating it, leaving these unfinished goals. Resurrected in dependency order:

1. **Validate the three-section + rotor_count_mode geometry.** Smoke-test the
   5 kW seed on the current HEAD. Two bugs the crashed campaign ran with are
   now fixed: the FoS off-by-one (`73af2d9`) and the rotor→ring `+1`
   (`828668d`, which made every multi-rotor design one rotor short). The
   crashed "winner" buckled (FoS 0.556) and its "3-rotor stack" was really
   2 rotors. Re-smoke BEFORE any re-campaign.
2. **Re-run the rotorcount campaign** — only after (1) is green. Parallel mode
   (`run_v13_5kw_masslift.jl --island N`) and `combine_islands_v13.jl` are in.
3. **Acceptance re-baseline** — blocked on valid winners; catalog
   `docs/plans/2026-08-22-acceptance-rebaseline.md`.
4. **Close the ledger OPEN items**: D4 (torque-cap law — MAJOR, needs its own
   session per `2026-08-22-physics-convention-fixes.md` §1), D1 (lin_damp
   dt-paired sweep), D7 (knuckle floor in ODE inertia), D2/D3 (hardware/field).
5. **Settle-ODE gap workstream** — `docs/plans/2026-08-22-settle-ode-gap-workstream.md`.
6. **Convention-fixes minor batch** — `2026-08-22-physics-convention-fixes.md` §5.

## 2. Scope-monitoring lessons (why it crashed, and the monitors that catch it)

The session died because it ran **four workstreams** (geometry rework + genome
rework + parallel-run infra + campaign/bugfixes) with **zero checkpoints**. It
left no handover, no DECISIONS entries, uncommitted files, and a void campaign.

Monitors that would have caught it in time:

| Signal to watch | Threshold | Response |
|---|---|---|
| Commits since last checkpoint | > ~3 without a DECISIONS/handover note | Stop; write the checkpoint |
| Distinct workstreams in one session | > 1 | Split — new workstream = new session |
| DE campaign launched | without a fresh smoke (visual + structural) on current HEAD | Block; smoke first (`scripts/preview_genome_geometry.jl` + one `evaluate_windowed`) |
| Seed/winner rationale | measured before the latest structural fix | Re-derive on current HEAD before quoting |
| Goal round budget | `maxGoalRounds` set at session start | Auto-stops runaway continuation |

**Rules, in one line each:**

1. One workstream per session. Refuse mid-session scope additions.
2. Checkpoint after every phase (DECISIONS or handover), not at the end.
3. Validate before campaign — re-smoke geometry/physics before any DE spend.
4. Bound the session (closed todo list + goal round cap); when the list is
   done, stop.
5. Re-derive seed rationale after any structural fix.

## 3. The immediate next action

Smoke the 5 kW seed on the fixed HEAD and eyeball it in the viewer:

```bash
julia --project=. scripts/preview_genome_geometry.jl            # interactive GLMakie
julia --project=. scripts/preview_genome_geometry.jl --headless # PNG → scripts/results/preview_genome.png
```

Expected seed form (three-section, 3 co-axial rotors): a small transmission
cylinder (r 0.575 m) at the ground, a 22° cone up to r 2.775 m, then a harvest
cylinder carrying three rotor annuli at rings 5–7. If the rendered form differs
from this, stop and diagnose before re-campaigning.
