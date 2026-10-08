# Glossary candidates — Track D handoff

**Slug** `glossary-candidates`

**Date** 2026-10-08. **To** the analysis room (Track D), via @hermes.

**Status** PREP v3, numbers-free by construction (no measurement values, no
model constants). The validators signed register v1, and section 5 carries
the constants interface. Every value slot in a definition stays a binding
slot for Track D.

**Owner** @science-writer (drafting assist). **Track D owns the glossary.**
The analysis room ratifies, rewrites, or rejects each entry below.

The ratified list lands at `docs/reporting/glossary.md`. The writers may only
use glossary terms, and a shortcut term with no entry is a release blocker,
gated like a number.

**Contract** the room consultation (Track D), the boot handover, the
AWE-context outline (section 6), and the machine-renderer spec (section 7
caption terms).

**Grounding** the repo record only: `docs/agents/physics-topology.md`,
`CONTEXT.md`, `docs/agents/genome-glossary.md`, `docs/agents/domain.md`,
`docs/agents/instrument-trust-log.md`, `docs/agents/stale-phrases.md`, and
`DECISIONS.md`.

The landscape terms come from the outline and its literature anchors.
Nothing here comes from recall.

**How to read the tables.** *Term* names the candidate. *Draft* is a candidate
definition for the room to ratify or rewrite. *Ground* names the repo source
that carries the meaning.

*Action* says what Track D does. **Ratify** means the record already supports
the draft. **Supply** means the room writes the authoritative definition.
**Verify** means check the draft against the awe-knowledge wiki.
**Room-supplies** means the term is central to the analysis story and needs
the exact reading from the analysis room.

## 1. Landscape terms (U1, literature-grounded)

The outline owns this ground. Track D verifies each draft against the
awe-knowledge wiki before it ships.

| Term | Draft | Ground | Action |
|---|---|---|---|
| airborne wind energy (AWE) | Wind energy harvested by flying devices, not towers. | outline, Diehl, Cherubini | supply |
| fly-gen (fly generation) | The generation family where the generator flies. Onboard turbines harvest the apparent wind. A conducting tether carries electricity down. | outline section 2, Loyd, Cherubini | verify |
| ground-gen (ground generation) | The generation family where the generator stays on the ground. The tether carries force. The ground station converts it. | outline section 2, Ampyx, SkySails, Kitepower, EnerKíte | verify |
| pumping cycle | The mainstream ground-gen method. Reel out under load, reel in depowered, repeat. The output is intermittent by construction. | outline section 2 | verify |
| rotary airborne wind energy | The family that flies its lifting surfaces on a ring. The ring sweeps an annulus. | outline section 3 | verify |
| kite turbine | The machine class of this report. Rigid blades ride the rings of a tensile rotary shaft. The shaft drives a ground generator. | outline section 3, CONTEXT.md | ratify |
| carousel | Method name (KiteGen). Define only where U1 uses it. | outline section 3 | verify |
| rotating reel | Method name (Benhaïem, Schmehl). A rotating-reel machine controls torque transfer with phase lag. | outline section 3, anchor table | verify |
| cyclic pitch | Method name (someAWE). | outline section 3 | verify |
| tensile kite network | The design concept of joining kites as one tensile network. The Daisy lineage carries it. | outline section 3, Read chapter anchor | supply |
| glide ratio | The aerodynamic ratio behind the fly-gen and ground-gen power trade. | outline section 2, Trevisi | supply |

## 2. Machine terms (U1 to U4, plus the renderer captions)

`docs/agents/physics-topology.md` is the authority for this group. The
renderer spec asks for caption-safe entries for shaft, ring, rotor, blade,
bank and swept annulus.

The rows below cover those terms, including the shaft section names from the
three-section geometry. Design-family names wait on the Phase 3 labels.

