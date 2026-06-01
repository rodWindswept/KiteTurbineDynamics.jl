# Unifying Dashboard and Sweep Metrics on a Single Source of Truth

**Status:** Proposed / Ready for next session
**Owner:** Next Agent
**Date:** 1 June 2026

## 1. Context: The Dashboard ≠ Sweep Divergence

Recurring problem: positions, tensions, and power shown in
`scripts/interactive_dashboard.jl` (the GUI a user actually reads) do not match
the numbers reported by the automated physics sweeps. The same physical
quantities are currently computed by **several independent formulas that
disagree**. A dashboard that misreports the physics is worse than no dashboard.

The authoritative physics is the ODE itself: `multibody_ode!`
(`src/simulation.jl:308`) → `compute_ring_forces!` (`src/ring_forces.jl`) and
`compute_rope_forces!` (`src/rope_forces.jl`). Anything displayed or reported
must be reconcilable to what the ODE actually integrated.

### 1.1 Power — three incompatible formulas

| Path | Formula | Location |
|---|---|---|
| Live HUD | `τ_gen·\|ω_gnd\|` via full control-law replica | `src/sim_frame.jl:128–188` → `src/visualization.jl:1078` |
| Dashboard headless CSV | `k_mppt·ω_hub³` | `scripts/interactive_dashboard.jl:231` |
| Sweeps | `k_mppt·ω_gnd³` | `scripts/power_curve_sweep.jl:150`, `scripts/mppt_twist_sweep.jl:134`, `scripts/mppt_twist_sweep_v2.jl:210,296`, `scripts/mppt_ramp_only.jl:115` |

The true ODE torque (`src/ring_forces.jl:136–199`) applies an `elev_scale`
derating (→0.2 near furl), active torsional damping `c_d·(ω_gnd−ω_hub)`, a
`±2500·power_scale` clamp, and a `tanh` brake. The bare `k_mppt·ω³` formulas
drop all of this, so they report power the simulation never extracted. The
headless dashboard additionally uses `ω_hub` instead of `ω_gnd`, so the
dashboard disagrees even with itself between interactive and batch runs.

### 1.2 Tension — three incompatible proxies

| Path | Definition | Location |
|---|---|---|
| True physics | `EA·strain + c_damp·vel_proj`, all 4 sub-segments, **with damping** | `src/rope_forces.jl:80–81` |
| Dashboard + HUD | ring-attachment chord `EA·(‖pb−pa‖−4·length_0)/4·length_0`, **no damping**, assumes uniform sub-segment length | `src/visualization.jl:173–186`, `src/sim_frame.jl:221–235` |
| Sweeps | single interior sub-segment node-to-node strain | `scripts/power_curve_sweep.jl:28–34`, `src/simulation.jl:250–256` |

The chord proxy assumes `4·length_0[first]` equals the segment's natural length
— wrong exactly where v5 non-uniform spacing applies (flagged in the code
comment at `src/visualization.jl:170`).

### 1.3 Why it keeps recurring

