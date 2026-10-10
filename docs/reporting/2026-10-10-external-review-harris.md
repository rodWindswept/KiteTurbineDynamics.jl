# External review — Harris (2026-10-10), for the reporting room

**Provenance.** Rod fed the current PDF build (draft `e0abbce`, register v1) into an independent bot (Claude) while in Harris, for commentary. He asks the room to **consider whether or not all of the points raised are relevant or not** — triage, not adopt-everything. Relayed to the repo by aero-worker 2026-10-10.

**Verbatim external record** — the review below is the external bot's text, kept word-for-word. It does not pass the STE gate, same as builder output.

**Reviewer's own summary.** "well-traced internal record" but "not yet a year-3 explanation"; three gaps: (1) printed numbers that contradict each other — do not post until these close; (2) missing content (software, wind speed, validation, outlook); (3) working scaffolding still in the reader text.

---

# Report draft v0.9: feedback for the forum version

- **Draft:** `e0abbce` (`docs/reporting/drafts/2026-10-08-report-first-draft.md`)
- **Build:** 2026-10-10T17:43Z, register v1 at `f86228a`
- **Reviewer:** Claude, for Rod, 2026-10-10
- **Target reader:** a third-year undergraduate engineer. This reader knows statics, beam buckling, rigid-body dynamics, ODE integration, actuator-disc and Betz, and basic optimisation. This reader does not know TRPT, KiteTurbineDynamics.jl, or the team's internal vocabulary.

## Verdict

The draft is a well-traced internal record. Every number traces to a signed row. The failure ledger (§4.2) and the fidelity section (§4.1) are more candid than most reports. Keep both.

It is not yet a year-3 explanation. There are three gaps.

1. **Numbers in the draft contradict each other.** A careful reader can combine values the draft already prints and find conflicts in speed and power, lift margin, and governing margin. Section 1 below lists them.
2. **Most of the brief is still missing.** The brief asks for the work, the software, the results, and the intent and potential. The draft covers the results at one operating point only.
   - It does not name the software.
   - It does not state the wind speed.
   - It does not show the validation.
   - It has no outlook section.
3. **The reader text still carries working scaffolding.** That includes the version log, brackets, row IDs, track names and commit hashes. The STE prose also removes the "because" from every explanation.

**Do not post until section 1 is closed.** Sections 2 and 3 describe the rewrite.

---

## 1. Fix before posting: numbers that do not reconcile

All arithmetic below uses only values printed in the draft.

### 1.1 Speed, load law and power disagree by 31 %

**What the draft says:**

- §2.3 gives τ = k·ω², P = k·ω³, k = 2.24 (NR-015).
- §3.3 gives ω_eq = 10.170 rad/s (NR-016) and P̄ = 5.309 kW (NR-008).

**The arithmetic:**

- 2.24 × 10.170³ = **2.36 kW**, not 5.31 kW.
- The twist figure, panel B, gives segment torque 396.8–397.7 N·m.
- From τ = kω², ω = √(397.2 / 2.24) = **13.32 rad/s** (127 rpm).
- Then τ·ω = **5.29 kW**, which agrees with NR-008.

**Conclusion:** the machine runs at about 13.3 rad/s during the measurement window. NR-016 is the settle speed, and it is 31 % lower.

**Fix:**

- **Report the right speed.** Use the window-mean ground-ring speed as the winner's operating speed (this needs a row). Either drop ω_eq from the results, or keep it with one sentence: "The settle state starts the run at 10.17 rad/s. The machine accelerates to 13.3 rad/s during the 10 s relax."
- **Investigate the gap.**
  - A settle state 31 % below the operating speed is not this machine's equilibrium at this load.
  - Rod's 09-15 ruling says a settle-versus-ODE disagreement is a re-initialisation or load-scaling bug, not a design question.
  - This gap is also a candidate cause of the warm-start rope-break in §4.1. The warm start injects the settle velocities, and the machine then has to spin up by 31 %.
  - One probe settles it: log ω(t) and peak line strain over the relax and the window, for the winner, on both paths.
- **State the units of k.** τ [N·m] = k ω² [rad²/s²], so k is in N·m·s² (equivalently kg·m²).

### 1.2 The lift margin is 1.21×, not 1.5×

**What the draft says (§3.3):**

