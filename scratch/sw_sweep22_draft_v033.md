# The kite turbine: a search over its design space

Internal engineering report. Draft v0.33. Date 2026-10-14.

Status DRAFT. Data commit `dd3cc6a`. Launch commit `a76c5e9`.
Numbers come only from signed register rows, cited by row ID.

A section marked [PENDING] waits on a gate.

**Draft status.** This is an internal draft.
Sections 3.4 to 3.6 await the Phase 1 to 3 interpretation.
Nomenclature and references stay incomplete.

The physics era is `post-95c385d_wind-authority`. The bank derate
applies throughout.

**Abstract.** This report presents a search for a 5 kW-class
ground-generation rotary kite turbine with a tensile rotary power
transmission (TRPT). The search varies ring geometry, polygon count,
rotor count, blade bank angles and blade scale.

A differential-evolution campaign evaluated 930 candidate kite turbine
designs under one fixed power-law generator load, each on the measurement
window (NR-001).

The campaign winner is the best feasible candidate kite turbine under the
modeled objective and gates. Its mean power is 5.309 kilowatts at the
site wind, 11.01 m/s at 9.41 m (NR-008, NR-032).

All checked TRPT rings and twist segments operate below their failure
boundaries at the final operating point (NR-021, NR-022).

The minimum factor of safety is 15.0 (NR-009).

At the winner operating point, the least segment torque margin is
2.03, at S1, the first of the five segments between the rings (NR-040).
The margin is torque capacity over the segment torque it carries, and the
least value governs.

All numbers are in the repo and
come from the physics era `post-95c385d_wind-authority`, with the bank
derate applied. The bank derate is a calculated depowering of the ring
output, because banked blades sweep less streamtube frontal area.

The study is simulation-only. Blade integrity is not yet gated, and the
outer stiffening bridles sit outside the model.

Lifter kite modulation
for steady lift tension across wind speeds remains an assumption. The
rope-break gate placement fix stays open.

The search is a screen, not a survey. The report does not claim a global
optimum.

**Keywords.** airborne wind energy, kite turbine, ground generation,
tensile rotary power transmission, differential evolution, multibody
simulation, design search, factor of safety.

**Summary for decision.** The project completed a 930-design simulation
screen of a 5 kW-class ground-generation rotary kite turbine with a
tensile rotary power transmission (NR-001).

The screen found a feasible candidate under the model and gates.
The key findings follow.

- The differential-evolution campaign evaluated 930 candidate designs (NR-001).

- Of the 930, 508 designs pass every gate and 422 fail one gate (NR-002).

- The campaign winner is the best feasible candidate under the modeled objective and gates.
  Its mean power is 5.309 kilowatts and its airborne mass 25.698 kilograms (NR-008, NR-018).
  Its minimum factor of safety is 15.0 (NR-009).

- All checked TRPT rings and twist segments operate below their failure boundaries at the final operating point (NR-021, NR-022).
  The least segment torque margin is 2.03, at S1 (NR-040).

- The seed genome scores 36.109 kg-equivalent (NR-006).
  Island 3 reaches 27.364 kg-equivalent (NR-005).

- The ODE path reproduces every recorded winner field (NR-012).
  The rapid path awaits its rope-break gate fix (NR-013).

The report shows that a feasible 5 kW-class candidate exists in the
searched space under the model and gates.

It does not show flight readiness, a global optimum, or full structural
safety. Blade integrity, lifter modulation, launch and recovery, and
atmospheric realism remain open work items.

## 1 Introduction

The wind above tower height is stronger and steadier than the wind
exploited by traditional wind turbines. Airborne wind energy systems
(AWES) are kite-based machines that chase that stronger wind.

Two families of AWES exist.

Fly-gen machines carry the generator and turbine aloft. A conducting
tether sends the electrical power to the ground.

Ground-gen machines keep the generator on the ground. The tether
carries force, and the ground station converts tether motion to
electrical power.

The field splits a second way, on the wing.

Soft wings use fabric. They survive crashes and pack small.

Rigid wings use composite airframes. They are more efficient and more
costly.

A third split matters for this report. It is the force transmission of
ground-gen systems.

A pumping (yo-yo) machine sends intermittent tension down a moving
tether. A rotary machine sends steady torque down a turning set of
tethers.

A rotary machine runs continuously. It needs no reel-in phase. That
continuity is where the kite-turbine family sits.

