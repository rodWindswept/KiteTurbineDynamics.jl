# The kite turbine: a search over its design space

Internal engineering report. Draft v0.57. Date 2026-10-16.

Status DRAFT. Data commit `dd3cc6a`. Launch commit `a76c5e9`.
Numbers come only from signed register rows, cited by row ID.

A section marked [PENDING] waits on a gate.

**Draft status.** This is an internal draft.
Sections 3.4 to 3.6 carry their text.
Nomenclature and references stay incomplete.

The physics era is `post-95c385d_wind-authority`. The bank derate
applies throughout.

**Abstract.** This report presents a search for a 5 kW-class
ground-generation rotary kite turbine with a tensile rotary power
transmission (TRPT). The search varies ring geometry, polygon count,
rotor count, blade bank angles and blade scale.

A differential-evolution campaign evaluated 930 candidate designs under
one fixed power-law generator load, each on the measurement window
(NR-001).

The campaign winner is the best feasible candidate under the modeled
objective and gates. Its mean power is 5.309 kW at the site wind,
11.01 m/s at 9.41 m (NR-008, NR-032).

All checked TRPT rings and twist segments operate below their failure
boundaries at the final operating point (NR-021, NR-022).

The minimum factor of safety is 14.972 (NR-009).

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
for steady lift tension across wind speeds remains an assumption.

The search is a screen, not a survey. The report does not claim a global
optimum.

**Keywords.** airborne wind energy, kite turbine, ground-generation,
tensile rotary power transmission, differential evolution, multibody
simulation, design search, factor of safety.

**Summary for decision.** The project completed a 930-design simulation
screen of a 5 kW-class ground-generation rotary kite turbine with a
tensile rotary power transmission (NR-001).

The screen found a feasible candidate under the model and gates.
The key findings follow.

- The differential-evolution campaign evaluated 930 candidate designs (NR-001).

- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).

- The campaign winner is the best feasible candidate under the modeled objective and gates.
  Its mean power is 5.309 kW and its airborne mass 25.698 kilograms (NR-008, NR-018).
  Its minimum factor of safety is 14.972 (NR-009).

- All checked TRPT rings and twist segments operate below their failure boundaries at the final operating point (NR-021, NR-022).
  The least segment torque margin is 2.03, at S1 (NR-040).

- The seed genome scores 36.109 kg-equivalent (NR-006).
  Island 3 reaches 27.364 kg-equivalent (NR-005).

- The ODE path reproduces every recorded winner field (NR-012).
  The rapid path takes the rope-break gate placement fix (NR-013 ext2).

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
The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it.
The power sizing sets the radius for the rotor at its local wind speed (NR-050).

The search treats each of these as a gene. The ring geometry sets the
topmost-ring and ground radii, and the rotor count sets how many rings carry
blades.
The shaft transition cone holds one fixed angle, 22 degrees, by construction.
It is not a search gene (NR-049).

At the top of the shaft the rotor turns in the wind.
The whole shaft turns with the rotor.
The shaft passes the torque from ring to ring.
The lowest ring turns the generator at the ground station.

The shaft works only under tension.
Tension gives the shaft its capacity to transmit torque.
With low tension the shaft bends and twists.
A slack shaft cannot carry the load.

Under the generator load the machine settles onto one operating point.
In the settled state the shaft runs twisted along its length.

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

Two earlier anchors retired.
3.55 was a mass-scaled value with no anchor.
5.39 was the 3-blade anchor chosen on the broken machine.
That load forces about 9 kW from the seed (NR-047).

An earlier round of this study swept the generator gain k on earlier machines.
At the top of that sweep the TRPT shaft entered a destructive resonance.
That round shares no number with this campaign, because the machine and the model differ.

The sweep rows read as follows (NR-047).

Rows k 0.5 to 1.5:

| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |
|---|---|---|---|---|
| 0.5 | reject | 3.49 | 19.14 | 51.8 |
| 1.0 | ok | 5.45 | 17.64 | 47.8 |
| 1.5 | ok | 6.78 | 16.59 | 42.8 |

