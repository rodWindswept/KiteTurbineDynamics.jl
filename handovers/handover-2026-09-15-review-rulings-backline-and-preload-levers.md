# Handover — review rulings, the back-line model, and the preload levers (2026-09-15)

## 1. How to run things

`scripts/ktd-julia <script>` (plain `julia --project=.` fails in this sandbox —
see `CLAUDE.md`). Fast suite at this session: **2108 pass / 0 fail / 3 broken,
true exit 0, 3 m 51 s**. Do not pipe through `tail` without `set -o pipefail`;
the pipe masks the exit code (this session did exactly that once and reported a
crash as exit 0).

## 2. Headline

An external six-week review (now committed at
`reviews/2026-09-15-six-week-review.md`) was read, checked against source, and
ruled on. Three work items came out of it: the damping/wobble policy, the
back-line model, and the lift requirement. The load split was re-derived with a
**rigid taut back line** as ruled, and the preload problem turns out to be
solvable **without touching the lift line**.

## 3. Rulings recorded — `DECISIONS.md` [2026-09-15] (three entries)

1. **Q4 deliverable: the validated 5 kW design first**, then the 1.5 kW
   Daisy-scale validation, then the report. Alicante end-October stands. 10–50 kW
   on hold. **Reverses review rec 4** (1.5 kW before 5 kW); compatible with rec 1
   (the exit gate is what the 5 kW design must pass).
2. **Bow is an output, not a constraint.** "Bow" = sag; explicitly *not* a
   translation. The 1.5 m figure must not be quoted as a result.
3. **Every damping term must be justified.** The wobble is **gated** (review
   option (c)); option (b), a DLF, is rejected.
4. **The back line is TAUT at the design point** and carries residual vertical
   tension. Soft through the climb, engages at the target elevation (normally
   30°); may slack off-design. Closes the "open" question in
   `physics-topology.md` §3.2.
5. **The bridle cone is fixed by the ring's resting radius**, not by
   expansion/blade state. Single-sourced; the `effective_radii` branches removed.
6. **The taut-chain rule is about the steady state.** Transient slack is
   expected; *sustained* slack is the defect. `AGENTS.md` and
   `physics-topology.md` §3 reworded.

## 4. The damping inventory (four mechanisms)

Source-verified. **This was already on the record** — the 2026-09-10 audit
(`DECISIONS.md` ~:385-412, workstream §2.7) said the same thing. The review
re-derived it. Read the record before re-deriving.

| Mechanism | Where | Basis | On the canonical path? |
|---|---|---|---|
| `p.zeta = 0.05` rope material damping | `parameters.jl:177,224` → `rope_forces.jl:58` | Dyneema, ζ 0.01–0.05 | yes |
| `TETHER_DRAG_CD = 1.0` line drag | `aerodynamics.jl:346-389` | Tveide (≈1.09, not landed) | yes |
| `lin_damp = 0.05` rope-node retention | `initialization.jl:599-657` via `simulation.jl:193` | **artificial**, ≈7.5e4 s⁻¹ (13 µs) | yes — the only artificial damper |
| `bearing_tr_damp`, `ang_damp` | `initialization.jl:698,725-738` | legacy | **no** — `run_canonical_sim!` accepts neither |

The four `# bearing damper retention factor` comments on `lin_damp` are corrected.

## 5. The load split with a rigid taut back line — measured

`scratch/taut_backline_angle_sweep.jl` (self-asserting, exit 0). Seed: R_hub
2.4 m, derived bearing offset **3.9943 m**, 6 lines, 8 segments, ω 12.9835,
τ_eq 377.60 N·m, T_thrust 1067.61 N, W_rotor 143.21 N.

**The closed form reproduces the 09-13 record exactly** — taut `T_top`
**1149.8 N** (record 1150.0), slack **1344.7 N** (exact). Trustworthy as a chain.

- **At the design point (el 70°, taut) `demand` = 1.1471** against a 0.9524 target
  — **past the torsional cliff**, not inside a thin margin.
- **The floor computes to 1388.2 N, not the record's 1274.47 N.** An 8.9 %
  discrepancy. **UNRESOLVED** — trace before quoting either.
- Lift-angle sweep: `T_cyan` rises and `T_back` falls monotonically (asserted).
  **Clears at el ≤ 50°, back line slacks at el ≤ 30° → band 31°–50°.** At 65° it
  is still 185 N short, so "slightly" is not enough.