- The vertical component of the lift tension is 1.5 × machine weight.
- T_lift = 324.1 N at 70° (NR-010, NR-026).
- Airborne mass is 25.698 kg (NR-018).

**The arithmetic:**

- Weight = 25.698 × 9.807 = 252.0 N, so 1.5× weight = 378.0 N.
- 324.1 × sin 70° = 304.6 N, which is **1.21 ×** the weight.
- A 1.5× ratio at this tension would need a 20.7 kg machine.

**A second conflict.** Rod's requirement puts the 1.5× at the sky hook. §3.3 puts it at the lift bearing. The two differ by the weight and angle of the bearing line.

**Fix:**

- State which mass the 1.5 multiplies, and why it is not NR-018.
- State where the vertical component is taken.
- Check that the numbers then give 1.5 by hand. If they do not, the run sized the lift wrongly. That would change the line tensions, and with them every margin.
- Summarise the reason for the factor 1.5 in one paragraph. Rod's requirement document for it is still to be written.

### 1.3 The headline margin is not the governing margin

The abstract-to-be and the conclusion quote FoS 14.972 (NR-009). The twist figure, already in the draft, shows smaller margins:

| Failure mode | Demand | Capacity / limit | Margin | Under the 2.5 gate? | Source |
|---|---|---|---|---|---|
| Ring beam-column, R6 | utilisation 0.067 | 1.0 | 15.0 | yes | NR-021 |
| Segment torque, S1 | 396.8 N·m | 805.0 N·m | **2.03** | ? | NR-023 |
| Twist vs realisability floor, S1 | 33.9° | 72.25° | **2.13** | ? | NR-022 |
| Twist vs δcrit, S1 | 33.9° | 98.9° | 2.92 | ? | NR-022 |
| Line tension vs break | ? | ? | ? | yes | no row (open request) |
| Blade root | — | — | not modelled (∞) | none | §4.3 |

The torque margins on S1–S4 are 2.03–2.05. These are below the stated FoS gate of 2.5.

**Fix:**

- **Torsion and the gate.** Say whether torsional capacity is under the 2.5 gate.
  - If it is, explain how the winner passes.
  - If it is not, say so and say why that is acceptable.
  - The reader will ask about gusts. Under τ = kω², a gust that raises ω by 42 % doubles the torque. Whether line tension rises fast enough to keep pace is the design question.
- **Placement.** Put this margin table in §3.3. Quote the minimum margin, with its failure mode, in the abstract and the conclusion.
- **Twist figure title.** The title says "far below its over-twist limit". It measures against δcrit (98.9°). But δcrit lies beyond the 72.25° realisability floor drawn on the same plot.
  - Measure against the binding limit, which is the lowest of the three.
  - Define all three limits in one table: δcrit, the realisability floor, and the crossing limit δα*. Say which one gates.
- **Definition of NR-009.** Say whether NR-009 is the minimum over the 40 s window and over all members. NR-009 is 14.972, while R6 at the final step (NR-021) is 15.033. That suggests NR-009 is a window minimum and NR-021 a final-step value. Say so.

### 1.4 Ring FoS of 15–35 in a mass-minimising search

A mass optimiser thins the ring tubes until a constraint binds. Rings sitting at FoS 15–35 mean something else is binding. The 09-06 finding was exactly this: FoS 17.2 was an OD-floor artefact.

**Fix:**

- For each ring, state whether the tube is at the OD or wall-thickness floor.
- If it is, the ring FoS is a manufacturing minimum, not a design margin. The text must say so.
- R5 has FoS 326,974. Add one sentence on why (near-zero axial load? a spacer in the cylindrical section?). In the body, write "> 10⁵ (effectively unloaded)".

### 1.5 The design length fails the power floor in the 10-05 screen

The §2.3 bracket reports a length screen run on 2026-10-05. All three lengths failed the power floor, before and after the cp fix:

- 18.8 m (the design length)
- 21.2 m
- 25.0 m

**Fix:** state whether launch commit `a76c5e9` includes the cp fix.

- **If it does not,** the campaign power numbers belong to the old physics. The team's own rule ("void the data, keep the record") voids them until they are re-gated.
- **If it does,** explain why the 18.8 m case failed on 10-05 while the winner passes at 18.8 m. Was it a different genome?

Either way, this cannot stay as an aside in the reader version.

### 1.6 Objective 27.364 kg vs airborne mass 25.698 kg