Rows k 1.94 to 3.0:

| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |
|---|---|---|---|---|
| 1.94 | ok | 7.56 | 15.80 | 40.1 |
| 2.24 | ok | 8.00 | 15.34 | 36.4 |
| 3.0 | ok | 8.89 | 14.42 | 24.3 |

At the light end the seed spins up.
The k 1.0 row settles at omega 17.6, tip about 85 m/s, near the 100 m/s ceiling.
The ceiling is a hard evaluator gate (TIP_SPEED_CEILING_MPS, src/objective_evaluator.jl:103).
The selected k 2.24 settles at omega 15.3, tip about 73 m/s (NR-047).

The power is measured, not computed from a mean speed. The load law reads
tau equals k times omega squared, and drawn power equals k times omega cubed.
The evaluator samples the electrical power at one hertz inside the window. At
each sample it reads the generator torque times the ground-ring speed. The
window mean of those samples is P_mean. The window-mean ground-ring speed is a
separate average (NR-029). The delivered-torque basis (NR-030) is P_mean
divided by NR-029, a derived ratio, not the instantaneous k times omega
squared. The two differ slightly: P_mean 5.309 kW against k times the cube of
NR-029, 5.366 kW, a 1.07 per cent gap. The exact source of the gap is open. It
may come from a slow speed trend across the window, from ground-ring drag, or
from how the instantaneous power is averaged.

At the heavy end the load raises the torque and the line tension, so FoS falls.
The FoS_min column reads 36.4 at k 2.24, down to 24.3 at k 3.0 (NR-047).
The heavy end also carries a score cost.
The objective charges 5 kg-equivalent per excess kW squared above the 5.0 kW ceiling (NR-046).

The load choice also has a structural side.
The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048).
The top-segment helix force reads about 1278 N/vertex (NR-048).
A low-wind lull is harmless under the load law.
The team refuses to ease k as the high-wind substitute.
The rotor spins up to 87.9° of twist against the 78.8° collapse limit (NR-048).

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

The ok designs pass every gate. The rejects fail a gate.
Clearance rejects fail the clearance gate. Twist rejects fail the twist gate.

The campaign minimizes a kg-equivalent objective score: the airborne mass plus the soft constraint penalties.
A lower score is better.
The objective score is not the physical airborne mass.

One kilogram of airborne mass adds 1.0 to the score (NR-046).
The penalty charges read in kg-equivalent.

The score builds along one chain.
The chain runs genome, decoder, builder, evaluator, window statistics, gate status, soft constraint penalties, score and rank.

The score adds three soft constraint penalties to the airborne mass (NR-046):
`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`
with `r = min(twist_ratio, 1)`, plus the stationarity add-on `10.0 * max(0, swing - 0.20)`.

The over-power charge reads P_score, the end power, against the 5.0 kW ceiling (NR-046).
The utilisation charge reads the window-minimum factor of safety against the 2.5 floor (NR-046).
The twist charge reads the worst segment twist ratio against the crossing limit (NR-046).
The stationarity add-on reads the window swing against 20 per cent (NR-046).

Every charge is continuous. None is step-like (NR-046).

Rejected designs carry no score.
The evaluator carries Inf for a rejected design.
The runner stamps the search cost `1e9` on every non-ok design (NR-046).
No reject ranks above an ok design.
The search cannot trade power or safety against mass.

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

The campaign scored every design on the cold path (NR-012).

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

The reject class splits three ways (NR-055).
96 ran below the 5 kW power floor.
Four ran at or above 5 kW with a factor of safety below 2.5.
The cause is not logged for the remaining 201.

Each island starts its population from the same seed genome.
The recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006).
The other members of each population draw at random under a fixed seed per island (scripts/run_v13_5kw_masslift.jl).

This campaign is the first search campaign of the wind-authority era.
Larger and wider campaigns sit ahead.

### 3.2 Convergence

