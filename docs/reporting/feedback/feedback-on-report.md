Thanks for sharing the draft. The strongest parts are the provenance discipline, the signed-row citations, the failure ledger, and the explicit model boundaries. The main weakness is that it currently reads like three documents fused together:

1. a scientific/engineering report,  
2. an internal audit/register log, and  
3. a project-management changelog.

If you separate those layers and make the reader-facing story cleaner, this can become much stronger.

Below is a practical improvement plan, with specific fixes.

---

## 1. Highest-impact changes to make first

### A. Write the abstract and keywords now, even if provisional
Right now the abstract is `[PENDING]`. Even in a draft, you should have a short working abstract so the reader immediately knows:

- what machine was studied,
- what design space was searched,
- what method was used,
- what the best result is,
- what the major limitations are.

A possible placeholder abstract:

> This report presents a simulation-based design search for a ground-generation rotary kite turbine using a tensile rotary power transmission (TRPT). The search varies ring geometry, polygon count, rotor count, blade bank angle, and blade scale under a 5 kW-class power-law generator load. A differential-evolution campaign evaluated 930 candidate designs over an honest operating window. The best feasible candidate produced 5.31 kW mean power with a minimum structural factor of safety of 14.97 under the modeled assumptions. All checked TRPT rings and twist segments operate below their failure boundaries in the final operating point. The study is simulation-only; blade integrity, lifter modulation across wind speeds, and rapid-path rope-break gating remain open limitations.

Then refine it once Phases 1–3 land.

---

### B. Move internal process notes out of the main text
These are useful for your team, but they clutter the report body:

- version history `v0.1` through `v0.10`,
- “lead pass by @hermes”,
- “owners refine this text against Track A and Track B responses”,
- bracketed notes like `[Terms await the Track D glossary]`,
- `[Closed 2026-10-08: selection, not derivation...]`,
- `figure-map row X` references in the main narrative,
- “Build record (builder output)”.

Move these to:

- a separate **Document control / version history** page,
- an **Appendix: Register index**,
- an **Appendix: Figure provenance**,
- or a project-management issue tracker.

The main report should cite evidence cleanly, for example:

> The campaign evaluated 930 designs (NR-001).

But the reader should not have to understand “figure-map row 6” unless that term is defined or moved to an appendix.

---

### C. Finish or explicitly quarantine the pending sections
You currently have major pending blocks in core results:

- `3.4 The levers [PENDING]`
- `3.5 The evolution story [PENDING]`
- `3.6 Design implications [PENDING]`
- `6 Nomenclature [PENDING]`
- abstract/keywords `[PENDING]`

If this is a working draft, that is fine, but the draft should make clear what is final and what is placeholder.

Consider adding a short “Draft status” box at the top:

> This is an internal draft. Sections 3.4–3.6 are partially populated with figures but await Phase 1–3 interpretation. Nomenclature and references are incomplete. Numbers cited by NR-row IDs are traceable to the signed register.

Then, before a final version, those sections must be completed or removed.

---

### D. Add a clear definition of “winner”
The word “winner” is used strongly, but the search appears limited:

- 930 designs only,
- stopped early,
- described as “a screen, not a survey”,
- model has missing blade integrity checks,
- lifter modulation is assumed.

So in the main text, consider using more calibrated language:

- “best feasible candidate”
- “campaign winner under the modeled objective and gates”
- “leading design from this search”

You can still call it “the winner” internally, but qualify it:

> The campaign winner is the best feasible design found in this particular search under the current model, gates, and evaluation window. It is not claimed to be a global optimum.

That protects the scientific credibility of the report.

---

## 2. Section-by-section improvements

## Front matter / title / version history

### Current issues
- “Working title.”
- Long changelog in the front matter.
- “Lead pass by @hermes” etc.
- “Status DRAFT. Numbers come only from signed register rows...”

### Suggested fix
Create a clean title page:

> **A Search Over the Design Space of a Rotary Kite Turbine with Tensile Rotary Power Transmission**  
> Internal engineering report — Draft v0.10  
> Date: 2026-10-11  
> Status: DRAFT  
> Data commit: `dd3cc6a`  
> Launch commit: `a76c5e9`

Then move the full changelog to an appendix or separate document-control page.

A more specific title would help. The current title is decent but a bit generic. Alternatives:

- **Design-space search for a ground-generation rotary kite turbine using tensile rotary power transmission**
- **Simulation-based optimization of a rigid-wing rotary kite turbine with TRPT**
- **A 5 kW-class rotary kite turbine design search: model, campaign results, and failure ledger**

---

## Abstract and keywords

### Current issue
Missing.

### Suggested keywords
If you need them later, consider:

- airborne wind energy
- kite turbine
- ground-generation AWES
- tensile rotary power transmission
- differential evolution
- multibody simulation
- factor of safety
- design-space exploration
- rigid-wing kite
- airborne rotor

---

## 1 Introduction

### Strengths
The introduction correctly identifies the main families:

- fly-gen vs ground-gen,
- soft wing vs rigid wing,
- pumping/yo-yo vs rotary.

It also motivates the TRPT idea clearly.

### Issues to fix

#### 1. Define acronyms on first use
You use:

- AWES,
- TRPT,
- ODE later,
- DE later,
- FoS later,
- PTO in figure notes.

