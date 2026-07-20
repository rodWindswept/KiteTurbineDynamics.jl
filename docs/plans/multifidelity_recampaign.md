# PLAN: Multi-fidelity re-campaign — v10 workhorse + v11 anchors + learned discrepancy

**Status:** PROPOSED 2026-07-20 (laptop session, from Rod's framing: "pin the
v10 map with v11 datapoints"). For the desktop to execute after sign-off.
**Prereqs:** Gates 2a/2b/1/3 closed (`DECISIONS.md` 2026-07-19/20). Corrected
physics default ON. `objective_v11` at c355ba6 (~15 min/eval full protocol).
**Read first:** CONTEXT.md, DECISIONS.md last ~200 lines, this doc fully.
Ground rules apply: `run_canonical_sim!` only, progressive CSV saves, cache
clear after src edits, suite green before commits.

## Architecture

Three instruments, one objective:

| Level | Instrument | Cost | Role |
|---|---|---|---|
| L0 | Campaign archive (existing v10 CSVs) | free | Active subspace + coarse landscape |
| L1 | `objective_v10` static (corrected physics via shared force model — verified objective_v10.jl:374) | ~seconds | DE workhorse |
| L2 | `objective_v11` windowed ODE | 4–15 min | Anchors + final verification |

The DE optimizes **f_corrected(x) = f_v10(x) + δ̂(x)**, where δ̂ is a cheap
interpolator fit to anchor pairs (f_v11 − f_v10). v11 never runs inside the
DE loop except on promotion checks.

## Phase 0 — Archive mining (½ day, no new sims)

1. Collect all historical v10 evaluation rows (campaign CSVs under
   `scripts/results/v10_campaign_50kw/` + islands). These are pre-fix
   evaluations — usable ONLY for active-subspace geometry screening (which
   dims move fitness), NOT for fitness values.
2. Rank the 14 genome dims by fitness sensitivity (per-dim variance of
   binned fitness, or a quick random-forest importance). Expect 4–6 active
   dims (likely: n_lines, λ_top/λ_bottom, r_hub, r_bottom, Do_top).
3. Deliverable: `docs/reports/<date>-active-subspace.md` + the dim list that
   Phase 1's LHS stratifies over.

## Phase 1 — Anchor batch (~1 overnight, parallel)

### 1a. Warm-start v11 variant (new: `objective_v11_warmstart`)

Full v11 protocol (settle→kick→spin→60 s window) ≈ 150 sim-s. The anchor
variant skips startup theater:

1. Run `solve_equilibrium_self_consistent` (the L1 path) → ω_eq + settled
   geometry.
2. Initialize the ODE state AT that equilibrium (positions from settle,
   ring ω = ω_eq, orbital velocities consistent).
3. 10 s relaxation + 30 s measurement window at 1 Hz.
4. Score: window-mean P, window-min FoS, window P range (noise weight),
   drift flag. Same fitness formula as objective_v11.

≈ 40 sim-s → **~4 min/anchor**. The trajectory's departure from the fixed
point (limit-cycle amplitude, FoS dips) IS the v10↔v11 discrepancy — this
variant measures the signal minus the startup transient, it does not
approximate it. **Startability is deliberately excluded** — it becomes a
binary full-protocol gate on the final front only (Phase 4).

### 1b. k handling per anchor

L1 has no k; L2 needs one. Per anchor, evaluate a 3-point log bracket
around the λ²-scaled prior (k̂·{0.5, 1, 2}) and keep the best window-mean P.
Gate-1 lesson (0.45-candidate: prior said 28, truth was 56): never trust the
prior with a single point. Record chosen k in the CSV.

### 1c. Anchor selection (target 60–100)

- ~40 by Latin hypercube over the feasible box, stratified on the Phase 0
  active dims, **stratified separately per n_lines value** (categorical —
  see Traps).
- ~10 legacy DE front members (old winner, islands incl. 51, V6.2 recovered
  12-line design) — these anchor the regions the DE will likely revisit.
- ~10 reserved for adaptive infill during Phase 4.

Output: `scripts/results/recampaign/anchors.csv` — genome vector, f_v10,
f_v11, window stats, chosen k, drift flag, git hash, physics era. Progressive
saves, resumable (done-key = genome hash).

## Phase 2 — Correlation gate (RED/GREEN, blocks Phase 3)

On the anchor set, compute Spearman ρ between f_v10 and f_v11 ranks:

| ρ | Verdict | Action |
|---|---|---|
| ≥ 0.7 | GREEN | δ̂ is a small smooth correction — proceed |
| 0.4–0.7 | AMBER | Fit δ̂ per-n_lines stratum (local models); re-check ρ within strata |
| < 0.4 | RED | Instruments disagree structurally; δ̂ cannot fix it. STOP — the campaign must run on v11 directly (small budget, elite-only) and the plan reverts to the hybrid periodic-check scheme. Report to Rod. |

Also report: sign of δ by region (where does static over/under-predict),
and δ vs FoS (static FoS vs window-min FoS discrepancy gets its own δ̂ —
the FoS gate must use corrected FoS, not just corrected power).

## Phase 3 — Discrepancy model δ̂ (½ day)

- Start simple: RBF / inverse-distance k-NN in **normalized** genome space
  (each dim scaled to [0,1] by its bounds), fit separately per n_lines
  stratum, weighted by anchor noise (window P range).
- Two outputs: δ̂_P (power correction) and δ̂_FoS (FoS correction).
- Validation: leave-one-out on anchors — LOO error must be < the anchor
  noise floor (median window range). If LOO error ≫ noise floor, add the
  10 reserve anchors at the worst LOO points and refit.
- No GP library dependency unless k-NN/RBF fails LOO — keep it auditable.

## Phase 4 — Corrected DE + verification ladder

1. DE runs on f_v10 + δ̂ (population parallel, static-solver speed).
   FoS gate: (static FoS + δ̂_FoS) ≥ 1.5.
2. **Promotion check:** any candidate entering the top-10 elite gets a real
   warm-start v11 eval; its pair joins the anchor set; δ̂ refit every ~20
   promotions. (This is where the 10–50× eval saving lives — v11 runs only
   where it changes decisions.)
3. **Mid-campaign divergence tripwire:** if promotion-check v11 values
   repeatedly disagree with predicted f_v10+δ̂ by > 2× LOO error, pause and
   re-run Phase 2 on the enlarged anchor set.
4. Final front (10–15 diverse designs), full protocol:
   - Full v11 (settle→kick→window) — dynamic scoring + **startability gate**
     (binary: does the kick reach a producing state?).
   - **Winner-front α-retest** (mandatory per Gate 1 caveat): 7 α-constant
     perturbations in full sim; ranking flip = recalibrate before claiming.
5. K-re-hunt on the winner (`hunt_kmppt_bisect`) for the operating point.

## Deliverables & maps

- `anchors.csv`, `recampaign_front.csv`, refit-history log.
- Landscape atlas: 2D heatmap slices of f_corrected over active-dim pairs,
  anchors overlaid with δ error bars — via the existing `render_v10_atlas.py`
  tooling (new data files, do not overwrite legacy atlas data).
- DECISIONS entries at each gate (Phase 2 verdict, Phase 4 winner).

## Acceptance criteria

- [ ] Phase 2 correlation gate verdict recorded with the anchor CSV cited.
- [ ] δ̂ LOO error < anchor noise floor, documented.
- [ ] Every quoted corrected fitness = window mean ± range, never snapshot.
- [ ] Final front verified by full v11 incl. startability + α-retest.
- [ ] All new CSVs carry git hash + physics-era + geometry fingerprint.
- [ ] Suite green incl. a regression test: `objective_v11_warmstart` at the
      static equilibrium of a reference design reproduces full-protocol
      window stats within noise (validates the warm-start shortcut once,
      loudly, per design — 2 reference designs minimum, triangle + 12-gon).

## Known traps

- **n_lines and rotor_mask are categorical.** Never interpolate δ̂ across
  n_lines values; stratify. Distance in normalized space must exclude the
  mask dim (decode-dependent).
- **Archive fitness values are pre-fix** — geometry screening only (Phase 0).
- **Anchors are DRIFTING by nature** — always carry window range into δ̂
  weights; a low-noise anchor set would be a red flag (limit cycles are the
  physics).
- **Physics-era column mandatory** in every CSV — this plan's data must
  never be confusable with pre-234a722 numbers.
- **Warm-start ≠ reachability.** A design scored well by warm-start may be
  unreachable by any start protocol; only the Phase 4 startability gate
  clears it for the outside world.
- Desktop/laptop clone sync: commit + push at every phase boundary.
