# Genome landscape analysis: bankderate2 campaign (5 kW, 18.8 m)

**Date:** 2026-10-08. **Status:** PLAN (sequencing for the whole team).
**Dataset:** `ktd-aw-fire/scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/`
(3 islands × 310 evals = 930. Launch `a76c5e9`, era `post-95c385d_wind-authority`,
k = 2.24, honest window 40 s, FoS 2.5/2.5, rotor_count_mode {1,2,3}).
Status mix: 508 ok, 301 reject, 110 clearance_reject, 11 reject_twist.
Winner: island 3, fitness 27.36 kg, found gen 26.

**Goal.** Find the genome levers. Which genes move which outputs, and by how much?
Turn that into characteristics of kite-turbine design the AWES community can read.
The audience question: "what does a 5 kW KTD look like and why". The plan answers
it from a 930-eval landscape, not from a single winner.

**Discipline rules (all phases).**
- Recorded > derived: numbers come from telemetry columns. Anything computed
  states its recipe (for example, φ = fitness/P_mean).
- Instrument-floor watch: a gene whose range leaves an outcome uniform is a
  dead gene, not a finding. The team found four dead genes once before
  (2026-08-24). Re-verify per gene here.
- Status-class honesty: read levers per status class (ok / reject /
  clearance_reject / reject_twist). A lever that only changes which designs
  die is as characteristic as one that shifts power.
- Betz ceiling on every P_mean claim.
- No public number before its phase gate signs.

## Phase 0: Data integrity audit (gate before any analysis)

Owner: **software-validator**, second reader **science-validator**.

**Status (2026-10-08): SIGNED.** Software-validator audited, science-validator
second read. Landed `8a440e6` on `bankderate2-results`, merged to master
`31ca00d`. Full record: `docs/validation/2026-10-08-phase0-bankderate2-audit.md`.
Phase 1 is unblocked.

1. Commit and push the results (fire worktree is detached at `a76c5e9`,
   results untracked). Data must exist on origin before analysis.
2. Gen-0 / gen-1+ discontinuity check (seed rows vs DE children: the
   instrument-floor pattern). Audit note: `k_chosen` is not a telemetry
   column, and `P_range` / `stationary` are unrecorded fields. Phase 1 must
   not cite them from CSV columns.
3. Destructure verification (all evaluator fields captured per generation).
4. Re-evaluate the winner standalone at `a76c5e9`. P_mean/FoS must reproduce
   from the recorded genome. A mismatch voids every row.
5. Cross-island instrument check: identical config and bounds imply
   overlapping distributions. Non-overlap is an instrument, not physics.
6. FoS=Inf guard presence on surviving rows.
Deliverable: audit doc in `docs/validation/` plus a verdict in
`docs/agents/instrument-trust-log.md`.

## Phase 1: Univariate lever ranking (the levers)

Owner: **science-worker** (conditioned stats), **aero-worker** (aero genes:
bank_top/bank_bot, rotor_count, blade scales). Gate: **science-validator**.

For each of the 10 genes (r_hub, r_bot, target_Lr, n_lines, density,
rotor_count, bank_top, bank_bot, blade_scale_top, blade_scale_bottom):

- Conditioned outcome distributions on ok rows: P_mean, T_lift, FoS, fitness,
  clearance.
- Reject-rate profiles: which gene values push designs into each reject class.
- Lever = a gene whose range shifts an outcome materially. Rank by effect
  size, not by winner-only reads.
- Priority questions:
  1. **rotor_count {1,2,3}**: do expansion-rotor designs (count ≥ 2) ever
     survive? This settles Rod's expansion-rotor campaign question from the
     data, not from a guard test.
  2. Bank saturation: the winner sits at bank_bot = 22° (the bound). Is bank
     a hard-hitting lever at its ceiling?
  3. n_lines = 3 (the floor bound) on the winner. Is the polygon count a real
     mass lever?
  4. target_Lr vs r_hub (Tulloch L/r): trade or constraint?
Deliverable: lever table plus per-gene conditioned plots (chart standards per
`ktd-chart-design` / `diagram-patterns`).

## Phase 2: Interaction structure

Owner: **science-worker**. Gate: **science-validator**.

- Test the known couplings: r_hub × target_Lr, bank × rotor_count,
  n_lines × rings (the 9-ring fold), density profile, blade_scale × span
  (λ^2.63 mass law), power_split = 0.6 fixed, which implies a rotor-count
  interaction.
- PCA / region analysis on the ok set (508 rows): dominant axes of the
  surviving landscape.
Deliverable: interaction matrix plus dominant axes ("what actually trades
against what").

## Phase 3: Characteristic regimes (the community-facing core)

Owner: **science-worker** with **aero-worker**. Gate: **science-validator**
plus **aero-validator**.

- Cluster surviving designs into design families (hub-only, stacked-rotor,
  banked hex, folded 9-ring).
- Per family: P_mean, T_lift, FoS, φ (kg/kW), clearance, twist margin,
  mass breakdown.
- Pareto front of fitness vs power. Where does the 27.36 kg winner sit? What
  does the front say about the mass-power trade?
Deliverable: the design-characteristics table. This is the source document for
"what a 5 kW KTD looks like".

## Phase 4: AWES-community presentation

Owner: **@author** (narrative), **@figures-images-diagrams** (charts).
- Figures: genome-landscape maps, lever sensitivity panels, regime table,
  Pareto front. STE-clean captions. Trace every number to telemetry rows.
- Prose in Rod's first person, AI voice stripped, numbers exact.
- Release sequencing: nothing public until validators sign Phases 0 to 3.

## Sequencing

Phase 0 → 1 → 2 → 3 → 4, strictly. Phase 0 must close before any lever claim
is written anywhere. The plan presents campaign truths. It does not
reconstruct them.
