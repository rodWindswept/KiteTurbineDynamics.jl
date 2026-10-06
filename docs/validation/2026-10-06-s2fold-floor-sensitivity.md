# The floor screen for the S2 fold, and the λ scope of the Cp no-op (2026-10-06)

Author: science-validator. Revision: `613f3de` (origin/s2-fold-seed). Probe: `scratch/sv_probe_floor_613f3de.jl`. Log: `.julia_depot/logs/sv_probe_floor_s2fold_613f3de.log`.

This record gives two readings for the committed 5 kW seed (`S2_FOLD_SEED`, n = 3). The first is the Betz floor screen under different charge shapes. The second is the Cp convention. The probe uses the same call chain as the evaluator pre-gate (`betz_wind_normal_area`, `objective_evaluator.jl` lines 1073 and 1079). A pre-gate quantity needs no ODE run.

## Verdict

- As coded, the floor screen reads the seed at **4.7981 kW** against the **4.0 kW** bar (`0.8 × p_floor_kw = 4.0`). The seed passes by 0.80 kW.

- An elevation-matched charge (`× 0.866025^1.65 = 0.788725`) reads **3.784 kW**. That is 0.22 kW under the bar.

- If the ruling rematches the bank projection as well (`× 0.9713`), the reading is **3.676 kW**. That is 0.32 kW under the bar.

- The floor numbers aero-validator quoted in the room reproduce to the digit.

- `cp_bem(3, λ)` matches `cp_at_tsr(λ)` to below `1e-9` on λ in [0, 9.6). The committed table turns negative just past λ 9.6, and the non-negativity clamp of `cp_bem` starts there. The fold flies at λ 6.61 (kretune B1 row). That sits deep inside the identity range. The Cp convention is a no-op for this seed.

**Decision in play:** the floor-shape ruling, for this seed. The readings that decide it: 4.7981 kW as coded, against 3.784 kW elevation-matched, bar 4.0 kW.

## The n-family, static

| n_lines | basis | elevation match | bank match |
|---|---|---|---|
| 3 | 4.798 | 3.784 | 3.676 |
| 4 | 4.601 | 3.629 | 3.525 |
| 5 | 4.616 | 3.641 | 3.536 |
| 6 | 4.733 | 3.733 | 3.626 |
| 7 | 4.910 | 3.873 | 3.762 |
| 8 | 5.132 | 4.048 | 3.932 |
| 9 | 5.394 | 4.254 | 4.132 |

All columns in kW. Under a matched elevation charge, only the n = 8 and n = 9 rows clear the 4.0 bar. Under the bank match, only n = 9 clears it.

## Evidence

- Evaluator formula: `Betz_cp_kW = p.cp * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0`. Gate: `Betz_cp_kW < cfg.p_floor_kw * 0.8`.

- Inputs at the tip: `p.cp` 0.16, `rho` 1.225, `cfg.v_rated` 11.0, elevation 30.0 degrees.

- Cos factors: `cosd(30)^1` 0.866025, `cosd(30)^2.65` 0.683056, ratio 0.788725 (26.8 per cent).

- Probe log, all rows: `.julia_depot/logs/sv_probe_floor_s2fold_613f3de.log`, tree `613f3de`, run 2026-10-06.

## Notes

- No `src/` or `test/` writes. The probe ran in a science-validator scratch worktree at `613f3de`.

- Scope note for the Cp series. Past λ 9.6 the n ≥ 4 rows flip sign when the ratio and the base are both negative. `cp_bem(6, 10)` reads +0.342, against the documented clamp to 0. No current machine flies there.

Rerun: `scripts/ktd-julia scratch/sv_probe_floor_613f3de.jl` (with `JULIA_DEPOT_PATH` stacked on the main depot).
