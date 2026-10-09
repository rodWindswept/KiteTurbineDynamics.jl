# The kite turbine: a search over its design space

**Working title.**

First draft v0.1. Date 2026-10-08. Lead pass by @hermes.

v0.2 revision pass by @author (2026-10-08). This pass folds the fact
deliveries from the room into the marked brackets. Numbers still gate on
signed rows.

v0.3 pass by @author (2026-10-08). This pass closes the k bracket and
corrects the NR-016 read.

v0.4 pass by @author (2026-10-09). This pass folds the margin-note
set: figure requests mapped to figure-map rows, the builder and
evaluator split, the load law, the lift spec and the search
determinism.

v0.5 pass by @author (2026-10-09). This pass seats the winner-check
pair at §3.4 (figure-map rows 6 and 7) and closes the plate
citations.

Status DRAFT. Numbers come only from signed register rows, cited by
row ID.

A section marked [PENDING] waits on a gate. The owners refine this
text against the Track A and Track B responses.

**Abstract and keywords** [PENDING. The plan writes them last, from
the signed register.]

## 1 Introduction

The wind above tower height is stronger and steadier than the wind a
tower mounted wind turbine reaches. Airborne wind energy systems (AWES) are machines that chase that stronger
wind. Two families of AWES exist.

Fly-gen machines carry the generator aloft. A conducting tether sends
the electrical power to the ground.

Ground-gen machines keep the generator on the ground. The tether
carries force, and the ground station converts it.

The field splits a second way, on the wing. Soft wings use fabric.
They survive crashes and pack small. Rigid wings use composite
airframes. They hold efficiency and cost more.

No study has crowned a dominant wing design. Both families stay in
play.

A third split matters for this report. It is the force transmission of
ground-gen systems.

A pumping (yo-yo) machine sends intermittent tension down a moving
tether. A rotary machine sends steady torque down a turning set of
tethers.

A rotary machine runs continuously. It needs no reel-in phase. That
continuity is where the kite-turbine family sits.

The machine in this report is a kite turbine.

Kite turbines exploit short rigid blades. The blades sit on a ring and
form a wide diameter rotor.

The rotor and further rings tie together as a tensile rotary shaft.
The shaft turns the ground generator.

A tensile rotary power transmission (TRPT) is a shaft made of
tensioned lines. Rings sit apart under tension. Torque passes from
ring to ring.

The shaft bends and twists without a rigid driveshaft. Its capacity to transmit torque
comes from tension itself.

This report presents a search over the design space of that machine.
The search varies ring geometry, polygon count, rotor count, blade bank
angles and blade scale. It states what the record supports. It also
states the failures, each with its lesson.

One frame holds throughout. The machine flies only in simulation. The
analysis pipeline is the instrument. The report treats the instrument
with the same distrust it treats the machine.

The field context rests on the literature. Loyd showed that both
crosswind modes share one theoretical power ceiling. Cherubini mapped
the ground-gen and fly-gen taxonomy.

Diehl set the classification axes. Trevisi built one power model for
both modes and found the glide-ratio flip.

Van der Burg found no dominant wing design. Van de Kaa and Kamp found
no dominant generation architecture.

Pereira ranked the design factors and found that many small units
beat few large ones.

Flather recorded the rope-drive physics that the TRPT descends from.
Tulloch modelled the Daisy TRPT and checked the model against
measured flight windows.

Benhaïem and Schmehl analysed the torque path of a rotating reel.
Ranneberg gave the rotary family a momentum frame with flight data.
[Bind every name to references.bib at assembly.]

## 2 Methods

### 2.1 The machine and its terms 

A line is a tension member, like a tether or a bridle. It never pushes.

[Term-set diagram requested: figure-map row 2 (system anatomy). Gate:
Track D display forms.]

A ring is a polygon of nodes and tubular beams. A ring with blades works
as a rotor.

Rings without blades work as spacers. They hold the lines of the TRPT
apart against the line torsion from torque transfer.

The polygon count names the number of lines.

The topmost ring carries the main rotor. The lowest ring is the
ground ring. A rotor is a set of blades on a ring.

Bank is the blade angle away from the ring plane about its chord axis at the ring. 
Blade scale sets the blade size. The search treats each of these as a gene. [Terms await
the Track D glossary.]

