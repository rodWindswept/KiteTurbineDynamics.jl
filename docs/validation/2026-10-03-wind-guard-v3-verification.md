# Wind-authority guard v3 `0de1c33` — both notes closed, verified (2026-10-03)

Author: software-validator. Third commit on the guard chain. Re-runs my two residual notes.

## Revision pinned

- `origin/av-wind-authority-guard` = **`0de1c33`**, third commit (parent `c4fe89b` confirmed).
- Scope: **`test/test_wind_authority.jl` only** (+19/−10). No `src/` change.
- Chain on origin: `f225e95 → a5be67f → c4fe89b → 0de1c33`.

## Note 1 — the crash is gone

`evaluate_exponent` now strips outer parentheses and trailing `/`/`.` , then returns **NaN** for
anything that is not a clean numeric token. Measured on the two capture forms that used to throw:

| form | capture | v2 | v3 |
|---|---|---|---|
| `z^2/(2*9.81)` | `2/` | `ArgumentError` | `2.0` — no throw |
| `x^3/x` | `3/` | `ArgumentError` | `3.0` — no throw |

## Note 2 — the double-paren case is gone

Regex is now `\^\(*([0-9][0-9./)]*)`. On a **non-`h_ref` base**, where the shape clause cannot help:
`(z/9.412)^((1/7))` → capture `1/7))` → normalised to `1/7` → **0.142857 → TRIPS**. Verified.

Bonus, same mechanism: equivalent-fraction spellings also land — `^(7/49)` and `^(2/14)` both
normalise to 0.142857 and trip.

## RED arm reproduced — exact match

6 `site_shear(` calls intact, four probes **added** (`^(1/7.0)`, `^(0.142857)`, `^((1/7))` on a
non-`h_ref` base, and `z^2/(2*9.81)`):

**35 pass / 4 fail / 0 errored / 39 total** — shape clause fires once (`:89`), value clause three
times, the division probe passes. Exactly the arm @aero-validator reported.

## No false positives, count unchanged

Every capture in the three real files evaluates clean — `visualization` 10 × `2.0`,
`control_map_hunt` `3.0`, `60.0`, `60.0`, `sim_runner` 0. **13 captures → 35 checks**, so the
standalone run is **35/35 as landed** and the suite total stays **2542**.

## Residual (honest scope, one item)

The NaN path trades a crash for a silent pass: a token that does not normalise to a clean numeric
(e.g. the capture from `(z/9.412)^(1)/(7)`) returns NaN, and `abs(NaN - 1/7) < 5e-3` is false, so
the assertion passes. That form is not valid Julia as a shear, so the exposure is nominal — and it
is the right trade against throwing. Worth naming so a future reader does not read NaN as "checked".

**On `^(ALPHA)`: the exclusion is right and I agree with the reasoning.** A named constant read
from the site spec is the target state, not a blind spot — forbidding identifier exponents would
forbid the fix. The one thing it leaves open is that nothing yet asserts such a constant *is*
defined from `SITE_ANCHOR`. That belongs with the `v_rated`/Cp pins, as @aero-validator says.

Probe: `scratch/sv_probe_guard_v3.jl`. Log:
`~/.hermes/profiles/software-validator/cache/scratch/fast_guard_0de1c33.log`.
