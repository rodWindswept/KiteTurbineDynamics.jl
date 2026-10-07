# Projection threading: landing record (2026-10-07)

**STE pass 2026-10-07:** no numbers or findings changed.

Revision: `b835ebc` on `bank-derate-cos2p65`. The cut started from `7c9f4b9`.
The base moved to `4311f5f` before the landing (kretune clamp-release annotation).
Probe: `scratch/av_probe_thread_ab.jl`. The probe runs in both trees.

Logs: `.julia_depot/logs/av_thread_ab_pre_7c9f4b9.log`, `av_thread_ab_post.log`,
`av_thread_suite_1.log` (first cut run, 16 moved pins), and `av_thread_suite_3.log`.

## What moved

One factor now runs through the fast hub-power chain and the sizing family.
The factor is the one the ODE charges on disc power (`ring_forces.jl`, power term):

    f = cosd(bank_deg)^2.65 · cos(elev_rad)^2.65

One authority: `BEM.projection_factor`. Eight live sites carry it:

- The hub charge (`objective_v6.jl` :426 and :490).
- The solver seed and re-size (`:567`, `:591`).
- The decode spacing reference and spans (`objective_v10.jl` :322, `:352`).
- The rank reference radius (`:524`).
- The beams hub-thrust fallback (`trpt_optimization.jl` :336).

The channels. `rotor_radius_for_power` gains `f`, default 1.0.
The default keeps direct sizer pins byte-stable.
Both solvers gain `bank_deg`, default 0.0 (elevation-only).

The two live callers pass the bank of the topmost rotor
(`objective_v10.jl` :541, `trpt_optimization.jl` :321).
The trpt expansion stack excludes the hub rotor.
A stack-inferred bank can not reach the hub there.
The explicit argument lands the full factor in both live contexts.

No other site applies f. The script tier (12 sites) stays optimistic until re-run.

## Closed forms and receipts

| quantity | value |
|---|---|
| f(10.74°, 30°) | 0.6518052428788816 |
| 1/f, 1/√f | 1.534202, 1.238628519015731 |
| elevation-only 1/f, 1/√f | 1.464009, 1.209962966766535 |
| f(0, 0) | 1.0, exact |

A/B receipts (pre and post logs above):

- Winner decode (bank 10.7399°): span 1.043269008805236 -> 1.292222799591.
  The ratio 1.238628569126777 equals 1/√f to 1e-15.
  Radius 4.564961043406 -> 4.739228696955.
  Raw annulus 26.504217768379 -> 33.233146203543.
- Realisability fixture (bank 0): span 1.118010888171 -> 1.352751256863 (×1.2099625).
  demand[1] 1.5462831959 -> 1.1832595207.
  τ_carry[8] 308.9724224170 -> 282.4392515219.
  F_ax[end] 636.1231817422 -> 825.8186437911.
  crossing 2.2397326086 -> 1.4715983066.
- Helper `projection_factor` minus the closed form: 0.0e+00 at both points.

## Re-baselines (same commit)

The first cut run showed 16 failures. The failures are the moved pins, nothing else.

- File `test_betz_ceiling_projection.jl`, testset 4 (island-3 winner), third re-baseline.
  The sized span scales by 1/√f. The file comment holds the movement receipts.
- File `test_trpt_realisability.jl`, section A (SEED_LR20, unbanked), eighth re-baseline.
  The span scales by 1.2099630. The verdicts hold.

## Suite

2571/2571 at the commit code (`av_thread_suite_3.log`).
The `7c9f4b9` baseline reads the same.

## Scope

Sizer-direct pins ride the `f = 1.0` default.
The dormant v6 objective rides the defaults.
Script and probe rows move on their own re-run cadence.
The census targets are ×0.652, ×1.21 and ×1.24. The two radius channels appear above.