The best recorded objective score on island 1 is 30.578 kg-equivalent at generation 30 (NR-003).
Island 2 reaches 30.637 kg-equivalent at generation 30 (NR-004).
Island 3 reaches 27.364 kg-equivalent at generation 26 (NR-005).
The physical airborne mass of the winner is 25.698 kg (NR-018).
The objective score adds 1.665 kg-equivalent of penalties (NR-039).

The surviving ok designs hold a mean power between 5.02 and 6.32 kW
(NR-007).

### 3.3 The winner

[Figure seated: figure-map row 10 (machine winner, slug `machine-winner-hero`). Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]

Island 3 carries the winner. Its mean power reads 5.309 kW and
its end power 5.314 kW (NR-008). Its factor of safety reads
14.972 (NR-009). That value is the window minimum.

The capture topmost ring
reads 15.033 at the final step (NR-021).

Its operating point reads as follows.

| Quantity | Value | Source |
|---|---|---|
| Mean power, measurement window | 5.309 kW | NR-008 |
| End-of-window power | 5.314 kW | NR-008 |
| Minimum factor of safety | 14.972 | NR-009 |
| Window power swing | 0.029 kW | NR-014 |
| Settle angular speed | 10.170 rad/s | NR-016 |
| Window-mean speed | 13.38 rad/s | NR-029 |
| Delivered torque | 396.76 N·m | NR-030 |
| Airborne mass | 25.698 kg | NR-018 |
| Topmost ring radius | 4.580 m | NR-011 |
| Ground radius | 0.804 m | NR-011 |
| Ring count | 6 | NR-011 |
| Polygon count | 3 | NR-011 |
| Active rotors | 1 | NR-011 |
| Main-rotor bank, ring 6 | 7.088 deg | NR-017 |
| Lift-line elevation | 70 deg | NR-026 |
| Lift-line tension | 324.1 N | NR-010 |
| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |
| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |
| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |
| Ring speed ratio | 5.566 | NR-031 |
| Tip-speed ratio | 6.8415 | NR-032 |

Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).
The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058).
The machine held a steady operating point through the measurement window.

The settle state starts the machine at 10.170 rad/s (NR-016).
The machine accelerates through the relax run.

The shaft axis bows off its design line, sagging straight down under gravity.
At the midpoint ring the bow reads 0.002 m at settle, and
0.105 to 0.310 m through the measurement window (NR-059).
The maximum sits at the hub and reads 0.209 to 0.613 m through the window (NR-059).

An extension run past the window ends at 0.422 m at the midpoint
and 0.833 m at the hub (NR-059).
Every state at the midpoint ring reads below the 1.5 m line (NR-059).

The settle hands off a straight stack while the run bows it.
The two do not agree on the bowed shape.
The disagreement reads as an instrument finding, not a design question (NR-059).

Its window-mean speed reads 13.38 rad/s, 127.772 rpm (NR-029).
Its airborne mass reads 25.698 kilograms (NR-018).

The swept area reads 45.9733 square metres raw and 39.4912 square
metres on the wind-normal basis (NR-033). The air density reads
1.225 kilograms per cubic metre (NR-034).

The rotor Cp reads from the AeroDyn v5.0.0 blade element momentum
(BEM) table: 0.2944 at the ring speed ratio, and 0.2258 at the
tip-speed ratio (NR-031, NR-032).

The Betz ceiling reads 19.1304 kW, and the winner delivers 27.75 per
cent of it (NR-034).

The winner clears each checked gate.

| Gate | Threshold | Winner outcome | Margin | Source |
|---|---|---|---|---|
| Power floor | 5.0 kW | pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent | NR-008, NR-027, NR-039 |
| Structural FoS floor | 2.5 | pass, 14.972 minimum. 14.972 on 2.5, margin +12.472 / +498.9 per cent, 5.99 times | NR-009, NR-015 |
| Clearance | blade-tip gate | pass, 5.468 m, margin +3.968 m | +264.5 per cent, 3.65 times | NR-042 |
| Twist | per-segment limit δcrit | pass, all five segments within limit | Least margin at S1. It reads +64.913 deg / +65.7 per cent, 2.91 times | NR-022 |
| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |
| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |

