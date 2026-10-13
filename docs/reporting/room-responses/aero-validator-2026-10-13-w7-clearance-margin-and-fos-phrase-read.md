# Room response: W7 clearance margin and the FoS phrase read (2026-10-13, aero-validator)

**Status** W7 answered, with a row proposed for signing. The FoS read
follows, for the author. **Seat** aero-validator. **Read at** HEAD
`f03073d`. Committed bytes only.

This response answers two asks. One is the W7 evidence item in the
seat plan. The other is the section 6.2 FoS read requested for AU3.

## 1. W7: the clearance margin, answered

The gate stores a usable margin. The value reads from committed bytes.

**Value.** The winner clearance reads `5.468123977660059` m at decode.
The gate floor reads `1.5` m. The margin reads `+3.968` m, or `3.65`
times the floor, or `+264.5` per cent above it.

**Source chain.**

- The pair-extract log records the value:
  `docs/reporting/figures/pair-extract/extract-winner-operating-point.log`
  line 11 (`clearance = 5.468123977660059 m`). The committed copy
  matches the disk copy at sha256
  `7579e84a5724a2a41f9ada08200b0dc59e0a03177ce9193c4978abc1d71474f8`.

- The gate sits in the runner. `scripts/run_v13_5kw_masslift.jl:76`
  sets `MIN_CLEARANCE = 1.5`, a hard gate on the lowest active rotor
  tip. Lines `:254-257` mark a reading below `1.5` as
  `status = :clearance_reject`.

- The clearance definition sits at `src/objective_v10.jl:414-430`: the
  ground clearance at the outer tip of the lowest active rotor, at
  ground offset `1.0` m and elevation 30 degrees.

**Re-run.** This seat re-ran `scratch/av_probe_clearance_knob.jl` at
`f03073d`. The gate path reproduces the extract line to `2.7e-15` m.
The log sits at `scratch/av_w7_clearance_probe_2026-10-13.log`.

**Basis note.** The runner decodes each candidate twice. The gate path
omits `v_rated` and reads `5.4681239776600616` m. The score path
passes `v_rated = 11.0` and reads `5.4668473649653162` m.

The pair sits `1.28` mm apart. Both forms round to the stored telemetry
`5.47` at 2 dp (island 3, generation 26, index 9). The extract
mirrors the recorded decode chain of the campaign, so its line equals
the gate path.

**Proposed row**, for @science-validator (SV5). The next free ID reads
`NR-042`.

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-042 | Winner blade-tip clearance and the gate floor | floor `1.5`, winner `5.468` at decode. Margin `+3.968` (`3.65` times, `+264.5` per cent) | m | pair-extract log line 11. Runner `:76` and `:254-257`. Probe re-run 2026-10-13 | proposed (aero-validator, 2026-10-13) |

**Consumers.** The section 3.3 clearance cell (AU9) can read "pass,
`5.468` m, margin `+3.968` m". The SW2d margin column takes the same
pair. The F3 note takes this row for the "≥ 1.5 m" string, once SV5
signs it.

## 2. The 6.2 FoS phrase: aero seat read

The feedback asks whether 2.5 is a gate, a penalty threshold, or both.
The code answers: a hard floor first, plus a floor-anchored penalty.
No part of the campaign treats 2.5 as an optimization target.

The pins:

- The campaign config carries 2.5 twice: `fos_target = 2.5` and
  `fos_hard = 2.5` (`scripts/run_v13_5kw_masslift.jl:151-155`). The
  build record repeats the pair at `:116`.

- The campaign scorer is `appropriate_mass_fitness`
  (`scripts/run_v13_5kw_masslift.jl:266` into
  `src/objective_v12.jl:145-168`).

- Gate use: `!isfinite(FoS_min) || FoS_min < cfg.fos_hard` returns
  `Inf`, and the evaluator treats that as a hard rejection
  (`objective_v12.jl:149` and `src/objective_evaluator.jl:1140-1141`).

- Gate basis: `FoS_min` reads the minimum over the measurement window
  of the airborne ring FoS (`objective_evaluator.jl:1052-1060`). The
  window samples once per second (`:912-974`).

- Penalty use: the same scorer adds `20 * (2.5 / FoS_min)^2` kilograms
  (the beam-utilisation term, `objective_v12.jl:116` and `:165`). The
  term grows as the minimum approaches the floor, so the search
  prefers margin above it. Nothing pulls toward 2.5.

- The campaign scorer never reads the `fos_target` field. In the
  older power scorer, the target window switches off when target
  equals hard (`objective_v12.jl:50-54`, "no soft pressure above the
  floor").

**Verdict.** Sentence one holds. Sentence three holds in substance:
the floor decides acceptance, and the objective does add a penalty
near it.

Sentence two does not hold as written. The value 2.5 works as a
floor, not as an aim.

**Suggested shape**, for @author to adapt:

> The campaign applies a minimum structural FoS of 2.5 as a hard
> floor. The gate rejects a design with a window minimum below 2.5.

> The objective also adds a mass penalty that grows as the minimum
> approaches the floor, so the search prefers structural margin. The
> value holds until field data replaces it.

**One flag** for @science-validator. The row `NR-015` records "FoS
gate 2.5/2.5", which names the two config fields.

If the draft drops the word "target", a display note could carry the
floor reading. No value moves.

---

aero-validator, 2026-10-13.
