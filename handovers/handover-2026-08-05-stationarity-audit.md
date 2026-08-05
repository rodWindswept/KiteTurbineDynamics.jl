# Handover — 2026-08-05 Stationarity Audit

**Scope:** audit of the `stationary=false` on 42/42 result in
`scripts/results/recampaign/feasibility_phase_a_v2.csv`. Source read + CSV
forensics only — no Julia executed (sandbox has no Julia). Every claim below is
re-derivable from the committed CSV and `src/objective_v11.jl` at `1d76492`.

## Headline

**"0 of 42 designs converged" is not a finding.** For 37 of the 42 rows the
stationarity gate is structurally incapable of returning `true`. The flag is
uninformative there. For the 5 rows where it *was* reachable it failed
genuinely, and hard.

Underneath that artefact sits a worse problem the flag was hiding: **25 of 42
rows are not simulations of anything.**

## 1. The gate cannot fire below 100 W

`src/objective_v11.jl:503-505`:

```julia
P_steady   = P_mean > 0.1  ? P_range / P_mean < 0.20 : false
FoS_steady = FoS_min > 0.01 ? FoS_range / FoS_min < 0.20 : false
stationary = dP < 0.10 && dF < 0.10 && P_steady && FoS_steady
```

The `: false` else-branch is unconditional. Any design under 0.1 kW is stamped
`stationary=false` no matter how perfectly settled it is. There is also an outer
guard at `:492`, `mean(P1) > 0.01`, which kills the whole block below 10 W.

| Population | Count | Consequence |
|---|---|---|
| P_mean ≤ 0.01 kW | 36 / 42 | outer guard fails — gate block never entered |
| P_mean ≤ 0.10 kW | 37 / 42 (88%) | `P_steady` hardwired `false` |
| FoS_min ≤ 0.01 or non-finite | 25 / 42 | `FoS_steady` hardwired `false` |

So `stationary=false` on the low-power population is a restatement of "P≈0",
which `P_mean_kw` already tells us. It carries no independent information about
whether the integrator converged.

**A converged, stably-stalled machine and a diverged one are recorded
identically.** That is the defect.

## 2. Where the gate *was* reachable, it failed on amplitude

Five rows have P_mean > 0.1 kW. All five fail the amplitude test, none fail on
drift:

| P_mean (kW) | P_range (kW) | ratio | threshold | FoS_min |
|---|---|---|---|---|
| 8.643 | 7.138 | 0.826 | 0.20 | 0.707 |
| 6.559 | 7.020 | 1.070 | 0.20 | 2.863 |
| 2.354 | 9.210 | 3.913 | 0.20 | 0.509 |
| 0.574 | 8.514 | 14.846 | 0.20 | 0.299 |
| 0.150 | 0.108 | 0.721 | 0.20 | 2.266 |

Misses of 4× to 74×, not marginal. **The handover's headline "P=8.6 kW" is a mean
over a trace whose peak-to-trough swing is 83% of that mean.** Quoting it as a
power figure is not defensible.

## 3. The 25 dead rows

25 of 42 rows have `FoS_min = Inf`, `util_axial = -1.0`, `omega_eq_rpm = 0`,
`P_mean = 0`, `P_range = 0`. Rotors that never turned. `FoS = Inf` because
`fos_samples` was empty or all-Inf (`objective_v11.jl:231`) — infinite structural
safety reported by a structure carrying nothing.

**This invalidates the "structure is adequate" reading.** The 35/42 with FoS ≥ 1.5
is 25 `Inf` sentinels plus 10 real values. Of the 32 genuinely quiet rows, only
7 have a finite FoS at all. 25 of 37 sub-100 W rows sit at exactly 0 rpm.

The campaign did not establish that power is the binding constraint. It
established that ~60% of the sampled space produces machines that never spin up,
and that the instrument cannot distinguish "didn't spin" from "spun safely".

## 4. A5 verified closed in production data

The `Inf`-FoS rejection band holds. All 25 dead rows score `f_feas = 12.0`;
honest stalls span 10.65–11.0. No dead row outranks any real design. The
exploit-register entry is closed against live campaign output, not just tests.

