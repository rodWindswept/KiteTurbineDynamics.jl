# machine-evolution-strip: the best-so-far extract

The one prepared extract the `machine-evolution-strip` reads (figure map row 9).
Seven panels show the best-so-far design of island 3, from seed to winner.

## Files

- `extract-best-so-far.csv` carries the extract, one row per panel.
- A row holds the selected generation, the identity label, and the genome source.
- The row then repeats the source telemetry fields verbatim (`island` through `x10`).
- The winner panel carries the raw genome byte-exact from `island_3/best_vector.csv`, the pair-extract basis.
- Every other panel carries the raw genome from the telemetry record.
- `extract-best-so-far.log` holds the run log and the parity certificate.

The generator is `scripts/extract_evolution_strip.jl`. Rerun it with `scripts/ktd-julia scripts/extract_evolution_strip.jl`.

## Provenance

- The dataset is `v13_5kw_masslift_len18.8_rotorcount_bankderate2`. Data commit `dd3cc6a`, launch `a76c5e9`, era `post-95c385d_wind-authority`.
- The source rows come from `island_3/telemetry.csv`, 310 rows across gens 0 to 30 and idx 1 to 10.
- The CSV header names the computing commit. The log holds the input hashes.

## Selection

- Rule: the best-so-far at a selected generation G is the ok row of minimal recorded fitness.
- The window covers gen 0 to G inclusive.
- Ties break to the earliest (gen, idx) pair.
- The selection drops non-ok rows (sentinel fitness `1.0e9`).
- No interpolation and no reconstruction. Each panel is a recorded evaluation.

The figures seat proposed milestones {0, 5, 10, 15, 20, 25, 26} on 2026-10-09.

- That cut repeats machines (M0 = M5, M10 = M15).
- Aero-validator amended the set to the improvement generations {0, 6, 10, 18, 22, 25, 26} on 2026-10-09.
- The amended set gives seven panels and seven distinct machines.
- The CSV header and the log record both sets and the amendment.

Revert by editing `SELECTED` in the generator and rerunning. Nothing else changes.

## Precision

- Telemetry records the raw genes rounded to 6 decimal places.
- That rounding is the only per-row genome record in the signed dataset.
- The byte-exact vector of the winner comes from `best_vector.csv`.
- It matches the telemetry rounding in all ten slots (max delta near 5e-7). The log holds this check in full.

The decode chain rounds before scoring.

- Slot x4 clamps into 3 to 16 and rounds.
- Slot x6 clamps into 1 to 3 and rounds.
- The n_active rule is min(count, n_rings).
- The extract carries the decode columns exactly as logged (display precision).
- The renderer derives geometry from the raw genes through the recorded chain.

## Parity certificate (full detail in the log)

1. The seed row matches across islands 1 to 3, in fitness and raw genes.
2. The final panel is the recorded winner (telemetry 27.364, meta 27.3635412663488, found gen 26).
3. The winner genome in `best_vector.csv` matches the telemetry rounding.
4. The running-best series never rises, and every selected row is ok and inside its window.
5. `convergence.csv` matches the running best at gen i, for i = 1 to 30.
6. The seven picks are distinct, and fitness falls strictly from 36.109 to 27.364.

## Rule

- Values become register rows before any figure draws them.
- The strip claims geometry only (machine-renderer SPEC). The renderer draws what it receives.
