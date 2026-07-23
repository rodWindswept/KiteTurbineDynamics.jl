Rod — forward this to the desktop Hermes in Stornoway. It replaces the two
same-day split handovers (both now SUPERSEDED stubs): the laptop and its
manager agent are being suspended, so **everything below runs on the desktop,
in the order given**. Before the laptop goes dark, push from it: commit
233ffc0 (DECISIONS Phase 2 RED entry) and this handover — nothing propagates
uncommitted, and Stage 0 below depends on both.

---

# Feasibility-first v11-direct campaign — single-agent pipeline (Stornoway)

## Context

Phase 2 correlation gate is RED — full verdict in DECISIONS.md entry
`[2026-07-23] Phase 2 correlation gate: RED` (commit 233ffc0). Facts that
drive everything below:

1. All 50/50 anchors (`scripts/results/recampaign/anchors.csv`, commit
   1acaaa2) are penalty-saturated in f_v10 (>1e6) AND fail the v11 FoS gate
   (best window-min FoS = 0.48 vs FOS_DESIGN = 1.5). The δ̂ multi-fidelity
   plan (`docs/plans/multifidelity_recampaign.md` Phases 3–4) is dead.
2. The binding problem is **feasibility, not power** (Rod, 2026-07-23). A
   power objective under a gate 0/50 designs satisfy just ranks failures.
3. Leading (unproven) mechanism: v10 FoS is axial-only Euler + tension
   stiffening (`trpt_optimization.jl` ~535, no bending terms); v11 FoS is
   combined beam-column utilisation (`ring_element_analysis.jl` ~277,
   `N_ax/N_crit + √(M_ip²+M_oop²)/M_el`) — asymmetric line tensions create
   M_ip bending v10 never sees. Caveats: whole-sample ρ has p ≈ 0.34
   ("systematic" is not yet supported; only the n_lines=8 stratum, n = 5,
   p = 0.04, is nominally significant), and note the live evaluator path
   uses `oop_relaxation = 0.05 × tether_relaxation` (ring_element_analysis
   ~479 → ~616), NOT the bare-function default 1.0 — M_oop is knocked down
   20×, so any real disagreement is carried by M_ip. Stage 1 tests this
   properly.

Skills to load: `windswept-knowledge`, `awe-knowledge`, `tdd`,
`ktd-simulation-workflow`, `ktd-headless-analysis`,
`ktd-v6-campaign-workflow`. Follow the trust-log pre-flight checklist
(`docs/agents/instrument-trust-log.md`) at every stage — this week produced
five instrument bugs; the pattern to watch is uniform metrics across varying
conditions.

## Stage 0 — Sync & preconditions

- `git pull`; confirm 233ffc0 and 1acaaa2 present, `anchors.csv` = 50 rows.
- Clear the Julia cache (`~/.julia/compiled/v1.12/KiteTurbineDynamics/`) —
  and again after every src/ edit below (CLAUDE.md rule).
- Run the warmstart regression testset (`test/test_objective_v11.jl`,
  "warmstart regression vs full protocol") — must be green before touching
  anything.

## Stage 1 — Instrument hardening (all before any campaign eval)

Ordered; each lands with tests green and, where physics changes, a
DECISIONS entry.

**1a. Stationarity settle gate.** Current "settled" = endpoint drift < 15%
passes designs oscillating 200+ kW mid-window. Replace with
stationarity-of-windowed-stats: split the scoring window in halves; require
|P_mean₁ − P_mean₂| within 10% and |FoS_min₁ − FoS_min₂| within 0.1 (tune
against known cases). Wire into `objective_v11_warmstart` as a `stationary`
flag column — a flag, NOT a hard reject (the campaign must see marginal
designs, marked). Warmstart regression testset stays green.

**1b. FoS instrument reconciliation (decisive test of the bending
hypothesis).** Cheap — static solver only. Re-run the v10 static evaluator
on all 50 anchor genomes; export paired
`(genome_hash, static_min_fos, v11_FoS_min, n_lines, chosen_k)` to
`scripts/results/recampaign/fos_pairs.csv`. Spearman ρ on the **FoS pairs**
(not fitness — the gate's fitness numbers had mass entangled via
penalty_mult), and δ_FoS = static − dynamic regressed against n_lines and
chosen_k. Hypothesis predicts δ_FoS grows with n_lines and FoS-pair ρ is
negative with decent p. Either outcome: DECISIONS entry closing or
reshaping the trust-log OPEN item "axial-only vs combined FoS". While in
there: the 0.05 M_oop knockdown has no recorded provenance — a 20×
relaxation on out-of-plane bending is load-bearing; provenance or a
sensitivity row in the trust log.

**1c. k = 1000 clamp diagnosis.** 10/50 anchors chose k at the clamp
(`clamp(k, 0.01, 1000.0)`, three sites in `src/objective_v11.jl`; bounds
are log₁₀k ∈ [−2, 3]). Take the saturated anchor with highest P
(`0d61db093a2c`, 4-line, 10 kW) and trace P_gen, P_aero, ω, FoS through the
window at k ∈ {600, 800, 1000}. Question: does power genuinely rise to the
boundary, or is the bracket rewarding a drifting state the P_mean gate
misses? Semi-implicit braking landed pre-fc280b7, so the old τ = k·ω²
blowup mode should be gone — verify, don't assume. Widen the clamp only if
P_aero stays under the swept-area Betz ceiling at the boundary. DECISIONS
entry either way.

