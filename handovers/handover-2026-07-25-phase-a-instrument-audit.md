Rod → Stornoway desktop. This is an audit of the running Phase A campaign, not
a new plan. Each item states **what was observed**, **why it matters**, **what
the reasoning implies**, and **the acceptance test that closes it**. The order
is deliberate: item 1 gates a structural-topology decision, so it comes first
even though item 2 is the more clear-cut bug.

Standing principle, carried from the trust log and earned five times in eight
days: *a metric that is uniform across varying conditions, or that contradicts
its own definition, is an instrument reading — not a physical finding.* Every
item below is an application of that one rule.

---

# Phase A instrument audit — 2026-07-25

## 0. Why this audit exists now

The campaign is producing a strategic conclusion — "bending overstress is ~24×,
tube sizing cannot close it, move to frames/trusses" — and that conclusion is
about to redirect the airframe programme. Before a decision of that size, the
instrument that produced the number has to pass its own consistency check. It
currently does not. Nothing here says the conclusion is wrong; it says the
conclusion is not yet *evidenced*, and separates the parts that are solid from
the parts that are pending.

---

## 1. The 24× bending number rests on a column that fails its own identity

### Observed

In `feasibility_phase_a_Pfloor1.csv`, `util_axial + util_bending` does not equal
`1/FoS_min`. It misses by more than 10% on 18 of the 68 rows carrying util data
(~26%), and by 19.8% on ae59adf6 — the row that was briefly promoted to GREEN.
Separately, every `n_active = 1` design reports `util_bending` exactly 0.

### Why this is an identity, not an approximation

From `ring_element_analysis.jl`:

```julia
util = N_term + M_term          # beam_column_utilisation, ~line 296
     = max(N,0)/N_crit + √(M_ip² + M_oop²)/M_el
fos  = 1/util                   # extract_beam_forces, ~line 278
```

`util_axial` and `util_bending` are *defined* as the two addends of the quantity
whose reciprocal is FoS. For one beam at one instant, `ua + ub = 1/fos` holds
to floating-point rounding. There is no modelling assumption in it and no
tolerance to negotiate. If it fails, the three numbers did not come from the
same beam at the same instant.

### What the failure most likely means

`FoS_min` is a double minimum: over airborne rings, and over the ~30 window
samples (`objective_v11.jl` ~line 222, `minimum(fos_samples)` where each sample
is itself a min over `ef.ring_fos`). The util split is captured separately. If
the split is taken from the worst beam of the wrong ring, or the worst beam at
the wrong timestep, or is aggregated per-ring before the split is taken, then
the recorded shares describe **a different beam than the one that is actually
failing**.

This was previously waved off as "a ring-vs-beam aggregation artifact, not a
wiring bug." For the purpose it is being used for, that distinction does not
exist. The whole point of the split is to attribute *the governing failure* to
axial or bending. If the split comes from a non-governing beam, the attribution
is unfounded — and the attribution is the entire basis for "24× bending →
frames." The `n_active = 1 → bending ≡ 0` pattern is consistent with the same
defect (a symmetric-loading beam being sampled instead of the loaded one) and is
itself the classic instrument-floor signature.

### Instruction

Make the util split come from the argmin of the same double minimum that
produces `FoS_min`: record the ring index and window sample index at which
`FoS_min` occurs, then take `N_ax/N_crit` and `√(M_ip²+M_oop²)/M_el` from *that*
beam at *that* sample. Assert the identity inline and fail loudly rather than
recording a silently inconsistent row.

### Acceptance test

On ≥ 20 re-evaluated rows spanning `n_active` 1–4:
`|ua + ub − 1/FoS_min| · FoS_min < 0.01` on every row, no exceptions. Only once
that passes does the "24×" figure become a number worth designing against — and
it should be re-read from the corrected rows, because it may move by an order of
magnitude in either direction.

### What this does *not* put in question

The scaling physics behind the frames/trusses direction stands independently:
`I ∝ Do⁴`, internal webs and infill add mass near the neutral axis where `y² → 0`
and buy almost nothing, and `t_over_D` is capped at 0.15 for a real reason
(beyond it the tube is approaching solid rod for ~32% more `I` at ~76% more
mass). If a genuine multiple-× bending deficit survives the fix, frames/trusses
remain the right answer. What is pending is only *the size of the deficit* — and
that is what decides whether a Do bump closes it or a topology change is
mandatory.

---

## 2. A failed simulation currently scores as the best possible design

### Observed

Ten rows carry `FoS_min = Inf`, `f_feas = −1.0`, `tier = feasible`.

### The code path

`objective_v11.jl` ~line 222:

```julia
FoS_score = isempty(fos_samples) || all(isinf.(fos_samples)) ? Inf : minimum(fos_samples)
```

`Inf` here is a **null result** — it means the window produced no valid airborne
structural sample. It is the sentinel for "did not measure," not for "infinitely
strong."

`objective_feasibility` (origin/master) has no guard on it:

```julia
if     P_mean < P_floor   ...   # stalled
elseif FoS_min < FoS_design ... # feasibility
else   return -min(P_mean, P_cap)/P_cap   # feasible
end
```

`Inf < 1.5` is false, so the null result falls through to the feasible tier and
scores `−1.0` — the floor of the objective, the best value the function can
return. A design whose structural measurement failed outranks every design that
was actually measured.

### Why it has not caused visible damage yet

