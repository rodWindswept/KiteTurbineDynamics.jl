# AWE-context outline: where the TRPT kite turbine fits

**Slug** `awe-context-outline`

**Status** PREP v1, draft for the room. Numbers-free by construction: no
measurement or model values and no register row citations. Register v1
waits for signatures.

**Owner** @author. **Co-owner** @science-writer: the explainer layer grows
from this document.

**Contract** the reporting framework (unit U1, the Introduction) and the
room boot handover. **Grounding** the `awe-knowledge` wiki and its paper
corpus. Every claim below traces to a wiki page or a corpus file, named
in the anchor table. Nothing here comes from recall.

**Gate** @science-validator reads this against the wiki when U1 reaches
draft prose. A claim this outline cannot trace gets cut before it reaches
the page.

## 1. Purpose

This document seeds U1, the opening chapter. It settles three things: the
axes for the landscape story, the place of the TRPT kite turbine on those
axes, and the literature anchors behind each claim.

`@science-writer` draws the teaching explanations from this material.
`@author` shapes the final prose in the first-person voice of Rod.

One rule holds from here on. Numbers come only from signed register rows.
This document needs none. It describes architecture and mechanism, not
quantity.

## 2. The landscape: two established axes, plus one

The field sorts along two established axes. A third axis matters here,
because it separates the kite turbine from the ground-gen mainstream.

### Axis A: the generation site

**Fly-gen.** The generator flies. Onboard turbines harvest the apparent
wind, and a conducting tether carries electricity to the ground. Makani
built the canonical machines.

The company shut down, and its intellectual property carries a public
non-assertion pledge. Fly-gen makes power continuously while the machine
flies.

**Ground-gen.** The generator stays on the ground. The tether carries
force, and the ground station converts it. Ampyx, SkySails, Kitepower and
EnerKíte built the mainstream of this family.

Their method is the pumping cycle: reel out under load, reel in
depowered, repeat. The output is intermittent by construction.

The founding analysis from Loyd shows both modes reach the same
theoretical ceiling for crosswind power. The choice between them is not
raw power. It is where the mass flies, what the tether carries, and
whether the output is continuous.

The literature measures the trade. Flying mass cuts ground-gen power,
because it lowers tether tension. Fly-gen tolerates mass better, and pays
with conducting-tether complexity.

A unified power model covering both modes traces the split further. At
low glide ratio, the balance can flip.

### Axis B: the wing

**Soft wings.** Fabric sails, either leading-edge inflatable or ram-air.
They survive crashes, pack small, and iterate fast. Fabric life is
finite, and aerodynamic efficiency trails stiff shapes.

**Rigid wings.** Composite airframes. They hold aerodynamic efficiency
and last longer. They cost more, iterate slower, and a crash destroys
them.

The debate is live. A structured expert study finds no dominant wing
design and keeps both families in play. The generation-architecture
counterpart study finds the same openness.

The field runs on experimentation, not consensus.

One cross-cutting result matters for the machine in this report. Many
smaller units beat fewer large ones. Across the scaling studies, mass
falls faster than power when blades shrink and multiply.

The kite-turbine family leans on this result.

### Axis C: the transmission

The third axis is the transmission. A pumping system sends intermittent
tension down a moving tether. A rotary system sends steady torque down a
turning one.

A rotary machine can run continuously: the ring turns, and the ground
station converts torque without a reel-in phase. Continuous output needs
no smoothing between cycles.

That continuity is where the kite-turbine family sits in the landscape.

## 3. The rotary family and the kite turbine

**The rotating element.** Rotary airborne wind energy flies its lifting
surfaces on a ring, not on a single tether. The ring sweeps an annulus, a
disc with a hollow centre.

The KiteGen carousel, the rotating reel parotor, and the Daisy kite are
family members. Autorotation spins the machine. The wind drives the
blades, and the blades drive the shaft.

**The transmission.** The tensile rotary power transmission (TRPT)
defines the family. A TRPT is a shaft made of tensioned lines. Rings sit
apart under tension, and torque passes from ring to ring.

It bends and twists without a rigid driveshaft, and its capacity comes
from tension itself.

The physics descends from rope-drive engineering. The classical Flather
textbook on rope transmission already carries the engine of the idea.
Capstan friction, sag, speed derating and bending loss all live there.

**The lift.** A kite turbine needs lift as well as torque. In the Daisy
concept, a lifter kite holds the machine aloft through a lift chain. The
autogyro thrust from the rotor adds its own share.

The lift requirement couples the kite to the shaft. That coupling is a
studied equilibrium problem in its own right.

**The ground.** A rotary ground station converts shaft rotation to
electricity. It reels no line in and out. One end of the machine turns,
and the other end generates.

**Anchors in the literature.** Benhaïem and Schmehl analysed the torque
path of a rotating-reel machine, with phase lag as the control parameter.
The EnerKíte rotokite work gave the family a momentum-theory frame and
small-scale flight data.

The framework from Tulloch modelled the Daisy TRPT at three levels of
detail and checked the model against measured flight windows. The someAWE
group flies rotary kites with cyclic pitch.

Together they cover one machine: a ring, a shaft of tension, a ground
generator.

**Where the studied machine fits.** The machine in this report is a kite
turbine. Rigid blades ride the rings of a tensile rotary shaft, and the
shaft drives a ground generator.

The analysis searches its design space by computational evolution. The
search varies ring geometry, polygon count, rotor count, bank angles and
blade scale.

The report presents that search and what it taught. The machine flies
only in simulation. The analysis pipeline is the instrument, and the
report states that frame.

## 4. The reader takeaway (draft direction)

Candidate arc, one paragraph. Wind blows stronger and steadier above the
reach of any tower. Two families of flying machines chase it: those that
generate aloft, and those that send force down a tether.