Define them the first time they appear.

Example:

> Airborne wind energy systems (AWES) are machines that harvest wind above conventional tower height.

#### 2. Make the literature paragraph less list-like
Current paragraph is a string of names:

> Loyd showed... Cherubini mapped... Diehl set... Trevisi built... Van der Burg found... Pereira ranked... Flather recorded... Tulloch modelled... Benhaïem and Schmehl analysed... Ranneberg gave...

This reads like a citation dump. Better structure:

1. theoretical ceiling and mode equivalence,
2. taxonomy/classification,
3. wing design uncertainty,
4. rotary/rotating-reel physics,
5. prior TRPT/Daisy modeling,
6. gap this report addresses.

Example rewrite:

> The theoretical power potential of crosswind AWES has been studied since early work on pumping and traction modes [Loyd]. Subsequent classification studies established the main architectural axes, including fly-generation versus ground-generation and soft-wing versus rigid-wing systems [Cherubini; Diehl]. Despite this progress, no dominant wing or generation architecture has emerged [Van der Burg; Van de Kaa and Kamp]. For ground-generation rotary systems, the relevant physics derives from rope-drive and rotating-reel mechanisms [Flather; Benhaïem and Schmehl], with prior TRPT modeling demonstrated in the Daisy system [Tulloch]. This report extends that line of work by searching a broader geometric design space for a rigid-wing rotary kite turbine using a tensile rotary power transmission.

#### 3. State the research question explicitly
Add one or two sentences like:

> The objective of this report is to identify feasible geometric configurations for a 5 kW-class ground-generation rotary kite turbine under a fixed generator load law and safety gates.

And maybe:

> The search asks whether a compact TRPT-based machine can simultaneously satisfy power, mass, structural, clearance, and twist constraints within the current simulation fidelity.

#### 4. Clarify “kite turbine” early
You say:

> The machine in this report is a kite turbine.

That is fine, but immediately define it operationally:

> In this report, a kite turbine is a ground-generation AWES machine in which airborne rigid blades rotate about a tensile rotary shaft, transmitting torque to a ground-based generator through tensioned lines.

---

## 2 Methods

This section contains the most important technical content, but it is currently interrupted by internal notes and figure placeholders.

### 2.1 The machine and its terms

#### Issues
- `[Term-set diagram requested...]` in body.
- Terms like “ring”, “line”, “rotor”, “spacer”, “bank”, “blade scale” need tighter definitions.
- “The polygon count equals the blade count.” This may be true for active rotors, but you later mention inactive rotor slots. Clarify.

#### Suggested rewrite style

> A **line** is a tension-only member. It transmits axial force but not compression or bending in the ideal model.  
> A **ring** is a closed polygonal structure composed of nodes and tubular beam segments. Rings may carry blades, in which case they act as rotors, or they may be bladeless spacers that maintain radial separation between TRPT lines.  
> The **polygon count** is the number of line attachments around a ring. For an active rotor, this equals the blade count.

Move figure placeholders to a “Figures” subsection or appendix.

---

### 2.2 The genome

#### Issues
- `[Genome visual requested...]` in body.
- “The winner genome names its genes in the decode fields (NR-011).” This is cryptic.

#### Suggested improvement
Add a small table:

| Gene | Meaning | Units / type | Example in winner |
|---|---:|---|---:|
| ring geometry | number/spacing of rings | count / length | 6 rings |
| polygon count | lines per ring | integer | 3 |
| rotor count | active rotors | integer | 1 |
| bank angle | blade angle relative to ring plane | deg | 7.088 at ring 6 |
| blade scale | blade size scaling factor | dimensionless | 0.82 active, 0.20 inactive slot |

Then explain inactive slots:

> The genome contains gene slots for multiple rotors. When the rotor count is one, only the first rotor slot is decoded; remaining blade-scale and bank slots are present in the vector but do not instantiate physical blades.

That would make “0.20 on a rotor that does not exist” much clearer.

---

### 2.3 The evaluator

This subsection is technically dense and contains several internal notes. It needs to be split into clearer subparts:

1. operating point,
2. load law,
3. dynamics integration,
4. determinism,
5. failure/clamping behavior.

#### Major clarity issues

##### 1. “FoS gate of 2.5 on 2.5”
This phrase is confusing. Probably you mean:

> minimum factor-of-safety gate = 2.5

or maybe:

> FoS gate value 2.5 applied to a reference load case of 2.5?

Clarify. If it is simply the minimum allowed FoS, write:

> Designs must satisfy a minimum structural factor of safety (FoS) of 2.5.

##### 2. Units for `k`
You state:

> τ = k·ω²  
> P = k·ω³

But you do not give units for `k`. Add them.

If torque is in N·m and angular speed in rad/s, then:

- `k` has units N·m/(rad/s)².
- Power law constant for `P = k ω³` would have units W/(rad/s)³ if using the same numerical `k`, but only if consistent with torque relation and assumptions.

Better to state explicitly:

> The load-law constant is fixed at k = 2.24 N·m/(rad/s)² for this campaign (NR-015).

If that is not the exact unit, correct it.

##### 3. “Honest window”
This term appears often but is not formally defined early enough.

Define it:

