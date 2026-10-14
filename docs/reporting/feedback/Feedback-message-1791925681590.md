The later sections feel less polished mainly because they are still **evidence containers** rather than **interpretive sections**. The front half is strong because it ties numbers to register rows. The back half needs to turn those numbers into claims, limits, and next actions.

A good fix is to give each later section one job:

- **3.x Results:** show what the search found and where the winner sits inside the gates.
- **Discussion:** separate instrument problems from model limitations.
- **Conclusion:** state the conditional result and the next work without overclaiming.
- **Nomenclature/References/Data availability:** make the report auditable and self-contained.

Below is a concrete improvement plan, with proposed rewrites for the weak spots.

---

## 1. Reorganize the Results so the figures have a home

Right now, section **3.4 “The levers”** is pending, but it contains two finished-looking plates:

- `ring-utilisation`
- `twist-limit`

Those figures are not really about “levers.” They are about **winner margins at the final operating point**. That mismatch makes the later results feel unfinished.

I would split the current 3.4 into two different sections.

### Proposed Results structure

```text
3 Results

3.1 The search at scale
    - 930 evaluations
    - status mix
    - island start point

3.2 Convergence
    - island bests
    - ok power range
    - objective vs physical mass

3.3 The winner
    - operating point table
    - gate table
    - lifter sizing
    - geometry decode

3.4 Winner margins: rings, segments, and twist
    - ring-utilisation figure
    - twist-limit figure
    - governing FoS, torque margin, twist limits

3.5 Design levers [PENDING or interim]
    - what the current record supports
    - what extracts are still needed

3.6 Evolution story
    - machine-evolution-strip figure
    - island 3 best-so-far objective milestones

3.7 Design implications
    - what to keep, change, and check next
```

This does three things:

1. It gives the two plates a proper section.
2. It keeps “levers” as a real design-space interpretation section.
3. It lets the evolution story use the strip figure without competing with pending analysis.

---

## 2. Rewrite or stub the pending sections deliberately

A `[PENDING]` section is okay in a draft, but it should not look accidental. Each pending section should say:

1. what it will contain,
2. what evidence is already available,
3. what exact extract or gate is missing.

For example, instead of:

```text
3.4 The levers [PENDING. Landscape Phases 1 to 2 supply this section.]
```

use something like:

```text
3.5 Design levers [PENDING Phase 1–2 extracts]

The full lever analysis awaits the Phase 1–2 landscape extracts. The current
record supports campaign-level statements only.

The status mix shows that clearance was a substantial named failure class:
110 of 930 designs were clearance_reject, compared with 11 twist rejects
(NR-002). The ok population spans 5.02–6.32 kW mean power (NR-007), so the
power floor is active but not uniquely binding across the feasible set.

The winner’s fitness includes 1.665 kg-equivalent of penalties:
over-power 0.493, utilisation 0.558, and twist 0.614 (NR-039). This indicates
that the final genome is not simply the lightest buildable machine; it is the
lowest-penalized feasible machine under the campaign objective.

Before making gene-level claims, the report needs extracts for:
- objective versus ring geometry,
- objective versus polygon count,
- objective versus rotor count,
- objective versus bank angle,
- objective versus blade scale,
- gate-failure counts by gene,
- penalty contributions across ok designs.
```

That turns a blank pending section into an honest interim result.

---

## 3. Add a “winner margins” section using the existing plates

You already have strong numbers for this. A polished 3.4 could read like this:

```text
3.4 Winner margins: rings, segments, and twist

At the final operating point, the structural margin is governed by the hub ring
R6. The window-minimum factor of safety is 14.972 (NR-009). At the final step,
R6 reads 15.033, while R2–R4 read 29.8–35.2 and R5 is effectively unloaded in
the checked beam (NR-021). The ground ring is excluded from the airborne ring
check because it rests on ground support.

For twist, all five segments remain inside their over-twist limits. S1–S4
transmit 33.6–33.9° against a 98.9° limit, and S5 transmits 22.8° against a
92.6° limit (NR-022). The smallest segment torque margin is at S1, 2.03, with
S5 at 2.69 (NR-040).

These plates show that the winner is not close to ring buckling, twist runaway,
or segment torque saturation at this operating point. The large margins are
conditional: they cover the checked TRPT rings and segments only, and they do
not yet include blade integrity or lifter loads across wind bands.
```

