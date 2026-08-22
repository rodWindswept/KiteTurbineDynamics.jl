# DECISIONS.md — KiteTurbineDynamics.jl

Running log of architectural and physical decisions. One entry per decision, newest at top.
Each entry explains the situation, what was decided, what alternatives were on the table, why
this choice was made, what it enables and rules out, and whether it is still active.

The purpose of this file is to make the reasoning behind the simulator transparent — so anyone
reading the code can understand not just *what* was done but *why*, and so future contributors
can assess whether a decision still holds when circumstances change.

---

## [2026-08-21] Daisy-anchored 5 kW seed fixes (rung scaling, lifter tension, annulus gates)

**Context:** The Daisy seed for the 5 kW mass-min re-run stalls
(`:reject`, 0 kW). Desktop reproduction (`scripts/diag_daisy_seed_stall.jl`)
showed the ODE actually sustains ω_gnd = 7.87 rad/s — the machine was fine;
the generator gain was wrong. `params_at_length` theory-scaled k_mppt from
`params_10kw` (a 10 kW DRR design) → k = 1.94 → P = k·ω³ ≈ 0.95 kW, an order
of magnitude below the 5 kW floor. Rod 2026-08-21: all rung scaling anchors
on the MEASURED 1.5 kW Daisy (Tulloch config 8), never on the 10 kW DRR
theory or the 50 kW BOM (extrapolation, not anchor).

**Choices made (Rod):**
1. **`params_daisy()`** — measured anchor (ring 1.52 m, tips 1.22/2.22 m,
   blade 420 g, TRPT 10.31 m, 6 lines, 3 blades, tether 2 mm,
   k = 0.175 @ 624 W/146 rpm, Cp_sys 0.16). Rungs scale via
   `mass_scale(params_daisy(), 1.5, target_kw)`.
2. **r_bottom decoder clamp** 1.5 m → 0.1 m (50 kW-era floor blocked
   Daisy-scale geometry; seed gene 0.575 was silently forced to 1.5 m).
3. **Lifter mass excluded from lift-line tension sizing** — the stack
   carries itself with its own lift; `sized_lifter_for` now sizes on
   `expansion_airborne_mass(; include_lifter=false)`. The runner PROVENANCE
   note claiming this was already true was wrong until this fix.
4. **Betz gates aligned to the ODE's annulus areas** — the ceiling used
   base-theory hub radius + blade offsets; expansion per-rotor Betz used full
   disk. Both now use the same π(r_out²−r_in²) annuli the ODE sweeps
   (main_rotor_swept_area / expansion_annulus_area). The `A = 2π·r_ring·L`
   identity comment corrected (valid only for a 50/50 split).
5. **Runner/smoke reference-tension path** passes `base_params=p_base`
   (was defaulting to the 50 kW base → phantom 81 kg / φ 16.3).

**Consequences:** new physics era for the 5 kW rung
(`post-4ce9fd0_daisy-anchored-5kw`); 50 kW default paths bit-identical.
k_mppt for the 5 kW seed determined by sweep (k=5.39, knee at k≈4.0 —
theory-scaled 3.55 is sub-knee and rejects at 0 kW); seed smoke must
pass before the campaign launches. Lifter test updated to assert the new
tension convention.

**Gate alignment (same machine, same rules — Rod 2026-08-21):**
`ode_gate_v13.jl` (and regate/ladder via include) previously built the
10 kW-DRR-theory machine (`params_10kw`, `mass_scale(..., 10.0, KW)`,
theory k) — a different machine than the campaign runner. Aligned to the
Daisy anchor: `params_daisy` base, `mass_scale(..., 1.5, KW)`,
sweep-selected k=5.39 at 5 kW, power floor 5.0 kW (was 2.5), L default
18.8 m. One machine + one lift + one operating point across runner,
smoke, gate, regate, ladder.

**Open:** Daisy i_pto not measured (0.3 kg·m² placeholder); φ mass exponent
underdetermined (field tests).

**RESOLVED 2026-08-21 — Gate 1c blade mass:** the builder forces
n_blades = n_lines (balanced polygon) while Daisy measured 3 blades on 6
lines, doubling blade mass (6 × 420 g vs measured 1.26 kg/ring). Fixed by
renormalising the anchor's per-blade mass to 210 g (3 × 0.420 / 6) so the
built machine's 6-blade rotors total the measured 1.26 kg/ring — same
precedent as params_10kw m_blade 11/5 (2026-07-18). Only Daisy had the
mismatch; all other params sets are n_blades = n_lines consistent.

**Still active:** yes.

---

## [2026-08-20] Test-suite split: fast unit vs slow acceptance

**Context:** Wiring the five ODE-heavy acceptance tests into test/runtests.jl
made the default suite jump from ~3.5 min to ~40 min. Each acceptance file runs
a 30,000-step settle plus 5-30 s simulation windows at dt=4e-5. The five files
were originally standalone scripts for exactly this reason.

**Choice made:** split the suite.
- test/runtests.jl = the 34 fast unit tests (~3.5 min). Run before every commit.
- test/acceptance_runtests.jl = the five ODE acceptance tests, run as five
  parallel subprocesses (~18 min). Run before a merge that touches physics.

**Mechanism (so the acceptance tests run only when they must, never again
hidden):**
- CI: .github/workflows/acceptance.yml runs the acceptance suite only when
  src/, scripts/ode_gate_v13.jl, scripts/compute_seeds.jl, or the five
  acceptance files change, or on a merge to master.
- Local: .githooks/pre-push warns when a push touches those paths.
- The fast unit suite runs on every push/PR in ci.yml.

**Rule:** never wire the acceptance files into test/runtests.jl. If you do, the
default suite jumps to ~40 min. The two test files carry header comments that
repeat this rule.

**Still active:** yes.

---

## [2026-08-20] Signed P_gen — τ_gen·ω_gnd everywhere (reverse regen reads negative)

**Context:** `P_kw`/`P_gen` drifted to two masked variants after the 2026-08-13
gate work: `src/sim_frame.jl` used `τ_gen·abs(ω_gnd)` (masks −ω → +) and
`scripts/ode_gate_v13.jl` used `τ_gen·max(ω_gnd,0)` (masks −ω → 0). Both hide a
reversed or regenerating generator. `get_generator_torque` is signed (damping
terms + the `±tau_max_safe` clamp), so `τ_gen·ω_gnd` is the correct electrical
power and is negative when the generator absorbs mechanical power.

**Choice made (2026-08-20, science-worker, per DECISIONS [2026-08-12] rationale):**
unify to signed `P = τ_gen·ω_gnd` in both readers. A reversed/regenerating
generator reads negative, not positive (abs) or zero (max). The `:table` /
`:const_power` no-regen floor (`ω_gnd ≤ omega_floor → τ=0`) is a τ-side clamp and
is unaffected — below the floor P reads zero, never negative. Healthy designs
(ω_gnd>0, τ_gen>0) are bit-identical.

**Consequences:** new physics era for settle-based paths (signed-ness change in
src/). Only designs that reverse or regenerate change value. Acceptance tests in
`docs/plans/2026-08-20-science-track-acceptance-fixes.md`.

**Still active:** yes.

---

## [2026-08-20] Lift-consistency invariant (Rod's ruling)

**Context:** A4's bit-identity broke because the gate migrated to the
mass-aware constant-tension lift (commit 0ee2d4c, 2026-08-19) while its test
still settled with `rotary_lifter_default()`. Different lift → different settle
→ ~3.5% drift.

**Choice made (2026-08-20, Rod):** a lift regime uses ONE concept+values across
every surface that adjusts lift tension — build, settle, ODE, gate, evaluator,
runner, tests. The canonical mass-aware lift is
`lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`.
Tests of the v13 gate/evaluator must settle/run with `lift_for`, never
`rotary_lifter_default()`. Lift-agnostic physics tests may keep a stable
fixture.

**Consequences:** `lift_for` is hoisted to a single top-level definition in
`scripts/ode_gate_v13.jl` (shared by gate + both v13 tests). Resolved same day:
the gate and both v13 tests initially passed `lift_for(sys, p)` (params_at_length,
n_lines=5) while `evaluate_windowed` passed `lift_for(sys, pc)` (genome-specific,
n_lines=6) — a different airborne mass and lift tension. Rod ruled this a software
bug (fixed reference vs the genome's own params), not a physics decision: all three
call sites now pass `lift_for(sys, pc)` (6=6).

**Still active:** yes.

---

## [2026-08-16] April-29 anchor: thesis geometry + measured generator load + stable dt

**Context:** The April-29 (2020) mast-mount rig (thesis config 9 = TRPT-5, 6
foam blades) is the calibration anchor for the 5 kW systems. The model was
"wind-blind" — 13.5 W / 5.98 rad/s at every wind. Diagnosis (source trace +
instrumented ODE) found two compounding artifacts, not rig physics:

1. **Numerical instability, not aero decoupling.** The 2 mm UHMWPE rope
   sub-segments (0.125 m) have a spring mode ω ≈ 2.6 MHz; explicit Euler at
   dt=4e-5 runs at ω·dt ≈ 103 (unstable by ~50× vs the 5 kW config's ω·dt≈1).
   The state diverges within ~8 steps, line-path strain exceeds the 3.5%
   break threshold, and the 2026-08-14 rope-break detector (option B)
   correctly kills the sim at step 7 — before any equilibrium exists. The
   "13.5 W at every wind" was the initial state, never a steady state.
2. **Generator torque clamp crushed the small rig.** `tau_max_safe =
   2500·(p_rated_w/10000)²` gives 2.25 N·m at p_rated=300 W — P = 2.25·ω =
   13.5 W at ω=6 exactly. The measured Quarq power ÷ controller rpm shows
   the real load: plateau τ ≈ 20-24 N·m at ω ≈ 9.5-12.5 rad/s (~9× the
   clamp), i.e. roughly constant power ~216-228 W (VESC charging a battery
   at ~constant current; 6.9 A × 36 V ≈ 250 W electrical ✓).

**Choice made (2026-08-16, Rod):**
1. **Builder geometry per the thesis** (config 9, Rigid Wings §3.1.1):
   rotor outer tip radius **2.22 m** (was 1.95), rotor ring **1.52 m** (was
   0.35), TRPT-5 total length **9.5 m** (Table 3.1; was 5.5), blades span
   1.0 m / chord 0.2 m / NACA 4412 / no twist / 4° pitch (was a 1.70 m
   annulus on the 0.35 m ring). Lower TRPT sections stay 0.35 m radius
   (70 cm hex rings); canonical taper law gives trpt_rL_ratio = 1.083.
2. **Measured generator load**: new gated `GeneratorLoadMode`
   (`set_generator_load!`): `:table` mode implements the measured τ(ω)
   curve — 12 knots = 30-s steady-block means (Quarq power ÷ controller
   rpm, 22.65→13.11 N·m over 9.75→12.86 rad/s; flat below/above; the
   earlier low-ω knots came from startup-transient rows and were dropped
   2026-08-16 pass-2 audit) — with a no-regen floor at 2.5 rad/s (the
   VESC "Too Slow 4 gen" behaviour; below it, incl. reversal, τ=0;
   without the floor a reversed ring locks at τ_cap and low-wind sims
   stall). `:const_power` (τ = P_set/ω) remains for other uses. Both
   bypass k_mppt, elevation scaling and the tau_max_safe clamp. Default
   `:mppt` is bit-identical for all campaigns. The tau_max_safe quadratic
   scaling remains flagged for a follow-up (latent for any small-rig sim).
3. **dt = 4e-6 for anchor sims** (smoke-verified 2026-08-16: ω·dt ≈ 10 at
   2 mm ropes, stable with the ζ=0.05 sub-segment damping; dt=4e-5 was
   unstable — ω·dt ≈ 103, rope-break at step 7).  ~14.3k steps/s.
4. **lifter_elevation = 10°** (was 85°): the bearing→mast-head line is the
   10° axis extension; the 12 kg bucket (118 N) acts on the bearing upward
   at 10° through the pulley. 85° described the bucket's hanging side,
   which is only the tension source.  **Bucket tension is CONSTANT**: new
   `StackedLifterParams.const_tension` flag (default false, bit-identical)
   — a hanging weight does not scale with v² like a kite; the v² law
   turned the 12 kg bucket into 22 N at low wind (slack chain).
5. **i_pto = 0.25 kg·m²** (was 0.05): 0.63 m ground wheel + 1:2.14 chain
   drive + 500 W generator (thesis §3.1.4) — the real drivetrain inertia.
6. **No expansion rotor on the anchor rig.** The builder's "hub rotor" was
   the same 10.8 m² annulus as the main rotor; the expansion-rotor α-model
   + induction drives the disk loading to a→0.5 at the 6-blade solidity,
   CL goes negative, and the element brakes the machine — bleeding it from
   13 rad/s to a stop in ~12 s (diag 2026-08-16). The main cp_at_tsr rotor
   IS the thesis's 6-blade representation (AeroDyn 3-blade + solidity
   trick). The expansion-rotor model is untouched for the DE campaigns.

**Verified:** anchor sim survives 25 s at dt=2e-6 with no rope break; spins
up from the 6 rad/s warm start; P-vs-wind comparison vs the measured bins
(212-227 W @ 5-8 m/s, 178-194 W @ 3.25-3.75 m/s). R1-R3 + full suite green.
**Still active:** yes. Open follow-ups: tau_max_safe quadratic scaling;
sensor reconciliation (con_rpm vs SRM cadence vs tip-derived R≈2.3 m — thesis
2.22 m adopted); uniform 0.864 m ring spacing vs Rod's 50 cm lower + graded
(ring_spacing_v4 if the comparison demands it).

---

## [2026-08-14] Rope break physics — lines fail at SK99 strain, disqualifying the machine

**Context:** After A2 (cp falloff), B (per-rotor Betz) and C1 (torque saturation)
landed, P4 stayed red: the old 18 m winner still reached ω_hub = 3.54e69 via a
new mechanism — *translational fling*. Its ultra-light hub ring (t_over_D =
0.005 → 0.14 mm walls, ~58 g) is flung outward by rotor thrust; the spring law
then integrated unbounded line stretch to ~1e135 N, whose torque exactly
cancelled the aero brake at the balloon fixed point. The model had no rope
failure, so tension was physically unbounded.

**Choice made (2026-08-14, Rod):**
1. **Break strain ε_break = 0.035** — Dyneema SK99 (3.5% ultimate strain).
2. **Option B consequence — break = immediate disqualification.** At the first
   step where a line exceeds the limit, the line is marked broken (zero
   tension), `any_broken` latches, `run_canonical_sim!` stops at the step
   boundary, and the evaluator rejects with `line_broken=true`. No wreckage
   physics: post-break dynamics have no calibration data and cannot change a
   verdict — the design is dead the instant a line fails.
3. **Break criterion is line-path strain, not per-sub-seg strain.** TRPT lines
   are ring→rope-node→…→ring chains; per-numerical-sub-seg strain trips on
   mid-node placement artifacts (the legacy builder settles with a 340%-strained
   rope node) and measures the wrong quantity. The full ring-to-ring path strain
   (`sub_seg_trpt_seg` map, precomputed at build) is the physical line strain.
4. **Breaks only during real operation.** `breaks_enabled` latches on in
   `run_canonical_sim!`; the settle's exploratory ω-scan transients over-strain
   lines momentarily and must not break healthy machines before their eval.
5. **C1 reworked onto the TRPT-chain map** — the original `both_rings` branch
   never fired for real TRPT lines (see context below), so the saturation clamp
   was inert where it mattered. The clamp now operates on the per-segment
   transmitted torque with action-reaction (`+τ` ring s, `−τ` ring s+1).
6. **Companion fix (a) landed: t_over_D floor 0.010** (the seed's own value —
   no thinner than the starting design); scale-aware static-gate re-enable is
   Monday's retrospective item.
7. `ObjectiveResult.line_broken` — rejection reason is recorded; B1 accepts
   either structural signature (twist OR line break) since the collapse
   design's failure mode is now the break.

**Verified:** R1–R3, P1–P4, B1–B7, suite 1900/1900. The 18 m winner breaks at
~44 kN elastic (≈105 kN sampled incl. viscous damper term), max|ω| = 17.9 rad/s
— no balloon. Healthy seed unchanged in behaviour (ω_gnd 13.18, no break).

**Still active:** yes. ε_break and the floor are rung-specific calibrations;
the Monday retrospective covers the scale-aware gate question and the Q1
(lin_damp) fling verdict.

---

## [2026-08-13] Evaluator v13 — the test that identifies realistic KTD designs

**Context:** The 5 kW campaign evaluator crowned designs the corrected ODE gate rejects.
Three scoring defects compounded (source-confirmed, then acceptance-tested): (1) it scored
P_mean over a 10 s hot-settle window — flywheel energy, not transmission; (2) `v12_fitness`
penalised power ABOVE the rung ceiling, so the seed (delivering ~7.5 kW) scored worse than
a flywheel design decaying through the [2.5, 5.0] kW window; (3) it never read the twist
state, so the torsionally-collapsing island-1 winner scored `:ok` at 6.3 kW. The acceptance
tests then exposed two further protocol defects: the cold path's 2 s kickstart (k=−60, a
legacy ζ=1.5 stall escape) itself wound a healthy seed's chain past δα*, and every 5 kW eval
silently ran at `ObjectiveConfig`'s default `k_mppt=10.0` (~5× the scaled system's rated
gain), inflating window power.

