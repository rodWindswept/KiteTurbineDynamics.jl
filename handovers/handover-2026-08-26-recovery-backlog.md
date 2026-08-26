# Handover — 2026-08-26: crashed-session recovery + resurrected backlog

**From:** recovery session (2026-08-26)
**To:** next session (and Claude, for the push)
**State:** recovery landed (commits `828668d`, `fe8ec77`, `e440595`, `53f3997`,
`83d67f9`). Fast suite **1967/1967 green**. Acceptance suite red-by-design
(`docs/plans/2026-08-22-acceptance-rebaseline.md`). Working tree clean of tracked
changes; untracked are only generated/void artifacts (`.claude/worktrees`,
`scripts/results/preview_genome.png`, `scripts/results/v13_5kw_masslift_len18.8_rotorcount/`
telemetry — VOID, see its `VOID.md`).

---

## FOR CLAUDE — push master to origin (read this first)

You are pushing the main repo's `master`. Verified state (HEAD `83d67f9`):

- `origin/master` is `5638fbd` (unchanged since 2026-08-24).
- `master` is **22 commits ahead, 0 behind** — a clean fast-forward.
- The "mystery commit" you saw (21 → 22) was **this session's** viewer-window
  fix (`83d67f9`), *not* a worktree agent. It is intended; no investigation needed.
- The commit after this handover (the one editing this file) is ALSO this session
  — expect `master` to be 23 ahead by the time you push. Push everything.

**To push (run from the main repo, not a worktree):**

```bash
git -C /home/rod/Documents/GitHub/KiteTurbineDynamics.jl push origin master
```

**The 22–23 commits are all legitimate and must all go up:** 5 recovery commits
on top (`828668d` rotor fix, `fe8ec77` viewer, `e440595` docs, `53f3997`
handover, `83d67f9` viewer-window fix, plus this checkpoint) over 17 crashed-session
commits (`73af2d9 … ccf3fb4`). The recovery docs reference the crashed-session
commits, so do not omit them.

**Do NOT:**
- `git add` the untracked files (`scripts/results/v13_5kw_masslift_len18.8_rotorcount/*`
  telemetry and `scripts/results/preview_genome.png` are intentionally untracked).
- Touch `.claude/worktrees/*` (stale June artifacts; not part of this push).
- Rebase / squash / force — a plain fast-forward is correct.

**After:** `git ls-remote origin master` should report `HEAD == 83d67f9` (or the
checkpoint commit that follows it). Report back the resulting commit hash.

---

## 1. Backlog — resurrected goals + Rod's viewer findings (in dependency order)

The crashed session pursued **lighter 5 kW designs on validated three-section
geometry + multi-rotor**. It landed code but died before validating it. Two NEW
items from Rod's viewer review come first:

1. **Clearance lower bound for the lowest rotor (NEW, Rod 2026-08-26).** The
   3-rotor seed's lowest rotor (ring 5, `r_out = 3.53 m`) sits at shaft `s = 7.70 m`,
   so its outer tips clear the ground by only **~1.3–1.8 m** (borderline against
   `MIN_CLEARANCE = 1.5 m`). Worse, `lowest_rotor_clearance`
   (`scripts/run_v13_5kw_masslift.jl:213`) uses `blade_tip_radius` — the **0.7·span
   OFFSET** (~0.76 m) — instead of the **absolute** tip radius (`r_ring + blade_tip
   = 3.53 m`), so it computes ~4.1 m clearance and the gate never bites. Same
   offset-vs-absolute class as the settle ω-scan (DECISIONS [2026-08-24] rule 2).
   Fix the gate to use the absolute tip radius, enforce the bound, and re-seed if
   the seed is genuinely below it.
2. **Blocking on the upper rotors (NEW, Rod 2026-08-26).** Co-axial stacked rotors
   wake-block each other. Add a blocking value so the **upper (downstream) rotors
   are estimated at 0.75× power** (currently `blocking_factor = 1.0` = no blocking).
   Note: today it de-rates *inflow* (`v_i *= blocking_factor`, so P ∝ v³) — 0.75×
   *power* means either power-side de-rating or `blocking_factor ≈ 0.75^(1/3) ≈ 0.91`.
3. **Validate the three-section + rotor_count_mode geometry** (smoke on fixed HEAD,
   now including 1 and 2). Two bugs the crashed campaign ran with are fixed: the
   FoS off-by-one (`73af2d9`) and the rotor→ring `+1` (`828668d`, which made every
   multi-rotor design one rotor short). The crashed "winner" buckled (FoS 0.556)
   and its "3-rotor stack" was really 2 rotors. Re-smoke BEFORE any re-campaign.
4. **Re-run the rotorcount campaign** — only after (3) is green. Parallel mode
   (`run_v13_5kw_masslift.jl --island N`) and `combine_islands_v13.jl` are in.
5. **Acceptance re-baseline** — blocked on valid winners; catalog
   `docs/plans/2026-08-22-acceptance-rebaseline.md`.
6. **Close the ledger OPEN items**: D4 (torque-cap law — MAJOR, needs its own
   session per `2026-08-22-physics-convention-fixes.md` §1), D1 (lin_damp dt-paired
   sweep), D7 (knuckle floor in ODE inertia), D2/D3 (hardware/field).
7. **Settle-ODE gap workstream** — `docs/plans/2026-08-22-settle-ode-gap-workstream.md`.
8. **Convention-fixes minor batch** — `2026-08-22-physics-convention-fixes.md` §5.

## 2. Scope-monitoring lessons (why it crashed, and the monitors that catch it)

The session died because it ran **four workstreams** (geometry rework + genome
rework + parallel-run infra + campaign/bugfixes) with **zero checkpoints**. It
left no handover, no DECISIONS entries, uncommitted files, and a void campaign.

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
4. Bound the session (closed todo list + goal round cap); when the list is done, stop.
5. Re-derive seed rationale after any structural fix.

## 3. The immediate next action

Smoke the 5 kW seed on the fixed HEAD and eyeball it in the viewer:

```bash
julia --project=. scripts/preview_genome_geometry.jl            # interactive GLMakie
julia --project=. scripts/preview_genome_geometry.jl --headless # PNG → scripts/results/preview_genome.png
```

Expected seed form (three-section, 3 co-axial rotors): a small transmission
cylinder (r 0.575 m) at the ground, a 22° cone up to r 2.775 m, then a harvest
cylinder carrying three rotor annuli at rings 5–7. **Rod's review already flags
two problems to fix first: the lowest rotor tip clears the ground by only
~1.3–1.8 m and the clearance gate under-counts it (item 1); and the upper rotors
need 0.75× blocking (item 2).**