| Term | Draft | Ground | Action |
|---|---|---|---|
| TRPT (tensile rotary power transmission) | A shaft made of tensioned lines. Rings sit apart under tension, and torque passes from ring to ring. The capacity comes from the tension itself. | outline section 3, CONTEXT.md, physics-topology 1 | ratify |
| tensegrity | A structure whose form follows its tension balance. The TRPT column is tensegrity, not a rigid shaft. | physics-topology 1 | ratify |
| shaft | The flying column between the main rotor and the ground station. It is a tensegrity column, not a rigid driveshaft. | physics-topology 1, renderer spec section 7 | supply |
| ring (TRPT ring) | A polygonal spacer ring of the shaft. The ring beams work in compression inside the polygon. | domain.md, physics-topology 2 | supply |
| shaft sections (transmission, cone, harvest) | The three sections of the shaft, from the ground up. A transmission cylinder at constant low radius. Then a cone tapers up to the top radius. The harvest section sits at the top, where the rotors are. | `src/ring_spacing.jl` (three-section geometry), winner-pack palette | supply |
| ground ring | The bottom of the TRPT. It is free to rotate, and it is the PTO end. One of only two parts that touch the ground. | physics-topology 1 | ratify |
| annulus (swept annulus) | The swept area of a ring-anchored blade. A ring-anchored blade sweeps an annulus, not a disc. | physics-topology 4.1, renderer spec section 7 | ratify |
| main rotor | The topmost rotor. Everything below it is the transmission for its torque. Never write "hub rotor". | physics-topology 4, CONTEXT.md | ratify |
| expansion rotor | A banked-blade rotor on a TRPT ring. It adds its own thrust and torque. It is a co-equal generating rotor, never "supplementary". | physics-topology 4, CONTEXT.md | ratify |
| bank angle (bank) | The angle of a blade out of its ring plane. Bank is not elevation, and it is not yaw. | physics-topology 4 | ratify |
| elevation angle (β) | The tilt of the shaft axis away from horizontal. | physics-topology 4, CONTEXT.md | ratify |
| sweep | The azimuthal setting of a blade within the ring. Tulloch names anhedral, bank and sweep together. | physics-topology 4 | supply |
| banked blade | A blade whose span runs out of the ring plane. The blade stays straight, and the angle lives in the mount. The swept surface is a cone frustum, not a flat annulus. | physics-topology 4 | supply |
| blade | One aerodynamic element of a rotor. The blade count equals the polygon line count. | physics-topology 4, renderer spec section 7 | supply |
| blade scale | A linear scale on blade span. Written out longhand. It is not λ. | genome-glossary terminology note | ratify |
| tip-speed ratio (TSR, λ) | Blade-tip speed divided by wind speed. The report reserves λ for this meaning alone. | CONTEXT.md TSR row | ratify |
| polygon count | The number of line vertices in a ring. It equals the blade count. | genome-glossary polygon gene | ratify |
| ring spacing ratio (L/r) | The ratio of ring spacing to ring radius. The shaft layout targets this ratio. | genome-glossary spacing gene, DECISIONS [2026-10-03] | supply |
| ring geometry | The lever family that sets ring radii and ring spacing. | genome-glossary radius and density genes, U2 | supply |
| rotor count | The number of ring stations that carry a rotor. The count reads rotor stations, not active blade lines. | genome-glossary rotor mask gene | supply |
| lift chain | The support path that holds the main rotor. It runs: lifter kite, lift line, sky hook, cyan line, lift bearing, bridles, main rotor. | physics-topology 2 | ratify |
| lifter kite | The topmost kite. It launches first and gives lift only. It carries no torque and no drive. | physics-topology 2 | ratify |
| lift line | One line from the lifter kite to the sky hook. | physics-topology 2 | ratify |
| sky hook (sky anchor) | The three-way knot between the lift line, the backline and the cyan line. Pick one name for the report. | physics-topology 2, CONTEXT.md | ratify |
| backline | One line from the sky hook to the backline ground anchor. It limits sky-hook altitude, and it is not a load path. It stays taut at the design point. | physics-topology 3.2 | ratify |
| cyan line | One line from the sky hook to the lift bearing. It carries the TRPT load. It is never a bridle. | physics-topology 2 | ratify |
| bridles (gold bridles) | The lines from the lift bearing to the main-rotor vertices. They are the load path of the lift chain. | physics-topology 2 | ratify |
| lift bearing | The swivel that rides the shaft axis. It sits at the apex of the bridle cone. | physics-topology 2 and 3.1 | ratify |
| ground station | The ground end of the machine: generator and power take-off. It reels no line. | outline section 3, CONTEXT.md | ratify |
| PTO (power take-off) | The part that converts shaft rotation into electricity. | CONTEXT.md | supply |
| autogyro thrust | The lift the spinning rotor makes by itself. It shares the support of the main rotor with the lift chain. | physics-topology 3 | supply |
| network rotor model | The design view where several rotors share the power equally. | CONTEXT.md | supply |
| tension-supplied capacity | The principle that TRPT torque capacity comes from shaft tension. More tension lets the same lines carry more torque. | outline section 3, CONTEXT.md MTR row | room-supplies |
| MTR (moment-to-tension ratio) | Moment-to-tension ratio. It ties the moment a shaft section carries to its tension and radius. | CONTEXT.md MTR row | supply |
| bank derate | The power factor applied to a banked rotor. It scales disc power by the cosine of the bank angle. The exponent takes a fixed value. | physics-topology 4.0.1, CONTEXT.md | room-supplies |
| torsional collapse | The failure mode where torque demand passes the geometric capacity of the shaft. Rings converge and power transfer fails. | CONTEXT.md | supply |
| collapse margin | The distance between the current twist state and the torsional collapse cliff. | CONTEXT.md | supply |
| FoS (factor of safety) | The ratio of capacity to load at a structural check. The report states which checks it covers. | CONTEXT.md FoS row | supply |
| Betz ceiling | The theoretical upper bound on rotor power. No rotor can take more from the wind. | framework section 3, awe-knowledge | supply |
| tip-speed ceiling | The operating limit on blade tip speed. | framework section 3 | supply |
| blade-mass law | The rule that blade mass scales as a power of blade span. The reference mass comes from the flown Daisy blade. | CONTEXT.md blade-mass law row | room-supplies |