> The **honest window** is the measurement interval used to score a design. It begins after startup and relax transients have decayed, so that recorded performance reflects sustained operation rather than initialization artifacts.

Then state values:

- relax time: 10 s,
- honest window: 40 s.

##### 4. “The run is deterministic by construction”
This is true for fixed seed and fixed code, but you also have stochastic DE islands. Clarify:

> For a given island seed, code version, configuration, and random number stream, the campaign is reproducible. The search itself uses differential evolution with one fixed seed per island.

That avoids implying the whole optimization is deterministic in the mathematical sense.

##### 5. “The evaluator derives the step per machine from the shortest shaft sub-segment.”
This is important but underexplained. Add at least:

- why the shortest segment controls stability,
- whether this is a CFL-like condition,
- what happens if step size becomes too large,
- maybe the formula or reference to code.

Even a short note helps:

> The integration step is limited by the fastest dynamic mode associated with the shortest shaft sub-segment, ensuring that tension-wave propagation and local structural dynamics remain resolved.

If you can include the actual rule, do so in an appendix.

##### 6. “NaN and Inf clamps guard the state.”
Clarify what this means:

- Are non-finite values replaced?
- Does a broken line end the run?
- Is this a safety clamp or a failure condition?

Suggested wording:

> Non-finite state values (NaN/Inf) are treated as invalid. A broken line terminates the simulation and marks the design as failed.

---

### 2.4 The campaign

#### Issues
- Status definitions are pending.
- “930 is the scale for this campaign” context note is internal.
- Island budget explanation is thin.

#### Suggested table

| Status | Count in campaign | Meaning |
|---|---:|---|
| `ok` | 508 | Passed all gates |
| `reject` | 301 | Failed at least one primary gate |
| `clearance_reject` | 110 | Failed clearance gate |
| `reject_twist` | 11 | Failed twist gate |

Then define each gate:

- power floor,
- minimum FoS,
- clearance,
- twist limit,
- rope-break condition,
- mass objective if relevant.

Also clarify the evaluation budget:

> Three islands were run in parallel. Each island evaluated 310 designs, for a total of 930 evaluations (NR-001). Each island used its own fixed random seed.

If each island ran 30 generations plus initial/seed evaluations, state that explicitly.

---

### 2.5 Fidelity paths

This is an important section, but it currently mixes code names and high-level method.

#### Suggested structure

| Path | Code name | Starting state | Use case | Known limitation |
|---|---:|---|---|---|
| ODE path | `:cold` | Full dynamic startup / settle | High-fidelity scoring | Slower |
| Rapid path | `:warm` | Static pre-solve with injected velocities | Fast screening | Currently trips rope-break gate for winners |

Then state clearly:

> The campaign results reported here use the ODE/cold path. The rapid/warm path is not currently valid for final acceptance because it rejects recorded winners at the rope-break gate due to gate placement during relax.

That is a critical statement. Without it, a reader may wonder whether the campaign itself was scored on a faulty path.

---

### 2.6 Reproducibility

This section is strong but can be improved.

#### Add:
- repository URL or identifier,
- exact branch names,
- commit hashes (you have them),
- script paths (you have some),
- random seed values,
- Julia / dependency versions if available,
- machine precision / platform if relevant,
- how to rerun the campaign.

Example:

> The dataset is stored at data commit `dd3cc6a` on branch `bankderate2-results`. The campaign launch configuration is pinned at commit `a76c5e9`. The Phase 0 audit is available at `master` commit `31ca00d`. Fidelity probes are located in `scripts/probe_rapid_vs_ode_winners.jl` and `scripts/probe_warm_reject_cause.jl`.

If possible, add:

> To reproduce the winner operating point, run `<script>` with seed `<value>` and configuration `<file>`.

---

## 3 Results

The results section has good data, but it needs better organization and fewer internal placeholders.

### 3.1 The search at scale

This is fine, but add a table:

| Metric | Value | Source |
|---|---:|---|
| Total designs evaluated | 930 | NR-001 |
| `ok` | 508 | NR-002 |
| `reject` | 301 | NR-002 |
| `clearance_reject` | 110 | NR-002 |
| `reject_twist` | 11 | NR-002 |
| Seed mass / score | 36.109 kg | NR-006 |

Then state the objective explicitly:

> The campaign objective was to minimize airborne mass subject to a power floor and structural/clearance/twist gates.

If that is not exactly right, correct it.

---

### 3.2 Convergence

#### Major issue: apparent mass inconsistency
You write:

> Island 3 reaches 27.364 kilograms at generation 26 (NR-005).

Later:

> Its airborne mass reads 25.698 kilograms (NR-018).

If the objective is mass minimization, this needs explanation. Possible explanations:

- `27.364 kg` is a different metric from “airborne mass”,
- `27.364 kg` is the best island score before some final decode/fold change,
- `25.698 kg` includes/excludes lifter differently,
- one value is pre-fold and one is post-fold,
- one is a constrained score and one is physical mass.

You must reconcile this. Add a note like:

> The convergence metric in NR-005 is the campaign objective score, which differs from the final physical airborne mass reported in NR-018 because it includes/excludes `<component>` or reflects `<model era>`.

If they should be the same, one of them is wrong.

#### Suggested table