## 6. The back line — geometry and spec

- **It is near-vertical**: direction `[-0.0640, 0, -0.9979]`, i.e. **3.7° off
  vertical** (asserted in the probe). It reacts **vertical tension only** and does
  **not** carry the downwind force at the sky anchor. Lowering the lift elevation
  *reduces* its tension (351 N at 70° → 228 N at 50°). The downwind force goes
  into the **cyan** line, where it becomes the preload the lever is for.
- Spec (Rod 2026-09-15): **3 mm Dyneema** (`EA ≈ 707 kN`), with **8 sections of
  4 mm bungee sewn in series**; each rests at 30 cm and sits at 40 cm at full
  tension, so the line has **80 cm of soft travel** and hardens at the design
  length. Model as **bi-linear, tension-only**: soft over 0–80 cm with
  `k_soft = T_design / 0.8` N/m (no extra field data needed), hard beyond.
- Measured off-design: `k_soft` = 439 N/m. At design the line is exactly on its
  hard stop, so any lift reduction moves it into the soft region.

## 7. The two preload levers — measured, and both my predictions were wrong

`scratch/levers_linecount_ringdensity.jl` (self-asserting, exit 0). Worst demand
at the design preload, ✓ = at or under the 0.952 target:

| lines \ L/r | 2.0 | 1.5 | 1.2 |
|---|---|---|---|
| 6 | 1.147 ✗ | **0.871 ✓** | 0.697 ✓ |
| 8 | 1.005 ✗ | 0.764 ✓ | 0.612 ✓ |
| 10 | 0.890 ✓ | 0.677 ✓ | 0.543 ✓ |

- **`target_Lr` (x[3]) is the clean lever.** The floor scales *exactly* with it:
  1388 / 1050 / 840 N at 2.0 / 1.5 / 1.2, ratios 0.757 and 0.605 against 0.75 and
  0.60. Demand ∝ chord; lower L/r ⇒ more rings (n_seg 8 → 12 → 17).
- **`n_lines` (x[4]) does NOT reduce demand at fixed tension** — the floor is
  ~1389 N at 6, 8 and 10 lines. It helps only *indirectly*, by changing the
  design: `T_thrust` rises 1067.6 → 1205.6 → 1340.4 N and the lifter is sized to
  a heavier machine, so `T_top` rises 1149.8 → 1316.4 → 1489.5 N.
- **Cleanest single fix: 6 lines at L/r 1.5 clears** — same lines, same 70° lift
  line, no extra back-line duty.
- **Mass reverses the ranking** (`scratch/diag_floor_mass_and_thrust.jl`): at
  6 lines, L/r 2.0 → 1.5 is **−0.3 % airborne** (29.31 → 29.22 kg) for a floor of
  1388 → 1050 N; 6 → 10 lines is **+120 %** (29.31 → 64.48 kg) for 1388 → 1390 N.
  **Pull L/r, not lines.**
- Floor discrepancy **resolved**: the plan's 1274.47 N is at `sin Δα ≤ 1`; the
  code's 1388.18 N is at `≤ 1/1.05`. Ratio of the two floors = 1.0506 = the margin
  exactly. The residual 3.7 % is the axial profile (plan 15.613 N/segment vs code
  3.903, from `p.m_ring = 0.7958 kg`).

## 8. Mistakes this session — recorded so they are not repeated

| # | Mistake | Correction |
|---|---|---|
| 1 | Claimed the back line must survive the horizontal load and that the lift-angle lever doubles its duty | The back line is 3.7° off vertical; it reacts vertical only, and the lever *lowers* its tension. Corrected in `ACTIVE.md` |
| 2 | Claimed `T_top` is independent of `n_lines` because the bridle term cancels | Algebraically true, but `T_top` rises 1149.8 → 1489.5 N with line count. Mechanism unexplained |
| 3 | Claimed `demand ∝ 1/n_lines` | False in the built design; the floor is flat at ~1389 N. `target_Lr` is the real lever |
| 4 | Said the 3.99 m offset "might be stale" | Wrong. `physics-topology.md:139` records the derived offset as 3.99 m at 2.4 m radius, which is this seed. The 09-13 numbers stand |
| 5 | Wrote `@printf("..." * "...")` | `@printf` needs a literal format string |
| 6 | Piped a run through `tail` and read "exit 0" off a crash | Use `set -o pipefail` |
| 7 | Re-derived the damping audit from source | It was already on the record (2026-09-10). Read first |