This is much stronger than leaving the figures under a pending “levers” heading.

---

## 4. Make the evolution story use the strip figure directly

Section **3.5 / 3.6** can be completed now from the register rows you already have.

A polished version could be:

```text
3.6 Evolution story

The machine-evolution-strip figure traces island 3’s best-so-far objective from
the common seed to the campaign winner. The recorded objective falls from
36.109 kg-equivalent at generation 0 to 27.364 kg-equivalent at generation 26
(NR-036, NR-005).

The improvement is front-loaded. The largest recorded drop is 3.816 kg-equivalent
between generations 0 and 6. Later generations improve more slowly, with the
final recorded step from generation 25 to generation 26 worth 0.951 kg-equivalent.

The winner’s physical airborne mass is 25.698 kg (NR-018). Its fitness of
27.364 kg-equivalent therefore includes 1.665 kg-equivalent of penalties
(NR-039). The final genome is not simply the lightest buildable machine; it is
the lowest-penalized feasible machine under the campaign objective.

The strip shows built geometry and search objective only. It does not print power
or airborne mass. The final panel matches the register winner: three lines, six
rings, hub radius 4.580 m, ground radius 0.804 m, blade scales 0.82 and 0.20
(NR-011). The unused second bank slot and inactive blade scale indicate that part
of the genome is redundant at one active rotor; this should be checked in the
decoder before the next campaign.
```

This gives the figure a narrative: **seed → early improvement → slower refinement → final feasible candidate**.

---

## 5. Turn “Design implications” into recommendations, not just observations

The current 3.6 is pending, but you already have enough to write a conditional implications section.

A strong version would be:

```text
3.7 Design implications

The current record supports four implications.

First, the searched TRPT family contains a compact feasible candidate under the
modeled objective and gates. The winner produces 5.309 kW mean power with an
airborne mass of 25.698 kg (NR-008, NR-018).

Second, the winner has large structural and twist margins at the final operating
point. The window-minimum FoS is 14.972 (NR-009), and the least segment torque
margin is 2.03 at S1 (NR-040). These margins suggest room for further mass
reduction, but only after blade integrity and lifter loads are gated.

Third, clearance should be treated as a first-class design constraint. Clearance
produced 110 named rejects in the campaign (NR-002). Future searches need an
explicit clearance map or penalty shaping so that the decoder does not spend
evaluations on geometries that cannot build cleanly.

Fourth, the genome contains inactive slots at one active rotor. The second bank
slot and inactive blade scale do not reach a built rotor (NR-011, NR-017). Making
these genes conditional, or removing them from the active search space, may improve
search efficiency without changing the physical problem.

Recommended next steps:
1. Fix the rapid-path rope-break gate before using :warm for screening (NR-013).
2. Add blade root factor-of-safety checks to the structural gate set.
3. Validate lifter modulation across wind bands rather than assuming it.
4. Run gust and turbulence sensitivity cases on the winner and nearby ok designs.
5. Extract lever statistics from telemetry: objective versus gene, gate failures
   by gene, and penalty contributions across ok designs.
6. Re-run a short campaign with conditional genes and a clearance-aware decoder.
```

That section becomes useful even before the full landscape analysis is complete.

---

## 6. Polish the Discussion by separating three kinds of limitation

Your Discussion is already good in spirit, but it can be cleaner if each subsection has one clear job.

### 4.1 Evaluation fidelity

Make the path distinction explicit and operational.

Current text is strong, but I would tighten it to:

```text
4.1 Evaluation fidelity

The ODE path, labeled :cold in code, is the reference path. It reproduces every
recorded winner field at the precision stored in the register (NR-012).

The rapid path, labeled :warm, currently rejects all three winners at the
rope-break gate (NR-013). The cause is evaluator gate placement, not the machine.
The rapid start injects ring velocities from a static pre-solve. The evaluator
then runs rope-break detection across the relax run as well as the measurement
window. The injected transient over-strain trips the gate immediately.

The 2026-09-16 ruling limits rope breaks to the measurement window, with break
detection off during relax. Until that fix lands, every warm-path result is an
instrument test, not a machine score. Any consumer that does not pass the cold
flag is measuring the evaluator, not the kite turbine.
```

