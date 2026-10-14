The v0.21 draft is already much stronger than the earlier version. The abstract is present, the objective is clearer, the campaign table is useful, the gate table is a major improvement, the failure ledger is visible, and the document control/build record has been moved out of the main narrative.

The next improvement is not mainly about adding more numbers. It is about making the report represent the **Kite Turbine Dynamics project** as a coherent engineering effort with three visible layers:

1. **The machine** — what was searched, what the winner looks like, and what it can do in simulation.  
2. **The search** — how the design space was explored, what survived, what failed, and what the search tells us.  
3. **The instrument** — how trustworthy the simulation pipeline is, where it broke, how it was corrected, and what remains open.

Right now the report contains all three, but they are still somewhat fused. To represent the project better, the report should make those three layers explicit and decision-useful.

Below is a practical plan for improving the representation of the work in v0.22 and beyond.

---

# 1. Make the report’s central argument explicit

The report currently begins with background and then moves into methods. That is fine, but the reader should immediately understand what the project has accomplished and what decision the report supports.

Add a short **key findings** block after the abstract, or fold it into the introduction.

Suggested one-sentence thesis:

> The Kite Turbine Dynamics project has built a reproducible simulation instrument for a ground-generation rotary kite turbine and used it to screen a 5 kW-class TRPT design space; the current evidence supports advancing the best feasible candidate into blade-structural and lifter-validation work, but not flight qualification.

Then add five or six bullet points:

> **Key findings**
>
> - The campaign evaluated 930 candidate designs using a differential-evolution search over ring geometry, polygon count, rotor count, bank angle, and blade scale (NR-001).  
> - 508 designs passed all modeled gates; 422 were rejected by structural, clearance, or twist gates (NR-002).  
> - The campaign winner is a feasible 5 kW-class candidate: mean power 5.309 kW, airborne mass 25.698 kg, minimum modeled FoS 14.972 (NR-008, NR-018, NR-009).  
> - All checked TRPT rings and twist segments remain below their failure boundaries at the final operating point; the least segment torque margin is 2.03 at S1 (NR-021, NR-022, NR-040).  
> - The search objective improved from a recorded seed score of 36.109 kg-equivalent to 27.364 kg-equivalent on island 3, but the campaign was a screen, not an exhaustive survey (NR-005, NR-006).  
> - The result is simulation-only. Blade integrity is not yet gated, lifter modulation is assumed, launch/recovery are excluded, and the rapid-path rope-break gate fix remains open (NR-013).

This would make the report feel less like a data dump and more like an engineering conclusion.

---

# 2. Add a “claim–evidence” structure

One of the project’s strongest assets is its provenance discipline: register rows, commits, scripts, hashes, and signed values. The report should make that discipline visible without making the reader wade through it.

Add a small **claim–evidence matrix**, either in the introduction or as an early appendix.

| Claim | Evidence | Report location | Register rows |
|---|---|---|---|
| Campaign scale and status mix | 930 designs; 508 ok, 301 reject, 110 clearance_reject, 11 reject_twist | §3.1 | NR-001, NR-002 |
| Winner power | Mean honest-window power 5.309 kW | §3.3 | NR-008 |
| Winner mass | Airborne mass 25.698 kg | §3.3 | NR-018 |
| Structural margin | Minimum FoS 14.972; ring utilization below failure boundary | §3.3, §3.4 | NR-009, NR-021 |
| Twist/torque margin | All segments within twist limit; least torque margin 2.03 at S1 | §3.4 | NR-022, NR-040 |
| Search improvement | Island best objective improved from seed to winner | §3.2 | NR-003–NR-006 |
| Instrument fidelity | ODE/cold path reproduces recorded fields; rapid/warm path has rope-break gate issue | §4.1 | NR-012, NR-013 |
| Model boundaries | Blade integrity, lifter modulation, launch/recovery, gusts not fully modeled | §4.3 | PRD 0006:147, assumptions |

This matrix would make the report’s epistemic posture clear: every major claim is tied to a signed row and a reproducible artifact.

---

# 3. Make the objective and penalties explicit

The draft now says:

> Objective search objective (airborne mass plus penalties), kg NR-036, NR-039

and later:

> Island 3 reaches 27.364 kilograms at generation 26 (NR-005), the search objective. It reads the airborne mass 25.698 kilograms (NR-018) plus 1.665 kilograms of objective penalties (NR-039).

This is much better, but the phrase “kilograms” is still dangerous. The 27.364 value is not purely physical mass; it is a **kg-equivalent objective score**.

Use this terminology consistently:

> The campaign minimizes a kg-equivalent objective score defined as airborne mass plus gate penalties. For island 3, the best recorded objective score is 27.364 kg-equivalent, composed of 25.698 kg airborne mass and 1.665 kg-equivalent penalties (NR-005, NR-018, NR-039).

Then add a small table if the register supports it:

| Objective component | Value | Units | Source |
|---|---:|---|---|
| Airborne mass | 25.698 | kg | NR-018 |
| Total penalties | 1.665 | kg-equivalent | NR-039 |
| Objective score | 27.364 | kg-equivalent | NR-005 |

If possible, break the 1.665 kg-equivalent penalty down by source:

| Penalty term | Value | Source |
|---|---:|---|
| Power floor penalty | ? | ? |
| Clearance penalty | ? | ? |
| Twist penalty | ? | ? |
| FoS penalty | ? | ? |
| Other | ? | ? |

If the breakdown is not yet signed, say so explicitly:

> The register currently records the total objective penalty as 1.665 kg-equivalent (NR-039). A term-by-term penalty breakdown will be added when the corresponding register rows are signed.