## 3. Search and evaluation terms (Methods, U2 to U4)

| Term | Draft | Ground | Action |
|---|---|---|---|
| campaign | One complete design search over a design space, with recorded telemetry. | domain.md, handovers | supply |
| genome | The design vector. A decoder turns it into a machine. | genome-glossary | ratify |
| decoded genome | The machine a genome builds. | genome-glossary pipeline, renderer spec decision D1 | ratify |
| differential evolution (DE) | The search algorithm. It evolves candidate designs across generations. | CONTEXT.md, genome-glossary | supply |
| island | One independent search population inside a campaign. | campaign runner, framework U3 | supply |
| generation | One step of the evolution loop. Each generation records its best design. | story skeleton U3, convergence records | supply |
| seed | The starting design a search round starts from. | genome-glossary, DECISIONS [2026-10-05] | supply |
| Daisy | The flown rigid-rotor kite turbine built by Windswept. The model anchors its site wind and its blade-mass reference to the flown machine. | DECISIONS [2026-10-03], CONTEXT.md | ratify |
| convergence | The record of best-fitness progress by generation. | campaign outputs | supply |
| fitness | The score the search minimizes for each design. Methods states its exact composition. | objective docs, register source column | supply |
| evaluator | The instrument that flies a design and measures it. The windowed evaluator is the single protocol. | CONTEXT.md windowed evaluator row | ratify |
| rapid path | The fast evaluation protocol. It starts from a static pre-solve. Probes reject the recorded winners through the rope-break gate. | consultation Track C item 5 | room-supplies |
| ODE path | The full settle-then-window evaluation protocol. It reproduces the recorded winners. | consultation Track C item 5 | room-supplies |
| ODE | Ordinary differential equation. Spell the acronym out at first use in the report. | Rod ruling 2026-10-08, consultation Track C item 5 | ratify |
| start mode | The evaluator switch between the two paths. The default is the rapid path. Settle the report-facing names. | register known boundaries, consultation Track C item 5 | room-supplies |
| settle | The start-up phase that brings the machine to its operating state before measurement. | CONTEXT.md, physics-topology 7 | supply |
| relax phase | The first part of a run, before the measurement window. The machine relaxes through its start transient. | CONTEXT.md honest window row | supply |
| measurement window | The part of a run that the scoring reads. | CONTEXT.md | supply |
| honest window | The settle-avoiding protocol: a relax phase, then a measurement window, scored on the tail. It stops the window sampling the settle decay. | CONTEXT.md honest window row, DECISIONS | room-supplies |
| gate | A hard acceptance check in the evaluator. A design that fails carries the measured statistics, not a guessed verdict. | CONTEXT.md EvalResult row | supply |
| rope-break gate | The gate that trips when a line passes its strain limit. | consultation Track C item 5 | room-supplies |
| clearance (blade-tip clearance) | The gap a blade tip keeps from the machine at its top-of-circuit pass. A gate rejects designs that breach it. | physics-topology 4, register status column | supply |
| FoS gate | The structural acceptance check against the FoS floors. | CONTEXT.md, register source column | supply |
| status (ok / reject) | The single reject channel of an evaluation. Never infer rejection from the fitness value. | CONTEXT.md EvalResult row | ratify |
| window statistics | The summary values a measured window reports: mean power, end power, tail statistic. | register rows, CONTEXT.md | supply |
| k_mppt (k) | The generator gain. Generator torque scales with the square of shaft speed, times k. | CONTEXT.md k_mppt row | ratify |
| MPPT (maximum power point tracking) | The generator-loading strategy that tracks rated power. | CONTEXT.md | supply |
| site wind (wind standard) | The measured wind profile every machine reads, re-expressed at its own rotor altitude. | DECISIONS [2026-10-03] | supply |
| computational evolution | The report-wide phrase for the search method: a design space searched by an evolutionary algorithm. | story skeleton | supply |

