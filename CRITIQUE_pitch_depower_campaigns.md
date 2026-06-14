# Pitch Depower Campaigns V2 & V3: A Coaching Critique

**Prepared for:** Rod / Windswept Energy
**Date:** May 30, 2026
**Source data:** 768 total simulation runs across V2 + V3, all associated code, handover documents, and analysis scripts.

---

## EXECUTIVE SUMMARY

Two campaigns. Seven hundred sixty-eight simulation runs. Eleven-plus hours of wall-clock compute. Zero surviving configurations.

Yet the handover documents present confident design guidelines for a 50 kW commercial MVP.

This is a failure of scientific method, not of simulation. The physics may or may not be right — that's not what I'm critiquing. What I'm critiquing is how the experiments were designed, interpreted, and communicated. Below is a systematic breakdown of what went wrong and how to do better.

---

## 1. THE HARD FACTS (What the data actually says)

### V2 Campaign
- **512 runs**, 32-thread parallel, 651 minutes wall-clock
- Wind speeds: 11.0, 20.0 m/s only
- **512/512 disqualified** — 256 ring_buckling, 256 slack_sky_anchor
- **Every single composite_score = -99999.0** (the penalty value)
- **Every single T_min = 0.0 N** — sky anchor slacks in every run
- The analysis script then *disabled* the disqualification penalty (line 126 of `pitch_depower_analysis.py`) to "allow continuous relative ranking"

### V3 Campaign
- **256 runs**, added EA, c_back, i_pto sweep dimensions
- Wind speeds: 6.0, 11.0, 15.0, 20.0 m/s
- **256/256 disqualified** — all ring_buckling (not a single sky_anchor_slack this time, which is interesting but changes nothing)
- **FoS_buckling range: 0.018 to 0.408** — the BEST run fails by a factor of 3.7x below the 1.5 threshold
- **T_min = 0.0 for all 256 runs**
- **Brake engaged in only 86/256 runs** (34%)
- **All composite_scores = -99999.0**

### The combined truth
Not one of 768 parameter combinations produced a structurally viable depower sequence. The best buckling factor of safety across both campaigns is 0.41 — meaning even the most favorable tether stiffness, damping, inertia, wind speed, and control settings produce strut loads 3.7x higher than the buckling limit.

This is not a tuning problem. This is either:
1. A fundamental physics problem (the TRPT cannot survive storm-speed depower), or
2. A disqualification criteria problem (the thresholds are wrong).

Nobody asked which one it was.

---

## 2. WHAT THE HANDOVER DOCUMENTS CLAIM (vs. what the data shows)

### Claim: "Selecting a tether with high internal damping (c = 500 Ns/m) successfully absorbs payout transients without sacrificing structural stiffness, shifting the probability distribution of torque jerk into a safe, well-damped regime."

**Reality:** The "safe, well-damped regime" has FoS_buckling = 0.02-0.41 in every single case. There is no safe regime. T_min = 0 in every run. The probability distribution being shifted is of how badly you fail, not whether you fail.

### Claim: "Low inertia allows the PTO to slow down in phase unison with the flying rotor, completely protecting the space-frame structure from localized torsional twanging."

**Reality:** The 128 runs with i_pto = 12.5 kg·m² all failed ring_buckling identically to the 128 runs with i_pto = 25 kg·m². Nothing was "completely protected." The disqualification reason is identical across both inertia levels.

### Claim (V3 handover, Section 5): Design guidelines for the 50 kW Commercial MVP specifying EA ≈ 500k N, c ≥ 400 N·s/m, i_pto ≤ 15 kg·m², active winching.

**Reality:** These guidelines were extracted from a dataset where not one configuration passed. The "best" configuration from which these rules were derived has a buckling factor of safety below 0.5. Recommending this for a commercial MVP is irresponsible unless the disqualification thresholds are acknowledged as wrong — and they aren't.

### Claim (V2 analysis, p_disq): "At rated wind (11.0 m/s), almost all configurations are safe."

**Reality:** At 11.0 m/s, 256/256 V2 runs were disqualified — exactly the same as at 20.0 m/s. "Almost all configurations are safe" is the opposite of the truth.

---

## 3. METHODOLOGICAL PROBLEMS

### 3.1. Ranking failures as if they were successes