| Island | Best generation | Best metric | Metric type | Source |
|---:|---:|---:|---|---|
| 1 | 30 | 30.578 kg | ? | NR-003 |
| 2 | 30 | 30.637 kg | ? | NR-004 |
| 3 | 26 | 27.364 kg | ? | NR-005 |

Then explain what “kg” means in each row.

---

### 3.3 The winner

This is the core result, but it currently mixes:

- performance,
- lifter architecture,
- genome decode,
- structural margins,
- model-era caveats.

Split it into subsections:

#### 3.3.1 Winner summary
Table:

| Quantity | Value | Units | Source |
|---|---:|---|---|
| Mean power over honest window | 5.309 | kW | NR-008 |
| End-of-window power | 5.314 | kW | NR-008 |
| Minimum FoS | 14.972 | – | NR-009 |
| Airborne mass | 25.698 | kg | NR-018 |
| Window power swing | 0.029 | kW | NR-014 |
| Settle angular speed | 10.170 | rad/s | NR-016 |

Then one paragraph interpreting:

> The winner remains within the power band and retains large structural margin under the modeled load case.

#### 3.3.2 Genome decode
Table:

| Gene / feature | Value | Note |
|---|---:|---|
| Lines per ring | 3 | polygon count |
| Rings | 6 | includes ground and hub? clarify |
| Active rotors | 1 | rotor count |
| Hub radius | 4.580 m | NR-011 |
| Ground radius | 0.804 m | NR-011 |
| Bank angle, ring 6 | 7.088° | NR-017 |
| Inactive bank slot | 22° | not decoded because rotor count = 1 |
| Active blade scale | 0.82 | active rotor |
| Inactive blade scale | 0.20 | inactive genome slot |

This will make the “rotor that does not exist” sentence unnecessary.

#### 3.3.3 Lifter and lift-line sizing
This is important but currently has a possible arithmetic/definition issue.

You write:

> The vertical load is 1.5 × 20.70 × 9.81 = 304.6 N.  
> The line tension is that load over sin 70°: 324.1 N.  
> The same tension over the full airborne mass of 25.70 kg gives a margin of 1.21.

If you use the **line tension** divided by total weight:

> 324.1 / (25.70 × 9.81) ≈ 1.29

not 1.21.

If you use the **vertical component** of the line force, which is the original vertical load:

> 304.6 / (25.70 × 9.81) ≈ 1.21

So the margin of 1.21 appears to be based on the vertical load, not the full line tension.

Clarify which definition you mean. For example:

> The vertical lift margin is the ratio of the vertical component of the lift-line force to the total airborne weight:  
> `margin = 304.6 N / (25.70 kg × 9.81 m/s²) = 1.21`.

If instead you intend to use line tension, recalculate or explain the different metric.

Also clarify:

- what is included in “full airborne mass” (25.70 kg),
- whether the lifter mass is included,
- why sizing used 20.70 kg but total mass is 25.70 kg,
- whether the 1.5 margin requirement applies to total mass or only non-lifter mass.

This is a key safety-related statement, so it should be unambiguous.

#### 3.3.4 Lifter assumption
The sentence:

> The report states the presumption as one (2026-08-05).

is awkward. Replace with:

> This is stated explicitly as Assumption A1: the lifter stack can modulate its lift to meet the required vertical force across the operating wind-speed range.

Then add a limitation:

> Because a fixed kite pull scales approximately with wind speed squared, achieving this modulation without multiple discrete kites or active control is a nontrivial design problem outside the scope of this report.

That is much clearer.

---

## 3.4 The levers

This section is currently pending and contains two strong figures:

- ring utilization / beam-column interaction,
- twist limit / torque capacity.

These figures are valuable, but “levers” usually means sensitivity to design variables, not just margins at one operating point.

### Suggested content for 3.4

You should answer questions like:

- Which design variables most affect power?
- Which variables most affect mass?
- Which variables drive FoS?
- Which variables drive twist utilization?
- Are there variables that are near their bounds?
- Is the winner close to any gate?
- Could mass be reduced if structural margin is traded?
- Does polygon count 3 appear optimal, or just feasible?
- Does blade scale 0.82 dominate performance?
- Is bank angle near a preferred range?

Possible substructure:

1. Structural lever: ring utilization and FoS margins  
2. Twist lever: transmitted twist vs δcrit  
3. Aerodynamic/geometric levers: polygon count, rotor count, bank, blade scale  
4. Line-length lever: 18.8 m vs 21.2 m vs 25.0 m  
5. Load-law sensitivity: `k` value and power floor

If Phases 1–3 have not produced sensitivity results yet, say so explicitly rather than leaving the section empty.

---

## Figures

Your figures appear technically strong, but the captions are overloaded with internal provenance.

### General figure improvements

#### 1. Separate scientific caption from provenance
Current captions include:

- data commit,
- extract name,
- capture pair,
- script commit,
- authority commit,
- row IDs,
- internal roster numbers.

That is excellent for auditability but too much for a main-text figure caption.

Suggested split:

**Main caption:**

> Figure 3. Beam-column utilization of checked rings at the final operating point of the island-3 winner. Bars show axial and bending shares of the worst-utilization beam in each ring. The dashed line indicates the failure boundary at unit utilization. The ground ring is excluded because it is ground-supported.

