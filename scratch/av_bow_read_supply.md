# Supply: the winner bow read (aero-validator seat, 2026-10-16)

**Machine** The bankderate2 island-3 winner genome (NR-005). Column 18.8 m. Elevation 30 deg. The top ring carries the main rotor.

**Bench** The NR-016 cold re-eval protocol. Relax 10 s + window 40 s. Kickstart off. `K_MPPT_5KW_HONEST`.

**Read at** Tip `4e9c6bd`. Script `scratch/av_bow_probe.jl`. Log `scratch/av_bow_probe.log`.

## 1. Bench gates

The read gates on the recorded NR-016 digits. All gates read true.

```text
bench gates vs recorded: fitness true (27.3635412663488)  omega_eq true  P_end true  twist true  FoS true
protocol gates vs phase 1: settle-omega true  P_end true  twist true  FoS true
```

## 2. The read (value / station / state)

Per-ring perpendicular offset from the design axis, in metres. The stations follow the 2026-10-15 naming rule.

```text
ring  s_axial   settle   win_min  win_mean  win_max   ext t=195
  1    0.000   0.00000  0.00000   0.00000   0.00000   -
  2    2.344   0.00132  0.02755   0.05705   0.07895   -
  3    4.689   0.00168  0.05422   0.11318   0.15692   -
  4    7.033   0.00171  0.08010   0.16843   0.23395   -
  5    9.376   0.00160  0.10531   0.22288   0.31005   0.42202
  6   18.714   0.00241  0.20862   0.44098   0.61302   0.83331
```

- **Midpoint ring (ring 5, the founder station).** The ring sits at `s_axial` 9.376 m of the 18.714 m span. The axial midpoint reads 9.357 m, so ring 5 is the nearest ring.

- **Hub (ring 6, the max station).** The raw read at t=200 s gives 0.833774 m.

- **State `settle`.** The operational settle output.

- **State `window`.** The scored measurement window (t = 11 to 50 s, 40 samples).

- **State `ext end`.** The extension run end (t=195 s sample, raw read at t=200 s).

- **Direction.** The offset runs straight down in the perpendicular plane. The down fraction reads 0.9999 at settle and 1.0000 at t=200 s. The sideways fraction stays under 0.003. No sideways drift appears.

- **Mapping clause.** The max station sits at the hub. The midpoint ring reads about half the hub value. The ratio reads 0.5058 at t=50 s and 0.5064 at t=195 s.

## 3. The extension run

The bow grows monotone and decelerates. The hub series reads 0.64199 m at t=55 s and 0.83331 m at t=195 s. The last increment reads +0.00053 m per 5 s at the hub, about 0.1 mm/s. The shape approaches a quasi-terminal value near 0.83 m at the hub. No line breaks: `any_broken = false` in both runs.

## 4. The September check (settle vs run)

The settle hands the machine off straight (max 0.00241 m). The run bows it (window mean 0.44098 m at the hub). The largest deviation reads 0.43857 m at ring 6 (settle against the window mean). The two shapes do not agree.

Per the 2026-09-15 ruling, a settle/ODE bow disagreement is an instrument finding. It is a re-initialisation or force-scaling bug, not a design question. The script prints that finding.

## 5. The founder line (same station, same state)

The founder measures bow as the midpoint ring belly drop from the common axis. This read meets that line at the same station and the same state.

Ring 5 reads 0.0016 m at settle. The window reads 0.10531 to 0.31005 m, and the extension end reads 0.42202 m. Every midpoint state reads below 0.5 m against the 1.5 m line.

Context only: the 2026-09-21 audit recorded the hub at 1.1 to 1.25 m on the earlier machine class. Rod ruled that reading expected. This machine reads 0.83 m at the hub. The machines differ, so this is not a comparison.

## 6. Proposed register row (NR-059, for the science seat)

| NR-059 | Winner bow (island 3) | midpoint ring settle 0.002 m, window 0.105 to 0.310 m. Hub max settle 0.002 m, window 0.209 to 0.613 m. Extension end midpoint 0.422 m, hub 0.833 m. Settle and run do not agree on the bowed shape | m | `scratch/av_bow_probe.jl` + `.log` | proposed (aero-validator, 2026-10-16) |
|---|---|---|---|---|---|

## 7. Evidence

- `scratch/av_bow_probe.jl` sha256 `24a1601718dcb2d8536872ca975b6a823fed640e72686486c434fdc6216c73a4`

- `scratch/av_bow_probe.log` sha256 `eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987`

- Iteration logs: `scratch/av_bow_probe_run1_buggy.log` (the scoping bug), `scratch/av_bow_probe_dbg.log` (the object-identity trace), `scratch/av_bow_probe_interrupted_2026-10-15-sig15.log` (the shutdown kill).