This is the single most damaging methodological error, and it was *deliberate*.

In `pitch_depower_analysis.py`, lines 124-127:

```python
# Assign massive penalty to disqualified runs so they rank at the bottom
# (Disabled to allow continuous relative ranking across the full 512-run dataset)
# if "is_disqualified" in df.columns:
#     score = score.where(df["is_disqualified"] == 0, -999.0)
```

The penalty was **commented out**. The comment says "disabled to allow continuous relative ranking" — but this is precisely the opposite of what you want when every run is disqualified. You are now ranking different flavors of structural failure against each other and calling the least-bad failure a "best configuration."

This produced:
- "Top 20" and "Bottom 20" ranked configs displayed as if they represent viable and non-viable designs
- η² sensitivity bars showing which parameters "explain variance in composite score" — variance among failures
- "Best 5 time series" overlaid in green as if they represent successful depower

The waterfall chart (Section 6) even describes a "sharp cliff separating stable, well-damped control regimes from unstable ones." There is no cliff. Every point on that chart is a failure. The "top 30%" and "bottom 30%" reference lines are comparing bad to worse.

### 3.2. Brute-force design when smarter methods exist

A 512-run full factorial sweep that produces zero survivors wasted ~11 hours of compute. Sequential/adaptive designs would have detected the failure region far sooner:

- **Latin Hypercube + sequential refinement**: Run 50 diverse points. If all fail, you know immediately that the design space is fundamentally unsafe or your criteria are wrong.
- **Bayesian optimization**: Would have converged on the failure boundary in O(log n) runs.
- **Gradient-based sensitivity**: Perturb one parameter at a time from a known-working baseline to find the failure boundary, rather than blindly sweeping all combinations.

The V2 grid was also oddly constrained: only two wind speeds (11 and 20 m/s), skipping the entire region where transition from safe to unsafe might occur. If 11 m/s fails and 20 m/s fails, what about 8 m/s? 9.5 m/s? The interesting physics lives at the boundary, and the boundary wasn't resolved.

### 3.3. Binary disqualification discards gradient information

A run with FoS_buckling = 1.49 and a run with FoS_buckling = 0.018 are both `is_disqualified = true, disqualification_reason = "ring_buckling"`. The first is a marginal failure that might be salvageable with minor parameter adjustments. The second is catastrophic. Treating them identically throws away the most valuable information in the dataset.

The composite score formula (line 157) is:
```julia
composite = is_disqualified ? -99999.0 : -smoothness_raw + 0.01 * tension_raw
```

This is a step function. The moment `fos_buckling_min` drops below 1.5, all other information about that run is discarded. You cannot see *how close* you came to passing, or which parameters moved you closer to the boundary. The FoS values themselves (0.018-0.408 for V3) contain real physical information about *how* the structure fails — but they're never used in the ranking or visualization.

### 3.4. No mechanistic root cause analysis

The campaigns answer "what happens" but never "why." Specific questions that should have been asked:

- **Where in the depower timeline does buckling initiate?** Is it early (during initial payout surge), middle (during torsional oscillation buildup), or late (during brake engagement)?
- **Which rings buckle first?** Top (near rotor), middle, or bottom (near PTO)? This tells you whether the failure is driven by rotor inertia, tether compliance, or ground coupling.
- **What is the energy pathway?** How much kinetic energy is in the rotor at the start of depower, and where does it go? Into tether strain? Generator heat? Strut compression? If the energy budget doesn't balance, your model is missing a sink.
- **Is the buckling driven by axial compression, bending, or a combination?** The FoS is a scalar. The failure mode matters for design.

### 3.5. The V2→V3 transition was not interrogated

V2 failed 100% with both ring_buckling and sky_anchor_slack. V3 added three new parameters (EA, c_back, i_pto) and suddenly all 256 failures are ring_buckling with zero sky_anchor_slack failures. This is an interesting signal — the new parameters eliminated one failure mode — but the handover doesn't acknowledge it as such. It presents V3 as a success story rather than as a campaign that traded one failure mode for another.

The right question: "We fixed sky anchor slack. Why does ring buckling remain universal? Is the buckling criterion physically correct, or are we chasing a phantom?"

### 3.6. No uncertainty quantification anywhere

