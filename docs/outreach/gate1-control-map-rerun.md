Max ... 
# Gate 1 — V10 Tight Control-Map Re-run Plan

**Purpose**: replace every ⟨RB⟩ number in `docs/outreach/technical-report.md`. Blocks the technical report freeze, the Zenodo DOI, and figures F1/F2/F3 of the rebuttal set.
**Superseded artifact**: `scripts/results/control_maps/v10_tight_control_map.csv` (tier X — retain, do not overwrite).

## 0. Preconditions (in order)

1. **Commit the fix set** (settle k_mppt_ref fix, m_blade λ² scaling, hub-radius handling, per-rotor capture fix) — currently uncommitted; HEAD here is still `faddb52`. Record the new short hash; it goes in every provenance footer.
2. **λ=1.0 reproduction gate**: `build_v10_tight_no_lowest()` at 11 m/s, k = 15.6 → expect ~193 kW (post-fix gate value). If this doesn't reproduce, stop — the environment differs from the session that produced it.
3. **Consistency stamp live**: every captured endpoint must log P_ground/(k·ω³). Rows with ratio ≠ 1.00 ± 0.01 are flagged, not silently kept.

## 1. Known defects of the old run (what the re-run must not repeat)

| Defect | Old evidence | Countermeasure |
|---|---|---|
| Settle started from wrong state (k = 614.9 vs 15.6) | 5–9 m/s rows: ω = 0, FoS = Inf, P from unspun shaft (1.2 kW at k≈500) | fixed settle; require ω > 0 at every converged endpoint |
| Partial convergence | gate drifted 166 → 193 kW (+16%) after fix; T_HUNT = 5 s bisection sims | dual-duration check (§3.4) |
| Underpowered winds report garbage instead of max-power point | 5 m/s row: k railed at 500, P = 1.2 kW | when P_rated unreachable, report the pre-sweep peak from a *converged* sim |
| No loss accounting in output | CSV has P_kw only — F3/F6 can't be built from it | add P_aero_kw, P_loss_kw columns (§3.3) |

## 2. Run matrix

**Decision (2026-07-05): hunt MAX POWER (unregulated MPPT), not P_rated.** Rationale: V10 has no pitch regulation; choking to 50 kW via left-flank overspeed rails at the solver's k_min = 2.0 (a numerical-stability bound, not physics — wording matters: regulation is out of scope for V10 torque control, not "physically impossible"); the old map was de facto unregulated at high winds, so max-power is the like-for-like comparison; and PRD figure F1 is specified as the unregulated curve with a 50 kW rated line.

Builders: `build_v10_tight_no_lowest` (λ = 1.0), V10 Reinforced, and the λ = 0.69 blade-rescaled build — identical schema, winds 5, 7, 9, 11, 13, 15 m/s. Modify the hunt to find the peak of the P(k) sweep and run the 60 s verification at that peak. **Persist the full P(k) pre-sweep per wind** (it is the control map — feeds F4 and measures peak flatness, i.e. k-scheduling tolerance); the current script discards all but the peak index. Report the rated-crossing wind (first v where P_max ≥ 50 kW) in the summary for F1/F7.

**Two distinct findings — do not conflate (PRD failure mode #3):**
- *Static–dynamic gap* = P_static(k*, v) / P_ODE(k*, v), same k, same wind. Each row must log the static solver's prediction at the hunted k. The v0.1 claim (static 50 kW vs dynamic 12.1 kW, 4.1×) was static over-predicting; post-fix dynamics deliver ~193 kW at the gate, so the gap may shrink, vanish, or invert — that is what this gate measures.
- *Design-target overshoot* = P_max vs 50 kW rated (e.g. ~193 vs 50 at 11 m/s) — the DE optimizer, compensating for the 3.3× load under-prediction with k_mppt_safety = 3.0, sized an oversized rotor. Separate figure, separate sentence.

## 3. Acceptance criteria per row

1. **Spin**: ω > 0 and steady at endpoint (|dω/dt| below tolerance over final 2 s).
2. **Stamp**: P_ground/(k·ω³) = 1.00 ± 0.01, logged in the CSV.
3. **Closure**: ΣP_aero − P_loss − P_ground residual < 1% of P_aero, logged.
4. **Convergence**: endpoint from T_HUNT and from 4×T_HUNT agree within POWER_TOL (0.5 kW) and 2% on FoS. This is the check that would have caught 172.7 vs 193. Run it at minimum for the final k at each wind, not every bisection step.
5. **Provenance**: CSV carries a header comment: script @ git-hash · builder · date.

## 4. Pre-registered predictions (write down before running)

1. 11 m/s max-power row lands near the post-fix gate: **~193 kW at k ≈ 15.6** (V10 Tight). Static-prediction column at that k determines the re-baselined gap — no prediction registered on its magnitude or sign.
2. 15 m/s FoS: old value 1.36 (fail). No prediction on pass/fail post-fix — this is the genuinely open number, and the honest position is that F2's tier-X point may be joined by a tier-P pass or a tier-P fail.
3. Loss column fits **P_loss ≈ c·ω³, c ≈ 2.2–2.9 W/(rad/s)³** across all converged rows (from the 8-run batch). A two-term fit τ₀·ω + c·ω³ should absorb the low-wind deficit (observed 0.77/0.86/0.95 of v³ at 5/7/9 m/s on λ=0.69). If c comes out design-dependent after all, §3.4.2 of the technical report changes.
4. Low winds (5–7 m/s): P_rated unreachable; expect real max-power points roughly v³-scaled from 11 m/s, minus the growing loss fraction at low ω.

## 5. Outputs

- `scripts/results/control_maps/v10_tight_control_map_postfix_<hash>.csv` (+ λ=0.69 variant)
- Old CSV untouched; F2 shows the old 15 m/s FoS 1.36 point as tier X per PRD §3.7 (history stays visible).
- On completion: strip ⟨RB⟩ markers in `technical-report.md`, replacing each with the measured value and one consistent static–dynamic gap figure (one number, stated once).

## 6. Explicitly out of scope for Gate 1

Loss mechanism attribution (Gate 1 only needs the loss *measured*, not explained), cross-fidelity CL validation, hub-disk radius design coupling, right-flank search. Don't let the re-run scope-creep into these.