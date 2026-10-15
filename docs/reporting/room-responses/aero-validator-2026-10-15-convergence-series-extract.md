# Room response: the convergence series extract lands (2026-10-15, aero-validator)

**Status** LANDED. **Seat** aero-validator. **Base** `9d04658` (branch `bank-derate-cos2p65`).

The figures notes flag one row want for the convergence figure (Harris 3.5 item 4). The figure needs the island 1 and 2 running-best series, 31 values each. This receipt records the extract, its parity set and its cross-checks.

## 1. The extract

- Source: `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv`. That is the campaign telemetry (era `post-95c385d_wind-authority`, launch `a76c5e9`).
- Rule: the strip-extract rule of 2026-10-09, reused. Best-so-far at generation G is the least recorded fitness among ok rows with gen <= G. Ties take the earliest (gen, idx). No interpolation, no reconstruction.
- Output: `scratch/av_conv_series.csv`. Islands 1 to 3, generations 0 to 30, 31 values each. 93 data rows.
- The file header carries the telemetry hashes: island 1 `6f359c33…`, island 2 `54172ce5…`, island 3 `34d40e8e…`.

## 2. The parity set

- Island 3 against NR-036 at generations [0, 6, 10, 18, 22, 25, 26]: 7 of 7 exact (36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364).
- The island 3 telemetry sha256 equals the strip-extract input hash. The island 3 ok count reads 194. Both match the strip extract.
- The ok counts read 152, 162 and 194. Their sum reads 508. That is the §5 count (NR-002).
- The finals read 30.578, 30.637 and 27.364. Those are the NR-003, NR-004 and NR-005 forms, and the §3.2 sentences.
- The stock-probe log (`scratch/av_rb_stock_probe.log`) reads the same 30.578 and 30.637 values. Two independent records agree.
- The island 1 and 2 finals read +11.7 per cent and +12.0 per cent against island 3. That is the Harris review line ("11.7-12.0 % heavier").
- The run: `scratch/av_conv_series.py`, log `scratch/av_conv_series.log`. All parity checks pass.

## 3. Evidence

- `scratch/av_conv_series.py`: the extract script.
- `scratch/av_conv_series.csv`: the series.
- `scratch/av_conv_series.log`: the run and the parity lines.

## 4. Handoffs

- @science-validator: the series sits for the register row. The source hashes travel in the file header.
- @fig-img-diagrams and @author: the convergence figure can drive from these bytes. The island 1 and 2 series are its flagged want.
- No plate byte moves. No draft byte moves.

Recorded by @aero-validator (aero seat).
