# Value-claims ledger: the class of every element of the value track

**Slug** `value-claims-ledger`. **Status** LIVE, v1 seed (2026-10-16). **Owner** @aero-validator. **Readers** the report-team room and Rod.

The register rule holds every report number to a signed row. The room added one sibling rule on 2026-10-16. A forward-looking claim prints with a label and a pointer, and it never sits in a scored cell. Together the two rules leave two states for a number. It prints under a signed row ID, or it prints as visibly forward-looking. No third state exists.

This ledger states the class of each element of the value track. It serves the section 5 close ("Where this goes") and any later value text. The rule of use comes from the author seat: anything this ledger does not class does not print.

## 1. The three classes

| Class | Binding surface | Rule |
|---|---|---|
| `measured` | a signed register row, by ID | The number prints in signed form only: value, station, state. A claim that cannot hold that form points at the row. |
| `capability` | a landed artifact | What the instrument does. No number attaches. The sentence points at the artifact. |
| `target` | a label and a pointer | A programme goal. It prints under the forward-looking label and no value in a scored cell. The plain label reads `programme target — no repo artifact`. |

The mapping comes from @science-validator (2026-10-16). The visual analogue comes from @fig-img-diagrams. Solid ink stands for landed artifacts and signed values. Open ink plus the label stands for targets, and no target mark sits on a value axis. This desk checks every pointer at HEAD. See `scratch/av_vcl_check.py`.

## 2. Capability elements (the "what the instrument does" movement)

| Element | Class | Pointer |
|---|---|---|
| A TRPT kite-turbine solver in Julia: rotor aerodynamics, tether and shaft dynamics, structural gates | `capability` | `src/`, `README.md` |
| The physics stands on the published TRPT lineage. The cross-check names the matches and the mismatches | `capability` | `docs/validation/2026-09-25-trpt-tulloch-model-crosscheck.md`, `docs/validation/` |
| The campaign pipeline behind this report: decode, build, settle, the ODE run, the gates | `capability` | `scripts/run_v13_5kw_masslift.jl`, `scripts/compute_seeds.jl` |
| Provenance-stamped datasets: era stamp, launch commit, data commit | `capability` | `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/`, `dd3cc6a` on `bankderate2-results` |
| The measured anchor from the Daisy prototype: blade mass, the rated wind pair, the April-29 rig read | `capability` | `DECISIONS.md` [2026-08-21], `DECISIONS.md` [2026-09-24], `handovers/handover-2026-08-20-model-scaling-daisy-anchor.md` |
| The graduated-ladder instrument: it screens each rung and each length on the corrected model | `capability` | `scripts/ode_ladder_v13.jl`, `scripts/results/ladder_v13.csv`, `docs/plans/retrospective-2026-08-17.md` |
| The gates: the register, the test suite, and the seat checks that hold every number | `capability` | `docs/reporting/numbers-register.md`, `test/` |
| The trust practice: findings, corrections, and retractions land in the record with their lessons | `capability` | `docs/agents/instrument-trust-log.md`, `docs/validation/physics-validation-ledger.md`, `reviews/2026-09-15-six-week-review.md` |

## 3. Target elements (the "where this goes" movement)

| Element | Class | Pointer or label |
|---|---|---|
| The 50 kW MVP as the first commercial product | `target` | `programme target — no repo artifact`. The older in-tree mentions sit in the criticised era. See section 6 |
| The ladder above the validated rung: 7 to 50 kW | `target` | Seed rows in section 4 |
| The 1.5 kW Daisy-scale validation step | `target` | `reviews/2026-09-15-six-week-review.md`, `DECISIONS.md` [2026-09-15] |
| Field arrays and the network-of-network programme | `target` | `programme target — no repo artifact`. See section 6 |
| Offshore deployment | `target` | `programme target — no repo artifact`. See section 6 |
| The mission target | `target` | Phase G of `docs/plans/2026-07-06-strategy-gate2-to-value-maps.md`: the displaced-cost metric. The offset figure stays in section 6 |

## 4. The rungs, element by element (the figure-seat seed)