The machine in this report is a kite turbine.

Kite turbines exploit multiple, short rigid blades. The blades sit on a
ring and form a wide diameter rotor.

The rotor and further rings tie together as a tensile rotary shaft.
The shaft turns the ground generator.

A tensile rotary power transmission (TRPT) is a shaft made of
tensioned lines. Rings sit at fixed distances under tether tension.
Torque passes from ring to ring, over multiple tethers.

The TRPT shaft is prone to bending and twisting, especially in low
tension. It is not a rigid driveshaft. Its capacity to transmit torque
comes from the tension in the kite lines.

This report presents a search over the design space of kite turbines.
The search varies ring geometry, polygon count, rotor count, blade bank
angles and blade scale.

The objective is to find the feasible geometries for a 5 kW-class
machine, and then characterise them.

The generator load law and the
safety gates stay fixed. The search asks whether one compact machine
can hold the power, mass, structural, clearance and twist constraints
at once.

The report reads the gate and the winner outcome for each
constraint in the results.

The report states what the record supports. It also states several
classes of failure in developing this system, each with its lesson.

One frame holds throughout. The machine flies only in simulation. The
analysis pipeline is the instrument. The report treats the instrument
with the same distrust it treats the machine.

The field context rests on the literature.

Loyd showed that both crosswind modes share one theoretical power
ceiling.

Diehl set the classification axes.

Trevisi built one power model for both modes and found the glide-ratio
flip.

Cherubini mapped the ground-gen and fly-gen taxonomy.

Van der Burg found no dominant wing design. Both wing families stay in
play. Van de Kaa and Kamp found no dominant generation architecture.

Pereira ranked the design factors and found that many small units
beat few large ones.

Flather recorded the rope-drive physics that the TRPT descends from.
Benhaïem and Schmehl analysed the torque path of a rotating reel.

Ranneberg gave the rotary family a momentum frame with flight data.

Tulloch modelled the Daisy TRPT and checked the model against measured
flight windows. This report extends that line of work.

## 2 Methods

### 2.1 The kite turbine and its terms

A line is a tension member, like a tether or a bridle. It carries a load
only in tension. A pull at one end passes along the line to the other end.
It never pushes.

A ring is a polygon of nodes and tubular beams. A ring with blades works
as a rotor.

Rings without blades work as line spacers. They hold the TRPT lines
apart against the line torsion from torque transfer. Holding the lines
apart is what preserves torque transmission and prevents torsional
collapse.

The polygon count names the number of lines (n_Lines). A hexagonal
polygon connects six lines. Each line meets the ring at one vertex.

For an active rotor, the polygon count equals the blade count. It also
equals the number of TRPT line attachments around the ring. A rotor is
a set of blades on a ring. A pentagonal rotor carries five blades.

Inactive genome slots may hold bank or blade-scale values. They do not
create physical blades unless the rotor count selects them.

The topmost ring carries the main rotor. The lowest ring is the ground
station power take-off (PTO) ring. The PTO ring anchors the shaft at the
ground and turns about its central axis.

Bank is the blade angle away from the ring plane about its chord axis at
the ring. The equivalent term in AeroDyn is pre-cone.

Blade scale sets the blade size. The scale multiplies the blade span
and chord, and the blade mass follows the span cubed.

The search treats each of these as a gene. The ring geometry sets the
hub and ground radii, and the rotor count sets how many rings carry
blades.

[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]

### 2.2 The simulation analysis pipeline instrument and its terms

#### 2.2.1 The gene

The search uses differential evolution (DE) to assess kite turbine
design variants. DE assesses machine genomes. A genome is a design
vector that describes the physical character of one machine.

The decoder reads it, and the builder builds the machine from it. The
evaluation then feeds the comparison before DE tries a new gene.

The genes set the ring geometry, the polygon count, the rotor count,
the bank angles and the blade scales. The winner genome names its genes
in the decode fields (NR-011).

[Systems block diagram requested: figure-map row 19 (the simulation
analysis pipeline instrument). Gate: the pipeline schema extract.]

#### 2.2.2 The evaluator

The builder builds the machine from the genome. The evaluator runs the
machine and measures its performance. Every evaluation has two phases:
a relax run and a measurement window.

The run starts from a settle state. That state comes from a simplified
power balance (NR-025). The relax run takes 10 seconds. It lets the
startup transient decay, and the machine moves to its operating point.