## 4. Trust and record terms (U5, U6, Methods, Data availability)

| Term | Draft | Ground | Action |
|---|---|---|---|
| instrument floor | A metric can stay uniform across conditions that should change it. That uniformity measures the instrument, not the design. | trust log detection pattern | room-supplies |
| instrument trust log (trust log) | The ledger of instrument faults, catches and retractions. | docs/agents/instrument-trust-log.md | supply |
| guard | A committed check that raises instead of returning a plausible wrong value. | physics-topology 6 | room-supplies |
| voided campaign (VOID) | A campaign whose results no longer count. A later finding broke its model or its geometry. | domain.md, DECISIONS | supply |
| dead genes (dead geometry genes) | Genes the search mutates with no effect. The simulated machine never reads them. | genome-glossary dead dimension, domain.md | room-supplies |
| k-alignment fault | The fault class where a check runs the wrong generator gain. The machine then differs from the one the campaign scored. | trust log [2026-08-13] and [2026-08-24] rows | room-supplies |
| stale-gate near-miss | The case where a re-gate ran at a stale gain and passed. A pre-push review caught it. | trust log [2026-08-24] row | room-supplies |
| the fold | The rebase of the lowest power rung onto the S2-class fold seed. The ceiling genes fold up, and the bounds recenter. | DECISIONS [2026-10-05] | room-supplies |
| numbers register | The single source of truth between the simulation and the audience. Only signed rows exist for reporting. | framework section 2, register header | ratify |
| register row | One claim with value, units, source and a validator signature. | framework section 2 | ratify |
| supersession | A claim changes by a dated new row, never by edit. The old row stays in the record. | register rules | supply |
| provenance stamp | The commit and era fingerprint carried on campaign data. | campaign CSVs, provenance sensor | supply |