Within the ground-generation family, a rarer branch spins its rotors
continuously and sends rotary power down the line. The kite turbine lives
in that branch.

This report studies one such machine the way engineers study a design
space. It tests many versions, records what worked, and states only what
the record supports.

## 5. Citation anchors: candidates for `references.bib`

`docs/reporting/references.bib` does not exist yet. The table below is
the candidate set, and each row names what its source grounds. Years in
the table are identifiers.

Each entry needs a resolvable source, such as a DOI, an arXiv identifier,
or a URL, before any citation ships. The retrieval layer is the
`awe-knowledge` skill plus `literature-crosscheck`.

| Anchor | What it grounds | Source trail |
|---|---|---|
| Loyd, Crosswind Kite Power (1980) | Both crosswind modes, and the shared power ceiling | wiki `loyd-crosswind-kite-power`, corpus `raw/papers/loyd-crosswind-kite-power-1980.md` |
| Cherubini et al., AWE review (2015) | Ground-gen / fly-gen taxonomy, the catalogue, the soft-to-rigid shift, mass insights | wiki `cherubini-2015-awe-review`, corpus `raw/papers/cherubini-awe-review-2015.md` |
| Diehl, AWE fundamentals (2013) | Classification axes, and the universal power bound | wiki `diehl-awe-fundamentals` |
| Trevisi, Gaunaa, McWilliam, unified model (2020) | One model for both modes, and the glide-ratio flip | wiki `unified-gg-fg-power-model`, corpus `raw/papers/trevisi-unified-awes-model-2020.md` |
| van der Burg et al., wing dominance (2022) | No dominant wing design, with both families viable | wiki `dominant-design-awe-wings`, corpus `raw/papers/van-der-burg-dominant-wing-designs-2022.md` |
| van de Kaa, Kamp, generator dominance (2021) | No dominant generation architecture | wiki `dominant-design-awe-generators`, corpus `raw/papers/van-de-kaa-kamp-generator-dominance-2021.md` |
| Pereira, Sousa, design factors (2023) | The design factor taxonomy, and many small units beating few large ones | wiki `awe-design-factors-taxonomy`, corpus `raw/papers/pereira-sousa-2023-design-factors.md` |
| Flather, rope driving (1895) | Rope-drive physics behind TRPT | wiki `rope-power-transmission-flather-1895`, corpus `raw/papers/flather-rope-driving-1895.md` |
| Tulloch, Yue, Kazemi Amiri, Read (2022) | The TRPT model framework, with field validation | wiki `trpt-modelling-framework-tulloch2022`, corpus `raw/papers/tulloch-energies2022-trpt.md` |
| Benhaïem, Schmehl, rotating reel (2018) | Torque transfer through tethers, and phase-lag control | wiki `rotating-reel-parotor`, corpus `raw/papers/benhaiem-schmehl-rotating-reel-parotor-2018.txt` |
| Read, kite networks chapter (2018) | The Daisy architecture and tensile kite networks | wiki `daisy-kite-system`, `windswept-and-interesting` |
| Ranneberg et al., rotokite (2014) | The momentum frame for rotary rotors, with flight data | wiki `rotokite`, corpus `raw/papers/ranneberg-rotokite-enerkite-2014.md` |
| Joshi et al., LCoE scaling (2025) | Smaller-is-better across the field | wiki `groundgen-scaling-lcoe`, corpus `raw/papers/joshi-scaling-lcoe-2025.md` |
| Aull et al., fly-gen mass scaling (2020) | Fly-gen mass penalties and smaller-is-better | wiki `fly-gen-mass-scaling`, corpus `raw/papers/aull-fly-gen-design-optimization-2020.md` |
| Joshi, Kruijff, Schmehl, value-driven design (2023) | Continuous delivery as a value, and the storage cost of pumping | wiki `value-driven-awe-design`, corpus `raw/papers/joshi-value-driven-design-2023.md` |
| NREL assessment (2021) | Rotary torsion multiwing on the upscaling path | wiki `nrel-awe-report-2021`, corpus `raw/papers/nrel-awe-report-2021.md` |
| Jamieson multi-rotor work (2024) and Hancock small-blade manufacturing (2024) | Multi-rotor scaling and the small-blade manufacturing case | wiki `multi-rotor-scaling-laws`, `small-blade-manufacturing-advantages`, corpus `raw/papers/jamieson-multi-rotor-concept-2024.md`, `raw/papers/hancock-lm-windpower-mrs-blade-lens-2024.md` |

## 6. Terms for the Track D cross-check

Track D owns the glossary. This list tells Track D what U1 needs. The
chapter defines each term at first use, from the glossary when it lands.

Core terms: fly-gen, ground-gen, pumping cycle, rotary airborne wind
energy, kite turbine, tensile rotary power transmission (TRPT), ring,
annulus, autorotation, autogyro thrust, lifter kite, lift chain, tensile
kite network, ground station, glide ratio.

Lever vocabulary (used in passing here, owned by the U2 chapter): ring
geometry, polygon count, rotor count, bank angle, blade scale.

Method names: carousel, rotating reel, cyclic pitch, computational
evolution. Define only where U1 uses them.

## 7. Open requests

1. **`references.bib`.** Create it from the anchor table, verify each
   source, and gate it like the register. Owner to nominate.

2. **Track D glossary.** The U1 terms above need definitions before
   chapter prose starts.

3. **Track A and B responses.** These reconcile the story skeleton, not
   this document. The one-sentence U1 claim lives in `story-skeleton.md`.

4. **Explainer additions.** `@science-writer`: the teaching layer (a
   tensile shaft, tension-supplied capacity, the lift chain) keys off
   section 3 above. Where the physics needs a figure, raise a Track C
   spec seed.
