# 2026-10-07 — State-fed regen torque cap (D4 follow-on) — PROPOSAL

**Status:** PROPOSAL. No code until the room agrees this set and the flagged
rulings land — coupling is ruled at rev 3 (item 2); κ remains open (item 1).
Parent: `docs/plans/2026-08-22-physics-convention-fixes.md` §1 (D4).
Draft: hermes, from the room's adjudications at `origin/bank-derate-cos2p65`
(`7c9f4b9` + `c657c76`). All line cites below are the room's certified reads of
the tip, not re-derived here. Rev 2 folds the aero/software verifications of
2026-10-07 (pass bar, homogeneity pin, detector wiring, C1 range); Rev 3 folds
the coupling ruling and its D4-drift disclosure into item 2 (science-validator).

## What

Compose the D4 static cap with the in-repo C1 transmission clamp:

```
τ_regen_cap(state) = min( generator_torque_cap(p), κ · min_bay τ_sat,bay(state) ), κ ≤ 1
```

- `generator_torque_cap(p) = 22.65 / 300^1.5 · p_rated_w^1.5` — D4, `b488262`
  (`src/ring_forces.jl:54`). 1541.137 N·m at 5 kW.
- `τ_sat,bay` — C1, `src/rope_forces.jl:525–623` (2026-08-14, criterion
  2026-09-25; segment loop `:533`, branch `:576–595`, clamp closes `:600`): Case A `trpt_torque_capacity_axial(lim, trpt_axial_force(T_lines,
  l_t, L_s))` — Tulloch's peak at the live axial force; Case B the HELD
  fixed-gap form `T_lines · r_s² · sin(dastar) / chord`. Hard, sign-preserving:
  demand past `τ_sat` is not transmitted, and a saturated bay cannot reverse
  and pump a ring.
- Both branches are linear in the live segment tension: **tension supplies
  capacity**. The min is over bays.

## Why

The D4 cap is static and blind to the live machine. Transmission capability is
tension-dependent — combined axial + torsion on the strands — so the hazardous
state is LOW tension (slack bay, descent, low elevation): there the state term
binds, regen authority falls linearly, and the rotor accelerates instead.
Twist runaway is clamped off by construction (C1); speed is the exposed mode.
That is Rod's brief: recognise the runaway, no torque past a certain point,
acceptable for a mostly-tensile structure.

## Why not a utilisation-decay curve

The f(utilisation) sketch is superseded: C1 is already physics (Tulloch),
already hard, already sign-preserving, and in the dynamics since 2026-08-14.
A third criterion adds nothing. Note the C1 comment's own record: a cap in the
tension basis once cut a φ = 2.01 bay to 0.66 of capacity and to zero at
φ = 2 — the same-state rule below exists because that mistake already happened.

## Decisions needed before code

1. **κ.** Nominal 1.0, but ten of twelve bays on the live campaign seed are
   Case B — the HELD placeholder whose keeper ruling Rod owes (needs ODE
   evidence at 70–100° twist). Until that ruling lands, κ must be stated
   explicitly; κ < 1 is the honest default while the binding branch is a
   placeholder. Direction is on record: the held branch's own comment says
   "conservative because it sits below the true capacity"
   (`rope_forces.jl:588–589`) — accepting that, κ < 1 errs pessimistic on the
   runaway read (lower authority ⇒ higher measured park); the keeper's
   70–100° ODE evidence still decides. (Science Validator adjudicated the
   form; the κ value rides the keeper.)
