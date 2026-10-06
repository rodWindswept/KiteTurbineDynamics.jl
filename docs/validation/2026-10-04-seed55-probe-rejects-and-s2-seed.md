# 5.5 kW seed probe: all four rejects, cause measured, and a scoreable 5.12 kW seed exists

Author: science-validator (2026-10-04). Revision: `f225e95` (= origin/bank-derate-cos2p65 at time of writing). Independent of the @hermes probe premise. STE pass 2026-10-06: no numbers or findings changed.

## Verdict

1. `scratch/hermes_probe_seed_55.jl` at HEAD: **all four cases `:reject`**. The twist did not cross. Window ratios: 0.6181 / 0.5451 / 0.6055 / 0.5973. The premise of the probe is era-dead (recorded winner = a 5.11 kW control under the current evaluator).

2. Cause, measured: the recorded bank-derate winner is a **pre-D1 genome**. Under the current (D1 site-wind) decode it is a **~3.78 kW machine**. The **Betz-floor pre-gate** of the evaluator (`cp·A_ZY·½ρv³ = 2.659 kW < 0.8·5.0 kW`) hard-rejects it with zeroed fields before scoring. Bisect: relaxing only `p_floor_kw` to 0.01 turns the same run `:ok` at P_end 3.7829 kW.

3. The bound box of the DE itself **does** contain a scoreable class: **S2** = winner genome with `r_hub 3.8347→4.32` (bound) and `blade_scale_top 0.6994→1.0` (bound). It measures **`:ok`, P_end 5.1218 kW, FoS 5.20, twist 0.392, stationary, no breaks**. Cold start, full regime, floor live.

## Evidence (all at f225e95. Logs in `.julia_depot/logs/`)

| # | source | key numbers |
|---|---|---|
| 1 | `hermes_probe_seed_55.log` | 4/4 reject. Twist 0.6181 / 0.5451 / 0.6055 / 0.5973, none crossed. |
| 2 | `sv_probe_seed55_why_reject.log` | reject with zeroed fields. ω_eq 10.7569 kept. Decode: A_ax 23.9801 m², A_ZY 20.3868 m², floor-gate basis 2.659 kW. Ceiling basis: 9.856 kW. |
| 3 | `sv_probe_seed55_bisect.log` | floor 0.01 ⇒ `:ok`. P_mean 3.7636, P_end 3.7829, FoS 8.9762, twist 0.6181. Stationary, T_lift 172.0 N. |
| 4 | `sv_probe_seed55_candidates.log` | static S0–S5 table (areas/basis/clearance). S2 ODE: P_mean 5.1138, **P_end 5.1218**. FoS 5.2028, ω 10.8627 (tip 57.2 m/s), twist 0.3923. Fitness 33.259, T_lift 362.5 N, clearance 5.76 m. |
| 5 | `docs/validation/2026-10-03-acceptance-reds-attribution.md` (software-validator) | class cross-ref: seed genome pre-D1 :ok 5.422 kW → post-D1 :reject 3.567 kW. |

Recorded-era values (telemetry git `ee6c64f`): winner `status=ok`, P_end 5.11 kW, FoS 9.38, all pre-D1.

## Notes

- Winner perturbations cannot close the gap. The four probe cases move area by ≤ +9 %. The gate needs ≈ +50 % (A_ZY ≥ 30.6 m²). Even S1 (r_hub bound alone, +12.6 % linear) reads only 2.98 kW of basis.

- Linear A→P scaling **overshoots** on this class. S2: estimated 6.17 kW, measured 5.12 kW. Efficiency falls with scale. ODE numbers win.
- `r_bot` is inert for the main annulus in 1-rotor mode (S2 ≡ S3 rows in the screen).

- S2 sits at two gene bounds. It stays in-box for `tight_bounds(seed_genome(5.0))` (r_hub hi 4.32, blade hi 1.0). A seed at 2 pinned genes is a judgment call for the owning role.

- The 5.5 kW target: **not reached** by the single-rotor bound-box class probed here. Max A_ZY 33.25 m² → 5.12 kW measured. Levers: DE search over multi-rotor stacks, or a bounds/architecture decision.

- Minor record inconsistency: recorded clearance 3.0 m (ee6c64f) vs current-decode 6.45 m (S0). Flagged for the owning role. Possibly the D1 decode moves the ring stack. S2 reads 5.76 m ≥ 1.5 either way, so the campaign gate is not at risk.

## Next (room)

- @software-worker: cold re-measure of S2 outside the probe harness (the independent reproduction). Then seed the re-based campaign from S2-class under D1.
- @aero-worker: no ≥5.5 case exists to review. If wanted, S2 is the review target. Span 1.356 m, twist 0.392, tip 57 m/s, FoS 5.2.

Rerun: `scripts/ktd-julia scratch/sv_probe_seed55_why_reject.jl` / `..._bisect.jl` / `..._candidates.jl`. Logs: `.julia_depot/logs/sv_probe_seed55_*.log`. New record. No `src/` or `test/` writes.
