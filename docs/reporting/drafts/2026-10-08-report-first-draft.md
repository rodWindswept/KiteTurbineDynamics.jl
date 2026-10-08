# The kite turbine: a search over its design space

**Working title.**

First draft v0.1. Date 2026-10-08. Lead pass by @hermes.

Status DRAFT. Numbers come only from signed register rows, cited by
row ID (NR-001 to NR-018).

A section marked [PENDING] waits on a gate. The owners refine this
text against the Track A and Track B responses.

**Abstract and keywords** [PENDING. The plan writes them last, from
the signed register.]

## 1 Introduction

The wind above tower height is stronger and steadier than the wind a
ground machine reaches. Airborne wind energy (AWE) machines chase that
wind. Two families exist.

Fly-gen machines carry the generator aloft. A conducting tether sends
the power to the ground.

Ground-gen machines keep the generator on the ground. The tether
carries force, and the ground station converts it.

The field splits a second way, on the wing. Soft wings use fabric.
They survive crashes and pack small. Rigid wings use composite
airframes. They hold efficiency and cost more.

No study has crowned a dominant wing design. Both families stay in
play.

A third split matters for this report. It is the transmission. A
pumping machine sends intermittent tension down a moving tether. A
rotary machine sends steady torque down a turning one.

A rotary machine runs continuously. It needs no reel-in phase. That
continuity is where the kite-turbine family sits.

The machine in this report is a kite turbine. Rigid blades ride the
rings of a tensile rotary shaft. The shaft turns the ground generator.

A tensile rotary power transmission (TRPT) is a shaft made of
tensioned lines. Rings sit apart under tension. Torque passes from
ring to ring.

The shaft bends and twists without a rigid driveshaft. Its capacity
comes from tension itself.

This report presents a search over the design space of that machine.
The search varies ring geometry, polygon count, rotor count, bank
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

A line is a tension member. It never pushes. A ring is a polygon of
nodes that holds the rotors. The polygon count names the number of
lines.

The topmost ring carries the main rotor. The lowest ring is the
ground ring. A rotor is a set of blades on a ring.

Bank is the blade angle away from the wind axis. Blade scale sets the
blade size. The search treats each of these as a gene. [Terms await
the Track D glossary.]

### 2.2 The genome

The genome is the design vector. The decoder reads it and builds the
machine.

The genes set the ring geometry, the polygon count, the rotor count,
the bank angles and the blade scales. The winner genome names its
genes in the decode fields (NR-011).

### 2.3 The evaluator

The evaluator builds the machine from the genome, settles it, and
measures it over an honest window. The honest window waits out the
startup transient before it records anything.

The operating point uses a power-law constant k of 2.24, a relax time
of 10 seconds, a window of 40 seconds, a factor of safety (FoS) gate
of 2.5 on 2.5, and a line length of 18.8 metres (NR-015).

FoS is the design load margin. It is the ratio of what the line can
carry to what the load demands. The dynamics run as an ordinary
differential equation (ODE) solver.

### 2.4 The campaign

The campaign runs a differential evolution (DE). A DE keeps a design
population. Each generation breeds new designs from the best. A gate
scores each design and culls the failures.

Three islands run in parallel. An island is an independent population
with its own drift. Each island evaluates 310 designs. The campaign
evaluates 930 designs in total (NR-001).

Four statuses result: ok, reject, clearance_reject and reject_twist
(NR-002).

The ok designs pass every gate. The rejects fail a gate. The
clearance rejects fail the clearance gate. The twist rejects fail the
twist gate. [Gate names and definitions await Track B and Track D.]

### 2.5 Fidelity paths

Two paths score a design. The cold path builds the machine, settles
it, and runs the full ODE. The warm path pre-solves a static state
and starts from it.

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
14.972 (NR-009). Its lift tension reads 324.1 newtons (NR-010).

Its geometry reads three lines, six rings and one active rotor. The
hub radius is 4.580 metres and the ground radius 0.804 metres
(NR-011). Its blade scales read 0.82 and 0.20 (NR-011).

Its bank gene holds 22 degrees in slot 8, but that gene reaches no
rotor at one active rotor. The main rotor bank reads 7.088 degrees at
ring 6 (NR-017).

Its window swing reads 0.029 kilowatts on 5.309 kilowatts, half a
percent (NR-014). Its rotor speed reads 10.170 radians per second
(NR-016). Its airborne mass reads 25.698 kilograms (NR-018).

### 3.4 The levers [PENDING. Landscape Phases 1 to 2 supply this.]

### 3.5 The evolution story [PENDING. Phase 3 and the machine renderer
supply this.]

### 3.6 Design implications [PENDING. Phase 3 and the regime table
supply this.]

## 4 Discussion

### 4.1 Evaluation fidelity

The cold path reproduces every recorded winner field at the precision
the record stores. Island 3 agrees at full precision (NR-012).

The warm path rejects all three winners at the rope-break gate
(NR-013). The warm start injects ring velocities that over-strain a
line past the break limit during the relax run.

The evaluator enables rope breaks across the relax and the window.
The ruling of 2026-09-16 enables breaks on the measurement window
only. The discrepancy remains open.

The lesson stands. The warm path is the evaluator default. Any
consumer that does not pass the cold flag measures the instrument,
not the machine.

### 4.2 The failure ledger

Candidate entries. Each failure enters with its lesson. [Track B will
reconcile these entries.]

- The dead geometry genes. The search proposed genomes that cannot build. Lesson: the decoder must refuse what the builder cannot make, at gate time, not at read time.

- The voided campaigns. We voided a campaign that produced bad data. We did not reuse it. Lesson: void the data, keep the record.

- The k-alignment faults. Two code paths disagreed on the operating constant k. Lesson: one constant, one source file.

- The stale-gate near-miss. A gate check fell behind the model it guarded. Lesson: a gate must pin a measured number, so drift fails the suite.

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

- Register rows for the bank derate values, the exponent included.
- A register row for the rope break limit.
- Register rows for the Daisy anchor values.
- Context values for the levers and implications chapters when Phases
  1 to 3 land.
