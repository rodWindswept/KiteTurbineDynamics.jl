Rod → Stornoway desktop. Current-state handover, superseding the operational
parts of `handover-2026-07-25-phase-a-instrument-audit.md` (that document's
reasoning still stands; its status claims are now out of date). Written after
57b064a and 5d02d45.

**Decision taken (Rod, 2026-07-25): the campaign holds.** No relaunch until
Part A lands. Rationale: the next run costs ~40 hours and the frames-versus-tubes
decision depends on data it cannot currently produce. A run started now would
finish without trustworthy bending attribution and could re-converge on the
degenerate family. Part A is roughly a day of work and makes the run worth its
compute.

---

# Pre-relaunch blockers, diagnostics, and housekeeping

## State of the exploit register

Rows 1, 2 and 4 are genuinely closed — verified in source, not just claimed.
`objective_feasibility` now guards non-finite and non-positive FoS before the
tier logic, its `P_floor` default is 25.0, and the stationarity gate computes
`dF` from `fos_finite` halves as a relative difference. The register and the
code now agree, which is the first time this fortnight that has been true.

Rows 3, 5, 6, 7 remain open and are correctly marked so.

---

## Part A — Blockers. All five before relaunch.

### A1. Util split must come from the FoS-min sample (highest value)

**Where it stands.** `objective_v11.jl` ~402–404 comments the util capture as
"at FoS-min sample" but computes `maximum(...)` over each sample array
independently. Two independent window maxima are not tied to each other, nor to
the instant that produced `FoS_min`.

**Why it matters more than anything else open.** From
`ring_element_analysis.jl`, `util = N_term + M_term` and `fos = 1/util` for a
single beam at a single instant — so `util_axial + util_bending = 1/FoS_min` is
an identity, not an approximation. It currently fails on ~26% of rows. Every
statement of the form "bending is 24× the elastic limit, therefore tube sizing
cannot close it, therefore frames" derives from these two columns. The physics
behind the frames direction is sound independently (`I ∝ Do⁴`; internal webs put
mass near the neutral axis where `y² → 0` and buy almost nothing; `t_over_D` is
capped at 0.15 for real reasons). What is unknown is the *size* of the deficit,
and that is exactly what decides whether a diameter increase closes it or a
topology change is mandatory. We are one instrumentation fix away from knowing.

**Do.** Record the ring index and window sample index at which `FoS_min` occurs,
then take `N_ax/N_crit` and `√(M_ip²+M_oop²)/M_el` from that beam at that
sample. Assert the identity inline and fail loudly rather than writing an
inconsistent row. Fix the comment to match.

**Acceptance.** On ≥20 re-evaluated rows spanning `n_active` 1–4:
`|ua + ub − 1/FoS_min| · FoS_min < 0.01`, no exceptions. Then re-read the
bending multiple from the corrected rows — expect it to move.

### A2. Betz ceiling (register row 3)

**Why.** The only current bound is `P_mean > 1e6` — a 1 TW overflow trap, about
ten million times the machine's ceiling. The 1103 kW row (≈10× over) passed it
untouched, became a parent, and contaminated gens 12–13. DE is a population
method: an impossible design is not one bad row, it is an ancestor.

**Do.** Compute the design's swept-area Betz ceiling and reject any evaluation
whose `P_aero` or `P_mean` exceeds it, into the rejection band (see A5) with a
reason column. This is a sanity bound, not a model — it should never bind on a
valid design, and frequent binding is itself the finding.

**Acceptance.** Re-scoring the archived CSVs flags the 1103 kW and 205 kW rows
and leaves every row below the ceiling untouched.

### A3. n_rings gate (register row 5) — with a scoping caveat

**Do.** Reject `n_rings < 5` at decode, before the ODE.

**But scope it correctly, and re-test it.** The register frames this as a
degenerate-geometry exploit. The likelier account is that it was the *attractor
of row 1*: `n_active = 1` with `n_rings = 3` is the least structure the encoding
permits, hence the shortest path to a degenerate sim, hence `FoS = Inf`, hence
−1.0. Note `objective_feasibility` never sees mass — the earlier "DE is
minimising structural mass" reading cannot be right for this objective, though
it was correct for v10 where `mass_total_kg` was the fitness.

