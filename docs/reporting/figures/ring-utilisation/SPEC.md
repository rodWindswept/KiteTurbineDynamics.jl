# SPEC: ring utilisation. The beam-column interaction for every checked ring, against the fail boundary.

**Slug** `ring-utilisation`

**Status** SPEC v1, R1 open. This document carries no data values. Angle
brackets ⟨⟩ mark binding slots. A slot resolves at GENERATE. The numbers
register v1 (signed 2026-10-08, `docs/reporting/numbers-register.md`) supplies
the citation discipline. The glossary candidates, section 6 (structural-limit
terms, the mechanism pair) supply the display forms.

**Owner** @figures-images-diagrams. **Companion figure** `twist-limit`. The
pair shares one source family and one shaft frame. **Content check**
@science-validator and @aero-validator. @aero-validator runs the F-VALUE
re-check at the sign-off commit. **Visual check** the multimodal image-reader,
on the visual checklist only. Pixels never validate numbers. Rod does the
final visual pass. **Reader-facing layer** @author. @author slots the pair.
Final numbers land after round three. @author writes the captions under the
register rules.

**Contracts** the reporting framework (figure workflow: SPEC / GENERATE /
CHECK, three rounds, deltas, dual captions). The numbers register (the
firewall). The glossary candidates, section 6. The Track E boundaries
statement.

## Why this exists

The gates name a structural factor of safety. Nothing yet shows the check
itself. This figure shows the ring check. For every checked ring it draws the
beam-column interaction: the axial share plus the bending share in one ratio.

The ratio meets the unit fail boundary. The factor of safety of the ring is
its reciprocal.

The axial share drawn here is where the N/Pcr bar of the dashboard lives.
The report bar adds the bending share. The two bars read as one argument at
two strictnesses.

One honesty note carries from the model record. Nothing buckles in the
model. The check is a post-process fraction, by design with no dynamics
coupling. Any buckled-shape drawing is an explanatory schematic, never
evidence. It carries its label and no numbers.

## What already exists. Extend, do not rebuild.

- `src/ring_element_analysis.jl` solves the per-beam space frame per ring
  and recovers per beam: `N`, `M_ip`, `M_oop`, `T_tor`, `N_crit` and `M_el`.
  The interaction is `utilisation = N/N_crit + √(M_ip²+M_oop²)/M_el`, with
  failure at the unit value. The model tracks torsion, but that column sits outside the
  interaction formula.

- `capture_extended` (`src/sim_frame.jl`) emits the per-ring arrays.
  `ring_util_axial` holds the axial share, `N/N_crit` on the
  worst-utilisation beam. `ring_util_bending` holds the bending share,
  `√(M_ip²+M_oop²)/M_el` on the same beam. `ring_fos` holds the reciprocal
  of the interaction per ring. The same-beam rule guarantees
  `ring_util_axial + ring_util_bending = max_util` at every sample (the A1
  fix). So the stacked bar is the interaction itself, not an approximation.

- The ring check covers all airborne rings. The ground ring stays out
  (ground-supported, not counted against airborne mass). The hub ring stays
  in. It is the hidden weakest ring, and covering it dates to R7, 2026-09-10.

- The dashboard `ring_health!` panel is the visual ancestor (axial share
  only, `R$i` labels).

## Inputs. The extract contract.

1. **Capture.** Same contract as the companion figure: one provenance-stamped
   extract, one run, one declared capture. ⟨capture⟩

2. **Arrays**, per checked ring, in record order:

   - `ring_util_axial[k]`, `ring_util_bending[k]` — emitted shares.

   - `max_util[k]` — the interaction. It equals the two shares summed (the
     identity above).

   - `ring_fos[k]` — emitted, `1 / max_util`. `Inf` where the interaction is
     zero.

   - Identity: ring ids `R2…RN` (record ring index: ring 1 is the ground
     ring, not checked), with the hub ring marked.

3. **Register binding.** Every number in the title, in a readout and in both
   captions cites a signed row. The values of the capture enter the register
   as the source rows of the figure before GENERATE. ⟨rows⟩

4. **Label ledger.** See below. One form per concept, pinned once, reused in
   labels, captions and prose alike.

## The drawing

### Frame, axes, scale

- The pair shares one shaft frame. The ground datum sits at the base. One
  vertical window holds the rows. The rows are the checked rings, `R2` at
  the base and `RN` (hub) at the top.