The measurement window takes 40 seconds. It measures the settled
machine. The evaluator scores the power over the measurement window
only (NR-015).

A short window can sample the decay and misstate the power. The team
sized the window to outlast the decay.

The generator load follows a power law. The commanded torque reads
τ = k·ω², so the drawn power reads P = k·ω³. The constant k sets the
load, and the load sets the speed at which the machine settles.

The operating point uses a power-law constant k of 2.24 N·m/(rad/s)², a
relax time of 10 seconds, a window of 40 seconds, a factor of safety
(FoS) target and hard floor, both 2.5, and a line length of 18.8
metres (NR-015).

The campaign fixed k at 2.24 N·m/(rad/s)² for every candidate design
(NR-015). One load applies to the whole search.

The team selected the value in a load sweep of the seed machine
(2026-08-22). The sweep ran the seed at a range of loads, each over the
same measurement window.

At the light end the seed reads under the power floor. At the heavy end
the power levels off. The selected value sits in the working range
between them.

The campaign also fixed the shaft length. The search does not vary it:
every candidate runs at one length, 18.8 metres (NR-015).

The length follows the Daisy anchor. It scales with the machine to this
size. It sets how high the machine stands above the ground station.

A longer shaft reaches stronger wind. The length screen ran 2026-10-05
on the pre-fold island-3 winner.

It covered 18.8, 21.2 and 25.0 metres, twice, before and after the cp
fix. All six rows failed the power floor (NR-027).

The cause is recorded. The screen measured the pre-fold winner under
the post-landing decode, whose span shrink took the power below the
floor. The folded class passes at 18.8 metres (NR-028).

The campaign searched the folded class, so the launch carries the
passing physics.

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

### 2.4 The campaign

The campaign runs a differential evolution (DE). A DE keeps a design
population. Each generation breeds new designs from the best. A gate
scores each design and culls the failures.

Three islands run in parallel. An island is an independent population
with its own drift. Each island evaluates 310 designs.

The campaign evaluates 930 designs in total (NR-001).

Four statuses result: ok, reject, clearance_reject and reject_twist
(NR-002).

The ok designs pass every gate. The rejects fail a gate. The
clearance rejects fail the clearance gate. The twist rejects fail the
twist gate.

The campaign minimizes a kg-equivalent objective score: the airborne mass plus the gate penalties.
A lower score is better.
The objective score is not the physical airborne mass.

The differential-evolution campaign fixed the configuration below.

| Setting | Value | Source |
|---|---|---|
| Islands | 3 | NR-001 |
| Designs per island | 310 | NR-001 |
| Evaluations, total | 930 | NR-001 |
| Objective | Airborne mass + penalties, kg-equivalent | NR-036, NR-039 |
| Power floor | 5.0 kW | NR-027, NR-039 |
| Structural FoS floor | 2.5 | NR-015 |
| Relax run | 10 s | NR-015 |
| Measurement window | 40 s | NR-015 |
| Load constant k | 2.24 N·m/(rad/s)² | NR-015 |
| Line length | 18.8 m | NR-015 |

### 2.5 Fidelity paths

Two paths score a design. The ODE path builds the machine, settles it,
and runs the full dynamics over the measurement window.

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
Each island starts its population from the same seed genome.
The recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006).
The other members of each population draw at random under a fixed seed per island (scripts/run_v13_5kw_masslift.jl).

### 3.2 Convergence

The best recorded objective score on island 1 is 30.578 kg-equivalent at generation 30 (NR-003).
Island 2 reaches 30.637 kg-equivalent at generation 30 (NR-004).
Island 3 reaches 27.364 kg-equivalent at generation 26 (NR-005).
The physical airborne mass of the winner is 25.698 kg (NR-018).
The objective score adds 1.665 kg-equivalent of penalties (NR-039).

The surviving ok designs hold a mean power between 5.02 and 6.32
kilowatts (NR-007).

### 3.3 The winner

Island 3 carries the winner. Its mean power reads 5.309 kilowatts and
its end power 5.314 kilowatts (NR-008). Its factor of safety reads
15.0 (NR-009). That value is the window minimum.

The capture hub
ring reads 15.033 at the final step (NR-021).

Its operating point reads as follows.

| Quantity | Value | Source |
|---|---|---|
| Mean power, measurement window | 5.309 kW | NR-008 |
| End-of-window power | 5.314 kW | NR-008 |
| Minimum factor of safety | 15.0 | NR-009 |
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