## 5. Latent hazard — sentinel collision (did NOT fire this run)

`run_feasibility_phase_a.jl:70-73`, the `catch` block returns `f_feas = 11.0`.
That is exactly the score of a legitimate `P_mean = 0` stall
(`10 + (25-0)/25 = 11.0`). A thrown exception is therefore indistinguishable
from an honest stall by score, **and ranks better than the 12.0 rejection band** —
crash beats dead sim.

Verified clean in this run: `k_chosen == 0.0` on 0 rows, `lift_tension_N < 0` on
0 rows, so no exception was swallowed. Fix before the next campaign: return 12.0
(or higher) from the `catch`, and log `e` rather than discarding it.

Related: `tier` is computed independently of the `Inf` guard
(`run_feasibility_phase_a.jl:74`), so all 42 read `"stalled"` — the tier label
loses the rejection category that `f_feas` preserves.

## 6. Leading hypothesis for the amplitude failures

`WARM_RELAX_S = 10.0` (`objective_v11.jl:239`) is **one third** of the cold path's
`DISCARD_S = 30.0` (`:44`). A design whose start-up transient outlasts 10 s is
still decaying across the entire 30 s warm-start measurement window, which
inflates `P_range` and makes the 0.20 amplitude test unpassable for numerical
rather than physical reasons.

The window's own comment — *"shorter — signal is in departure"* — says it was
tuned to detect **leaving** a state. A stationarity gate on that same window
demands the opposite. Those two intents are in direct conflict.

This is a hypothesis, not a conclusion. It is testable, and the test is written.

## Changes made this session

| File | Change |
|---|---|
| `src/objective_v11.jl:239-240` | `WARM_RELAX_S` / `WARM_WINDOW_S` const → `Ref`. Defaults identical (10.0 / 30.0); behaviour unchanged unless set. Refs rather than env-read consts specifically to dodge the precompile-cache trap. |
| `src/objective_v11.jl:357,368` | deref `[]` at the two use sites |
| `scripts/diagnose_relax_sensitivity.jl` | new — the test below |

## Next action (desktop — sandbox has no Julia)

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji \
      ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