Consequences: log the gate as a **model-validity bound** (like the Betz
ceiling), not as a physical finding about the machine — we are excluding
`n_rings = 3` because the Tulloch model is uncalibrated at `L/r > 3.5`, not
because three rings are physically impossible. And after row 1's guard is in
force, check whether the family still appears without the gate. If it does not,
the gate is insurance rather than necessity, and that distinction matters when
someone later asks why the design space is restricted.

### A4. x8 dead zone — fix before relaunch because it changes the space

**Found by the glossary on its first day, which is the argument for the
glossary.** Bounds give x8 ∈ [3, 16]; `ring_spacing.jl:409` clamps
`clamp(Int(round(x[8])), 3, 12)`. Everything above ≈12.5 decodes to 12 lines —
~27% of the dimension is dead. Confirmed empirically: across all three campaign
CSVs (200+ evals) no design ever decoded above 12 lines.

**Why it is a blocker rather than a tidy-up.** The blowup family sat inside the
dead zone (x8 mean 15.09), where the DE gets no discrimination on that axis at
all. Populations collapse onto plateaus, so this plausibly contributed to the
convergence independently of the Tulloch story. Also: every plan and handover
stating "n_lines up to 16" is false and should be corrected.

**Do.** Either raise the decoder clamp to 16 or lower the bound to 12 — a design
decision, not a bug fix, so make it deliberately and record which and why.
x10 has the same defect in miniature (bound 60.0, clamp to 59); x3 is a dead
dimension at 1.0–1.0 that the DE still mutates across.

### A5. Rejection band above the stalled tier (row 1 residual)

**Why.** As written, a null-FoS design with `P ≥ P_floor` returns exactly
`10.0`, while honest stalls return `10 + (P_floor − P)/P_floor` ∈ (10, 11]. Null
measurements therefore score *strictly better* than every genuine stall. In a
population where most evaluations are rejects — which is where this campaign has
lived — the DE would still preferentially breed null-measurement designs. The
ratchet is reduced in amplitude, not removed.

**Do.** Give rejections a distinct band that can never be preferred: return
≥ 12.0 for non-finite FoS, Betz violations and geometry rejections, with a
reason column distinguishing them. Ordering becomes
`feasible < feasibility < stalled < rejected`.

**Acceptance.** Unit tests asserting every rejection path exceeds every stalled
score.

---

## Part B — Diagnostics that decide the structural programme

These do not block relaunch but they decide something larger than the campaign.
16 of 17 blowups share one fingerprint: `n_lines = 12`, `n_active = 1`,
`n_rings = 3`, L/seg ≈ 22 m, `L/r > 3.5`, high k. (Caveat on reading the earlier
per-gene correlations, mine included: that sample is one cluster, so per-gene
`r_pb` values were six projections of a single family, not six mechanisms.)

### B1. dt refinement

`V11_DT = 4e-5` in `objective_v11.jl` is the single constant to vary. Run three
blowup genomes at dt, dt/4, dt/10. Clean integration at smaller dt means the
failures are numerical — the τ = k·ω² positive-feedback path — and the guard is
mislabelling designs. Failure at every dt means genuine instability.

### B2. Real-tension Tulloch margin

The existing margin audit used `T_line = 500 N` as a placeholder and returned
positive margins of 6–69°; under ODE loading actual tension is plausibly 5–10×
that, which would move the answer. Pull `T_line` from the ODE state at the
blowup instant (the tension-chain / extended-frame fields) and recompute
`δα* − |Δα|` there. From `ring_forces.jl`:
`δα* = 2·arcsin(L/√(2(L²+2r²)))` and `τ_cap = T_total·r²/√(L²+2r²)` — note both
depend on L and r only, so `Do_top` does *not* shift the collapse threshold; its
route is torsional compliance (GJ ∝ Do⁴ → more twist accumulated per unit
torque → a fixed δα* reached sooner).