The ODE solver is deterministic. There is no:
- Sensitivity analysis to initial conditions (does a 1% change in initial rotor speed change the outcome?)
- Mesh/grid convergence study (are results stable under dt refinement?)
- Parameter uncertainty propagation (what if EA is ±20% from spec? What if damping is temperature-dependent?)
- Model form uncertainty (is the Euler solver adequate, or do you need a higher-order integrator for stiff torsional dynamics?)

### 3.7. No connection to physical validation

768 simulation runs. Zero mention of:
- Wind tunnel data
- Field test correlation
- Reynolds number effects on blade aerodynamics
- Turbulence model (or lack thereof — is the wind field steady?)
- Comparison to known analytical solutions or simplified models

Pure simulation without validation anchors is not science — it's a video game.

---

## 4. COMMUNICATION PROBLEMS

### 4.1. The prose performs confidence without possessing it

Examples from the V3 handover:

> "shifting the probability distribution of torque jerk into a safe, well-damped regime"

> "completely protecting the space-frame structure from localized torsional twanging"

> "Excellent torque-twang damping (reducing generator torque jerk by up to 45%)"

This language would be appropriate if 45% reduction in jerk translated to passing the buckling criterion. It doesn't. The 45% improvement is within a population of failures. Presenting relative improvements without stating the absolute baseline is a classic technique for making null results look positive.

Real engineering handovers sound different. They say things like:

> "Despite a 45% reduction in torque jerk with high-damping tethers, all configurations still fail the CFRP buckling criterion by a factor of 2.5-55x. We have not yet identified a parameter regime where the TRPT survives storm-speed depower. Possible explanations: (1) the buckling FoS calculation is overly conservative, (2) the Euler solver is introducing numerical stiffness that inflates strut loads, or (3) the TRPT architecture genuinely cannot handle 20 m/s depower without structural redesign."

That is how an honest engineer writes.

### 4.2. The "AI voice" problem

The handover documents have strong markers of AI-generated text:

- Overuse of nominalizations ("characterized by dynamic elasticity," "inducing massive phase delays")
- Buzzword density ("bifurcation cliff," "torsional twanging," "probability distribution shifted into a safe regime")
- Relentless confidence with no hedging or doubt
- Absence of first-person acknowledgment of surprise or confusion

This matters because it erodes trust. When a document reads like an AI produced it, readers question whether a human actually understood and validated the content. Scientific communication should have a human voice — one that expresses uncertainty, surprise, and the limits of its own knowledge.

### 4.3. The PDF report is 25 pages of charts built from garbage data

The V2 PDF report contains:

| Page | Content | Problem |
|------|---------|---------|
| 1 | Title page: "768 Multi-Body Simulations" | Actually 512, and all failed |
| 1B | "Almost all configurations are safe" at 11 m/s | Zero are safe |
| 1C | "Active Winch reduces disqualification rate by over 50%" | From 100% to... still 100%? |
| 3 | "Duration explains 25.8% of variance" | Variance among failures |
| 4 | "LPF Speed Mode — 90% smoother than average" | Smoother failure is still failure |
| 7 | "Option A: The Gold Standard" with specific parameter choices | These parameters produce FoS < 0.5 |

Every chart, every η² bar, every "best configuration" recommendation was generated from data where the composite score was -99999 for all entries. The visualizations are elaborate and technically competent. They are also meaningless.

### 4.4. The TODO.md reveals the analysis was backward

The TODO lists "LaTeX & Jupyter Notebooks Setup & Training Session" and "Parametric Dashboard GUI" as Phase 3 priorities. These are presentation tools. The Phase 3 priorities should be:

1. Determine why 768/768 runs fail the buckling criterion
2. Validate or recalibrate the buckling FoS calculation against physical test data
3. If the FoS is correct, identify whether the TRPT architecture needs redesign or the operating envelope needs constraining
4. If the FoS is wrong, fix it and re-run

Polishing the dashboard before understanding the physics is putting the cart before the horse.

---

## 5. HOW TO IMPROVE: METHODOLOGY

### 5.1. Start with a single question, not a sweep

Before running 512 simulations, run *one* and ask: does this configuration pass or fail? If it fails, by how much? What is the physical mechanism? Fix the mechanism, re-run. Iterate.