- §3.2 gives the island-3 best as 27.364 kg (NR-005).
- §3.3 gives the airborne mass as 25.698 kg (NR-018).
- The 1.666 kg gap is never explained.

**Fix:** write the objective as an equation. Itemise everything it adds to the airborne mass: a penalty term, the lift line, a lifter share, or something else.

### 1.7 Numerical damping is not declared

The 09-15 ruling keeps lin_damp only as a declared, pinned numerical stabiliser. The report does not declare it anywhere.

**Fix:** if lin_damp is active at `dd3cc6a`, §4.3 must say four things:

- **Its value and action.** Each step multiplies the non-orbital velocity of every rope node by 0.05, at dt ≈ 29 µs.
- **Its consequence.** It suppresses transverse line dynamics such as waves and snap loads. The FoS and torque margins therefore exclude dynamic line loads.
- **The other dampers.** Declare `bearing_tr_damp` and `ang_damp` with their values.
- **The physical damping.** Cite the Tveide drag model (C_D = 1.0) separately, as the physical line damping.

### 1.8 Ambiguities to remove

| Where | Text | Problem | Fix |
|---|---|---|---|
| §2.3 | "FoS gate of 2.5 on 2.5" | Unreadable | Name both quantities, e.g. "FoS ≥ 2.5 on lines and ≥ 2.5 on ring beams" |
| §2.3, §3.1 | "seed" | Means the RNG seed in §2.3 and the starting genome in §3.1 | Use "RNG seed" and "starting design" |
| §3.3 | "blade scales 0.82 and 0.20" | One active rotor, but two scales | Say what the 0.20 scales, or mark it inactive |
| §3.3 | Bank gene 22° "reaches no rotor"; main rotor bank 7.088° | Where does 7.088° come from? | State the rule that sets the main-rotor bank. State the winner's effective genome dimension. |
| §3.3 | "the cyan line" | A colour from a figure the reader has not seen | Name the line, e.g. "bearing line" |
| §3.3 | "sky anchor, the three-way knot" | Only two of the three legs are described | Name the third leg: the back line. It is taut at the design point: 3 mm Dyneema with sewn bungee sections. Say whether it is modelled. |
| §2.1 | "Bank … about its chord axis" | The standard rotor term is coning angle | "bank (the blade's coning angle out of the ring plane)" |
| Throughout | "reads" | Used as the verb for every value | Use "is" |

---

## 2. Missing content for a year-3 reader

### 2.1 The operating point

The draft never gives the wind speed. Add a table with:

- wind speed at hub height and at reference height
- shear law and exponent
- air density
- turbulence (steady wind?)
- shaft elevation angle
- rotor swept area, both true and projected on the wind
- Cp and tip-speed ratio λ
- window-mean ω

Then add one Betz check: P = ½ρAv³Cp ≤ (16/27)·½ρAv³·cos³β, or whatever form the code uses for the tilted annulus. A student will do this check; do it for them.

Also state that the 0.5 % window swing (NR-014) comes from steady wind. It is not a stability property of the machine.

### 2.2 The design problem as an equation

State the problem directly:

> minimise m(x)
> subject to P̄(x) ≥ 5 kW, FoS_min(x) ≥ 2.5, clearance(x), twist(x), no line break, …

Add a gene table with columns for index, name, symbol, units, bounds and live condition. An example live condition: "slot 8, bank of rotor 2, dead when rotor_count = 1". Without this table, "the winner genome names its genes in the decode fields" means nothing to an outside reader.

### 2.3 TRPT physics, with the equation

The draft asserts that the shaft's "capacity to transmit torque comes from tension itself". Show it.

**Set-up.** Take one segment:

- n lines, each at tension T
- end rings of radii r₁ and r₂
- line length L
- relative twist Δα

**Derivation.**

- Each line runs from (r₁, 0, 0) to (r₂ cos Δα, r₂ sin Δα, h).
- Its tangential force component at the lower ring is T·r₂ sin Δα / L.
- Summing over the n lines gives

  τ = n T r₁ r₂ sin Δα / L, with h² = L² − r₁² − r₂² + 2 r₁ r₂ cos Δα.

**Fixed axial load.**

- With axial load F = nTh/L held fixed, τ = F r₁ r₂ sin Δα / h.
- Because h falls as Δα grows, peak torque sits beyond 90°.
- That is why δcrit is 92.6–98.9°.

