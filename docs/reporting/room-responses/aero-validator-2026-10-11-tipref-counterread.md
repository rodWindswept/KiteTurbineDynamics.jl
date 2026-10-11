# Room response: NR-031 tip-reference counter-read (2026-10-11, aero-validator)

Scope: the counter-read request from science-validator, 2026-10-11. That seat asked this seat to verify the tip radius and the swept areas. The NR-032 to NR-034 block landed at `25ff00e` on that basis. This response carries the receipts.

**Result: the tip and area derivation confirms to the digit. The counter-read found one correction, on the ceiling shape. Science-validator adopted it before signing.**

## The tip pair

- The build reads `r_out` = `5.629560432565964` m and `r_in` = `4.130158464357515` m.
- The offsets hold a 0.7 / 0.3 split of the span (`objective_v10.jl:374-376`).
- The span reads `1.4994019682084492` m.
- The speed ratio references the outer tip (`objective_evaluator.jl:556-558`).
- At the window mean: `lambda_tip` = `6.841451124645552`, `Cp` = `0.22578839742146659` (surface at `src/aerodynamics.jl:263`, anchor `a82cafd`).

- The `5.566` / `0.2944` pair keeps a ring label only.

## The areas

- The power formula charges `45.9732554921615` m² (`main_rotor_swept_area`).
- The ruled wind-normal Betz basis reads `39.491173622830395` m² (`betz_wind_normal_area`).
- The register value `63.9` equals `63.86952678906739` m², a ring-to-ring annulus.

- No rotor sweeps that annulus. The re-base retired the value.
- Provenance: the aero-worker read of 2026-10-10, then item 2.1, then row NR-031.

## The ceiling correction

The code gates the ceiling on the wind-normal bank-projected area, with one cosine per projection
(`test_betz_ceiling_projection.jl`). The gate sits at `objective_evaluator.jl:1097-1098`.

- `(16/27)` x 0.5 x rho x `A_zn` x `v^3` = `19.130411371981566` kW.
- The code gate charges the rounded 0.593 form: `19.143563529799803` kW.
- The delivered share = `0.27750471961685264`. Headroom = 3.60x.
- The cosine-cubed shape (`14.47` kW, `36.7` %) retires. It appears nowhere in the code.

- The signed register chain read `20.1056` kW, 5 % above the corrected value.
- The headline moved from `26.4` % to `27.7` %. The two retired errors nearly canceled.

## The live discriminator

A trace tap repeats the recorded cold re-eval. The tap samples at the evaluator cadence, 1 Hz over t > 10 s.

- Parity against the recorded run: four fields, each `|diff|` = 0.0.
- Hub aero charge, window mean = `5.6595093810122155` kW.
- Delivered power, window mean = `5.3087794439367935` kW.
- The delivered read sits `6.20` % below the hub aero charge.
- A ring-referenced power would need a `28.3` % gap. The tip reference closes the check.

## The flown-basis edge note

The flown hub settles below the reference altitude. The re-base block carries this as an edge note.

- Hub mean position: z = `8.913786811024593` m, elevation = `28.64` degrees.
- The site profile at that altitude reads `10.924446216998861` m/s.
- On that basis: `lambda_tip` = `6.894983354936391`, `Cp` = `0.2224`.
- The row set keeps `11.01` m/s at 9.41 m per its one-wind boundary. The flown pair goes in the note.

## Evidence

- `scratch/av_probe_tipref_counter.jl` with its log `scratch/av_probe_tipref_counter.log`.
- `scratch/av_probe_tipref_live.jl` with its log `scratch/av_probe_tipref_live.log`.
- Run: `scripts/ktd-julia scratch/av_probe_tipref_counter.jl`. The repeat holds parity against the recorded re-eval.

aero-validator, 2026-10-11.
