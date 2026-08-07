# Findings — Phase A v2 DE audit (2026-08-07)

Audit of `scripts/results/recampaign/feasibility_phase_a_v2.csv` (44 evals,
2026-08-06 17:04:44 → 2026-08-07 00:30:20, 7h26m, git `4894787`) against
`scripts/run_feasibility_phase_a.jl`, `src/objective_v11.jl`,
`src/ring_element_analysis.jl`, `src/ring_spacing.jl`.

**Bottom line: no number in this CSV is quotable.** The `beam_aspect` fix did
resurrect the run (the previous 39-eval run was 100% dead), but the campaign it
resurrected is optimising against an inert structural constraint, from a seed
that sits outside the search box, in a region the DE was never able to leave.

---

## F1 — The V10 seed is outside the search bounds

`run_feasibility_phase_a.jl:63` seeds `X_V10[1] = 0.060` (Do_top).
`ring_spacing.jl:355` sets `Do_lo = 0.20`.

The seed is **3.3× below the lower bound of the domain it seeds.**

- The seed itself is evaluated unclamped (seeds bypass `clamp_genome`).
- Every DE trial derived from it is clamped to 0.20 (`run_feasibility_phase_a.jl:173–175`).
- **The DE therefore cannot search the region the V10 winner lives in.**

Consequence: `x1 == 0.2000` exactly in **25 of 44 evals (57%)**, 13 of the 19
live evals. That is not a DE result, it is the clamp. Selection is pressing
*down* against `Do_lo` and being held there.

Related dead code: `objective_v10.jl:221` reads
`base_lo[1] = max(base_lo[1], 0.05)  # Do_top min: 0.05 m (was 0.01)`.
Since `search_bounds_v4` already returns 0.20, this is `max(0.20, 0.05)` — a
no-op with a comment that actively misstates the operative bound.

## F2 — The seed produces 0.4 watts

First eval of the run, 17:04:44.652:

| field | value |
|---|---|
| `x1` | 0.060 |
| `P_mean_kw` | **0.000388** (0.39 W) |
| `FoS_min` | 55.4 |
| `f_feas` | 11.0 (stall floor) |

The script comment calls this seed "V10 winner only (post-A1-A5 — **known
feasible**)". Under current physics it is a dead machine. The campaign has no
valid anchor, and no baseline to measure the 44 evals against.

## F3 — The FoS gate never engaged. Not once, in 44 evals.

`FOS_DESIGN = 1.5`. Observed `FoS_min` over the 19 live evals:

| | min | median | max |
|---|---|---|---|
| FoS_min | 23.1 | **159.1** | 653.8 |
| util_axial | 0.0 | **2.0e-5** | 1.9e-3 |
| util_bending | 3.1e-4 | 4.3e-3 | 4.1e-2 |

`util_axial` is **exactly 0.0** in 10 of 29 rows. The rings are carrying
~0.15% of capacity while allegedly transmitting 44 kW.

Zero evals landed in the `"feasibility"` tier (`0 < f_feas < 1.5`). Tier
counts are feasible/stalled only. So `objective_feasibility` collapses to its
third branch, `-min(P,50)/50`, for every design that turns — and
`v11_fitness` collapses to `-P_mean` (verify: best row `f_v11 = -44.199679`,
`P_mean_kw = 44.199679`, identical).

**This is a power maximiser wearing a feasibility campaign's name.**

## F4 — F3 is a regression, and the mechanism is in `analyse_ring`

Same script, previous commit `55caa5d` (`..._run2-dotop-orphan.csv`, Do_top
not yet wired):

| | FoS median | FoS range | util_axial median |
|---|---|---|---|
| `55caa5d` (before) | **0.791** | 0.319 – 4.2 | **0.343** |
| `4894787` (this run) | **159.1** | 23.1 – 653.8 | **2.0e-5** |

**201× FoS jump. 16,800× util_axial collapse.** Introduced by `d6f1964`
("Wire Do_top into physics").

Two compounding causes, both in `ring_element_analysis.jl:483–507`:

**(a) The bound floor.** Legacy sizing was `Do = 0.01396·√R` (≈ 0.03 m at
R = 5 m). The wired path uses `Do_top ≥ 0.20 m`. ~7× the diameter.

