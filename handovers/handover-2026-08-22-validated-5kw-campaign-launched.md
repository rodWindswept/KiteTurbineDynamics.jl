# Handover — 2026-08-22: validated 5 kW base, honest evaluator, campaign LAUNCHED

**From:** AI agent (desktop session)
**To:** next agent session (laptop or desktop)
**Repo:** /home/rod/Documents/GitHub/KiteTurbineDynamics.jl
**State:** HEAD `adea1a3` + 6 earlier commits this session (see §3). Working
tree clean except `.claude/worktrees` (ignored). **NOT PUSHED — the sandbox
has no GitHub credentials; push with `git push origin master` from a
credentialed machine (pull --rebase first, multi-writer).**
**Campaign:** 5 kW DE **RUNNING** (launched 14:12, ~22–35 h expected) — see §5.

---

## 1. What this session accomplished (the 5 kW validation chain)

Rod's brief: prove the physics of an ideal 5 kW kite turbine; consistent,
trustworthy evaluators; DE campaigns on validated models. Decisions taken:
honest window (Option 1) now + settle-fix (Option 2) as a parallel workstream;
unified λ³ blade-mass law APPROVED; campaign scope = mass/evaluator variants
first, then geometry families.

**Four physics/evaluator defects found and fixed (each with its own commit):**

1. **Unified blade-mass law** (`bdc9ae7`): three inconsistent laws (main λ²,
   expansion CFRP `(0.3+0.1·tip)·λ³`, Gate-1c 210 g) → ONE law
   `m = m_ref·λ³`, `M_BLADE_REF_KG = 0.420` (measured Daisy blade, restored),
   knuckle floor (0.050 kg/blade) in `expansion_airborne_mass`, ring-count
   fix (hub ring included), `geometry_fingerprint` double-count fix.
   Fast suite 1936/1936.
2. **Campaign length double-scaling** (`76ae985`): `params_at_length(18.8)`
   mass_scaled the length AGAIN (×√(5/1.5)) → every "18.8 m" machine since
   2026-08-21 was actually 34.3 m while h_ref/masses said 18.8 m.  Fixed in
   runner, smoke, gate, k-sweep.  **All 5 kW ODE evidence from that era is
   superseded.** Also: `evaluate_ramp` was building every rung with the
   50 kW base (12.0757 kg/blade) — the 2026-08-20 contamination, missed in
   the ramp evaluator; both evaluators now build the same machine.
3. **Hub-rotor double-model** (`cc92a6b`): `expansion_params_from_rotors`
   mapped the hub rotor into `sys.expansion_rotors`, so the ODE applied the
   main cp/ct rotor AND the expansion α/induction model to the SAME annulus
   — the expansion model brakes at 6-blade solidity (the 2026-08-17
   anchor-session mechanism).  The seed decayed to ω ≈ −0.2 rad/s at EVERY
   k, even freewheeling; the pure main-rotor build accelerates to 14.2 rad/s.
   The hub's expansion entry ALSO double-counted blade mass (12.8 kg twice).
   **The old "true equilibrium 3.15 kW" (08-21 handover) was entirely this
   brake artifact.** Fix: hub (decoder ring_idx == n_rings) excluded from the
   expansion mapping + defensive guard in ring_forces.  Supersedes all
   multi-rotor results since the 08-20 unified-rotors decoder.
4. **Honest window + k re-sweep** (`adea1a3`): relax 10 s + window 40 s
   (tail5 at 35–40 s); cold path now carries the settle's ω into ω_eq (was
   0.0); k swept honestly on the FIXED machine: k=0.5 rejects at 3.47 kW
   (honest), k≥1.0 sustains — 1.0 → 5.45 kW, 1.5 → 6.78, **2.24 → 8.00 kW
   (the 6-blade Daisy anchor 0.175·(5/1.5)^2.5)**, saturating ~8.95 kW.
   The 60 m² seed is OVER-rotored (the old "under-rotored, needs 17 m²"
   narrative was the brake artifact) — the DE shrinks it.

## 2. Anchor numbers (do not re-derive — measured on the current HEAD)

- Corrected machine: 18.8 m, n_ring 10, seed r_hub 2.775 m, rotor r_out
  4.78 m, annulus 60.4 m², m_airborne (no lifter) **17.12 kg** (λ³ law,
  knuckles, hub excluded), T_lift(ref) 268.1 N (1.5×margin const-tension).
