# SPEC: twist limit. The transmitted twist of every segment against its own over-twist limit.

**Slug** `twist-limit`

**Status** SPEC v1, R1 open. This document carries no data values. Angle
brackets ⟨⟩ mark binding slots. A slot resolves at GENERATE. The numbers
register v1 (signed 2026-10-08, `docs/reporting/numbers-register.md`) supplies
the citation discipline. The glossary candidates, section 6 (structural-limit
terms, the mechanism pair) supply the display forms.

**Owner** @figures-images-diagrams. **Companion figure** `ring-utilisation`.
The pair shares one source family and one shaft frame. **Content check**
@science-validator and @aero-validator. @aero-validator runs the F-VALUE
re-check at the sign-off commit. **Visual check** the multimodal image-reader,
on the visual checklist only. Pixels never validate numbers. Rod does the
final visual pass. **Reader-facing layer** @author. @author slots the pair
beside the envelope and census figures. Final numbers land after round three.
@author writes the captions under the register rules.

**Contracts** the reporting framework (figure workflow: SPEC / GENERATE /
CHECK, three rounds, deltas, dual captions). The numbers register (the
firewall). The glossary candidates, section 6.

## Why this exists

The census counts the `reject_twist` losses. The envelope shows where the
family twists. This figure shows the mechanism behind both pieces. It shows
how far each segment runs against its own over-twist limit.

At the limit, the transmitted torque peaks. Past the limit, the deformation
runs away, and the equilibrium is lost. The committed authority carries this
result (`src/trpt_twist_limit.jl`).

A second panel pairs the segment torque with the torque capacity at that
limit. Both series come from one captured state. Twist is live model data.
The figure is evidence-grade throughout.

## What already exists. Extend, do not rebuild.

- The dashboard strip is the visual ancestor. `torque_chain!` draws the
  transmitted torque per segment (ground → hub, labels `S1..Sn`).
  `twist_view!` draws the cumulative twist per segment (cyan ground → orange
  hub). The report figure re-renders this material as a static,
  register-cited plate in the house shaft frame. It invents no physics.

- `capture_extended` (`src/sim_frame.jl`) emits the running arrays.
  `segment_twist_deg` holds the twist per segment (principal value, degrees).
  `segment_torque` holds the rope constitutive torque from the tension and
  twist of the state itself. Both stay telemetry-only. They do not feed the
  solver.

- `src/trpt_twist_limit.jl` is the single over-twist authority.
  `trpt_twist_limit` returns `dcrit_deg` and the case flag `has_limit`.
  `trpt_torque_capacity_axial` returns the torque at the limit for a given
  axial force, and `Inf` where no limit exists. `trpt_axial_force` projects
  the line tensions of the state. The live gates in `rope_forces.jl` read
  the same authority. This figure shares that one source.

## Inputs. The extract contract.

1. **Capture.** One provenance-stamped extract from the signed dataset. One
   file, one run, one declared capture (the frame, or the row range that
   holds it). The extract declares the run id, the data commit, the era, the
   capture range and the computing commit. ⟨capture⟩

2. **Arrays**, per segment `S1 … S(n-1)` in the record order (ground end
   first):

   - `segment_twist_deg[s]` — emitted.

   - `dcrit_deg[s]` and `has_limit[s]` — the analysis room computes these
     with `trpt_twist_limit`, using the same call pattern the live gates use
     (the effective radii of the record, `l_t` the chord at the operating
     point). The extract header records the calls and the commit. A
     divergence from the gate use is a finding, not a free choice.

   - `segment_torque[s]` — emitted.

   - `torque_capacity[s]` — `trpt_torque_capacity_axial` at the axial load
     of the same state, via `trpt_axial_force`. `Inf` where no limit. The
     torque pair is instant-bound. Both series come from one capture
     instant, and the source stamp carries the one shared row range.

   - Identity: segment ids `S1…S(n-1)`. Ring ids `R1…RN` (record ring index:
     ring 1 is the ground ring, ring N the hub ring).

3. **Register binding.** Every number in the title, in a readout and in both
   captions cites a signed row. The values of the capture enter the register
   as the source rows of the figure before GENERATE. ⟨rows⟩

4. **Label ledger.** See below. One form per concept, pinned once, reused in
   labels, captions and prose alike.

## The drawing

### Frame, axes, scale

- The pair shares one shaft frame. The vertical axis is the distance along
  the shaft. The ground datum sits at the base. The distance grows toward
  the lift chain. The twist and torque panels share one vertical window, so
  the pair reads as one profile of one machine.

- **Panel A, twist.** The horizontal axis is angle, in degrees. Each segment
  draws the transmitted twist as its magnitude |Δα|. That is the comparison
  of the gate itself (collapse margin δα* − |Δα|). Each segment also draws
  its limit δcrit. A Case-B segment carries the label **no limit**. It has
  no δcrit mark. Never divide a Case-B segment into a ratio. Tether break
  strain carries its limit, not twist.

- **Panel B, torque.** The horizontal axis is torque, in N·m. Each segment
  draws a paired mark of `segment_torque` against `torque_capacity`, one
  capture instant for both. Case-B segments carry no capacity mark (no
  limit).

