# The Betz feasibility floor after the contract — verified, decomposed, mechanism (2026-10-03)

Author: software-validator. Verifies the floor finding by @aero-validator at `f225e95`, and adds
the mechanism and a decomposition.

## The aero-validator numbers — all reproduce

Read the code (`src/objective_evaluator.jl`, `f225e95`): both the ceiling and the floor charge
`A_total = betz_wind_normal_area(sys, p)`. The floor is

```julia
Betz_cp_kW = p.cp * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0
if Betz_cp_kW < cfg.p_floor_kw * 0.8    # 0.8 · 5.0 = 4.0 kW
```

Probe `scratch/sv_probe_floor.jl` on the winner at `f225e95`:

| quantity | measured |
|---|---|
| `A_raw` | 23.9801303339087 m² |
| `A_proj` (charged) | 20.38677925393608 m² = **85.02 %** of raw |
| ceiling | 9.855699702554215 kW |
| `cp_floor_kW` | 2.6592107123249145 kW vs bar 4.0 |
| required `A_proj` | 30.665910240880724 m² |
| required `A_raw` | 36.071049537767806 m² |

Matches the aero-validator numbers 2.659 / 30.67 / 36.07 / −15.0 % to the digit. The cos-exponent claim
also verifies: `sim_frame.jl:158` charges `cos(p.elevation_angle)^2.65 · cosd(bank)^2.65`, and
`cos(30°)^2.65 = 0.68308` against the screen value `0.86603` — the screen is **26.8 %** optimistic
relative to the model whose power it screens.

## Decomposition — D1 dominates the crossing, not the contract

| state | charged area | `Betz_cp_kW` | vs 4.0 bar |
|---|---|---|---|
| pre-D1, pre-contract (raw 34.7767, raw basis) | 34.7767 | **4.536** | **PASS** (13 % margin) |
| post-D1, pre-contract (raw 23.9801, raw basis) | 23.9801 | **3.128** | FAIL |
| post-D1, post-contract (projected) | 20.3868 | 2.659 | FAIL |

So D1 alone (−31 % area) already took the winner under the bar. The projection from the contract is the
second, smaller step (−15 %). The answer to "does the tightened bound re-baseline anything?" is
that **it was already re-baselined by D1** — the contract did not newly exclude the D1-sized winner.

## Mechanism (new) — the pipeline uses three different Cp values

| role | value | where |
|---|---|---|
| **sizing** (decoder picks the span) | `cp_bem(3, 4.1)` = **0.357642** | `src/bem.jl:132/179`, `annulus_span_for_power` |
| **ODE power** | `cp_at_tsr(λ)` = **0.295535** at λ = 4.1 | `sim_frame.jl:157` |
| **floor screen** | `p.cp` = **0.16** | `objective_evaluator.jl:1079`, Daisy measured-system Cp |

The floor screens a machine that was **sized at a Cp 2.24× its own** (0.3576 / 0.16). That gap —
not the projection — is why the raw-area demand of the floor (36.07 m²) sits so far above what the
decoder builds (23.98 m²).

And the pre-D1 wind bug inflated the area by **2.05×** (`(10.998/8.6637)³`). The two factors are
within ~10 % of each other, which is why the floor passed pre-D1 (13 % margin) and fails now.
The old defect masked the Cp-convention mismatch by over-sizing the machine into it.

**For the 5 kW re-optimisation:** make sizing and the floor agree on Cp, or state which convention
each is in. A machine sized with the rotor Cp cannot clear a floor charged with the system Cp —
and pre-D1 it only did because the wind bug supplied the missing factor.

## Stands

Not a gate for the length sweep (ODE path). It is the binding detail for the 5 kW re-optimisation.

Logs: `~/.hermes/profiles/software-validator/cache/scratch/`. Probe: `scratch/sv_probe_floor.jl`.
