# Room response: item 1.7, damper call-site confirmation (2026-10-11, software-validator)

Scope: the morning list of the lead shows this open item: "1.7 ...
call-site confirmation open (software seat)". The forensics packet
(`9f29df1`) pinned the values. This seat confirms them at the sites.

**Result: the call sites confirm the values. This seat signs item 1.7.**

## Confirmation

- `lin_damp = 0.05`. The canonical runner applies it at each step
  (`src/simulation.jl:194-195`, gated by `lin_damp > 0.0`). The
  signature default is at `src/simulation.jl:71`. The mechanism is
  `orbital_damp_rope_velocities!` (`src/initialization.jl:738`). The
  code scales its rate with dt (`:794`, calibrated at dt = 4e-5 s).
  The campaign evaluator default is at `src/objective_evaluator.jl:698`.
  The evaluator passes the value at `:875` and `:986`.
- `bearing_tr_damp = 0.99994` and `ang_damp = 1.0`. These two exist
  only in the legacy `simulate()` (`src/initialization.jl:830-840`,
  applied at `:867` and `:876`). `run_canonical_sim!` accepts neither
  (`src/simulation.jl:63-81`). Only older scripts call legacy
  `simulate(`: `scripts/cold_start_collapse.jl`,
  `scripts/mppt_ramp_only.jl`, `scripts/mppt_twist_sweep.jl`. The
  campaign runner and the evaluator do not call it. The campaign never
  used the two dampers. Confirmed.
- `TETHER_DRAG_CD = 1.0` at `src/aerodynamics.jl:335` (const). It is
  physical and Tveide-validated. The team deliberately did not land the
  1.09 factor (DECISIONS.md [2026-09-11]).
- `p.zeta = 0.05` at `src/parameters.jl:177, 224`. Physical rope
  damping.

## Note

`scripts/kwarg_default_audit.py` already lists `lin_damp` and
`bearing_tr_damp` as audited default kwargs. Its open items can now
cite this confirmation.

This seat checked the positions at `bank-derate-cos2p65` HEAD `264a008`.
The damper values are at data_commit `dd3cc6a`.

Software-validator, 2026-10-11.
