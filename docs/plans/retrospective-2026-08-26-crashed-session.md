# Retrospective — 2026-08-26 (crashed session)

**Scope:** the 2026-08-25 → 08-26 session that reworked the TRPT geometry
(three-section cylinder→cone→cylinder), added `rotor_count_mode` + per-island
parallel campaign infrastructure, launched `v13_5kw_masslift_len18.8_rotorcount`,
and died before writing a handover or any DECISIONS entry.

**Status:** recovered. DECISIONS entries for the work now exist
([2026-08-25] ×2, [2026-08-26] ×2). This document extracts the lessons.

## 1. Timeline — what the session actually did (9 commits)

1. **Geometry rework** (`3c00a32`, `2e81053`, `b483e0e`): three-section radius
   profile + signed hoop compression (Wacker §4.2.4) + 1/2/3 concurrent top
   rotors.
2. **Genome + campaign infra** (`f33d733`, `5b38fd9`, `fdecb01`, `9753b3d`):
   `power_split`, min-spacing check, `blocking_factor` placeholder, revert to
   14-D genome, `simple_rotors → rotor_count_mode` rename, `--island N`
   parallel mode + `combine_islands_v13.jl`.
3. **Bugfixes** (`005b3f8`, `73af2d9`): `combine_islands_v13` soft-scope wrap,
   and the FoS_min off-by-one.

## 2. What it left behind (all recovered now)

- **No handover, no DECISIONS entries** for any of it. The session outgrew its
  own checkpoints and the last state was lost to the crash.
- **Uncommitted `CONTRIBUTING.md`** with stale test counts (917 tests / 22
  files; the suite is 1964 / 44 files).
- **Untracked results dir** whose "winner" is structurally invalid.

## 3. Lessons

1. **Scope explosion without checkpoints is the failure mode.** One session did
   geometry rework + genome rework + parallel-run infra + a campaign + two
   bugfixes, and wrote no checkpoint after any of it. RULE: one phase per
   session; write a DECISIONS entry (or handover) after each; keep the
   trajectory recoverable even if the session dies.

2. **A physics change was campaigned before it was validated.** The three-section
   geometry + signed hoop compression went straight into a DE campaign with no
   smoke on the new geometry and no check that the transmission cylinder
   survives. Its first "winner" buckled at FoS 0.556. RULE: re-smoke the seed on
   any geometry change (this is the same rule the 08-24 audit already stated)
   before spending ~12 h of DE.

3. **The FoS off-by-one is the known index-space fault class again.** Past
   faults read the ω block instead of the α block; this one read
   `ring_fos[2:end]` where the array was already stripped of ground+hub. RULE:
   one authority for index-space mapping (`min_airborne_fos`), and a regression
   test that pins the "index 1 included" contract — `test_airborne_fos.jl`.

4. **"Geometry far from expected" had two independent causes, both now fixed.**
   (a) The 08-24 dead genes (x6/x7/x9 ignored by the builder) and (b) the FoS
   gate hiding the buckled lowest ring. A **visual 3D seed check** would have
   caught both before the campaign — the direct motivation for Phase B.

5. **Seed rationale can be measured on broken code.** The "3-rotor stack 37.7 kg
   vs 59.4 kg single" re-seed argument was measured before the FoS fix landed, so
   it is unverified. RULE: re-derive seed rationale after any structural-gate fix.

## 4. Next steps (sequenced)

1. **Phase B** — visual 3D Makie seed/genome check, wired as a pre-campaign
   eyeball step, so a bad geometry form is caught before any DE run.
2. **Phase C** — close the physics-validation-ledger OPEN/SUPPORTED items,
   including the static structural FoS threshold (admissibility gate 13) that
   the three-section geometry made more urgent.
3. **Do not re-launch** the rotorcount campaign until the three-section geometry
   smoke-tests green on the current FoS path and the winner re-gate is clean.

## 5. Evidence

- Campaign results (VOID winner): `scripts/results/v13_5kw_masslift_len18.8_rotorcount/`
  (see `VOID.md` inside for the re-eval verdict).
- Fault ledger rows are in `docs/agents/instrument-trust-log.md` (the FoS
  off-by-one and the 08-24 geometry class).