Use the exact form in `src/`. If it differs from this, show the code's form and say why.

**Realisability floor.** Explain sin Δα ≤ 1/1.05, which gives 72.25°, and say what the 1.05 represents.

One labelled segment diagram covers all of this. This is the core physics the reader came for, and it is missing.

### 2.4 The load law

- Give the textbook optimal-tracking law: τ = Kω², with K = ½ρπR⁵Cp,max / λ_opt³ (Burton et al.; Manwell et al.).
- Show the closed-form value for this machine (the flagged 3.55) beside the swept value of 2.24. Their ratio is 0.63.
- Say why the closed form overshoots here: the annular rotor, the tilt, or something else.

That turns the "[Closed: selection, not derivation]" bracket into a teaching point.

### 2.5 The sub-models

Give one paragraph and one reference for each sub-model:

- **Rotor aerodynamics:** blade element or not, induction, aerofoil data source, Cp clamp, wake and blocking.
- **Lines:** tension-only, EA, break load, material, Tveide drag with C_D = 1.0.
- **Rings:** tube material, OD and wall, E, and the beam-column interaction N/N_cr + |M|/M_el ≤ 1.
- **Mass:** the blade-mass law with exponent 3.0 (validated).

Then add a winner mass budget that sums to 25.698 kg: rings, lines, blades, bearing, bridles, hardware.

### 2.6 Numerics

- Name the scheme: semi-implicit (symplectic) Euler.
- Give the winner's step: 50.0 s / 1,724,859 steps = 29 µs.
- Explain the step limit. It comes from the stiffest, shortest segment, with dt ∝ √(m/k).
- Keep the implicit-brake paragraph. It is the best explanation in the draft.
- Give the wall-clock time per evaluation.

### 2.7 The search

**State the DE settings:** NP, F, CR, strategy, stopping rule, and migration between islands.

**Population size.** 310 evaluations per island over generations 0–30 implies about 10 designs per generation. The usual guidance is NP = 5–10 × D (Storn & Price), and this genome has about 10 genes.

**What the result supports.**

- All three islands start from one design.
- Islands 1 and 2 end 11.7–12.0 % heavier than island 3.
- That supports this claim: "a 24 % mass reduction from the starting design (36.1 → 27.4 kg), found in 930 evaluations".
- It does not support "an optimum" or "a search over the design space".

Say this in §3.2, and match the title to it.

### 2.8 Validation: the biggest gap

The Daisy April-29 anchor is the only external validation. It appears only in the conclusion, with no numbers.

**Add a validation section** (§3.0 or a new §4) covering:

- the Daisy geometry
- measured versus simulated power against wind speed (212–227 W at 5–8 m/s, from the August calibration)
- the measurement uncertainty
- what was tuned and what was predicted

**State the extrapolation plainly.** The model is checked at about 0.2 kW and used at 5.3 kW, roughly 24 times higher.

**Register the Daisy rows now.** Rod's ruling is that the 5 kW design and the Daisy-scale validation together make the report. The forum post cannot stand on the 5 kW half alone.

### 2.9 The software

The body never names Julia or KiteTurbineDynamics.jl. Add a section covering:

- language, package and repository (with a public URL if it is public), and licence
- a module map, drawn as one block diagram: decoder → builder → settle → ODE evaluator → gates → DE runner
- test suite size and acceptance status at the build commit
- runtime per evaluation, campaign wall-clock time, and hardware
- one command that reproduces the campaign

The register and sign-off workflow deserves half a page: multi-agent drafting, signed rows, and the citation checker. It is unusual, and it is the reason the numbers can be trusted.

### 2.10 Intent and potential

The draft has no outlook section. A year-3 reader wants one page covering:

- **Why rotary over pumping:** continuous power, a ground-based generator, no reel-in phase.
- **What limits a TRPT:** torque capacity ∝ tension × r₁r₂ / L. This is the scaling law the 10–50 kW work depends on.
- **The lifter dependence.**
- **Specific power at this design point:** 5.309 kW / 25.698 kg = 207 W per airborne kg. Label it as a design-point simulation number.
- **Multi-rotor stacking** (rotor_count).
- **The route forward:** Daisy → 5 kW → 10–50 kW.

### 2.11 Off-design

The winner is evaluated at one wind speed and one k. Do one of these:

- **Add a wind sweep:** for example 4–14 m/s on the ODE path at fixed k = 2.24, reporting P̄, ω, minimum margin and twist. The sweep also answers the gust question in 1.3.
- **Or state plainly** that this is a design-point result, not a power curve.

### 2.12 Bow

Rod ruled hub bow to be an output. Report the winner's bow, and whether settle and ODE agree on it.

---

## 3. Presentation

### 3.1 Two builds

Add one flag to the builder so it produces two builds.

**The reader build strips:**

- the v0.1–v0.9 version log
- every [PENDING], [Closed], [Answered] and [Result] bracket
- "the room", Track A–D and @handles
- figure-map and roster numbers
- commit hashes in body text
- inline row IDs

**Row IDs move to an appendix table** with columns for value, units, row, source file and commit. The body cites that table once per section.

**The working build** keeps everything.

### 3.2 Prose

The STE sentence rules strip out causal links. Allow compound sentences joined by "because", "so" and "which". For example:

**Before (§1):**

> A tensile rotary power transmission (TRPT) is a shaft made of tensioned lines. Rings sit apart under tension. Torque passes from ring to ring. The shaft bends and twists without a rigid driveshaft. Its capacity to transmit torque comes from tension itself.

**After:**

> A tensile rotary power transmission (TRPT) replaces a rigid driveshaft with tensioned lines strung between rings. When the upper ring turns ahead of the lower one, every line leans, and the tangential part of its tension turns the ring below. The torque a segment can carry therefore rises with line tension and ring radius and falls with segment length, which is why the lift system matters as much as the rotor.

### 3.3 Jargon

| Draft | Reader version |
|---|---|
| honest window | measurement window (after a 10 s settling period) |
| the instrument | the simulation |
| settle-carried equilibrium | settle state (the initial condition) |
| rapid path / ODE path (`:warm` / `:cold`) | warm start / cold start; code names appear in the software section only |
| gate | constraint (feasibility check) |
| tension-supplied capacity, the fold, the guards | define each one, or drop it (Conclusion) |
| register row, signed | appendix only |

### 3.4 Precision

- Use three significant figures in the body and full precision in the appendix.
- Write "t = 50.0 s", not "49.99999483862295 s".
- Write "FoS 15.0", not "15.033".

### 3.5 Figures

**Missing figures, in priority order:**

1. **System anatomy** (figure-map row 2). Show the lifter, lift line, sky anchor, back line, bearing line, lift bearing, bridles, rotor, rings R1–R6, segments S1–S5, ground station and generator, wind direction, and elevation angle. Label every term from §2.1. Without this figure, a reader cannot follow §2.1 or §3.3.
2. **TRPT segment diagram** with r₁, r₂, L, h, Δα and T. This supports 2.3.
3. **Daisy validation:** measured versus simulated power.
4. **Convergence:** best mass against generation, for all three islands.
5. **Winner tables:** the winner summary and the margin table from 1.3.
6. **Sensitivity tornado** for §3.4. Perturb each live gene ±10 % around the winner on the ODE path, and plot Δmass, ΔP̄ and the change in minimum margin. This costs two runs per live gene.

**Existing figures:**

- **Ring utilisation:**
  - Move it to §3.3 (winner checks). It is not a lever, so it does not belong in §3.4.
  - Utilisations of 0.03–0.07 on a 0–1 axis make the bars slivers, and the bending share is invisible. Add a log axis or an inset.
  - Change "√(M²)" to "√(M_y² + M_z²)".
  - In the caption, change "RN" to "R6".
- **Twist limit:**
  - Move it to §3.3.
  - Remove the changelog lines from the legend: the 2026-08-13 winner at 22,425°, and "the former 90° asin clamp is removed". That history belongs in the failure ledger.
  - The δcrit labels on S1–S4 overlap.
  - Measure the title and the margin against the binding limit (see 1.3).
- **Evolution strip:**
  - At A4 size each panel is about 2 cm wide, and the labels and footer are illegible raster. Give it full width in two rows, or render it as vector.
  - Add the mass under each panel. This needs rows for generations 0, 6, 10, 18, 22 and 25. Without mass, the strip shows seven near-identical machines and tells no story.
  - The shafts are drawn vertical. Either say so, or draw them at the operating elevation.
- **Numbering:** change "Figure (roster row 6)" to "Figure n".

### 3.6 Structure