`src/sim_frame.jl` was designed as the one source of truth ("consumers read
SimFrame instead of extracting metrics from raw u"). But the sweeps and the
headless dashboard mode bypass it and recompute inline, and `capture_frame`
itself **re-derives** the control law by hand-copying ~70 lines of
`ring_forces.jl` rather than reading the torque the ODE applied. Two copies of
the control law drift independently; the inline sweep formulas are a third
family. Every new script reintroduces the divergence.

---

## 2. Target Architecture

One rule: **the control law and the tension law each exist in exactly one
function; both the ODE and every observer call that same function.**

1. Extract the physics into **stateless, zero-allocation helpers** in
   `src/ring_forces.jl` and `src/rope_forces.jl` (Step 2). `multibody_ode!`
   calls them to apply forces during integration; `capture_frame` calls the
   *same* helpers during post-processing.
2. `capture_frame` builds `SimFrame` from those helpers — no copied control law.
3. Every consumer — live HUD, headless CSV, all sweeps — reads `SimFrame`.
   No consumer recomputes power or tension from raw `u`.

### Why not a mutable field on `sys`

The first draft of this plan suggested `ring_forces.jl` stash the applied
`tau_gen` on a mutable `sys` field for `capture_frame` to read. **That is
broken** — and the failure is silent. `build_dashboard` post-processes the saved
raw-`u` `frames` vector *after* the solver has stopped
(`src/visualization.jl:202`); during that loop the physics is not running, so a
`sys` field holds the *last step's* value and every historical frame would read
the same stale number. The HUD would show constant power/tension across the
whole playback. Stateless helpers that take state as arguments avoid this
entirely.

### The path-dependent-state caveat (important)

Rope tension *is* a pure function of `u` (positions and velocities both live in
the state vector), so `get_subsegment_tension(ss, pa, pb, va, vb)` is fully
recoverable from a saved frame. **Generator torque is not.** `tau_gen`
(`ring_forces.jl:136–199`) depends on three pieces of latched/integrated state a
single `u` cannot reconstruct:

- `sys.brake_engaged[]` — monotonic latch, set once `|ω_hub| < 1.0`
  (`ring_forces.jl:185–186`), never cleared.
- `k_mppt_scale` — MPPT stall ramp integrated over the depower sequence
  (`simulation.jl:297`).
- `backline_payout` / `L_winch` — winch actuator integrator state
  (`simulation.jl:286–301`).

So `get_generator_torque` must take these as **explicit arguments**, not read
them off `sys` (which would reintroduce the staleness bug for the boolean and
the params). Note `capture_frame` is already handed the static base `p` — not
`p_step` — at `visualization.jl:202`, and it already *mutates* `sys.brake_engaged[]`
inside the post-process loop (`sim_frame.jl:181`); playback of any
depower / stall / brake scenario is therefore **wrong today**. The fix is to
persist this latched state per saved frame (Step 0) so playback can feed it back
into the pure helper.

After this, the dashboard, batch runs, and sweeps cannot disagree by
construction, because they read the same struct produced by the same helpers fed
the same per-frame state.

---

## 3. Implementation Steps

### Step 0 — Persist latched state per saved frame (prerequisite for correct playback)

`run_canonical_sim!` already computes `tau_gen`, `T_max`, and `n_slack` per saved
frame internally for its `DepowerResult` (`simulation.jl:380–441`) — it has the
live `p_step` and valid `sys` state right there. Two clean options:

- **Preferred:** have `run_canonical_sim!` emit a `Vector{SimFrame}` (built via
  the §3.2 helpers, using the live `p_step` / `sys`) and have the dashboard
  consume that **directly** instead of re-post-processing raw frames. Geometry
  observables keep reading raw `u` (pure in `u`, unaffected). The HUD reads the
  live-captured `SimFrame`. This eliminates re-post-processing — and the whole
  staleness class — outright.
- **Minimal:** persist `(brake_engaged, k_mppt_scale, backline_payout)` per saved
  frame alongside `u`, and feed them into `get_generator_torque` during the
  `build_dashboard` post-process loop.

Either way, no consumer derives latched state from a single `u` or from stale
`sys` fields.

### Step 1 — Route all consumers through `capture_frame` (smallest change, biggest payoff)

Make every reported number come from `SimFrame`. This alone makes the dashboard,
headless CSV, and sweeps agree, even before the deeper refactor in Steps 2–3.
`scripts/science_pitch_depower_dynamics.jl:115` already does this — use it as the
template.

Edits:
- `scripts/interactive_dashboard.jl:226–238` (headless block): replace the inline
  `pk = p.k_mppt * om^2 * abs(om) / 1000.0` with a `capture_frame(...)` call and
  push `sf.P_kw`, `sf.T_max`, `sf.hub_z`, etc.
- `scripts/power_curve_sweep.jl:144–172`: replace `_mid_tension`/`_T_max` and the
  `k_mppt·ω_gnd³` power with `SimFrame` reads. Delete the local `_mid_tension`,
  `_T_max`, `_T_mean`, `_twist_deg` helpers (lines 27–53).
- `scripts/mppt_twist_sweep.jl:134`, `scripts/mppt_twist_sweep_v2.jl:210,296`,
  `scripts/mppt_ramp_only.jl:115`: same substitution.

Acceptance: for one fixed design and wind speed, the live HUD value at a given
`t` and the sweep CSV value at the same `t` match to within float tolerance.

### Step 2 — Extract stateless physics helpers; delete the duplicated control law

Create one canonical, allocation-free function per quantity and call it from
both the ODE and `capture_frame`.

```julia
# src/ring_forces.jl — single source of truth for the control law.
# Latched state is passed in explicitly (NOT read off sys) so the function
# is pure and safe to call on historical frames during playback.
function get_generator_torque(u, sys, p, t, wind_fn;
                              brake_engaged::Bool, k_mppt_scale::Float64)
    # extracts ω_hub, ω_gnd, hub_pos → elev_scale, active damping, clamp, brake
    # returns tau_gen::Float64
end

# src/rope_forces.jl — single source of truth for spring-damper tension.
# Pure in u (positions + velocities are both in the state vector).
function get_subsegment_tension(ss, pa, pb, va, vb)  # → tension::Float64
function get_max_rope_tension(u, sys, p)             # → (T_max, n_slack)
```

- `compute_ring_forces!` / `compute_rope_forces!`: refactor to call these
  helpers (no behavioural change to the ODE).
- `src/sim_frame.jl:128–188`: delete the ~70-line copied control-law block;
  replace with `tau_gen = get_generator_torque(u, sys, p, t, wind_fn;
  brake_engaged, k_mppt_scale)` and `P_kw = tau_gen·|ω_gnd|/1000`, sourcing
  `brake_engaged` / `k_mppt_scale` from the per-frame state persisted in Step 0.
  Remove the `sys.brake_engaged[]` mutation at `sim_frame.jl:181`.
- This removes the silent-drift class of bug (one control law, not two) and the
  playback-staleness class (no `sys` reads for latched state).

Acceptance: a unit test that runs one ODE step, captures the applied `tau_gen`,
then calls `get_generator_torque` on that frame's `(u, brake_engaged,
k_mppt_scale)` and asserts equality to machine precision.

### Step 3 — One tension definition

Use the `get_subsegment_tension` / `get_max_rope_tension` helpers from Step 2 as
the canonical tension (spring + damper, all sub-segments). Pure in `u`, so no
per-frame state persistence is needed here.
- `src/sim_frame.jl:219–236`: replace the chord-strain reconstruction with
  `get_max_rope_tension(u, sys, p)`.
- Delete the chord proxy in `src/visualization.jl:173–186` (the `_seg_T`
  closure) and have the tether-colour observables read `sim_frames_obs` instead,
  matching how `ring_beam_utils` is already wired (`src/visualization.jl:299–307`).
- Delete the single-sub-segment `_mid_t` in `src/simulation.jl:250–256` once no
  caller needs it.

Note the trade-off: the canonical tension now includes the damping term
`c_damp·vel_proj`, so displayed tension will show transient ripple the old chord
proxy smoothed away. This is correct (it is what the rope carries) but will look
different from historical screenshots — call it out in the changelog.

Acceptance: tether colour in the 3D view and `SimFrame.T_max` derive from the
same per-segment array; no formula for tension exists outside the rope-force
routine.

### Step 4 — Regression guard

Add `test/test_metric_consistency.jl`:
- Build one system, settle, run N steps capturing frames **with their latched
  state** (Step 0).
- Assert `SimFrame.P_kw` from `capture_frame` equals the ODE-applied
  `tau_gen·ω_gnd/1000` within tolerance, across several frames spanning normal
  operation, elev-derated, and brake-engaged regimes. The brake-engaged case is
  the key regression: it only passes if `brake_engaged` is fed per-frame rather
  than read from `sys`.
- Add a **playback** assertion: re-run `capture_frame` over the saved frames in
  order and confirm `P_kw`/`T_max` vary frame-to-frame (guards against the
  stale-`sys`-field freeze).
- Assert `SimFrame.T_max` equals `get_max_rope_tension(u, sys, p)`.
- Grep guard (CI script or test): fail if any file under `scripts/` contains
  `k_mppt *` followed by an `ω`/`om` cube outside `src/`. Prevents reintroducing
  inline power formulas.

Wire into `test/runtests.jl`. Keep the suite green (`julia --project=.
test/runtests.jl`, ~48 s).

---

## 4. Verification Before/After

Before starting, quantify the current gap so we can prove the fix:
- Run `scripts/power_curve_sweep.jl` and `scripts/interactive_dashboard.jl
  --headless --wind 11` on the same design; diff `P_kw` and `T_max`.
- Expect the largest divergence where `elev_scale < 1` (hub above design
  elevation), where active damping is on, and during brake engagement.

After Step 1, the same diff should be ~0. After Steps 2–3, the diff is 0 by
construction and the regression test enforces it.

---

## 5. Sequencing and Risk

- **Step 1** is low-risk and independently shippable — do it first; it resolves
  the user-facing symptom for steady-state runs immediately.
- **Step 0** is a prerequisite for *correct* playback of depower / stall / brake
  scenarios. If only Step 1 ships, those non-steady scenarios stay wrong; flag
  that limitation until Step 0 lands.
- **Steps 0 + 2 + 3** are the durable fix (one control law, one tension law, no
  stale state) and should land together with **Step 4** so the invariant is
  locked in.
- Risk: the stateless helpers run on the ODE hot path and must not allocate.
  Pass scalars/views, return scalars; no temporary arrays. Validate with
  `@allocated` in a test.
- Do **not** stash applied forces on a mutable `sys` field for `capture_frame`
  to read — it freezes during playback (see §2). Latched state travels with the
  saved frame instead.
- Out of scope: changing the physics itself. This plan only removes redundant
  re-computation; the `ring_forces.jl` / `rope_forces.jl` formulas are unchanged.
