# Reject-cause probe: failure classes and conditions

Hermes, 2026-10-17. This follows the reject-class split (`b65e9c8`) and the
probe Rod asked for. It names the gate that rejects each of the 201 FoS=Inf
reject rows.

## Method

Two probes re-run every plain-reject genome through the checks that the
evaluator uses.

`scratch/reject_cause_probe.jl` re-runs each genome through `evaluate_windowed`
with a trace callback. The callback latches the first failure in the return
order that the evaluator uses. It also decodes the pre-settle gates cheaply.
The expensive Betz check runs at the 1 Hz window cadence that the evaluator
uses.

`scratch/reject_underfloor_split.jl` splits the residual post-window bucket. It
uses the static `betz_cp_floor_kw`.

## Result

The 201 FoS=Inf rejects split into six classes.

- betz_cp_floor: 93. Rotor swept area times Cp cannot reach 80% of the 5 kW floor.

- settle_fail: 37. Torsional realisability cliff. The shaft needs sin(Δα) over 1.

- spacing: 36. Concurrent rotors tighter than 0.8 times 2·r_rotor.

- rope_break: 29. A line exceeded the break strain in the window.

- betz_ceiling: 3. Aggregate window power over 1.1 times the Betz ceiling.

- hub_tip: 3. Hub ring ω non-finite, or tip speed past the sanity ceiling.

The 100 finite-FoS rejects sit outside these six classes. 95 of them read
P_end below 5.0 kW and fail the power floor. See `b65e9c8`.

## The NaN question

Two of the classes Rod flagged as "NaN conditions" are not NaN at all.

`settle_fail` (37) is the torsional realisability cliff. The settle throws a
clean error. The design asks the shaft to carry more torque than its tension
can physically transmit. The twist would have to pass 90 degrees. This is a
design failure, not a numerical fault.

`spacing` (36) is a geometry gate. The evaluator checks it before any
simulation runs.

Only `hub_tip` (3) is a genuine numerical divergence. The angular velocity of
the hub ring goes non-finite, or the tip speed passes the sanity ceiling. That
is the true "NaN" class. It is 3 rows of 201.

## Rope-break gate caveat

The telemetry came from `a76c5e9` (2026-10-07). The probe re-ran at HEAD
`b65e9c8`. HEAD carries one source change. `2bf76a3` (2026-10-15) arms the
rope-break detector at the relax boundary. Detection runs on the measurement
window only. The producing commit armed it for the whole run.

So the rope_break count (29) may shift by a few rows if re-run at the producing
commit. The other five classes stay unchanged.

## Provenance

- `scratch/reject_cause_probe.jl`
- `scratch/reject_underfloor_split.jl`
- Log: `/tmp/reject_probe_full.log`
- Physics era: `post-95c385d_wind-authority`. Config reproduced from
  `scripts/run_v13_5kw_masslift.jl` (k_mppt=2.24, cold start, 18.8 m).