This matters because the convergence plot and evolution strip currently show “kg” values that are actually objective scores. The reader needs to know whether lower is always better and whether the value includes penalties.

---

# 4. Clarify the difference between mass, objective score, and physical candidate quality

The report should make this distinction explicit in §3.2 or §3.3.

Suggested wording:

> The campaign searches over a kg-equivalent objective score, not raw mass alone. A lower score is better, but the score includes penalties for constraint violations or near-limit behaviour. Therefore, the best objective score does not always correspond directly to the lowest physical airborne mass. The winner’s physical airborne mass is reported separately as 25.698 kg (NR-018).

This prevents a subtle but important misreading: the reader might otherwise think the project found a 27.364 kg machine, when the actual airborne mass is 25.698 kg.

---

# 5. Add an assumptions and scope table

The report currently states several assumptions in prose. They should be collected in one place.

Suggested table:

| ID | Assumption / scope limit | Consequence if false |
|---|---|---|
| A1 | The lifter stack can modulate lift across the operating wind-speed range. | If not, the winner may require multiple kites or active control not modeled here. |
| A2 | The scored wind is steady and sheared according to the site profile; no gusts or turbulence are included. | Power and loads may shift under realistic atmospheric conditions. |
| A3 | Launch and recovery are excluded. Each run starts with the machine already aloft. | The candidate has not been validated through full mission phases. |
| A4 | Blade root integrity is not structurally gated in this campaign. | The reported FoS does not include blade failure. |
| A5 | Tether-to-blade bridling drag is not included. | Aerodynamic drag and loads may be underpredicted or misdistributed. |
| A6 | The rapid/warm path is not currently valid for final rope-break acceptance. | Consumers using the default path may reject healthy machines. |
| A7 | The campaign is a screen, not an exhaustive global search. | The winner is the best found in this searched region, not a proven global optimum. |

This table would make the report’s boundaries much easier to defend.

---

# 6. Improve the Methods section

The Methods section is technically strong but still contains some opaque project-specific language. To represent the work better, it should read as a reproducible method, not just an internal log.

## 6.1 Define the machine terms more cleanly

The current definitions are good, but a few sentences need tightening.

Current:

> The polygon count names the number of lines. Each line meets the ring at one vertex. The polygon count equals the blade count.

This becomes confusing later when there are inactive rotor slots. Suggested replacement:

> For an active rotor, the polygon count equals the number of blades on that rotor and the number of TRPT line attachments around the ring. Inactive genome slots may contain bank or blade-scale values, but they do not instantiate physical blades unless selected by the rotor count.

Current:

> Its blade scales read 0.82 on the active rotor and 0.20 on a rotor that does not exist.

Suggested replacement:

> The winner genome contains two blade-scale slots. Slot 1 reads 0.82 and is decoded to the single active rotor. Slot 2 reads 0.20 but is inactive because the rotor count is one; it does not correspond to a physical blade set.

Same for bank angle:

> The winner genome contains two bank-angle slots. Ring 6 decodes the active main-rotor bank angle as 7.088 degrees. A second bank slot reads 22 degrees, but because the rotor count is one, it does not reach a physical rotor.

This is much clearer and removes the odd “rotor that does not exist” phrasing.

---

## 6.2 Expand the evaluator description

The evaluator section should be split into smaller logical blocks:

1. Operating point and load law  
2. Honest window definition  
3. Multibody dynamics and integration  
4. Gate logic  
5. Determinism and reproduction  

A few specific improvements:

### Define “honest window” formally

Add:

> The honest window is the 40-second scoring interval following a 10-second relax run. Performance metrics are computed only over this interval. The relax run allows startup transients to decay but is not used for final performance scoring.

Then state the time axis explicitly:

> In the current capture, the full scored run spans approximately 0 to 50 seconds: 0–10 s relax, 10–50 s honest window. The final operating-point capture occurs near t = 50 s.

This would make the existing figure captions much easier to interpret.

### Clarify the FoS target/floor phrase

Current:

> a factor of safety (FoS) target and hard floor, both 2.5

This is still slightly ambiguous. Suggested replacement:

> The campaign applies a minimum structural FoS gate of 2.5. The same value is used as the optimization target/penalty threshold for structural margin. A design must pass the hard FoS floor to be accepted; the objective may additionally penalize behaviour near the target.

If that is not exactly right, adjust the wording, but the reader should understand whether 2.5 is a gate, a penalty threshold, or both.

### Define the line length

The report says:

> line length of 18.8 metres (NR-015)

But it does not clearly say what “line” means in that sentence: TRPT line? lift line? tether segment? shaft sub-segment?

Add a definition:

> The campaign line length is the nominal TRPT line length used in the scored geometry, 18.8 m (NR-015). This is distinct from the lift-line geometry described in §3.3.

If “line length” means something else, correct it. This is important because the length screen compares 18.8, 21.2, and 25.0 m.

### Define the wind profile

Current:

> The campaign wind is steady and sheared. Its speed rises with altitude on the site wind profile. The profile comes from wind measured at the Daisy machine.

This is a major modeling assumption, but it is still under-specified. Add either a table or a short formula:

| Quantity | Value / form | Source |
|---|---|---|
| Wind regime | Steady, sheared, no gusts | ? |
| Shear model | Power-law / log-profile / site profile | ? |
| Reference height | ? m | ? |
| Reference speed | ? m/s | ? |
| Hub-height speed | ? m/s | ? |
| Ground speed | ? m/s | ? |

If the exact values are not yet signed, say:

> The scored wind profile is steady and sheared, derived from Daisy site measurements. The profile parameters will be cited by register row when the corresponding rows are signed.

But do not leave “Daisy anchor” as a vague phrase in the conclusion without either defining it or marking it pending.

---