**Provenance line or appendix:**

> Data commit `dd3cc6a`; script `eacf073`; rows NR-021; capture pair `pair-extract-2026-10-08-winner-ops`.

That keeps the figure readable while preserving traceability.

#### 2. Make figures self-contained
A reader should understand each figure without reading internal notes.

For the ring-utilization figure, add:

- what “utilisation” means,
- why FoS is reciprocal of utilization,
- why R1 is not checked,
- why R5 FoS is extremely large,
- whether torsion is included or tracked separately.

For the twist figure, add:

- what `Δα` is,
- what `δcrit` is,
- what “no limit” means,
- why torque and capacity are paired at the same state,
- what the realizability floor 72.25° means relative to δcrit values.

The note about the 2026-08-13 winner running to 22,425° is interesting but may distract in the main figure. Move it to a failure-ledger appendix or validation note.

#### 3. Consider scaling for extreme FoS values
A FoS of 326,974 on a linear axis makes other values hard to compare. Options:

- use a log scale for FoS readout,
- cap the visual bar and label the true value,
- add a note: “R5 utilization is below display resolution; FoS = 326,974.”

#### 4. Consistent figure numbering
You currently have internal “roster row” references. Use normal report numbering:

- Figure 1: system anatomy
- Figure 2: genome decode strip
- Figure 3: design family grid
- Figure 4: convergence history
- Figure 5: winner anatomy
- Figure 6: ring utilization
- Figure 7: twist/torque margins
- Figure 8: machine evolution strip

Then provide a mapping appendix if you need to preserve internal figure-map rows.

---

## 3.5 The evolution story

This section is pending, but the machine-evolution-strip figure is already strong.

### Suggested narrative
Explain what the search learned over generations:

- Did ring count decrease or stabilize?
- Did polygon count move from many sides to few?
- Did blade scale grow?
- Did bank angle settle into a range?
- Did mass drop while power stayed above floor?
- Were early failures dominated by clearance, twist, or structural gates?
- Did the winner emerge from exploration or local refinement?

Even a short paragraph would help:

> Island 3 initially explored higher ring counts and larger blade scales. By generation 10, feasible designs clustered around three-line geometries. Later generations refined bank angle and blade scale while maintaining power above the floor. The final winner retained large structural margin, suggesting that the campaign had not fully exhausted the mass-reduction direction within this search budget.

If you do not have that analysis yet, state:

> The evolution strip shows geometric progression only; quantitative lever analysis is deferred to Section 3.4 once Phase 1–2 landscape data are available.

---

## 3.6 Design implications

This section should convert results into engineering guidance.

### Possible implications to discuss
Depending on your data, this section could cover:

1. **Power floor vs mass tradeoff**  
   If the winner is near the power floor, the search may be mass-limited rather than performance-limited.

2. **Structural margin is large**  
   FoS ~15 suggests possible mass reduction if blade integrity and other gates were included.

3. **Twist margins are adequate**  
   But clarify whether twist becomes critical for larger radii or longer tethers.

4. **Polygon count 3 may be sufficient**  
   If lower polygon counts reduce line/tower/bridle complexity while retaining performance, that is important.

5. **Line length 18.8 m passes after fold correction**  
   This supports the selected length but should be framed carefully because pre-fold rows failed.

6. **Lifter assumption dominates feasibility**  
   If lifter modulation is not solved, the airborne machine result may not translate to a deployable system.

7. **Blade integrity missing**  
   The current mass and FoS results are optimistic for structural feasibility until blade root checks are added.

8. **Search breadth limited**  
   930 evaluations is useful as a screen, but not proof of global optimality.

---

## 4 Discussion

The discussion currently has two strong parts:

- evaluation fidelity,
- failure ledger.

Both need tightening.

### 4.1 Evaluation fidelity

#### Key issue to make explicit
You state:

> Every healthy winner reads reject on the default path. Pass the cold flag, and every recorded winner field reproduces (NR-012).

This is a major finding. Make it more prominent.

Suggested wording:

> The default rapid/warm path currently rejects all three recorded winners at the rope-break gate. This rejection is caused by gate placement during the relax transient, not by a structural failure of the machines. The campaign results reported in this paper use the ODE/cold path, on which all recorded winner fields reproduce at stored precision (NR-012). Until the rapid-path gate is corrected, the warm path should not be used for final acceptance screening.

Then summarize the prior rulings:

> Two earlier rulings established that healthy machines should not fail because of settle transients or measurement-window artifacts. The current discrepancy is the same class of issue and requires the same correction in the evaluator.

That is clearer and more formal.

---

### 4.2 The failure ledger

This is one of the report’s best features, but it reads like a narrative log. Convert it into a structured table plus short interpretation.

#### Suggested table