**Reading the results.** Twist crossing δα* before the NaN in every dt condition
→ Tulloch, genuine, guard correct, and the binding constraint is torsional.
NaN vanishing at dt/10 → numerics. Note that `n_lines` appears in the numerator
of `τ_cap` via `T_total`, so Tulloch predicts more lines gives *more* margin —
the wrong sign against the observed fingerprint. That tension needs resolving
before the torsional account is accepted.

**Why this outranks the campaign in importance.** If Tulloch is binding, the
frames/trusses direction is aimed at the wrong failure mode: overtwist is a
kinematic/torsional limit and a stiffer bending frame does not obviously raise
`τ_cap`. The levers there are larger ring radius, shorter segments, higher
pretension. Committing the airframe programme to bending stiffness while the
machine fails in torsion would be an expensive misread.

**Cheap win regardless.** Add `collapse_margin_deg` and `max_twist_deg` as
first-class CSV columns and put a twist gate in the objective. `sim_frame.jl`
already computes `segment_twist_deg`, `control_map_hunt.jl` already computes
collapse margin, `objective_v10` has Gate 5, and `soft_ramp_controller` tracks
`margin_i = δα*_i − |Δα_i|`. The campaign objective is the only instrument in
the project blind to twist. Closing that converts an unexplained crash into a
scored constraint.

---

## Part C — Housekeeping that stops this recurring

1. **Glossary drift test.** The header says bounds are "asserted by test"; the
   test does not exist. Write it — committed glossary must match
   `search_bounds_v11` and the decoder clamps, red on drift — or mark the header
   PENDING until it does. A document establishing trust must not overstate its
   own verification.
2. **Register discipline.** Keep the Status column honest: no row says closed
   until the named test exists and passes. The register was created because
   claims outran verification; it briefly contained six claims that outran
   verification. The format now works — keep it.
3. **Report generator and liveness.** Historical generations changed between
   cron reports (gen 0 best FoS appeared as 0.5095, 0.059, 10.00, 0.51) and
   "NOT RUNNING" was reported four times while eval counts climbed 46→105.
   Define liveness as new rows plus advancing timestamps, never process state.
   Prove the generator by running it twice over a frozen CSV: byte-identical or
   it is not fixed.
4. **Test-suite audit after the P_floor default change.**
   `test_objective_v11.jl:101–103` call with defaults and carry comments
   referencing `P_floor = 1.0`. Line 119 was testing within-feasible-tier
   monotonicity and now compares across tiers, passing vacuously.
5. **Stationarity nits.** `all(isfinite.(fos_finite))` is trivially true after
   filtering. `dF` compares half-window *means* while scoring uses the *min*, so
   a design with a steady mean and a downward-spiking minimum passes; min-based
   comparison is the truer test.

---

## Part D — Relaunch checklist

Relaunch when all of these hold:

- [ ] A1 identity passes on ≥20 rows spanning `n_active` 1–4
- [ ] A2 Betz guard flags the two known rows, touches nothing else
- [ ] A3 gate live, logged as model-validity, family re-checked without it
- [ ] A4 x8 resolved deliberately and prior "up to 16" claims corrected
- [ ] A5 rejection band ordered above stalled, unit-tested
- [ ] Archived CSVs re-scored under the corrected rules into new files with a
      provenance header naming the commit — banners, not rewrites
- [ ] The re-scored power-versus-FoS Pareto front reviewed before committing
      another 40 hours. That front, not the best `f_feas`, is what the
      frames/trusses decision should be argued from.

## Part E — Settled; do not relitigate

- `P_floor = 25 kW`. Throttling the generator to protect the frame is not an
  optimisation strategy.
- `n_active` is expansion-rotor *station placement*, not line selection. All
  `n_lines` always carry tension. `VALID_ROTOR_MASKS` requires bit 0 set and
  `min_gap = 2`, so the hub station is always active and `n_active = 1` is the
  minimum the encoding permits — not an arbitrary choice.
- The v10 static instrument is closed as unevaluable under both physics eras.
- The recording-bug fix and the re-eval that proved P/FoS were nonetheless
  intact were the right call, correctly executed.
- Gaming risks are objective-specific: mass-minimisation motives apply to v10,
  where `mass_total_kg` was the fitness, and not to the current objective.
