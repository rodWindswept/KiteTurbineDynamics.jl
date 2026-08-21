# Field-test proposal — DRAFT for review (funding-facing)

**Date:** 2026-08-20
**Status:** DRAFT — budget figures are indicative ranges for Rod to price;
nothing here is committed. Follows the grounded-economics findings
(`docs/reports/grounded-economics-v13.md`).
**Purpose:** get out of theory — propose field tests that resolve the open
questions a funding reviewer (and we) need answered, priced and phased, ready
to attach to a funding application.

---

## 1. Why a field test now

The corrected model is in its strongest state so far:

- **F9 anchor:** model 234 W vs measured 223 ± 79 W at 6.25 m/s; Cp_sys ≈ 0.16
  on both sides (Oliver's spring-disc Cp_max = 0.166) — power-curve realism
  validated at the 220 W scale. **Not affected by the contamination below.**
- **5 kW rung in model:** 7.68 / 8.24 / 8.32 kW sustained at the ground ring
  at 18.0 / 21.2 / 25.0 m, every structural gate green —
  **⚠ CONTAMINATED (2026-08-20):** the winners were produced under a
  mass-blind objective carrying 50 kW blade mass (12.0757 kg/blade, not
  rung-scaled) and were gated at a lift tension sized ~9× too high. The power
  numbers are pending re-run after the build fix; the ~139–164 kg masses are
  artefacts, not real 5 kW designs (a true one ≈ 16 kg). See
  `docs/reports/grounded-economics-v13.md` §4b.
- **Ladder (5–15 kW viable band):** computed through the same contaminated
  build path — treat the band as qualitative pending the fix, not as
  published numbers.
- **≥25 kW unproven by the gate** (cold-start artifact + seed under-sizing)
  — this conclusion does not depend on the blade-mass contamination.

But the model cannot settle its own open questions. Only measured data can:

1. **Real mass.** The model's 5 kW winners carry 133–157 kg of blades (95% of
   airborne mass — see Finding 1 in the economics doc). Is that real, or a
   scaling artefact? **Weighing a real machine answers it directly** — and it
   determines whether the economics say "viable" or "not".
2. **Power-vs-wind curve.** AEP is currently CF × one 11 m/s point. A measured
   P(v) curve replaces the assumption with data.
3. **The λ gap.** The model parks at λ ≈ 7.6 vs field λ ≈ 4.35 (thesis's own
   flagged 6-blade modelling gap). A field test measures the true operating
   λ and tells us which side is wrong.
4. **Self-start / low-wind behaviour.** The cold-start stall mechanism at
   scale (the same one behind the April-29 "13.5 W at every wind" artifact)
   needs a real machine to confirm it starts and regulates.
5. **Reliability signals.** Sustained operation, twist margin, line condition —
   the "practical, reliable" claims need run-hours, not just simulations.

## 2. Candidate tests (phased, escalating cost)

### Test A — Re-run the April-29 mast rig against the corrected model (~£1–3k, 1–3 months)

The 2020-04-29 rig (TRPT-5: hex rings, 6 outer tethers, 2 mm UHMWPE lines,
12 kg bucket, mast-mounted) already exists and now has a corrected-model
prediction to test against: **~220 W at 5.5–7 m/s, Cp_sys ≈ 0.16**, the F9
curve (`scripts/results/april29_model_curve.csv`). The four fixes that closed
the wind-blind era (dt=4e-6, measured τ(ω) table, constant bucket tension,
main-rotor-only aero) make the prediction falsifiable.

- **What we measure:** 30-s-mean wind vs power vs ω, tension at the PTO wheel
  (the logged 18–22 kg channel), self-start wind speed.
- **Cost basis:** rig exists; spend is instrumentation + logging + consumables.
  Prior build data anchors component prices (Daisy model: anemometer £65, load
  cells, ESC £280, battery/inverter £600 — see
  `/mnt/Windswept Energy/10kW Design/legacy KITE TURBINE & DAISY STANDARDS/
  3-5kW Daisy EV/`).