- Move the lifter assumption and the lift sizing out of §3.3 and into Methods, as boundary conditions.
- Open §3.3 with a winner table: geometry, mass, operating point, power, minimum margin.
- Turn the §4.2 lessons into a table with columns for failure, date, how it was detected, consequence, lesson, and the guard now in the code.

### 3.7 Claims and voice

- **Title.** "A search over its design space" overclaims; the draft itself calls the run "a screen, not a survey". Suggested title: *Simulation-based design screening of a 5 kW kite turbine with tensile rotary power transmission*.
- **Lifter claim.** Remove "The stack sizing is a solved problem" (§3.3). CoaxialAutogyroStacking.jl was idle at the 09-15 review. Write instead: "We impose a lift force at the [bearing / sky anchor]. Designing a lifter that delivers that force across wind speeds is outside this report."
- **Lift tension.** "Its tension stays flat as the wind rises" follows from that assumption; it is not a result. Say so.
- **Voice.** The conclusion switches to first person ("a machine I flew"). Pick one voice for the whole report.
- **Authorship.** Add an authorship line and a short statement of how AI agents were used in the analysis and drafting. Forum readers will ask, and the signed-register process is a strength worth showing.
- **Abstract.** Write it now and update it as the draft changes, so every section serves it.

### 3.8 Fix §4.1 in code before posting

A public report that says the evaluator default "measures the instrument, not the machine" invites an obvious question: why was it not fixed? So:

1. Land the 09-16 ruling in the evaluator: rope-break detection on the measurement window only.
2. Re-run the warm-start probe on the three winners.
3. Rewrite §4.1 as a fixed defect with its lesson.

---

## 4. Target outline (about 20 pages)

| § | Section | Content | Pages |
|---|---|---|---|
| 1 | Introduction | AWE context, rotary vs pumping, what a kite turbine is (Fig 1), aims | 1.5 |
| 2 | The machine | TRPT physics (Fig 2), lift system and back line, rotor, generator load law | 3 |
| 3 | The simulation | Sub-models, numerics, constraints, software architecture, testing, reproducibility | 3 |
| 4 | Validation against Daisy | Measured vs simulated, tuned vs predicted, extrapolation gap | 2 |
| 5 | Design search | Problem statement, genome table, DE set-up | 1.5 |
| 6 | Results | Convergence, winner and margins, sensitivity, evolution, off-design | 4 |
| 7 | Discussion | Warm vs cold start, model boundaries (incl. damping and blades), failure ledger, scaling and potential | 3 |
| 8 | Conclusion | | 0.5 |
| — | Appendices | Nomenclature, number register, reproduction commands | |

---

## 5. Requests to the room

| # | Item | Needed for |
|---|---|---|
| 1 | Window-mean ground-ring ω and torque for the winner (row) | 1.1 |
| 2 | ω(t) and peak line strain over relax and window, warm and cold | 1.1, 3.8 |
| 3 | The mass and location behind the 1.5× lift rule; hand check to 1.5 | 1.2 |
| 4 | Torsional-capacity gate status; minimum line FoS (row) | 1.3 |
| 5 | Per-ring tube size vs the OD and wall floor; R5 load | 1.4 |
| 6 | Whether `a76c5e9` includes the cp-fix commit | 1.5 |
| 7 | Objective definition, with the 1.666 kg itemised | 1.6 |
| 8 | Damper values active at `dd3cc6a` | 1.7 |
| 9 | Wind speed, profile, ρ, elevation, swept area, Cp, λ (rows) | 2.1 |
| 10 | Gene table with bounds and live conditions | 2.2 |
| 11 | Exact torque and twist-limit expressions from `src/` | 2.3 |
| 12 | DE settings | 2.7 |
| 13 | Daisy rows (open since v0.1) | 2.8 |
| 14 | Per-generation best mass, island 3 | 3.5 (evolution strip) |
| 15 | Sensitivity runs (two per live gene) and the wind sweep | 3.5, 2.11 |

## 6. Order of work

1. Close section 1 (items 1–8). Any change to a number re-runs the register sign-off.
2. Land the warm-start rope-break fix (3.8).
3. Register the Daisy rows and write the validation section.
4. Draw Figures 1 and 2. Write 2.3 and the software section.
5. Rewrite the prose for the reader build and strip the scaffolding.
6. Run the sensitivity and wind sweep. Write §3.4–3.6 and the outlook.
7. Write the abstract last, from the margin table and the validation.