julia --project=. test/runtests.jl                        # confirm 1859/1859 still green
julia --project=. scripts/diagnose_relax_sensitivity.jl
```

Re-scores the 5 reachable genomes at `WARM_RELAX_S ∈ {10, 30, 60, 120}` s,
window fixed at 30 s, canonical path otherwise untouched. Progressive CSV save
after every eval; resumable by `(genome_hash, relax_s)`.

Reading the output:

- **ratio collapses under 0.20 as relax grows** → artefact. Raise `WARM_RELAX_S`
  to at least `DISCARD_S` and re-run Phase A. The current 42 rows cannot support
  any physics conclusion.
- **ratio flat and high** → physical surge. `stationary=false` is real for those
  5 rows. The other 37 stay uninformative regardless.
- **P_mean itself shifts materially with relax** → every kW figure in the CSV is
  window-dependent and none can be quoted.

Budget: 4 settings × 5 genomes × 3 k-bracket evals, at 10–20 min per warm-start
eval under GC pressure. The 120 s setting dominates.

## Independent of the outcome

1. Fix the `P_steady` / `FoS_steady` else-branches so a settled zero-power design
   reports `stationary=true`. Convergence and productivity are different
   questions and must not share a flag.
2. Give `FoS = Inf` from an empty sample set its own CSV column or tier label.
   `f_feas = 12.0` catches it in ranking, but the tier string still says
   `"stalled"` and the FoS column still says `Inf`, which is what let "35/42 have
   FoS ≥ 1.5" get written down.
3. Raise the `catch` sentinel above the rejection band and log the exception.

## Carried forward from 2026-08-04 (unaffected by this audit)

- Init-path divergence: `settle_to_operational_state` blows up (NaN hub_z,
  ω≈1e141) where `warmstart_with_k_bracket` reports 8.6 kW. Still open, and now
  more urgent — §2 shows the warmstart figure was never trustworthy either.
- B1 dt refinement at dt, dt/4, dt/10 on 3 blowup genomes.
- Lift device: PCA-2 vs CoAx BEM discrepancy, orders of magnitude. The 638 N is a
  hard-coded assumption in every row, and `ring_forces.jl:390-392` exempts
  `RotaryLifterParams` from the 2 m/s passive stall cut-off, so the lifter cannot
  stall in-model.
- Dashboard `--genome-csv` ArgParse registration.

---

# ADDENDUM — relax sweep result (desktop run, `ccd577c`)

`scripts/results/recampaign/relax_sensitivity.csv`, 20 evals, 5 genomes ×
{10, 30, 60, 120} s. **The hypothesis in §6 is refuted, and the script's own
auto-verdict was wrong.** Corrected reading below.

## The classifier was bugged — same defect it was written to expose

v1 classified on `ratio = P_range/P_mean` alone and printed
"MIXED: 2 of 5 genomes settle". It called `7d07fde` and `fca19b4` ARTEFACT
because their ratio fell below threshold. Their ratio fell because **P_mean
collapsed four orders of magnitude** — the numerator died faster than the
denominator. A dead machine reads as perfectly steady.

That is precisely the `P_steady` defect from §1: a ratio whose denominator can
collapse is not a steadiness measure. Credit to the local manager for catching
it. Classifier v2 (committed) requires `P_mean >= 0.1 kW` before it will assess
steadiness, and reports the power trend as a first-class result.

## Corrected verdict: 0 of 5 settle. Every design dies.

| genome | P @10 s | P @120 s | Δ | ratio 10→120 | v2 tag |
|---|---|---|---|---|---|
| `6f9db729` | 6.559 | 3.031 | −54% | 1.07 → 1.21 | DECAYING |
| `7d07fde3` | 2.354 | 0.00011 | −100% | 3.91 → 0.16 | STALLS OUT |
| `873fe660` | 8.643 | 0.000091 | −100% | 0.83 → 9.65 | STALLS OUT |
| `9afcfb4d` | 0.150 | 0.034 | −77% | 0.72 → 0.54 | STALLS OUT |
| `fca19b4c` | 0.574 | 0.000047 | −100% | 14.85 → 1.47 | STALLS OUT |

`SETTLES 0 · SURGES 0 · DECAYING 1 · STALLS OUT 4`

Not "2 artefact, 3 physical" (script v1). Not "2 stall-out, 3 genuine surge"
(manager). **5 of 5 lose power monotonically as the observation window moves
out**, 4 of them to effectively zero. There is no plateau at any relax time.

**This is not a "tune `WARM_RELAX_S`" problem.** There is no correct window to
pick, because no design has a steady state to find. The 10 s campaign figure is
simply the highest point on a decay curve. Every P in
`feasibility_phase_a_v2.csv` is a readout of how far a design had got through
dying when sampling happened to stop.

## FoS_min is window-dependent, and moves the wrong way

Worse than the power result, because FoS is the gate the whole campaign is built on.

| genome | FoS @10 s | @30 s | @60 s | @120 s | swing | crosses 1.5 gate |
|---|---|---|---|---|---|---|
| `6f9db729` | 2.863 | 2.183 | 1.744 | 1.490 | 1.9× | yes |
| `7d07fde3` | 0.509 | 0.603 | 11.14 | 11.89 | **23.4×** | yes |
| `873fe660` | 0.707 | 3.888 | 3.705 | 7.796 | **11.0×** | yes |
| `9afcfb4d` | 2.266 | 3.948 | 6.234 | 3.170 | 2.8× | no |
| `fca19b4c` | 0.299 | 2.537 | 3.312 | 4.634 | **15.5×** | yes |

**4 of 5 cross the FoS ≥ 1.5 design gate purely as a function of when you look.**

`873fe660` — the 8.6 kW headline genome — reads P=8.64 kW / FoS=0.707 (fails
structure) at 10 s and P=8.84 kW / FoS=3.89 (passes comfortably) at 30 s. Same
design, same code, same k, same wind. **The structural verdict flips from fail to
pass on a window change alone.** No FoS in the campaign is quotable.

Direction is systematic, not noise: across all 20 evals,
Pearson r(log P, log FoS) = **−0.598**, Spearman ρ = **−0.552**. 4 of 5 genomes
are individually anti-correlated. **The structure looks safer the less power it
makes** — an unloaded structure is a safe structure. This is the mechanism behind
§3's "25 dead rows report FoS = Inf", now measured continuously rather than only
at the degenerate limit. The campaign's "structure is adequate" reading is an
artefact of measuring machines that had stopped working.

Only `6f9db729` has FoS *falling* with relax — and it is the only one still
holding meaningful power at 120 s (3.03 kW). Consistent with the same mechanism.

## The k-bracket is also window-dependent

`k_chosen` switched on 2 of 5 as relax grew: `7d07fde3` 246.5 → 492.9,
`873fe660` 461.3 → 115.3 (a 4× drop). The bracket keeps whichever of its three
candidates scores best over the window, so when the window changes, a different
k wins. It is not locating a physical MPPT point; it is locating whichever k
looks best over an arbitrary interval. Any campaign `k_chosen` inherits this.

## Next question: physical spin-down or numerical dissipation?

Two readings of the universal decay, with opposite consequences:

- **PHYSICAL** — aero torque cannot sustain rotation against generator + losses,
  so these machines genuinely spin down at rated wind. Plausible: the
  induction + α fix (`234a722`) already cut triangle from 117 kW to ~20 kW at
  11 m/s. If so the campaign's real finding is that the whole sampled envelope is
  non-viable, and the search space needs rethinking, not the instrument.
- **NUMERICAL** — the integrator bleeds energy over the 30–120 s horizon. Then
  every long-horizon result in the project is suspect, not just this campaign.

**These are distinguishable and the test is cheap.** Trace ω(t), τ_aero(t),
τ_gen(t) over the full 120 s on the warm-start path. If ω decays and
τ_aero < τ_gen + losses throughout, it is physical. If ω holds while P falls, or
if the torque balance does not close, it is numerical.

Do it by adding a `callback` kwarg to `objective_v11_warmstart` and forwarding it
to the existing `run_canonical_sim!` call — **not** by replicating the ~80-line
init sequence in a standalone script, and **not** via
`settle_to_operational_state`, which blows up on these genomes (§ carried
forward). Guarantees the trace is the identical code path that produced the
numbers above.

## Minor: telemetry omits the lift device

`objective_v11.jl:381` calls `capture_extended(..., wf, nothing; ...)` while the
ODE runs *with* the lift device. Checked: in `capture_frame` the `lift_device`
argument only populates `T_lift`, `elev_lift`, `lift_margin`, `lift_type`
(`sim_frame.jl:213-229`); it does **not** feed `max_util`, `ring_fos` or `T_max`,
which come from the state vector and therefore already include the lift force.

So this is a **reporting-only** defect — P and FoS above are unaffected. It does
mean the objective's own `T_lift`/`lift_margin` read zero, and that the campaign's
`lift_tension_N` column comes from a separate `lift_force_steady` call
(`run_feasibility_phase_a.jl:76`), which is why it is ~638 N on every row
regardless of what the machine was doing. Pass `lift_device` for consistency;
nothing downstream changes.

---

---

# ADDENDUM 2 — design-aware lift device (Rod, 2026-08-05)

## The bias

`LIFT_DEVICE` was a `const RotaryLifterParams(1.3 m, ...)` in the campaign
launcher — outside the genome, outside `search_bounds_v11`. Every design received
an identical ~638 N. Meanwhile `autogyro_lift_required` built its requirement from
a hard-coded `m_shaft = 12.0 # kg — v5 optimized shaft`, so it reported a healthy
2.2–2.8× margin for every genome regardless of what was actually being lifted.