**(b) The two branches do not agree, despite the comment saying they do.**

```julia
# design === nothing  (line 489-490)  ← what the campaign actually runs
scale = sqrt(R / p.trpt_hub_radius)
Do    = max(sys.ring_Do_top[] * scale, ...)

# design !== nothing  (line 498-499)  ← what the comment claims to match
scale     = (R / design.r_hub)^design.Do_scale_exp
Do_scaled = max(design.Do_top * scale, ...)
```

The wired branch **hardcodes the taper exponent to 0.5** (discarding
`design.Do_scale_exp`, i.e. genome `x4`) and **swaps the reference radius**
from `design.r_hub` (genome `x5`, observed 2.9 – 28.6) to
`p.trpt_hub_radius`. Search bounds set `r_hub_lo = 1.50 * p.trpt_hub_radius`,
so the campaign path always divides by a radius at least 1.5× smaller — and up
to ~19× smaller — than the design path would. That is up to another ~4.4× on Do.

Combined ≈ 30× diameter → bending capacity ~D³ ≈ 2.7e4×. That is the right
order for the observed 1.7e4× util collapse. **The tubes being simulated are
far fatter than the design vector specifies.**

`sim_frame.jl:168` and `:381` call `ring_element_analysis(u, alpha, sys, p, t,
wind_fn)` with no `design` argument, so `design = nothing` — the campaign only
ever takes branch (a).

Corroborating signature: `x4` (Do_scale_exp) is railed at its upper bound 1.0
in **14 of 44** evals. That is what a gene under zero selection pressure looks
like.

## F5 — Nothing is stationary

`stationary == true` in **1 of 44** rows — and that one is a 6.29 kW stall,
not a candidate.

All nine "feasible" designs, by `P_range / P_mean`:

| P_mean kW | P_range kW | swing |
|---|---|---|
| 44.20 | 34.16 | 0.77 |
| 43.92 | 39.44 | 0.90 |
| 38.97 | 54.01 | **1.39** |
| 36.07 | 34.14 | 0.95 |
| 34.13 | 14.26 | 0.42 |
| 33.82 | 17.72 | 0.52 |
| 30.93 | 49.20 | **1.59** |
| 27.45 | 17.17 | 0.63 |
| 25.68 | 10.61 | 0.41 |

The stationarity gate requires `P_range/P_mean < 0.20`. Nothing is within a
factor of two of it. `drift_flag` is true in 34/44. Two designs swing wider
than their own mean.

The GREEN condition at line 353 requires `stationary` — it was never met, so
the run cannot have declared GREEN regardless of the power numbers.

This is the same finding as the 2026-08-05 relax sweep. The 10 s
`WARM_RELAX_S` vs 30 s `WARM_WINDOW_S` tension is flagged in the source
comment at `objective_v11.jl:278-284` and is still unresolved.

---

## Secondary findings

**S1 — `x15` is a dead gene.** `warmstart_with_k_bracket` overwrites
`x_k[15] = log10(k_try)` where `k_try = clamp(p.k_mppt · λ_eff² · scale, 0.01,
1000)`. The genome's `x15` never reaches the simulation. The DE searches 15
dimensions of which one has provably zero fitness effect. `x15` is railed at a
bound in 15/44 evals; the campaign's own `best_vector.csv` has `x15 = -2.0`
(the floor) — a meaningless value recorded as if it were a result.

**S2 — `k_chosen` railed at the clamp ceiling in 16/44.** The bracket is
`k_prior·{0.5, 1.0, 2.0}` clamped to `[0.01, 1000]`. When `k_prior·0.5 > 1000`
all three points collapse to 1000 → three identical ~10-min sims for one data
point. 5 of the 9 "feasible" designs sit at k ≥ 950. The optimum is on the
boundary, so the bracket is not bracketing anything.

**S3 — `lift_tension_N` is a constant, and it isn't newtons.** All 44 rows read
`1.5`, which is `LIFT_MARGIN` (dimensionless). The script has a TODO at line
86-92 acknowledging it. In a CSV produced to validate a *lift-margin* fix, the
lift column measures nothing and is mislabelled by units.

