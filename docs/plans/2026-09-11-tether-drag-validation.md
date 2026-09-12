# Tether-drag validation against Tveide's solver (2026-09-11)

**Status:** validation run; no code changed. Companion to
`handover-2026-09-11-tether-line-drag-teviede.md` (Rod's brief).
**Tool:** `TetherDragODESolver`, MIT, `github.com/tallakt/TetherDragODESolver`
(Tveide). Cloned to `.julia_depot/TetherDragODESolver`; its pinned Manifest was
too old for Julia 1.12, re-resolved fresh. The solver reproduces the author's
published reference values exactly (`multiplier 0.26584`, `eff 0.49482`).

---

## 1. What the 0.5 factor actually is

`tether_curvature_factor = 0.5` lives in **`parasitic_drag_power`**
(`src/objective_v6.jl:246`, applied at `:334`). That is the **static** estimator,
called by `solve_equilibrium_omega` → `solve_equilibrium_self_consistent`, which
R7's `size_beams_closed_form` uses for its equilibrium ω (and which the warm
start uses). It is **not** on the live ODE path: `rope_forces.jl:294-310`
computes per-sub-segment drag from the actual local relative velocity
(perpendicular to the line), i.e. a discrete, dynamic, belly-aware line, with no
curvature factor.

So this validation governs the **static equilibrium ω** (and therefore the R7
sizing loads), not the ODE drag directly.

## 2. Equivalence in KTD's units (the §8 hypothesis, resolved)

Tveide's `drag_coefficient_multiplier` is a drag **force** ratio normalised
against the whole tether moving at kite speed. KTD's factor multiplies a
local-speed **power** sum. For a straight taper the equivalence is

```
factor_KTD = multiplier · 4·r1³ / (r0³ + r0²r1 + r0·r1² + r1³)
```

**Self-check:** for a straight tether this gives exactly 1.0, and the solver
returns ≈1.0 at high tension / zero twist (§3, 2500 N row: 1.007). The
normalisations are therefore reconciled.

### 2.1 Provenance (derived from the solver source, not a hypothesis)

`solved_drag_coefficient_multiplier` (`src/TetherDragODESolver.jl:291-301`) is

```julia
drag_moment = m1 - m0                       # moment lost between r1 and r0
drag_force  = drag_moment / radius1         # a *fictitious* force, not total drag
drag_100    = 0.5 * rho * (omega*radius1)^2 * Cd * length * diameter
multiplier  = drag_force / drag_100
```

so `drag_moment = multiplier · ½ ρ Cd d ω² L r1³`, and since the shaft is rigid
at constant ω the **true** lost power is

```
P_true = ω · drag_moment = multiplier · ½ ρ Cd d ω³ L r1³
```

KTD's `P_seg_raw` sum (no factor) is `P_model = ∫₀^L ½ρ Cd d (ω r)³ ds`, which
for the linear taper integrates to `(1/8) ρ Cd d ω³ L (r0³+r0²r1+r0r1²+r1³)`.
Dividing gives the §2 conversion exactly — so §2 is now **derived**, not
hypothesised. (The brief's §8 warning is correct: `multiplier` is *not* `D/D_full`;
its denominator is `½ρ(ωr1)²Cd d L`, and its numerator carries a spurious `/r1`.)

**Falsifiable prediction.** A straight taper has `P_true = P_model`, hence
`multiplier_straight = (r0³+r0²r1+r0r1²+r1³) / (4 r1³)`. At KTD's geometry
(r0 = 0.575, r1 = 2.4) that is **0.3277**. The high-tension limit of §3 gives
`1.007 / 3.052 = 0.330` — the belly-free limit of the solver, recovered. The
constant-radius case is degenerate (both formulae give 1.0) and was therefore
*not* the self-check; this straight-**taper** check is.

## 3. Results at KTD's 5 kW seed geometry

r0 = 0.575 m, r1 = 2.4 m, L = 18.8 m, ω = 13.2 rad/s, d = 2 mm, per-line tension
as shown. `factor_KTD` is what the model should use in place of 0.5.

| T_line (N) | twist 0° | twist 90° | twist 294° |
|---|---|---|---|
| 150 | 1.206 | 0.920 | 1.027 |
| 305 | **1.093** | 0.848 | **0.937** |
| 700 | 1.037 | 0.812 | 0.892 |
| 2500 | 1.007 | 0.792 | 0.867 |

Raw multipliers (for reference, same grid): 305 N → 0.358 / 0.278 / 0.307.

## 4. Headline

At KTD's operating point (per-line tension ≈ 305 N, zero twist — the static
estimator assumes a straight shaft) Tveide's method gives an equivalent
**factor ≈ 1.09**. The model currently uses **0.5** — so the static estimator
**under-estimates tether drag by ≈ 2.2×**, not over-estimates. The result is
robust across tension (1.0–1.2) and only drops below 1 at high twist
(0.79–0.94 between 90° and 294°).

This matters for R7: `size_beams_closed_form` gets its equilibrium ω from this
estimator, so ~2× more modelled tether drag would change that ω (and the loads
and beam masses).

### 4.1 It also removes a settle↔ODE inconsistency

The live ODE path (`rope_forces.jl:294-310`) sums per-sub-segment drag from the
actual local perpendicular velocity and applies **no** curvature factor — i.e. it
already behaves as `factor = 1.0`. So the static estimator is the *only* place
that scales tether drag down by 2×. Setting the static factor to the validated
≈1.0–1.1 therefore makes the static equilibrium ω agree with the ODE's own drag
budget — the same coherence goal as the settle workstream
(`docs/plans/2026-09-10-shaft-windup-workstream.md` §4.3). The two changes should
land together and be evaluated with one acceptance run.

## 5. Caveats (why this is not yet a code change)

1. **Low tension.** Tveide's own validation case uses 2.5–7.5 kN; KTD's per-line
   tension is ≈ 305 N, where the belly is large and the method is outside its
   comfortable range. At zero twist the solver returns a **negative** efficiency
   ratio at 150–305 N (ground moment reversed), a signal the configuration is at
   the edge of the model's validity.
2. **Per-line vs shaft.** The solver models one tether. KTD's shaft is 6 parallel
   lines; the comparison uses the per-line tension.
3. **Twist.** The static estimator assumes no twist; the running shaft twists
   ~294° cumulative. The table covers both.
4. **VIV not included.** Tveide's solver has no vortex-induced vibration. Dunker
   (2018) measured line-drag rises up to 300 % from VIV and 210 % from galloping.
   KTD's line Reynolds number at rated wind is only ≈1500 (2 mm line) — **inside**
   the VIV range — so `TETHER_DRAG_CD = 1.0` may itself be low. That is a
   separate, compounding question.

## 6. Guard

Any change to the factor or `TETHER_DRAG_CD` is a physics change: proposal and
acceptance test first, and a run that shows the effect on ω and the loads.

## 7. Repro

`scratch/r7_teviede_validation.jl` (copy into the solver's project and run with
its environment — see the file header for the equivalence used).
