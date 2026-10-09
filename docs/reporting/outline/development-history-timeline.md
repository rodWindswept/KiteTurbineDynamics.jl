# Development history timeline: the tool and the method

**Slug** `development-history-timeline`

**Status** PREP v1, chapter seed. **Owner** @author. **Date** 2026-10-08.

**Ask** Rod, 2026-10-08: a chapter that shows how the software itself
developed, and how our solutions for optimising kite turbine forms
developed.

**Contract** the reporting framework and the story skeleton. Companion:
`awe-context-outline.md` for U1. Placement stays open until Rod rules
(section 4).

**Sources** `CHANGELOG.md`, `DECISIONS.md`, the git record,
`docs/TRPT_Optimisation_Monograph.md`, the handovers, the numbers
register, the Phase 0 audit, and the control records
(`docs/plans/2026-06-27-soft-ramp-kmppt-v2.md`,
`docs/gate1-control-map-rerun.md`, `scripts/results/control_maps/`).

**Discipline** dates state chronology. Values attach at production from
signed register rows, by row ID. Cross-era values stay era-tagged or
out.

## 1. The claim of the chapter

A hand built machine became a search problem. The search learned to
reject its own false answers.

Each era crowned a winner. The next era audited it. Wrong answers
voided, and the model tightened every time.

That habit is the credibility of this report. The chapter tells it.

## 2. The acts

### Act 0: before the tool

The Daisy machine is the physical anchor. It flew and it generated.
Its measured blade feeds the current blade mass reference
[CHANGELOG 0.11.0].

The tool exists to search forms beyond the reach of hand design.

### Act 1: scaffold and structural campaigns, March to April 2026

- 2026-03-16: the first commits land the package scaffold, the node
  types, the rope and ring forces, and the multibody ODE. The
  dashboard follows in days.

- 2026-03-18: torsion becomes emergent from rope geometry. The
  analytical torque formula retires [DECISIONS].

- 2026-03-28: the team chooses differential evolution (DE) over
  gradient methods [DECISIONS]. Every campaign after this date runs
  on that choice.

- April: campaigns v2 to v5 [April monograph]. v2 trusts Euler
  buckling alone and returns a shaft that later fails the torsional
  check. v3 adds the torsional gate. v4 restores taper by the
  constant L/r spacing law. v5 couples BEM aerodynamics.

- The lesson line starts here. Each campaign exposes the next missing
  constraint.

### Act 2: network rotors and control, May to July 2026

- May: pitch depower replaces furl [DECISIONS 2026-05-23].

- June: the v6 campaigns bring distributed rotors, tension stiffening,
  and multi start DE with collapse reseeding [CHANGELOG 0.4.0]. v11
  tapers the tether diameters [DECISIONS 2026-06-20].

- The control law matures through June and July.
  The soft-ramp controller plan of 2026-06-27 sets the direction.
  The dashboard RampController ramps the k_mppt gain under structural
  guards to find its sustainable value [CHANGELOG 0.8.0, 0.9.0].

- The control maps arrive next: dynamic k_mppt hunts with
  pre-sweeps across six wind speeds [CHANGELOG 0.9.0].
  The two-flank analysis marks one flank unreachable in dynamics.
  The dP/dk sign check in the RampController watches the power peak.

- 2026-07-05: the map decision lands.
  The control-map re-run hunts maximum power under unregulated
  tracking, not the rated point [docs/gate1-control-map-rerun.md].

- Widened bounds return very light winners that dynamics later rejects
  [CHANGELOG 0.6.0, 0.8.0].

- The v10 family unifies the rotor model and widens the search to 14
  degrees of freedom [CHANGELOG 0.10.0]. One v10 winner later fails a
  dynamic check [CHANGELOG 0.8.0].

- Lesson: cheap static scoring crowns machines that cannot fly.
  The control line adds its own: the operating point is a control-law
  outcome, and the gain belongs to the machine.

### Act 3: the honesty era, August into September 2026

- The windowed evaluators arrive. The honest window lands first, then
  the rapid and ODE paths in report naming [CHANGELOG 0.11.0].

- The evaluator adopts the controller: the ramp evaluator discovers
  the sustainable gain during scoring.
  The dashboard and the evaluator then share one k-selection path.
  The gain is an output of the evaluation, not a genome gene
  [DECISIONS 2026-08-11].

- The blade mass law correction lands. A campaign voids
  [DECISIONS 2026-08-22]. The geometry audit finds dead genes
  [DECISIONS 2026-08-24].