638 N is ≈61 kg of vertical support at a 70° line. What that means by design scale:

| airborne mass | T_line needed at 1.5× | old fixed 638 N covered |
|---|---|---|
| 25 kg (v5 reference) | 391 N | 163% |
| 74.17 kg (V6.2 optimum) | 1,161 N | 55% |
| 150 kg | 2,349 N | 27% |
| 300 kg | 4,698 N | 14% |

Light designs were over-lifted, heavy ones starved, monotonically. **Torsional
rigidity costs mass, mass was unsupported, and the margin readout concealed it.**
The optimiser could not buy stiffness. This is a strong candidate for the sinking
mechanism in Addendum 1 — and it would explain why the DE kept converging on huge
rotors with minimal ring counts.

## The change

**Presume the coaxial autogyro stack delivers enough lift at the lift bearing to
hold the machine smoothly in the air, and size it to 1.5× this genome's weight.**
Stack sizing lives in `CoaxialAutogyroStacking.jl` and is deliberately out of
scope here. The presumption is to be published as one.

`StackedLifterParams` + `sized_lifter_for(sys, p; margin=1.5, v_ref=11.0)`:

    T_ref = margin · m_airborne · g / sin(elevation)      # vertical = margin × weight
    T(v)  = T_ref · (v / v_ref)²                          # dynamic-pressure scaling