| ID / Date | Event | Class | Affected data | Root cause | Lesson | Status |
|---|---|---|---|---|---|---|
| 2026-08-14 | Inverted-taper genome diverged while telemetry appeared normal | Model/geometry failure | Specific campaign data? | Builder accepted invalid geometry? | Decoder must reject unbuildable genomes at gate time | Resolved / lesson applied |
| 2026-08-22 | Blade-mass-law correction | Void | Prior campaign winners | Incorrect blade mass law | Correct physical laws before final scoring | Data voided, record kept |
| 2026-08-13 | k-alignment fault: 5 kW designs scored at 50 kW default gain | Void / near-miss? | Specific run | Mismatched generator gain constant | One constant, one source file | Caught by acceptance test |
| 2026-08-24 | Stale gain in winner re-gate | Near-miss / void? | Re-gate result | Superseded window/gain value | Pre-push review; pin constants | Re-gated correctly |
| 2026-08-22 | FoS=Inf exploit fix missing from some scoring paths | Near-miss | Campaign path unguarded | Incomplete guard propagation | Gates must pin measured numbers and fail suite on drift | No corrupted survivor found |

Then keep a short narrative for the most important lessons.

#### Specific wording fixes
- “ground instruments still read normal power” is odd. If this is simulation, say:
  > simulated telemetry still reported plausible power
- if it is hardware, define “ground instruments”.
- “The data from before it then counts no more.” Good, but maybe too blunt. Use:
  > Data generated under the superseded model are void for design conclusions, though they remain useful as historical record.

---

## 4.3 Model boundaries

This section should be expanded. You currently state two major boundaries:

- blade integrity not checked,
- tether-to-blade bridling drag not included.

Add more.

### Suggested limitations list

1. **Blade structural integrity is not gated**  
   Blade root FoS is infinite in the model. Therefore mass and feasibility may be optimistic.

2. **Bridling drag is omitted**  
   Real flown blades have tether-to-blade bridling that improves load resistance but adds drag.

3. **Lifter modulation is assumed**  
   The report applies required lift but does not design or validate the lifter across wind speeds.

4. **Launch and recovery are not modeled**  
   The lifter launches first, but the full launch sequence is outside scope.

5. **Aerodynamic fidelity may be limited**  
   State what aerodynamic model is used: panel? lifting line? blade element? CFD? Empirical? What stall/spin behavior is captured?

6. **No fatigue or cyclic loading assessment**  
   FoS is evaluated at an operating point, not over a load-life cycle.

7. **No control-system validation**  
   The machine is assumed to operate under the modeled load law; active control is not part of the search.

8. **Wind environment simplified**  
   State whether wind is steady, turbulent, sheared, gusty, or idealized.

9. **Search space limited**  
   930 evaluations is a screen, not exhaustive optimization.

10. **Rapid-path evaluator bug affects screening validity**  
   Until fixed, warm-path results cannot be trusted for rope-break acceptance.

This will make the “valid science” case much stronger.

---

## 5 Conclusion

The conclusion is too short and introduces new terms late:

> The Daisy anchor keeps the model honest to a machine I flew and measured.

If “Daisy” has not been defined in the main text, define it first or move this sentence earlier.

### Suggested conclusion structure

1. **What was done**
   > A 930-design differential-evolution search was run over a rigid-wing rotary kite turbine design space using a TRPT power transmission and a full ODE evaluator over an honest window.

2. **Main result**
   > The best feasible candidate produced 5.309 kW mean power with a minimum structural FoS of 14.972 under the modeled assumptions.

3. **Interpretation**
   > The result demonstrates that compact TRPT geometries can satisfy the selected power, clearance, twist, and structural gates in simulation. Large residual margins suggest room for mass reduction or higher-fidelity structural gating.

4. **Limitations**
   > The conclusion is conditional on the current model: blade integrity is not gated, lifter modulation is assumed, and the rapid evaluator path requires correction before use for final screening.

5. **Next steps**
   > The next phases should add blade structural checks, validate lifter modulation, complete sensitivity analysis, and extend the search if the current screen indicates a promising region.

Avoid first person unless your house style allows it. “I flew and measured” may be too informal for an engineering report. Use:

> The Daisy anchor provides measured flight reference data used to constrain model behavior.

---

## 6 Nomenclature

This should not remain pending if the report uses many specialized terms.

### Suggested glossary entries

| Term | Definition |
|---|---|
| AWES | Airborne wind energy system |
| fly-gen | Architecture where the generator is airborne and power is transmitted down a conducting tether |
| ground-gen | Architecture where the generator is on the ground and the tether transmits mechanical force |
| pumping / yo-yo | Intermittent tension cycle with reel-in/reel-out phases |
| rotary AWES | Continuous rotation of tethers/rotor without a separate reel-in phase |
| TRPT | Tensile rotary power transmission: torque transmitted through tensioned lines between rings |
| ring | Polygonal structural loop in the TRPT |
| polygon count | Number of line attachments around a ring |
| rotor | Ring carrying active blades |
| spacer ring | Bladeless ring used to maintain separation/tension geometry |
| bank angle | Blade angle relative to ring plane about chord axis |
| blade scale | Dimensionless scaling factor for blade size |
| genome | Design vector passed to decoder/builder |
| honest window | Measurement interval excluding startup/relax transients |
| relax run | Initial transient phase before scoring window |
| FoS | Factor of safety, ratio of capacity to demand |
| DE | Differential evolution optimizer |
| island | Independent DE population |
| ODE path / cold | Full dynamic evaluation path |
| rapid path / warm | Static pre-solve accelerated evaluation path |

---

## 7 References

Currently:

> Seeded in references.bib. Fifteen of eighteen sources verified. Three source calls pending...

For a final report, this is not enough.