**Choice made (v13, all opt-in via `ObjectiveConfig`; defaults preserve v12 exactly):**
1. **Twist collapse rejection** — `twist_collapse_check(u, sys)` reads the raw free-integrated
   α states (`u[6N+1:6N+Nr]`), per-segment Δα vs the geometric crossing limit
   δα* = 2·asin(L/√(2(L²+2r²))), r = max(r_i, r_{i+1}); any crossing → hard reject. Exported;
   `ObjectiveResult` carries `twist_crossed`.
2. **Sustained power** — `power_stat=:tail5` feeds the fitness the mean of the last 5 window
   samples (`P_end`), not the full-window mean.
3. **No over-delivery penalty** — `penalize_ceiling=false`: above-ceiling power at rated wind
   is headroom; the Betz hard gate still rejects cheating.
4. **Ring-FoS soft target off at 5 kW** — `fos_target=fos_hard=1.5` (guarded in `v12_fitness`)
   stops the below-target quadratic from favouring light/unloaded structures; torsional
   safety is carried by the twist detector.
5. **Kickstart off** — `kickstart_s=0.0`; with ζ=0.05 the settle reaches the productive
   branch directly and the motor kick is an obsolete stall crutch that winds chains past δα*.
6. **Rated MPPT gain** — `cfg.k_mppt = p.k_mppt` (the scaled system's gain, ≈1.94 at 5 kW),
   not the 50 kW default 10.0.
7. **Tip-speed sanity (2026-08-14, tightened same day per Rod).** `tip_speed_sanity_ok(u, sys)`:
   every TRPT ring rim and every rotor tip (hub + expansion) must stay ≤ 100 m/s — anchored
   to the design point (~44 m/s at TSR 4, 11 m/s wind). The first v13 campaign (18 m) crowned
   a design (−6.66) whose hub ring diverged to ω≈3.5e66 within 5 s (r_hub=0.474, inverted
   taper, n_active=1) while P_gen read 8.6 kW and twist 0.0 — ground-side instruments cannot
   see a diverged ring. The Betz gate is output-side (generator power vs swept-area ceiling)
   and correctly passed it; state-integrity failures need state-variable ceilings. Hard reject
   in the evaluator and gate; r_hub lo raised 0.2 → 0.7 m; acceptance B6/B7 green, suite
   1901/1901.

**Acceptance (test/test_evaluator_v13.jl, RED on master → all green):** B1 island-1 winner
`:reject`, twist_crossed=true. B2 18 m flywheel winner `:reject`. B3 original seed `:ok`,
twist_crossed=false, P_end=4.2 kW, fitness −1.075 — strictly outranks the flywheel design.
B4 fitness(7.5) < fitness(3.5). B5 detector flags a +π-wound segment, not the post-settle
state. Full suite green 1901/1901 (the metric-consistency grep guard's 8 flagged scripts
were fixed to use `get_generator_torque`).

**Alternatives:** keep the v12 evaluator and rely on post-hoc gating (rejected — the DE
re-discovers the flywheel/collapse attractors every generation); lengthen the window only
(rejected — the collapse and decay regimes need the twist detector and tail scoring, not
just more samples).

**Consequences:**
- No verified 5 kW DE winner exists; the seed is the only design passing the corrected
  evaluator. Previous v12 campaign fitness values are void for ranking purposes.
- `scripts/run_v13_5kw.jl` is the new 5 kW campaign runner (full-genome telemetry).
- v12 warmstart/ramp paths are untouched (defaults preserved bit-for-bit).

**Status:** active. Proposal: `docs/plans/2026-08-13-evaluator-v13-realistic-ktd.md`.

---

## [2026-08-13] ODE gate reads generator-side power and per-segment twist (ode_gate_v13)

**Context:** The 2026-08-13 power-budget investigation of the 5 kW island-1 winner found the
V12 gate's `P = k·ω_hub³` metric was measuring freewheel power: during torsional collapse the
hub held ~9–15 rad/s while the ground ring fell to zero. The gate reported "6.34 kW sustained"
for a machine whose generator output was zero after t≈50 s. The collapse itself — twist
concentrating at the top segment to 22,425° (62 revolutions) against a 42.6° crossing limit —
was only visible in the twist state, which the gate never read.

**Choice made:** Two instruments in the gate, both reading the ODE's own state:
1. `P_gen = τ_gen·ω_gnd` with `τ_gen` from `get_generator_torque` (the exact function the ODE
   uses; Mode 0 MPPT extracts at the ground ring, `src/ring_forces.jl:70`).
2. Per-segment twist check: `Δα_i = |α[i+1]−α[i]|` vs the geometric crossing limit
   `δα* = 2·asin(L/√(2(L²+2r²)))`, r = max(r_i, r_{i+1}) (conservative). Any segment past its
   limit fails the gate regardless of power.
Acceptance tests A1–A4 green (`test/test_gate_v13.jl`): the collapsing winner fails
(twist ratio 169×, P_gen 0.84 kW); the post-settle state is not flagged (ratio 0.13); P_gen is
numerically identical to a direct `τ_gen·ω_gnd` recomputation.

**Verdicts under the new gate (2026-08-13):** 18 m winner ❌ (P_gen 4.06→1.41 kW, flywheel
decay, no crossing), 25 m winner ❌ (4.18→0.86 kW), island-1 winner ❌ (twist collapse),
original 5 kW seed ✅ (P_gen 8.0→4.12 kW, twist ratio 0.3, ω_gnd 12.85). The gate separates
the three regimes — decay, collapse, and genuine transmission — and passes the seed.

**Alternatives:** keep the hub metric (rejected — measured freewheel power); static torsional
FoS gate alone (rejected for this change — it is a separate, still-open proposal to re-enable
it as a hard gate at ≤7 kW; the ODE confirmed its collapse prediction).

**Consequences:**
- All 2026-08-12/13 5 kW "sustained power" verdicts are void: hub freewheel or flywheel
  decay, not transmitted power. No verified DE winner exists at 5 kW; the seed passes.
- The V12 campaign evaluator (10 s window) must be re-instrumented with the same two metrics
  before any new campaign — DE ranked flywheel designs above the seed-like designs.
- Gate scripts `gate_length_winners.jl` / `ode_gate_5kw_winner.jl` are historical record.

**Status:** active. `scripts/ode_gate_v13.jl` is the reference gate.

---

## [2026-08-12] Rope structural damping ζ promoted to SystemParams (default 0.05)

**Context:** Every ODE simulation — regardless of genome, k_mppt, or start-up strategy —
converged to a stable reverse-rotation state at ω ≈ −0.2 rad/s. The static BEM scan predicted
22 kW peak for the V10 Reinforced genome, but the ODE never produced sustained positive power.
Two sessions of diagnostics (k_mppt sweeps, kickstart protocols, lift-device wiring) found no
parameter-level fix.

**Root cause:** `initialization.jl` hardcoded `zeta = 1.5` for all rope sub-segments, driving
`c_damp = 2·ζ·√(EA/L·m)` to ~30-150× physical Dyneema material damping (ζ ≈ 0.01-0.05). The
tension rectifier `max(0.0, EA·ε + c_damp·v)` in `rope_forces.jl` clips the damper contribution
asymmetrically — the damper can add tension at full strength but is clipped when subtracting.
Over any oscillation cycle this rectification leaves a non-zero mean force (DC bias), which at
ζ=1.5 overwhelms the aero torque and parks the rotor at negative ω. A pure damper has no offset
(equilibrium at ω=0); the rectifier is the symmetry-breaking term and ζ is its gain.

**Diagnostics:** ΔL_z measurement across `orbital_damp_rope_velocities!` exonerated the orbital
velocity overwrite (mean ΔL_z ≈ 0). Zeroing c_damp eliminated the stall (ω: 2.0→10.7 rad/s).
ζ=0.05 (1/30th) confirmed: low-ω cold start → 10.56 rad/s, MPPT sustain, no stall.

**Choice made:** Promote ζ to a `SystemParams` field with default 0.05. All callers pick it up
through the grouped-spec constructor; `override_params` auto-adapts via `fieldnames`. The prior
magic number is now tunable, traceable, and auditable in the DE genome if ever needed.

**Consequences:**
- Reverse-torque bias eliminated; ODE now sustains power at all tested scales
- ζ=0.05 is physically grounded in Dyneema material damping, not stability headroom
- Test suite: 1902 assertions green
- See `handovers/handover-2026-08-12-zeta-damping-fix.md`

**Status:** Active. Implemented 2026-08-12.

## [2026-08-11] FoS hard cap at 16 in V12 fitness

**Context:** DE campaigns were producing designs with FoS=287, dominating the population because
the gentle linear above-target penalty (w_fos_above=0.02) let high-FoS designs score nearly as well
as target-FoS designs. These are physically unbuildable machines with massive ring beams.

**Choice made:** Added `fos_cap::Float64 = 16.0` to `ObjectiveConfig`. In `v12_fitness`, FoS > fos_cap
returns `Inf` (hard rejection, status=:reject). This is NOT a penalty -- the design cannot progress.
Below the cap, the existing gentle linear slope still allows the DE to follow a gradient toward the
3.0 target.

**Consequences:**
- FoS=17 is rejected, FoS=16 is the maximum accepted value
- DE no longer wastes generations on heavy designs
- `fos_cap` is a tunable ObjectiveConfig field (default 16.0)
- Tested: 6 new assertions in `test/test_objective_v12.jl`

**Status:** Active. Implemented 2026-08-11.

## [2026-08-11] P_available(v) Betz floor gate

**Context:** The control-first design sweep (5-15 m/s) was rejecting geometries at low wind speeds
because the evaluator could not hit P_rated at winds where physics cannot deliver it. At 5 m/s,
available power is only (5/11)^3 ~ 9.4 percent of rated -- a 50 kW system cannot produce 25 kW
at 5 m/s regardless of geometry quality.

**Choice made:** Added a P_available(v) gate in `evaluate_windowed` that checks:
`Cp * 0.5 * rho * A_total * v_rated^3 / 1000 >= P_floor * 0.8`
If the wind cannot physically reach 80 percent of the power floor, the evaluation returns `:reject`.
Uses the rotor actual Cp (not Betz 0.593) so small/low-Cp rotors gate correctly.

**Consequences:**
- Geometries are no longer falsely rejected at low wind speeds
- The gate sits alongside the existing Betz ceiling check (P_mean < 1.1 * Betz_max)
- 80 percent threshold prevents edge cases where the floor is just barely reachable

**Status:** Active. Implemented 2026-08-11.

## [2026-08-11] Ramp-controller evaluator (evaluate_ramp)

**Context:** The DE evaluator used a 3-point k bracket (k_prior scaled by 0.5, 1, 2) with fixed
k_mppt during the scoring window. The dashboard uses RampController (IDLE to RAMPING to HOLDING)
which dynamically adjusts k with structural guards. The two paths could converge to different k
values for the same genome.

**Choice made:** Built `evaluate_ramp()` in `src/objective_evaluator_ramp.jl` -- a new evaluator
that uses the RampController to discover the sustainable k_mppt dynamically. Protocol:
warm pre-solve -> settle -> RampController chunked loop (2s ODE chunks with update_ramp!) ->
60s scoring window (ramp continues, k never frozen) -> score via the same fitness_fn seam.
k_mppt is NOT in the genome (14-D V10) -- it is an output of the evaluation.

**Consequences:**
- Dashboard and evaluator now share the same k-selection path
- Ramp mode is 3-10x slower than bracket mode (acceptable for calibration campaigns)
- Ramp results can calibrate the fast bracket lambda-squared scaling factor
- V12 adapter: `objective_v12_ramp()`
- Not yet CI-tested (short-horizon smoke test pending)

**Status:** Active. Implemented 2026-08-11. Pending first calibration campaign.



## [2026-06-25] Bank angle bound tightened 35° → 25° for pitch depower blade-tip clearance

**Context:** During pitch depower, the shaft elevates to ~65° from horizontal to spill
wind. At the top of the shaft rotation circuit (12 o'clock position), a blade extending
radially from a ring points upward at (90° − θ) from horizontal where θ is shaft elevation.
The blade tip is banked downward by bank_angle from the ring plane. For the tip to stay
above the root's horizontal plane:

```
tip_elevation = 90° − θ − bank_angle ≥ 0  →  bank_angle ≤ 90° − θ
```

| Shaft elevation θ | Max safe bank |
|---|---|
| 30° (normal operation) | 60° |
| 65° (pitch depower) | **25°** |

At 65° shaft tilt, any blade banked steeper than 25° has its tip below the root horizontal
at top-of-circuit. A blade tip below horizontal at this point in the rotation means the
apparent wind hits the top face of the blade (back-wind), reversing the lift direction.
Since the tether bridling supports the blade in tension for underside loading only, back-wind
stresses the blade root and ring fitting in ways the structure is not designed for.

**Previous bound:** 35° (set as a DE search bound in V6.2 after reducing from 45° in
earlier versions). The 35° limit was adequate for normal operation but fails the pitch
depower geometric constraint by 10°.

**Choice made:** Tighten bank_angle upper bound from 35° → 25° in all DE search bounds
(V6 and V10). This is a geometric constraint derived from the pitch depower shaft angle,
not an aerodynamic or structural limit — it ensures the blade physically cannot back-wind
regardless of bridling configuration.

**Alternatives considered:** 
- Keep 35° and rely on bridling incidence to prevent back-wind: rejected because bridling
  cannot fix a geometric inversion where the tip sits below the root.
- Compute a dynamic limit from φ_inflow during gusts: deferred as the geometric constraint
  is tighter and simpler to enforce.

**Consequences:**
- Reduces the DE's F_radial per unit blade lift (shallower bank = more F_axial, less F_radial)
- May increase the optimal ring beam mass since less radial spreading → less tension stiffening
- V10 tight winner at bank_bottom=35° becomes infeasible; campaign must be re-run
- The true feasible bank angle may be even lower if bridling incidence is explicitly modeled
  (deferred to a future incidence/AoA model)

**Status:** Active. Pending code change in search_bounds_v6, search_bounds_v10,
design_from_vector_v6, design_from_vector_v10.

## [2026-06-20] V11: Tapered tether diameters — top tethers carry less load, don't need the same SWL

**Context:** Tether tension accumulates from hub to ground. In the V10 winner (76.75 kg,
n=12, FoS=3.5), the ground tethers carry ~1,000 N per line requiring 3 mm Dyneema
(SWL 3,500 N), but the hub tethers carry only ~200 N per line — they could use
1.1 mm Dyneema (SWL ~475 N).  The current model uses uniform 3 mm diameter
everywhere, over-designing the upper tethers by up to 7×.

**What was decided (V11 scope):**

1. **Single new design variable:** `tether_taper` ∈ [0.3, 1.0] — ratio of top tether
   diameter to bottom diameter.  1.0 = uniform (backward-compatible), 0.3 = top tethers
   at 30% of bottom.  Quadratic taper profile along the shaft.

2. **Per-segment FoS check replaces global tether FoS gate.**  Each inter-ring segment
   is sized for its local cumulative thrust, with its local tapered diameter.

3. **Practical minimum diameter:** D_min = 1.5 mm (not 1.1 mm theoretical).  Below
   1.5 mm, Dyneema braided lines have handling, inspection, and splicing issues, and
   the SWL ∝ D² scaling breaks down due to sheath-to-core ratio.  This limits
   tether_taper to ~0.5 and mass saving to ~2.5 kg.

4. **Expected impact:** ~3 kg mass reduction (72-74 kg vs 76.75 kg), ~1.5 kW drag
   reduction.  The n_lines trade-off shifts — tapered designs make fewer thick lines
   more competitive.

**Alternatives considered:**
- *Uniform tethers (current):* Rejected — over-designs 80% of the tether length.
- *Full per-segment diameter as separate variables:* Rejected — too many DoF.
  A single taper ratio captures the physics with minimal search space expansion.
- *No D_min, allow 1.1 mm:* Rejected — practical handling concerns and SWL
  model fidelity concerns for very small braided lines.

**Status:** Active.  Implemented in V11 campaign.  See
`docs/plans/2026-06-20-v11-tapered-tethers.md` for full scope.

---

## [2026-06-20] Dashboard verification reveals three unmodelled failure modes — constraint expansion required

**Context:** The V9.0 campaign winner (44.52 kg, n=8, n_exp=9, λ=0.40, bank=30°) passed all
`objective_v6` checks (beam buckling FoS ≥ 1.8, torsional FoS ≥ 1.5, P_gen ≥ 50 kW at
equilibrium ω, parasitic drag balanced).  But when loaded into the interactive dashboard
under steady 11 m/s wind at 30° elevation, the design failed catastrophically:

- Power: 403.7 kW (8× rated) — expansion rotors injecting ~350 kW into shaft
- Rotor ω: 85 rpm — dashboard settles to different equilibrium than campaign solver
- Tether FoS: 0.3 — tension 8.2× SWL (3,500 N), peak tension 28,653 N
- Torsional overtwist: RED ALERT — inter-ring twist exceeded π
- Slack events: 38/500 frames (7.6%) — tethers going slack in steady wind

The `objective_v6` function checks structural FoS and power balance, but does NOT model:
1. **Tether tension FoS** — tethers sized for static hub thrust; dynamic forces 8× higher
2. **Torsional overtwist** — the Tulloch limit (inter-ring twist < 0.95π); expansion rotor
   τ_net can twist the shaft beyond safe limits
3. **Slack events** — the static evaluator assumes all lines taut; 7.6% slack frames
   observed in steady wind

Additionally, `solve_equilibrium_self_consistent` uses a 30-point log scan (1–300 rpm) which
has coarse resolution at high ω (~20 rpm between points near 80 rpm), potentially missing
equilibrium crossings where expansion rotor τ_net dominates.

**What was decided:**

1. **Dashboard verification is mandatory** for every campaign winner before it is cited as
   viable.  The dashboard is the ground truth — if it shows failure, the campaign objective
   is missing a constraint.  This is the validation loop: campaign → dashboard → gap →
   constraint → re-campaign.

2. **Three new constraints will be added to `objective_v6`** before the next campaign:
   - Tether tension FoS: `T_per_line / TETHER_SWL ≥ 3.0`
   - Torsional overtwist: `max_twist < 0.95π` (cumulative per-ring twist)
   - Slack guard: `min(thrust_per_ring) > 0` (no decompressed rings)

3. **Equilibrium scan resolution** will be increased from 30 to 100 points, and the
   lifter torque term will be added to `solve_equilibrium_self_consistent` to close
   the ω mismatch between campaign solver and dashboard.

4. **The V9.0 winner (44.52 kg) is scientifically useful but not viable as-is.**  It
   represents the best design within the modelled constraint set.  With the three new
   constraints, the feasible region will shrink and the optimum mass will rise.  The mass
   trajectory — V6.5 fantasy (17.7 kg) → V6.8 corrected drag (58 kg) → V9.0 equilibrium
   (44.5 kg) → V10 full constraints (TBD) — is the arc of increasing physical fidelity.

**Alternatives considered:**
- *Accept the campaign winner and ignore dashboard failures:* Rejected.  The dashboard is
  the higher-fidelity model; if it shows failure modes the campaign missed, those modes
  are real and the objective is incomplete.
- *Abandon the campaign approach and only use full ODE evaluation:* Rejected — the ODE is
  too expensive for DE optimisation (millions of evaluations).  The correct approach is
  to add static proxies for each dynamic failure mode to the objective.
- *Blame the dashboard for the mismatch:* Rejected after investigation — the ω mismatch
  is caused by the campaign solver undersampling the equilibrium scan and ignoring lifter
  torque, not by a dashboard bug.

**Status:** Active.  The three new constraints plus scan resolution fix are the V10
campaign scope.  See `references/v9_0-dashboard-verification.md` for full evidence.

---

## [2026-06-20] Architectural unification — all rotors are expansion rotors, hub rotor special case removed

**Context:** The V6–V9 architecture treated the hub rotor (ring 1) as a distinct entity:
always present, no bank angle, blades in the rotation plane, separately sized.  N
additional expansion rotors were placed via a clustering strategy, all with identical
bank angle and blade scale.  This created two code paths for rotor force computation,
power sharing (`P_per_rotor = P_total / (1 + n_expansion)`), and structural evaluation.

The V9.0 dashboard revealed that expansion rotor τ_net can inject 350+ kW into the
shaft at high ω — the special-cased hub rotor model couldn't capture this because
it assumed the hub dominated the power balance.  Additionally, the expansion rotor
clustering strategy was arbitrary — there was no physics justification for clustered
vs distributed placement.

**What was decided:**

1. **Ring 1's rotor is just another expansion rotor.**  It can have a bank angle
   (0° = axial driving rotor, the former hub-rotor behaviour).  All rotors use
   the same force model, same power sharing, same structural contribution.

2. **Rotor placement is a 60-pattern bitmask.**  Rotors go on the top 10 rings
   (rings 1–10 from hub) with at least 2 bare rings between any two active rotors
   for wake clearance.  This gives 60 valid patterns encoded as a discrete proxy
   variable.  The optimizer chooses which rings get rotors — from 0 (no expansion)
   to 4 (max density at positions 1,4,7,10).

3. **Blade scale and bank angle become gradients.**  `λ_top` and `λ_bottom` with
   linear interpolation between them.  Same for `bank_top` and `bank_bottom`.
   This lets upper rotors carry larger blades at shallower bank (clean air,
   stronger wind, more thrust) while lower rotors use smaller blades at steeper
   bank (wake-affected, more radial spreading).

4. **Per-rotor BEM sizing with wind shear.**  Each rotor is sized for its local
   wind speed via power-law shear (`v ∝ z^0.14`).  The self-consistent equilibrium
   solve sizes all rotors at their local wind, sharing a common ω.

5. **Hub rotor term retired.**  Code references to "hub rotor," "main rotor,"
   "supplementary expansion rotors" are removed.  All rotors are co-equal.

**Alternatives considered:**
- *Keep hub rotor special case:* Rejected — the dashboard proves expansion rotors
  can dominate the power balance, making the hub-centric model physically wrong.
- *Full bitmask over all 21 rings:* Rejected — bottom-half rings see reduced wind
  (shear), are in the wake of upper rotors, and have smaller radius (less leverage
  for spreading).  10 top rings captures the viable rotor positions.
- *Per-ring binary variables (2^10 = 1024 options):* Rejected — the 2-ring gap
  constraint collapses this to 60 valid patterns, which is manageable.

**Status:** Active.  Implemented in V10 campaign (`objective_v10.jl`).  See
`docs/plans/2026-06-20-v10-full-dynamic-constraints.md` for full scope.

---

## [2026-06-20] V10 campaign implementation — bug fixes, validation gates, and bounds tightening

**Context:** The V10 campaign was launched after implementing the architectural
unification (all-rotors-are-expansion) and 8-gate constraint set.  During
implementation, four bugs were discovered that would have silently produced
physically nonsensical designs.  Additionally, the campaign runner lacked
defence against pathological islands — a single buggy design could waste
hours of compute before being caught.  These gaps were closed before launch.

**What was decided:**

### 1. Four critical bugs fixed in `objective_v10.jl`

| Bug | Root cause | Fix |
|-----|-----------|-----|
| Rotor at ground ring | Mask positions mapped 1:1 to ring indices; position 10 → ground ring (n_rings) | Clamp positions to top half (`n_rings ÷ 2`), convert position → ring index = `n_rings - p + 1` |
| λ=0.005 microscopic blades | Lower bound let optimizer functionally disable rotors (blade tip radius → 0) | Raised λ_min from 0.005 to **0.05** (5 cm minimum blade scale) |
| Duplicate `ring_spacing_v4` | Code called the spacing function twice after refactor, using stale `zs` values | Removed duplicate call; single source of truth |
| Wrong zs index for wind | `pos` started as mask position, used directly to index `zs` after it already became ring index | Use `zs[pos]` directly after position→ring conversion |

### 2. Per-island validation gates (6 checks)

Before the campaign advances to the next island, the current island's best design
is validated through a 6-gate check in `_validate_island()`:

| Gate | Check | Rationale |
|------|-------|-----------|
| 1 — Rotor count | `n_active ≥ 1` | Design must have at least one rotor |
| 2 — Mass sanity | 10 kg < mass < 300 kg | Catch pathological penalty escapes and implausible designs |
| 3 — Blade scale floor | `min(λ) ≥ 0.051` | Ensure no rotor has effectively zero blades |
| 4 — Bank diversity | Not all rotors at bank=35° | Pure spreading rotors with zero thrust are degenerate |
| 5 — Equilibrium ω | 1 < ω < 250 rpm | Designs that can't find equilibrium ("air brake") or overspeed are rejected |
| 6 — Power ratio | 0.90 < P_gen/P_rated < 1.10 | Designs must deliver power within 10% of target at equilibrium ω |

If any gate fails, the campaign **halts** with a diagnostic message and the
offending island number.  The user can fix the issue and `--resume` from that
island.  This trades campaign autonomy for compute efficiency — catching a
bug at island 2 saves ~58 islands of wasted DE iterations.

**Alternative considered:** Run all islands regardless and flag failures in a
post-mortem log.  Rejected — by the time the user sees the log, 60 islands of
compute have been wasted.  Halting immediately is the correct trade-off during
active development.

### 3. Design vector tightened from plan

The original plan specified 14-DoF with n_lines ∈ [3, 24].  Three bounds were
tightened compared to the plan:

| Parameter | Plan bound | Implemented bound | Reason |
|-----------|-----------|-------------------|--------|
| `Do_top` min | 0.01 m | **0.05 m** | 1 cm beam OD is below manufacturing floor for a 50 kW system |
| `r_bottom` min | 0.1 m | **0.5 m** | Ground ring below 0.5 m radius can't carry 3× tether attachment geometry |
| `n_lines` max | 24 | **16** | Strip theory Cp model not validated above n=12; 16 already extrapolating |

### 4. Collapse mechanism carries forward from V6

The DE search uses the same stall-detection and population-reset mechanism from
the V6 campaign: every 100 iterations, check population diversity; if collapsed,
perturb the best vector and re-randomise the rest.  This was vetted across the
V6.x–V9.x campaigns and performed reliably.

### 5. Incremental CSV checkpointing

After each island completes, four files are written (appended) with `flush()`:
`convergence_history.csv`, `island_bests.csv`, `parameter_trace.csv`, and
`verification_log.csv`.  The global best is updated atomically in
`best_design.json` + `best_vector.csv`.  This means:
- **Mid-run inspection:** `tail convergence_history.csv` shows progress
- **Crash recovery:** `--resume` reads `island_bests.csv`, skips completed islands
- **No data loss:** `flush()` ensures data hits disk even if the process is killed

**Status:** Active.  The V10 campaign is currently running (60 islands, 80 pop,
elliptical beam profile only).  First campaign launch produced a 49.1 kg winner
(n=12, 2 rotors, r_bottom=2.1 m free); a second launch with tightened bounds is
in progress.  Dashboard verification of the winner is mandatory per the
[2026-06-20] dashboard decision above.

---

## [2026-06-21] V10 v2 diagnostic campaign — fixes to search machinery confirmed correct but insufficient to shift the fitness landscape

**Context:** A dashboard investigation of the V10 winner (island 41, 76.75 kg,
1 rotor at hub) revealed it is dynamically dead: 0.0 kW, −2 rpm, 144 slack
lines, bouncing lift kite, misaligned hub ring.  The single hub rotor
concentrates all thrust at the top ring; upper tethers go slack under dynamic
load and torque cannot transmit to the generator at the ground ring.

Three fixes were applied to the V10 search machinery before a diagnostic
re-run (v2):

1. **Rotor-position clamp removed** (`design_from_vector_v10`).  The old code
   applied `max_positions = n_rings ÷ 2`, silently discarding rotor mask
   positions beyond the top half of rings.  For the V10 winner (n_rings=7,
   mask positions [1,4,7,10]), only position 1 survived — positions 4, 7, 10
   were killed.  The DE selected 4-rotor masks but the objective only evaluated
   1 rotor.  The atlas visualisation (`export_v10_atlas_data.jl`) reported
   `n_rotors = count_ones(mask)` (the raw bit count, 4) rather than the
   clamped `n_active` (1), creating a silent rotor-count mismatch between
   what the pairs plot showed and what the campaign actually optimised.

2. **Tension-distribution gate added** (`objective_v10`, gate 6b).  After the
   structural evaluation, checks `minimum(cumulative_thrust) / n_lines > 0` —
   every tether segment must carry positive tension at ω_eq.  A slack segment
   means the TRPT cannot transmit expansion-rotor torque to the ground-ring
   generator.  Rejects designs with a mass-scaled penalty + 1e6.

3. **Hub-rotor mask filter** (`_generate_valid_rotor_masks`).  41 of 60 masks
   lacked a rotor at position 1 (hub, highest wind).  These were filtered out
   by adding `(m & 1) == 0 && continue`, reducing the valid set to 19 masks,
   all with a hub rotor.  Eliminates DE search time wasted on configurations
   that place the first rotor partway down the shaft.

Additionally, the dashboard's MPPT gain slider range was widened from
`1:1:50` to `1:1:2000` after discovering that `params_v5_50kw().k_mppt ≈ 615`
was out of range — the dashboard was testing at k_mppt=50 (8% of campaign
value), explaining the "massive overpower" symptom reported during dashboard
testing.

**What the v2 diagnostic run showed:**

The v2 campaign was launched (`launch_v10_50kw_v2.sh`, 60 islands, 80 pop)
and stopped after 22 islands.  Every island converged to the same basin as
v1: **n_active=1, 76.7 kg, 41 rpm**.  The tension-distribution gate did not
trigger on single-rotor designs — `cumulative_thrust` is monotonically
positive when all thrust comes from the hub ring.  Multi-rotor masks (e.g.
[1,4], [1,5]) are now available but the DE has no incentive to select them:
a second rotor costs blade mass with no offsetting benefit in the objective.

**Why the fixes didn't change the outcome:**

The fixes addressed structural problems in the *search machinery* (clamp,
masks, gates) but did not change the *fitness landscape*.  Lower mass always
wins, a second rotor always costs mass, and the static tension gate sees
positive cumulative thrust for 1-rotor designs.  The 144 slack lines observed
in the dashboard are a *dynamic* effect from the lift-kite interaction —
tension oscillates, bridles go slack, and the static equilibrium solver
cannot model this.

**What would actually shift the DE toward multi-rotor designs:**

1. **Model the lift kite in the objective's force balance.**  The lift kite's
   tension vector changes the tether force distribution.  Without it, the
   static solver thinks tethers are fine when the ODE shows they collapse.

2. **Add a thrust-spreading incentive.**  Penalise designs where >80% of
   cumulative thrust comes from a single ring.  This would make 2-rotor
   designs at rings [7,4] competitive against 1-rotor at ring 7 alone.

3. **Replace the static tension check with a dynamic proxy.**  The
   `headless_verify_structural` (gravity-settle only) catches degenerate
   geometry but not dynamic slack.  A cheap dynamic check — perhaps a very
   short wind-driven ODE settle with lift device — could close this gap
   without the full 5-minute `headless_verify` scan.

**Status:** The three search-machinery fixes are committed and correct — they
enable multi-rotor exploration and prevent silent rotor-count mismatches.
They do not, by themselves, change the optimum.  The V10 campaign must be
re-run with at least a thrust-spreading incentive or lift-kite modelling
before a multi-rotor design can emerge.  See `docs/plans/2026-06-21-rotor-
position-clamp-tension-gate.md` for the implementation record.

---

## [2026-06-21] Ring-count mismatch — rotor on wrong ring, bridles slack, k_mppt blade-area scaling

**Context:** Dashboard testing of the V10 winner (76.75 kg, 1 rotor, bank=35°,
λ=0.234) revealed 0 kW, −2 rpm, 144 slack lines, and a bouncing lift kite.
Systematic tracing through the ODE state revealed three compounding issues.

**Issue 1 — Rotor on wrong ring.** `design_from_vector_v10` uses intermediate
ring numbering (1..n_rings from `ring_spacing_v4`). `build_kite_turbine_system`
adds ground (ring 1) and hub (ring n_rings+2) rings, creating a +2 offset.
A rotor meant for the hub (mask position 1 → intermediate ring n_rings) was
placed at system ring n_rings (an intermediate ring at r=5.26m) instead of
ring n_rings+2 (the actual hub at r=3.70m).  Rotor thrust and bridle
connections were on different rings — 12/13 bridles slack, tension chain
broken.  **Fix:** Remap ring indices in `build_from_campaign_v10` and
`_build_verify_system`: intermediate ring i → system ring i+1, and the
hub-proxy ring (intermediate ring n_rings) → system ring n_rings+2.

**Issue 2 — Blade scale λ exploited as mass cheat.** The DE converged to
λ=0.234 because blade mass ∝ λ³. The static equilibrium solver found ω_eq
at k_mppt=615 regardless of λ — tiny blades were "compensated" with higher
ω in the solver, but the ODE showed the rotor lacks startup torque to reach
that ω.  At λ=0.234 (tip=2.7m): stalls at 10 rpm, 0.6 kW.  At λ=1.0
(tip=11.5m): spins to 35 rpm, 31 kW.  **Fix:** Scale k_mppt by λ² inside
the equilibrium solver (`k_mppt_eff = p.k_mppt × λ²`).  A λ=0.5 rotor has
¼ the swept area of λ=1.0 and should expect ¼ the power.  The scaled
k_mppt is passed to `solve_equilibrium_self_consistent` so ω_eq is found
for the correctly-sized generator load.  Applied in both `objective_v10`
and `build_from_campaign_v10` for dashboard consistency.

**Issue 3 — Lift kite tension adequate but structural tension degrades.**
After fixes 1 and 2, all 12 bridles are taut (139-161N).  The lift kite
provides 1.53 kN vs 0.75 kN system weight — healthy 2× margin.  Initial
slack drops from 36% to 5%.  After 2s simulation: 19% slack, 2.3 rpm,
0 kW — tension still degrades dynamically.  Force balance at hub shows
bridle axial force (1.53 kN) slightly exceeds rotor thrust (1.36 kN) plus
axial weight (0.38 kN) by 0.21 kN — the lift kite is marginally too weak
to maintain axial preload under dynamic conditions.  Not yet resolved;
the rotary lifter radius/elevation factor may need tuning, or a second
rotor to increase total thrust.

**Status:** Issues 1 and 2 are fixed and committed (commits 71ea694 and
1c86b69).  Issue 3 (dynamic tension degradation) remains open.

The tight-bounded campaign with k_mppt scaling (`launch_v10_tight.sh`,
commit 04f2d18 with widened validation gates) found a fundamentally
different basin: **49.20 kg, 4 rotors, λ=0.519, r_hub=2.89m, ω=59 rpm**
— a 36% mass reduction from the V10v1 76.75 kg baseline.  The k_mppt
λ² scaling prevented the DE from converging to λ→0; the ring-mapping
fix placed rotors on the correct hub ring; the hub-rotor mask filter
reduced the search space from 60 to 19 masks.

However, post-campaign dynamic verification (`headless_verify` k_mppt
scan) shows the design is still dynamically dead: 12.1 kW at 55.6 rpm
(24% rated) vs the static solver's prediction of 50 kW at 59 rpm.  The
static-vs-dynamic power gap persists — the equilibrium solver and the
multibody ODE disagree on the operating point even with the k_mppt
scaling fix.  Five parameters are screaming at bounds (Do_top, t_over_D,
r_bottom, target_Lr, λ_bottom), indicating the true optimum lies outside
the current tight envelope.

Full analysis: `docs/reports/v10-tight-analysis.md`.
Landscape diagram: `docs/awes-forum-diagrams/v10-tight-landscape.png`.

---

## [2026-05-23] Banishment of Furl, Transition to Pitch Depower, and Terminological Preservation of Furl

**Context:** During wind-spilling winching scenarios in *KiteTurbineDynamics.jl*, the simulator previously used the term "Furl" to refer to the process of winching out the backline to raise the turbine rotor and spill the wind. This terminology created significant confusion with "Lift Kite Furling" (the aerodynamic modulation of the top lift device to prevent structural overload in high winds). 

Furthermore, high-fidelity dynamic simulations of this scenario identified a critical failure mode: if the backline is paid out without active tension constraints on the top lift device, the sky anchor and bearing sag under gravity and wind, causing the gold bridles to go completely slack (Tension = 0.0 N). This structurally decouples the ground generator from the airborne rotor, rendering active drivetrain damping and $k_{\text{MPPT}}$ stall governance completely useless, and triggering severe, unphysical 100 rad/s intermediate ring whipping and torsional collapse.

**What was decided:**
- **Banishment of "Furl" for Shaft Operations:** The term "Furl" is completely retired from all user-facing GUI, status messages, simulation parameters, and test campaigns. It is replaced by **"Pitch Depower"** (or **"Turbine Rotor Pitch Depower"** in full).
- **Physical Concept & Terminological Separation:** 
  1. *Pitch Depower:* Raising the generating rotor (at the top of the TRPT) by paying out the backline to tilt its axis of rotation closer to vertical, reducing its apparent wind annulus area and spilling wind.
  2. *Furl:* Strictly reserved for future work on the lift kite's own aerodynamic lift modulation/reduction under extreme wind loads to protect the sky anchor from overload.
- **The Lifter High-Tension Constraint:** The top lifting rotor kite must maintain **full operational lift force and tension** (high-tension pull, similar to and at least as much as under normal operating conditions, i.e., $T_{\text{lift}} \ge 1000\text{ N}$) throughout the entire Pitch Depower operation. This ensures that the TRPT column remains preloaded and taut, the gold bridles never go slack, and the ground-winch + MPPT stall braking controls can safely and smoothly stall the generating rotor.
- **Drivetrain Active Damping Preservation:** Ground damping is preserved during pitch depower and is physically valid because the high-tension pull of the lifter kite keeps the bridles and tethers taut ($GJ \gg 0$).
- **UI HUD Default Open:** The "Lift Device" HUD telemetry section is set to start open by default to display the lifting line tension $T_{\text{lift}}$ in real time, so that the high-tension pull constraint is immediately visible and easily monitored.

**Alternatives Considered:**
- *Letting the lift kite depower at the same time:* Checked in simulation, but this causes complete loss of tether tension, leading to bridle slackness, dynamic uncoupling of the PTO, and immediate torsional collapse.
- *Keeping "Furl" as the general term:* Ruled out due to the clear physical distinction between spilling wind on the generating rotor (Pitch Depower) and spilling wind on the lifting device (Furl).

**Status:** Active.

---

## [2026-05-22] Phase N — Full 6-DOF Inertia Relief & Moment Equilibration in Space-Frame Ring FEA Solver

**Context:** During dynamic simulations (e.g., startup, wind changes, or furl/slack scenarios), the intermediate spacer rings of the airborne kite turbine undergo acceleration due to unbalanced forces (such as gravity, aerodynamic wind drag, and cyclic tether tension). Because the space-frame finite element method (FEA) solver in `src/ring_element_analysis.jl` is static, it solves a stiffness equation $K d = F$. To handle rigid-body modes (since the free-floating ring is not physically anchored to the ground), a soft Tikhonov ground spring regularisation ($\varepsilon$) is added to the diagonal of $K$.

Previously, when the net applied force vector $\vec{F}_{\text{net}} \neq \vec{0}$, these soft ground springs reacted to the net force, leading to huge fictitious rigid-body translations ($d \approx 10^6 \text{ m}$ to $10^8 \text{ m}$). We initially resolved this using a 3-DOF translational inertia relief. However, even with balanced forces, the intermediate rings experienced unbalanced out-of-plane rotational (pitch/yaw) moments ($M_x, M_y$) and in-plane torsional moments ($M_z$) due to dynamic, asymmetric tether loading. The soft regularisation springs ($\varepsilon$) reacted to these unbalanced moments by generating massive fictitious rigid-body rotations (e.g., $10^4$ to $10^6$ radians). Floating-point precision loss (limited to 16 decimal digits for `Float64`) completely corrupted the local coordinate transformations and local displacement recovery ($d_{\text{elem}} = T d$). This numerical noise leaked in-plane forces into colossal, artificial out-of-plane bending moments ($M_{\text{oop}} \approx 400 - 700\text{ N}\cdot\text{m}$ vs elastic capacity $54.7\text{ N}\cdot\text{m}$), causing all struts to turn bright red in the dashboard (max utilisation $>9000\%$, FoS = 0.0) even in benign operating points.

**What was decided:**
- **Full 6-DOF Inertia Relief Formulation:** Apply D'Alembert's Principle to perfectly equilibrate both the translational forces and the rotational/torsional moments of the system before passing it to the static FEA solver. Since the ring is a flat, symmetric polygon in the local ring frame, its mass is distributed symmetrically among $n$ identical knuckles of radius $R$ at local coordinates $(x_j, y_j)$. We formulate the angular D'Alembert inertial reaction force corrections as follows:
  1. *Translational Inertia Relief (3 DOFs):*
     $$\Delta \vec{F}_{\text{global}, j} = -\frac{\vec{F}_{\text{net}}}{n}$$
     This perfectly zeroes the net global force: $\sum_{j=1}^n \vec{F}_{\text{global}, j} = \vec{0}$.
  2. *Torsional Inertia Relief (1 DOF - in-plane rotation about local z-axis):*
     Given the net torsional moment $M_z = \sum_{j=1}^n (x_j F_{y,j} - y_j F_{x,j})$, the D'Alembert reaction forces at each vertex must oppose $M_z$ proportionally to their radial distance. For a flat ring of radius $R$, the corrective forces are tangential:
     $$\Delta F_{x, j} = + \frac{M_z y_j}{n R^2}, \quad \Delta F_{y, j} = - \frac{M_z x_j}{n R^2}$$
     This cancels the net torque perfectly: $\sum (x_j \Delta F_{y,j} - y_j \Delta F_{x,j}) = -M_z$.
  3. *Rotational Inertia Relief (2 DOFs - out-of-plane pitch/yaw about local x and y axes):*
     Given net out-of-plane moments $M_x = \sum y_j F_{z,j}$ and $M_y = \sum -x_j F_{z,j}$, the out-of-plane D'Alembert reaction forces at each vertex oppose these moments:
     $$\Delta F_{z, j} = - \frac{2}{n R^2} (M_x y_j - M_y x_j)$$
     This cancels out-of-plane moments perfectly: $\sum y_j \Delta F_{z,j} = -M_x$ and $\sum -x_j \Delta F_{z,j} = -M_y$.
- **Algorithm:** In `analyse_ring`, we compute $M_x, M_y, M_z$ in local coordinates and subtract/add the respective corrective forces. This mathematically guarantees that all net forces and moments in the local frame are zeroed to machine precision ($<10^{-13}$), removing all fictitious translations and rotations.
- **Alternatives Considered:**
  - *Pinning arbitrary nodes/DOFs:* Introducing fixed/pinned nodes violates the free-floating boundary conditions, introducing artificial reaction forces and asymmetric stresses that corrupt the physical load distribution.
  - *Increasing the regularisation parameter $\varepsilon$:* Increasing $\varepsilon$ suppresses fictitious motions but acts as a stiff artificial ground spring, which constrains ring deformation and artificially inflates local beam forces.

**Results, Rationale & Physical Design Limits:**
- **Numerical Zeroing:** All fictitious rigid-body motions are eliminated, reducing translational displacements to $\approx 10^{-15}\text{ m}$ and rotations to $\approx 10^{-16}\text{ rad}$. Floating-point precision is fully preserved.
- **Visual Accuracy:** The spacer struts in the interactive dashboard now accurately show realistic, physical, and highly differentiated colors corresponding to actual structural bending and compression, rather than a uniform red warning.
- **Real physical torque waves:** The simulation now clearly reveals physical torsional propagation waves running up and down the TRPT shaft, validating the dynamic multibody line tension coupling.
- **Physical Design Limit at $t = 1.26\text{ s}$:** With the numerical artifacts eliminated, we observe that at $t = 1.26\text{ s}$ (during peak transient power transmission of $8.21\text{ kW}$ and a TRPT twist of $181.1^\circ$), the worst-beam strut utilization reaches **$302.8\%$** (FoS $\approx 0.33$). 
  - *Spacer Rings (Rings 1 to 13):* Remain perfectly safe, with utilization ratios between $0.6\%$ and $1.5\%$, proving the spacer ring sizing is structurally sound.
  - *Ground-end Ring (Ring 14):* The high utilization of $302.8\%$ occurs on the ground-end ring which directly reacts the PTO torque and shear. This is **physically real**, indicating that the ground-end ring structure under peak transient dynamic torque waves is under-designed. A wider ring radius or larger tube diameter is physically required at the ground end to handle peak dynamic torque transients.

**Status:** Active.

---

## [2026-04-30] Phase K — v5 campaign results: BEM-coupled rotor radius closes the n_lines loop

**Context:** The v4 campaign found n_lines = 8 at the upper search bound in all 60 islands and
the audit (entry below) established this was an artefact: more lines always improved Euler
buckling resistance at zero aerodynamic cost because rotor radius R was a fixed input from
`SystemParams` with no Cp(n_lines) coupling. v5 closes the loop by deriving R
self-consistently from n_lines via a BEM Cp model, so Cp degradation from over-solidity
translates into a larger R, higher thrust, and higher shaft mass.

**What was decided (v5 formulation):**

- Rotor radius R is no longer a fixed input. It is derived per candidate design: given n_lines,
  chord geometry, and a BEM Cp(σ, TSR) surface, compute the σ that maximises Cp, find Cp_max,
  then back-calculate R from `P_rated = 0.5ρv³πR²Cp_max·η`.
- BEM Cp surface fitted from a sweep over n_lines ∈ {3…12}, TSR ∈ {3…10}, solidity
  σ = n_lines × chord_eff / (2π × R). Stored in `src/bem_cp_model.jl`.
- All other physics unchanged from v4 (Euler FOS ≥ 1.8, Torsional FOS ≥ 1.5, L/r spacing, DLF).
- n_lines upper bound kept at 8: strip theory is not validated above n = 6; raising the bound
  pending CFD/panel-method confirmation.

**Results — 10 kW winner:**

| Parameter           | Value                               |
|---------------------|-------------------------------------|
| Mass                | **11.470 kg** (+8.3 % vs v4)        |
| n_lines             | 8 (unanimous across all 60 islands) |
| Beam profile        | Circular                            |
| r_hub               | 1.600 m                             |
| r_bottom            | 0.340 m                             |
| target_Lr           | 2.0                                 |
| Cp (BEM-derived)    | 0.453                               |
| R (self-consistent) | 5.12 m (vs fixed 5.0 m in v4)       |

**Campaign summary across all runs (10 kW):**

| Campaign | Constraint set                          | Best mass    | Δ vs v3   |
|----------|-----------------------------------------|--------------|-----------|
| v2       | Beam buckling only                      | 2.808 kg     | — (torsionally infeasible) |
| v3       | Beam + torsion (cylindrical forced)     | 15.435 kg    | baseline  |
| v4       | Beam + torsion (taper free, fixed R)    | 10.587 kg    | −31.4 %   |
| **v5**   | **Beam + torsion (taper free, BEM R)**  | **11.470 kg**| **−25.7 %** |

**n_lines = 8 is robust under BEM coupling.** The Cp penalty at n_lines = 8 solidity
(σ ≈ 0.18 for the winner geometry) relative to n_lines = 5 canonical (σ ≈ 0.11) is
approximately 3–4 %, translating to ~2 % larger R, ~3 % higher thrust, ~2 % higher shaft mass.
The structural benefit of 8 vs 5 lines (shorter polygon segment → lighter beams) outweighs
the aerodynamic penalty. n_lines = 8 is the unanimous choice across all 120 islands
(60 v4 + 60 v5), across both 10 kW and 50 kW configurations.

**Strip theory validity flag:** BEM strip theory is well-validated for n_lines ≤ 6. At
n_lines = 8, blade-to-blade interaction (wake interference, solidity effects, potential-flow
blockage) is not captured. Cp values at n_lines = 8 are provisional. CFD or panel-method
validation is required before adopting n_lines = 8 for hardware.

**Figures generated (committed to master):**

- `figures/report/fig_trpt_system.png`, `fig_elevation_angle_trade.png`,
  `fig_structural_efficiency_profile.png`, `fig_tulloch_wacker_chart.png`,
  `fig_cp_contour.png`, `fig_nlines_mass_curve.png`, `fig_campaign_geometry_evolution.png`,
  `fig_campaign_progression.png`, `fig_design_space.png`, `fig_fos_landscape.png`
- `figures/fig_k_beam_profile_mass.png`, `fig_k_nlines_v4_v5.png`,
  `fig_k_Lr_sensitivity.png`, `fig_k_taper_vs_mass.png`, `fig_k_torsional_binding.png`,
  `fig_k_v4_v5_mass_comparison.png`

**In progress:** `TRPT_AWE_Forum_Report_v3.docx` — builds on v4 and v5 results for external
presentation.

**Open questions for v6:**
1. CFD/panel-method validation of n_lines = 8 Cp (strip theory not validated at n > 6).
2. Joint β + structural optimisation: β fixed at 30° throughout v2–v5; cold-start and
   lift-kite analysis suggest optimum near β ≈ 26°. v6 should free β alongside the
   structural parameters.
3. Dynamic torsional loading and fatigue: all campaigns size against a static peak envelope.
   Cyclic tether tension (1P, 2P rotor harmonics) and fatigue life are not modelled.

**Status:** Active. v5 (11.470 kg) is the current best physically-consistent TRPT shaft
design. The +8.3 % mass penalty vs v4 is the cost of aerodynamic self-consistency.

---

## [2026-04-25] Phase J — v4 campaign results: taper recovery yields 31 % mass reduction vs v3

**Context:** The v3 campaign (Phase I) established the first torsionally-constrained minimum-mass
TRPT shaft design. It identified 15.435 kg as the 10 kW optimum, but that campaign forced a
cylindrical shaft profile (`taper_ratio = 1.0`) to isolate the torsional constraint as the new
physics. The v4 formulation restored taper freedom and replaced the five-parameter axial profile
family with a single `target_Lr` variable that enforces a constant L/r ratio across all shaft
segments via a geometric-series ring spacing.

**What was decided (campaign setup):**

- **Formulation:** 9 design variables per island — `Do_top`, `t_over_D`, `beam_aspect`,
  `Do_scale_exp` (taper), `r_hub`, `r_bottom`, `target_Lr`, `knuckle_mass_kg`, `n_lines`.
  Ring count `n_rings` is derived, not free.  `target_Lr ∈ [0.4, 2.0]`.
- **Beam profiles:** Circular, Elliptical, Airfoil (3 families).
- **Power configs:** 10 kW and 50 kW (2 configs).
- **Islands:** 60 = 3 beams × 5 Lr initialisation zones × 2 seeds × 2 power configs.
- **Optimiser:** Differential Evolution, F = 0.7, CR = 0.9, pop = 64, stall restart at 1 500
  generations; 168 h total budget ≈ 2.8 h per island.
- **Constraints:** beam buckling FOS ≥ 1.8 (hard); torsional collapse FOS ≥ 1.5 (hard).
- **Objective:** minimise TRPT shaft mass (kg) subject to both constraints being feasible.

**Results — 10 kW winner:**

| Parameter          | Value                |
|--------------------|----------------------|
| Mass               | **10.587 kg**        |
| Beam profile       | Circular (or Elliptical — identical mass) |
| r_hub              | 1.600 m              |
| r_bottom           | 0.336 m              |
| Tether length      | 30.0 m               |
| target_Lr          | 2.0                  |
| n_rings (derived)  | ≈ 19                 |
| n_lines            | 8                    |
| Do_top             | 0.039 m              |
| Do_scale_exp       | 0.49 (tapered)       |
| t_over_D           | 0.02                 |
| Beam FOS           | 1.80 (at constraint) |

**Results — 50 kW:**

- Circular/Elliptical: 79.51 kg (beam FOS = 1.80, feasible)
- Airfoil: 749.50 kg (airfoil profile penalty large at 50 kW scale)

**Comparison vs previous campaigns (10 kW):**

| Campaign | Constraint set          | Best mass | Notes                              |
|----------|-------------------------|-----------|------------------------------------|
| v2       | Beam buckling only      | 2.808 kg  | Torsionally infeasible — invalid   |
| v3       | Beam + torsion (cylindrical) | 15.435 kg | Taper forced to 1.0            |
| **v4**   | **Beam + torsion (taper free)** | **10.587 kg** | **−31.4 % vs v3**    |

**Key finding — taper restoration:**

Restoring taper freedom (freeing `Do_scale_exp` from its v3-implicit cylindrical value)
reduces optimum mass from 15.435 kg to 10.587 kg — a 31.4 % saving under identical
torsional and beam constraints.  The winning `Do_scale_exp` = 0.49 gives a shaft that tapers
smoothly from hub (Do = 39 mm, r = 1.6 m) to a narrow ground ring (r = 0.34 m); the beam
tubes at the ground end are proportionally thinner, saving steel where the torsional load is
lowest.

The v4 mass (10.587 kg) is still 3.8× heavier than the v2 taper-and-beam-only result
(2.808 kg), confirming that torsional constraint adds real mass, not just formulation cost.
Taper does not "undo" the torsional penalty; it recovers the mass that the forced-cylindrical
assumption artificially added to v3.

**Convergence robustness:** All 20 islands in the 10 kW circular + elliptical groups
converged to the same design parameters (mass = 10.587 kg, target_Lr = 2.0) regardless of
initial Lr zone or seed, confirming the DE found a single global minimum.  The 10 kW airfoil
group converged to a distinct, heavier solution (70.78 kg), confirming that airfoil beam
profiles are structurally inferior at this scale.

**Figures generated:**
- `figures/fig_v4_pareto.png` — mass by group (all 60 islands), log-scale
- `figures/fig_v2_v3_v4_comparison.png` — mass and FOS comparison across campaigns
- `figures/fig_v4_geometry.png` — side-elevation of the winning shaft (≈19 rings, 30 m tether)
- `figures/fig_v4_island_heatmap.png` — 60-cell mass heatmap

**Alternatives considered:**
- Continue v3 search with cylindrical assumption and more compute time — ruled out; cylindrical
  is demonstrably sub-optimal and the 31 % gap is physically justified, not a search artefact.
- Run v4 with 50 kW as the primary target — done in parallel; 50 kW winner is 79.5 kg
  (circular), forming the design-space anchor for future 50 kW structural work.

**Status:** Superseded as the current reference by v5 (11.470 kg with BEM-coupled R). v4 remains
the structural lower bound — the minimum mass achievable if Cp is truly independent of n_lines.
Future work should validate the winning geometry against a higher-fidelity structural model.

---

## [2026-04-25] n_lines Cp independence assumption in v4 (resolved in v5)

**Context:** The v4 campaign found n_lines = 8 (the upper bound) in both 10 kW and 50 kW
winners. Power (10 kW / 50 kW) entered v4 only via a fixed `r_rotor` in `SystemParams`. There
was no Cp(n_lines), Cp(TSR), or Cp(solidity) term in the v4 objective. CT = 1.0 was a fixed
conservative BEM ceiling. More lines was always structurally better (shorter polygon segments →
higher Euler resistance), with zero aerodynamic cost — so the optimiser saturated n_lines at
the upper bound as an artefact, not as a physically validated aerodynamic optimum.

**Decision:** Accept v4 as the minimum-mass shaft design conditional on Cp being independent of
n_lines. Flag v4 as structurally valid, aerodynamically unverified.

**Resolution (v5, 2026-04-30):** v5 implements BEM-coupled rotor radius. n_lines = 8 still
wins unanimously across all 120 islands, confirming the structural benefit outweighs the Cp
penalty at this solidity. The n_lines = 8 preference is robust within the BEM strip model but
not validated at n > 6 by higher-fidelity methods (see v5 entry above).

**Status:** Resolved for the BEM-strip model. CFD/panel-method validation pending for n_lines = 8.

---

## [2026-04-22] Ground ring deployment constraint: maximum radius 1.5 m

**Context:** The ground ring of the TRPT shaft is the lowest ring — closest to the ground
station, anchored and connected to the drive train. Its radius sets the physical footprint of
the ground structure (rotor anchor frame, bearing housing, guide ropes). In the v2 optimiser,
`taper_ratio` was bounded below (taper_ratio ≥ 0.15, or 0.5/r_hub for small systems) to
prevent geometrically degenerate designs. The v4 formulation replaces `taper_ratio` with
`r_bottom` as an explicit design variable. Without an upper bound on `r_bottom`, the optimiser
could select a ground ring radius approaching the hub radius (nearly cylindrical) — maximising
structural efficiency but requiring a large, difficult-to-transport ground anchor structure.

**Choice made:** `max_ground_radius = 1.5 m` as the hard upper bound on `r_bottom`. Designs
with `r_bottom > 1.5 m` are returned as infeasible by `evaluate_design`. The parameter is
configurable — `search_bounds_v4` and `evaluate_design` both accept a
`max_ground_radius` keyword argument with default 1.5 m. The lower bound on `r_bottom` is
0.3 m (minimum structural ring capable of carrying rope attachment geometry without the beam
centroid overlapping the rope).

**Alternatives considered:** Deriving the ground ring constraint dynamically from the ground
station footprint model. This would require the ground station geometry as a system parameter
— accurate but coupled. A simpler alternative of using `taper_ratio` bounds as before (≥ 0.15
of r_hub ≈ 0.3 m for 10 kW) would work for a single power class but doesn't scale correctly
when r_hub changes with power rating.

**Why this choice:** 1.5 m ground ring radius fits within a standard flatbed trailer width
(2.4 m) with margin for structural frame and anchoring — a practical deployment constraint
for the 10 kW field trials. A 50 kW system would require revisiting this bound (r_hub ≈ 4–5 m
suggests r_bottom up to 2.0–2.5 m may be acceptable). Making it a keyword argument means it
can be changed per power class without changing the function signature.

**Consequences:** The v4 optimiser will not discover designs with ground ring radius above
1.5 m. If future site access improvements allow larger ground structures (e.g., permanent
offshore installation), the bound should be raised. The lower bound 0.3 m guards against
structurally nonsensical designs; raising it risks missing valid extreme-taper configurations.

**Status:** Active.

---

## [2026-04-22] v4 ring spacing: variable positions targeting constant L/r per segment

**Context:** In v2 and v3, polygon spacer rings are placed at uniform axial intervals along
the 30 m tether, with ring radii interpolated along one of five profile families (linear,
elliptic, parabolic, trumpet, straight-taper). The torsional collapse analysis showed that
uniform spacing with a tapered geometry creates severely non-uniform L/r ratios per segment:
thin bottom segments (small r) get the same axial spacing L as wide top segments (large r),
giving them a much higher L/r ratio. This drives two problems simultaneously:
(a) thin bottom segments are in the Euler buckling danger zone (P_crit ∝ 1/L²), and
(b) the optimiser is forced toward taper_ratio → 1.0 (cylindrical) because any taper with
uniform spacing makes the bottom segments structurally expensive and the optimiser eliminates
taper to equalise the segment lengths.

**What was decided:** v4 replaces the (n_rings, taper_ratio, axial_profile) triplet with two
design variables: `r_bottom` (ground ring radius, bounded) and `target_Lr` (target L/r ratio,
common to all segments). Ring positions are no longer inputs to the optimiser — they are
computed from the constant-L/r constraint via `ring_spacing_v4()`. The number of rings n_rings
is an output: determined by the geometry, not the optimizer.

**Physics:** For a linear taper from r_top to r_bottom, constant L/r implies radii form a
geometric series. The key relationships:
- Segment axial length: L_i = target_Lr × r_mid_i (shorter near ground, longer near hub)
- Ring radii ratio: r_{i+1}/r_i = k, where k = (2 - α×target_Lr)/(2 + α×target_Lr),
  and α = (r_top - r_bottom)/tether_length is the taper slope
- Euler buckling capacity: P_crit ∝ I/L² ∝ r² (for Do ∝ r^0.5 scaling) / L²
  → with L = c×r: P_crit ∝ r²/(c×r)² = 1/c² = constant across all rings ✓
- Compression load N_comp ∝ T_line ≈ constant (dominated by axial thrust / n_lines)
- Result: FoS ≈ constant across all rings → no wasted structural margin anywhere

Mass scales as ∝ D² × L ∝ r × L = r × target_Lr × r = target_Lr × r². Bottom rings are
lighter (smaller r) AND have shorter span — doubly efficient. Drag loss scales as ∝ D × L ∝ r
× target_Lr × r = target_Lr × r² (same scaling as mass — consistent trade-off).

**Alternatives considered:** Uniform spacing (v2/v3) — proven above to be wasteful for tapered
designs. Manually specified ring positions — maximum flexibility but too many variables for a
DE search and no physical structure. Geometric-series spacing with n_rings as integer input
(rather than target_Lr as continuous input) — preserves the physics but loses the natural
parametrisation and creates discontinuities when n_rings rounds.

**Why this choice:** target_Lr is a smooth, physically meaningful continuous parameter (the
slenderness ratio is a canonical beam design parameter). The optimizer can gradient-follow it
continuously while n_rings adjusts discretely in the background. This is more natural than
optimising n_rings directly. The constant-L/r constraint is also the correct structural analogy
to "keep all segments at the same point on the Euler buckling curve" — a classical optimal
design principle.

**Consequences:** The v4 formulation removes the axial profile family variables
(axial_profile, profile_exp, straight_frac) — they become redundant since ring positions are
fully determined by (r_bottom, target_Lr, r_hub, tether_length). The dimensionality drops from
12 DoF (v2) to 9 DoF (v4). Results are NOT directly comparable with v2/v3 campaign winners
without re-running both; the v4 formulation searches a different manifold of the design space.
The v4 campaign should be run after v3 to compare minimum-mass winners at the same FoS
threshold.

**Status:** Active.

---

## [2026-04-20] Taper ratio and n_rings lower bounds in DE search space

**Context:** The 12-DoF search space for the Phase C optimisation needed lower bounds on
`taper_ratio` (r_bottom / r_top) and `n_rings` (number of intermediate polygon frames). A
taper ratio near zero would produce a TRPT that tapers to a point at the ground end — geometrically
degenerate and physically implausible. Too few rings and the inter-ring segment length grows
long, increasing the segment Euler buckling load dramatically for a given beam size.

**Choice made:** `taper_ratio` lower bound set at 0.15 (the bottom ring radius is at least
15% of the top ring radius). `n_rings` lower bound set at 3 (minimum of 3 intermediate rings,
giving 4 inter-ring segments over the 30 m tether length — segment length ≤ 7.5 m).

**Alternatives considered:** Lower `taper_ratio` bound of 0.05 (nearly a point) was considered
to let the optimiser fully explore the extreme taper space. Lower `n_rings` bound of 1 was
considered to allow very sparse configurations.

**Why this choice:** A taper ratio below ~0.2 produces a bottom ring so small that attachment-
point geometry is dominated by rope sag rather than ring radius, making the structural model
increasingly inaccurate. Below 0.15 the ring is smaller than the rope diameter at minimum SWL,
which is physically nonsensical. For n_rings, fewer than 3 intermediate rings means inter-ring
spacing exceeds 6 m; at this segment length and the design tether tensions, even large-diameter
beams are near the buckling threshold. The optimiser would waste evaluations on degenerate
geometries. These bounds are engineering-informed guards, not arbitrary.

**Consequences:** Regions of parameter space below these bounds are not explored. If a
genuinely optimal design existed below taper_ratio = 0.15 (extremely unlikely given the
buckling physics), it would be missed. The 60-island campaign found all global minima well
above these bounds (taper_ratio ≈ 0.25 for straight-taper winners), confirming the bounds
do not constrain the real optimum.

**Status:** Active.

---

## [2026-04-20] DLF (Design Load Factor) calibrated at 1.2; emergency brake excluded

**Context:** The structural fitness function needs to convert tether line tension into an
effective inward radial force per pentagon vertex — the input to the Euler buckling FoS
calculation. Under perfectly uniform loading and zero twist, the net radial force per vertex
is zero (tension components from above and below cancel). In practice, taper non-uniformity,
torque-induced helix inclination, and gust asymmetry all create a non-zero inward force. A
lumped Design Load Factor (DLF) captures this: F_in_per_vertex = DLF × T_line.

DLF was calibrated from `scripts/calibrate_dlf.jl` by running the canonical 10 kW ODE through
six load scenarios and extracting the peak per-ring inward-force envelope:
- Steady 11 m/s (rated): 0.83
- Steady 15 m/s: 0.56
- Steady 20 m/s: 0.40
- Steady 25 m/s (peak design wind): 0.32
- Coherent gust 11→25 m/s: 0.74
- Emergency brake (k_mppt stepped to 3×): 1.39

The emergency brake produces the highest DLF (1.39) by a large margin.

**Choice made:** DLF = 1.2. The emergency brake scenario is excluded from the sizing
envelope.

**Alternatives considered:** DLF = 1.39 (include emergency brake as a sizing case).
DLF = 0.85 (size against rated + small margin only).

**Why this choice:** The emergency brake at 3× k_mppt is an operationally-avoided fault.
The live system shutdown sequence is: (1) ease MPPT load through a controlled ramp, never
a step; (2) haul on back-anchor tether to yaw shaft off-axis; (3) rotor stalls
aerodynamically before mechanical braking is applied; (4) haul stalled rotor down on lifter
line. No step change in k_mppt ever hits the airframe in normal operation. Sizing to a fault
that is operationally mitigated would penalise the design weight significantly (DLF 1.39 vs
1.2 is a ~16% increase in required second moment of area). DLF = 1.2 provides ~60% margin
over the worst aero-only steady case (0.83 at rated) and ~60% margin over the coherent gust
transient (0.74), while covering manufacturing tolerance and Class A turbulence.

**Consequences:** The structural sizing is contingent on the shutdown procedure being followed.
If the shutdown sequence is violated (e.g., sudden electrical disconnect causing step braking),
the structure is under-designed for that event. This is an operational constraint, not a design
safety margin. If the shutdown procedure ever changes to allow step braking, DLF must be
recalibrated.

**Status:** Active. DLF recalibrated once already (Phase B); will need revisiting when 50 kW
system load cases are calibrated independently.

---

## [2026-04-20] Torsional collapse not in optimiser fitness function

**Context:** The TRPT structural fitness function (`evaluate_design()` in
`src/trpt_optimization.jl`) evaluates Euler column buckling FoS of each polygon segment and
checks beam manufacturability bounds. It does not evaluate whether the shaft can transmit the
design torque without torsionally collapsing. Torsional collapse is the characteristic failure
mode of a TRPT shaft: when the applied twist angle per unit length exceeds the geometric limit
set by the helical line winding angle and ring radius, the lines go slack and the shaft loses
its torque-transmitting ability.

Tulloch (PhD thesis, TU Delft) and Wacker (unpublished analysis, Windswept internal) derived
the torsional collapse criterion for TRPT-style tensile shafts. The criterion sets a minimum
on (ring radius × number of turns) relative to (shaft torque ÷ tether tension). This is a
geometric stability limit, distinct from material failure.

**Choice made:** Torsional collapse constraint not implemented in the Phase B or Phase C–H
optimiser. The optimiser sizes for Euler buckling only.

**Alternatives considered:** Implement the Tulloch/Wacker criterion as an additional Boolean
feasibility constraint in `evaluate_design()`, returning infeasible for any design that cannot
transmit the rated torque without collapsing. This is the correct long-term approach.

**Why this choice (at the time):** The Tulloch/Wacker criterion requires knowledge of the
operating torque and tether tension at rated conditions, which depend on the rotor radius and
the aerodynamic model — inputs that are fixed for a given power class (10 kW or 50 kW) but
which interact with the geometric design variables in a non-trivial way. Implementing the
constraint correctly requires either (a) computing the torsional limit analytically from the
design geometry and rated operating point, or (b) running the multi-body ODE for each
candidate design (computationally prohibitive at 192 million evaluations per island). The
correct approach is (a), but it requires deriving the closed-form torsional stability limit
for a tapered, variable-radius TRPT shaft — not a trivial extension of Tulloch's constant-
radius derivation. Deferring this allows the Euler-only sizing to complete while the torsional
derivation is developed separately.

**Consequences:** Designs that pass the Euler FoS check may still be torsionally fragile.
In particular, designs with small ring radius, few lines, or very long inter-ring spacing
may be well under the torsional stability limit at rated torque. The optimiser cannot detect
this. Any winning design from the Phase C–H campaign should be independently checked against
the Tulloch/Wacker criterion before being treated as a final design.

**Status:** Resolved (2026-04-22). The torsional collapse constraint was implemented as a hard
feasibility gate in v3 (see the v4/v5 campaign entries above). All campaigns from v3 onwards
enforce Torsional FOS ≥ 1.5 alongside Euler buckling FOS ≥ 1.8. This entry is retained for
historical context — it describes the gap as it existed during Phase C–H (v2).

---

## [2026-04-09] Hub elevation angle β freed as a dynamic degree of freedom

**Context:** The original model fixed the hub position such that the shaft always pointed at
the design elevation angle β = 30°. This was implemented by reading `p.elevation_angle`
as a fixed parameter in `rope_forces.jl` and suppressing hub translational velocity in
`orbital_damp_rope_velocities!`. The hub could not droop.

**Choice made:** `shaft_dir` in `rope_forces.jl` is now computed as `normalize(hub_pos)` at
every ODE step. Hub ring translational velocity is no longer killed. The hub is a free 3D
body, held by rope tension + back line + lift device.

**Alternatives considered:** Keep fixed β but add a spring-restoring force toward the nominal
hub position. This would allow some hub motion while preventing numerical drift, but it
introduces an artificial restoring force with no physical basis.

**Why this choice:** The hub elevation angle is a physical outcome of the force balance, not
a design input. A simulator that constrains it to a fixed value cannot model droop, collapse,
or the dynamics of lifting and lowering the system. The freedom is essential for any realistic
launch/retrieval or fault simulation. The intermediate ring velocities are still suppressed to
prevent numerical drift, but the hub itself must be free.

**Consequences:** Simulations now require a lift device or CT thrust to maintain hub altitude.
Without any lift force, the hub droops from 30° to ~26° over ~10 s. This is physically
correct. Simulations from this commit onward produce different hub position trajectories than
earlier runs — they are more realistic, not broken.

**Status:** Active.

---

## [2026-04-01] Sim/reporting decoupled: Julia CSVs → Python Word documents

**Context:** The original pipeline ran Julia to produce results and immediately generated Word
reports in the same script. This made overnight batch runs monolithic: if the report generator
crashed (e.g., a Python library issue), the simulation data was lost or had to be re-run. It
also meant the simulation environment (Julia) and the reporting environment (Python/python-docx)
had to both be available and working simultaneously.

**Choice made:** Julia scripts write results as CSVs to `scripts/results/`. Separate Python
scripts (`produce_*.py`) read those CSVs and generate Word documents. The two steps are
completely independent.

**Alternatives considered:** Single Julia → Word pipeline using a Julia Word library
(e.g., OOXML.jl). This would avoid the Python dependency but requires maintaining Julia-side
document formatting code — more fragile and less readable than Python's mature python-docx.

**Why this choice:** Decoupling means (a) simulation data is preserved regardless of what
happens to the reporting step, (b) reports can be regenerated from saved data without
re-running multi-hour simulations, (c) the two toolchains (Julia numerics, Python/Word
formatting) each stay in their natural domain, and (d) adding new analyses to existing reports
only requires changing the Python scripts. The tradeoff is that reports can become stale —
`RESTART_INSTRUCTIONS.md` documents the regeneration sequence to guard against this.

**Consequences:** All overnight simulation runs must explicitly write their outputs as CSVs.
Any analysis that was computed in memory but not saved to CSV is lost on process exit. Julia
scripts must be written with explicit `CSV.write()` calls; results should not rely on Julia
session persistence.

**Status:** Active.

---

## [2026-03-28] Differential Evolution chosen over gradient-based optimisation

**Context:** The TRPT structural sizing problem requires minimising the total ring frame
mass subject to FoS ≥ 1.8 for all rings. The search space includes discrete variables
(n_rings, n_lines) and the fitness function has discontinuities where manufacturability
bounds activate (minimum wall thickness, t/D limits). Multiple axial profile families create
disconnected feasible regions.

**Choice made:** Differential Evolution (DE) with F = 0.7, CR = 0.9, population size 64.

**Alternatives considered:** L-BFGS-B (gradient-based, handles box constraints), CMA-ES
(covariance matrix adaptation evolution strategy), Bayesian optimisation (surrogate model).

**Why this choice:** L-BFGS-B requires differentiable objectives — the t_min wall clamp and
integer rounding for n_rings and n_lines make this impractical without smoothing heuristics.
CMA-ES is effective on continuous, unimodal problems but struggles with the multi-modal
structure introduced by the five axial profile families. Bayesian optimisation builds a
surrogate model that becomes expensive to maintain beyond ~1000 evaluations; the analytic
fitness function evaluates in <1 ms so the surrogate overhead is never recovered. DE handles
all of these naturally: it operates on populations that maintain diversity across disconnected
feasible regions, rounds integer variables, and needs only function evaluations. F=0.7, CR=0.9
are standard settings from Storn & Price (1997) that have converged reliably on similar
engineering sizing problems.

**Consequences:** DE converges more slowly per function evaluation than a gradient method
when the problem is smooth and unimodal. In this case, the fast analytic fitness (192 million
evaluations per island in ~3 h on a single core) more than compensates. The 60-island campaign
provides independent convergence verification: when two seeds of the same island reach the same
minimum, we have high confidence it is the global optimum within that (beam, axial profile)
combination.

**Status:** Active.

---

## [2026-03-20] FoS 1.8 as the structural feasibility threshold

**Context:** The optimiser needs a single scalar threshold to classify designs as structurally
feasible or infeasible. This threshold directly controls the minimum-mass winner — a higher
FoS threshold produces heavier, more conservative designs; a lower threshold produces lighter
designs with less margin.

**Choice made:** FoS ≥ 1.8 as the hard constraint. The constraint is applied to Euler column
buckling of each polygon segment at the peak design load (25 m/s, DLF = 1.2).

**Alternatives considered:** FoS 1.5 (IEC 61400-1 extreme event, well-documented loads),
FoS 2.5 (conservative for novel technology with poorly characterised loads), FoS 3.0 (used in
earlier TRPT_Ring_Scalability_Report analysis for rated-load buckling).

**Why this choice:** FoS 3.0 in the scalability report was applied at rated load (11 m/s),
not at the 25 m/s survival load. At 25 m/s the load is approximately 5× the rated load
(load ∝ v²); applying FoS 3.0 at 25 m/s would produce enormously heavy designs. FoS 1.8
at 25 m/s corresponds to roughly FoS 9 at rated — conservative for the operating regime.
IEC 61400-3 guidance for offshore wind uses 1.35 for partial safety factor on thrust load
with well-characterised dynamic response; for an AWE prototype with limited validation, 1.8
provides additional margin against load model uncertainty, manufacturing variability, and
installation-induced pre-stress.

**Consequences:** Designs at FoS exactly 1.8 are accepted. Any design that the model deems
feasible at FoS 1.8 may have true FoS lower or higher depending on how well the analytic
buckling model represents the as-built structure. The FoS threshold is a design policy, not
a guarantee — it should be revisited with measured field data.

**Status:** Active. The Phase E envelope check verified top candidates at a 1.5 FoS floor
across six operating points; all winners satisfied 1.5 floor comfortably, which gives
confidence that 1.8 at the survival design point is not marginal.

---

## [2026-03-18] Emergent torsion replaces analytical torque formula

**Context:** The predecessor code (`TRPTKiteTurbineJulia2`) computed inter-ring torque
transmission using `compute_tensegrity_torque()` — an analytical formula relating the twist
angle difference between adjacent rings to a restoring torque via a torsional stiffness
constant. This gave one scalar torque per ring pair. Torsional collapse was detected by a
separate threshold check on the twist angle.

**Choice made:** `compute_tensegrity_torque()` is deleted entirely. Torsional coupling
emerges from attachment-point geometry. Each of the 5 lines has 3 intermediate rope nodes;
tension in each sub-segment contributes a linear force and a torque to its ring nodes through
the cross-product `r_attach × T_vec`. Torsional collapse emerges from the `max(0, ...)`
tensile-only spring clamp.

**Alternatives considered:** Keep the analytical torque formula but add line-by-line slack
detection to capture torsional collapse more accurately. This hybrid approach would have been
faster to implement.

**Why this choice:** The analytical formula requires calibrating a torsional stiffness
constant, which is itself a function of the line geometry, material properties, and pre-tension
— all of which change dynamically. Calibrating it correctly is as hard as the physical model.
More fundamentally, the analytical formula cannot capture load wave propagation, snap loads,
or the asymmetric partial-collapse behaviour where some lines go slack and others remain taut.
These are physically real phenomena that a lumped-parameter model cannot represent. The
emergent approach models each line individually; the correct torsional stiffness, damping, and
collapse threshold all fall out of the geometry and material properties without additional
calibration.

**Consequences:** The ODE state vector grows from 128 states (TRPTKiteTurbineJulia2) to 1478
states. Simulation time increases proportionally. The QNDF implicit solver is needed to manage
the stiffer system (shorter sub-segment springs). This is the fundamental reason for rewriting
the simulator in a new package rather than extending the old one.

**Status:** Active. The emergent model is the simulation core from which all analyses derive.

---

## [2026-03-18] Canonical physics refactor: phantom CL lift removed from CT thrust

**Context:** The predecessor code applied two aerodynamic hub forces simultaneously: a BEM CT
rotor thrust in the tether (shaft) direction, and a kite-style lift force `q·A·CL` in the
`[0,0,1]` (straight up) direction. The intent was to model the net upward force from the
rotating disc. This was physically wrong for two independent reasons.

**Choice made:** The `q·A·CL` block in `ring_forces.jl` was deleted. The only aerodynamic
hub forces are: (1) CT thrust in the shaft direction, and (2) the separate lift device force
(from `lift_kite.jl`, applied only when a LiftDevice is provided).

**Alternatives considered:** Correct the CL direction from `[0,0,1]` to the disc normal
direction (shaft axis) and reduce the CL coefficient to avoid double-counting with CT. This
was considered but rejected: the disc normal force is CT thrust by definition. There is no
additional kite-style lift force from the rotor disc at 30° elevation — the in-plane wind
component (v·sin30°) produces a force slightly downward along the tether, not upward.

**Why this choice:** The phantom CL lift inflated the hub's upward force, making the hub
appear to float on its own aerodynamic lift at much larger apparent kite area than physically
justified. This masked the real requirement for the lift device: once removed, the required
lift dropped to just the airborne weight (245 N), which changed the sizing of all three lift
device architectures. Removing phantom forces is always preferable to correcting them: a
correction requires an accurate coefficient, while removal just applies the correct physics.

**Consequences:** All simulations before this commit (including all reports prior to
`12bc91b`) used the phantom lift. Their hub force balance and lift device sizing conclusions
are wrong. The canonical reference output is `scripts/results/canonical_output_v12.0.csv`
from after this fix. All reports were regenerated.

**Status:** Active. This decision is permanent — the phantom force was a bug, not a modelling
choice.

---

*This file is updated with each significant decision. Minor implementation choices (variable
names, code structure, test organisation) are not recorded here. Record a decision when:
(a) multiple plausible alternatives existed, (b) the choice has non-obvious consequences, or
(c) the choice is likely to be revisited or questioned.*

---

## Knowledge Pipeline Decisions

*These decisions were made during the 2026-06-22–23 K1 knowledge extraction sprint.
They live here because the pipeline serves KTD.jl's literature grounding.
Full session record: `docs/reports/knowledge-pipeline-sprint.md`.*

### [2026-06-22] Single-doc GPU processor for industry documents

**Context:** Initial approach used persistent K1 GPU server (localhost:8000). Crashed after
4–5 requests due to GPU memory accumulation.

**Decision:** Switched to single-doc processor — each cron tick loads the K1 model fresh,
processes ONE document, then frees GPU memory.

**Rationale:** Eliminates server OOM. Trade-off: ~20s model load overhead per doc, but
reliable. Of 45 industry docs, none lost to crashes after the switch.

**Status:** Deployed in `ingest_one_industry.py`. Cron paused 2026-06-23.

### [2026-06-22] Cursor + skip logic for academic ingestion

**Context:** Initial `k1_ingest.py` re-processed all 540 papers on every run. 64 papers
(patents/catalogues) produced empty graphs, wasting 14 reads per batch.

**Decision:** `~/.k1_ingest_cursor` tracks last-processed filename. Skip gate checks for
existing `graph.json` before processing. Empty graphs are also skipped.

**Rationale:** Idempotent ingestion. No wasted GPU on known-empty or already-processed papers.

**Status:** Deployed. Cursor file at `~/.k1_ingest_cursor`.

### [2026-06-22] JSON repair over clean-output enforcement

**Context:** K1 4B model produces near-valid JSON with common failures: unterminated
strings, markdown code fences, trailing commas.

**Decision:** Accept imperfect K1 output and repair post-hoc rather than constrain
K1 generation (which would reduce extraction quality).

**Rationale:** JSON repair is deterministic and cheap. Prompt constraints to force
perfect JSON reduce extraction quality. Repair handles 95%+ of failures.

**Status:** Deployed in `k1_server.py` and `k1_ingest.py`.

### [2026-06-22] max_tokens=4096 + paragraph-boundary chunking

**Context:** Initial max_tokens=2048 caused frequent JSON truncation. Papers with
many findings produced partial graphs.

**Decision:** Increased to 4096 tokens output. Input text chunked on paragraph
boundaries at 6000-char windows.

**Rationale:** Doubled token budget nearly eliminated truncation. 4096 is the practical
limit for K1 4B on RTX A4500 (20 GB VRAM). Paragraph-aware chunking preserves
semantic units.

**Status:** Deployed in both `k1_ingest.py` and `ingest_one_industry.py`.

### [2026-06-23] Phase prioritization: 1 → 3 → 3b

**Context:** Multiple analysis phases compete for attention. Need Porto-ready materials.

**Decision:** Phase 1 (collaboration map) → immediately useful for networking.
Phase 3 (citation lineage) → ground claims in literature.
Phase 3b (web validation) → pressure-test highest-risk claims before being challenged.

**Rationale:** Collaboration map is the most immediately useful deliverable. Citation
lineage prevents embarrassment. Web validation catches K1 graph blind spots. Phases
4 (CSV anchoring) and 5 (paper synthesis) deferred.

**Status:** Phases 1, 3, 3b complete. Phases 4, 5 planned.

### [2026-06-23] All crons paused for Porto preparation

**Context:** Ingestion complete (540 academic + 45 industry). Continuous cron
notifications generate noise during focused preparation.

**Decision:** Paused all three ingestion crons. GPU freed. Signal notifications stopped.

**Status:** All crons paused. AWS Paper Ingest, K1 Paper Ingest, Industry Doc Ingest
all in 'paused' state as of 2026-06-23 15:17.

### [2026-08-19] Mass-aware constant-tension lift regime — 5 kW redo

**Context:** The first 5 kW v13 campaigns (18.0/21.2/25.0 m) ran a FIXED
rotary lifter — tension was wind-dependent and identical for every genome.
ODE gate matched the runner, but the regate passed no lift device at all.
Rod (2026-08-18): the rung must be redone with mass-aware lift.

**Decision:** Lift line tension = f(kite-turbine mass) ONLY: vertical
component = 1.5 × m_airborne × g, FLAT at all wind speeds (const_tension,
modulated-lifter assumption), applied per genome via
`lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0,
const_tension=true)`. All instruments (campaign runner, ode_gate_v13.jl,
regate, ladder) resolve to the same lift_for. Lift kite mass does NOT enter
the tension calc. First-campaign results retained as the **fixed-rotary
regime** baseline for regime-vs-regime comparison (not voided); the redo is
the **mass-aware constant-tension regime**.

**Model era:** post-428f491_mass-aware-const-tension_ON (suite 1912/1912
green on 428f491). Smoke acceptance 2026-08-19: status=:ok at all three
lengths, in-run T_lift ≡ T_ref to 0.00% rel.

**Status:** Redo runner + gate aligned + smoke passed; launch pending Rod's go.

### [2026-08-20] 50 kW blade-mass contamination — fixed; λ reserved for TSR

**Context:** The 5 kW v13 winners carried 133–157 kg of blades — 95% of
airborne mass, φ ≈ 17–20 kg/kW. Rod's hypothesis: the 5 kW campaign does not
penalise low power-to-weight devices. **Confirmed, stronger than suspected:**
`build_system_from_v10` hard-coded `p_base = params_v5_50kw()` and
`m_blade = p_base.m_blade · le²` (le = 1.0) → 12.0757 kg/blade on EVERY rung,
while the campaign's own scaled base gives 0.863 kg (14× discrepancy); λ
scaling reached the expansion rotors (0.37 kg) but never the main blades. The
v12_fitness objective has no mass term (mass was removed from the objective
at V11 after DECISIONS [2026-06-21] — mass-in-objective broke the DE), so the
contamination was invisible: power ∝ lines, blade mass = 12.0757 × lines →
maximising power maximised mass (corr(fitness, mass) = −0.175; best-5 designs
all 139–151 kg; lightest-5 at 41.8 kg scored worse). The mass-aware lift
tension was inflated ~9× (2,175 N vs ~240 N).

**Decision (Rod's approval, 2026-08-20):**
1. **Rung-scale the build base:** `build_system_from_v10` gains a
   `base_params` kwarg (default `params_v5_50kw()` → legacy 50 kW callers
   bit-identical); `evaluate_windowed`, `ode_gate_v13.jl` and the economics
   script pass the campaign's scaled base.
2. **λ²-scale main-rotor blade mass:** `m_blade = base_params.m_blade ·
   λ_eff²`, `λ_eff = rotors[1].blade_scale` (the existing k_mppt λ²
   convention). Deliberate physics change for any λ<1 rotor, not just 5 kW.
3. **λ reserved for TSR only:** genome genes x13/x14 renamed
   `blade_scale_top`/`blade_scale_bottom` across the decoder, telemetry
   headers, genome chooser, recampaign, export/plot tools, genome glossary
   and CONTEXT.md (backward-compatible reads of historical `lambda_top`/
   `lam_top` CSVs).
4. **Main-rotor radius λ-blind — RESOLVED (Rod: "obvious physics scaling
   failure... needs resolved"):** `build_system_from_v10` had hard-coded
   `rotor_radius = 5.0·le`, so the ODE swept area (∝R²), TSR and blade chord
   ignored the rung and the genome's blade_scale — aero power was λ-blind
   while blade mass was λ²-scaled, and the DE exploited it (λ→0 blades with
   full 5 m-disk power). Now `rotor_radius = hub_rotor.blade_tip_radius`
   (= r_rotor × blade_scale), completing the k_mppt λ²-scaling intent.
5. **Ring-anchored 70/30 annulus for ALL rotors (Rod, 2026-08-20):** the
   main rotor is now a first-class parametric rotor like the expansion
   rotors — blade span is a genome parameter (λ), anchored at the RING
   radius with the 70/30 split (70% outboard / 30% inboard of the span),
   consistent across the decoder (`blade_tip = +0.7·span`, `blade_hub =
   −0.3·span`), the builders and every evaluator. The ODE swept area is the
   ANNULUS `π(r_out² − r_in²)` with `r_out = r_ring + 0.7·span`, `r_in =
   r_ring − 0.3·span` (via the new `RotorSpec.blade_hub_radius` and
   `main_rotor_swept_area`); TSR uses r_out. **`r_ring ≥ 0.3·span` is a hard
   gate** (`rotor_annulus_ok`) — inner tips may not cross the shaft axis.
   **Calibrated against the thesis:** the Daisy rigid rotor is exactly this —
   ring radius 1.52 m, inner tip 1.22 m, outer tip 2.22 m (outboard 0.70 m =
   0.7·span, inboard 0.30 m = 0.3·span). The old decoder hub (0.25·R, positive)
   and the full-disk ODE area are retired.

**Why this choice:** the contamination made every non-50 kW rung carry 50 kW
blades, inflating φ ~20× and the mass-aware lift ~9×, and poisoning the
economics (LCOE 14.8–16.4 p/kWh). Fixing the build (not the objective) is
the minimal correct change: rung-scaling + λ² are the same physics the
expansion rotors already implement, and the 50 kW default keeps legacy
callers bit-identical.

**Consequences:** on the SAME (old, mass-blind) winners the fixed mass model
gives airborne 6.3–7.0 kg, φ ≈ 0.8–0.9 kg/kW, capital ≈ £9.4k, LCOE ≈
5.5–5.8 p/kWh and ≈ 1.24 gCO₂e/kWh @ CF 0.30 — but those winners were still
mass-blind-optimised, and the recorded P_gen was gated with the inflated
lift. **Remaining:** acceptance suite; re-gate the winners; mass-aware
objective (φ target — Daisy-scale ~1–2 kg/kW production, prototype-realistic
3–5 kg/kW, Rod's call); 5 kW re-run; full-scope 2026 LCOE/LCA workbook.
Open physics item surfaced: main-rotor BEM power uses rotor_radius = 5.0 m
regardless of λ — power is not λ-scaled while mass now is; examine in the
re-run.

**Status:** All five fixes implemented; fast suite 1918/1918 green through
all of them. Re-gate after the mass fix alone: winners PASS with power
retained (7.143 / 6.254 / 7.130 kW) — the mass fix is aero-neutral. **After
the radius fix (item 4) and the annulus fix (item 5), the OLD winners are
VOID: the 18 m winner (r_hub 0.7 m ring, r_out 1.08 m, 2.73 m² annulus,
Betz cap ≈ 1.3 kW) cannot reach 5 kW.** The 5 kW re-run is now mandatory;
no 5 kW economics are quotable until then. The re-run will use the
mast/Daisy-up base (Rod: scale UP from the 1.5 kW Daisy and the mast test,
not down from 50 kW — thesis ring 1.52 m, tips 1.22/2.22 m; the 10 kW
General Release report was itself "scaling the existing 1.5 kW kite
turbine") and a hard-constraint mass-minimisation objective (power + FoS
floors hard-reject; score = true physics mass). Acceptance suite: expected
red (old-physics expectations) — re-baseline on the re-run's winners.
Working tree NOT commit-ready.

### [2026-08-20] FoS floor 2.5 + NZTC carbon LCA + certification route

**Context:** Rod asked whether an FoS floor of 2.5/3.0 would be too lenient
for flying permission/certification. The model's FoS metric is uncalibrated
(the Daisy flew successfully while the model scored it ≈ 0.22 — gate 13,
static FoS currently DISABLED ≤ 7 kW), so an absolute floor is a design
policy, not a validated certification number. The certification route is not
a single FoS figure — it is the safety case (CAP 393 / CAA Article 253 for
<2 kg small kites; SORA for larger; the AWE White Paper on safe operation &
airspace integration).

**Decision (Rod):** FoS floor = **minimum 2.5 at all points we measure**,
"until we know better through field trials and breakages". Re-enable the
static structural FoS gates (gate 13) at the 2.5 floor for the re-run; the
mass-minimisation objective minimises mass ABOVE that hard floor. Note
2.5 is MORE conservative than the repo's prior 1.5/1.8 (IEC 61400 ~1.35
partial factors; aerospace ~1.5 ultimate).

**Implemented (2026-08-20):** the evaluator seam now passes the TRUE physics
mass — `fitness_fn(P, FoS, cfg, mass)` with `mass = expansion_airborne_mass
(sys, pc)`; `v11_fitness`/`v12_fitness` gained 4-arg overloads (mass ignored,
backward compatible); new `mass_min_fitness(P, FoS, cfg, mass)` = `Inf` below
either hard floor (`FoS < cfg.fos_hard`, `P < cfg.p_floor_kw`) else `mass`.
All adapter lambdas (src + scripts + test_evaluator_v13) updated to 4-arg;
unit test added; fast suite 1918/1918 green. **Remaining to wire before the
re-run:** set `fos_hard = 2.5` and `fitness_fn = mass_min_fitness` in the
campaign runner, and build the mast/Daisy-up base.

**Sources:** Airborne Wind Europe folder (`04_Business/AWES Co-opetition &
Market Analysis/Airborne Wind Europe/`): `AWE White Paper on safe operation
and airspace integration_v1.0.pdf`, airspace-integration recommendations
(Task 48 WP3), AWE-Definitions tables, AWE Sites 2024.xlsx — the SORA +
airspace-permission + safe-operation guides for the field-test proposal's
certification section.

**Carbon LCA (extracted, NZTC TechX):** `02_Funding/Applications/NZTC
TechX/Impact Assessment/Carbon Impact Model_v2.xlsx` is a full 50 kW LCA
"based on scaling the 1.5 kW Daisy" (per the sheet): BOM — airborne 25 kg
(carbon epoxy 5, Dyneema 6.5, foam 7.5, Dacron 3, PLA 3), ground 823 kg
(steel 681, copper 112, circuits 9, battery 2, PLA 19); CF 0.528; 20 y;
total 3,632 kg CO₂e → **0.78 gCO₂e/kWh**. IdeMat carbon factors (the ones
the LCA uses): carbon epoxy **88.9** kgCO₂e/kg (vs the Economics module's
24 — a 3.7× under-count), Dyneema 1.70, PUR foam 3.50, PET/Dacron 1.66,
PLA 3.57, steel 0.958, copper 3.24, PCB 26.3, LiFePO4 battery 94.1. The
Economics module's carbon factors must be replaced with these before any
gCO₂/kWh figure is quoted. **The 50 kW BOM is NOT an anchor (Rod, 2026-08-20)
— it is extrapolation on shaky data.** The measured anchor is the Daisy:
blade = 420 g foam + shrink skin + 2 carbon rods (9 mm OD / 0.5 mm wall) +
3D fuselage; flying weight **< 2 kg** at **> 1.5 kW @ 10 m/s** (AWEC 2019);
624 W / 146 rpm / 6-blade / 11.2 m² / ζ=3.77 (Dec 2019 blog). Cross-check:
the annulus π(2.22²−1.22²) = 10.8 m² matches the measured 11.2 m²; Daisy
φ ≈ 1.3 kg/kW → 5 kW ≈ 4–7 kg, consistent with the fixed model's φ ≈
1 kg/kW. Mass exponent underdetermined from one point; field tests measure
it.
### [2026-08-22] Unified blade-mass law: m = m_ref · λ³ + knuckle floor

**Context:** three mutually inconsistent blade-mass models coexisted: the
main-rotor AREA law (`m_blade · λ²`, objective_evaluator.jl), the CFRP
CUBE law for expansion rotors (`(0.3 + 0.1·tip)·λ³`, expansion_rotor.jl),
and the empirical rung law (`m ∝ P^1.35`). Rod (2026-08-22): rigid-foam
blades scale with VOLUME (λ³), not area — the λ² term and the CFRP
constants are rejected. The Daisy blade anchor is **420 g** (measured; the
same wings/fuselages on both the 3-blade and 6-blade rotors) — the Gate 1c
renormalisation to 210 g is REVERSED: the built 6-blade rotor carries
6 × 420 g = 2.52 kg/ring.

**Decision (Rod's approval, 2026-08-22):**
1. **Unified law:** `m_per_blade = m_ref · λ³` for main AND expansion
   rotors, `m_ref` = the rung's per-blade reference mass (`M_BLADE_REF_KG`
   = 0.420 kg at the Daisy rung; higher rungs pass their mass_scale'd
   base). λ = decoded genome blade_scale × builder dial. The λ³ law
   composes ON TOP of rung scaling (m_ref ∝ P^1.35) — the rung scales the
   reference blade geometry, λ scales within a rung. k_mppt stays λ²
   (power ∝ swept area ∝ λ²); only the mass law changes.
2. **Knuckle floor:** every blade node carries ≥ `OPT_KNUCKLE_MASS_KG`
   (0.050 kg, approved 2026-04-20), added into `expansion_airborne_mass`
   (the DE score AND the lift sizing input). ODE-inertia knuckles flagged
   as follow-on.
3. **420 g anchor restored** in `params_daisy`; `M_BLADE_REF_KG = 0.420`
   exported.
4. **`geometry_fingerprint` double-count fixed** (`er.mass × er.n_blades`
   where `er.mass` is already the assembly total).
5. **Airborne ring count fixed:** `sys.n_ring − 1` (was `p.n_rings`,
   missing the hub ring).
6. **Ramp evaluator contamination fixed:** `evaluate_ramp` did NOT pass
   `base_params=p` to `build_system_from_v10` — it built every rung with
   the 50 kW base (12.0757 kg/blade), the same contamination DECISIONS
   [2026-08-20] fixed for `evaluate_windowed`. Both evaluators now build
   the same machine.
7. **Length double-scaling fixed:** `params_at_length(L)` in the runner,
   smoke, gate and k-sweep mass_scaled the explicitly-passed length again
   (×√(5/1.5) ≈ 1.826) — "18.8 m" machines were actually 34.3 m while
   h_ref/masses described 18.8 m. `tether_length` is now restored to L
   after rung scaling. **All 5 kW ODE evidence from 2026-08-21 onward was
   measured on the wrong-length machine and is superseded** (the k sweep
   is re-run under the honest window, 2026-08-21 open task).
8. **Seed rotor-area discrepancy flagged:** the built seed sweeps ≈ 60 m²
   (decoder sizes against the hub wind v_i ≈ 8.7 m/s, r_out ≈ 4.8 m) —
   NOT the ~10.8 m² the 2026-08-21 handover assumed. The honest-window
   traces must measure the true sustained power of the corrected machine.

**Verification:** RED tests first (`test/test_blade_mass_law.jl`, 15
assertions: λ³ law, 420 g anchor, knuckle floor, fingerprint, rung base);
implemented; fast suite **1936/1936 green**. Seed consequences on the
corrected 18.8 m machine: m_airborne (no lifter) = 29.85 kg (was 13.12 kg
at the wrong length / 210 g law), T_lift(ref) = 467 N (1.5× margin,
const_tension), main blades 12.8 kg + 1 expansion rotor 12.8 kg + knuckles
0.6 kg.

**Remaining:** k re-sweep under the honest window on the corrected machine
(2026-08-21 open task); acceptance suite re-baseline on the re-run's
winners; ODE-inertia knuckles.

### [2026-08-22] Hub-rotor double-model eliminated — expansion mapping excludes the main rotor

**Context:** the honest-window k sweep on the corrected 18.8 m machine showed
the seed decaying to ω ≈ −0.2 rad/s (backward) at EVERY k — even freewheeling
(k=0). Bisection isolated it: a build WITHOUT the expansion mapping sustained
and accelerated (ω → 14.2 rad/s at k=5.39), the canonical build died.
`expansion_params_from_rotors` mapped the HUB rotor (decoder ring_idx ==
n_rings, "mask position 1") into `sys.expansion_rotors` on the hub ring, so
the ODE applied BOTH the main cp/ct rotor AND the expansion α/induction model
to the SAME annulus. At 6-blade solidity the expansion model brakes (the same
mechanism the 2026-08-17 anchor session found and worked around by using the
main cp rotor only). The hub entry ALSO double-counted blade mass in
`expansion_airborne_mass` (the 5 kW seed's 12.8 kg blades appeared twice).

**Decision:** the hub rotor is the MAIN rotor — it is modelled by the cp/ct
rotor at the hub ring and must NOT appear in the expansion list.
1. `expansion_params_from_rotors` (and the phantom builder's inline loop)
   skip rotors with ring_idx == n_rings. Expansion rotors are ADDITIONAL
   rotors on intermediate rings only. `minimal_hub` machines are hub-only by
   construction (empty expansion list).
2. Defensive guard in ring_forces.jl: the expansion loop skips the hub ring.
3. Verified: the canonical 5 kW seed now sustains and accelerates (ω 12.16 →
   14.33 rad/s over 20 s at k=5.39; P_gen ≈ 9 kW at 20 s and climbing — the
   60 m² seed is OVER-rotored for 5 kW, the DE's job is to shrink it).
4. This changes the dynamics (and mass accounting) of EVERY multi-rotor
   machine since the "unified rotors" decoder (2026-08-20) — including the
   V10 50 kW family, whose hub was being braked/double-counted. All prior
   results from that era are superseded; acceptance suite re-baseline covers
   it. Fast suite 1926/1926 green.

**Remaining:** honest k re-sweep on the fixed machine (running); settle-vs-ODE
gap workstream (Option 2) stays a parallel proposal — the settle now
UNDER-predicts the ODE equilibrium (11.96 vs ~14+ rad/s), a different (less
harmful) mismatch than the 2026-08-13 over-prediction.