- The horizontal axis is utilisation. The unit line is the fail boundary.
  The figure labels it "fail boundary". ⟨The axis window resolves at
  GENERATE.⟩

- Per ring, one stacked bar: the axial share and the bending share. The top
  of the bar is the ring interaction. The ring FoS readout at the row
  end reads the emitted `ring_fos`. The model takes the reciprocal, not the
  figure.

- The ground ring appears as a marked base row with no bar: "ground ring —
  not checked (ground-supported)".

- Dashboard warning furniture (`buckling_risk`, `torsional_overtwist`) is
  not report content. The figure draws neither.

- **Companion schematic** ⟨a buckled shape, exaggerated, explanatory. Label
  only, no numbers. Placement (this plate or a separate asset) and home
  (TikZ) resolve at R1. It is never evidence.⟩

### Elements table

| tag | drawn from | drawing rule | asserted |
|---|---|---|---|
| `ring_row` | extract | one row per checked ring, R2 at the base, hub at the top | count |
| `share_stack` | `ring_util_axial`, `ring_util_bending` | stacked bar per row | values |
| `unit_line` | — | the fail boundary at the unit value | presence |
| `fos_readout` | `ring_fos` | row-end readout | values |
| `ground_note` | — | the excluded base row, marked | presence |
| `schematic` | — | explanatory, no data | label only |
| `source_stamp` | — | data commit · extract · run + row range · register rows · script commit · authority commit | presence |

### Readout list. One-to-one with the emitted names.

| Figure string | Emitted name | Where used | Note |
|---|---|---|---|
| ring utilisation | `max_util`, per ring (run level: `ring_max_util`) | bar top, caption | the beam-column interaction (term of record: "ring check") |
| axial share | `ring_util_axial` | stack, legend, caption | `N/N_crit` on the worst-utilisation beam |
| bending share | `ring_util_bending` | stack, legend, caption | `√(M_ip²+M_oop²)/M_el` on the same beam |
| ring FoS | the `ring_fos` vector per ring, or the `fos_ring` scalar for the worst ring | readout | `1 / max_util`, from the emitted array. `Inf` renders ∞ |
| fail boundary | the unit value of the interaction | line label | the caption pins the form: "beam-column interaction", never "Euler" |
| `R2…RN` | record ring index | row labels | ground ring excluded, hub ring included and marked |

The display forms pin here once. Two strings are new to the report: "axial
share" and "bending share". They are candidates for glossary section 6 if
the decomposition stays (@science-writer, Track D).

**Bridge precision for @author.** The axial bar of the dashboard is
`max(N)/max(N_crit)` over the beams of the ring (independent maxima). The
axial share of the report is the same-beam share that completes the
interaction. The two sit in one quantity class. They are not guaranteed
bit-equal. The captions should state the relationship, never an equality of
the two axial components.

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

**Caption plan (dual, from the first figure).** Plain sentence: every ring
meets one strict structural check. This figure shows how much of the check comes from compression and how much comes from bending.

STE technical caption: name the
interaction form (beam-column interaction, with torsion tracked outside the
formula), the unit line, the ground-ring exclusion, the hub-ring inclusion
and the capture. No "Euler". @author writes them. Every number they carry is
a register citation.

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
   the worst-margin frame of its measurement window, or a case from the census
   for contrast. The room decides. The extract records the choice.

2. **Annotation rows.** The register rows the title and any readouts cite.

3. **The home of the schematic.** One plate with the chart, or a separate
   explanatory asset. TikZ either way. Never numbers. The R1 review decides.

4. **Ring label pin.** Shared with the companion figure. One convention
   report-wide. Record indexing proposed: ring 1 ground … ring N hub.

5. **Glossary.** The display forms of the ledger follow glossary section 6.
   The two new strings ("axial share", "bending share") need the ruling of
   Track D.

## Non-goals

The figure re-derives no physics and reads no raw telemetry. No 3D
perspective. No fixed values in this document. No buckled-shape numbers,
ever. The schematic is explanatory. The `T_tor` column stays out of the
drawn interaction.

## Deltas

- v1 (2026-10-08): R1 opens with this spec and the composition mock. No
  values carried. Awaiting the capture, the annotation rows, and the R1
  composition review. R2 to ⟨append⟩. R3 to ⟨append⟩.