### Needed:
- complete reference list,
- in-text citations for every named claim,
- consistent citation style,
- no unresolved “pending source” notes.

Every sentence like:

> Pereira ranked the design factors and found that many small units beat few large ones.

needs a proper citation.

Also, if you cite internal register rows, decide whether those are:

- references,
- data sources,
- appendix entries,
- or a separate “Register index”.

I would not mix NR-row IDs with literature references unless clearly separated.

---

## 8 Data availability and reproducibility

This section is already good. Strengthen it by adding:

- repository URL,
- branch names,
- commit hashes,
- script paths,
- seed values,
- exact configuration file names,
- dependency versions,
- figure-generation commands,
- register-row lookup method.

Example:

> All datasets are stored in the project repository at `<URL>` on branch `bankderate2-results`, data commit `dd3cc6a`. The campaign launch commit is `a76c5e9`. Figure scripts and extraction notebooks are pinned in the same repository. Register rows cited as NR-XXX are listed in Appendix A with values, units, source commits, and sign-off dates.

---

## 9 Open requests / build record

These should not be in the report body unless this is explicitly an internal working document.

### Move to:
- project issue tracker,
- appendix “Open items”,
- separate status page.

If kept in the draft, put them under a clearly labeled non-report section:

> **Non-report status block — for internal tracking only**

But for any circulated version, remove or move them.

---

## 10 Specific numerical and wording issues to fix

Here are concrete items I would flag before the next pass.

| Location / issue | Problem | Recommended fix |
|---|---|---|
| “FoS gate of 2.5 on 2.5” | Unclear phrase | Write “minimum FoS gate = 2.5” or explain the second 2.5 |
| `k = 2.24` | Units missing | Add units, e.g. N·m/(rad/s)² if correct |
| Island 3 best mass 27.364 kg vs winner airborne mass 25.698 kg | Possible inconsistency | Clarify metric difference or correct row |
| Lift margin 1.21 | Appears to use vertical load, not line tension | Define margin formula explicitly |
| “same tension over full airborne mass gives margin 1.21” | Arithmetic suggests 1.29 if using tension | Use vertical component or recalculate |
| Winner FoS 14.972 vs figure hub FoS 15.033 | Different values for similar quantity | Explain whether one is global minimum and the other ring-specific |
| “blade scales read 0.82 on active rotor and 0.20 on a rotor that does not exist” | Confusing | Use genome-slot table; explain inactive slots |
| “The report states the presumption as one (2026-08-05)” | Awkward | “This is stated explicitly as Assumption A1.” |
| “Every healthy winner reads reject on the default path” | Critical but underexplained | State that campaign used cold path and warm path is invalid until fixed |
| “Daisy anchor keeps the model honest to a machine I flew and measured” | First person / late introduction | Define Daisy earlier; use formal tone |
| Figure captions with commit hashes | Too much provenance in main caption | Move provenance to appendix or shortened line |
| `figure-map row` references | Internal jargon | Replace with standard figure numbers or move mapping to appendix |

---

## 11 Suggested revised report structure

A cleaner final structure would be:

1. **Title page**
2. **Abstract and keywords**
3. **1 Introduction**
   - 1.1 Background
   - 1.2 Machine class
   - 1.3 Objective and scope
   - 1.4 Report organization
4. **2 Machine definition and terminology**
   - 2.1 TRPT architecture
   - 2.2 Genome and decoder
   - 2.3 Lifter assumption
5. **3 Methods**
   - 3.1 Operating point and load law
   - 3.2 Multibody evaluator
   - 3.3 Integration and stability
   - 3.4 Gates and status definitions
   - 3.5 Search campaign
   - 3.6 Fidelity paths
   - 3.7 Reproducibility
6. **4 Results**
   - 4.1 Campaign overview
   - 4.2 Convergence
   - 4.3 Winner summary
   - 4.4 Structural margins
   - 4.5 Twist margins
   - 4.6 Machine evolution
7. **5 Discussion**
   - 5.1 Evaluation fidelity
   - 5.2 Failure ledger and lessons
   - 5.3 Model boundaries
   - 5.4 Design implications
8. **6 Conclusion and next steps**
9. **References**
10. **Appendices**
   - A: Nomenclature
   - B: Register row index
   - C: Data availability and reproducibility
   - D: Figure provenance
   - E: Failure ledger timeline
   - F: Model era / voided data log
   - G: Open items (if internal)

This separates the scientific narrative from audit metadata.

---

## 12 Suggested new tables to add

These tables would improve clarity significantly.

### Table 1: Campaign configuration

| Parameter | Value | Source |
|---|---:|---|
| Optimizer | Differential evolution | – |
| Islands | 3 | NR-001? |
| Designs per island | 310 | NR-001? |
| Total evaluations | 930 | NR-001 |
| Objective | minimize mass / score? | clarify |
| Power floor | ? kW | add row |
| Minimum FoS | 2.5 | clarify |
| Honest window | 40 s | NR-015? |
| Relax time | 10 s | NR-015? |
| Load constant k | 2.24 | NR-015 |
| Line length | 18.8 m | NR-015 |

### Table 2: Winner operating point