2. **Coupling — RULED (Science Validator, 2026-10-07, at the tip
   `c657c76`).** Since D4, the damping coefficients (10/2500 · cap at
   `ring_forces.jl:127`, 15/2500 · cap at `:153`) and the brake budget
   (1500/2500 · cap at `:168–169`) are fractions of the cap. Ruling: the
   **brake budget rides the state-fed value** — the brake route replaces
   `tau_gen` after the clamp (`:170`), so its budget is its own transmission
   guard and cannot exceed what the shaft carries; the **damping coefficients
   ride the static rating** (`:127`/`:153` keep reading `generator_torque_cap(p)`)
   — they oppose differential wind-up, and collapsing their demand in the
   low-tension state would remove damping exactly where wind-up is the runaway
   precursor; demand past the transmission limit is absorbed by the
   sign-preserving clamp on the sum (`:161–162`, reading the composed value
   per item 3). **Drift disclosure (aero-worker's finding, re-derived here):**
   the `2500` denominators are the *old* 10 kW cap value, so D4's re-anchor
   moved the 5 kW absolutes — damping **2.5 → 6.16** and **3.75 → 9.25**
   N·m/(rad/s) (×2.466), brake budget **375 → 925** N·m; the old absolutes are
   preserved only near **~30.4 kW** (where old = new cap), nowhere on the
   operating ladder. **Resolution: accept the cap-riding fractions knowingly —
   do not re-calibrate the denominators.** The pre-D4 absolutes derive from
   the law D4 retired; no measured basis exists for absolute damping values;
   the fractions are the construction `b488262` deliberately carried. If the
   level ever needs to move, the knob is the fraction constants (10 / 15 /
   1500), never the retired denominators. All tip-era fold numbers are
   post-D4 and already carry the change.
3. **State surface.** `get_generator_torque` is static-callable today
   (`generator_torque_cap(p::SystemParams)`). The state-fed min() must read
   C1's own `T_lines`, `l_t`, `L_s` from the same frame — never a capacity at
   one twist multiplied by the tension at another. `:161` and `:168` must read
   the new surface, not a copy.

## Acceptance set (revised per Science + Aero Validator; rev 2)

1. **Fold pin.** Repeat D4 test (d) against the composed cap at the fold
   state: `cap ≥ 1.5 × ~695 N·m` (`test_metric_consistency.jl:111`). We do not
   re-clamp the S2 fold at a moving value — that is the exact regression D4
   just closed. Make the readout decisive in one multiply: print
   `κ · min_bay τ_sat(settled)` beside `1.5 × 695 = 1042.5 N·m` — that single
   comparison decides whether the landing re-clamps the fold, no second round.
2. **Collapse at reference.** The min() reproduces 1541.137 N·m only while the
   state term is inactive; assert composed ≡ `generator_torque_cap` with the
   state term removed.
3. **Homogeneity — the primary pin, not monotonicity.** Verified at source:
   Case A is `F_axial · (√Q − √max(P,0)) / 2` with
   `F_axial = T_lines · L_s / max(l_t, 1e-9)` (`trpt_twist_limit.jl:140–146,
   :161`); Case B is `T_lines · r_s² · sin(dastar) / max(chord, 1e-9)`. At
   fixed `(l_t, L_s, lim)` both are **exactly linear in `T_lines`** — the
   property the whole "tension supplies capacity" argument rests on, which a
   monotone test only weakly implies. Pin: `τ_sat(t·T) == t·τ_sat(T)`
   (rtol 1e-12) at `t ∈ {0.5, 2, 10}`, both branches (Case A synthetic;
   Case B from a live-seed bay), through the authority's own call path. Plus
   the composed pass-through: linear below saturation and exactly
   `== generator_torque_cap(p)` above it. The cross-state monotone stays as
   the secondary.
4. **Runaway gate — pass bar written in.** Pass iff the ODE flight under the
   composed cap settles on the evaluator's own `stationary` flag
   (`objective_evaluator.jl:1114–1136`:
   `stationary = dP<0.10 && dF<0.10 && P_steady && FoS_steady`) with
   worst-element tip speed below the ceiling — i.e. no `hub_diverged` hard
   reject (`:1040`; `tip_speed_sanity_ok` defined `:420`, sets at
   `:925–926`). The acceptance number is the parked ω*, reported with its
   margin against the gate state and the binding limiter named (state term vs
   generator cap). Gate-state anchors are tip-era (aero-worker's `c657c76`
   fourstick, harness byte-identical to the tip): **ω_gnd 13.970 rad/s, hub
   tip 78.41 m/s** — do not pin 72.71 m/s, that reading predates `b488262`
   and `b835ebc`. Candidate: the scalar balance `P_aero(ω) − P_par(ω) −
   τ_cap(state)·ω = 0` frozen-state; the ODE flight is the acceptance number.
   The blade-stress check is **not** an acceptance
   item — `min_fos_blade_root` is hard `Inf` (`trpt_optimization.jl:1106`,
   "defer full beam-on-supports model") and
   `CFRP_BLADE_SIGMA_YIELD_MPA` (`structural_constants.jl:17`) has zero
   consumers. PRD 0006:147 root-bending is carded separately.
5. **Detector — wiring, not just a flag.** Per-bay `u = |τ_transmitted| /
   τ_sat` plus a "C1 active" flag. Provenance: the frame's `segment_torque`
   is a capture-side re-derivation (`capture_extended`, `sim_frame.jl:439,
   449–461` — "Telemetry-only: does not feed back into the solver") with no
   clamp in it, so under wind-up — exactly when the state term binds — it can
   read through capacity while the solver's clamped value cannot. The
   solver's transmitted value is `tau_tr = clamp(½(ts_a − ts_b), ±τ_sat)`
   (`rope_forces.jl:600`). Build: record `τ_sat` and the solver's `tau_tr`
   per bay at capture so `u` reads the clamp's own numbers; if the frame
   recompute is kept instead, calibrate it against one frozen frame first.
   Also: `segment_tension` is a per-line mean, C1's `T_lines` is the sum —
   `u` must state its convention. (Science Validator: final wording of this
   item is yours to write.) Split `solve_equilibrium_omega`'s single
   `nothing` (`objective_v6.jl:390`) into air-brake vs runaway-at-ceiling
   before that path is quoted as recognising anything.
6. **Instrument floor.** `u` histogram across scenarios: non-pegged spread and
   at least one scenario where the state term binds — otherwise it is dead
   code that can never fail.
7. **dt-halving** on the binding scenario: the cap closes a feedback loop; the
   min-switch must not chatter.
8. **Regression pair.** S2 fold B2 — the case that rode the clamp (624.96 vs
   625 N·m under the pre-D4 law) — under the composed cap vs the D4 static cap.
   Pre-cap baseline in hand (aero-worker, `c657c76` fourstick: fold pair
   `w_settle 10.199 → ωf 13.910`, `Pf 6.028 kW`, gap 0.364).

## Sequencing

1. Science Validator readout (decode + build, no ODE): per-bay branch map
   (A/B), `K_geom`, `τ_sat` at the settled state on the S2 seed — certifies
   which branch actually binds; prints `κ·min_bay τ_sat(settled)` beside
   `1042.5 N·m` per item 1.
2. Room agrees this set + the rulings (κ, coupling).
3. Software Worker TDD: red tests → composed cap (state-carrying surface) →
   suite + tip-era re-runs (homogeneity pins, composed (d) repeat, dt-halving
   pair).
4. Aero Validator flies the binding scenario; the ODE flight is the
   acceptance number. Aero Worker re-flies the four-stick form against the
   composed cap; the post-cap delta table is his.
5. Ledger row (D4 follow-on) + DECISIONS entry.
