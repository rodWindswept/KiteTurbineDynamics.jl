# Window-trace extract: the scored tap grid

This folder holds the taps behind the section 2.3 evaluator-protocol
plate (roster row 4). It covers the winner run on the cold path. The
dense cold curve, the warm path and the ruling-mode run live in
`../eval-timeline-extract/`.

## Sources

The winner is island 3 of the file
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/best_vector.csv`.
The probe `scripts/probe_window_trace.jl` decodes it and evaluates it as
`run_v13_5kw_masslift.jl` does. The probe keeps the tap samples.

Tree: `8d01394`. Physics era: `post-95c385d_wind-authority`. The probe
script last changed at `b665e6e` (the NR-029 basis).

## Files

| file | content | rows |
|---|---|---|
| `extract-winner-window-taps.csv` | the kept tap grid, cold path, 0 to 50 s | 52 |
| `extract-winner-window-taps.log` | the full run log, with the parity certificate | 1 |

Each CSV carries a provenance header. The header names the run, the tree
and the path.

## Columns

`t_s,step,omega_hub,omega_gnd,phase`

- `t_s`, `step`: the sample time and the integration step at the tap.
- `omega_hub`, `omega_gnd`: hub-ring and ground-ring rates in rad/s.
- `phase`: `relax` for `t < 10 s`, `window` for `t >= 10 s`.

The probe keeps a tap when at least 0.999 s has passed since the last
one. The probe always keeps the first and last steps. The grid holds 52
taps: 11 relax and 41 window.

The window mean reads from the window taps. These are the samples the
evaluator scores.

## Certificates

1. Cold parity against the recorded cold re-eval (NR-012). The difference
   is `0.0` on four fields: fitness, `P_mean`, `P_end`, `omega_eq`.

2. Window mean, ground ring: `13.380259861740395`. That value is NR-029.
   A mean recomputed from the CSV reproduces the value exactly.

3. Lambda on the window mean: `5.565968202980965` (ground ring) and
   `5.56592352649632` (hub). Those values are NR-031.

## Hashes

- CSV sha256: `73132bdcb477d2b890f3940b8e690982e694296a016dee72fd4ea7936dce4e66`
- Log sha256: `59a53ff4e2ff95e1ed6015881a5b81f02eaf7faf4038c2f9c6d50cc61df96899`

## Regeneration

```bash
scripts/ktd-julia scripts/probe_window_trace.jl
```

The run writes to stdout. The 2026-10-12 run log sits at
`scratch/av_probe_window_trace_2026-10-12.log` (local-only) and as the
`.log` file in this folder. A rerun reproduces the extract bit for bit.
