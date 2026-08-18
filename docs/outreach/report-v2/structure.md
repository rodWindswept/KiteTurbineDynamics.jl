# Report v2 — narrative architecture (hypothesis-led)

The report is organised as a hypothesis test, not a results dump. Each
section states a claim, shows the evidence, and names its caveat.

## The spine

**1. The hypothesis — what we set out to test**
A multi-rotor kite turbine — rotors mounted on rings along a tensioned,
rotating chain, with configurable blade banking — can deliver useful power
from the wind. The design space is wide: rotor count and placement
(including expansion rotors along the chain), banking angle (0–22°),
line count, ring geometry, chain length (12–40 m), rated power (5–50 kW).
Which of these configurations are viable — and why — is the question the
work answers.
- Figures: F1 (the TRPT concept), F2 (the physics gates every candidate
  must satisfy — the admissibility checklist).

**2. The method — how the hypothesis was tested**
A differential-evolution search swept the configuration space in three
parallel populations per chain length (18.0 / 21.2 / 25.0 m), each
candidate decoded into a full ODE simulation (tensioned chain + BEM
rotors + generator controller) and scored on sustained power at the
ground ring, with hard gates: power floor, ground clearance, chain twist,
tip-speed ceiling, structural factor of safety.
- Figures: F2 (the gates), F4 (the search itself — convergence of the
  three populations per length).

**3. The answer at 5 kW — single rotor won**
All three campaigns converged on the same family: a single rotor at the
minimum hub radius, line count growing with chain length — delivering
7.68 / 8.24 / 8.32 kW at 18.0 / 21.2 / 25.0 m. The multi-rotor and
expansion-rotor configurations were tested and lost; the failure census
shows how (clearance, twist, power shortfall — the dominant rejection
classes). Banking stayed within the swept 0–22° band; the winners' bank
angles are in the design cards.
- Figures: F7 (the census — why the losers lost), F5 (winner design
  cards), F3 (the wider envelope this family sits in).

**4. The envelope — where the family works**
The graduated ladder (5–50 kW × 12–40 m): the baseline family delivers
4.6–8.7 kW at 5–15 kW targets and short-to-mid lengths, degrades with
length, and the 40 m column is the twist wall. The 25–50 kW rows never
spun in the gate — a start-up limitation at scale, so the ladder cannot
yet judge them (the seeds also carry ~3× too little swept area for their
ratings at 11 m/s).
- Figures: F3.

**5. Trust check — the field anchor**
The model's power was validated against the 29-Apr-2020 mast-mount test
(thesis config 9 — the same field data behind Oliver Tulloch's largest
model-experiment discrepancy): model 234 W vs measured 223 ± 79 W at
6.25 m/s; system Cp ≈ 0.16 for both, against Oliver's spring-disc
Cp_max = 0.166. Three independent derivations agree at the plateau. The
measured "curve" was a controller ceiling, and the raw extreme bins were
gust transients — both shown, not hidden.
- Figures: F9 (the anchor).

**6. What went wrong — and what it taught us**
The path to valid results ran through instrument faults and model
exploits: a crowned "winner" that was hub freewheel, diverged hubs
reading healthy at the ground, unbounded rope tension, no high-TSR brake,
torque without saturation. Each fix (Betz gates, C1 saturation, rope
break, hub-sanity gate) closed an exploit the search had found. One
campaign generation was voided after the fact and is kept as evidence —
the admissibility checklist exists because of it.
- Figures: F6 (the voided vs corrected traces), F8 (failures-and-learnings
  table).

**7. Implications — and the next rung**
The 5 kW proof stands on a model the field data endorses. The
multi-rotor question is answered at 5 kW and open at scale: the losing
families may come into their own where more rotors share the Betz budget
(pool analysis, pending). Next: the 7 kW rung, then a fair test of ≥25 kW
(rotors sized from the power budget — area ∝ rating — and a gate that can
start them).
- Figures: F3 + F7 revisited; W2 pool analysis.

**8. Reproducibility + comparison with prior and parallel work**
One command per step, ~11 h single machine (REPRODUCIBILITY.md);
comparison with the Daisy line and the thesis.

## Figure roles (one sentence each)

| Figure | Role in the argument |
|---|---|
| F1 | What a TRPT kite turbine is (concept) |
| F2 | The physics gates — the standard every candidate was held to |
| F3 | The envelope: where the family delivers, where it twists, where the data can't judge |
| F4 | The search: three campaigns converging (method evidence) |
| F5 | The winners — the single-rotor family the hypothesis test produced |
| F6 | Evidence discipline: the voided attempt kept, not hidden |
| F7 | The census: why the losers lost (clearance, twist, power) |
| F8 | Failures-and-learnings table |
| F9 | The anchor: model vs field test — the trust argument |

## Claims → evidence (each section's caveat is named)

| Claim | Evidence | Caveat |
|---|---|---|
| Multi-rotor/banking configs were genuinely tested | F7 census + campaign telemetry | Family-level breakdown needs the W2 pool analysis (data-ready) |
| Single-rotor wins at 5 kW | Winner regates 7.68/8.24/8.32 kW | 5 kW only; scale question open |
| Model power matches the field | F9: 234 vs 223 ± 79 W, Cp_sys ≈ 0.16 | Speed gap (λ 7.6 vs 4.35) — thesis's own 6-blade caveat |
| ≥25 kW unproven, not impossible | F3 hatched cells | Gate start-up limitation + seed area 3× short; fix list known |