Its window swing reads 0.029 kilowatts on 5.309 kilowatts, half a
percent (NR-014).

The settle state starts the machine at 10.170 radians per second
(NR-016). The machine accelerates through the relax run.

Its window-mean speed reads 13.38 radians per second, 127.772
revolutions per minute (NR-029). Its airborne mass reads 25.698
kilograms (NR-018).

The winner clears each checked gate.

| Gate | Threshold | Winner outcome | Source |
|---|---|---|---|
| Power floor | 5.0 kW | pass, P_mean 5.309 kW | NR-008, NR-027, NR-039 |
| Structural FoS floor | 2.5 | pass, 15.0 minimum | NR-009, NR-015 |
| Clearance | blade-tip gate | pass | NR-036 |
| Twist | per-segment limit δcrit | pass, all five segments within limit | NR-022 |
| Rope break | none on the window | pass on the cold path | NR-012, NR-013 |

A lifter kite holds the machine aloft. The lifter gives lift only. It
gives no torque and no drive.

Its load path runs from the lifter kite down the lift line to the sky
anchor, the three-way knot. Then it runs down the cyan line to the lift
bearing, and down the bridles to the main rotor.

In the field the lifter launches first. It lifts the rig into tension.
The rotor turns after that.

The lift acts throughout operation, not only at spin-up. The team
sizes the lift line up front.

The lifter sizing holds a 1.5 margin on the vertical load at the lift
bearing. The sizing mass is the airborne mass without the lifter
itself, 20.698 kilograms. The kite carries its own weight (2026-08-21
ruling).

The vertical load is 1.5 × 20.698 × 9.81 = 304.6 newtons. The lift line
runs at 70 degrees of elevation (NR-026). The line tension is that
load over sin 70 degrees: 324.1 newtons (NR-010).

The lifter is a stack of autogyros. The report assumes the stack can
modulate to meet the lift requirement at all wind speeds.
A fixed kite cannot: its pull grows as the square of the wind speed.
Without modulation, each weather band needs its own kite, up to a giant.

The report applies the lift force the machine needs and tests the
machine on that basis. Designing a lifter that delivers that force
across wind speeds is outside this report. The report states the
presumption as one (2026-08-05).

Its geometry reads three lines, six rings and one active rotor. The
hub radius is 4.580 metres and the ground radius 0.804 metres
(NR-011).

The winner genome contains two blade-scale slots. Slot 1 reads 0.82 and
decodes to the single active rotor. Slot 2 reads 0.20 and stays inactive
because the rotor count is one (NR-011).

The winner genome contains two bank-angle slots. Ring 6 decodes the
active main-rotor bank angle as 7.088 degrees (NR-017).

A second bank slot reads 22 degrees. It does not decode to a physical
rotor at a count of one (NR-011).

This result differs from earlier eras for recorded reasons. The bank
derate, the measurement window and the tightened gates moved the search
space. Numbers across the eras would compare models, not machines.

This run also trades breadth for fidelity: fewer evaluations, each on
the measurement window. It stopped early: a screen, not a survey.
This report covers the wind-authority era campaign and the recorded
corrections that shaped it.

### 3.4 The levers

[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]

[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]

The hub ring R6 governs the structural check at the winner operating point (NR-021).
The window-minimum factor of safety is 15.0 (NR-009).
At the final step, R6 reads 15.033 (NR-021).
R2 to R4 read 29.8 to 35.2 (NR-021).
R5 carries almost no load in the checked beam (NR-021).

The ground ring sits on ground support and stays outside the ring check.
All five TRPT segments remain inside their over-twist limits at the winner operating point (NR-022).
S1 to S4 transmit 33.5 to 33.9 degrees against a 98.9 degree limit (NR-022).
S5 transmits 22.8 degrees against its 92.6 degree limit (NR-022).
The least segment torque margin is 2.03, at S1 (NR-040).

S5 carries the largest segment torque margin, 2.69 (NR-040).
The winner is not close to ring buckling, over-twist or segment torque saturation at this operating point.
The margins are conditional.
They cover the checked TRPT rings and segments only.
They do not yet include blade integrity or lifter loads across wind bands.