- **Success criteria:** measured P within ±20% of the F9 model curve over
  3.5–8 m/s; Cp_sys plateau reproduced within ±0.03; self-start wind recorded.
- **Deliverable:** the first *independent* measured-vs-model P(v) curve — the
  credibility cornerstone for funders.

### Test B — Instrumented 5 kW-scale prototype at 18 m (indicative £10–25k build + site, 6–12 months)

Build the 18.0 m winner's geometry at real scale (11 lines, 5 rings, r_hub
0.70 m, Do_top 14.4 mm, 2.1 mm tethers — genome in
`scripts/results/v13_5kw_len18.0/best_vector.csv`), with a generator, PTO
wheel, and logging. **⚠ Contamination note (2026-08-20):** that winner's
~139 kg predicted mass and 2.2 kN lift tension are artefacts of the mass-blind
objective carrying 50 kW blades (see economics doc §4b); a true 5 kW machine
is expected around ~16 kg. **The single most valuable measurement is the
component weight breakdown — it resolves the mass question with data, and it
is now even more important because the model's own mass prediction is known
to be wrong until the build fix lands.** Second: P(v) at 5 kW scale. Third:
sustained-run reliability (hours, twist margin, line checks).

- **What we measure:** component masses (blades, rings, tethers, knuckles);
  P(v) 30-s means; ω regulation; tension at ground; twist/collapse margin
  proxies (line crossings, ring spacing); run-hours until any fault.
- **Cost basis (from the prior costings, one-off prototype prices — NOT the
  production-unit costs):** Daisy 3–5 kW production build was £2,162/unit at
  300 units; a one-off prototype pays single-piece prices and tooling. Use the
  10 kW L3 model's component prices as the upper anchor (motor/generator £270,
  head & thrust bearing £439, gearbox £154, ESC £410, 5 kWh battery + inverter
  £2,015, PTO wheel, control housing, anemometer). A 5 kW airborne + ground
  build is realistically **£3–8k of parts**, plus mast, instrumentation, site,
  insurance and labour → indicative **£10–25k**. Full-scale comparison: the
  10 kW L3 model priced a whole prototyping *programme* (jig, equipment,
  engineering) at **£421.6k Phase 1** — that is the upper bound for a funded
  10 kW prototype programme, not this 5 kW test.
  **PRICE-LEVEL CAVEAT (2026-08-20):** all of the above are historical
  (2021–2023) prices. Cumulative UK CPI 2021→2025 ≈ **+23%** — apply at least
  that uplift for a 2026 budget, and re-price categories (CFRP, Dyneema,
  electronics, batteries, shipping, labour) at build time. The **10 kW L3
  proposal case** is the best-grounded base for the detailed re-modelling;
  these figures are order-of-magnitude only.
- **Success criteria:** measured mass within ±10% of the model decomposition
  *or* a documented correction to the mass model; P within ±20% of model
  P_gen at each wind; ≥50 h sustained operation with no twist collapse and no
  line failure.
- **Deliverable:** the first scale-relevant validation of mass AND power — the
  data that lets the economics be final.

### Test B2 — Flown, lift-kite-enabled evaluation (the AWES point; ~£10–25k+, 6–12 months)