**1d. Expansion blade inertia — quantify, then decide.** Known gap: blades
contribute aero force but zero dynamic mass (`er.mass` never enters the
ODE). Re-run the 5 seed designs (hashes in Stage 2) with blade mass on ring
nodes (n_blades_per_ring × expansion_blade_mass, rod-integral inertia per
the Gate 2b hub pattern). Report ΔFoS_min and Δω_eq per design.
- ΔFoS < 0.05 on all five → document, defer, proceed to Stage 2.
- Material (likely at 8–12 lines) → land it BEFORE the campaign, behind a
  toggle default ON with the `LEGACY_PHYSICS` pin (archived CSVs stay
  reproducible; `N_expansion = 0` stays bit-identical to v5 — FR4). Do not
  change physics mid-campaign; that ambiguity is exactly what Stage 1
  exists to prevent.

## Stage 2 — Phase A feasibility campaign

**Objective — `objective_feasibility`,** built on `objective_v11_warmstart`
/ `warmstart_with_k_bracket` with the P_mean convergence gate (ed4a3e5).
Do NOT reuse `v11_fitness` (power-primary). DE minimises:

```
P_floor = 1.0 kW
if P_mean < P_floor:      f = 10.0 + (P_floor − P_mean)/P_floor   # stalled tier, worst
elif FoS_min < 1.5:       f = 1.5 − FoS_min                        # feasibility tier ∈ (0, 1.5)
else:                     f = −min(P_mean, P_cap)/P_cap            # feasible tier ∈ [−1, 0)
```

Stalled tier exists because an unloaded structure fakes high FoS (anchor
batch interim: FoS 0.92 at P = 0). A design must produce AND survive.
P_cap ≈ 50 kW keeps the feasible tier from re-creating the power chase.
Unit-test tier ordering and boundary monotonicity first (tdd; mirror the
sign-verification tests in `test/test_objective_v11.jl`).

**Instrumentation (free hypothesis test):** per eval, record the worst
ring's utilisation split from `BeamResult` — columns `util_axial`
(N_ax/N_crit) and `util_bending` (√(M_ip²+M_oop²)/M_el) alongside FoS_min.
If 1b's hypothesis is right, bending-dominated failures cluster at high
n_lines and Phase A proves it as a by-product. Do NOT bias seeding or
bounds toward low n_lines on the hypothesis — the statistics don't yet
support steering.

**Parameters:**
- Search space: `search_bounds_v11` unchanged (15-dim).
- Budget: population 24, ≤ 30 generations, hard cap 500 v11 evals. A probe,
  not a production campaign.
- Seeds (best window-min FoS with P > 1 kW, from anchors.csv):
  `205c119cd2cb` (8-line, FoS 0.48), `fdc0c9e0907b` (3-line legacy, 0.37),
  `0d61db093a2c` (4-line, 0.34), `f697422b778f` (12-line legacy, 0.23),
  `caddb19b866b` (6-line, 0.17), plus the V6.2 recovered 12-line optimum
  (recovered from 3fcc795).
- Output: `scripts/results/recampaign/feasibility_phase_a.csv` —
  progressive saves (one row per eval, written immediately), resume by
  genome hash, anchors.csv schema + `f_feas`, `tier`, `stationary`,
  `util_axial`, `util_bending`. Never modify anchors.csv. Banners, not
  rewrites.

**Gates — do not silently continue past these; each gets a DECISIONS entry
citing CSV + git hash:**
- **GREEN:** any design reaches FoS_min ≥ 1.5 with P_mean ≥ 1 kW → freeze
  the genome, go to Stage 3. Phase B (power optimization) stays blocked
  until Stage 3 confirms.
- **AMBER:** best FoS ≥ 1.0 but < 1.5 at budget → report the FoS-vs-P
  Pareto set to Rod; likely worth one targeted second budget.
- **RED:** best FoS < 1.0 after 500 evals → STOP. The search says the
  design family is structurally underbuilt under corrected physics; the
  successor task is airframe/materials rework (aerostructural review), not
  more search. Escalate to Rod. If Stage 1b showed bending-dominated
  failures, the rework conversation starts at ring section modulus /
  tension equalisation.

## Stage 3 — Verification of GREEN candidates

With the laptop suspended there is no second machine, so machine
independence is gone — substitute **protocol independence**, on this
machine, per candidate:

1. Full protocol, not warmstart: settle → kick → window via
   `run_canonical_sim!` (never hand-rolled), P_mean gate + `stationary`
   flag from 1a.
2. Dual-duration check: T and 4×T endpoints agree within 0.5 kW and 2% FoS
   (gate1-rerun standard).
3. α-retest (mandatory per the Gate 1 caveat): 7 α-constant perturbations
   in full sim; a feasibility flip = recalibrate before claiming.
4. Cold-start cross-check: re-evaluate from a fresh settle with a different
   RNG seed / initial ω — guards against a warm-start-basin artifact, the
   nearest available substitute for a second machine.

Verdict in DECISIONS.md: CONFIRMED / NOT REPRODUCED, with script + git
hash + CSV path. First CONFIRMED unblocks Phase B design (bring the plan
back to Rod before building it).

## Standing rules

- One DECISIONS entry per stage gate; reference artifacts by path.
- Progressive CSV saves throughout; scripts idempotent.
- Anything uniform across varying conditions is an instrument floor until
  proven otherwise (trust log, this week, five times).