`m_airborne` comes from `expansion_airborne_mass` — the design's real tether,
rings, blades and expansion rotors.

**Wiring note that matters.** `lift_device` now also accepts a `Function`, called
as `f(sys, pc)` once the system is built, because the device cannot be constructed
before the genome's mass exists. It is handed **`pc`, not `p`** — `p` is the shared
base `SystemParams`, `pc` is the one carrying this genome's `n_lines`, `n_rings`,
`tether_length` and blade-scaled `m_blade`. Sizing against `p` computes an
identical mass for every genome and silently reintroduces the exact bias this
removes. Guard that in review.

| File | Change |
|---|---|
| `src/lift_kite.jl` | `StackedLifterParams`, `sized_lifter_for`, `lift_force_steady` method; `autogyro_lift_required(p, sys=nothing)` now design-aware |
| `src/objective_v11.jl` | `lift_device` accepts `Function`; resolved against `pc`; `lift_dev` substituted at all three use sites |
| `src/ring_forces.jl` | `StackedLifterParams` exempt from the 2 m/s passive stall cliff (it already fades as v²) |
| `src/sim_frame.jl`, `src/visualization.jl` | pass `sys` to `autogyro_lift_required` |
| `scripts/run_feasibility_phase_a.jl` | design-aware `LIFT_DEVICE`; `catch` now returns 12.0 + logs (was 11.0, colliding with a legitimate P=0 stall) |
| `scripts/trace_altitude_torque.jl` | same device; `KTD_LEGACY_LIFT=1` reproduces the old fixed force for A/B |

## Self-check when it runs

`lift_margin` is `T_lift / autogyro_lift_required(p, sys)`, and the requirement is
the 1.0× weight figure — so a correctly wired sized lifter reads **1.50×**. Any
other value means the sizing did not take. The trace script asserts this and
prints the implied airborne mass alongside.

## Do this first

Run the trace **both ways** — `KTD_LEGACY_LIFT=1` and without. If the machines
stop sinking under design-aware lift, Addendum 1's decay is explained and Phase A
must be re-run from scratch: every one of the 42 rows was scored under a lift
device that could not hold the design up.

---

## Handover-vs-CSV conflicts — do not quote `handover-2026-08-04-session.md` numbers

1. Says best genome `k_mppt = 0.01` and "DE converged on zero torque extraction".
   CSV `k_chosen` spans 12.3–1000 with no row below 1.0; best row is k=461.
   Unsupported by this file.
2. Says ω ≈ 25 rad/s for the campaign path. CSV says 39.2 rpm ≈ 4.1 rad/s.
3. Frames solver instability as a best-genome problem. It is a whole-table
   problem, and for 37 rows it is not a solver problem at all — it is a gate
   that could not fire.
