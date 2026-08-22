# Handover — 2026-08-22: blade mass law, campaign status, open physics decision

**Session:** Signal, 2026-08-22. Desktop agent.
**Repo:** `~/Documents/GitHub/KiteTurbineDynamics.jl` (HEAD `b5902a0`, working tree dirty — see below).
**Next session focus:** land the blade mass law decision (proposal + acceptance tests), then commit, re-verify, and relaunch the 5 kW campaign.

---

## 1. What happened this session

Rod opened with three questions: why are blades 210 g, is anything making power, did the k-sweep work.

Answers given (all verified against files at the time):

- **210 g** came from commit `b5902a0` (2026-08-21 21:13): "Gate 1c blade mass renormalised for Daisy anchor (420→210 g)". Premise written in the commit was: Daisy measured 3 × 420 g = 1.26 kg/ring on 6 lines; the builder forces `n_blades = n_lines` (6), so per-blade was halved to 210 g to conserve 1.26 kg/ring.
- **Power:** the k-sweep re-run completed at 00:34 with honest telemetry (`scripts/results/k_sweep_daisy_5kw.csv`): k=5.39 → status ok, 7.15 kW mean / 5.97 kW end; k=7.0/9.0 ok ~7.26 kW; k≤4 rejects but with real numbers (not the old 0 kW / FoS=Inf lie). T_lift = 205.4 N constant (const-tension lift, ~14 kg airborne excluding lifter at the 210 g anchor).
- **Campaign:** `v13_5kw_masslift_len18.8` died at 21:15 (externally killed, 1 row; bit-exact repro showed a clean reject, not a crash). Never relaunched. No Julia processes running.

## 2. Rod's corrections — the important part

**Correction 1 (blade mass):** the `b5902a0` premise is wrong. The same physical blades (420 g rigid foam) were used on BOTH the 3-blade and 6-blade Daisy systems. The 6-blade system carried 6 × 420 g = **2.52 kg/ring**. The "3 × 420 g = 1.26 kg" anchor belongs to the 3-blade config (the <2 kg flying-weight record), not to the 6-blade machine the model builds (`n_blades = n_lines = 6`). Docs that support this: `docs/validation/tulloch-prototype-configurations.md` ("6-blade rotor uses the same wings/fuselages as the 3-blade"), `docs/validation/daisy-anchor-provenance.md` (6 blades / 6 lines; 624 W anchor is the 6-blade config). So the 210 g renormalisation must be REVERTED conceptually — 420 g is the measured per-blade anchor.

**Correction 2 (scaling law):** rigid foam mass scales with VOLUME (λ³), not area. Rod explicitly rejected the λ² assumption. Note also: Kitepower-style soft kites scale by area — a different category entirely; do not mix them into the anchor reasoning.

**Correction 3 (constraint shape):** no fixed per-ring total as a floor. The model must evaluate small blades and multi-expansion-rotor designs honestly. Required: a blade density / volume-scaling law, plus a per-node knuckle mass floor (every blade node carries at least knuckle mass).

## 3. Verified code audit (file:line receipts)