Then add a small table:

| Path | Code label | Current status | Evidence | Action |
|---|---:|---|---|---|
| ODE path | `:cold` | reference; reproduces winners | NR-012 | use for scored results |
| Rapid path | `:warm` | rejects all three winners at rope-break gate | NR-013 | fix gate placement before screening |

That makes the operational consequence impossible to miss.

---

### 4.2 Failure ledger

This is one of the report’s best sections conceptually, but it reads a little like notes. Convert it into a table or consistent entries.

Suggested format:

| Failure class | What happened | Lesson | Status / evidence |
|---|---|---|---|
| Dead geometry genes | Decoder proposed genomes the builder could not make safely | Decoder must refuse unbuildable genomes at gate time | 2026-08-26, 2026-08-14 |
| Voided campaigns | Later physics or decode corrections invalidated earlier data | Void the data, keep the record | blade-mass-law correction, rotorcount data |
| k-alignment faults | Checks ran at the wrong generator gain | One constant, one source file | 2026-08-13, 2026-08-24 |
| Stale gate near-miss | FoS=Inf guard missing from some scoring paths | Gates must pin measured numbers so drift fails the suite | 2026-08-22 |

Also move bracketed notes out of the body. For example:

```text
[2.24 holds a register row (NR-015). The other values need rows first.]
```

should become either:

- a real register row, or
- an open-data-request item in the tracker.

If the historical k values are not signed rows, do not quote them as report numbers. Phrase them qualitatively until rows exist.

---

### 4.3 Model boundaries

This section should be a table. It is currently prose that deserves structure.

| Boundary | Current assumption | Consequence | Next check |
|---|---|---|---|
| Blade integrity | Blade root FoS is infinite; full blade model deferred | Rotor blades are not structurally gated | Add blade root gate, PRD 0006:147 |
| Bridling | Model assumes unbridled blades | Thrust, expansion, and drag are misrepresented | Add flown bridling model or test correction |
| Launch and recovery | Run starts aloft at operating point | Startup, hoisting, and recovery loads are absent | Simulate full launch/recovery sequence |
| Lifter modulation | Lift force is applied as required; modulation assumed | Wind-band coverage is not proven | Design/validate lifter stack across wind speeds |
| Wind | Steady sheared profile, fixed direction | No gust or turbulence sensitivity | Add gust/turbulence cases to winner and nearby ok designs |
| Ground ring | Excluded from airborne ring check | Ground-supported loads are not part of the ring FoS result | Include only if ground support becomes a design constraint |
| TRPT capacity | Capacity comes from tension-based limits; outer stiffening bridles outside model | Capacity may be conservative or nonconservative depending on unmodeled parts | Validate with tests or higher-fidelity model |

This makes the “valid-science case” much easier to scan.

---

## 7. Rewrite the Conclusion as a conditional decision statement

The current conclusion is close, but it can be sharper.

Suggested replacement:

```text
5 Conclusion

This report screened 930 rigid-wing, ground-generation rotary kite turbine
designs with a tensile rotary power transmission under one fixed power-law
generator load and a fixed set of gates. The campaign scored each design on the
ODE path over the measurement window.

The search found a feasible candidate in the searched space. Its mean power is
5.309 kW, its airborne mass is 25.698 kg, and its window-minimum factor of
safety is 14.972 (NR-008, NR-018, NR-009). All checked TRPT rings and twist
segments operate below their failure boundaries at the final operating point
(NR-021, NR-022), and the least segment torque margin is 2.03 at S1 (NR-040).

The result shows that a compact TRPT machine can satisfy the power, clearance,
twist, and structural gates in simulation under the modeled load and wind. It does
not show flight readiness, global optimality, or full structural safety. Blade
integrity is not yet gated. Lifter modulation remains an assumption. The rapid
path awaits its rope-break gate fix (NR-013).

The next work is to close the model gaps: add blade structural checks, validate
lifter modulation, complete launch and recovery analysis, and extend the wind
cases beyond steady sheared flow. The large structural margins suggest room for
mass reduction, but only after those checks are in place.
```

