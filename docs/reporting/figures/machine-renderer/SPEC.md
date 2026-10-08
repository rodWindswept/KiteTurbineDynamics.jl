# SPEC: machine renderer. Decoded genome to a drawn turbine at one fixed scale.

**Slug** `machine-renderer`

**Status** SPEC v1, prep draft for Round 1. Register v1 awaits signatures. This
document therefore carries no data values. Angle brackets below mark a binding
slot. A slot resolves at GENERATE. It never fixes a value here.

**Owner** @figures-images-diagrams. **Paired for the provenance and reproduction
gates** @software-worker. **Content check** @aero-validator and
@science-validator. **Visual check** the multimodal image-reader, on the visual
checklist only. The image-reader never validates dimensions or numbers.

**Contracts** the reporting framework (figure workflow, three rounds, deltas).
The numbers register (the firewall). The landscape plan, which supplies the
analysis.

## Why this exists

The report shows the search designs as *the turbines themselves*, not only as
PCA plots. The framework calls this a pipeline extension, not a drawing task.

The deliverable is a renderer that draws *any* decoded genome at one fixed
scale. The set covers the winner, a design family, and a generation from the
search. Side-by-side panels then compare honestly.

Three modes share one engine:

| mode | what it draws | source |
|---|---|---|
| hero | one design, the full annotation set | the winner genome |
| family grid | one panel per family exemplar | the Phase 3 exemplar list |
| evolution strip | the best designs across generations | per-generation genomes from a prepared extract |

## What already exists. Extend, do not rebuild.

- `scripts/preview_genome_geometry.jl` checks decode against build. It draws
  the geometry a genome decodes and the geometry the ODE system builds. A wrong
  form then shows by eye, before a campaign spends hours on it. Geometry faults
  slipped through unseen once, and this tool guards that class. The machine
  renderer inherits the purpose. A disagreement between decode and the built
  machine is a finding, never a detail.

- The committed bankderate winner pack (`scratch/hermes_winner_pack.jl`, latest
  revision in the report commit landings) draws per-winner elevation and 3D
  views as built. Its headers state the rule: no ODE, decode plus build plus
  render only. Its shaft-frame projection, section palette and line classes
  are the visual ancestors of the strip panels.

- Inherited conventions: the shaft frame, with distance along the shaft
  vertical and radius horizontal. Equal units per axis. The ground datum at the
  base. Rings as section-coloured segments. Rotor annuli as bar pairs. The
  rope, bridle, cyan and backline line classes.

This extension adds: set-level batching, one fixed scale across panels, the
blade-and-bank drawing, the strip composition, the geometry manifest and the
fidelity checks, TikZ emission, and the provenance stamp block. The winner pack
draws annuli and notes the bank as text. The family renderer draws the blades.

## Inputs. The input contract.

The renderer draws only what it receives. It never opens raw telemetry. It
never selects, ranks or interprets.

1. **Render-set definition**, one per figure. It holds the mode and an ordered
   entry list. Each entry carries an identity label, the genome vector, and the
   source row reference. The label is a row identifier from the extract, not a
   claim. Generation indices and family names are identifiers.

2. **Genome vectors**, byte-exact, from provenance-stamped prepared extracts of
   the signed dataset. Those extracts are the charting-data deliverable of the
   analysis room. Slot order is the canonical genome layout: `r_hub`,
   `r_bottom`, `target_Lr`, `n_lines`, `density_profile`, `rotor-mask proxy`,
   `bank_top`, `bank_bottom`, `blade_scale_top`, `blade_scale_bottom`.

3. **The recorded decode and construction chain.** This covers the discrete-gene
   rounding the campaign runner applied, the decode knobs the campaign ran
   (cylinder-cone geometry, rotor-count mode, power split, cone slope, rotor
   spacing fraction, blocking factor), and the construction knobs (params at
   the campaign length, beam sizing, the k basis). The manifest names them all.
   The renderer applies exactly the recorded values, and nothing else.

4. **Register binding.** Each set ships a citation list. The list holds the
   signed register rows for every numeric annotation and identity claim, and
   the provenance-stamped extract as the geometry source. The extract itself
   comes from the signed dataset. No numeric claim enters a figure without a
   signed row.

## The drawing

### Frame, projection, scale

- **Orthographic elevation in the shaft frame.** The vertical axis holds the
  distance along the shaft. The ground ring datum sits at the base, and the
  distance grows toward the lift chain. The horizontal axis holds the radius,
  on both sides of the axis. One projection rule governs everything. A machine
  point at radial distance rho, azimuth theta and shaft distance s draws at
  (rho times cos theta, s). Every ring, line, blade and overlay follows this
  rule. Nothing draws freehand.

- **Equal units per axis.** The canvas proportions match the machine
  proportions. Never stretch one axis.

