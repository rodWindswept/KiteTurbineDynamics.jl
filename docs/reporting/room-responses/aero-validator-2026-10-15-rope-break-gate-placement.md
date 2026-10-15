# Room response: the rope-break gate placement fix lands (2026-10-15, aero-validator)

**Status** LANDED. **Seat** aero-validator. **Base** `84ac158` (branch `bank-derate-cos2p65`).

The queue item reads: "The rope-break gate placement fix (NR-013, Harris 3.8).
The code still runs the gate across relax and window. A code fix lands before
the printed number stands." This receipt records the fix, its acceptance set
and the fresh warm extract for the register.

## 1. The fix

Break detection gains an arm time. The latch honors `sys.breaks_arm_s`, and the
windowed evaluator arms at the relax boundary (`breaks_arm_s = cfg.relax_s`).
Detection runs on the measurement window only. The 2026-09-16 ruling now sits
in the code.

The default 0.0 keeps every other caller exactly as-coded. Scope: the kick
call, the ramp evaluator and the control-map hunt stay armed from the start.
The kick runs off in every recorded campaign. No recorded number moves.

Files: `src/types.jl`, `src/initialization.jl`, `src/simulation.jl`,
`src/rope_forces.jl` (both latch gates) and `src/objective_evaluator.jl` (the
combined-run call). Test: `test/test_rope_break.jl` gains R4.

## 2. The acceptance set

- The placement check (`scratch/av_rb_placement_check.log`), 5 checks, 0 fail:

  - The control (default arm) still latches at the recorded trip. Step 98,
    t = 0.002841 s, TRPT S4 L3, strain over break 1.00081. NR-013 records the
    2.84 ms trip.
  - The fixed path completes the full 50 s with no latch (35.8 s wall).
  - The relax transient peak above the limit is present and suppressed:
    1.44819 at t = 5.740 ms. These are the digits of the condition run.
  - With an arm at 1e-6 s the same latch fires. Detection stays live when
    armed.

- The condition-run reproduction. The fixed-path run against the committed
  `extract-eval-timeline-warm-rulingmode.csv` on the same grid: 1,823 rows,
  max diff 0.000e+00 on t, omega_gnd, omega_hub and P
  (`scratch/av_rb_compare.log`). The condition curve is now a real code run.

- The trajectory identity (`scratch/av_rb_ab_check.log`). The evaluator path,
  the direct build and the raw and clamped genome decode read one trajectory.
  The tail sums agree at all printed digits. The value reads 10.186959954 over
  5,002 steps. The raw and clamped genomes decode identically, because the
  rotor-count slot rounds to 1 either way. An earlier apparent window-mean
  difference was a sampling artifact on the ringing window. No machine
  difference exists.

- Cold parity (`scratch/av_rb_stock_probe.log`). The cold rows of the re-run are
  identical to the pre-fix baseline (`scratch/sv_regv1_probe_fidelity.log`) on
  all three islands, at every displayed value. NR-012 holds.

- The warm path post-fix, the fresh extract at `scratch/av_rb_warm_extract/`.
  All three winners complete with no latch anywhere:

  | island | P_mean kW | P_end kW | FoS_min | omega_eq | twist |
  |---|---|---|---|---|---|
  | 1 | 5.719 | 3.381 | 0.154 | 7.727 | 0.54 |
  | 2 | 5.803 | 7.563 | 0.439 | 8.064 | 0.54 |
  | 3 | 5.115 | 5.070 | 0.593 | 14.231 | 0.96 |

  The status reads reject on the honest gates, never on the relax artifact.
  Before the fix all three warm rows read `broken=true | reject`.

- `test/test_rope_break.jl`: ALL ACCEPTANCE TESTS PASS (R1 to R4).

- The fast suite reads 2,606 pass, 0 fail, in 2m56.9s.

## 3. The register shape (for the science-validator)

Their desk. One direction: an NR-013 extension block records the post-fix
state. The warm path no longer false-rejects, the three winners' window stats
read as above, and the arm time reads as the executed placement. The NR-025
protocol sentence describes the campaign as-run. The ruling now sits in the
code, so future quotes need the armed-at-window form. The extract CSVs carry
provenance headers. The rows sign from those bytes.

## 4. Boundaries

No value moves. No register number changes, no plate byte moves, no draft byte
moves. Downstream folds for the room: section 4.1 rewrites as a fixed defect
(@author). The eval-timeline label "not yet in the code" now overstates
(@fig-img-diagrams). The register quote form reads as above
(@science-validator). The queue line moves to the closure (@hermes).

## Evidence

- `scratch/av_rb_placement_check.jl` and `.log` (5 checks, 0 fail)
- `scratch/av_rb_warm_extract.jl`, `.log` and `scratch/av_rb_warm_extract/`
  (three island CSVs)
- `scratch/av_rb_ab_check.jl` and `.log` (the trajectory identity)
- `scratch/av_rb_compare.py` and `.log` (the condition reproduction)
- `scratch/av_rb_stock_probe.log` (warm and cold, three islands)
- `scratch/av_rb_test_rope_break.log` (R1 to R4)
- `scratch/av_rb_suite.log` (2,606 pass)
- `scratch/av_rb_placement_island3.csv`
- `scratch/av_rb_timeprobe.jl` and `scratch/av_rb_genome_check.jl`

aero-validator
