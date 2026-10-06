# Wind-authority guard `a5be67f` — verified, teeth reproduced, one coverage hole (2026-10-03)

Author: software-validator. Independent of the run by @aero-validator.

## Revision pinned

- `origin/av-wind-authority-guard` = **`a5be67f`**, one commit on `f225e95` (parent confirmed).
- Scope: `src/{KiteTurbineDynamics,control_map_hunt,sim_runner,visualization,wind_profile}.jl`
  + `test/runtests.jl` (1 include) + `test/test_wind_authority.jl`. Nothing else moved.
- `origin/acceptance-records-2026-10-03` = `e619556`, one commit on `a5be67f`. Its delta is
  docs + probes only (6 files, no `src/`, no `test/`).

## What verifies

| check | expected | measured |
|---|---|---|
| 17 literals retired | 0 left in the 3 files | **0** (`sim_runner` 0, `visualization` 0, `control_map_hunt` 0) |
| `site_shear` calls | 6 / 8 / 3 | **6 / 8 / 3** |
| single authority | reads `SITE_ANCHOR.shear_exp` | `wind_at_altitude(1.0, h_ref, h; hellmann_exponent=SITE_ANCHOR.shear_exp)` |
| checks in the new file | 25 | **25** (25/25 standalone) |
| count arithmetic | 2507 + 25 | **2532** ✓ |
| negative control | source pin fails, behaviour passes | **reproduced: 23 pass / 2 fail** |

`grep -c '1/7'` over the whole `src/` tree still returns `objective_v6.jl` (the `Cf ≈ 0.027/Re^(1/7)`
skin-friction comment — unrelated) and `wind_profile.jl` (the `site_shear` docstring quoting the
retired spelling). Both are prose, not live closures.

### Teeth — reproduced independently

ARM 1 (as landed): **25 pass / 25**.
ARM 2 (`src/sim_runner.jl` restored to the `f225e95` literal form, helper present):
**23 pass / 2 fail**, both failures in the source-pin section. **Sections 1 and 2 (every
behaviour check) still pass**. That is exactly the control @aero-validator reported, and it is the
justification for the source assertion in one line: at the anchor the literal is bit-identical to
the spec, so only a source pin has teeth.

## Coverage hole — the source pin matches exact spellings only

The pin strips whitespace (`flat = replace(src, r"\s+" => "")`) — so `(1.0 / 7.0)` **is** caught,
which is the right call. But it then matches only two exact strings:
`!occursin("1.0/7.0", flat)` and `!occursin("^(1/7)", flat)`.

**ARM 3 (measured):** with all 6 `site_shear(` calls intact **and two live wind closures re-typed**
as `(z / p.h_ref)^(1/7.0)` and `(z / p.h_ref)^(0.142857)`, the guard reports **25 pass / 25** —
the regression is invisible.

Variants that slip the pin: `1/7.0`, `1//7`, `0.142857`, `0.14`, and `^(1 / 7.0)` (which the
whitespace strip collapses to `^(1/7.0)` — still matching neither literal).

**Fix shape (small, same site):** add the numeric-exponent forms to the negative set, e.g.
`!occursin(r"\^0\.14", flat)` and `!occursin("1/7.0", flat)`, or match the exponent generically
(`r"\^\(?1\s*/\s*7"`). The counted `site_shear(` clause already holds the positive direction.

## Stands

- Not a gate for anything downstream: the effect of the guard is correct (numerically identical at
  the anchor, correct off it) — the hole is in the **regression pin**, not in the code it guards.
- The two scoping notes from @aero-validator are accurate: it pins the shear exponent only, and
  `v_rated` / the Cp convention are correctly excluded pending their rulings.

Probe logs: `~/.hermes/profiles/software-validator/cache/scratch/fast_guard_a5be67f.log`.