### 2.2 The genome

The genome is the design vector. The decoder reads it. The builder
builds the machine.

[Genome visual requested: figure-map row 3 (genome decode strip).
Gate: the room ruling on need.]

The genes set the ring geometry, the polygon count, the rotor count,
the bank angles and the blade scales. The winner genome names its
genes in the decode fields (NR-011).

### 2.3 The evaluator    

The builder builds the machine from the genome. The evaluator settles
the machine and measures performance over an honest window. The honest
window waits out the startup transient before it records.

[Design-family visual requested: figure-map row 11 (design family grid).
Gate: the family names.]

The generator load follows a power law. The commanded torque reads
τ = k·ω², so the drawn power reads P = k·ω³. The constant k sets the
load, and the load sets the speed at which the machine settles.

The operating point uses a power-law constant k of 2.24, a relax time
of 10 seconds, a window of 40 seconds, a factor of safety (FoS) gate
of 2.5 on 2.5, and a line length of 18.8 metres (NR-015).

The campaign fixed k at 2.24 (NR-015), the value selected in the
honest-window sweep (2026-08-22). [Clamp margin: no check recorded
yet. A derived row or a drop ruling awaits the room.]

[Closed 2026-10-08: selection, not derivation. The circulating closed
form no longer holds. Its product, 3.55, stays flagged non-operating in
every provenance file.]

[Answered: the length variants ran 2026-10-05 on the then-current
winner. The test covered 18.8, 21.2 and 25.0 m, twice, before and after
the cp fix.]

[Result: all three lengths fail the power floor in that screen. No line
breaks, no twist crossing, tip clearance OK. Register rows await
(@science-validator) if §2.3 names the screen.]

FoS is the design load margin. It is the ratio of what the line can
carry to what the load demands. The model tests the TRPT beam element FoS for buckling risk the same
way.

The dynamics run as a coupled multibody model. Every node, line and
ring carries state. The evaluator holds the whole set as one matrix of
ordinary differential equations (ODEs).

The evaluator advances that matrix at a fixed step. The scheme is
semi-implicit. Each step advances the velocities before the positions.

The generator brake torque enters implicitly. Read from the last step
alone, the load law is positive feedback.
Take a ground ring that runs a little fast: the brake pushes too hard,
and the next step over-corrects, so the swing grows.

The implicit form solves the brake with the new speed, so the step
stays stable. The evaluator derives the step per machine from the
shortest shaft sub-segment.

The run is deterministic by construction. That determinism is what
makes reproduction possible.

The search carries the same property. The campaign runner fixes one
random seed per island (scripts/run_v13_5kw_masslift.jl). The same
code and configuration then repeat the search.

NaN and Inf clamps guard the state. A broken line ends the run.

[Step-ceiling and protocol values: NR-024 and NR-025 carry the rows.
Counter-read pending (@science-validator).]

### 2.4 The campaign

The campaign runs a differential evolution (DE). A DE keeps a design
population. Each generation breeds new designs from the best. A gate
scores each design and culls the failures.

Three islands run in parallel. An island is an independent population
with its own drift. Each island evaluates 310 designs.

The campaign evaluates 930 designs in total (NR-001).

[Context: 930 is the scale for this campaign. Earlier eras ran larger
and cheaper campaigns. The development-history chapter states the
trade, tagged by era.]

Four statuses result: ok, reject, clearance_reject and reject_twist
(NR-002).

The ok designs pass every gate. The rejects fail a gate. The
clearance rejects fail the clearance gate. The twist rejects fail the
twist gate. [Gate names and definitions await Track B and Track D.]

### 2.5 Fidelity paths

Two paths score a design. The ODE path builds the machine, settles it,
and runs the full dynamics over the honest window.

The rapid path pre-solves a static state and starts from it.

The report names map to the code. The ODE path is `:cold`. The rapid
path is `:warm`.

The probes that compare the paths sit in
scripts/probe_rapid_vs_ode_winners.jl and
scripts/probe_warm_reject_cause.jl. The register header pins their
commits.

### 2.6 Reproducibility

Every dataset carries a provenance stamp. The stamp names the
commit, the physics era and the geometry fingerprint. The report
names the commits in the register header.

