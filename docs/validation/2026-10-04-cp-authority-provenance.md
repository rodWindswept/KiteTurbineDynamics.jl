# The Cp authority: which rotor power coefficient is evidence, and which is a placeholder

Date: 2026-10-04
Scope: rotor power coefficient (`Cp`) on the sizing path and on the ODE path.
Revision measured: `av-wind-authority-guard` tip `0de1c33` (child of `f225e95`). STE pass 2026-10-06: no numbers or findings changed.

## The question

The library carries two Cp reads: sizing calls `cp_bem(n_lines, tsr)`
(`src/bem.jl:179`, inside `annulus_span_for_power`), the ODE power path calls
`cp_at_tsr(lambda)` (`src/sim_frame.jl:157`, `src/ring_forces.jl:221`,
`src/initialization.jl:1032` and `:1052`), and the floor screens a third value,
`p.cp = 0.16`.

The open ruling asks the ODE to fly `cp_bem(n_lines, λ)` instead. This note
measures what that change would do to the 5 kW campaign seed.

## What the probe measured

Probe: `scratch/av_probe_cp_provenance.jl`. Output:
`scratch/av_cp_provenance_out.log`. Run at the revision above.

The campaign seed is `seed_genome(5.0)`. It decodes with `n_lines = 6`
(gene `x[4] = 6.0`), 3 rotors, 13 rings.

| read | value | ratio to `cp_at_tsr(4.1)` |
|---|---|---|
| `cp_at_tsr(4.1)` — what the ODE flies | **0.295535** | 1.000000 |
| `cp_bem(6, 4.1)` — what sizing assumes | **0.269278** | 0.911154 |
| `cp_bem(3, 4.1)` | 0.357642 | 1.210152 |
| `cp_bem(4, 4.1)` | 0.325455 | 1.101241 |
| `cp_bem(5, 4.1)` | 0.295535 | 1.000000 |
| `cp_bem(8, 4.1)` | 0.227454 | 0.769636 |

Two consequences follow.

1. **For this machine the ODE is the optimistic side.** It flies 1.0974 times
   the Cp the sizing assumed. Making the ODE fly `cp_bem(n_lines, λ)` would
   *lower* the power the seed delivers, by about 8.9 % at fixed λ
   (3.567 kW to about 3.25 kW), and it cannot be the change that closes the gap
   to 5 kW.

2. **The size and the sign of the correction follow `n_lines`, not the physics of the machine.**
   The figure of +21 % is the `n_lines = 3` value. The campaign seed is
   `n_lines = 6`, where the correction is −8.9 %. The two reads agree
   only at `n_lines = 5`.

## Why the correction itself is not yet evidence

`src/bem.jl:8` describes the baseline table as "NACA4412, 3 blades,
n_lines=5". `src/aerodynamics.jl:5` describes the same table, from the same
AeroDyn v5.0.0 sweep of 2026-06-10, as "NACA4412, 3 blades, R=4.0 m".

The table is a 3-blade measurement. `cp_bem` treats it as the 5-line baseline
and rescales it by `(5 / n_lines)^0.7` times a Prandtl tip-loss ratio.

`src/bem.jl:19-21` records the status of that rescaling:

> PLACEHOLDER — the scaling exponents (0.7 for Cp, 0.5 for CT) are physically
> motivated but approximate. AeroDyn BEM sweeps across n_lines ∈ {3,4,5,6,7,8}
> are needed to validate or replace these. The single validated data point is
> n_lines=5; at that point the model matches AeroDyn exactly.

The single validated data point is the 3-blade sweep. The label on it says 5.
So the exponent that decides the ruling rests on a blade count the table was
not generated with, and on a scaling the library itself flags as a placeholder.

## Recommendation

Make the measured table the single Cp authority on both paths.

- The ODE keeps `cp_at_tsr`.
- `annulus_span_for_power` stops calling `cp_bem` and reads `cp_at_tsr` too.

This is the only Cp read in the library with a measurement behind it. It
removes the 9.7 % disagreement between the two paths without adopting an
unvalidated exponent.

The cost is plain. The 5 kW machine sizes about 9 % smaller in frontal area.
Cp loses its blade-count dependence as a search lever for now.

The blade-count dependence then becomes its own question, with its own
evidence: run the AeroDyn BEM sweeps at 3, 4, 5, 6, 7 and 8 blades, and
replace the placeholder with a table. Turn the lever back on when a sweep
supports it.

## Knock-on

The floor-to-sizing Cp mismatch is smaller than reported, because the earlier
figure used the `n_lines = 3` sizing value. For this seed (`n_lines = 6`), the
floor screens `0.16` against a sizing Cp of `0.2693` — a factor of 1.68, not
2.24.
