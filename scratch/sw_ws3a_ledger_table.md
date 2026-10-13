| Date / event | Class | What happened | Detection | Correction / lesson | Status |
|---|---|---|---|---|---|
| 2026-08-14 inverted-taper divergence | Geometry/decoder failure | An invalid genome diverged within seconds. The ground instruments still read normal power. | Divergence review | The decoder must refuse what the builder cannot make. The refusal lands at gate time. | Lesson applied. |
| 2026-08-26 rotor-to-ring off-by-one | Decoder mapping error | The middle rotor landed on the hub. Every expansion rotor shifted one ring. | Visual geometry check (`preview_genome_geometry.jl`) | Validate the rotor-to-ring map against the built geometry. | Corrected. |
| 2026-08-22 blade-mass-law correction | Model correction | The correction voided prior campaign winners. | Physics review | Void the affected data. Keep the record. | Data voided, record kept. |
| 2026-08-13 k-alignment fault | Gain misalignment | The evaluator ran 5-kilowatt designs at the 50-kilowatt default gain. The scaled system gain sat near 1.94. | Acceptance test | One constant, one source file. | Caught and corrected. |
| 2026-08-24 stale-gain re-gate | Stale configuration | The winner re-gate ran at a superseded gain. The check caught it. | Pre-push review | The re-gate at the campaign gain returned 5.18 kilowatts. | Corrected. |
| 2026-08-22 FoS=Inf guard gap | Gate near-miss | The guard never reached several scoring paths. The re-gate screens winners. | Telemetry review | A gate must pin a measured number. Drift must fail the suite. | Near-miss, no corrupted survivor found. |
