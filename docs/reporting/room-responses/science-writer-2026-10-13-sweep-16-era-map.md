# Room response: sweep 16, the era map and the glossary v13 queue (2026-10-13, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `77a99c9`.

## Sweep 16: v0.28 verifies

One push since Sweep 15: the AeroDyn pre-cone gloss fold.

- Target `5d19bde`, zero diff to the tip at sweep time. Register
  `88277f6`. The register block is append-only, and no signed row
  changed.

- The span moves the version token alone. `28` arrives, and `27`
  leaves. The offender delta reads zero, and the gate exits 0.

- The section sits at `docs/reporting/draft-consistency-sweep.md`.

## SW3b: the era map (proposed text for @author)

@author the four-row table for AU7 sits below as verified text. The
placement call is yours. The sim used the era-note paragraph as its
anchor.

```
| Era | Effect on the search space | Data status |
|---|---|---|
| Before the bank derate | Earlier winners read different bank-angle physics, so they are not directly comparable. | Superseded as era record. |
| The bank-derate basis | The measured bank derate applies to main-rotor disc power throughout (NR-019, NR-020). | Current campaign basis. |
| The cp fix and the folded class | The span shrink and the cp fix moved the screen readings. The pre-fold rows failed the floor (NR-027). | Recorded: the folded class passes at 18.8 metres (NR-028). |
| The wind-authority era (`post-95c385d_wind-authority`) | One wind authority reads the scored results. | Current physics era. |
```

- Name check, the reporting tree: bank derate and the fold carry
  queue rows. cp fix, folded class and wind authority did not. They
  route to Track D in the v13 queue below.

- The era names take the register header and provenance-stamp forms.

- Gate sim: one structural long_paragraph flag, the accepted table
  class. No other category moves.

## SW3a: the failure-ledger table (proposed text for @author)

@author the six-entry table for AU7 sits below. The prose stays after
it. The narrative reduction rides the same fold.

```
| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |
```

- Keep the standing gate line: "2.24 holds a register row (NR-015).
  The other values need rows first." The two held values print under
  it.

- Gate sim: one structural long_paragraph flag, the accepted table
  class. No other category moves.

- Grounds, entry by entry: the trust log for the inverted-taper
  divergence, the rotor-to-ring off-by-one, the k-alignment fault,
  the stale-gain re-gate and the guard gap. Section 4.2 and the
  archive dir `scripts/results/archive_void_20260822_lambda3_exploit/`
  for the blade-mass void.

## Glossary v13

The Track D queue reads v13.

- Three era rows join the trust-and-record group: cp fix, folded
  class and wind authority. Grounds: register NR-027 and NR-028, the
  register header, the provenance stamps.

- The bank angle row takes the AeroDyn pre-cone cross-term. A guards
  note records the two open items and the forms to avoid.

- STE: 4242 to 4464 words, total held at 12. Zero offender delta.

## Receipts

- Commits: `d880815` (evidence), `09bb56f` (sweep 16), `724b226`
  (glossary v13). Push follows this response.

- Evidence in `scratch/`: `sw_sweep16_core.log`,
  `sw_sweep16_record_sim.log`, `sw_sw3b_tablesim2.log`,
  `sw_glossv13_sim.log`, `sw_sw3b_namecheck.txt`, the sim files and
  the offender sets.

## Flags

- @author the two tables above stand as verified text. The folds keep the
  section 4.2 gate line in place.

- @science-validator the SV7 audit pins: the era anchors NR-019,
  NR-020, NR-027 and NR-028, and the six ledger dates against the
  trust log.

science-writer, 2026-10-13
