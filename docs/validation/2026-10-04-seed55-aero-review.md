# Validation Report: Aero Review of Seed S2 (and the n_lines / Bank Levers)
**Date:** 2026-10-04  
**Author:** `@aero-validator`  
**Git tree:** `f225e957f05e403972ada4193d73f4d969432641`  
**Target:** Seed candidate S2 (`r_hub=4.32, blade_top=1.0`) from `docs/validation/2026-10-04-seed55-probe-rejects-and-s2-seed.md` under post-D1 evaluator rules.

---

**STE pass 2026-10-06:** no numbers or findings changed.

## 1. Executive Summary

- **S2 aero review verdict:** **PASS.** S2 is aerodynamically viable, structurally benign, and operates comfortably inside every physical limit.
  - **Power:** $P_{\mathrm{end}} = 5.1218\,\mathrm{kW}$ (cold-start tail-5 on the full $40\,\mathrm{s}$ regime, $p_{\mathrm{floor}}=5.0\,\mathrm{kW}$ live).
  - **Twist collapse margin:** `twist_ratio` $= 0.3923$ (well below the $1.0$ discrete-truss crossing bound).
  - **Blade tip speed:** $57.24\,\mathrm{m/s}$ (vs. the $100.0\,\mathrm{m/s}$ ceiling; headroom $= 42.76\,\mathrm{m/s}$).
  - **Structural factor of safety:** $\mathrm{FoS}_{\mathrm{min}} = 5.2028$ (vs. hard gate $2.5$).
  - **Stationarity:** `:ok`, no drift, no line breaks, single active rotor ($N_A = 1$).

- **Key aerodynamic insight (the untouched levers):**
  The static screen that produced S2 held `n_lines = 3` and `bank_top = 10.74°` fixed.
  1. **$n_{\mathrm{lines}}$ lever:** In the closed-form sizer, $c_{p,\mathrm{BEM}}(n, \lambda=4.1)$ drops with line count ($0.3576$ at $n=3 \to 0.2110$ at $n=9$), which sizes a larger annulus ($A_{ZY} = 33.25\,\mathrm{m^2} \to 44.04\,\mathrm{m^2}$, span $1.36\,\mathrm{m} \to 1.77\,\mathrm{m}$). When flown under the full-regime ODE, **$n=9$ measures $P_{\mathrm{end}} = 5.4480\,\mathrm{kW}$, $\mathrm{FoS} = 7.75$, twist ratio $= 0.2962$, tip $= 57.23\,\mathrm{m/s}$**.
  2. **Bank derate lever:** Main-rotor torque is derated by $\cos^{2.65}(\theta_{\mathrm{bank}})$. At $\theta=10.74°$, the derate factor is $0.9546$ (a $4.5\%$ loss, equivalent to $\approx 241\,\mathrm{W}$). Reducing bank angle directly recovers this power.

- **Reseeding caveat for `@software-worker`** (corrected 2026-10-05):
  `tight_bounds` in `scripts/compute_seeds.jl` is *seed-relative* for `r_hub` on the hi side only: `r_hub` $\in [0.7,\ 1.8 s_1]$ — hi is the standing $+80\%$ spread, so the old ceiling $4.32$ was $1.8 \times 2.4$, never a set number; lo stays the absolute $0.7\,\mathrm{m}$ floor, decoupled. `blade_top` $\in [\max(0.05, 0.2 s_9),\ 1.0]$ — hi is the fixed $1.0$ stall cap. Folded in as the base seed, S2 re-centres the box to $r_{\mathrm{hub}} \in [0.7,\ 7.776]\,\mathrm{m}$ ($1.8 \times 4.32$), opening the searchable design space upwind on the documented law.

---

## 2. Re-measured Aero Metrics Table

All evaluations run against `ObjectiveConfig(p_floor_kw=5.0, v_rated=11.0, window_s=40.0, relax_s=10.0, k_mppt=3.864)` cold-start on tree `f225e95`.

| Candidate | $n_{\mathrm{lines}}$ | $r_{\mathrm{hub}}$ | $\mathrm{blade}_t$ | $\mathrm{span}$ (m) | $A_{ZY}$ ($\mathrm{m^2}$) | $P_{\mathrm{end}}$ (kW) | FoS | Twist ratio | Tip (m/s) | Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Recorded Winner (pre-D1)** | 3 | 4.00 | 0.80 | 1.18 | 27.20 | Rej ($<4.0\,\mathrm{kW}$ floor) | — | — | — | `Betz_pregate` |
| **S2 (live seed candidate)** | 3 | 4.32 | 1.00 | 1.36 | 33.25 | **5.1218** | **5.20** | **0.3923** | **57.24** | `:ok` |
| **S2 + $n=4$** | 4 | 4.32 | 1.00 | 1.42 | 34.95 | — | — | — | — | static |
| **S2 + $n=5$** | 5 | 4.32 | 1.00 | 1.49 | 36.78 | — | — | — | — | static |
| **S2 + $n=6$** | 6 | 4.32 | 1.00 | 1.56 | 38.65 | — | — | — | — | static |
| **S2 + $n=9$ (max annulus)** | 9 | 4.32 | 1.00 | 1.77 | 44.04 | **5.4480** | **7.75** | **0.2962** | **57.23** | `:ok` |

---

## 3. Logs and Reproduction Scripts

- Raw probe script: `scratch/av_probe_seed55_nlines.jl`
- Raw logs: `.julia_depot/logs/av_probe_seed55_nlines.log`
- Correction re-check (2026-10-05): `scratch/av_probe_s2fold_bounds.jl` (box `[0.7, 7.776]` and `seed_genome(5.0) == S2_FOLD_SEED` re-verified at tip `071fbee`); log `.julia_depot/logs/av_probe_s2fold_bounds.log`.
