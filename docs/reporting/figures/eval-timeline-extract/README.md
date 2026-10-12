# Eval-timeline extract (F3)

This folder holds the data behind the F3 figure. It covers the winner run.
The cold file carries three certificates. They appear below.

## Sources

The winner is island 3 of the file
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/best_vector.csv`.
The probe decodes it and evaluates it as `run_v13_5kw_masslift.jl` does.

Tree: `980de02`. Physics era: `post-95c385d_wind-authority`.

## Files

| file | content | rows |
|---|---|---|
| `extract-eval-timeline-cold.csv` | as-coded `:cold` run, 100 Hz samples, 0 to 50 s | 5000 |
| `extract-eval-timeline-warm.csv` | as-coded `:warm` run, one row per step, `s = 1..98` | 98 |
| `extract-eval-timeline-warm-rulingmode.csv` | warm-start condition run, see below | 1823 |

Each CSV carries a provenance header. The header names the run, the tree and
the path.

The warm run ends at the rope-break latch. The latch sits at `t = 2.84 ms`.

The ruling-mode file is a condition run. It uses a different rope-break gate:
the gate is off for `t < 10 s` and on for `t >= 10 s`. This matches the
pending 2026-09-16 placement.

Samples: every 20 steps for `s <= 2000`, then every 1000 steps.

## Columns

`t, omega_gnd, omega_hub, P_gen_kw, tau_gen_Nm, strain_max_over_break, any_broken`

- `omega_gnd`, `omega_hub`: ground-ring and hub-ring rates in rad/s.
- `tau_gen_Nm`: generator torque from the load law, with `k = 2.24` and a payout factor.

- The load law reads the hard-coded payout `0.1 m` from `objective_evaluator.jl:619-621`.
- The factor is `1 - 0.1/9.4 = 0.9893617021276596`.
- `P_gen_kw`: `tau_gen * omega_gnd / 1000`, the scored definition. No filter, no loss.

- `strain_max_over_break`: peak path strain over `0.035`, the rope break strain.
- The probe replicates the rope sub-segment geometry for this column.
- `any_broken`: the rope-break latch at the sample instant.
- The ruling-mode file omits `tau_gen_Nm`. Recover it with `P_gen_kw * 1000 / omega_gnd`.

## Certificates

1. Cold parity against the recorded cold re-eval (NR-012). The difference is `0.0` on four fields: fitness, `P_mean`, `P_end`, `omega_eq`.
2. `capture_extended` parity: `|dP_kw| = 0.0` at five instants, `t = 15/25/35/45/50`.
3. Torque law: per-sample `tau/(2.24*w^2)` equals `0.989361702127660`. The minimum and the maximum hold 15 significant digits.

## The warm run

At `980de02`, the as-coded `:warm` path rejects the winner (NR-013).

The warm seed writes `v = omega_eq * |pos| * tang_z` into each ring centre.
That seed lives at `objective_evaluator.jl:823-834`.

The seed drives rings 2 to 6 at 33.7, 67.4, 101.1, 134.8 and 267.9 m/s.
It adds 204.9 kJ of translational energy. The hub takes 152.4 kJ.

The cone segments absorb the pull. S4 line 3 crosses the break strain at
step 97-98, at `t = 2.84 ms`. The latch ends the run.

The ruling-mode run survives the transient. Its true peak is `1.448` times
break strain at `t = 5.74 ms`. The strain decays after that.

The machine completes 50 s with no window latch. It flies at 12.31 to
12.64 rad/s and 4.50 to 4.96 kW. Both sit below the 5 kW floor, and below
the cold point (13.38 rad/s, 5.31 kW).

Label this file as a condition run in any plot.

## Regeneration

```bash
scripts/ktd-julia scripts/probe_eval_timeline.jl       # cold + warm CSVs
scripts/ktd-julia scratch/av_f3_warm_diag2.jl          # ruling-mode CSV + seed exhibit
```

Logs: `.julia_depot/logs/av_probe_eval_timeline.log` and `.julia_depot/logs/av_f3_warm_diag2.log`.
