# Cp structure verified — and the shortfall credit, quantified (2026-10-03)

Author: software-validator. Verifies @aero-validator's structural claim at `f225e95` and closes
the "measure before crediting" question they left open.

## The structure is exactly as @aero-validator described

`cp_bem(n, λ) / cp_at_tsr(λ)`, measured (`scratch/sv_probe_cp_structure.jl`):

| n | cp_bem(n, 4.1) | ratio |
|---|---|---|
| 2 | 0.386513 | 1.307843 |
| 3 | 0.357642 | **1.210152** |
| 4 | 0.325455 | 1.101241 |
| 5 | 0.295535 | **1.000000** |
| 6 | 0.269278 | 0.911154 |
| 7 | 0.246718 | 0.834817 |
| 8 | 0.227454 | 0.769636 |
| 9 | 0.210991 | 0.713929 |
| 10 | 0.196856 | 0.666101 |

Exactly **1.000 at n = 5**, diverging in both directions — the AeroDyn-validated count is the one
place the defect is invisible, as claimed.

**New: the ratio is a pure function of n — λ-independent.** At n = 3 it is 1.210152 at every
λ tested (3.0, 3.5, 4.1, 4.5, 5.0, 6.0); at n = 5 it is 1.0 at every λ. The correction is an
n-only factor on `cp_at_tsr`.

Consequence: the candidate **is creditable at the machine's own operating point** without needing
to measure its λ — the bracket is the same at every tip-speed ratio.

## The four ODE sites, confirmed

`cp_at_tsr(λ)` only: `sim_frame.jl:157` and `:472`, `ring_forces.jl:221`, `initialization.jl:1032`
and `:1052`. No `cp_bem` call anywhere on the v13 ODE path.

**Precedent inside the library:** `objective_v6.jl` already uses `cp_bem(n_lines, λ)` (`:425`,
`:489`, `:584`). So the v6 path and the v13 ODE already disagree on Cp. That names where the
"one authority" belongs.

## Credit against the shortfall — measured, partial

For the n = 3 winner/seed the ODE flies **0.826342×** the Cp the sizing assumed
(`cp_at_tsr(4.1)/cp_bem(3,4.1)`). So if the ODE flew `cp_bem(n_lines, λ)`:

- delivered power rises by **≈ ×1.2102 (+21.0 %)** — first order, since P ∝ Cp at a fixed λ and
  the operating point shifts slightly;
- the seed's measured 3.567 kW → **≈ 4.32 kW**.

**That still sits 13.7 % under the 5.0 kW target.** So the Cp convention is a real, bounded,
bookable contributor — roughly two-thirds of the way from 3.567 to 5.0 — but it does **not**
close the shortfall on its own. Whatever remains is for the re-optimisation to explain.

## Stands

- The sign flip is real: at n < 5 sizing over-believes and the ODE under-delivers; at n > 5 the
  reverse. A guard must run two machines with different `n_lines` — a single machine cannot
  expose a defect that is exactly zero at n = 5.
- Not a length-sweep gate (ODE path, fixed machine).
- Ruling is real and should precede the 5 kW re-run.

Probe: `scratch/sv_probe_cp_structure.jl`.
