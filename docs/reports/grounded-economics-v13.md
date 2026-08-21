# Grounded economics of the validated 5 kW rung — v13, corrected model

> ## ⚠ CONTAMINATED — READ FIRST (2026-08-20)
>
> **The 5 kW winner numbers in this document (§3, and every LCOE/CO₂ value
> derived from them) were produced under a mass-blind objective carrying
> 50 kW blade mass (12.0757 kg/blade, the 50 kW base, NOT rung-scaled and NOT
> λ-scaled — see §4b).** The masses are model-true but the designs are
> **power-maximising artefacts, not design optima**; the lift tension that
> gated them was sized ~9× too high; and the economics describe machines no
> sane engineer would build. **Do NOT quote any §3 number externally.**
> The fix (rung-scale + λ²-scale blade mass in `build_system_from_v10`) and
> the 5 kW re-run are the gating items before these numbers become usable.
> The F9 anchor result (234 W vs 223±79 W, §6) is from the separate April-29
> rig and is NOT affected.

**Date:** 2026-08-20 (session)
**Status:** FINDINGS — for review; **the blade-mass question below gates every
economic conclusion**. No `src/` changes; script + CSV + this doc only.
**Script:** `scripts/report/grounded_economics_v13.jl` (new, uncommitted)
**Output:** `scripts/results/grounded_economics_v13.csv` (9 rows)
**Model era:** HEAD `4e26d29` (fast/slow suite split) + uncommitted working tree;
decoder/build path identical to `scripts/ode_gate_v13.jl`.
**Julia note:** this checkout runs via `/snap/julia/current/bin/julia` with
`JULIA_DEPOT_PATH=$PWD/.julia_depot:~/.julia` (see `.gitignore` entry — sandbox
workaround for a read-only `~/.julia`).

---

## 1. Why this document exists

The near-term goal is to get out of theory and propose **viable field tests for
funding**. A funding reviewer's first questions are cost and carbon. The repo's
`src/economics.jl` `competitor_comparison()` table quotes TRPT at **4.8 p/kWh
and 0.17 gCO₂e/kWh (10 kW)** — but those are *targets*, not outputs of the
corrected model. This document recomputes CO₂/kWh and LCOE from the **actual
validated 5 kW rung winners**, using the campaign's own build path and mass
function, with every assumption separated from every model/measured value.

## 2. Method and provenance chain (no new ODE compute)

For each of the three winners (`v13_5kw_len18.0/21.2/25.0`):

1. **Genome** — `best_vector.csv` (14 values) from `scripts/results/`.
2. **Power** — `P_gen` at 11 m/s design wind from `regate_verdict.md`
   (7.678 / 8.243 / 8.322 kW sustained at the ground ring, corrected model,
   mass-aware gate, all structural checks green). **Provenance: recorded
   verdicts; see §5 for a decoder discrepancy that requires re-gating.**
3. **Decode + build** — exactly the gate's path: `params_at_length(p2, L, KW)`
   → `design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=5 kW)` with the
   gate's rounding (`x[8]` → `round(clamp(·,3,16))`, `x[10]` clamp) →
   `build_system_from_v10(dec, 1.0, k; tether_diameter=p.tether_diameter)`.
4. **Masses** — the campaign-authoritative decomposition
   `expansion_airborne_mass(sys, pc)` (tether + rings + main blades +
   expansion rotors + 5 kg lifter) plus knuckles (15 g each, one per line per
   ring). **Cross-check: the 18.0 m winner total reproduces the recorded
   `lift_retrospective_note.md` value to the gram (138.93 kg).**