**S4 — `tier` hides hard failures as stalls.** `tier` is assigned on
`P_mean < P_FLOOR` alone, so the 15 rows with `f_feas = 12.0` (the rejection
sentinel: FoS non-finite) are labelled `"stalled"` — indistinguishable from a
genuine low-power design. `tier` and `f_feas` disagree on 15/44 rows.

**S5 — `12.0` is overloaded, and the bracket's guard doesn't catch it.**
`objective_v11.jl` has nine `return (12.0, ...)` rejection paths. The bracket's
filter is `if !isfinite(fitness) || fitness >= 1e8: continue` — 12.0 passes it
and is accepted as a legitimate fitness. It also collides exactly with
`objective_feasibility`'s own 12.0 rejection code, in the adjacent CSV column.
Any plot of `f_v11` shows a +12 spike for 15 rejected designs alongside real
values of −44.

**S6 — Effective budget was 19 evals, not 44.**

| outcome | n | % |
|---|---|---|
| hard reject (P=0, FoS=Inf, f_v11=12) | 15 | 34% |
| milliwatt-dead (P < 0.003 kW) | 10 | 23% |
| live (P > 0.1 kW) | 19 | 43% |

57% of a 7.4-hour run produced no machine. The 10 milliwatt rows carry
FoS values up to **3198.9** at `util_axial = 4e-6` — an unloaded structure
reported as a passing FoS.

**S7 — `POP_SIZE = 8` in a 15-D space.** DE mutation moves within the span of
population differences; 8 individuals span at most a 7-dimensional affine
subspace. The search is structurally confined to ≤7 of 15 dimensions from
initialisation onward. Standard heuristic is 10×D ≈ 150.

**S8 — `best_vector.csv` is stale.** `feasibility_phase_a_v2_best_vector.csv`
matches **no row** in `feasibility_phase_a_v2.csv`, and none in
`..._run2-dotop-orphan.csv` either. It is an orphan from an earlier run.
Anyone reading it as this campaign's answer gets a genome this campaign never
evaluated.

**S9 — the prior run was 100% dead, and "resume" did not resume.** At
`d6f1964` the CSV held 39 rows, every one `P=0 / FoS=Inf / f_feas=12`,
timestamps spanning **2.8 seconds total** (16:45:37.343 → 16:45:40.162) — every
eval threw on the `design.aspect_ratio` field-name mismatch. `4894787` fixed
it. The new 44-row file shares **zero genome hashes** with the old 39: the file
was replaced wholesale, not appended. Worth confirming that was intended.

---

## Suggested order of attack

1. **Reconcile the two `analyse_ring` branches** (F4b). Pass `design` through
   from `sim_frame.jl`, or make the `design === nothing` branch use
   `Do_scale_exp` and `design.r_hub`. Until then `x4` is dead and every
   simulated tube is oversized. This is the single highest-value fix.
2. **Resolve F1** — either lower `Do_lo` to admit the V10 seed, or accept that
   the seed is obsolete and reseed from a genome inside the box. It cannot stay
   as-is: the campaign is anchored to a point it cannot reach.
3. **Re-check FoS scale after (1)** before running anything long. If FoS still
   sits at 10²–10³ the constraint is still inert and the campaign is still a
   power maximiser.
4. **Fix the relax/window tension** (F5) — a `P_mean` from a 90%-swinging
   signal is not a mean.
5. Cheap hygiene: drop `x15` from the search vector (S1), widen or remove the
   k clamp (S2), fix the `lift_tension_N` column or delete it (S3), separate
   the `rejected` tier from `stalled` (S4), delete the stale `best_vector.csv`
   (S8).

## Verification notes

- FoS/util identity `util_a + util_b = 1/FoS_min` holds on all live rows —
  the A1 fix is working. The utilisations are internally consistent; they are
  consistently *tiny*.
- `f_v11 == -P_mean` exactly on all 9 feasible rows, confirming the FoS
  penalty branch of `v11_fitness` never fired.
- Do³ capacity scaling is an order-of-magnitude argument, not a precise one —
  R and `r_hub` vary across designs. It is used only to show the observed
  1.7e4× util collapse is the right *order* for the diameter change, not to
  claim an exact factor.