That conclusion is honest, decision-useful, and consistent with the register.

---

## 8. Add a real Nomenclature section

Section 6 is currently pending, but you can draft it now from terms already in use. This will improve the whole report because several terms are doing heavy work without definition.

A starter glossary:

| Term | Meaning in this report |
|---|---|
| AWES | Airborne wind energy system. |
| Fly-gen | Generator and turbine are airborne; electrical power is sent to ground through a conducting tether. |
| Ground-generation, ground-gen | Generator is on the ground; tether transmits force or torque. |
| Pumping / yo-yo | Intermittent tension cycle using reel-in and reel-out phases. |
| Rotary machine | Continuous rotation of a turning set of tethers or rings. |
| Kite turbine | AWES machine using multiple short rigid blades on one or more rings to form a wide-diameter rotor. |
| TRPT | Tensile rotary power transmission: a shaft made of tensioned lines and rings. |
| Line | Tension-only member, such as a tether or bridle. |
| Ring | Polygon of nodes and tubular beams; may carry blades or act as a spacer. |
| Node | Point where lines connect to the ring structure. |
| Tubular beam | Beam element forming part of a ring. |
| Polygon count | Number of lines in the ring polygon, `n_Lines`; also equals blade count for a rotor ring. |
| Rotor | Ring carrying blades that produce aerodynamic torque. |
| Active rotor | Rotor that is built and active in the current design. |
| Bank | Blade angle away from the ring plane about its chord axis; equivalent to pre-cone in AeroDyn. |
| Blade scale | Gene scaling blade span and chord; blade mass follows the span-cubed law used by the model. |
| Genome | Design vector describing one candidate machine. |
| Decoder | Maps a genome to built machine parameters. |
| Builder | Constructs the simulation model from decoded parameters. |
| Evaluator | Runs the simulation, applies gates, and returns scores. |
| Relax run | 10 s transient phase allowing startup decay before measurement. |
| Measurement window | 40 s settled phase used for scoring. |
| Power-law generator load | Load law `τ = k ω²`, giving `P = k ω³`. |
| `k` | Generator load constant, fixed at 2.24 N·m/(rad/s)² for the campaign. |
| FoS | Factor of safety: capacity over demand. |
| Gate | Pass/fail constraint applied during evaluation. |
| ok | Design passes every gate. |
| reject | Design fails a generic gate. |
| clearance_reject | Design fails the clearance gate. |
| reject_twist | Design fails the twist gate. |
| kg-equivalent objective | Search objective: airborne mass plus gate penalties, expressed in kg-equivalent. |
| Differential evolution, DE | Population-based search algorithm used by the campaign. |
| Island | Independent DE population with its own drift. |
| ODE path / cold path | Full dynamics path labeled `:cold` in code; reference fidelity path. |
| Rapid path / warm path | Faster pre-solved start path labeled `:warm` in code. |
| Rope-break gate | Gate that fails a run if a line breaks. |
| δcrit | Over-twist limit for a TRPT segment. |
| Segment torque margin | Segment torque capacity divided by segment torque carried. |
| Bank derate | Calculated reduction in ring output because banked blades sweep less streamtube frontal area. |
| Physics era | Model/code state identified by commit, used to keep results comparable. |

You should also define or move to the tracker:

- `folded class`
- `pre-fold`
- `cp fix`
- `Daisy anchor`
- `bank derate2-results` branch meaning
- `post-95c385d_wind-authority` era

If those are internal jargon, either define them briefly or put them in an internal glossary appendix.

---

## 9. Fix small consistency issues that make the report feel less polished

These are not huge, but they add up.

### Numbering

The Methods section currently jumps from **2.2** to **2.4**. That creates a visible gap.

Either insert a missing **2.3**, or renumber:

```text
2.1 The kite turbine and its terms
2.2 The simulation analysis pipeline instrument and its terms
    2.2.1 The gene
    2.2.2 The builder and decoder
    2.2.3 The evaluator
    2.2.4 Gates and operating point
2.3 The campaign
2.4 Fidelity paths
2.5 Reproducibility
```

Or, if you want to keep the current numbering, add a real 2.3.

---

### “Fail one gate” wording

Current:

```text
Of the 930, 508 designs pass every gate and 422 fail one gate (NR-002).
```

A design may fail more than one physical check but be assigned one status. Safer:

```text
Of the 930, 508 designs pass every gate and 422 are classified as failures:
301 reject, 110 clearance_reject, and 11 reject_twist (NR-002).
```

---

### Precision consistency

You use both:

- `15.0`
- `14.972`

That is acceptable if you are rounding, but make it explicit once.

Suggested:

```text
The window-minimum factor of safety is 14.972, quoted as 15.0 where rounded
(NR-009).
```

After that, use one convention.

---

### “Failure boundary” vs “gate floor”

The ring-utilisation figure mentions a fail boundary at the unit value, i.e. FoS = 1. The campaign gate is FoS ≥ 2.5. Those are different things.

Add a sentence to the figure caption or section:

```text
The dashed line marks the physical interaction limit at 1.0, corresponding to
FoS = 1. The campaign structural gate is stricter, requiring FoS ≥ 2.5.
```

This prevents readers from confusing physical failure with gate pass/fail.

---

### Units and terminology

Pick one style and use it consistently:

- Use `kW`, not “kilowatts,” after first definition.
- Use `m/s`, `N·m`, `rad/s`.
- Choose one spelling for the machine family:
  - I would use **ground-generation** in prose.
  - Use **ground-gen** only as a compact label if needed.
- Avoid “candidate kite turbine” when “candidate” or “design” is enough.
- Use **kg-equivalent** when referring to the objective, not kilograms, because penalties are included.

For example, the machine-evolution-strip caption says:

```text
The number under each machine is its search objective, in kilograms.
```

That should probably be:

```text
The number under each machine is its search objective, in kg-equivalent.
```

because the objective includes penalties.

---

## 10. Make figure captions start with the takeaway

Your captions are detailed, which is good, but they often start with “This figure shows…” A polished report can lead with the result.

### Ring utilisation

Current first sentence:

```text
This figure shows how much of the structural check on each ring comes from
compression and how much from bending.
```

Better:

```text
The hub ring R6 governs the structural check at FoS 15.0; all other airborne
rings have much larger margins. The plate stacks axial and bending shares for
each checked ring at the winner’s final operating point.
```

Then keep the detailed explanation after that.

### Twist limit

Better opening:

```text
All five TRPT segments remain inside their over-twist limits at the winner’s
final operating point, with S1 carrying the least torque margin, 2.03.
```

Then explain panels A and B.

### Machine evolution strip

Better opening:

```text
Island 3’s best-so-far objective falls from 36.109 to 27.364 kg-equivalent as
the built geometry converges to the register winner.
```

Then explain the panels and scale.

This makes the figures useful even to readers who skip the long captions.

---

## 11. Move bracketed notes out of the report body

Several bracketed notes are useful, but they interrupt the reader-facing text:

```text
[2.24 holds a register row (NR-015). The other values need rows first.]
[Daisy values need register rows before the final report quotes them.]
[Systems block diagram requested: figure-map row 19 ...]
```

For a polished draft, move those into one of two places:

1. **Open data requests** in the tracker, or
2. a short **“Draft status and open requests”** section at the end.

Example:

```text
Draft status and open requests

The following items are tracked outside the report body:
- Systems block diagram for the simulation analysis pipeline instrument.
- Register rows for historical generator gains quoted in the failure ledger.
- Register rows for Daisy anchor values before final quotation.
- Phase 1–2 lever extracts for section 3.5.
- Track D glossary ratification for section 6.
```

Then the main text stays clean.

---

## 12. Add a short “scope and non-goals” paragraph early

The report already says it is simulation-only, but that scope would help even earlier. After the Introduction or at the end of the Summary, add something like:

```text
Scope and non-goals

This report is a simulation screen over a bounded design space. It establishes
whether feasible compact candidates exist under the modeled load, wind, gates,
and fidelity path. It does not establish flight readiness, global optimality,
launch or recovery safety, blade structural integrity, lifter modulation across
wind bands, or performance under gusts and turbulence.
```

That prevents readers from overinterpreting the large FoS and power result.

---

## 13. Improve References and Data availability without weakening provenance

### References

Current text:

```text
Seeded in references.bib. Fifteen of eighteen sources verified. Three source
calls pending...
```

That is useful for the team, but it is not a polished References section. For the report body, either:

- list the references normally and mark pending items as `[pending verification]` only in draft status, or
- move the verification status to Document Control.

In-text citations should be consistent. If you use author names in the Introduction, use the same citation style throughout:

```text
Loyd showed...
Diehl set...
Trevisi built...
```

or numbered references:

```text
The theoretical power ceiling is established in [1].
The classification axes follow [2].
```

Pick one.

---

### Data availability

This section is already strong. I would make it more operational:

```text
8 Data availability and reproducibility

The dataset is committed to the repository at dd3cc6a on bankderate2-results.
The launch commit is a76c5e9. The Phase 0 audit sits at master 31ca00d. The
fidelity probes sit on the bank-derate-cos2p65 branch.

Every cited number traces to a signed row in the data register. Every figure
ships with its generating script, source extract, and data commit. The campaign
runner fixes one random seed per island, so the same code and configuration
repeat the search.

To reproduce a quoted result:
1. Locate the cited NR row.
2. Open the named source file or extract.
3. Check the commit and physics era in the provenance stamp.
4. Run the named probe or script if the row is derived rather than raw.
```

That makes reproducibility actionable.

---

## 14. A minimal v0.30 editing plan

If you want a fast improvement pass, do these in order:

### Priority 1: Fix structure

1. Move `ring-utilisation` and `twist-limit` into a new **Winner margins** section.
2. Keep **Design levers** as a separate pending/interim section.
3. Move **Evolution story** after the convergence and winner sections.
4. Rename or renumber Methods so there is no missing 2.3.

### Priority 2: Write the sections that can be completed now

5. Write **Winner margins** from NR-021, NR-022, NR-040.
6. Write **Evolution story** from NR-005, NR-006, NR-036, NR-011.
7. Write **Design implications** as conditional recommendations.
8. Rewrite the Conclusion as a conditional decision statement.

### Priority 3: Clean up auditability

9. Add a starter Nomenclature section.
10. Move bracketed notes to an open-requests list.
11. Add register rows or remove numbers for:
    - site wind speed/height if not fully covered by NR-032,
    - historical k values in the failure ledger,
    - Daisy anchor values in the conclusion.
12. Make figure captions start with the takeaway.

### Priority 4: Polish language

13. Standardize units and precision.
14. Choose one spelling for ground-generation / ground-gen.
15. Replace “fail one gate” with “classified as failures.”
16. Use **kg-equivalent** for objective values, not kilograms.
17. Tighten repeated `The ... The ... The ...` openings.

---

## 15. The single biggest improvement

The biggest win is to stop treating the later sections as “leftover notes” and start treating them as the decision part of the report.

A polished later section should always answer:

```text
What did we learn?
What evidence supports it?
What does it not prove?
What should we do next?
```

For example:

| Section | Learn | Evidence | Does not prove | Next action |
|---|---|---|---|---|
| Winner margins | Winner is structurally and twist-wise comfortable at the final point | NR-021, NR-022, NR-040 | Blade integrity, lifter loads, gusts | Add blade gate and gust cases |
| Evolution story | Island 3 found a lower-penalized feasible design than islands 1–2 | NR-003–NR-006, NR-036 | Global optimum | Run longer or broader campaign if needed |
| Design implications | Clearance and inactive genome slots deserve attention | NR-002, NR-011, NR-017 | Optimal gene set | Build lever extracts and decoder changes |
| Discussion | Instrument and model limits are known and bounded | NR-012, NR-013, PRD 0006:147 | Flight readiness | Fix warm path, add blade checks |

If every later section has that shape, the report will feel much more finished even while some sections remain pending.