## 9. Open items

1. ~~Floor 1388.2 N vs the record's 1274.47 N~~ **RESOLVED** — different criteria
   plus a stale ring mass; see §7.
2. ~~Why `T_thrust` moves with `n_lines`~~ **RESOLVED** — the rotor moves with it
   (`R_rotor` 3.6572 → 3.8704 m, `A_sw` 31.14 → 37.22 m²). A design coupling.
3. **Back-line handling demand and safety** — **ANSWERED by Rod**, now in
   `physics-topology.md` §3.2 and `docs/lift/README.md`: containment on TRPT
   failure, plus tensioned raise/lower for deployment, recovery and high-wind
   stalling. **Design load = worst of {design point, hoisting, break containment,
   high-wind handling}; none of the four is quantified.**
4. **Lift requirement** — the record now lives in `docs/lift/README.md` (register
   L1–L5, the requirement we hold, the safety case, evidence files, aspirational).
   The 1.5 itself still has no basis, and the code meets it at `v_ref` only.
5. **Realisability margin vs gust transient** — Rod: **aspirational, further down
   the road.** Logged in `ACTIVE.md` "Noted for later" and `docs/lift/README.md`.
6. `ACTIVE.md` item 2 remainder, then the static solver (item 3).

## 10. Files touched

**Source:** `src/initialization.jl` (cone single-sourced on the resting radius;
two `effective_radii` branches removed), `src/objective_evaluator.jl`,
`src/objective_v11.jl` (mislabelled damper comments).

**Docs:** `DECISIONS.md` (three [2026-09-15] entries), `AGENTS.md`,
`docs/agents/physics-topology.md` (taut-chain rule; §3.2 ruled + safety roles),
`docs/plans/ACTIVE.md` (**new** — single priority list),
`docs/lift/README.md` (**new** — lift evidence base and requirements),
`reviews/2026-09-15-six-week-review.md` (**new**), `handovers/README.md` (index).

**Probes (new, all self-asserting):** `scratch/taut_backline_angle_sweep.jl`,
`scratch/levers_linecount_ringdensity.jl`,
`scratch/diag_floor_mass_and_thrust.jl`.

## 11. Readiness for a new 5 kW campaign seed — and where to start

**Design side close; model side not.**

| Gate | Status |
|---|---|
| Realisability clears | **On paper only** — L/r 2.0 → 1.5 at 6 lines: demand 1.147 → 0.871, airborne mass −0.3 % |
| Code implements the ruled **taut** back line | **No** — `lift_chain_design` / `design_axial_preload` still solve the sky-anchor balance **slack** (`initialization.jl:920-926`) |
| Static equilibrium solver | **No** — does not converge; the 09-14 candidate could not land |
| Wobble gate implemented | **No** — every FoS still depends on `lin_damp` |
| Exit gate (acceptance 8/8 unrebased, load split re-derived, V2/V3/V6) | **0 of 4**; acceptance at 4/8 |
| Candidate through the evaluator | **Not run** |
| Lift requirement documented | Facility exists; the 1.5 has no basis |

**The dominant gap: the ruling lives in `DECISIONS.md` and a probe, not in
`src/`.** Until the taut load split is in the code, no evaluator run reflects it.

In order:

1. **Run the candidate through the evaluator** — the one measurement that turns
   the first row from "on paper" to "measured":
   `[2.6, 0.575, 1.5, 6, 0, 3, 11, 11, 0.8, 0.8]`. Watch the **lift chain
   connect** — the 09-14 candidate disconnected it (bridle 525.7 → 0.000 N).
2. **Put the taut load split into `src/`** — replace the slack sky-anchor solve.
3. `ACTIVE.md` item 2 remainder, then item 3 (static solver by dynamic
   relaxation), then the wobble gate, then the exit gate.

## 12. Housekeeping

- Committed this session. `scratch/hermes_probe_*.jl` (4 files, dated 09-14,
  another agent's) are left **untracked deliberately** — not this session's work.
- `ACTIVE.md` is now the single priority list; the per-handover priority lists
  are superseded and should be treated as history.
- Acceptance suite untouched at 4 of 8 failing — its pre-existing state.
- Ready to run on the desktop PC: nothing in this commit changes `src/` behaviour
  (the cone change is behaviour-preserving; the rest is comments and docs).