The gate set reads per class. The structural members and the lines
hold a factor of safety of 2.5 or higher (NR-015).

Torsion keeps its own criteria. The collapse factor of safety reads
1.5 or higher, and the twist stays within the crossing limit (NR-052).

The realisability floor reads 72.25 degrees (NR-053). As run, the
2.5 gate does not cover torsion (NR-052).

A lifter kite holds the machine aloft. The lifter gives lift only. It
gives no torque and no drive.

Its load path runs from the lifter kite down the lift line to the sky
anchor, the three-way knot. Then it runs down the cyan line to the lift
bearing, and down the lifting bridles to the main rotor.

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
Without modulation, each weather band would need its own single kite.
That kite would reach giant sizes and be too hard to handle.

The report applies the lift force the machine needs and tests the
machine on that basis. Designing a lifter that delivers that force
across wind speeds is outside this report. The report states the
presumption as one (2026-08-05).

The report also assumes a staged launch of the stack.
A staged launch is easier to handle than one giant kite.

Its geometry reads three lines, six rings and one active rotor. The
topmost ring radius is 4.580 metres and the ground radius 0.804 metres
(NR-011).

The winner genome contains two blade-scale slots.
The main-rotor slot, `blade_scale_top`, reads 0.82 and decodes to the single active rotor.
The second-rotor slot, `blade_scale_bottom`, reads 0.20 and stays inactive
because the rotor count is one (NR-011).

The winner genome contains two bank-angle slots. Ring 6 decodes the
active main-rotor bank angle as 7.088 degrees (NR-017).

The second bank slot holds `bank_bottom`. It reads 22 degrees at the top of its search box.
It does not decode to a physical rotor at a rotor count of one (NR-011, NR-017).

This result differs from earlier eras for recorded reasons. The bank
derate, the measurement window and the tightened gates moved the search
space. Numbers across the eras would compare models, not machines.

The three movers carry their records. The bank derate is a
calculated depowering of the main-rotor disc (NR-019, NR-020).
The window basis sits at section 2.2.2, and the gate set at
section 2.4.

| Era | Effect on the search space | Data status |
|---|---|---|
| Before the bank derate | Earlier winners read different bank-angle physics, so they are not directly comparable. | Superseded as era record. |
| The bank-derate basis | The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). | Current campaign basis. |
| The cp fix and the folded class | The span shrink and the cp fix moved the screen readings. The pre-fold rows failed the floor (NR-027). | Recorded: the folded class passes at 18.8 metres (NR-028). |
| The wind-authority era (`post-95c385d_wind-authority`) | One wind authority reads the scored results. | Current physics era. |

This run also trades breadth for fidelity: fewer evaluations, each on
the measurement window. It stopped early: a screen, not a survey.
This report covers the wind-authority era campaign and the recorded
corrections that shaped it.

### 3.4 The levers of Performance

[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]

[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]

The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021).
The window-minimum factor of safety is 14.972 (NR-009).
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
The next steps add the blade checks and the gust cases.