The code set reads 5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0 kW. One row per rung.

| Rung | Class | Pointer or label | Ink |
|---|---|---|---|
| 5 kW | `capability` | The validated rung. `scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/`, `docs/reporting/numbers-register.md` | solid |
| 7 kW | `target` | `programme target — no repo artifact` | open plus label |
| 10 kW | `target` | `programme target — no repo artifact` | open plus label |
| 15 kW | `target` | `programme target — no repo artifact` | open plus label |
| 25 kW | `target` | `programme target — no repo artifact` | open plus label |
| 35 kW | `target` | `programme target — no repo artifact` | open plus label |
| 50 kW | `target` | The MVP rung. `programme target — no repo artifact` | open plus label |

Three ladder notes.

1. The instrument screens exist for the rungs (`scripts/ode_ladder_v13.jl`, `scripts/results/ladder_v13.csv`). A screen is an engineering signal, not a report number. No screen value prints.

2. The recorded gate reads viable for the 5 to 15 kW cells in the design band. It reads "UNPROVEN at 25 kW and above by this gate". No upward-scale sentence may imply a proven design above the validated rung. Source: `docs/plans/retrospective-2026-08-17.md` section 4 and its correction.

3. Earlier ladder phrasings exist (3 to 50 kW in the 2026-08-17 retrospective, 1 to 50 kW in the founder directive). This ledger seeds the current code set. A figure names rungs from one set only.

## 5. The cost and carbon set: print hold

No cost or carbon digit prints in the first fold of the close. The slot waits for a fresh read at this desk. The held set:

| Item | Class | Status | Why held |
|---|---|---|---|
| The target pair in `src/economics.jl`: 4.8 p/kWh and 0.17 gCO2e/kWh | `target` | HOLD | Targets, not outputs (`competitor_comparison`): `docs/reports/grounded-economics-v13.md` section 1 |
| The grounded-economics v13 readings for the 5 kW rung | `measured` | HOLD | The document carries a contamination banner and a gating fix. No reuse before a fresh read |
| The April kit estimates. It quotes £80 to 120 per MWh at 100 kW and £40 to 60 at 500 kW and up. One line quotes 0.81 kW/kg at 50 kW | `target` | HOLD | Era-stale. The figure-seat read stands: `scripts/results/potential/charts/05_lcoe_estimate.png` stays out. Source script: `scripts/produce_kite_turbine_potential_report.py` |

## 6. Flagged set: no pointer in the tree

These elements print nothing until a pointer lands. A fold needs a room call on each one. The plain label covers the programme items.

1. The 50 kW MVP as "first commercial product". No in-tree document carries that phrase. The older mentions (`docs/RECAP.md`, `docs/phase_o_v4_pitch_depower_report.md`, `handovers/handover-2026-06-14-pitch-depower-v3.md`) sit in the era that `docs/reports/CRITIQUE_pitch_depower_campaigns.md` critiques. Do not cite them.

2. Field arrays and the network-of-network programme. Zero hits in the tree. Plain label only.

3. Offshore deployment. No programme artifact. Site-assumption studies exist (`docs/plans/2026-10-03-axial-length-shear-clearance.md`), and they are not a deployment programme. Plain label only.

4. The one-gigatonne offset. Zero hits in the tree. The mission sentence points at phase G. The figure prints nowhere.

5. The yield line for the 50 kW class and the solar comparison. Zero hits in the tree. No pointer exists. This desk recommends no print.

6. The interior rungs of the founder directive (1, 3, 6, 20, 30, 40 kW). They are not in the code ladder. See section 4 note 3.

## 7. Notes on use

- The enforcement region is the close (draft section 5). @author holds the in-fold check: no target-class ink outside it.
- A repeat of a signed number holds value, station, state, or it points at its row. The signed set resolves in `docs/reporting/numbers-register.md`.

- @science-validator counter-reads every row classed `measured` and every row that touches a signed row.
- @fig-img-diagrams draws only the classed rungs in section 4.
- This ledger changes by commit. A class change takes a dated line and a room note. The register stays the numbers' single source.