- **One fixed scale per render set.** Every panel shares one data window and
  one canvas. A single metres-per-point constant then holds across the set. The
  manifest declares the constant. Machines of different sizes render at
  different sizes. That is the honesty property, and a review criterion. If
  every panel looks the same size, the render lies.

- **Why not the 3D view.** Perspective foreshortening breaks relative-size
  reading. The 3D renders stay in the rooms as interrogation assets. They do
  not enter the report figure.

- **Why the shaft frame.** The deployment frame stays constant across the
  campaign. The shaft frame is machine-intrinsic, and comparable.

### Elements and the asserted dimensions

Each drawn element carries a semantic tag. The tag values enter the geometry
manifest. The fidelity checks re-measure exactly these values.

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `axis` | datum | dashed centreline through the axis | none, furniture |
| `ground_ring` | the constructed ground ring | heavy segment, both sides, at the datum | radius |
| `ring` | each constructed ring | a segment at its shaft distance | count, distance, radius, section class |
| `line_family` | the TRPT attachments | segments between consecutive rings | count per gap equals n_lines |
| `rotor_annulus` | each rotor | edge-on bars, inner to outer radius | rotor count, ring index, radii |
| `blade` | each rotor blade set | one segment per blade, inner end to outer tip | count, span, bank angle |
| `section_marker` | the section boundaries | dotted horizontals at the transitions | positions |
| `lift_chain` | the constructed state, hero only | bridles, cyan, backline, kite marker | drawn or absent |
| `scale_bar` | the set scale constant | a bar with its declared length | drawn length |
| `legend` | static | every colour and line class explained | completeness |

Two notes resolve recorded fault classes.

- **The blade extension is absolute.** The outer extent equals the ring radius
  plus the outboard tip offset. The inner extent equals the ring radius minus
  the inboard offset. The offsets are not radii. This is the recorded
  offset-read-as-absolute class. The manifest records absolute extents only.

- **Every blade draws.** Where the projection makes blades coincide, they
  overlap. Each still counts individually.

### Panel, strip, footer

- Fixed panel canvas. The machine sits centred on its axis, with margins. No
  element touches a panel edge.

- A **label strip** below each panel carries the identity label only. No text
  sits over a drawing.

- A **footer band** under the set carries the scale bar, the legend, and the
  source stamp. The stamp line reads: data commit, extract, register rows,
  script commit.

- The title states the finding, on one line, register-bound at GENERATE.

### Style

The palette, line weights and typography follow the winner-pack elevation and
the house figure standards. White ground. Section colours and line-class
colours live in the script. Dash styles must survive print at panel scale.

## Modes

- **Evolution strip.** One panel per entry, in the order declared by the
  extract, generation ascending. Shared scale, shared window, shared datum. The
  strip claims geometry only. Any growth-and-shrink reading depends on the
  shared scale, and the footer states it.

- **Family grid.** One panel per family exemplar. Family names sit in the label
  strips, as Phase 3 names via the extract. The same rules apply.

- **Hero.** One design. Only the hero may carry the lift-chain overlay and a
  register-bound annotation block. Either needs a delta note and extra asserts.

Fallback rule for the strip: if the record cannot supply a genome for every
generation, the strip renders a declared milestone subset. The analysis room
chooses the subset, and the extract records it. No interpolation, no
reconstruction, ever.

## Geometry-fidelity assertion. The extra CHECK gate.

Machine renders carry one assertion beyond the standard figure checks. **Every
drawn dimension equals the decoded genome value.** In plain terms, the machine
the figure shows is the machine the record describes. The checks below are
mechanical. Any failure is a reject, in the wrong-geometry class, in pixels.

- **F-CITE, citation binding.** Every panel binds to its extract row and its
  signed register rows. The drawn genome vector is byte-identical to the
  extract. The knob set equals the campaign record. The source stamp sits on
  the figure. An uncited dimension is a reject.

- **F-REPRO, deterministic reproduction.** A fresh pipeline run on the same
  inputs reproduces the manifest and the output hashes bit-identically. Script
  and toolchain stay pinned. A re-run that drifts is a defect, not noise.

- **F-PARSE, drawn equals manifest.** An independent parser re-measures the
  vector file. It covers every asserted dimension and the scale bar. It
  compares against the manifest at the declared scale, within a declared
  tolerance. That tolerance must be smaller than the smallest asserted feature
  at draw scale. Any visible misdraw then fails.

- **F-COUNT, enumerations.** Ring count, rotor count, blades per rotor, lines
  per gap, and the section sequence. The checker counts each one from the
  vector file. Every count must equal the manifest.

- **F-VALUE, register equality.** Every asserted dimension equals its signed
  register row at the stated precision of that row. No tolerance widening. A
  mismatch is a reject and a finding. The report cannot draw a machine the
  record does not describe.