- Honest k sweep: `scripts/results/k_sweep_daisy_5kw.csv` (P_mean ≈ P_end
  everywhere — window converged).
- Smoke (k=2.24): status ok, P_mean 8.00 kW, P_end 8.01 kW, FoS 36.4,
  T_in = T_exp = 268.1 N (0.00% rel). ALL PASS.
- Fast suite: **1926/1926 green** (two runs after the last changes).

## 3. Commits this session (all local, NOT pushed)

```
6e6141a fix+test: settle-scan cp-peak clamp + honest low-k reject telemetry
961a11c docs: settle-scan low-k stall analysis plan + 2026-08-22 handover
ae190e0 fix: runner provenance + banner honesty (GIT_HASH read, fos_target)
bdc9ae7 fix+physics: unified blade-mass law m = m_ref·λ³ + knuckle floor
76ae985 fix: campaign length double-scaling (34.3→18.8 m) + ramp rung base
cc92a6b fix+physics: hub-rotor double-model eliminated
adea1a3 fix+perf: honest-window k sweep + cold-path ω_eq + k=2.24 anchor
```

## 4. Environment note (sandbox)

Julia runs ONLY with
`export JULIA_DEPOT_PATH=$PWD/.julia_depot:~/.julia` and
`julia --project=. --compiled-modules=existing` — writes outside the
workspace are blocked, so Julia cannot rebuild its compiled cache under
`~/.julia`.  `.julia_depot/` is gitignored (repo's own 2026-08-20
workaround).  The sandbox also has no GitHub credentials — push is a
human/laptop task.

## 5. THE CAMPAIGN (running) — monitor this first

- **Job:** background, log `/tmp/v13_campaign_len18.8.log`; results dir
  `scripts/results/v13_5kw_masslift_len18.8/` (PROVENANCE.md + telemetry.csv
  progressive).
- **Config:** mass_min_fitness (score = TRUE physics mass), FoS floor 2.5,
  P floor 5.0 kW, L=18.8 m, k=2.24, honest window (10 + 40), cold start,
  mass-aware const-tension lift (1.5×), 10 pop × 3 islands × 30 gen,
  per-eval timeout 300 s, eval cache, clearance gate.
- **Eval cost:** ~87 s/eval (50 s sim @ dt=4e-5) → ~22 h + overhead;
  handover-08-21 estimated 28–35 h.
- **When done:** pick winners (mass_min → lightest feasible), re-gate with
  `ode_gate_v13.jl` (now aligned: same machine, honest window), then
  **re-baseline the acceptance suite** (red-by-design until then) on the
  winners; update DECISIONS with the winner genomes; then the staged
  "evaluate different models" DE campaigns (mass-law/evaluator variants →
  geometry families, per Rod's approval).

## 6. Open items (priority order)

1. **Push** the 7 commits (no credentials in sandbox).
2. **Monitor the campaign** (§5); kill/restart if telemetry shows an
   evaluator regression (the honest window should hold).
3. **Option-2 workstream** (approved, proposal written):
   `docs/plans/2026-08-22-settle-ode-gap-workstream.md` — the settle now
   UNDER-predicts the ODE equilibrium (11.96 vs ~14.3 rad/s; the old
   over-prediction was partly the hub-brake).  Diag script
   `scripts/diag_settle_gap.jl` traces the gap; fix (shared init) after the
   campaign, TDD-style.
4. **Acceptance suite re-baseline** on the campaign winners (gates
   calibrated on pre-fix physics are red-by-design).
5. **ODE-inertia knuckles** (flagged in the mass-law proposal — the ODE
   rotor inertia counts blades only; the DE score counts knuckles).
6. **i_pto = 0.3 kg·m² placeholder** in `params_daisy` (unmeasured).
7. **Repo hygiene** (Phase 6): root diag CSVs/logs (regenerable script
   outputs), stale doc counts (standards-debt audit 2026-08-20), the
   brake-torque scaling + ring-numbering + P_kw-sign convention items
   (each needs a proposal + acceptance tests).
8. **Physics validation ledger** (Phase 5): reconcile `bem.jl` vs
   `aerodynamics.jl` (literature cross-check still OPEN), CT(λ)
   monotonicity, cos²/cos³ elevation factor — against the Daisy anchor.

## 7. Skills for the next session

`ktd-de-campaigns` (launch checklist, campaign reading) · `tdd` (settle
workstream, acceptance re-baseline) · `ktd-campaign-analysis` (winners)
· `physics-convention-audit` (mass law conventions) · `root-file-hygiene`
