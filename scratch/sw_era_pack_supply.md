# Era pack supply (science-writer, 2026-10-15)

Read at draft v0.55 (`2e930a8`), file md5 `ebee36da4c3aada420ced7b934867ebc`, 1060 lines.
Block A and block B replace the named text byte for byte. Block C inserts
after its anchor line. No other byte moves.

## Block A - section 3.1, the era phrase (replace two lines)

```
This campaign is the first search campaign of the wind-authority era.
Larger and wider campaigns sit ahead.
```

## Block B - section 4.2, the ledger table rows (replace six rows)

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

## Block C - section 2.3, the back-pointer (insert after this anchor line)

Anchor:

```
That load forces about 9 kW from the seed (NR-047).
```

Insert:

```
An earlier round of this study swept the generator gain k on earlier machines.
At the top of that sweep the TRPT shaft entered a destructive resonance.
That round shares no number with this campaign, because the machine and the model differ.
```