**Rod (2026-08-20):** the 5 kW test should also include a **flown (not
mast-held) lift-kite-enabled configuration** — because AWES exists to access
*higher wind with less material*. A mast test validates the rotor/TRPT
power chain at fixed orientation; a flown machine validates the full system
argument: the **autogyro-stack lift device** (CoaxialAutogyroStacking.jl,
prototype path §2c) lifting the kite turbine to altitude, where the wind is
stronger and steadier. Success criteria: lift system holds the machine at
the design elevation and tension (the §2c quad-stack target 5 kN at 8 m/s
scales to the 5 kW machine's needs); the machine produces power while
lifted; the "less material per kWh at altitude" claim is demonstrated (P at
altitude vs P at mast height on the same day). This is the test that answers
the funder's "why fly it?" question.

### Test C — Rotor/blade wind-tunnel or ground-rig characterisation (indicative £1–3k/day facility)

Blade aero (CL/CD vs α, the NACA 4412 BEM table), blade mass per unit length,
and the 6-blade solidity gap behind the λ discrepancy. Precedent: Durham's AWE
wind-tunnel PhD programme. Cheap, de-risks the biggest modelling gap.

## 2b. Site reality — the Aiginish flight envelope (from the drive's safety case)

The existing permissioned test site is **croft 15 Aiginish, Isle of Lewis**
(`03_Engineering/Safety & Standards/Aiginish kite test flight safety.pdf`):
**26 m AGL max altitude, flying angle max 60°, airborne mass < 2 kg** (Article
253 — NON-EASA, no registration needed under 30 m even inside the ATC zone,
which matters given Stornoway Airport is ~2.7 km away with HIAL ATZ
objections), soft-kite networks only, CAP 393 compliance, **6 years of flight
precedent**.

Consequences for the tests:
- **Test A** (220 W scale): fits the small-mass, low-altitude envelope in
  spirit — but the 2020 rig's 12 kg bucket era predates the current <2 kg
  airborne permission. The re-run must either be a small-mass variant of the
  rig or carry a new safety case. This is the first reality check the
  proposal must pass.
- **Test B** (5 kW prototype, ~139 kg airborne): **cannot fly under the
  current Aiginish envelope** — it needs a new CAA/EASA safety case, a site,
  and insurance. That is a real cost and timeline item, not an assumption.

Reliability inputs exist on the drive: the **10 kW FMEA** (`04_Business/
Business Plans & Models/project management/10kWautoKT FMEA Spec Validation
deliverables.xlsx` — the "Parts from FMEA" behind the Daisy costings) and the
corporate **Risk Register** (`Risk Register.ods` in the legacy layout).

## 2c. The lift-system R&D line — the gating R&D (why this matters)

**Strategic context (Rod, 2026-08-20):** *safe lift-kite scaling was the
issue that closed the 10 kW project* (the 2024 halt of the 10 kW automation
line, per the drive's collaboration-request note). The decision was to restart
on **smaller-system R&D and refocus on active lift systems**. So the lift
system is not a side component — it is the gating R&D line, and **reliable
cost forecasting must include its R&D costs and a collaboration-funding
structure**, not just the turbine's build costs.

The lift-system codebase is `CoaxialAutogyroStacking.jl` (separate repo —
stacked lifting autogyro kites on one line, BEM v2.1, 407 tests green,
Phase 11 dynamic-inflow work). Its prototype path is already defined
(`PROTOTYPE_PATH.md`):

| Gap | Time | Cost |
|---|---|---|
| Sourcing (per rotor) | 1 week | £245/rotor |
| Manufacturing | 2–3 weekends | £100–200 |
| Assembly | 3–4 h/rotor | — |
| Ground testing | 3–4 h | £50 |
| Flight testing (Croft) | 3 sessions | travel |

**Total: ~6 weeks, ~£400–500 + travel for rotor 1** (quad-stack later).
Flight plan: session 1 = single rotor (prove autorotation, tension within 30%
of model); session 2 = dual stack; session 3 = quad stack (target **5 kN at
8 m/s**). Model best config: 4-rotor stack, mean anchor tension 839 N, peak
1,412 N at 12 m/s, tip speed 23–38 m/s.

**Plain-language logic:** the lift device is what the whole turbine hangs
from. The 10 kW project closed because the lift kite couldn't be scaled
safely. The autogyro-stack line is the attempt to fix exactly that — so
funding the kite turbine without funding the lift line would repeat the
mistake. The prototype path above means the lift R&D is *small and cheap*
(~£500 + travel for the first rotor) — an ideal first collaboration ask.

## 3. Funding angles and the collaboration structure

**Proposed structure — three workstreams, each matched to its natural source
(Rod's steer 2026-08-20: R&D costs and collaboration funding for the lift
system must be in the picture before reliable cost forecasting):**

1. **Lift-system prototype R&D** (~£1–3k all-in: rotor 1 build + Croft flight
   sessions, per §2c). Sources: HIE small grants (Aiginish/Croft precedent),
   TechX alumni network, a university partnership (Strathclyde — thesis
   origin, or Durham's AWE wind-tunnel group: they get BEM/wind-tunnel
   validation data and a paper; we get access + credibility), AWES community.
   Deliverable: autorotation proven + tension-vs-model match — the safe-lift
   evidence the whole concept rests on.
2. **Kite-turbine system field validation** (Test A ~£1–3k; Test B
   £10–25k+): the power-curve and mass measurements (§2). Sources: Innovate
   UK / Energy Entrepreneurs Fund, HIE, AWES community collaboration.
3. **2026 full-scope economics re-modelling** (in-house, no funding needed):
   the shared evidence base — 10 kW proposal-case structure, re-priced to
   2026 with R&D amortisation included. This is what makes workstreams 1 and
   2 fundable: funders need the numbers.

**Collaboration principle:** the lift line and the turbine line share the
same evidence base (BEM models, field data, economics). Partners should be
chosen for what they bring to that shared base — a university's wind tunnel
and rigour, the AWES community's field-test experience and audience — not
just for money. A collaboration-funded lift prototype is the cheapest,
highest-leverage first step: ~£500 of parts proves (or refutes) the
safe-lift premise that closed the 10 kW project.

## 4. Risks (state them before a funder does)

| Risk | Mitigation |
|---|---|
| λ gap (model 7.6 vs field 4.35) | Test A measures it; Test C characterises the blades; the thesis flagged the 6-blade modelling gap — we fix the model, not hide it |
| Blade-mass question unresolved in model | Test B weighs the machine; economics doc holds until then |
| Cold-start / self-start stall at scale | Test A records self-start wind; Test B tests regulation from rest |
| Weather windows (UK) | Phased 6–12 month window; 30-s-mean protocol designed for gusty data |
| Flying-tether insurance/site | Site + insurance costed in Test B; **Aiginish envelope = 26 m AGL, <2 kg airborne** — Test B needs a new safety case; Test A needs a small-mass rig |
| Reliability unknowns (lifetimes 1.5–6 y in prior cost models) | Measure run-hours/fault rate in Test A/B; the 10 kW FMEA is the reliability baseline |
| **Certification / airspace** | Route = SORA + the **AWE White Paper on safe operation & airspace integration** + CAP 393 / CAA Article 253 (<2 kg) — guides in `04_Business/AWES Co-opetition & Market Analysis/Airborne Wind Europe/`. Design floor: **FoS ≥ 2.5 at all points** (Rod 2026-08-20) until field trials/breakages calibrate it |

## 5. Open items for Rod

1. Confirm/price the remaining budget lines — site, insurance, labour, mast —
   now that component costs are anchored to the prior Daisy/10 kW L3 costings
   (drive: `/mnt/Windswept Energy/10kW Design/…`).
2. Choose Test A vs A+B vs A+C sequencing (recommendation: A first — cheapest,
   fastest, and it de-risks B; and it is the smallest-built-system evidence
   base you rightly say is the most reliable).
3. Confirm the mass measurement question is worth a dedicated Test B (it is
   the single highest-value measurement — it resolves Finding 1 with data).
4. Funding targets to prioritise (HIE vs Innovate UK vs university).

---

*This draft will be revised with the acceptance-suite result and any Rod
decisions on the economics findings.*