## 5. Register interface: definitions that carry constants

Some definitions would carry a model constant in their natural form. The
report rule says no sentence may contain a number that is not a signed
register row.

**Answer recorded** (2026-10-08, register-side, @science-validator, with the
v1 sign): if a value will appear in prose, a model-constants row is the
ready format. The validators sign those rows like any other. A purely
qualitative definition needs no row.

Two lawful routes follow, and both stay open per constant:

1. Qualitative route. The definition carries no value, and the Methods
   equations carry the constants. No row applies.

2. Value route. The definition quotes the constant, and the constant gets
   its own signed row (the constants class).

The constants affected, at least: the bank-derate exponent, the site wind
shear exponent, the lift margin, the blade-mass exponent, the FoS floors,
the collapse thresholds, the strain limit of the break gate, and the
reference coefficients (Cp, Ct) if a definition quotes them.

Track D picks the route per constant. The default here stays qualitative
until a constants row exists.

**Notation.** The Nomenclature section carries symbols and units. Candidates
for it: λ (tip-speed ratio), β (elevation), L/r (ring spacing ratio),
k_mppt, MTR, FoS, ω (shaft rotation rate), P (power), τ (torque). Track D
and @author settle the final symbol list.

## 6. Naming traps (the retire list)

The record supersedes or bans these phrases. A draft that uses one is a
defect, like a missing register row.

| Do not write | Write | Ground |
|---|---|---|
| "hub rotor", or "hub" for a rotor | main rotor, topmost rotor | stale-phrases, physics-topology 4 |
| "bridles (cyan lines)" | name each line: bridles, cyan line | stale-phrases, physics-topology 2 |
| bare "the line" | name the line | physics-topology 2 |
| "λ" for the blade-scale gene | blade scale, written longhand | genome-glossary |
| "λ³" for blade mass | the blade-mass law in blade span | CONTEXT.md blade-mass law row |
| "supplementary" rotors | co-equal generating rotors | CONTEXT.md |
| unqualified "V10" | V10-DE, V10-Spoke, or V10-Tight (retracted) | CONTEXT.md canonical names |
| "bank" as "yaw", or as "elevation" | bank, yaw and elevation are three concepts | physics-topology 4 |
| "rigid driveshaft" for the TRPT | tensegrity column | physics-topology 1 |
| "the expansion model replaces the disc model" | the record bans the expansion model at every ring. A banked rotor uses the disc model with the bank derate. | stale-phrases notes, physics-topology 4.0.1 |

## 7. Handoff

1. **Track D** takes this list, ratifies or rewrites each entry, adds terms
   from Tracks A and B, and lands `docs/reporting/glossary.md`. The room
   response goes to `docs/reporting/room-responses/` per the consultation.

2. **Caption terms** for the machine renderer (shaft, ring, rotor, blade,
   bank, swept annulus, the shaft section names): section 2 covers these
   terms. The family names wait on the Phase 3 labels.

3. **Literature terms** in section 1 need `references.bib` checks on their
   anchors. The outline carries that open request.

4. **The constants interface** sits in section 5: a value that reaches
   prose needs a signed row (the constants class is the ready format). A
   qualitative definition needs none.

5. This list is a floor, not a ceiling. The room adds whatever the report
   needs. No gate applies to this draft: it carries no numbers and no claims
   beyond the record.

## Deltas

- **v2 (2026-10-08):** register v1 signed. Section 5 records the constants
  answer. One row joins the machine group: the shaft section names
  (transmission, cone, harvest) for the renderer captions. No other change.

- **v3 (2026-10-08):** one row joins the search-and-evaluation group: ODE,
  spelled out at first use (Rod ruling). No other change.
