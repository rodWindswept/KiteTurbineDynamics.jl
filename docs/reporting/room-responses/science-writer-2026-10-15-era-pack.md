# Room response: the era pack and the section 2.3 back-pointer (2026-10-15, science-writer)

**Status** LANDED. **Seat** science-writer. **Read at** `9ef8de5`
(draft v0.55, `2e930a8`, md5 `ebee36da4c3aada420ced7b934867ebc`).

**The era call is ruled.** Rod, in the room: "sure add the sentence ...
more facts do not hurt". The pack stands on its own, and the back-pointer
sentence rides with it. The supply for @author sits at
`scratch/sw_era_pack_supply.md`, produced by `scratch/sw_era_pack_check.py`
(20 checks, 0 fail) with the log at `scratch/sw_era_pack_check.log`.

## 1. The era reconcile: the phrase names no era

The draft cites the `physics-validation era` once, at section 3.1 (line
486). The era record names no such era. Two reads carry that finding.

- The era labels live in the provenance stamps. The stamps under
  `scripts/results/` name five: `post-4ce9fd0_daisy-anchored-5kw`,
  `post-807efa6_span3-honest-window`, `post-94223eb_bank-derate`,
  `post-428f491_mass-aware-const-tension_ON` and
  `post-95c385d_wind-authority`. The docs tree adds
  `post-4894787_f4b-taper-reconcile_nrings1_decayck`. No stamp and no
  doc names a physics-validation era (0 hits). The inventory sits at
  `scratch/sw_era_pack_era_inventory.txt`.

- `physics-validation` names a ledger in this record, not an era.
  `docs/validation/physics-validation-ledger.md` holds the claim-by-claim
  record (CONTEXT.md line 255). The section 3.5 table names four eras,
  and the register header names the current label.

**Block A, the supply for @author.** The section 3.1 pair takes the era
the record carries. One line moves. No digit moves, and no row is needed.

```
This campaign is the first search campaign of the wind-authority era.
Larger and wider campaigns sit ahead.
```

The held form, if the room prefers no first-claim: "This campaign runs in
the wind-authority era." then "Larger and wider campaigns sit ahead."

- Grounds: the register header, the dataset provenance stamps, the
  section 3.5 row (`The wind-authority era`), and the section 3.3 era
  note. That note reads "This report covers the wind-authority era
  campaign and the recorded corrections that shaped it."
- The "first search campaign" form holds on the stamps. One campaign
  directory carries the `post-95c385d_wind-authority` label, the
  bankderate2 dataset.

## 2. The section 4.2 table takes date order

The six-row ledger table reads out of date order today:
2026-08-14, 2026-08-26, 2026-08-22, 2026-08-13, 2026-08-24, 2026-08-22.
The earliest entry sits fourth, and the two 2026-08-22 rows split across
the 2026-08-26 row. This seat supplied the table at sweep 16, so the fix
is mine.

**Block B, the supply for @author.** The header and the rule hold. The
six body rows take date order: 08-13, 08-14, 08-22, 08-22, 08-24, 08-26.

```
| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the topmost ring. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |
```

- Every body cell holds byte for byte (30 cells compared). Only the row
  order moves.
- The two 2026-08-22 rows keep their current relative order, because the
  record dates both to the same day.
- The prose after the table stays as it reads. It groups the entries by
  failure class, so its date order is deliberate, not a defect.

## 3. The section 2.3 back-pointer (the ruled sentence)

**Block C, the supply for @author.** Three sentences close the load
block. They carry no value token, because no signed row covers the
earlier round.

Anchor line (draft line 299):

```
That load forces about 9 kW from the seed (NR-047).
```

Insert:

```
An earlier round of this study swept the generator gain k on earlier machines.
At the top of that sweep the TRPT shaft entered a destructive resonance.
That round shares no number with this campaign, because the machine and the model differ.
```

- Grounds: `docs/NOTES_MPPT_TWIST.md` holds the earlier round and its
  4.0x cliff. `docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md`
  section 9 restates the destructive resonance at `k_mult = 4x`. Both
  files read at this pass.
- **Placement note for @author.** No `### 2.3` heading reads in the
  draft at this tip. The load block sits inside section 2.2.2, and the
  2.3 slot stays open per the sweep-16 cascade note. The sentence lands
  after the anchor line either way.
- A digit form ("four times the load multiplier") needs a signed row
  first. The earlier round ran on earlier machines, and no row covers
  it. Route that row to @science-validator if the room wants the digit
  printed.

## Glossary v18 (landed at this seat)

`docs/reporting/glossary-candidates.md` takes four moves.

- One retire row joins section 7: `physics-validation era` retires for
  the wind-authority era.
- Two rows join section 3 from the author seat: the shear law, and
  steady wind. Grounds: NR-056 and NR-058.
- The section 2 elevation-angle row takes the campaign form. Ground:
  NR-057.

## Receipts

- Evidence in `scratch/`: `sw_era_pack_check.py` and its log,
  `sw_era_pack_era_inventory.txt`, `sw_era_pack_supply.md`.
- The draft takes no edit at this seat. The author owns the draft, and
  the three blocks land there as folded text.

## Flags

- @author blocks A, B and C stand as verified text. The ledger table
  fix corrects a sweep-16 supply of mine.
- @science-validator the era-label inventory reads from the provenance
  stamps. No signed row changes, and no new row travels.
- @hermes the queue can read the era call as ruled and the era pack as
  landed. Sweep 33 keys on the next draft push and spans v0.54 and v0.55.

science-writer, 2026-10-15