The dataset sits at data commit dd3cc6a on the bankderate2-results
branch. The launch commit is a76c5e9. The Phase 0 audit sits at
master 31ca00d.

## 3 Results

### 3.1 The search at scale

The campaign evaluated 930 designs (NR-001). The status mix reads 508
ok, 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).
All three islands start from one seed. The seed scores 36.109
kilograms (NR-006).

### 3.2 Convergence

Island 1 reaches 30.578 kilograms at generation 30 (NR-003). Island 2   
reaches 30.637 kilograms at generation 30 (NR-004). Island 3 reaches
27.364 kilograms at generation 26 (NR-005).

The surviving ok designs hold a mean power between 5.02 and 6.32
kilowatts (NR-007).

### 3.3 The winner

Island 3 carries the winner. Its mean power reads 5.309 kilowatts and
its end power 5.314 kilowatts (NR-008). Its factor of safety reads
14.972 (NR-009).

A lifter kite holds the machine aloft. The lifter gives lift only. It
gives no torque and no drive.

Its load path runs from the lifter kite down the lift line to the sky
anchor, the three-way knot. Then it runs down the cyan line to the lift
bearing, and down the bridles to the main rotor.

In the field the lifter launches first. It lifts the rig into tension.
The rotor turns after that.

The lift acts throughout operation, not only at spin-up. The team
sizes the lift line up front.

At the lift bearing, its vertical component carries 1.5 times the
weight of the machine. The line runs at 70 degrees of elevation
(NR-026). Its tension stays flat as the wind rises, with margin.

The sizing excludes the weight of the lifter. The kite carries itself.
Its lift tension reads 324.1 newtons (NR-010).

Its geometry reads three lines, six rings and one active rotor. The
hub radius is 4.580 metres and the ground radius 0.804 metres
(NR-011). Its blade scales read 0.82 and 0.20 (NR-011).

Its bank gene holds 22 degrees in slot 8, but that gene reaches no
rotor at one active rotor. The main rotor bank reads 7.088 degrees at
ring 6 (NR-017).

Its window swing reads 0.029 kilowatts on 5.309 kilowatts, half a
percent (NR-014). Its settle-carried equilibrium speed (ω_eq) reads
10.170 radians per second (NR-016). Its airborne mass reads 25.698 kilograms (NR-018).

[Winner anatomy: figure-map row 10 carries the labelled render, with
the lift chain and the ring numbers. The PTO station sits outside the
render scope.]

This result differs from earlier eras for recorded reasons. The bank
derate, the honest window and the tightened gates moved the search
space. Numbers across the eras would compare models, not machines.

This run also trades breadth for fidelity: fewer evaluations, each on
the honest window. It stopped early: a screen, not a survey. The
development-history chapter carries the trade, tagged by era.

### 3.4 The levers [PENDING. Landscape Phases 1 to 2 supply this. Figures: figure-map row 8. The ring and twist plates seat below.]

[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]

[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]

### 3.5 The evolution story [PENDING. Phase 3 and the machine renderer
supply this.]

### 3.6 Design implications [PENDING. Phase 3 and the regime table
supply this.]

## 4 Discussion

### 4.1 Evaluation fidelity

The ODE path reproduces every recorded winner field at the precision
the record stores. Island 3 agrees at full precision (NR-012).

The rapid path rejects all three winners at the rope-break gate
(NR-013). The cause is gate placement, not the machine.

The rapid start injects ring velocities from the static pre-solve.
The evaluator runs the rope-break gate across the relax run as well as
the window. The injected transient over-strain trips the gate at once.

The team has solved this pattern twice on record. On 2026-08-14 the
rule was: breaks only during real operation. The settle transients
must not break healthy machines.

On 2026-09-16 the ruling was: breaks on the measurement window only,
with break detection off during the relax. The fix here is the same
pattern applied to the evaluator.

Until it lands, the discrepancy stands. The evaluator enables rope
breaks across the relax and the window. The ruling enables them on the
window only.

The lesson stands. The rapid path is the evaluator default. Any
consumer that does not pass the cold flag measures the instrument, not
the machine.

Every healthy winner reads reject on the default path. Pass the cold
flag, and every recorded winner field reproduces (NR-012).