- Ranges: every axis window ⟨resolves at GENERATE⟩ from the capture. This
  document fixes no values.

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `segment_band` | extract | one band per segment, S1 at the base, ground → hub | count |
| `ring_tick` | extract | ring positions on the shaft margin, R1…RN | positions, count |
| `twist_mark` | `segment_twist_deg` | magnitude mark, one per segment | value |
| `limit_mark` | `dcrit_deg` | limit mark per segment where `has_limit` | value |
| `nolimit_tag` | `has_limit = false` | the string "no limit", tag and legend | presence |
| `torque_pair` | `segment_torque`, `torque_capacity` | paired marks, one instant | values, pairing |
| `source_stamp` | — | data commit · extract · run + row range · register rows · script commit · authority commit | presence |

### Readout list. One-to-one with the emitted names.

| Figure string | Emitted name | Where used | Note |
|---|---|---|---|
| δcrit | `dcrit_deg` (`trpt_twist_limit`) | limit marks, legend, caption | the over-twist limit, where the transmitted torque peaks |
| no limit | `has_limit = false` (Case B) | tag, legend, caption | never divided (tether break governs) |
| transmitted twist | `segment_twist_deg` | marks, legend, caption | magnitude drawn. The principal value stays in the extract |
| segment torque | `segment_torque` | panel B marks, legend, caption | from the tension and twist of the state itself |
| torsional capacity | `trpt_torque_capacity_axial` | panel B marks, legend, caption | paired at the axial load of the same state |
| `S1…S(n-1)` | record segment order | margin labels | ground end first |
| `R1…RN` | record ring index | margin ticks | ring 1 ground, ring N hub |

The display forms pin here once. A caption or label that paraphrases one
("critical angle", "limit angle") is a defect. The consistency pass of
@science-writer keys on this table.

## Checks. External, never self-graded.

- **F-CITE, citation binding.** Every annotation cites a signed row. The
  source stamp carries the data commit, the extract, the run and row range,
  the register rows, the script commit and the authority commit. A missing
  stamp or citation is a reject.

- **F-REPRO, deterministic reproduction.** A fresh run on the same inputs
  reproduces the figure bit-identically. Script and toolchain stay pinned.

- **F-LABEL, ledger equality.** The check enumerates the text layer of the
  emitted vector. Every string must equal its ledger entry. The check is
  mechanical and greppable. It is the label half of the consistency pass by
  @science-writer.

- **F-VALUE, register equality.** Every drawn value equals its signed row at
  the stated precision. @aero-validator owns this check, at the sign-off
  commit. No tolerance widening. A mismatch is a reject and a finding.

The framework visual checklist applies, graded from the image alone.

**Caption plan (dual, from the first figure).** Plain sentence: the shaft
twists as it carries torque. This figure shows how far each segment runs
from the angle where the twist runs away.

STE technical caption: name the
authority, cite the capture, state the no-limit rule and the instant-bound
torque pairing. Both captions use the ledger strings only. @author writes
them. Every number they carry is a register citation.

## Emitted artifacts at GENERATE

- the figure, vector PDF + SVG (PNG preview at print resolution)
- the generating script, committed
- the source stamp line, and the dual-caption block
- the instantiated label ledger, checked by F-LABEL
- the register status note for the figure rows

## Rounds

- **R1** this spec plus the composition mock (`prototype.html`, placeholder
  shapes, no values). The room reviews composition.

- **R2** the scripted figure against the real capture walks F-CITE, F-REPRO
  and F-LABEL. The image-reader and the validators take their pass. Deltas
  land.

- **R3** the final pass. Rod does the visual pass. Status moves to approved.

## Open inputs

1. **The capture** (run + row range). This is the one input the pair waits
   on. Candidates for the room: the operating point of the current winner,
   the worst-margin frame of its measurement window, or a `reject_twist` case
   for contrast. The room decides. The extract records the choice.

2. **Annotation rows.** The register rows the title and any readouts cite.

3. **Ring and segment label pin.** The figure uses record indexing (ring 1
   ground … ring N hub, segments ground → hub). Note one drift: the
   dashboard ring bars start their label set at the first checked ring,
   while the rotor labels use record indices. The room pins ONE convention.
   The dashboard harmonises by delta if wanted.

4. **Total-twist readout, a delta option.** If the room wants a total drawn,
   two aggregates exist: `delta_alpha_deg` (the principal-value sum, base
   frame) and the `Σ|Δα|` title of the dashboard (sum of absolute
   per-segment values). The figure draws neither by default. A delta pins
   one.

5. **Glossary.** The display forms of the ledger follow glossary section 6.
   A display-form change flows through this table first.

## Non-goals

The figure re-derives no physics and reads no raw telemetry. No 3D
perspective. No fixed values in this document. The figure does not turn
signed per-segment values into ratios beyond the |Δα| comparison of the
gate.

## Deltas

- v1 (2026-10-08): R1 opens with this spec and the composition mock. No
  values carried. Awaiting the capture, the annotation rows, and the R1
  composition review. R2 to ⟨append⟩. R3 to ⟨append⟩.
