# test/archive — retired test files (R10, 2026-09-10)

These files were **removed from `test/runtests.jl`** because they assert only
code the v13 pipeline never calls. They are kept here for provenance, not run by
CI, and a green run here is **not** a v13 health signal.

Classification from `docs/reports/2026-09-08-test-suite-inventory.md` (the
2026-09-08 test-appropriateness audit):

| File | Why archived |
|---|---|
| `test_parameters.jl` | pins `params_10kw` (DRR-theory anchor); the v13 chain anchors on `params_daisy`. |
| `test_expansion_stack.jl` | exercises `build_expansion_stack`, whose only src caller is the legacy `objective_v6`. v13 rotors come from the decode + `expansion_params_from_rotors`. |
| `test_trpt_axial_profiles.jl` | the whole v2 `TRPTDesignV2` / `r_of_z` / axial-profile family, removed from the physics in v4 (`DECISIONS [2026-04-22]`). |
| `test_physics_path_guard.jl` | guards the **static** `objective_v10` solver, which no v13 entry point calls. The live ODE-path guard is `test/test_physics_path_ode.jl` (acceptance, 2026-09-08 guard 2). |

**Era-pinned (still in the fast suite, with an `ERA PIN` header):**
`test_blade_geometry.jl`, `test_documented_claims.jl`, `test_lift_kite_rotary.jl`
— provenance value, but they cannot fail on v13 drift.

**Still to do (follow-up):** the museum-pin *testsets* inside live files
(first seven testsets of `test_builders_v10.jl`; testsets 4-6/8-9 of
`test_ring_spacing_v4.jl`) were not split out here.