## 6.3 Expand the campaign table

The current campaign table is good. Extend it to include the DE parameters if available:

| Parameter | Value | Source |
|---|---:|---|
| Optimizer | Differential evolution | ? |
| Islands | 3 | NR-001 |
| Designs per island | 310 | NR-001 |
| Total evaluations | 930 | NR-001 |
| Initial population / seed genome | ? | NR-006 |
| Number of generations | up to 30 | ? |
| Mutation strategy | ? | ? |
| Crossover rate | ? | ? |
| Selection rule | ? | ? |
| Island migration / drift | ? | ? |
| Random seed policy | One fixed seed per island | scripts/run_v13_5kw_masslift.jl |
| Objective | Airborne mass + penalties, kg-equivalent | NR-036, NR-039 |
| Power floor | 5.0 kW | NR-027, NR-039 |
| Minimum FoS | 2.5 | NR-015 |
| Relax run | 10 s | NR-015 |
| Honest window | 40 s | NR-015 |
| Load constant k | 2.24 N·m/(rad/s)² | NR-015 |
| Line length | 18.8 m | NR-015 |

If some values are not in the register, mark them as pending rather than omitting them silently.

---

## 6.4 Make the fidelity paths section decision-useful

The current §2.5 is useful but short. Add a table:

| Path | Code name | Start condition | Use | Current status |
|---|---|---|---|---|
| ODE path | `:cold` | Full dynamic settle from startup state | High-fidelity scoring and reported results | Valid for current winner reproduction (NR-012) |
| Rapid path | `:warm` | Static pre-solve with injected velocities | Faster screening | Currently rejects recorded winners at rope-break gate due to gate placement during relax (NR-013) |

Then add a strong sentence:

> The campaign results reported here use the ODE/cold path. The rapid/warm path should not be used for final acceptance until the rope-break gate is restricted to the measurement window as ruled.

This is one of the most important instrument-related findings in the report, and it should be impossible to miss.

---

# 7. Improve the Results section

The Results section now has good data, but it still needs more interpretation and visual support.

## 7.1 Add a status-mix table with percentages

Current text:

> The status mix reads 508 ok, 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).

Add a table:

| Status | Count | Fraction | Meaning |
|---|---:|---:|---|
| ok | 508 | 54.6% | Passed all gates |
| reject | 301 | 32.4% | Failed primary gate(s) |
| clearance_reject | 110 | 11.8% | Failed clearance gate |
| reject_twist | 11 | 1.2% | Failed twist gate |
| Total | 930 | 100% | — |

Then add one interpretive sentence:

> The status mix shows that the search space contains a substantial feasible region, but clearance and primary structural/operational gates remove nearly half of the evaluated designs.

If you have gate-by-gate failure counts, add them. That would be very useful.

---

## 7.2 Clarify convergence units

Current:

> Island 1 reaches 30.578 kilograms at generation 30 (NR-003). Island 2 reaches 30.637 kilograms at generation 30 (NR-004). Island 3 reaches 27.364 kilograms at generation 26 (NR-005), the search objective.

Suggested replacement:

> The best recorded objective score on island 1 is 30.578 kg-equivalent at generation 30 (NR-003). Island 2 reaches 30.637 kg-equivalent at generation 30 (NR-004). Island 3 reaches 27.364 kg-equivalent at generation 26 (NR-005). The winner’s physical airborne mass is 25.698 kg (NR-018); the objective score additionally includes 1.665 kg-equivalent of penalties (NR-039).

This avoids mixing physical mass and optimization score.

---

## 7.3 Add a “winner at a glance” table

You already have an operating-point table, which is excellent. Consider renaming it:

> Table: Winner operating point and margin summary

Then add the torque margin row, since it appears in the abstract but not in the table:

| Quantity | Value | Source |
|---|---:|---|
| Mean power, honest window | 5.309 kW | NR-008 |
| End-of-window power | 5.314 kW | NR-008 |
| Minimum factor of safety | 14.972 | NR-009 |
| Least segment torque margin | 2.03 at S1 | NR-040 |
| Window power swing | 0.029 kW | NR-014 |
| Settle angular speed | 10.170 rad/s | NR-016 |
| Window-mean speed | 13.38 rad/s | NR-029 |
| Delivered torque | 396.76 N·m | NR-030 |
| Airborne mass | 25.698 kg | NR-018 |
| Hub radius | 4.580 m | NR-011 |
| Ground radius | 0.804 m | NR-011 |
| Ring count | 6 | NR-011 |
| Polygon count | 3 | NR-011 |
| Active rotors | 1 | NR-011 |
| Main-rotor bank, ring 6 | 7.088 deg | NR-017 |
| Lift-line elevation | 70 deg | NR-026 |
| Lift-line tension | 324.1 N | NR-010 |

This makes the winner’s evidence compact and easy to audit.

---

## 7.4 Add a gate-margin table, not just pass/fail

The current gate table is good, but it would be stronger with margins.

| Gate | Threshold | Winner value | Margin / interpretation | Source |
|---|---:|---:|---|---|
| Power floor | P_mean ≥ 5.0 kW | 5.309 kW | +0.309 kW, +6.2% above floor | NR-008, NR-027 |
| Structural FoS | FoS ≥ 2.5 | 14.972 minimum | Large margin; about 6× floor | NR-009, NR-015 |
| Clearance | Blade-tip clearance pass | pass | Need numeric clearance if available | NR-036 |
| Twist | Segment twist ≤ δcrit | all segments within limit | Add min twist utilization/margin if available | NR-022 |
| Torsional capacity | Torque/capacity margin ≥ 1 | 2.03 at S1 | Least torque margin, still above 1 | NR-040 |
| Rope break | No rope break in window on cold path | pass | Warm path currently false-rejects | NR-012, NR-013 |

