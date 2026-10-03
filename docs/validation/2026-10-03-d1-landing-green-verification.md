# D1 landing — independent verification of the green suite (2026-10-03)

Author: software-validator. Independent of @software-worker's own run.

## Revision pinned

- `origin/bank-derate-cos2p65` = **`f9f3182`** (`f9f31828a93fe782674371edc94e317891170265`).
- Three commits present, exactly as reported:
  - `6f4cdbe` feat: land D1 site-wind standard, kill the 50 m decoder anchor
  - `ac781a6` docs: D1 dated DECISIONS entry + Defect-D supersession
  - `f9f3182` test: re-baseline the L/r 2.0 realisability fixture for D1 site-wind
- Local branch `bank-derate-cos2p65` in the main tree is still at `4d1b6c9`; only origin moved.
- Verified in a clean worktree at f9f3182: `/home/rod/Documents/GitHub/.vt-f9f3182-sv`
  (placed as a GitHub sibling so the `../CoaxialAutogyroStacking.jl` dev path resolves).
  Working tree clean; the shared main tree's queue WIP was never touched.

## Gates

| Check | Expected | Measured | Consequence |
|---|---|---|---|
| Fast unit suite @ f9f3182 | 2435/2435 | **2435 Pass / 2435 Total**, exit 0, 2m54.1s | pass confirmed independently |
| Commit set on origin | 3 commits, head f9f3182 | exact | as landed |
| Dated DECISIONS entry | `[2026-10-03]` D1 | present | recorded |
| `DECISIONS.md:319` supersession | tagged | “SUPERSEDED (2026-10-03, D1)” present | recorded |
| Fixture wind closure | derived, no re-typed literal | `wind_at_altitude(p.v_wind_ref, p.h_ref, z; hellmann_exponent=SITE_DAISY.shear_exp)` | derived (Rod's point applied) |
| `settle_case_builders.jl` winds | derived | `ObjectiveConfig(v_rated=p.v_wind_ref)`, `sized_lifter_for(v_ref=p.v_wind_ref)` | derived |
| Merge vs queue WIP | clean | `git merge-tree --write-tree f9f3182 × WIP` → 0 conflicts | clean later |
| bem_unified identity guard | present | `p.v_wind_ref ≈ site_wind(p.h_ref)` over 7 factories + `mass_scale` | guard landed |

The fixture's own pins recompute to the reported values (preload 1116.10 → 688.87 N,
max demand 0.88123 → 1.44589, saturating 90°); the suite passing means the fixture
recomputed and matched those pins — i.e. the re-baseline is a measured flip, not a re-typed one.

## Residual-hardcoded-exponent census — the quoted list is short

The D1 “Open” note names three `src/` closures. Re-grepped the whole tree at f9f3182:

| Site | Quoted | Measured |
|---|---|---|
| `src/sim_runner.jl` | 6× | **6** ✓ |
| `src/control_map_hunt.jl` | 3× | **3** ✓ |
| `src/visualization.jl` | 7× | **8** ✗ (lines 675, 680, 685, 690, 695, 706, 713, 719) |
| `src/objective_v6.jl` | (implicit) | false positive — `Re^(1/7)` skin-friction, not wind shear |

Beyond `src/` (outside the DECISIONS “Open” note's scope, ranked by blast radius):

- **8 shipped sweep scripts** define `const WIND_MS = 11.0` as their wind closure:
  `catalog_sweep`, `feasibility_sweep`, `kickstart_sweep`, `kickstart_sweep_12gon`,
  `kickstart_sweep_dual`, `kickstart_sweep_triangle3`, `recheck_12gon_convergence`,
  `sensitivity_alpha_constants`.
- **101 scripts** in total contain the `(z/p.h_ref)^(1/7)` idiom.

Consequence: the residual is one law hardcoded in the third `src` path **and** in the
campaign/sweep scripts — a non-anchor `at_site(...)` re-base would move the ODE and decoder
while those silently kept flying 1/7.