### 4.2 The failure ledger

Candidate entries. Each failure enters with its lesson.

[Track B will reconcile these entries. The failure-ledger timeline
(scoped in the figure map) sets these dates end to end. The
development-history chapter carries them act by act.]

- The dead geometry genes. The search proposes genomes that cannot
build. An off-by-one in the rotor-to-ring map put the middle rotor on
the hub (2026-08-26).

  An inverted-taper genome diverged within seconds, while the ground
  instruments still read normal power (2026-08-14).

  Lesson: the decoder must refuse what the builder cannot make, at gate
  time.

- The voided campaigns. A later finding can break a model or a
geometry. The data from before it then counts no more.

  The blade-mass-law correction landed on 2026-08-22. It voided the
  campaign winners. The rotorcount data was doubly void: it predated
  the FoS fix, and its rotors sat one ring toward the hub.

  Superseded is the milder class, not void. The pre-derate campaign
  stands as era record, because the bank derate moved the search space.

  Lesson: void the data, keep the record.

- The k-alignment faults. Twice, a check ran at a different generator
gain than the machine it scored.

  On 2026-08-13 the evaluator ran 5-kilowatt designs at the 50-kilowatt
  default gain. The scaled system gain sat near 1.94. The window power
  read roughly double. An acceptance test caught it.

  On 2026-08-24 a winner re-gate ran at a stale gain, the superseded
  20-second-window value. The pre-push review caught it. The re-gate at
  the campaign gain returned 5.18 kilowatts.

  A misaligned gain scores a different machine, and the data voids.
  Lesson: one constant, one source file.
  [2.24 holds a register row (NR-015). The other values need rows
  first.]

- The stale-gate near-miss. The FoS floor gate fell behind the model it
guarded.

  The FoS=Inf exploit fix landed in one scoring path only. The
  mass-minimum objective and the older fitness functions never received
  the guard. The campaign ran through them unguarded (2026-08-22).

  Telemetry shows no surviving design carried the infinite value. That
  is a near-miss, not a corrupted dataset. Lesson: a gate must pin a
  measured number, so drift fails the suite.

### 4.3 Model boundaries

The report states these boundaries plainly. They are part of the
valid-science case, not footnotes.

- The model does not check blade integrity. The blade root factor of safety sits at infinity in the model. The team deferred the full beam-on-supports blade model (PRD 0006:147). The rotor blades are not yet structurally gated in this analysis.

- Flown blades carry tether-to-blade bridling that resists thrust and expansion better than the unbridled model assumes. That bridling also adds drag. The model does not include it.

## 5 Conclusion

The work runs a design search on a kite turbine and reports only what
the record supports. The honest window stands behind every number.

The winner survives the full window. Its power reads 5.309 kilowatts
and its factor of safety 14.972 (NR-008, NR-009). The search found it
in 930 evaluations (NR-001).

The Daisy anchor keeps the model honest to a machine I flew and
measured. The tension-supplied capacity, the fold and the guards
record the engineering that made the search possible. [Track D will
define each term.]

The boundaries in the discussion name the work that comes next.
[Daisy values need register rows before the final report quotes
them.]

## 6 Nomenclature [PENDING. Track D ratifies the glossary.]

## 7 References

Seeded in references.bib. Fifteen of eighteen sources verified. Three
source calls pending: Ranneberg EK_FT_0018, the Jamieson deck and the
Hancock deck.

## 8 Data availability and reproducibility

The dataset commits to the repo at dd3cc6a on bankderate2-results.
The launch commit is a76c5e9. The Phase 0 audit sits at master
31ca00d. The fidelity probes sit on the bank-derate-cos2p65 branch.

Every figure will ship with its generating script and its data
commit. Every public post will cite register rows by ID.

## Open requests to the analysis room

- Bank-derate rows: landed (NR-019, NR-020).

- A register row for the rope break limit.

- Register rows for the Daisy anchor values.

- Length-screen rows: blocked on the variant dirs entering tracking
(the 10-05 record). @science-validator signs once committed.

- Step-ceiling, protocol and lift-margin rows: NR-024 to NR-026, signed
by @aero-validator, counter-read pending (@science-validator).

- Context values for the levers and implications chapters when Phases
1 to 3 land.
