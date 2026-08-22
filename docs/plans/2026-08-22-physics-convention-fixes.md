# Proposal — physics-convention fixes from the 2026-08-20 standards audit (2026-08-22)

**Status:** PROPOSAL — read-only analysis done; NO code changes while the
5 kW campaign runs (the running campaign's provenance must stay tied to HEAD
`adea1a3`+). Land these after the campaign, TDD-style, with acceptance tests
and DECISIONS entries.

Source: `docs/audit-2026-08-20-standards-debt.md` §2 (science conventions),
re-verified against HEAD on 2026-08-22.

## 1. Generator/brake torque scale law — LINEAR vs QUADRATIC (MAJOR)

**Receipts:**
- `src/simulation.jl:343` — `power_scale = p_base.p_rated_w / 10_000.0`
  (LINEAR), with the comment "matches ring_forces.jl logic" — **false**.
- `src/ring_forces.jl:142,149` — `power_scale = (p.p_rated_w / 10000.0)^2`
  (QUADRATIC) feeding `tau_max_safe = 2500·power_scale` and the torsional
  damping coefficients (`c_d = 10·power_scale`, `c_d_active = 15·power_scale`).

**Consequences (verified):**
- At 5 kW: linear 0.5 vs quadratic 0.25 → the generator clamp differs 2×
  (`tau_max_safe`: 1250 vs 625 N·m).  The 5 kW machine operates at
  τ ≈ P/ω ≈ 8000/15.3 ≈ 523 N·m — the quadratic clamp (625 N·m) sits only
  20% above the operating point and will BIND on transient overshoots;
  the DE could exploit or be distorted by it.
- At 50 kW: 5 vs 25 → 5× divergence (62,500 N·m clamp — never binds, so
  the 50 kW results were unaffected in practice).
- At 300 W (anchor rig): quadratic gives 2.25 N·m vs the MEASURED
  20–24 N·m (9× under-clamp, audit §2.4) — the quadratic law is
  wrong at small scale, exactly where we now work.

**Proposed fix:** a single `generator_torque_cap(p)` derived from the
machine's RATED torque.  τ_rated = P_rated/ω_rated with ω_rated ∝ v/R and
R ∝ P^0.5 → τ ∝ P^1.5; a cap at `k_cap · P_rated^1.5` (or, better, the
design's actual τ at the rated point, e.g. `p_rated_w / (v_rated·λ_design/R)`),
used by BOTH ring_forces and simulation.  Acceptance tests: cap matches the
anchor-rig measurement band at 300 W; equals the operating τ with ≥50%
margin at 5 kW and 50 kW; simulation.jl and ring_forces.jl agree at 5/10/50 kW.

## 2. Ring numbering — code ground=1 vs docs hub=1 (MAJOR, docs+code)

**Receipts:** code `src/initialization.jl` ring 1 = ground; DECISIONS.md and
ADR 0001 describe ring 1 = hub (audit §2.3).  The code convention is the
authoritative one for ODE state layout (`u[6N+1:6N+Nr]` α block, ring 1 =
ground).  **Fix:** update the docs (DECISIONS, ADR 0001, CONTEXT) to state
"ring 1 = ground (code convention)" and add a doc test asserting the ODE
layout's ground-first ordering so neither side drifts again.

## 3. `P_kw` sign-masking — `tau_gen * abs(omega_gnd)` (MAJOR)

**Receipt:** `src/sim_frame.jl:133,462` — `P_kw = tau_gen * abs(omega_gnd)`
masks a reversed ring as positive "generation".  The v13 gate uses SIGNED
`P_gen = τ_gen·ω_gnd`.  **Fix:** signed power in sim_frame (dashboard shows
negative generation when the ring reverses — the dashboard labels it
"electrical" too, which is wrong: it is mechanical shaft power, audit §2.6).
Acceptance: sim_frame P_kw sign equals the gate's signed P_gen for a
reversed-ring test case.

## 4. `tau_max_safe` hidden-unit law (MAJOR)

**Receipt:** `src/ring_forces.jl:143-144` — `2500·(P/10000)²` is a magic
constant with hidden units (N·m at 10 kW).  Folded into fix 1 (the cap
derives from the rated operating point).  Remove the magic 2500.

## 5. Minor items (batch with the above, one commit each or one proposal)

- `src/objective_v10.jl:170,189` — `sind(30.0)` hardcodes the elevation
  duplicating `p.elevation_angle` (audit §2.5).
- `src/objective_evaluator_ramp.jl:237` — manual `* pi / 180.0` instead of
  `deg2rad` (audit §2.7).
- `src/parameters.jl:251-252` — `pi/6` literal next to `deg2rad(70.0)`
  (audit §2.8); `elevation_angle` lacks the `_rad`/`_deg` suffix (audit §2.9).
- `src/builders_util.jl:264-267` — comment "drop lowest" but code pops the
  HIGHEST ring_idx (audit §2.10 — verify intent before fixing).
- `src/objective_evaluator.jl` — ObjectiveConfig mixes W and kW fields
  (audit §2.12 — cosmetic; keep W for physics, document).
- `src/ring_forces.jl:377,145` — τ_gen sign semantics never declared
  (audit §2.13 — document in the docstring).

## Sequencing

0. **URGENT — non-finite-FoS guard in mass/v12 fitness (2026-08-22, found
   during campaign monitoring).** `mass_min_fitness` (`objective_v12.jl:86`)
   and `v12_fitness` (`objective_v12.jl:29`) test `FoS_min < cfg.fos_hard`
   WITHOUT an isfinite guard — `FoS_min = Inf` (null structural measurement,
   exploit-register row 1, fixed in `objective_feasibility` but NOT here)
   passes the floor and scores the mass.  A machine that transmits ≥5 kW
   with unmeasured ring loads (FoS=Inf) would be crowned.  **Fix (TDD,
   immediately after the running campaign):** `(!isfinite(FoS_min) ||
   FoS_min < cfg.fos_hard) && return Inf`; RED test in test_objective_v12.
   MONITOR the running campaign's telemetry for `ok` rows with FoS=Inf —
   if any appear, the campaign is polluted and must be killed/restarted
   after the fix.
1. Campaign completes (running now, ~22–35 h) → winners re-gated.
2. Land fix 1 (torque cap) + fix 4 (magic law) as one TDD change with the
   acceptance tests — then re-run the honest k sweep once to confirm the
   operating map is unchanged or improved at 5 kW.
3. Fixes 2, 3 (docs + sign) — smaller, independent.
4. Minor batch.
5. Re-baseline acceptance suite once (all convention fixes together) rather
   than per-fix, to amortise the ODE test cost.
