# Room response: the k-sweep display rows sign, NR-047 and NR-048 land (2026-10-14, science-validator)

**Status** The queue-item sign-off closes. NR-047 binds the six display rows for section 2.3, one row per load, from the committed sweep file. The block names the omega column, `omega_final`. The `omega_eq` column reads 0.0 on all ten rows and quotes nothing. NR-048 binds the sizing-side pair. The tip pair and the two retirements ride NR-047.

**Seat** science-validator. **Read at** HEAD `8d8901a`, the tip at read time. Register edited below the NR-046 counter-read block. Additions only: totals 111 to 130, rate 0.97 to 1.03 per100w. STE rc=0.

## The read

The read walks six files.

1. `scripts/results/k_sweep_daisy_5kw.csv`: blob `d17d1377` at the landing commit `adea1a3`, at HEAD and at origin. The column line and ten data rows.

2. `scripts/sweep_k_mppt_5kw.jl`: the anchors at lines 6 to 8, the load list at line 47, and the column naming at line 112.

3. `scripts/run_v13_5kw_masslift.jl`: the tip pair and the two retirements at lines 161 to 168.

4. `src/objective_evaluator.jl`: the ceiling const at line 103 and its applications at lines 427 to 437.

5. `DECISIONS.md`: the [2026-09-06] beam-sizing entry.

6. `docs/plans/2026-09-06-closed-form-beam-sizing.md`: section 7.1 and the scenario list.

## The six display rows (as signed)

Rows k 0.5 to 1.5:

| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |
|---|---|---|---|---|
| 0.5 | reject | 3.49 | 19.14 | 51.8 |
| 1.0 | ok | 5.45 | 17.64 | 47.8 |
| 1.5 | ok | 6.78 | 16.59 | 42.8 |

Rows k 1.94 to 3.0:

| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |
|---|---|---|---|---|
| 1.94 | ok | 7.56 | 15.80 | 40.1 |
| 2.24 | ok | 8.00 | 15.34 | 36.4 |
| 3.0 | ok | 8.89 | 14.42 | 24.3 |

Each triple cross-reads the raw file at full precision and rounds from the stored digits. The k 0.5 row reads 3.4852 kW against the 5.0 kW bar and carries reject. The k 4.0 to 9.0 rows stay with NR-041 and its plateau band.

## The companion forms (NR-047)

- Tips. The runner comment pairs k 2.24 with omega 15.3 and tip about 73 m/s. It pairs k 1.0 with omega 17.6 and tip about 85 m/s, near the 100 m/s ceiling. The ceiling is the hard gate `TIP_SPEED_CEILING_MPS = 100.0` at `src/objective_evaluator.jl:103`. No exact per-row tip print sits in the record. A full tip column takes a fresh derivation.

- Retirements. 3.55, the mass-scale unanchored value, and 5.39, the 3-blade anchor chosen on the broken machine. The "~9 kW" claim cross-reads the sweep file: the k 5.39 row reads P_end 8.97 kW.

- Bases. The comment "8.0 kW" reads P_end, and the comment says so. Its "5.45 kW" reads P_mean. The table prints P_mean at 2 dp and names P_end where it means it.

## The sizing-side pair (NR-048)

The tokens re-read verbatim at the two record files: the load-step sizing case and the k-easing refusal. The sizing case reads "nominal `k_mppt × 2`", measured `F_helix ≈ 1278 N/vertex` on the hub segment. The refusal reads "twist 87.9° against the 78.8° limit". The measurement is the first-cut scenario sweep of 2026-09-06. The tree holds the script, and it does not carry the console record, so this row signs the record forms. A re-derivation is a new read.

The fold prints the pair at the record forms: "× 2" or "twice the nominal load", "1278 N/vertex", "87.9°", "78.8°".

## Evidence

- Checker: `scratch/sv_nr047_k_sweep_rows_check.py`. Log: `scratch/sv_nr047_k_sweep_rows_check.log`. 46 checks, 0 fail: 4 file-identity checks, 13 recompute checks, 15 pin checks, 8 record-token checks, 6 register re-reads.

- Register: `docs/reporting/numbers-register.md`, the NR-047 and NR-048 blocks below the NR-046 counter-read.

- STE: rc=0. The register reads totals 111 to 130, rate 0.97 to 1.03 per100w, additions only. This receipt reads 0.00 per100w.

## Handoffs

- @author: the fold gate lifts. The k table reads NR-047. The tip text reads NR-047. The sizing pair reads NR-048. The retirements read NR-047. The over-power tie-in rides NR-046.

- @aero-validator: counter-read requested on both rows and the checker.

- @hermes: queue item 4 takes its science-validator leg closed. The author fold is next.

- @user: register-side only. The draft, the figures and the review copy keep their state.

science-validator, 2026-10-14.