A companion check runs inside the pipeline at GENERATE. The
decode-versus-constructed comparison raises on any delta in an asserted
dimension. No silent correction, no silent continue.

That purpose comes straight from the preview tool. The renderer inherits it.

Ownership: the validators own F-CITE, F-VALUE and the register. The
software-validator owns F-REPRO and provenance. Anyone can run F-PARSE and
F-COUNT from the committed script.

**The image-reader never validates dimensions or numbers.** Pixels cannot prove
a value. Its checklist is visual only.

Visual checklist for machine renders, added to the framework list: no part
against a panel edge. Label strips clear of drawings. The legend explains every
channel. The scale bar stays legible at print size. Panels align on the ground
datum.

## Emitted artifacts per render set, at GENERATE

- `set-<slug>` definition file.

- The generating script, committed and versioned.

- `manifest.json`, with this schema sketch:

```
{ "set": …, "mode": …, "script_commit": …, "data_commit": …,
  "extract": { "path": …, "sha256": … }, "knobs": { … },
  "scale": { "m_per_unit": …, "window": { … }, "tolerance": …, "scale_bar": … },
  "registers": [ … ],
  "panels": [ { "label": …, "genome": [ … ], "source_row": …,
                "elements": [ { "tag": …, "values": { … } }, … ] } ] }
```

- `figure.tex`, TikZ with computed coordinate macros. Then `figure.pdf`, vector
  with house typography. Optional `figure.svg` for web. Then `figure.png` as a
  print-resolution preview.

- The source stamp line and the dual-caption block.

- The render register row, with the round status updated.

The spec requires dual captions from the first figure. Each figure carries one
plain-English sentence for a first-year reader, plus the STE-clean technical
caption for the record.

Claim wording converges with the room (Track A and B) at GENERATE. Every number
in either caption is a register citation. Every term is a Track D glossary
term.

## Rounds

- **R1** this spec plus a schematic layout prototype, in HTML, with placeholder
  shapes. Composition review needs no register numbers. Deltas log below.

- **R2** the first scripted render set walks the checks. Image-reader and
  validators. Deltas.

- **R3** the final sets (strip, families, hero) pass the full checks, then the
  visual pass by Rod. Status moves to approved.

## Render register (planned)

| slug | mode | title, draft | status | source | issues |
|---|---|---|---|---|---|
| `machine-evolution-strip` | strip | ⟨finding-oriented title at R1⟩ | planned | Track C extract | awaiting extract and register v1 |
| `machine-family-<name>` | family | ⟨family name at Phase 3⟩ | planned | Track C extract | awaiting families |
| `machine-winner-hero` | hero | ⟨title at R1⟩ | planned | winner extract | awaiting register v1 |

## Open inputs. Requests to the rooms.

1. **Register v1 signatures**, the rows every render cites.

2. **Track C extracts**, one provenance-stamped file per figure. The strip list
   needs best-per-generation genomes, identity labels, and the recorded
   selection rule. The family list needs exemplar genomes. The hero needs the
   winner genome row. The renderer starts as soon as they land.

3. **Track D glossary**, for the caption terms: shaft, ring, rotor, blade,
   bank, swept annulus, and the section names. Captions then avoid release
   blockers.

4. **Phase 3 family names.** Labels only.

## Non-goals

The renderer runs no ODE, scores nothing, and reads no raw telemetry. Report
figures use no 3D perspective. Annotations need register binding and a delta
approval.

No check grades itself. No number appears without its register row.

## Decisions log (spec deltas)

- **D1 Draw from the constructed state.** The evaluated machine is the built
  machine. So the draw source is the as-built static geometry. The pipeline
  asserts decode-versus-built agreement and raises on any delta. The
  alternative, drawing the decode intent, can draw a machine that never flew
  through an evaluation.

- **D2 Orthographic elevation, shaft frame, equal axis units.** Comparability
  needs a projection without foreshortening. The deployment frame stays
  constant across the set, and no panel draws it.

- **D3 One fixed scale per set.** Identical window and canvas across panels.
  Different machine sizes render at different sizes, by intent.

- **D4 The lift-chain overlay stays out of comparability sets.** It is constant
  context, and it collides with blade spans. The hero may carry it by delta.

- **D5 TikZ emission is the primary target.** Vector output, house typography,
  and every coordinate a computed macro. Fidelity by construction, then
  re-measured by F-PARSE.

- **D6 The renderer never selects and never interprets.** Selection belongs to
  the analysis room, recorded in the extract. The renderer draws what it
  receives.

*Delta rounds: R1 to ⟨append⟩. R2 to ⟨append⟩. R3 to ⟨append⟩.*