This would immediately show which gates are tight and which are loose.

The likely key insight is: **power is the closest performance gate, while structural margins are large.** That is a major design implication.

---

## 7.5 Explain where the minimum FoS comes from

The report says:

> Its factor of safety reads 14.972 (NR-009). That value is the window minimum. The capture hub ring reads 15.033 at the final step (NR-021).

This is good, but the reader may wonder: if the ring FoS values in the figure are 15.033 or higher, where does 14.972 come from?

Add a sentence such as:

> The minimum window FoS of 14.972 (NR-009) is the global minimum over the checked structural elements and time steps used by the gate. The ring-utilization plate reports ring-specific beam-column FoS values at the final capture step; the hub ring reads 15.033 (NR-021). The slight difference reflects the distinction between the global gated minimum and the final-step ring readout.

If that is not exactly right, adjust it, but the report should explicitly reconcile NR-009 with NR-021.

---

## 7.6 Add a mass-budget representation

Because the objective is mass-related, the reader will want to know where the mass goes. Even if the full breakdown is not yet signed, add a placeholder table:

| Mass component | Value | Source |
|---|---:|---|
| Rings / beams | ? | ? |
| TRPT lines | ? | ? |
| Blades | ? | ? |
| Lifter stack | ? | ? |
| Other airborne components | ? | ? |
| Total airborne mass | 25.698 kg | NR-018 |

If the lifter mass is not separated, say so:

> The register currently records total airborne mass as 25.698 kg (NR-018). A component-level mass breakdown will be added when the corresponding rows are signed.

But the report should signal that this is a planned evidence item.

---

# 8. Make §3.4 “The levers” useful even while pending

Section 3.4 is currently marked PENDING, but it already contains two strong figures: ring utilization and twist/torque limits. The problem is that the section title promises “levers,” which implies sensitivity to design variables, while the current content mostly shows margins at one operating point.

There are two options.

## Option A: Rename the section temporarily

If Phase 1–2 landscape analysis is not ready, rename it:

> **3.4 Winner margin evidence**

Then later add:

> **3.5 Design levers and sensitivity** [PENDING]

This avoids promising a sensitivity analysis that is not yet present.

## Option B: Write a provisional interpretation

Even without full landscape data, you can say what the current margins imply:

> At the winner operating point, structural and twist margins are large relative to the gates. The closest performance margin is the power floor: mean power is 5.309 kW against a 5.0 kW floor. This suggests that, within the current model, further mass reduction may be possible by trading structural margin for lighter geometry, but only until aerodynamic power, blade integrity, or clearance constraints become active.

Then mark the deeper lever analysis as pending:

> A full lever analysis requires Phase 1–2 landscape data: sensitivity of power, mass, FoS, clearance, and twist to ring count, polygon count, bank angle, blade scale, and line length.

That would make the section honest and still useful.

---

# 9. Make §3.5 “The evolution story” more than a figure caption

The machine-evolution strip is a strong visual, but the section is currently PENDING and mostly relies on the figure caption.

Add a short narrative:

> The island-3 evolution strip shows the best built geometry at selected generations from the common seed to the winner. The sequence demonstrates that the search did not merely tune one parameter; it moved through a coupled region of ring geometry, polygon count, rotor placement, and blade scale. The final winner retains large structural margin, indicating that the campaign had not fully exhausted the mass-reduction direction within this screen.

Then add what to watch for:

> The panels should be read together with the convergence plot. A decrease in objective score does not by itself identify which gene changed; the evolution strip provides the geometric interpretation.

If Phase 3 is not ready, state that explicitly:

> Quantitative attribution of each generation’s improvement to specific genes awaits Phase 3 analysis.

---

# 10. Make §3.6 “Design implications” decision-oriented

Even while pending, this section should contain provisional implications. Suggested content:

## Provisional implications

1. **The feasible region is non-empty.**  
   The search found a candidate that passes the modeled gates for a 5 kW-class machine.

2. **Structural margin is not currently the binding constraint.**  
   The minimum modeled FoS is far above the 2.5 floor, and checked ring/twist margins are large.

3. **Power is likely the tighter performance constraint.**  
   Mean power is only 6.2% above the 5.0 kW floor.

4. **Mass reduction may be possible, but not yet justified.**  
   Large structural margins suggest headroom, but blade integrity is not gated and the search was limited.

5. **Clearance gates are materially shaping the design space.**  
   110 designs failed clearance, so geometry bounds are not trivial.

6. **The next limiting factors are likely outside the current model.**  
   Blade structural checks, lifter modulation, launch/recovery, and atmospheric realism may dominate before hardware claims can be made.

This would make the report feel like it is guiding engineering decisions, not just reporting numbers.

---

# 11. Strengthen the Discussion section

The Discussion is one of the best parts of the draft. To represent the project better, it should be organized around three questions:

1. **How much can we trust the result?**  
2. **What did the instrument teach us?**  
3. **What does the result mean for the next phase of work?**

## 11.1 Evaluation fidelity

The current §4.1 is strong. Make the conclusion even more explicit:

> The ODE/cold path is currently the trusted scoring path for this report. It reproduces every recorded winner field at stored precision (NR-012). The rapid/warm path, however, rejects all three winners at the rope-break gate because the gate is active during the relax transient (NR-013). This is an instrument issue, not evidence that the machines are structurally broken. Until the rope-break gate is restricted to the measurement window, the warm path should be treated as invalid for final acceptance.

Then add a small validation table:

| Check | Result | Source |
|---|---|---|
| Cold-path reproduction of winner fields | Pass at stored precision | NR-012 |
| Warm-path rope-break behaviour | False reject due to relax transient | NR-013 |
| Probe scripts for path comparison | Present in repo | scripts/probe_rapid_vs_ode_winners.jl, scripts/probe_warm_reject_cause.jl |

This makes the fidelity argument concrete.

---

## 11.2 Convert the failure ledger into a table

The failure ledger is valuable, but prose alone buries it. Add a table:

| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | Invalid genome diverged while telemetry appeared plausible | Divergence review | Decoder must refuse unbuildable genomes at gate time | Lesson applied |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | Middle rotor placed on hub | Review / correction | Rotor-to-ring map must be validated against build geometry | Corrected |
| 2026-08-22 blade-mass-law correction | Model correction | Prior campaign winners voided | Physics review | Void affected data; retain historical record | Data voided, record kept |
| 2026-08-13 k-alignment fault | Gain misalignment | 5 kW designs scored at 50 kW default gain | Acceptance test | One constant, one source file | Caught and corrected |
| 2026-08-24 stale gain re-gate | Stale configuration | Winner re-gate used superseded gain | Pre-push review | Re-gate at campaign gain returned 5.18 kW | Corrected |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | Guard missing from some scoring paths | Telemetry review | Gates must pin measured numbers; drift should fail suite | Near-miss, no corrupted survivor found |

Then keep a short narrative after the table. The table makes the discipline visible; the narrative explains the culture.

---

## 11.3 Add an “era map”

The report repeatedly mentions earlier eras, bank derate, cp fix, folded class, pre-fold winner, post-landing decode, and wind authority. These are important, but they are still somewhat opaque to a new reader.

Add a small era table:

| Era / change | Effect on search space | Data status |
|---|---|---|
| Pre-bank-derate campaigns | Different bank-angle physics; earlier winners not directly comparable | Superseded as era record |
| Post-bank-derate | Current bank derate applied throughout | Current campaign basis |
| cp fix / folded class | Span shrink affected power; pre-fold length-screen rows failed | Recorded; folded class passes at 18.8 m |
| post-95c385d_wind-authority | Current wind authority used for scored results | Current physics era |

This would make the report’s temporal logic much clearer.

---

## 11.4 Expand model boundaries into a risk register

The current §4.3 is good. Make it even more explicit by turning it into a risk register:

| Risk / boundary | Current treatment | Impact if unaddressed | Next action |
|---|---|---|---|
| Blade root integrity not gated | Blade FoS effectively infinite in model | Winner may be structurally optimistic | Implement beam-on-supports blade model, PRD 0006:147 |
| Bridling drag omitted | Model assumes unbridled blade behaviour | Loads and power may shift | Add bridling drag/load model |
| Lifter modulation assumed | Required lift applied directly | Feasibility may not transfer to real launch/weather bands | Validate lifter stack across wind speeds |
| Launch/recovery excluded | Runs start aloft | Full mission feasibility unknown | Model launch and recovery sequences |
| No gusts/turbulence | Steady sheared wind only | Power/load variability unknown | Add turbulence/gust cases after base case is locked |
| Rapid path rope-break gate open | Warm path false-rejects winners | Screening tool may mislead users | Restrict rope-break detection to window |
| Limited search breadth | 930 evaluations, screen not survey | Winner may not be global optimum | Expand search or perform targeted local optimization |

This would make the Discussion much more actionable.

---

# 12. Add a “what this report does and does not show” section

A short subsection near the end of the Introduction or beginning of the Discussion would help a lot.

Suggested wording:

> This report shows that a feasible 5 kW-class TRPT kite-turbine candidate exists within the searched design space under the current simulation model and gates. It does not show that the machine is ready for flight, that the winner is globally optimal, or that all structural components are safe. Blade integrity, lifter modulation, launch/recovery, and atmospheric realism remain open work items.

This single paragraph would prevent overinterpretation.

---

# 13. Add a set of figures that represent the project as a system

The current figures are strong but still feel like exhibits rather than a coherent visual argument. The report should have a figure system that tells three stories: machine, search, instrument.

Below are the figures I would prioritize.

---

## Figure 1 — System anatomy and lift chain

**Purpose:** Establish the physical vocabulary.

**Layout:** Side elevation or isometric schematic of the full machine. Show lifter stack, lift line, sky anchor, cyan line, lift bearing, bridles, main rotor, TRPT rings R1–R6, ground station/PTO as dashed block.

**Labels:**  
lifter stack, lift line, sky anchor, cyan line, lift bearing, bridle, main rotor, TRPT lines, R1 ground ring, R6 hub ring, ground generator/PTO.

**Data type:** Schematic geometry plus a few winner dimensions: 6 rings, 3 lines, hub radius 4.580 m, ground radius 0.804 m.

**Relation to text:** Supports §1 and §2.1. It should make clear that the lifter provides lift only, not torque or drive.

**Suggested format:** SVG-first vector diagram, PNG fallback. Colour-blind-safe palette. Thick lines for primary load path, thin lines for secondary bridles.

**Caption subtext:**  
> Schematic anatomy of the ground-generation rotary kite turbine. The lifter provides lift only; torque is transmitted through the tensioned TRPT rings to the ground station.

This figure should be the reader’s first visual anchor.

---

## Figure 2 — Genome-to-machine decode strip

**Purpose:** Explain how a candidate design becomes a buildable machine.

**Layout:** Horizontal three-zone diagram.  
Left: genome chips.  
Centre: decoder rules.  
Right: simplified built machine.

**Genome chips:**  
ring geometry, polygon count, rotor count, bank angle slots, blade scale slots.

**Decoder rules:**  
- rotor count selects active rings  
- inactive slots do not instantiate blades  
- polygon count sets line/blade attachments for active rotors  
- bank and blade scale apply to decoded rotors