[Figure seated: figure-map row 20 (the levers landscape, slug `pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.]

[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]

The two plates map the same search in two views.
They project the 930 designs of the campaign onto the first two
principal components of the ten-gene search (NR-001).
Those axes hold 22.4 and 17.3 per cent of the variance in the search,
39.7 per cent together (NR-044).

The horizontal axis is PC1 — blade scale against unit count.
Its inset reads larger main-rotor blades, wider ring spacing and a wider ground ring to the right.
It reads more TRPT lines and more rotors to the left.
The top loadings read -0.5385 for the TRPT line count, -0.5222
for the rotor count and +0.5180 for the main-rotor blade scale (NR-044).

The vertical axis is PC2 — second-rotor and clustering settings.
Its inset reads a deeper second-rotor bank, smaller second blades and
rings biased toward the ground upward.
It reads even rings, a shallow second bank and larger second blades downward.
The top loadings read +0.5621 for the second-rotor bank, -0.5605
for the second-rotor blade scale and -0.5018 for the ring density profile (NR-044).

The colour is the mean search objective in each cell, in kg-equivalent.
Bright reads lower, and only feasible designs shade the field.
The low-objective cells gather toward the upper right, where the winner sits.

Three lines trace the island best-so-far paths, one step per generation (NR-045).
Each island ran 31 generations.
All three start at the common seed, 36.109 kg-equivalent (NR-006).
Island 3 reaches the winner value, 27.364, at generation 26 and holds
it to the end (NR-005).
Islands 1 and 2 finish lower in the field.

The atlas repeats the projection ten times, once per gene slot.
Each panel colours the mean value of one gene across the field.
The star marks the common seed and the diamond marks the winner.
The atlas lets a reader follow one gene at a time across that ground.

The two plates fix the search frame.
They show where the search went, how light the designs get and how
each gene tracks across that ground.
The gene-level effects wait on the landscape extracts.

### 3.5 The evolution story

[Figure seated: figure-map row 9 (machine evolution strip, slug `machine-evolution-strip`). Values cite NR-005, NR-006, NR-011 and NR-036.]

The machine evolution strip traces the search on island 3 from the common seed to the campaign winner (NR-036).
The objective falls from 36.109 kg-equivalent at generation 0 to 27.364 kg-equivalent at generation 26 (NR-036).
The largest recorded drop falls between generations 0 and 6, from 36.109 to 32.293 (NR-036).
The final recorded step reads 28.315 to 27.364, a drop of 0.951 (NR-036).

The winner value is the search objective, not a mass reading.
The objective reads the airborne mass 25.698 kg plus 1.665 kg-equivalent of penalties (NR-018, NR-039).

The final panel matches the register winner.
The panel reads three lines and six rings (NR-011).
The hub radius is 4.580 m and the ground radius is 0.804 m.
The blade scales read 0.82 and 0.20 (NR-011).
The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017).

The strip shows built geometry and the search objective only.
The strip prints no power value and no airborne mass value.

### 3.6 Design implications [PENDING. Phase 3 and the regime table supply this.]

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

- The model does not simulate launch or recovery.
  Each run starts with the machine already aloft at its operating point.
  The full launch sequence and the recovery are outside this report.

  The lift system must also carry the machine during hoisting, after a TRPT break and in high wind.
  The record does not quantify those cases.

- The campaign wind is steady and sheared.
  Its speed rises with altitude on the site wind profile.
  The profile comes from wind measured at the Daisy machine.
  Gusts and turbulence do not occur in a scored run.
  The wind direction stays fixed.
  The scored profile is a base case, not a full weather envelope.

## 5 Conclusion

The work runs a differential-evolution search over the design space of a rigid-wing ground-generation rotary kite turbine.
The machine uses a tensile rotary power transmission.
The campaign scores each design on the ODE path.
The measurement window stands behind every number.

The campaign found the best feasible candidate in 930 evaluations (NR-001).
The winner survives the full window.
Its power reads 5.309 kilowatts and its factor of safety 15.0 (NR-008, NR-009).
At the winner operating point, the least segment torque margin is 2.03, at S1 (NR-040).

The result shows that a compact TRPT machine can satisfy the power, clearance, twist and structural gates in simulation.
The large structural margins suggest room for further mass reduction.

The Daisy anchor ties the model to a measured flight reference.

The conclusion is conditional on the model.
Blade integrity is not yet gated.
Lifter modulation remains an assumption.
The rapid path awaits its rope-break gate fix (NR-013).

The next steps add blade structural checks, validate lifter modulation and complete the levers and implications sections.
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

## Document control

The version history, the working notes, the open requests to the
analysis room and the seat notes sit in `docs/reporting/draft-tracker.md`. This document
carries only reader-facing material.

The title stays a working form pending the founder decision.

## Appendix: Claims and evidence

The table ties each headline claim of this report to its evidence and its signed register rows.

| Claim | Evidence | Report location | Register rows |
|---|---|---|---|
| Campaign scale and status mix | 930 designs. The status mix reads 508 ok, 301 reject, 110 clearance_reject and 11 reject_twist. | §3.1 | NR-001, NR-002 |
| Winner power | Mean power 5.309 kW over the measurement window. | §3.3 | NR-008 |
| Winner mass | Airborne mass 25.698 kg. | §3.3 | NR-018 |
| Structural margin | Window-minimum factor of safety 15.0. The checked ring utilisations stay below the failure boundary. | §3.3, §3.4 | NR-009, NR-021 |
| Twist and torque margin | All five segments stay inside their over-twist limits. The least segment torque margin is 2.03 at S1. | §3.4 | NR-022, NR-040 |
| Search improvement | The search improved the best objective from the common seed to the winner. It reads 36.109 to 27.364 kg-equivalent. | §3.2 | NR-003 to NR-006 |
| Instrument fidelity | The cold path reproduces the recorded winner fields. The rapid path rejects all three winners at the rope-break gate. | §4.1 | NR-012, NR-013 |
| Model boundaries | Blade integrity is not gated. The report assumes lifter modulation. Launch and recovery sit outside this report. Gusts and turbulence are not modelled. | §4.3 | PRD 0006:147, assumptions |

## Appendix: Figure provenance

One row per built exhibit. All four read dataset commit `dd3cc6a`.

| Exhibit | Source extract | Cited rows | Script commit | Era |
|---|---|---|---|---|
| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `eacf073` | `post-95c385d_wind-authority` |
| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `eacf073` | `post-95c385d_wind-authority` |
| Machine evolution strip | `strip-extract-2026-10-09-best-so-far` | NR-005, NR-006, NR-011, NR-036 | `74cfef9` | `post-95c385d_wind-authority` |
| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `9cecee3` | `post-95c385d_wind-authority` |

**Output hashes (SHA-256).** The short labels name the exhibit files.
`png`, `svg` and `pdf` are the file types. `ledger` is the label
ledger. `checks` is the check log.

Ring utilisation plate:

- `png` `6f19832088375b96cdc566aff596ccd548f26b629b9782bc56d8831d03c622ba`
- `svg` `ec0f4b96f3fa9b646183e1f7004a0e5d8ce0f9ab28f111472d4ed32ffa0c6b58`
- `pdf` `508b3a641fde21b582ee2a58a3d3df2a769998281f78c8763ba07438286c1f8f`
- `ledger` `c040fca2dd63df9c68b56a767ccd0383962db479b04d75d23821b311628ce099`

Twist limit plate:

- `png` `7ff5c05cc0caa0890400fec50a9366397a203b891031fa400d9638872d0b4501`
- `svg` `ffac9c1eba5386fe79d3c1f5a69afdfadafaba507adaf47963a1b2ddd669d472`
- `pdf` `d207343460263fde7481c8be1572e797895db488f7828b35d14a09003436d4a1`
- `ledger` `6dfbd6eae0285a55475cd8cfe365e92bb9a6137d5e4da23f469634c58d1f1c28`

Machine evolution strip:

- `png` `8e9d1d40684b984059601f31d5fb2daed8f835f6f8184a716280f8cd779e1cb6`
- `svg` `6c36b0ff1de3b664dac23f8c754481d7a844e7d24d60488e87e6d0a90246d59e`
- `pdf` `6ce4daba18e3972e5284f7a813aff91be723ee9816deac5f113cfc1eb30a2844`
- `checks` `b8c654ea55b26f97a03c7fc6acd1049300bda5c188a972136e7eb12ce2c94bde`

System anatomy plate:

- `png` `f1c322bc20068299651bea7978bde254991b4037bf02fe689a15e1e3297a09ea`
- `pdf` `9beffb6bf8463d39a5808164630d04d8c286184a4990a083296e7fc6d512f2cf`
- `ledger` `b250c1a187132f68c37747b70f3d6081eb89e677ba378b12e6eb14b8a05a2389`
- `checks` `0e857cbfb288ff7110aafec99c11211bae1c46e4d3b2a5594d5949f318d9f279`
