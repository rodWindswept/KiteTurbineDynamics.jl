# Wind-authority guard v2 `c4fe89b` — hole closed, verified (2026-10-03)

Author: software-validator. Re-runs the exact hole test that opened this, against the fix.

## Revision pinned

- `origin/av-wind-authority-guard` = **`c4fe89b`**, second commit (parent `a5be67f` confirmed —
  additive, no force-push).
- Scope: **`test/test_wind_authority.jl` only** (+33/−6). No `src/` change.
- Stack on origin: `f225e95 → a5be67f → c4fe89b → 3f589dd → 92c4cef`
  (`acceptance-records-2026-10-03-v2` @ `92c4cef`).

## The hole is closed

Re-running my exact opening test — all 6 `site_shear(` calls intact, two live wind closures
**added, not substituted**, in the spellings the exact-string form missed:

| arm | at `a5be67f` (v1) | at `c4fe89b` (v2) |
|---|---|---|
| two injected `^(1/7.0)` + `^(0.142857)` closures | **25 pass / 25 — invisible** | **34 pass / 3 fail / 37** |

Failures at v2: the SHAPE clause (`:75`, `!occursin("h_ref)^", flat)`) fires once, the VALUE clause
(`:80`) twice. Exactly @aero-validator's reported RED arm.

Every spelling that slipped v1 now trips: `^(1/7.0)`, `^(1//7)`, `^(0.142857)`, `^(0.14)` — and
the VALUE clause also catches a shear written against a **non-`h_ref` base** (`(z/9.412)^(1/7)`:
shape `ok`, value `TRIPS`), which the shape clause alone would miss. That is the right division of
labour between the two clauses.

Check count reconciles: §1 13 + §2 3 + §3 (2 + 12 + 5) = **35**, matching the standalone run.

## Two residual notes (honest scope, neither weakens the guard)

`scratch/sv_probe_guard_v2.jl`, run over the three files' real captures
(`sim_runner` 0 matches; `visualization` 10 × `2`; `control_map_hunt` `3`, `60`, `60`):

1. **Latent crash, not a silent pass.** `evaluate_exponent` throws `ArgumentError` on a capture
   ending in `/` — a future legitimate edit like `x^2/(2*g)` makes the guard **error** instead of
   reporting. It fails loud, so protection is intact; it will just read as a broken test.
   Cheap hardening: strip a trailing `/` before splitting.
2. **Two contrived blind spots**, both requiring a non-`h_ref` base: a doubly-parenthesised
   exponent (`(z/9.412)^((1/7))` — value regex takes 0 captures) and a named-constant exponent
   (`a^(ALPHA)`). For the `h_ref` base the shape clause catches both. Not reachable from any form
   the codebase uses today.

Neither is a gate. The guard does what it claims.

## Stands

- v1 → v2 is a genuine fix, not a widening: the clauses are generic, and the current files carry
  no false positive (35/35 as landed).
- @aero-validator's corrected numbers are right: standalone 35/35 (superseding 25), suite
  **`2507 + 35 = 2542`** (superseding 2532).

Probes: `scratch/sv_probe_guard_v2.jl`; log
`~/.hermes/profiles/software-validator/cache/scratch/fast_guard_c4fe89b.log`.