**Relation to text:** Supports §2.2 and §3.3. It explains why the winner can have a 0.20 blade-scale slot that does not correspond to a physical rotor.

**Suggested format:** Vector diagram with rounded rectangles and arrows. Active slots filled; inactive slots greyed or outlined.

**Caption subtext:**  
> The genome is a design vector. The decoder translates it into buildable geometry. Inactive gene slots remain in the vector but do not create physical blades.

---

## Figure 3 — Honest-window evaluation timeline

**Purpose:** Make the “honest window” concept visually undeniable.

**Layout:** Horizontal time axis from 0 to 50 s. Shade 0–10 s as relax, 10–50 s as honest window. Add lanes for speed, power, torque, and gate activity.

**Data type:** Time series plus boolean gate states.

**Relation to text:** Supports §2.3, §3.3, and the operating-point table. It explains why final capture is near t = 50 s and why transient behaviour is excluded from performance metrics.

**Suggested ranges:**  
- Speed: 0 to about 14 rad/s  
- Power: 0 to about 6 kW  
- Torque: 0 to about 450 N·m  
- Gate lane: green/red or pass/fail markers

**Caption subtext:**  
> Performance metrics are computed only over the 40-second honest window. The 10-second relax run is used for settling and is not included in final power scoring.

This figure would greatly improve readability of the operating-point values.

---

## Figure 4 — Campaign architecture and status funnel

**Purpose:** Show how 930 designs flow through gates.

**Layout:** Top-down funnel or horizontal pipeline.  
Top: 930 total evaluations.  
Branches: ok, reject, clearance_reject, reject_twist.  
Side panel: three islands, each 310 designs.

**Data type:** Counts and percentages.

**Relation to text:** Supports §2.4 and §3.1.

**Suggested format:** Vector funnel with labelled counts. Use a restrained palette: ok in green, rejects in neutral red/amber.

**Caption subtext:**  
> The campaign evaluated 930 designs across three islands. The status mix shows the fraction of the searched space that survives each modeled gate class.

This is one of the best ways to show the scale of the work without overwhelming the reader.

---

## Figure 5 — Convergence with objective-score clarity

**Purpose:** Show search progress over generations.

**Layout:** Line plot, x = generation, y = best objective score per island. Use kg-equivalent units. Add seed value as a horizontal dashed line. Optionally add a secondary line for airborne mass if available.

**Data type:** Time/generation series.

**Relation to text:** Supports §3.2 and the evolution strip.

**Suggested ranges:**  
- x: 0 to 30 generations  
- y: about 26 to 37 kg-equivalent

**Key annotations:**  
- seed score 36.109 kg-equivalent  
- island 3 winner 27.364 kg-equivalent at generation 26  
- physical airborne mass 25.698 kg if you add a second line or annotation

**Caption subtext:**  
> The convergence plot shows the best recorded objective score per island. The objective is kg-equivalent and includes penalties; it is not identical to physical airborne mass.

This would prevent misreading of “kg” values.

---

## Figure 6 — Pareto frontier: power versus objective/mass

**Purpose:** Show the search space, not just the best point.

**Layout:** Scatter plot.  
x = mean power, kW  
y = objective score or airborne mass, kg-equivalent/kg  
colour = status  
highlight winner and seed.

If possible, add a third visual channel: FoS, clearance margin, or twist utilization as point size or hue.

**Data type:** Campaign-level scatter.

**Relation to text:** Supports §3.1–§3.3 and the design implications. It shows that feasible designs exist above the power floor and reveals where rejects cluster.

**Suggested ranges:**  
- x: 4.5 to 6.5 kW  
- y: 24 to 37 kg-equivalent or mass, depending on data

**Annotations:**  
- vertical line at 5.0 kW power floor  
- winner point labelled  
- seed point labelled  
- optional shaded region for ok designs

**Caption subtext:**  
> The Pareto view shows the trade space between performance and objective score. The winner is the best feasible candidate under the modeled objective and gates, not a proven global optimum.

This figure would significantly improve the report’s representation of the search.

---

## Figure 7 — Winner operating-point time series

**Purpose:** Show that the machine settles and stays stable over the honest window.

**Layout:** Three or four aligned panels sharing one time axis:  
- angular speed, rad/s  
- power, kW  
- torque, N·m  
- optionally minimum FoS or segment margin

Shade relax and honest window. Mark final capture near t = 50 s.

**Data type:** Time series.

**Relation to text:** Supports §3.3 operating-point table. It gives the reader confidence that the reported mean/end values are not arbitrary snapshots.

**Suggested ranges:**  
- speed: 9 to 14 rad/s  
- power: 5.0 to 5.6 kW  
- torque: 380 to 420 N·m  
- margin/FoS: appropriate scale

**Caption subtext:**  
> The winner settles during the relax run and remains stable over the honest window. The final operating point used for margin plates is captured near the end of the scored interval.

---

## Figure 8 — Winner margin dashboard

**Purpose:** Summarize all gate margins in one view.

**Layout:** Horizontal bar or bullet chart, one row per gate:  
- power floor margin  
- structural FoS margin  
- clearance margin  
- twist utilization/margin  
- torsional capacity margin  
- rope-break status

Use a common “distance to limit” representation where possible. For rope break, use a pass/fail marker.

**Data type:** Margin values from register rows.

**Relation to text:** Supports §3.3 gate table and §3.4/§3.6 implications.

**Suggested design:**  
- Bar length = margin or utilization  
- Limit line at 1.0 or threshold  
- Winner value annotated  
- Source row under each bar

