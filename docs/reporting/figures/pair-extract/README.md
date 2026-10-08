# pair-extract: the mechanism-pair capture

The one capture the `ring-utilisation` and `twist-limit` plates both read.
The declared capture is the winner operating point. This is the final
frame of the measurement window.

Files:

- `extract-winner-operating-point.csv`: the extract.

  Ring block: `max_util`, `util_axial`, `util_bending`, `ring_fos` for
  every checked ring, R2 to R6, hub marked. `station_m` gives the
  cumulative ring-centre separation along the shaft. R1 sits at 0.

  Segment block: `abs_dalpha_deg` (raw, from the stored alpha block) and
  the emitted `segment_twist_deg`, `dcrit_deg`, `has_limit`,
  `segment_torque_Nm`, `torque_capacity_Nm` for S1 to S5.

- `extract-winner-operating-point.log`: the full run log, including the
  parity certificate.

- Generator: `scripts/extract_pair_capture.jl`. Rerun with
  `scripts/ktd-julia scripts/extract_pair_capture.jl`.

Provenance. The dataset is `v13_5kw_masslift_len18.8_rotorcount_bankderate2`
(data commit `dd3cc6a`, launch commit `a76c5e9`, era
post-95c385d_wind-authority). The path is `evaluate_windowed :cold`, the
NR-012 basis. The capture reads s = 1724859, t = 49.99999483862295 s.
The computing commit sits in the CSV header.

Parity certificate. The run reproduces the recorded cold re-eval
(`scratch/sv_p0_winner_reeval.txt`) at full precision. Nine of nine
fields match exactly: P_mean, P_end, FoS_min, fitness, util_a, util_b,
T_lift, twist_ratio, omega_eq. A rerun reproduces the extract bit for
bit.

Rule. Values become register rows before any figure draws them. Rows
NR-021 to NR-023 carry this capture.