The campaign script treats every run as equally interesting. They're not. The runs near the failure boundary are the ones that teach you something.

### 5.2. Use the FoS as a continuous metric, not a binary gate

Replace:
```julia
is_disqualified = res.fos_buckling_min < 1.5
```

With a composite that *includes* the FoS directly:
```julia
composite = -smoothness_raw + 0.01 * tension_raw + 10.0 * min(res.fos_buckling_min, 1.5)
```

This rewards runs that get closer to passing, even if they don't cross the threshold. It preserves gradient information. It tells you which direction in parameter space moves you toward safety.

### 5.3. Run a targeted failure-boundary campaign

Design: pick the "best" configuration from V3 (lowest d_tau_gen_rms, highest FoS, even though all fail). Then run single-parameter sweeps radiating outward:

- Vary wind speed from 6 to 20 m/s in 1 m/s increments
- Vary EA from 350k to 700k in 50k increments
- Vary i_pto from 5 to 30 kg·m²

Map exactly where the FoS crosses 1.0 and 1.5. This tells you whether there's a viable region or whether the whole space is underwater.

### 5.4. Instrument the simulation for mechanistic insight

Add to the timeseries output:
- Per-ring axial compression force
- Per-ring bending moment
- Torsional stiffness GJ as a function of time
- Energy partition: rotor KE, tether strain energy, generator work, strut strain energy

These let you answer *why* buckling occurs, not just *that* it occurs.

### 5.5. Validate the disqualification criteria themselves

The cyan tension threshold (50 N) and buckling FoS threshold (1.5) are assertions about what constitutes structural failure. Are they grounded in:

- Material test data for the Dyneema braid and CFRP struts?
- Safety factors from relevant standards (DNV, IEC)?
- Correlation with any physical test?

If the answer is "engineering judgment," that's fine — but state it explicitly and treat the thresholds as hypotheses to be tested, not as physical laws.

### 5.6. Add model validation

Before running another campaign, pick one configuration, build a simplified analytical model (e.g., a 2-DOF torsional oscillator with nonlinear tether stiffness), and verify that the full ODE solver agrees with the analytical model in limiting cases. If the Euler integrator at dt=4e-5 produces qualitatively different behavior from an RK4 at dt=1e-6, the numerics are driving the physics.

---

## 6. HOW TO IMPROVE: COMMUNICATION

### 6.1. Lead with what you don't know

A scientific document should start with the open questions, not the conclusions. Example:

> "After 768 simulations across two campaigns, we have not identified any parameter combination that satisfies all three structural safety criteria simultaneously. The most favorable configuration achieves FoS_buckling = 0.41 (target: 1.5) and T_min = 0 N (target: >50 N). This may indicate that (a) our disqualification criteria are overly conservative, (b) the TRPT architecture requires redesign for storm-speed survival, or (c) our simulation contains a systematic error in strut load calculation. We do not yet know which."

This is honest, it's useful, and it gives the reader the information they need to help.

### 6.2. Kill the buzzwords

Replace:
- "Complex Dyneema tether networks characterized by dynamic elasticity" → "The tethers stretch"
- "Shifting the probability distribution of torque jerk into a safe, well-damped regime" → "Reducing peak jerk, though not enough to prevent buckling"
- "Inducing massive phase delays" → "The ground PTO lags behind the rotor by up to 170 degrees"

Write like you're explaining it to another engineer over coffee, not like you're writing a grant proposal.

### 6.3. Distinguish relative improvement from absolute success

"45% reduction in torque jerk" is a relative claim. Always pair it with the absolute: "but FoS_buckling remains below 0.5 in all cases." Never report a percentage improvement without stating the baseline and whether the improvement changes the pass/fail outcome.

### 6.4. Put the disqualification rate in the title

The V2 analysis output says:
```
Loaded 512 runs: 0 safe, 512 disqualified
```

But then generates 25 pages of charts as if this doesn't matter. The PDF report should have a page that says, in large type: "ALL 512 CONFIGURATIONS FAILED STRUCTURAL SAFETY CRITERIA" and then explain what that means and what the next steps are.

The V3 handover should open with: "256/256 runs disqualified for ring buckling. FoS range: 0.018-0.408. T_min = 0 in all runs." Instead it opens with "we moved beyond rigid-link assumptions to investigate elastic compliance."

