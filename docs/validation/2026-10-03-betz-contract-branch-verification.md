# Betz contract branch (e632f83) — independent verification (2026-10-03)

Author: software-validator. Independent of @software-worker's report.

## Revision pinned

- `origin/betz-contract-projection` = **`e632f83`** (`e632f83b9ebba8c7ef4b950cc64ac64a1c928b33`).
- Single commit, parent = `f9f3182` (D1 tip). Diff scope: `src/objective_evaluator.jl`
  only — **+47 / −15**. Matches the report.
- Verified in a clean worktree at e632f83: `/home/rod/Documents/GitHub/.vt-betz-sv`.

## Gates

| Check | Expected | Measured | Consequence |
|---|---|---|---|
| Fast unit suite @ e632f83 | 2435/2435 | **2435 Pass / 2435 Total**, exit 0, 2m52.8s | no regression — but see scope note |
| Diff scope | one file | `src/objective_evaluator.jl` only | as claimed |
| Contract arithmetic (re-derived) | A_zn 29.555903 | **29.555903388447888** | correct |
| Un-fold inverse | algebraically exact | reproduces pinned `raw_annulus` 34.77672218884952 | correct |
| betz × queue-WIP merge | clean | `git merge-tree --write-tree` → **0 conflicts** (base 4d1b6c9) | combined landing clean |
| betz test file runs? | (implied pass) | **aborts at line 106** | contract pins are UNTESTED |

### Scope note on the 2435

The test that covers the new contract — `test/test_betz_ceiling_projection.jl` — is
**untracked**, and the branch's committed `test/runtests.jl` does **not** include it.
So the 2435/2435 run contains no assertion about `main_rotor_bank_projected_area` or
`betz_wind_normal_area`: it is a no-regression result on the pre-existing suite, not a
verification of the new contract.

### Independent re-derivation (my probe, not the test's)

`scratch/sv_probe_betz_azn.jl`, run against the branch's own `src`:

```
r_ring      = 3.8346727372      span = 1.348532145
raw_annulus = 34.77672218884952   (test pins 34.7767221889)
A_bank      = 34.12821755492592
A_zn        = 29.555903388447888  (test pins 29.555903; residual 3.9e-7 < rtol 2e-6)
A_ZY        = 30.117524875897654  (test pins 30.117525)
```

The un-fold `r_ring = 0.3·r_out + 0.7·r_in`, `span = r_out − r_in` is the exact algebraic
inverse of the decoder's ring-anchored 70/30 fold; it reproduces the pinned raw annulus.
The arithmetic is right.

### The betz test does not run

`test/test_betz_ceiling_projection.jl:103-106` builds `CASES` with
`d = decode_winner(x; L=L18, KW=KW)`. `decode_winner` lives in the **uncommitted**
`scripts/ode_gate_v13.jl` refactor, so the file errors **before** the outer testset:

```
bank-derate winner, bank 10.7399 deg | 1 Pass 1 Error Total 2
UndefVarError: `decode_winner` not defined
```

Sections 1–5 (the un-fold check, the A_zn reconciliation at `:223`, the cos¹-per-projection
split, the raw-helper guard) therefore **never execute**. Their pins are untested, not
passing — the value happens to be right (re-derived above), but nothing in the suite
measures it. Both red-first files the wiring slice carries (`test_winner_decode_invariant.jl`,
`test_betz_ceiling_projection.jl`) share this `decode_winner` dependency, so the wiring is
blocked until `ode_gate_v13.jl` lands — a double dependency, not a single red.

## Verdict

Commit code: correct, in scope, and merge-safe (combined landing conflict-free).
Contract: **verified by re-derivation, but not by any running test** — the branch is a
no-regression landing, and its contract stays parked with the untracked test.