[Figure seated: figure-map row 20 (the levers landscape, slug `pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.]

[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]

[Figure seated: figure-map row 23 (the corner machines, slug `machine-corner-grid`). Values cite NR-044 and NR-051.]

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
The topmost ring radius is 4.580 m and the ground radius is 0.804 m.
The blade scales read 0.82 and 0.20 (NR-011).
The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017).

The shaft transition cone holds one fixed angle, 22 degrees,
in every machine of the campaign (NR-049).
A later campaign can vary it.

The strip shows built geometry and the search objective only.
The strip prints no power value and no airborne mass value.
The trace reads one island of the campaign.
It does not prove a global optimum.
A longer or broader run would extend the search.

### 3.6 Design implications

The record supports four implications.

First, the searched TRPT family contains a compact feasible candidate under the modeled objective and gates.
The winner produces 5.309 kW of mean power with an airborne mass of 25.698 kilograms (NR-008, NR-018).

Second, the winner holds large structural and twist margins at the final operating point.
The window-minimum factor of safety is 14.972 (NR-009).
The least segment torque margin is 2.03, at S1 (NR-040).
The margins suggest room for further mass reduction.
Any reduction waits on blade integrity and lifter validation.

Third, future searches should treat clearance as a design constraint in its own right.
The status mix reads 110 clearance_reject designs (NR-002).
Future searches can steer away from low-clearance geometry with a clearance map or a shaped penalty.

Fourth, part of the winner genome stays inactive at one active rotor (NR-011, NR-017).
Conditional genes can improve the search efficiency without changing the machine problem.

The implications hold under the modeled objective and gates.
They do not prove an optimal gene set.

Recommended next steps:

1. Use the rapid path for screening under its fixed rope-break gate (NR-013 ext2).

2. Add blade root factor-of-safety checks to the structural gate set.

3. Validate lifter modulation across the wind bands.

4. Extend the wind cases beyond the steady sheared profile.

5. Extend the model to the launch and recovery sequence.

6. Extract the lever statistics from the campaign telemetry.

7. Re-run a short campaign with conditional genes and a clearance-aware decoder.

## 4 Discussion

### 4.1 Evaluation fidelity

The ODE path reproduces every recorded winner field at the precision
the record stores. Island 3 agrees at full precision (NR-012).

The rapid path once rejected all three winners at the rope-break gate
(NR-013). The cause was gate placement, not the machine.

The rapid start injects ring velocities from the static pre-solve.
The evaluator ran the rope-break gate across the relax run as well as
the window. The injected transient over-strain tripped the gate at once.

The team has solved this pattern twice on record. On 2026-08-14 the
rule was: the check judges only real operation. The settle transients
must not break healthy machines.

On 2026-09-16 the ruling was: breaks on the measurement window only,
with break detection off during the relax. The fix here is the same
pattern applied to the evaluator.

The fix has landed. The evaluator arms the
rope-break check at the relax boundary (NR-013 ext2). Detection runs
on the measurement window only.

The fix removes false rejections. It never allows breaks.
A rope break in the measurement window always rejects the design.
No design passes with a broken rope at its operating point.

The lesson stands. The rapid path is the evaluator default. Any
consumer that does not pass the cold flag measures the instrument, not
the machine.

Every healthy winner reads reject on the default path. Pass the cold
flag, and every recorded winner field reproduces (NR-012).

### 4.2 The failure ledger

Candidate entries. Each failure enters with its lesson.

| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at k_mppt 10.0, the 50-kilowatt default gain. That gain is about five times the scaled system's own gain, near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the topmost ring. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |

- The dead geometry genes. The search proposes genomes that cannot
build. An off-by-one in the rotor-to-ring map put the middle rotor on
the topmost ring (2026-08-26).

  An inverted-taper genome diverged within seconds, while the ground
  instruments still read normal power (2026-08-14).

  Lesson: the decoder must refuse what the builder cannot make, at gate
  time.

- The voided campaigns. A later finding can break a model or a
geometry. The data from before it then counts no more.

  The blade-mass-law correction landed on 2026-08-22. It voided the
  campaign winners. The rotorcount data was doubly void: it predated
  the FoS fix, and its rotors sat one ring toward the top.

  Superseded is the milder class, not void. The pre-derate campaign
  stands as era record, because the bank derate moved the search space.

  Lesson: void the data, keep the record.

- The k-alignment faults. Twice, a check ran at a different generator
gain than the machine it scored.

  On 2026-08-13 the evaluator ran 5 kW designs at k_mppt 10.0, the
  50 kW default gain. That gain is about five times the scaled system's
  own gain, near 1.94. The window power read roughly double. An
  acceptance test caught it.

  On 2026-08-24 a winner re-gate ran at a stale gain, the superseded
  20-second-window value. The pre-push review caught it. The re-gate at
  the campaign gain returned 5.18 kW.

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

The report screened 930 rigid-wing ground-generation rotary kite turbine designs with a tensile rotary power transmission (NR-001).
The campaign scored each design on the ODE path over the measurement window (NR-015).
One fixed power-law generator load and one fixed gate set held for every design (NR-015).

The search found 508 feasible candidates in the searched space (NR-002).

The 301 rejects split three ways (NR-055).
96 ran below the 5 kW power floor.
Four ran at or above 5 kW with a factor of safety below 2.5.
The cause is not logged for the remaining 201.

The best performing one had a mean power of 5.309 kW.
Its airborne mass is 25.698 kilograms (NR-008, NR-018).
Its window-minimum factor of safety is 14.972 (NR-009).
All checked TRPT rings and twist segments operate below their failure boundaries at the final operating point (NR-021, NR-022).
The least segment torque margin is 2.03, at S1 (NR-040).

The result shows that a compact TRPT machine can satisfy the power, clearance, twist and structural gates in simulation.
That result holds under the modeled load and wind.
It does not show flight readiness, a global optimum, or full structural safety.
Blade integrity is not yet gated, and lifter modulation remains an assumption.
The rapid path takes the rope-break gate placement fix (NR-013 ext2).

The Daisy anchor ties the model to a measured flight reference.

The next work closes the model gaps.
Add blade structural checks and validate lifter modulation.
Extend the model to the launch and recovery sequence.
Extend the wind cases beyond the steady sheared profile.
The large structural margins suggest room for mass reduction, once those checks hold.

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
| Structural margin | Window-minimum factor of safety 14.972. The checked ring utilisations stay below the failure boundary. | §3.3, §3.4 | NR-009, NR-021 |
| Twist and torque margin | All five segments stay inside their over-twist limits. The least segment torque margin is 2.03 at S1. | §3.4 | NR-022, NR-040 |
| Search improvement | The search improved the best objective from the common seed to the winner. It reads 36.109 to 27.364 kg-equivalent. | §3.2 | NR-003 to NR-006 |
| Instrument fidelity | The cold path reproduces the recorded winner fields. The rapid path once rejected all three winners at the rope-break gate. The placement fix has landed. | §4.1 | NR-012, NR-013 ext2 |
| Model boundaries | Blade integrity is not gated. The report assumes lifter modulation. Launch and recovery sit outside this report. Gusts and turbulence are not modelled. | §4.3 | PRD 0006:147, assumptions |

## Appendix: Figure provenance

One row per built exhibit. All eight read dataset commit `dd3cc6a`.

| Exhibit | Source extract | Cited rows | Script commit | Era |
|---|---|---|---|---|
| Ring utilisation plate | `pair-extract-2026-10-08-winner-ops` | NR-021 | `1af63fc` | `post-95c385d_wind-authority` |
| Twist limit plate | `pair-extract-2026-10-08-winner-ops` | NR-022, NR-023 | `1af63fc` | `post-95c385d_wind-authority` |
| Machine evolution strip | `strip-extract-2026-10-09-best-so-far` | NR-005, NR-006, NR-011, NR-036 | `74cfef9` | `post-95c385d_wind-authority` |
| System anatomy plate | `scratch/fig1_decode_winner.jl` · `best_vector.csv` | NR-011, NR-017, NR-043 | `9241b23` | `post-95c385d_wind-authority` |
| Levers landscape | `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv` | NR-001, NR-005, NR-006, NR-044, NR-045 | `e23f226` | `post-95c385d_wind-authority` |
| Parameter atlas | `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{1,2,3}/telemetry.csv` | NR-001, NR-005, NR-006, NR-044 | `e23f226` | `post-95c385d_wind-authority` |
| Machine winner | `strip-extract-2026-10-09-best-so-far` · `pair-extract-2026-10-08-winner-ops` | NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |
| The corner machines | `corner-grid-extract-2026-10-15-picks` | NR-044, NR-051 | `a4b4057` | `post-95c385d_wind-authority` |

**Output hashes (SHA-256).** The short labels name the exhibit files.
`png`, `svg` and `pdf` are the file types. `ledger` is the label
ledger. `checks` is the check log.

Ring utilisation plate:

- `png` `bfc744008aafe755679b7f45e543147654a654b002f5c4a70d0ea871bab94ef3`
- `svg` `ce3dee1282941a71819c4a23125a141b84f6fca4611803f8b8a0d8590b33fab6`
- `pdf` `3548ecd3552940c48e1727756c6b8f40d2bd148b3f98874fbe1c87d0a3f71611`
- `ledger` `8cd86f6954590122ee44dca167c24a65df272a85adf9a2726df8ae1d7b437f9d`

Twist limit plate:

- `png` `14f6b8b286d1f8e53a85e4a9072c936267eff530dbc44c0f385e8e05dce68069`
- `svg` `cc3edf9cb255d7687f1c81ee5be3ad69167a0f7d8323266dcc5e8662f46dca28`
- `pdf` `5618f35b01ef4cb4831099ba2bf5fab12a169c337e5687ca22d7f49d6fe071e5`
- `ledger` `7b40b2f6edcc2efcfac9f645ee417b299042a9375b4cfce923a4da56c26d10ae`

Machine evolution strip:

- `png` `8e9d1d40684b984059601f31d5fb2daed8f835f6f8184a716280f8cd779e1cb6`
- `svg` `6c36b0ff1de3b664dac23f8c754481d7a844e7d24d60488e87e6d0a90246d59e`
- `pdf` `6ce4daba18e3972e5284f7a813aff91be723ee9816deac5f113cfc1eb30a2844`
- `checks` `b8c654ea55b26f97a03c7fc6acd1049300bda5c188a972136e7eb12ce2c94bde`

System anatomy plate:

- `png` `696be723993c708b038e0d1e10b96e83ba357a65cb2442580b1de371dedf8c66`
- `pdf` `c55bd7a888a1f3d657445460a9e6bebb05504efe04d4194661b3ae8f1a844d4c`
- `ledger` `bed029d0f36a4e3b218510fc16fe5debf294b65413f64aa2abcafbfdc6ae4912`
- `checks` `99e81f32e1dbc3882a9a63400dac0a4410b3be618d29365b6633886a3aeec31a`

Levers landscape:

- `png` `4b1bd3453a6aa20d9b9b0af75eb989212b16df8986c752766edd625ae13d9892`
- `svg` `94d518bb13c604d4949f9c1011845050d150c4122a357449a8e185f506ae48dc`
- `pdf` `712e918b0b6ac73335ef2355113f59a2f3c6f63a421407ee122c98cfa6a2ecd7`
- `ledger` `91282957dd23b9a9919756e9db578404497e1f0a58d11c4824a7550ad5a91c5e`

Parameter atlas:

- `png` `1e46b70ae65f5557d23bb1a78ab7a75fdc2550a712ac9b2652d31562c67096e8`
- `svg` `28c032cf27c7412c9e76e0d756967143b7201c1ec4b6fe819498f40fe2021b9c`
- `pdf` `aede4d29da694a23e9af14c0ccb72f1932bf09a23b61adcf2095391c69a375b8`
- `ledger` `d3a2bcb1208db0bf0a4e5eb061620d9e73e99e776dc091dd26c067a2324d6f76`

Machine winner:

- `png` `fae022131b198ac7f523d83521c4723b619ae3c70f7edb83acb3f222835d82e6`
- `svg` `0101b58fcfb9b8fe95cc7fedf6e80f944742e02048ff7ec2f9e444df1c45b993`
- `pdf` `1689506ae8bf99a824a5c8f0b542309a933485830879514c4a6ac6bd0fd580ce`
- `checks` `31cda877e9131e6f34270ffe8bdb62bd50225d9cc34653ed221a899eae81e962`

The corner machines:

- `png` `517a77bf032bec1c0cde4eea7db93fdbc47470c65c9d76e6c4e58249436a2568`
- `svg` `b2e4055d39b7ff72d1e10ea11f59d3bbc8af145ef8a30dc83b7016530b4de0b2`
- `pdf` `298a0f8e4e674dc8e13b64715ee0dfd383e7671d9f3c262a376abe7d5b5114c6`
- `checks` `e6bcfca931d36089dd2a8d6e9c8414fb49230c0d2110717176cf1e0ae385ffbe`