- Rope break physics enters as a gate [DECISIONS 2026-08-14].

- The Daisy anchored seed lands [DECISIONS 2026-08-21].

- The masslift campaign runs three islands. The screen accepts a
  candidate that the envelope check later rejects [item 4 campaign
  summary].

- Lessons: the screen selects, it does not qualify. Every instrument
  fault gets a name and a record.

### Act 4: model convergence and the current dataset, September to October 2026

- The rings are the rotors. The spokes carry tension duty. Blocking
  takes a share of the power [DECISIONS 2026-09-29].

- The bank derate lands. The disc model times the cosine factor
  replaces the banned expansion model [DECISIONS 2026-10-01 and
  2026-10-07].

- The correction forces a 5 kW re-baseline [AGENTS.md].

- The seed folds to the S2 class [DECISIONS 2026-10-05].

- 2026-10-08: the current dataset completes. Phase 0 signs the same
  day [Phase 0 audit, instrument trust log].

### The current dataset, stated honestly

- The run was short. The search stopped after a small generation
  count.

- The sample is small: ten genomes per generation, one island per
  process [NR-001 holds the evaluation count].

- Two islands were still descending at the stop. Their best design
  arrived in the final generation [NR-003, NR-004]. The third island
  stopped improving earlier [NR-005].

- The dataset is a screen, not a survey. The winner is an upper bound,
  not a converged optimum.

- Winner qualification has no record yet for these winners. The
  chapter states the boundary between the screen and the qualifying
  tests plainly.

## 3. The themes

1. **Fidelity bought with breadth.** Early campaigns ran huge numbers
   of cheap evaluations. The current campaign runs few expensive
   honest ones. The trade is a recorded fact [monograph era versus
   NR-001, era-tagged].

2. **Falsification as the method.** Every era crowned a winner, and
   the audit of the next era tested it. Wrong answers voided, and the
   model tightened.

3. **Two stages, always.** Evolution screens. The envelope tests
   qualify. A machine can pass with artificial damping and fail
   without it.

4. **Honesty instruments.** Provenance stamps, the instrument floor
   watch, the trust log. The same culture gates this report through
   the register.

5. **The search space sharpened.** Beam genes went closed form. Dead
   genes got new wiring. Bounds moved as physics landed.

## 4. Placement and terms

Recommendation: a short chapter of its own, after the Introduction and
before Methods. The chapter gives the journey. Methods gives the
machinery.

U3 keeps its own job. It shows the machines of the search generation
by generation. This chapter shows the tool.

The two do not overlap. No figures sit in this chapter. The control-law
figures stay with the figure map, rows 4 and 5. The evolution
strip stays with U3.

Terms to define first, per Track D: DE, generation, island, genome,
screen versus qualify, envelope test, honest window, rapid and ODE,
dead gene, instrument floor, L/r, bank derate. The glossary decides
the exact wording.

## 5. Open items

1. Rod: placement and budget. @hermes: one row in
   `2026-10-08-document-targets.md` when Rod rules.

2. Rod: the meaning of "turbine tests" in the note of 2026-10-08. A
   candidate reading: the qualifying envelope checks for the winners
   of this run. No record of them exists yet.

3. Register rows if the chapter quantifies "short": the generation
   count and the island wall times (the Phase 0 audit holds them).
   The found-generation facts already carry rows NR-003 to NR-005.

4. Reconcile with the Track A and Track B responses when they land.

5. The note of 2026-10-08 says 30 solutions per island. NR-001 holds
   the per island evaluation count. The chapter will state the
   denominators, so "few" carries its number.

## Deltas

- v1 (2026-10-08): seed from the repo record, per the ask of Rod.

- v2 (2026-10-08): the software-ledger handoff from @hermes is logged for the
  Track B fold: the two k-alignment faults (2026-08-13, 2026-08-24), the
  voided campaigns (blade-mass law 2026-08-22; rotorcount doubly void), the
  dead-gene examples (2026-08-14 taper divergence, 2026-08-26 rotor
  off-by-one), and the stale-gate near-miss (FoS floor guard, 2026-08-22).
  The §4.2 entries of the report draft v0.2 carry the same facts.

- v3 (2026-10-08): the control-law lineage folds into Acts 2 and 3
  (soft-ramp controller, control maps, the max-power hunt decision,
  the ramp evaluator), per the room pass of 2026-10-08.
  The sources extend with the control records.