| Quantity | Value | Units | Source |
|---|---:|---|---|
| Mean power | 5.309 | kW | NR-008 |
| End power | 5.314 | kW | NR-008 |
| Minimum FoS | 14.972 | – | NR-009 |
| Airborne mass | 25.698 | kg | NR-018 |
| Hub radius | 4.580 | m | NR-011 |
| Ground radius | 0.804 | m | NR-011 |
| Ring count | 6 | – | NR-011 |
| Polygon count | 3 | – | NR-011 |
| Active rotor count | 1 | – | NR-011 |
| Bank angle at ring 6 | 7.088 | deg | NR-017 |
| Lift-line elevation | 70 | deg | NR-026 |
| Lift-line tension | 324.1 | N | NR-010 |

### Table 3: Gate summary

| Gate | Threshold | Winner value | Margin / status |
|---|---:|---:|---|
| Power floor | ? kW | 5.309 kW mean | pass |
| Minimum FoS | 2.5 | 14.972 | pass |
| Clearance | ? | ? | pass |
| Twist | δcrit limit | max utilization? | pass |
| Rope break | no break in window | none on cold path | pass |

You may not have all values yet, but this is the kind of table a reader needs.

---

## 13 Style and readability improvements

### Use consistent terminology
Pick one term per concept and use it consistently:

- “kite turbine” vs “machine” vs “rig” vs “system”
- “winner” vs “best design” vs “candidate”
- “honest window” vs “measurement window” vs “scoring window”
- “rapid path” vs `:warm`
- “ODE path” vs `:cold`

Code names are fine in reproducibility sections, but define them first.

### Use active voice where helpful
Current text is often terse and passive. Some active voice improves clarity:

Instead of:

> The campaign evaluates 930 designs in total (NR-001).

Use:

> We evaluated 930 designs in the campaign (NR-001).

If first person plural is allowed. If not:

> The campaign evaluated 930 designs (NR-001).

That is fine, but be consistent.

### Avoid over-compressed sentences
Some sentences are very short and choppy:

> A line is a tension member, like a tether or a bridle. It carries a load only in tension. A pull at one end passes along the line to the other end. It never pushes.

This is clear but slightly staccato. You can combine:

> A line is a tension-only member, such as a tether or bridle; it transmits axial pull from one end to the other and does not carry compression in the ideal model.

### Be explicit about units
Every number should have units either in text or table:

- kW,
- kg,
- m,
- s,
- deg,
- rad/s,
- N,
- N·m,
- dimensionless.

Avoid bare numbers except for counts.

---

## 14 Suggested “claim calibration” language

Because the model has missing blade checks and assumed lifter behavior, use careful claims.

### Stronger but safe wording
- “The campaign identified a feasible candidate design under the modeled assumptions.”
- “The winner satisfies the selected power, clearance, twist, and structural gates in simulation.”
- “The result demonstrates that the TRPT architecture can meet the target load case within the current model fidelity.”
- “Large structural margins suggest that the search has not yet fully exploited mass reduction under the current objective.”

### Avoid or qualify
- “The machine is viable” → “The candidate is viable under the modeled assumptions.”
- “The winner proves...” → “The winner suggests...”
- “The design is optimal” → “The design is the best found in this limited search.”
- “The system will fly” → “The simulation indicates stable operation over the honest window.”

---

## 15 A practical next-pass checklist

Before producing v0.11, I would do this:

1. **Remove all bracketed internal notes from the main body.**
2. **Move version history and build record to appendices.**
3. **Write a provisional abstract and keywords.**
4. **Add a “Scope and assumptions” subsection.**
5. **Define AWES, TRPT, FoS, DE, ODE, honest window, cold/warm paths.**
6. **Create tables for campaign config, winner metrics, genome decode, gates, and failure ledger.**
7. **Reconcile the mass values: 27.364 kg vs 25.698 kg.**
8. **Fix/clarify lift margin calculation and definition.**
9. **Clarify `k` units and FoS gate wording.**
10. **Explain why rapid path rejects winners and confirm campaign used cold path.**
11. **Convert failure ledger into a table.**
12. **Expand model boundaries to include blade, lifter, launch, fatigue, control, wind environment.**
13. **Rewrite conclusion with result + limitation + next steps.**
14. **Complete nomenclature or move to appendix with full glossary.**
15. **Finish references and in-text citations.**
16. **Shorten figure captions; move provenance to appendix.**
17. **Add a register-row index appendix so NR-IDs are interpretable.**
18. **Do a numerical audit: every number has source, units, and consistent value.**

---

## 16 My overall recommendation

The report currently has excellent engineering discipline but needs better reader-facing architecture. The best improvement is not more data; it is clearer separation of:

- **what was done**,
- **what the result means**,
- **what is proven vs assumed**,
- **what internal process notes are not part of the scientific argument**.

If you make the next draft answer these four questions cleanly, it will be much stronger:

1. **What machine did we search?**  
   A ground-generation rotary kite turbine with TRPT and rigid blades.

2. **What did the search find?**  
   A feasible 5.31 kW mean-power candidate with large structural margin under the modeled gates.

3. **How confident are we?**  
   Confidence is high for model-internal consistency, but limited by missing blade integrity checks, assumed lifter modulation, and evaluator path issues.

4. **What should happen next?**  
   Fix rapid-path gating, add blade structural checks, validate lifter modulation, and complete sensitivity/implication analysis.