**Caption subtext:**  
> The margin dashboard compares the winner against each modeled gate. Power is the closest performance margin; structural and twist margins are large at the current operating point.

This would be one of the most useful figures in the report.

---

## Figure 9 — Ring utilization plate, improved

You already have a strong ring-utilization figure. To make it better:

- Keep the stacked axial/bending shares.  
- Add the global minimum FoS (NR-009) as an annotation if it is not one of the rings.  
- Add a small side panel showing what is not checked: ground ring, blade root integrity.  
- Add a note that torsion is tracked outside the beam-column interaction formula.

**Caption subtext:**  
> The plate covers airborne rings only. The ground ring is excluded because it is ground-supported. Blade root integrity is not included in this structural check.

This would prevent overgeneralization from the ring plate to full machine safety.

---

## Figure 10 — Twist/torque limit plate, improved

You already have a strong twist/torque figure. To make it better:

- Pair panels A and B more explicitly with matching segment labels.  
- Add a small table below the figure: segment, twist angle, δcrit, torque, torsional capacity, torque margin.  
- Highlight S1 as the least torque-margin segment (2.03).  
- Keep the explanatory notes about no-limit segments and removed 90° clamp.

**Caption subtext:**  
> Panel A shows transmitted twist against the over-twist limit. Panel B pairs segment torque with torsional capacity at the same final state. S1 carries the least torque margin, 2.03 (NR-040).

This would make the figure easier to audit.

---

## Figure 11 — Machine evolution strip with gene trajectories

You already have the evolution strip. To make it more analytical:

- Keep the seven machine panels.  
- Above or below each panel, add small line traces for key genes: ring count, polygon count, active rotor count, bank angle, blade scale.  
- Below each panel, keep objective score.  
- Add a final column or annotation comparing seed vs winner: hub radius, ground radius, mass/objective.

**Purpose:** Show not only what the machines look like, but how the genome moved.

**Relation to text:** Supports §3.5 and design implications.

**Caption subtext:**  
> The strip shows built geometry at selected island-3 generations. Gene traces show which design variables changed as the objective score decreased. The final panel is the campaign winner.

This would turn a nice visual into an analytical figure.

---

## Figure 12 — Failure ledger / era timeline

**Purpose:** Represent the project’s self-correction culture.

**Layout:** Horizontal timeline from early development to current report. Mark:  
- blade-mass-law correction  
- k-alignment faults  
- FoS guard near-miss  
- bank derate  
- cp fix / folded class  
- honest window adoption  
- wind authority 95c385d  
- rope-break gate issue

Use two lanes: “model/instrument corrections” and “data status outcomes.”

**Data type:** Event timeline.

**Relation to text:** Supports §4.2 and the era map.

**Caption subtext:**  
> The timeline shows how model, decoder, gate, and configuration corrections shaped the current search space. Voided data are retained as historical record but excluded from current conclusions.

This would make the failure ledger feel like a project asset rather than a list of mistakes.

---

## Figure 13 — Provenance map

**Purpose:** Show how report claims connect to code, data, and register rows.

**Layout:** Left-to-right flow:  
code commits → scripts/probes → datasets/extracts → register rows → report claims → figures.

Use small nodes with commit hashes and row IDs. Do not make it exhaustive; show the main chain for the winner.

**Relation to text:** Supports §2.6, §8, and appendix.

**Caption subtext:**  
> The provenance map traces a reported value from source code through data extraction, register signing, and figure generation. Every public claim should resolve to signed register rows and reproducible artifacts.

This would make the project’s reproducibility discipline visible as a system property.

---

# 14. Specific wording fixes in the current draft

Below are targeted edits that would improve clarity immediately.

## 14.1 “The development-history chapter”

Current:

> It stopped early: a screen, not a survey. The development-history chapter carries the trade, tagged by era.

Problem: there is no visible development-history chapter in the report.

Suggested replacement:

> It stopped early: a screen, not a survey. A full development history would compare earlier eras, but the current report limits itself to the post-wind-authority campaign and the recorded corrections that shaped it.

Or, if you plan to add the chapter:

> The development-history section will carry the era-by-era trade-offs. In this draft, the relevant corrections are summarized in §4.2.

---

## 14.2 “Daisy anchor”

Current:

> The Daisy anchor ties the model to a measured flight reference.

Problem: too vague, especially because references and register rows for Daisy values are pending.

Suggested replacement if values are not yet signed:

> The Daisy machine provides the measured flight reference used to constrain the wind profile and validate parts of the rotary family model. Specific Daisy comparison values will be cited by register row before the final report quotes them.

Or, if you have rows:

> The Daisy anchor ties the model to a measured flight reference (NR-xxx). The comparison shows ...

Do not leave “Daisy anchor” as an unsupported claim in the conclusion.

---

## 14.3 “The report states the presumption as one”

Current:

> The report states the presumption as one (2026-08-05).

Suggested replacement:

> This assumption is recorded as Assumption A1 (2026-08-05): the lifter stack can modulate to meet the required lift across the operating wind-speed range.

---

## 14.4 “All three islands start from one seed”

Current:

> All three islands start from one seed. The seed scores 36.109 kilograms (NR-006).

This may be true, but it could conflict with “one random seed per island.” Suggested replacement:

> The campaign used a fixed-seed policy for reproducibility. The recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006). Each island then evolved independently from its configured population.

Adjust if the actual DE initialization is different.

---

## 14.5 “The polygon count equals the blade count”

Suggested replacement:

> For an active rotor, the polygon count equals the number of blades on that rotor and the number of TRPT line attachments around the ring. Inactive genome slots do not create physical blades.

---

## 14.6 “Its blade scales read 0.82 on the active rotor and 0.20 on a rotor that does not exist.”

Suggested replacement:

> The winner genome contains two blade-scale slots: slot 1 = 0.82, decoded to the single active rotor; slot 2 = 0.20, inactive because the rotor count is one.

---

## 14.7 “A second bank slot reads 22 degrees, but it reaches no rotor at a count of one.”

Suggested replacement:

> The winner genome contains two bank-angle slots. Ring 6 decodes the active main-rotor bank angle as 7.088 degrees. A second bank slot reads 22 degrees, but because the rotor count is one, it does not decode to a physical rotor.

---

## 14.8 “The campaign wind is steady and sheared.”

Add:

> The scored profile excludes gusts, turbulence, and directional shifts. It represents a base-case atmospheric condition, not a full weather envelope.

---

# 15. Suggested revised section structure

For v0.22, I would consider this structure:

```text
Title page / status block

Abstract
Key findings
What this report does and does not show

1 Introduction
1.1 AWES context
1.2 Kite turbine and TRPT concept
1.3 Scope and assumptions
1.4 Report organization

2 Methods
2.1 Machine and terminology
2.2 Genome and decoding
2.3 Evaluator, load law, and honest window
2.4 Campaign configuration and objective
2.5 Gates and margin definitions
2.6 Fidelity paths: cold versus warm
2.7 Wind profile and environmental assumptions
2.8 Reproducibility and provenance

3 Results
3.1 Campaign scale and status mix
3.2 Convergence and objective improvement
3.3 Winner operating point
3.4 Winner margin evidence
    3.4.1 Ring utilization
    3.4.2 Twist and torque margins
3.5 Evolution story
3.6 Design implications

4 Discussion
4.1 Evaluation fidelity and validation
4.2 Failure ledger and era corrections
4.3 Model boundaries and risk register
4.4 What the result supports
4.5 What the result does not support

5 Conclusion
5.1 Summary of evidence
5.2 Decision-relevant implications
5.3 Next steps

6 Nomenclature
7 References
8 Data availability and reproducibility
Appendix A: Figure provenance
Appendix B: Artifact hashes / build manifest
```

This structure separates machine, search, instrument, and decision implications more cleanly than the current draft.

---

# 16. Prioritized v0.22 improvement checklist

If you want a practical near-term plan, I would prioritize these items in this order.

## Priority 1: Prevent misinterpretation

- Replace “kg” with “kg-equivalent objective score” wherever the value includes penalties.  
- Add key findings block after abstract.  
- Clarify that the winner is best feasible under current model/gates, not globally optimal.  
- Clarify difference between physical airborne mass and objective score.  
- Reconcile NR-009 minimum FoS with NR-021 ring FoS values.  
- Clarify what “line length 18.8 m” means.  
- Clarify inactive genome slots for bank angle and blade scale.

## Priority 2: Make the evidence structure visible

- Add claim–evidence matrix.  
- Add status-mix table with percentages.  
- Add gate-margin table with numeric margins where possible.  
- Add validation table for cold/warm paths.  
- Add failure-ledger table.  
- Add era map or corrections timeline.

## Priority 3: Add the most useful figures

- System anatomy / lift chain.  
- Honest-window evaluation timeline.  
- Campaign status funnel.  
- Convergence plot with kg-equivalent units.  
- Pareto frontier of power versus objective/mass.  
- Winner margin dashboard.  
- Improved evolution strip with gene traces.

## Priority 4: Complete or quarantine pending sections

Either complete the levers/implications sections with provisional interpretation, or rename them to reflect current content:

- §3.4 → “Winner margin evidence”  
- §3.5 → “Evolution story”  
- §3.6 → “Provisional design implications”

Do not let [PENDING] labels dominate the reader’s impression if you can still provide honest provisional content.

## Priority 5: Clean up internal artifacts

Move the build record and output hashes out of the main report or clearly separate them as an audit appendix. The report itself should remain readable by engineers who are not yet familiar with the internal toolchain.

Suggested placement:

- Main report: human-readable evidence and conclusions.  
- Appendix A: figure provenance.  
- Appendix B: artifact hashes and build manifest.  
- Separate file: full builder output, uncited row list, toolchain details.

---

# 17. The single biggest improvement

If only one change is made in v0.22, make it this:

> Add a short decision-oriented summary at the front of the report that says exactly what was searched, what was found, how strong the evidence is, and what cannot yet be concluded.

Suggested block:

> **Summary for decision**
>
> The Kite Turbine Dynamics project has completed a 930-design simulation screen of a 5 kW-class ground-generation rotary kite turbine using a tensile rotary power transmission. The campaign found a feasible candidate with mean power 5.309 kW, airborne mass 25.698 kg, minimum modeled structural FoS 14.972, and least segment torque margin 2.03 at S1. All checked TRPT rings and twist segments remain below their failure boundaries at the final operating point under the current model.
>
> The result supports advancing the winner into blade-structural validation and lifter-modulation work. It does not yet support flight-readiness claims, because blade integrity is not gated, lifter modulation is assumed, launch/recovery are excluded, and atmospheric realism is limited to steady sheared wind. The campaign was a screen, not an exhaustive search, and the current result should be treated as the best feasible candidate in the searched space under the current instrument.

That block would immediately make the report feel like a mature engineering document rather than a draft data package.

---

# 18. Final recommendation

To represent the Kite Turbine Dynamics project better, v0.22 should shift from “here are the numbers” to:

> Here is the design space we searched, here is what survived, here is how we know the instrument is trustworthy, and here is what that means for the next engineering decision.

The report already has the technical substance. The main missing layer is **decision framing**. Add key findings, make the objective and margins explicit, convert the failure ledger into a visible asset, and use figures to show the machine, the search, and the instrument as three connected parts of one project.