- `src/objective_evaluator.jl:303` — `le = blade_scale` (the builder argument; 1.0 in 5 kW campaign calls). NOT the rung scale.
- `src/objective_evaluator.jl:348-357` — main-rotor blade mass `p_base.m_blade × le² × λ_eff²` → with le=1 this is **m_blade × λ² (area)**. This is what feeds the 5 kW campaign.
- `src/builders_util.jl:76-96` — `expansion_params_from_rotors` → `expansion_blade_mass(tip·λ, λ)` = `(0.3 + 0.1·tip·λ)·λ³` — **cube law, CFRP-calibrated constants**, treated as n_blades assembly total (docstring `src/expansion_rotor.jl:445-474`). Two genuinely different laws in one build.
- `src/parameters.jl:533-538` — `mass_scale`: lengths ∝ P^0.5, masses ∝ P^1.35 (≈ R^2.7). Rung-to-rung scaling is volume-ish; leave alone.
- `src/expansion_analysis.jl:37-58` — `expansion_airborne_mass` = tether + n_rings×m_ring + n_blades×m_blade + Σ er.mass + lifter. **No knuckles.** Ring mass (`objective_evaluator.jl:316-323`) is tube-only CFRP (50 g floor).
- Knuckle constants exist in other subsystems but never reach the DE score: `src/trpt_optimization.jl:25` (`OPT_KNUCKLE_MASS_KG = 0.050`, approved 2026-04-20), `src/ring_element_analysis.jl:434` (knuckle self-weight in structural analysis), `src/trpt_axial_profiles.jl` (10–200 g DoF).
- **Bug found:** `src/builders_util.jl:336` — `geometry_fingerprint` does `er.mass × er.n_blades`, but `er.mass` is the assembly total → double-counts expansion blade mass by ×n_blades. Print-only, but wrong and would confuse audits.
- **Not yet verified (flagged, offered, not done):** whether knuckle mass sneaks into ODE inertia states via `build_kite_turbine_system` → `src/initialization.jl` (line 43: `m_rotor = p.n_blades * p.m_blade` — no knuckles seen there).

## 4. Research summary (mass scaling norms)

- Rigid-wing AWES (Kitepower WES 2025, 100–2000 kW): kite mass 700 → 10,663 kg over 20 → 160 m²; ~140–190 W/kg. Soft kites are area-scaling — withdrawn as irrelevant to rigid foam blades.
- Daisy TRPT: <2 kg @ >1.5 kW ≈ 750 W/kg (4–5× better than rigid-wing AWES).
- Wind turbine blades: pure similarity R³; structurally optimised production blades R^2.2–2.5 (DNV 2.2, NREL/WISDEM 2.44–2.54, WindPACT 2.87). Foam-core + shrink-wrap has no spar to shed → stays near R³, consistent with Rod's position.
- Daisy anchor: 420 g per blade, 1.0 m span (tips 1.22/2.22 m), rigid foam construction.

## 5. Proposed physics change (AWAITING Rod's go — proposal + acceptance tests + DECISIONS entry first, per convention)

1. Unified law: `m_blade = m_ref × λ³`, m_ref = 0.420 kg at Daisy reference geometry, for BOTH main rotor and expansion rotors (kill the λ² main-rotor term and the CFRP `(0.3 + 0.1·tip)` constants).
2. Knuckle floor: m_node = m_blade + m_knuckle (≥ 0.05 kg, existing approved constant) added into `expansion_airborne_mass`.
3. Restore 420 g anchor in `params_daisy` (the 210 g renormalisation is dead under a geometry-scaled law).
4. Fix `geometry_fingerprint` double-count.
5. Consequences: seed airborne mass rises (~19–20 kg), T_lift rises toward ~280–305 N, mass-min floor is honest. k-sweep + seed verification re-run on the new law before campaign relaunch.

## 6. Working tree state (desktop, UNCOMMITTED — laptop authoritative)

- `M src/initialization.jl`, `M src/objective_evaluator.jl`, `M test/acceptance_runtests.jl`, `M scripts/diag_chain_state.jl`, `M scripts/results/k_sweep_daisy_5kw.csv` — the 2026-08-21 settle-scan/low-k honest-telemetry fixes (fast suite was 1919/1919 green).
- `?? test/test_settle_lowk_honest.jl` (15/15, wired into acceptance runner), `?? docs/plans/2026-08-21-settle-scan-lowk-stall.md`, `?? scripts/diag_*.jl` (5 files), `?? scripts/results/v13_5kw_masslift_len18.8/` (1-row telemetry).
- Per workflow these wait for laptop review/commit. The blade-mass law change should land on top of them.

## 7. Suggested skills for the next session

- `ktd-desktop-workflow` — campaign launch discipline on the desktop
- `ktd-campaign-analysis` — reading campaign CSVs honestly
- `physics-convention-audit` — the mass law change touches conventions
- `trace-physics-value` / `verify-model-claims` — blade mass through the ODE build
- `tdd` — acceptance tests for the new law (RED → GREEN)
- `root-file-hygiene` — archive this handover once absorbed