5. **Economics** — `Economics.compute_capital_cost` on the genome's params
   (`pc`) with `p_rated_w` overridden to the **delivered** power (7.7–8.3 kW;
   `pc.p_rated_w` is the 50 kW base and is not this machine's rating).
   LCOE and gCO₂/kWh computed over AEP = delivered power × CF × η_gen × 8766 h,
   with η_gen = 0.90 folded in (mechanical → electrical).

## 3. Results (grounded, current model)

| Length | P_gen@11 m/s | Airborne | **Blades** | φ | Capital | LCOE @ CF .30 | Embodied CO₂ | **gCO₂/kWh @ CF .30** | Payback @ CF .30 |
|---|---|---|---|---|---|---|---|---|---|
| 18.0 m | 7.678 kW | 138.9 kg | **132.8 kg (96%)** | 18.1 kg/kW | £25,161 | 15.8 p/kWh | 3,634 kg | **10.0** | 10 mo |
| 21.2 m | 8.243 kW | 139.3 kg | **132.8 kg (95%)** | 16.9 kg/kW | £25,311 | 14.8 p/kWh | 3,663 kg | **9.4** | 10 mo |
| 25.0 m | 8.322 kW | 163.8 kg | **157.0 kg (96%)** | 19.7 kg/kW | £28,243 | 16.4 p/kWh | 4,252 kg | **10.8** | 11 mo |

Sensitivity (CF 0.20 → 0.40, η_gen 0.90 fixed): LCOE 22–25 p/kWh → 11–12 p/kWh;
gCO₂/kWh 14–16 → 7–8.

## 4. Finding 1 — THE decision: the blade-mass treatment gates everything

**Blades are 95–96% of airborne mass, 88% of embodied CO₂, ~63% of capital
cost.** The main-rotor blade mass comes from `build_system_from_v10`:
`p_base.m_blade · le²` with `p_base = params_v5_50kw()` (the **50 kW** base,
mass-scaled: 1.375 kg → 12.07 kg per blade) and `le = 1.0`. It does **not**
scale with the 5 kW rung, and it does not scale with the genome's λ values.

The internal inconsistency (same genome, same build):
- main rotor blades: **132.8 kg** (11 blades × 12.07 kg)
- expansion rotor(s) of the same genome: **0.37 kg total** — λ-scaled via
  `expansion_blade_mass(blade_tip_radius·λ, …)`.

So the aero scales with λ but the main-blade mass does not. The power side is
credible (F9 anchor: Cp_sys ≈ 0.16 on both sides; the 7.7–8.3 kW at 11 m/s is
physically consistent with the 5 m rotor). The mass side is the open question.

**Consequence:** the grounded verdict on the current model is
**LCOE 14.8–16.4 p/kWh @ CF 0.30 — not competitive** (~3× onshore wind's
5.5 p/kWh, ~3× the repo's own 4.8 p/kWh target). Carbon is **9.4–10.8 gCO₂e/kWh
— still ~25× below the UK grid (233) and ~4× below solar PV (41)**, so the
"low CO₂/kWh" claim survives even with heavy blades; the *cost* claim does not
at 5 kW as modelled.

**If** the blade mass is instead rung-scaled (mass_scale factor 0.392 →
0.86 kg/blade → ~9.5 kg blades; airborne ≈ 16 kg; φ ≈ 2 kg/kW), blade shares of
cost and carbon fall ~90% and the LCOE verdict likely flips toward viability.
**The physics decision on blade-mass scaling therefore determines whether the
5 kW rung is viable or not — it is the gating item before any funding-facing
number is published.** Options: (a) rung-scale `m_blade` via the same
`mass_scale` factor as the rest of the machine; (b) λ²-scale main blades like
the expansion rotors; (c) keep the 50 kW-base blades as a deliberate
conservative bound. This needs a DECISIONS.md entry.

### Root cause — CONFIRMED (2026-08-20, checked with a second bot)

Rod's hypothesis — *"the 5 kW campaign is not penalising low power-to-weight
ratio devices enough"* — is **confirmed, and it is stronger than "not
enough": the objective actively prefers heavy designs.** Two confirmed parts:

**Part 1 — the 50 kW blade-mass contamination (mechanism verified in code):**

- `build_system_from_v10` hard-codes the 50 kW base: `src/objective_evaluator
  .jl:280` `p_base = params_v5_50kw()`, and `:307`
  `mat = MaterialSpec(tether_diameter, p_base.e_modulus, m_ring_design,
  p_base.m_blade * le^2)` with `le = blade_scale = 1.0` (`:391-393`).
- `params_v5_50kw().m_blade = 12.0757 kg` = 1.375 kg × (50/10)^1.35 — a
  genuine 50 kW mass. `n_blades = n_lines`, so blade mass = 12.0757 × n_lines
  (the 132.83 / 156.98 kg measured).
- The campaign's own base (`params_at_length` → `mass_scale(10 kW → 5 kW)`)
  gives **m_blade = 0.863 kg — a 14× discrepancy**. The build silently
  ignores the campaign's scaled base.
- λ scaling applies to geometry and the **expansion rotors** (hence
  m_expansion = 0.37 kg) but **not** to the main-rotor blade mass. The
  comment at `:391-393` ("the genome's λ values already scale blades") is
  true for tip radius, false for mass.
- Consequence: power ∝ lines (BEM), mass = 12.0757 × lines, no mass penalty
  in `v12_fitness` → the DE chases power via lines with no mass cost. The
  mass-aware lift tension was inflated ~9× (2,175 N for the 18 m winner vs
  ~240 N at 0.863 kg/blade), so the winners were gated at a tension sized for
  a machine 9× heavier than a true 5 kW one.

**Part 2 — why the mass penalty was removed (recorded, DECISIONS.md):**

- The V10 objective WAS mass-minimising (`objective_v10.jl:239` returns
  `total_mass × power_penalty`). DECISIONS.md [2026-06-21] "V10 v2 diagnostic
  campaign" records the conflict: *"Lower mass always wins, a second rotor
  always costs mass"* — the mass term drove the DE to single-rotor,
  minimal-mass designs, converging λ→0 to save blade mass (∝ λ³) while the
  equilibrium solver compensated with higher ω — but the rotor lacked startup
  torque to reach that ω in the ODE. The V10 winner (island 41, 76.75 kg,
  1 rotor) was dynamically dead: 0.0 kW, −2 rpm, 144 slack lines.
- V11 flipped to pure power (`v11_fitness = -P_mean / fos_penalty`, mass term
  gone). V12/V13 kept power scoring; [2026-08-13] additionally removed the
  ceiling penalty and the FoS soft target (the below-target quadratic
  "favoured light/unloaded structures").
- **The irony:** the mass penalty was removed because mass-in-the-objective
  broke the optimiser — and now the objective has no mass term at all, so the
  50 kW blade-mass contamination is invisible to the DE. It only shows up in
  the mass-aware lift tension and FoS.

**Empirical evidence** (18.0 m telemetry, 663 OK designs): corr(fitness,
mass) = −0.175; the best-5 designs are all 139–151 kg; the lightest-5
(41.8 kg) score −3.6 to −4.7 vs the winners' −6.23; the heaviest-5 (200 kg)
score up to −6.2.

**Verified fix direction** (pending Rod's go — physics change, DECISIONS.md
entry required):
1. `build_system_from_v10` gains a `base_params` kwarg (default
   `params_v5_50kw()` → 50 kW campaign bit-identical at λ=1); the evaluator
   (`:393`) and gate pass the campaign's scaled `p`.
2. Main-rotor blade mass scales with the genome's λ: `m_blade =
   base_params.m_blade · λ_eff²` with `λ_eff = rotors[1].blade_scale` (already
   computed at `:426`). At 5 kW: ≈ 0.863·λ² kg → airborne ≈ 16 kg at λ=1,
   φ ≈ 2 kg/kW, lift tension ≈ 240 N.
3. Land (1) first (rung fix, 50 kW bit-identical), then (2) (λ² fix) as a
   separate verified change.

**Re-run cost estimate:** 930 evals/length (10 pop × 3 islands × 30 gen),
~1–3 min/eval (acceptance-suite bound) → ~15–30 h/length, ~45–90 h for all
three, sequential. Recommend: fix + fast smoke (1 island, few gens) first,
then one length (21.2 m) full re-run, then the rest. The runner prints exact
wall time ("Campaign complete in …s").

## 5. Finding 2 — provenance discrepancy: decoder n_lines vs recorded verdicts

The current decode yields n_lines = **11 / 11 / 13** for 18.0 / 21.2 / 25.0 m,
but the recorded regate verdicts state **12 / 14 / 16** (and r_hub 0.702 vs
0.700 decoded now). The verdicts (2026-08-15) predate later decoder/lift
changes (2026-08-19/20). **Follow-on: re-gate the three winners on current
HEAD and confirm P_gen bit-consistency before the §3 numbers are quoted
externally.** The economics conclusions (blade dominance) are insensitive to
this ±1–3-line difference.

## 6. Assumptions ledger (measured/model vs assumed)

| Quantity | Value | Status |
|---|---|---|
| P_gen @ 11 m/s | 7.678 / 8.243 / 8.322 kW | **Model output** (regate verdicts, corrected model, mass-aware gate) |
| Cp_sys ≈ 0.16 | — | **Measured-vs-model** (F9 anchor: model 234 W vs 223±79 W measured; Oliver 0.166) |
| Component masses | §3 table | **Model output** (decoded genomes, design-aware ring mass, campaign function) |
| Generator efficiency η_gen | 0.90 | Assumption (sensitivity not yet run; flag) |
| Capacity factor | 0.20 / 0.30 / 0.40 | Assumption (AEP from a single 11 m/s point × CF — a P(v) curve from the anchor machinery is the follow-on) |
| Lifetime | 20 y | Assumption (Economics default) |
| Discount rate | 7% | Assumption (Economics default) |
| Grid intensity | 0.233 kgCO₂/kWh | Assumption (Economics default, UK 2026) |
| Carbon factors | CFRP 24, Dyneema 5, steel 2 kgCO₂/kg; GFRP ≈ CFRP proxy; generator 10 kgCO₂/kW | Assumptions (Economics defaults; literature values — cite in the report) |
| Cost model | `default_cost_model_2026` (blades £120/kg, Dyneema £40/kg, CFRP £25/kg, gen £200/kW…) | Assumption (small-batch 2026 pricing) |
| Lift kite / lifter | 5 kg airborne, cost via Economics lift-kite line | Assumption (Economics convention) |

## 7. Comparison with prior claims

| Claim | Source | Grounded 5 kW rung (CF .30) |
|---|---|---|
| LCOE 4.8 p/kWh (TRPT 10 kW) | `competitor_comparison()` | **14.8–16.4 p/kWh** (current model) |
| Carbon 0.17 g/kWh (TRPT 10 kW) | `competitor_comparison()` | **9.4–10.8 gCO₂e/kWh** (current model) |

The old table's numbers are **unvalidated targets**; the grounded values are
~3× and ~55–65× those targets respectively. Neither claim is publishable until
Finding 1 is adjudicated and the winners re-gated (§5).

## 8. Full-system scope — prior Windswept costings (production-scale anchors)

**Steer from Rod (2026-08-20):** the most reliable design data comes from the
*smallest* systems — the only ones actually built and flown. 50 kW is the
aspiration, not the evidence base. And LCOE/LCA must include the whole system:
ground station, lift-device launcher, field transport, maintenance, and all
other scoped cost/emissions factors — plus reliability and output detail.

**Second steer (2026-08-20):** every figure below is **historical** — the
workbooks date from 2021–2023 — and global prices have restructured and
inflated since. A blanket CPI uplift is only the *floor*: cumulative UK CPI
2021→2025 was ≈ **+23%** (in2013dollars/officialdata UK series), and proper
re-modelling means re-pricing each category at 2026 levels (CFRP, Dyneema,
electronics, batteries, shipping, labour have moved differently). **None of
the £/p-kWh values in this section may be quoted as current.** The **10 kW
proposal case** (the L3-autonomous v4/v5 workbook: Phase 1 prototyping → 2 →
3 production, P&L forecast, 18-month balance sheet, FMEA-derived parts) is the
**most thoroughly analysed system so far** and is the designated base for the
2026 re-modelled full-scope workbook; the §3 airborne masses/power from the
validated model feed it as inputs.

The Windswept drive
(`/mnt/Windswept Energy/10kW Design/legacy KITE TURBINE & DAISY STANDARDS/…`)
holds four prior **production-scale** full-scope cost models (300-unit runs):

| Model | Unit production cost | LCOE (retail / producer-run) | CF | Turbine life | System life | Scope highlights |
|---|---|---|---|---|---|---|
| **Daisy 3–5 kW** (Polygonal remodel) | £2,162 | 3.66 / 2.29 p/kWh | 0.36 | 6 y | — | lifter, backline, top bearing, blades £150, PTO wheel, **head/thrust bearing £439**, motor £270, frame, **ESC £280**, control housing, anemometer £65, **BMS+battery+inverter £600** |
| **10 kW L3 autonomous** (v4) | £9,016.5 | 13.18 / 7.96 p/kWh | 0.38 | **1.5 y** | 10 y | KAP lifter 30 m² + pod controller, 360° backline winches/turret, gearbox £154, **5 kWh battery £2,015**, ESC £410, prototype phase £421.6k, eng. dev. £207.6k, shipping/returns, replacement turbines, service contract |
| **1.8 MW (18×100 kW) L4** | £745,333 | — | 0.39 | 3 y | 16 y | 18-lifter net, blade control sets, hemisphere ground track £2.0M, comms/software, replacement turbines, ~£15k/yr service |
| **10 MW L5** | £5,259,000 | — | 0.38 | 4 y | 16 y | autonomous network, same scope categories |

**What this means for the grounded numbers (§3):**

1. **Scope.** The §3 figures are a *prototype-scale* estimate of airborne + a
   simple ground station (~£25k capital, 14.8–16.4 p/kWh @ CF 0.30). The prior
   models show the full-scope LCOE is dominated by the support system and by
   **lifetime/reliability assumptions** (turbine life 1.5–6 y, replacement
   turbines, service contracts, battery/inverter/electronics) — exactly the
   categories Rod listed. A prototype is not a production machine in costs,
   and neither is directly comparable to the other.
2. **Reliability and output detail.** CF 0.36–0.39 assumed across all prior
   models; turbine lifespan 1.5–6 y drives replacement cost. These are the
   reliability assumptions a field test must measure (run-hours, fault rate,
   twist margin), not accept on faith.
3. **The model's role.** KTD.jl sizes and stress-tests the *airborne* machine
   (masses, power, structure). The production LCOE/LCA boundary belongs to the
   cost-model workbooks, which already exist on the drive. The correct next
   step is to feed the model's grounded masses/power into a full-scope
   LCOE/LCA workbook (the §3 airborne numbers become one input line, not the
   whole answer).
4. **R&D must be scoped before reliable cost forecasting (Rod, 2026-08-20).**
   The 10 kW project closed because *safe lift-kite scaling* could not be
   resolved; the pivot was to smaller-system R&D + **active lift systems**
   (the autogyro-stack line, `CoaxialAutogyroStacking.jl`). Any credible
   2026 full-scope LCOE/LCA therefore carries an **R&D amortisation line**,
   and the lift-system R&D has its own funding structure (prototype path
   ~£500 + travel for rotor 1 — see the field-test proposal §2c/§3).

**Where the full-scope machinery lives (drive, via `Source_Inventory.md`):**

- **Full-scope LCOE lineage** (same phased structure — Phase 1 prototyping →
  Phase 2 pre-production → Phase 3 production, L3 autonomy, battery+inverter,
  launcher pulley, backline winches, shipping, service):
  `04_Business/Business Plans & Models/financing models/10kW -100kW Kite
  Turbine Porduction LCOE - R&D Pilot 12-02-21.xlsx` (2021) →
  `…/LCOE evaluation/10kW Kite Turbine Porduction L3 autonomous with LCOE
  v4/v5.xlsx` → `1.8MW 18x100kW L4` → `10MW L5` (all under `10kW Design/
  legacy KITE TURBINE & DAISY STANDARDS/`).
- **Reliability/FMEA**: `04_Business/Business Plans & Models/project
  management/10kWautoKT FMEA Spec Validation deliverables.xlsx` (the "Parts
  from FMEA" source behind the Daisy costings) + corporate Risk Register.
- **Unit economics / business model**: `04_Business/Business Plans & Models/
  business model canvas/Business cost Model Sharavan 3-5kW Daisy.pptx` and the
  `10kW Kite Turbine Autonomy 31-03-22…xlsx` financing model.
- **Historical carbon target:** the mission doc's **0.7 gCO₂e/kWh** target
  (Purpose Mission Goals.docx, noted in `Source_Inventory.md`) is *another*
  unvalidated aspiration, alongside `competitor_comparison()`'s 0.17 g/kWh —
  both far below the grounded 9.4–10.8 g/kWh and the Daisy-scale full-scope
  reality; neither should be quoted until the full-scope workbook is built.

## 9. Plain-language glossary (terms used above)

| Term | Meaning |
|---|---|
| **LCOE** (Levelised Cost of Energy) | The cost of each unit of electricity over the machine's life, in pence per kWh — capital + running costs ÷ total energy produced. The number to compare against other generation. |
| **LCA** (Life Cycle Analysis) | Counting ALL greenhouse gas from making, running and disposing of the machine, in grams of CO₂-equivalent per kWh. |
| **Capacity factor (CF)** | The fraction of the rated power actually produced on average over a year (wind doesn't blow at rated speed all the time). 0.38 = 38%. |
| **φ (mass per kW)** | Airborne weight per kilowatt of power — a scaling metric. Lower is better. |
| **Re-gate** | Re-run the acceptance check (the physics "gate": power, twist, tip speed, clearance) on the three winning designs with the *current* code, to confirm the recorded results still hold after later changes. |
| **P(v) curve** | The measured power produced at each wind speed — the real-world power-vs-wind curve, needed to compute energy output without assuming a capacity factor. |
| **Autonomy level (L3/L4/L5)** | How independent the machine is: L3 = supervised autonomous operation; L4 = networked with automatic control; L5 = fully self-managing network. |
| **Finding 1 (blade mass)** | The model's 5 kW winners carry 12 kg each of blades sized from the 50 kW design. Whether that is real or a modelling scale-up error decides whether the small machine's economics look viable. |

## 10. Recommendations

1. **Fix the blade-mass contamination (new top priority — confirmed §4b):**
   add `base_params` to `build_system_from_v10` (rung-scaling; 50 kW
   bit-identical), then λ²-scale main-rotor blade mass. Both changes
   verified in direction; needs Rod's go + DECISIONS.md entry + acceptance
   re-run (fast suite + `test_evaluator_v13.jl`).
2. **Re-run the 5 kW rung** (21.2 m first) with the fixed build and a
   mass/φ-aware objective — the winners will shift to light machines
   (~16 kg airborne, φ ≈ 2 kg/kW expected) and the §3 economics must be
   recomputed. Estimated ~15–30 h/length (930 evals/length, ~1–3 min/eval).
3. **Adjudicate the objective's mass term** (Finding 1/Part 2): restore the
   `fos_target > fos_hard` FoS-above pressure and/or an explicit φ target at
   Daisy-scale (~1–2 kg/kW production; prototype-realistic 3–5 kg/kW) —
   Rod's call, DECISIONS.md entry.
4. **Re-gate the three winners on current HEAD** (§5) — still needed for the
   recorded-power claims, but note their lift tension was sized ~9× high.
5. **Build a P(v) power curve** from the anchor machinery (April-29 rig +
   corrected model) so AEP uses a wind distribution instead of CF × one point.
6. **Full-scope LCOE/LCA workbook** — feed the *fixed* model's masses/power
   into the Windswept cost-model structure (Daisy/10 kW L3 scope). Prior
   workbooks on the drive are the starting point; historical prices need
   2026 re-pricing (CPI floor ≈ +23% since 2021).
7. **Recompute economics** after 1–6, then draft funding-facing numbers —
   prototype ≠ production costs; smallest built systems are the most reliable
   data (50 kW is the aspiration, not the evidence).
8. Do not reuse the `competitor_comparison()` TRPT rows in any outward
   material until 1–7 are done.

## 11. Fix status (2026-08-20 — implemented, suites green)

The two approved fixes are implemented and verified on the fast suite
(1912/1912 green); the acceptance suite is being re-run.

**1. Blade-mass contamination fix (`src/objective_evaluator.jl`
`build_system_from_v10`):** added `base_params` kwarg (default
`params_v5_50kw()` → legacy callers bit-identical) and λ_eff² main-rotor
blade-mass scaling (`λ_eff = rotors[1].blade_scale`, the same convention as
the k_mppt λ²-scaling). `evaluate_windowed`, `ode_gate_v13.jl`, and the
economics script pass the campaign's rung-scaled base.

**2. λ rename (λ reserved for TSR only):** genome genes x13/x14 →
`blade_scale_top`/`blade_scale_bottom` across the decoder
(`src/objective_v10.jl`), campaign runners' telemetry headers, the genome
chooser, recampaign, export/plot tools (backward-compatible reads of
historical `lambda_top`/`lam_top` CSVs), `docs/agents/genome-glossary.md`,
and `CONTEXT.md`. λ now means tip-speed ratio only.

**Before → after on the SAME (old, mass-blind) winners — fixed mass model:**

| Length | Airborne | φ | Capital | LCOE @ CF .30 | gCO₂/kWh @ CF .30 |
|---|---|---|---|---|---|
| 18.0 m | 138.9 → **6.30 kg** | 18.1 → **0.8** | £25.2k → **£9.2k** | 15.8 → **5.8 p/kWh** | 10.0 → **1.24** |
| 21.2 m | 139.3 → **7.02 kg** | 16.9 → **0.9** | £25.3k → **£9.4k** | 14.8 → **5.5 p/kWh** | 9.4 → **1.26** |
| 25.0 m | 163.8 → **7.01 kg** | 19.7 → **0.8** | £28.2k → **£9.4k** | 16.4 → **5.5 p/kWh** | 10.8 → **1.24** |

**Honest caveats on these after-numbers:**
- The winners were still *optimised* under the old mass-blind objective; a
  mass-aware re-run will find different (better) designs. These numbers show
  the mass model corrected, not the final design.
- Their blade mass is now consistent with the genome's λ (0.02–0.05 kg/blade
  at λ≈0.14–0.6), but that exposes a **separate physics item**: the main
  rotor's BEM power uses rotor_radius = 5.0 m regardless of λ, so power is
  NOT λ-scaled while mass now is. Whether the DE exploited that (tiny blades,
  full power) must be examined in the re-run — flag for the objective work.
- **P_gen under the fixed build: NOT YET MEASURED (corrected 2026-08-20).**
  An earlier claim here that the 18 m winner "stalls at 1.09 kW / power was
  lift-tension-dependent" was WRONG — it misread acceptance test D, which
  runs the **v12_5kw_coldstart** winner (a different, already-void campaign)
  under **rotary_lifter_default()** (≈2,224 N), not the v13 18 m winner under
  the mass-aware lift. The v13 winners' power with the corrected masses and
  the mass-aware lift (~99 N at 6.3 kg airborne) must be measured by
  re-gating — pending. The economics script's P_gen column is the OLD
  recorded value and must not be quoted until the re-gate.

**Third fix (2026-08-20): main-rotor radius was λ-blind — RESOLVED.**
`build_system_from_v10` hard-coded `rotor_radius = 5.0·le` for the hub rotor,
so the ODE swept area (∝R²), TSR and blade chord ignored BOTH the rung
(`rotor_radius_for_power` sizes r_rotor per P) AND the genome's blade_scale —
aero power was λ-blind while blade mass was λ²-scaled. **The DE exploited
this (as the k_mppt λ²-scaling comment history warned): λ→0 blades with full
5 m-disk power.** Now `rotor_radius = hub_rotor.blade_tip_radius`
(= r_rotor × blade_scale), completing the λ² intent.

**Consequence — the re-gated numbers above are now SUPERSEDED:** the 18 m
winner (λ=0.143 → 0.46 m swept disk, Betz cap ≈ 0.3 kW) re-gates to **0.0 kW
under the fully-corrected physics**. The old winners were exploiting the
phantom radius; they are void. **No 5 kW economics can be quoted until the
re-run** (mandatory now): the DE must raise λ toward 1, where swept area and
mass are both λ²-scaled consistently. Fast suite remains 1912/1912 green
through all three fixes; acceptance re-baseline pending the re-run's winners.

**Historical record — re-gate after the MASS fix alone (before the radius
fix; kept for traceability, now superseded):**

| Winner | Old P (contaminated) | **P after mass fix only** | Verdict |
|---|---|---|---|
| 18.0 m | 7.678 kW | 7.143 kW (−7%) | PASS |
| 21.2 m | 8.243 kW | 6.254 kW (−24%) | PASS |
| 25.0 m | 8.322 kW | 7.130 kW (−14%) | PASS |

That showed the mass fix alone is aero-neutral (the earlier "power was
lift-tension-dependent" hypothesis was refuted by measurement). **The radius
fix (§11 third fix) then revealed the deeper exploit — those winners are
void (0.0 kW at λ=0.14).** No economics table is quoted for the current
model; the re-run's new winners will produce it.

**Acceptance status after the fix:** fast suite 1912/1912 green.
Acceptance suite: PASS test_evaluator_v13 (B1–B7), test_gate_v13 (A1–A4),
test_rotor_power_realism (P1–P4); FAIL test_rope_break R3 (seed ω band
12.19 vs 12.5–13.5 — recalibrate) and test_settle_drag_alignment A + D (both
use the v12_5kw_coldstart fixture and the rotary lifter — the power/window
behaviour shifted with the corrected mass model). **Expected red — the
expectations were calibrated on the contaminated physics; A and D do NOT
speak to the v13 winners.** Re-baseline the acceptance tests on the NEW
winners from the 5 kW re-run; do not commit the working tree until then.

**Remaining steps:** mass-aware objective φ target decision → 5 kW re-run →
re-baseline acceptance on new winners → full-scope 2026 LCOE/LCA workbook.

## 12. Small-device anchor — the measured scaling base (Rod's steer 2026-08-20)

**Rod: "Why scale down from 50 kW fixed numbers, not up from the known mast
test and ~1.6 kW numbers? On the scale of devices modelled, rely more on the
smaller ones — bias scale-dependent notions toward them before the 5 kW
re-run."** Agreed — the current chain is theory-down (params_10kw DRR/AeroDyn
→ `mass_scale` with the uncalibrated 1.35 exponent from the Mass Scaling PDF);
the measured base is the mast test + Daisy. Extracted from the Tulloch PhD
thesis (`/mnt/Windswept Energy/03_Engineering/Academic Uni & Research/
Strathclyde/Tulloch, PhD Thesis Final Submission.pdf`, text in
`.julia_depot/tulloch_full.txt`):

| Quantity | Measured/thesis value (small device) | Current model constant | Notes |
|---|---|---|---|
| System Cp_max | **0.15** (config 8), optimised 0.18 | 0.22 (BEM peak) | F9 anchor: Cp_sys ≈ 0.16 both sides ✓ |
| **Ring radius** | **1.52 m** ("the ring, for all prototypes, has a radius of 1.52 m") | r_hub gene | **The 70/30 ring anchor IS the measured device** |
| **Rotor tips** | **r_in = 1.22 m, r_out = 2.22 m** (rigid rotor) | — | outboard 0.70 m = 0.7·span, inboard 0.30 m = 0.3·span — **exactly 70/30** |
| Blade inner tip | r/R_out = 0.55 (rigid proto) / 0.37 (opt) | 70/30 ring-anchored (2026-08-20) | old decoder 0.25·R retired |
| Solidity | **7.5%** | 0.113·R chord | measured solidity lower |
| Blade profile | **NACA 4412** | NACA 4412 ✓ | Consistent |
| Rated | **~1.5 kW @ 12 m/s**, 9 prototypes field-tested | 10 kW @ 11 m/s canonical | 10 kW MVP was itself "scaling the existing 1.5 kW kite turbine" (General Release report) |
| Measured power | ~220 W (mast, 5.5–7 m/s) | — | F9 anchor model 234 W ✓ |
| Mast rig rotor | ≈ 1.95 m (derived), 2 mm UHMWPE, 70 cm hex rings | — | April-29 rig |

**Measured Daisy blade construction + records (Rod, 2026-08-20 — the mass
anchor):**

- **Blade**: 420 g foam core + plastic shrink-wrap skin + **2 carbon spar
  tubes ~9 mm OD / 0.5 mm wall** + custom 3D-printed fuselage (thesis Fig 3.6).
- **Flying weight < 2 kg** for the single rigid-ring rotor, **> 1.5 kW at
  10 m/s** (AWEC 2019).
- **624 W / 146 rpm / 6-blade / 11.2 m² / ζ = 3.77** (Dec 2019 blog).

**Cross-checks against the model:**

- **Swept area**: the ring-anchored annulus π(2.22² − 1.22²) = **10.8 m²**
  vs the measured **11.2 m²** — the annulus geometry is measured-consistent
  (the 0.4 m² / 3.6% delta is the blade chord's effective area / tip
  rounding).
- **Mass anchor**: Daisy airborne ≈ 2 kg at 1.5 kW → **φ ≈ 1.3 kg/kW**. A
  5 kW machine scaled up is ≈ 4–7 kg (φ ≈ 0.8–1.4 depending on exponent) —
  **consistent with the fixed model's φ ≈ 1 kg/kW**. The exponent is
  underdetermined from ONE measured point (the NZTC 50 kW "25 kg" is
  extrapolation on shaky data, NOT an anchor — Rod); field tests measure it.
- **Reconciliation open**: 6 × 420 g blades ≈ 2.5 kg vs the "< 2 kg" flying
  weight — the difference is the fuselage/rods being inside the 420 g, or a
  different prototype config. To resolve when the thesis Fig 3.6 / blog
  config is pinned down.

The **50 kW BOM from the NZTC carbon model is NOT treated as an anchor** — it
is a scaled extrapolation; only the Daisy measurements (above) anchor the
mass and geometry.

**Cp with scale — the documented signs (agreed; the 0.166 is SYSTEM Cp, not
rotor Cp):** v5 BEM strip-theory peak Cp = 0.453 at n_lines=8 (DECISIONS v5
winner); the ladder's "realistic aero" ≈ 0.30; the ≥25 kW analysis assumed
rotor Cp 0.4–0.45 with η 0.8–0.85 at proper size. Mechanism: fixed losses
(transmission, tether drag, generator) shrink relative to output as P ∝
A·v³, so system Cp climbs toward rotor Cp with scale — and better ground
station generation control should beat the "very unstable" Daisy's 0.166.
The F9 calibration makes the scale-up prediction credible (model matches
0.16 at small scale; it is not a fitted number).

**The 10 kW General Release report** (`10kW Design/Design Reasoning Report -
General Release.pdf`) is the scaling source Rod flagged: the MVP "is based
on scaling the existing 1.5 kW kite turbine", it concludes the *safely
practical scaling limit for simple (static-lift) designs*, it pivots to
"alternative, active lifting kite solutions to enable scaling", it contains
per-sub-system scalability appraisals (rotor, ground station, TRPT, BackBot,
lift kite), and it calls to "train our engineering model with detailed
performance effects of increasing scale".

**Proposed re-run base (pending Rod's go):** build a **mast/Daisy-up**
5 kW base — rotor radius sized from measured Cp_sys ≈ 0.16 (≈4.0 m at 5 kW,
not the BEM-theory 3.3–3.5 m), blade geometry from the thesis ratios (inner
tip 0.37–0.55 R, length 0.63 R, solidity ~7.5%), and the mass-scaling
exponent calibrated from measured device pairs (masses to be extracted from
the thesis/Daisy build records) rather than the theory 1.35. The decoder
constants 0.25 (hub) and 0.113 (chord) are flagged as **not** matching the
measured device and should be re-derived from the thesis before the re-run.

## 13. Annulus implementation status (2026-08-20 — implemented, suite green)

Rod's directive ("all evaluators and builders should have consistent annulus
geometry — main-rotor annulus + ring-anchored 70/30, consistent with the
expansion rotors, r_ring ≥ 0.3L in the design bounds") is **implemented and
verified** (fast suite 1912/1912 green):

- **Decoder** (`objective_v10.jl`): blades are ring-anchored 70/30 offsets —
  `blade_tip = +0.7·span`, `blade_hub = −0.3·span` (span magnitude preserved).
  The topmost rotor is now parameterised exactly like the expansion rotors.
- **Builders** (`build_kite_turbine_system` + v5 + impl): new
  `rotor_blade_hub_radius` kwarg (0.0 = legacy full disk, bit-identical for
  non-annulus callers); `build_system_from_v10` sets the main rotor from the
  decoded hub rotor: `r_out = r_hub + 0.7·span`, `r_in = r_hub − 0.3·span`.
- **ODE** (`ring_forces.jl`, `sim_frame.jl`, settle): swept area is the
  ANNULUS `π(r_out² − r_in²)` via `main_rotor_swept_area`; TSR uses r_out.
  The expansion rotors' annulus (already π(r_out²−r_in²)) is now fed the
  correct negative inboard offset — fixing a latent geometry bug there too.
- **Constraint**: `rotor_annulus_ok` hard-gates `r_ring ≥ 0.3·span` (inner
  tip ≥ 0) for the main rotor and every expansion rotor in `evaluate_windowed`.
- **Calibration**: the thesis confirms the split — Daisy ring 1.52 m, tips
  1.22/2.22 m = exactly 70/30 around the ring.

Sanity (old 18 m winner, decoded): r_hub 0.7 m ring → r_out 1.08 m, r_in
0.54 m, annulus 2.73 m² (Betz cap ≈ 1.3 kW at 11 m/s) — cannot reach 5 kW;
the old winners are void under the corrected geometry, and the 5 kW re-run's
design space must respect the annulus constraint (r_ring floor ≈ 1.35 m at
5 kW, Cp 0.16).

## 14. What was NOT done (scope)

No ODE compute; no campaign re-runs; no `src/` changes; no changes to the
recorded verdicts or campaign CSVs. The acceptance suite is being re-run on
this checkout (environment fix: `julia` shim in `.julia_depot/bin` so the
parallel runner's bare `julia` invocations resolve to a working binary).