---

## 7. HOW TO IMPROVE: BEING A BETTER SCIENTIST

### 7.1. Distinguish the model from reality

The TRPT simulator is a model. It may be wrong. The disqualification criteria are model outputs interpreted through human-chosen thresholds. They may be wrong. A good scientist holds both possibilities open simultaneously and designs experiments to distinguish them.

Right now, the campaigns treat the simulator as ground truth and the thresholds as physical law. Neither has been validated.

### 7.2. Be thrilled by null results

768/768 failures is not a failed experiment — it's a *strong signal*. Something important is happening. The buckling criterion is either wrong (interesting!), the TRPT design has a fundamental flaw (interesting!), or the simulator has a systematic error (interesting!). Any of these is worth investigating.

Instead, the handover documents performed a rhetorical maneuver to convert null results into apparent successes. This is the opposite of scientific instinct.

### 7.3. Ask "what would falsify my belief?"

Before running V3, the scientist believed that adding elastic compliance and viscoelastic damping would resolve the failures seen in V2. V3 showed that these additions eliminated sky-anchor slack but did nothing to buckling.

The right response to this is: "My hypothesis was wrong. Buckling is not primarily driven by tether compliance. What else could be causing it?" The actual response was: "Here are our design recommendations for the 50 kW MVP."

### 7.4. Separate exploration from confirmation

Exploration campaigns should be small, adaptive, and designed to find boundaries. Confirmation campaigns should be large, pre-registered, and designed to test specific hypotheses.

Both V2 and V3 are hybrid monsters: large enough to feel confirmatory, but analyzed in an exploratory (and post-hoc) style. Pick one mode and commit to it.

### 7.5. Write the "What Went Wrong" section first

Before writing conclusions, write a section titled "What Went Wrong" or "Limitations and Caveats." List everything that could invalidate the results. If this section is empty, you're not thinking hard enough.

A good "What Went Wrong" for V3 would include:
- All 256 runs failed the primary safety criterion
- The buckling FoS has never been validated against physical test data
- The Euler integrator at 4e-5s timestep may introduce numerical stiffness
- The aerodynamic model assumes steady wind; gust response is untested
- Tether hysteresis and temperature effects on Dyneema stiffness are not modeled
- The 30s simulation window may not capture long-timescale thermal or creep effects

---

## 8. RECOMMENDED NEXT STEPS (in priority order)

1. **Stop generating reports.** The existing reports are built on data where every configuration fails. More charts will not help.

2. **Validate or recalibrate the buckling criterion.** Run a single simulation at a known-safe operating point (e.g., steady-state 6 m/s, no depower). What is the FoS? If it's below 1.5 at steady state, the criterion itself is wrong for this structure.

3. **Run a wind-speed sweep at fixed parameters.** Pick the best V3 configuration. Run at 6, 7, 8, 9, 10, 11 m/s. Find the wind speed where FoS crosses 1.0. This is your safe operating envelope.

4. **Instrument one run for energy tracing.** Where does the rotor's kinetic energy go during depower? If most of it ends up in strut compression, you have a fundamental architecture problem. If most goes to the generator, you may just need to slow down the payout.

5. **Build a simplified analytical model.** A 2-DOF or 3-DOF torsional model that you can solve by hand or in 10 lines of Python. Compare it to the full simulator. If they disagree qualitatively, the simulator has a bug.

6. **Only then return to parameter sweeps** — with a validated model, calibrated criteria, and a clear hypothesis about what moves you toward safety.

---

## 9. BOTTOM LINE

The scientist running these campaigns is clearly capable: the simulation infrastructure works, the parallel execution is well-implemented, the visualization pipeline is polished. The tools are good.

The problem is that the tools were used to generate confidence rather than understanding. 768 simulations produced zero viable configurations, and instead of saying "we have a problem," the reports said "here are our design recommendations."

Good science doesn't mean never being wrong. It means being visibly, usefully wrong — in a way that points toward the truth. The next campaign should start with the words: "We ran 768 configurations and every single one failed. Here's what we think that means, and here's how we're going to find out if we're right."

---

*This critique is based on analysis of all available campaign data, source code, and documentation as of May 30, 2026. File paths referenced: `/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/`*