Only the `stationary = true` requirement added to the GREEN break is stopping
these from terminating the campaign. That is luck, not defence in depth — and it
is exactly the failure mode the three-tier design was built to prevent. The
stalled tier exists because an *unloaded* structure fakes high FoS; this is the
same pathology one level deeper, where an *unmeasured* structure fakes infinite
FoS.

### Instruction

Guard on non-finite FoS explicitly, ahead of the tier logic, and route it to a
rejection score at or above the stalled tier. `NaN` gets the same treatment
(`NaN < 1.5` is also false, so it takes the same path today). Then audit the
ten affected rows: whether the null result is a sim failure, a geometry with no
airborne rings, or a `ring_fos` population bug is itself worth knowing.

### Acceptance test

Unit tests asserting `objective_feasibility(P, Inf) ≥ 10` and
`objective_feasibility(P, NaN) ≥ 10` for P above and below `P_floor`, added to
the existing tier-ordering testset. Re-scoring the archived CSVs must move all
ten rows out of the feasible tier.

---

## 3. Super-Betz rows are entering the population

### Observed

Gen 13 produced P = 1103 kW at FoS = 0.007; gen 12 produced 205 kW.

### The arithmetic

At 15 m/s, `½ρv³ ≈ 2.07 kW/m²`; the Betz ceiling is `0.593 ×` that, ≈ 1.23
kW/m². 1103 kW therefore requires roughly 900 m² of swept area. An 8 m ring
sweeps ~200 m², and the design's union area is well below the sum of its
annuli. The row is ~5–10× over the physical ceiling — it is the energy
non-conservation signature from the pre-induction era reappearing, or a
transient being read as an operating point (the k = 1000 diagnosis found exactly
that: spin-down transients scoring as power).

### Why it matters beyond the one row

DE is a population method. An impossible design does not merely produce a bad
row — it becomes a parent, and its genome propagates into subsequent
generations. Any trend line computed across gens 12–13 is contaminated.

### Instruction

Add a hard physical-admissibility reject in the evaluator: compute the design's
swept-area Betz ceiling and reject (rejection tier, flagged with a reason
column) any evaluation whose `P_aero` or `P_mean` exceeds it. This is a sanity
bound, not a model — it should never bind on a valid design, and if it starts
binding frequently that is itself the finding.

### Acceptance test

Re-scoring the archived CSVs flags the 1103 kW and 205 kW rows and leaves every
row below the ceiling untouched.

---

## 4. The progress reports contradict themselves and the liveness check is wrong

### Observed — liveness

The 2-hourly cron reported "campaign stopped / NOT RUNNING / no julia process"
at 22:51, 00:53, 02:57 and 05:11, while the eval count over the same window rose
46 → 63 → 78 → 92 → 105. The campaign was alive throughout. This is the same
0%-CPU sampling artifact already diagnosed once during launch.

### Why it is dangerous rather than merely annoying

A false "stopped" invites a kill-and-relaunch. This session has already lost
four hours to an inverted resume guard, and every relaunch so far has either
introduced or exposed a fault. A monitoring signal that cries stop is worse than
no monitoring.

### Observed — report integrity

Historical generations change between reports. Gen 0 best FoS appears as 0.5095,
then 0.059, then 10.00, then 0.51. Gen 2 appears as 2.4522, 0.172, 0.008, 2.45.
Completed rows are immutable, so at least three of those four readings are wrong
in each case — the report generator is applying different filters, columns, or
Inf-handling on each run.

### Consequence

Every trend table produced by the cron is unreliable, including the
"f_feas 1.44 → 1.26, DE is working" reading that has been shaping tactical
decisions. The underlying CSV may be fine; the lens is not.

### Instruction

Define liveness as *new rows appearing* — compare row count and max timestamp
against the previous report, not process state. Fix the report generator to a
single deterministic query, and prove it by re-running it twice over a frozen
CSV: byte-identical output, or it is not fixed.

---

## 5. Sequencing, and what to do with the running campaign

Items 2 and 3 change scoring, so they cannot be hot-patched into a live search
without making the population half-scored under each rule — the same mid-campaign
ambiguity Stage 1 was structured to avoid. Item 1 is instrumentation only and
does not affect `f_feas`. Item 4 touches nothing the campaign reads.

Recommended order: let the current run finish or stop it deliberately (either is
defensible — it is a probe), then land 1–4 together, re-score the archived CSVs
under the corrected rules, and only then decide whether to relaunch. Re-scoring
is cheap and answers the question that matters most: **with null results and
super-Betz rows excluded, and the util split corrected, what does the
power-versus-FoS Pareto front actually look like?** That front, not the raw best
f_feas, is what the frames/trusses decision should be argued from.

Preserve every archived CSV as-is. Re-scored outputs go to new files with a
provenance header naming the commit that produced the corrected rules — banners,
not rewrites.

## 6. What is settled and should not be relitigated

- `P_floor = 25 kW` is correct. Throttling the generator to protect the frame is
  not an optimisation strategy, and the old floor let the DE win by unloading.
- The `n_active` diagnosis is correct and important: it is expansion-rotor ring
  *placement*, not line selection; all `n_lines` always carry tension. The
  optimiser was gaming it by placing a single rotor. If a minimum-`n_active`
  constraint is wanted later, that is a design decision, not a bug fix.
- The recording-bug fix (hardcoded `k = 0`, `ω = 60`, `P_range = 0` in the DE
  child `save_row`) was found and fixed correctly, and the decisive re-eval that
  proved P/FoS were nonetheless intact was exactly the right test to run.
- The static v10 instrument is closed as unevaluable under both physics eras.
  Nothing below depends on it.
