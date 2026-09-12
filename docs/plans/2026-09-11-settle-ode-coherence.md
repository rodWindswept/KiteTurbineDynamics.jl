# Proposal — settle↔ODE coherence (no initial jerk)

**Status:** diagnosis complete, root cause measured, fix implemented in
`src/initialization.jl` and verified on the seed; fast suite green. One known
limitation open (§2.3). Rod's answers (2026-09-11): implement the closed-form
matched-place solve; accept the transmission shortening.
Date: 2026-09-11. Supersedes §2.16 + "fix option 3" of
`docs/plans/2026-09-10-shaft-windup-workstream.md`.

**Rod's directive (2026-09-10/11):** "the best approach is to match the settle to
the ODE — fix the settle's twist initialisation (no per-eval cost). Removes the
wind-up, not the wobble."

---

## 1. Root cause (measured, 2026-09-11) — it is the AXIAL PRELOAD, not frame softness

The settle **intends** a per-line tension of 283, 280, 278, 275, 234, 232, 267,
265 N (from `F_ax/n_lines`, `initialization.jl:966-1008`). It **achieves**
1947, 1946, 1945, 1944, 1538, 988, 740, 601 N.

The mechanism is a chord-geometry inconsistency, not a soft frame:

```
chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos Δα
```

The preload restore sets the **axial gap `L_ax`** for the *untwisted* line — a
strain of `F_ax/(n·EA) = 2.7e-4`. The twist bisection then adds `Δα`, and the
`cos Δα` term alone lengthens the chord. At the `Δα = 6.58°` the bisection lands
on, that twist-induced stretch is **1.6e-3 — six times the intended axial
preload**. The bisection therefore sees a segment ~7× too stiff in torsion and
converges to `6.58°/segment` instead of the running `48.8°`.

Verified numerically (`scratch/r7_preload_audit.jl`):

| segment | intended T/line | achieved T/line | ratio |
|---|---|---|---|
| 1–4 | 283 / 280 / 278 / 275 | 1947 / 1946 / 1945 / 1944 | **6.9–7.1×** |
| 5 | 234 | 1538 | 6.6× |
| 6 | 232 | 988 | 4.3× |
| 7–8 | 267 / 265 | 740 / 601 | 2.8 / 2.3× |

(the ratio falls with segment length because the twist-induced chord growth is
absolute, not relative — the top segments have 4.8 m gaps, the bottom 1.17 m.)

### 1.1 The settle and the run differ ONLY in tension

`scratch/r7_tension_settle_vs_run.jl`, 5 kW / 18.8 m seed, k = 2.24, ω = 12.98:

| | settle (t=0) | run (t=20 s) | ratio |
|---|---|---|---|
| per-segment line tension (N) | 1947…601 | 301…208 | **6.5× / 2.9×** |
| first-segment twist | 6.58° | 48.85° | **7.4×** |
| cumulative Δα | 42.5° | 263.7° (294° at 60 s) | 6.2× |
| transmitted torque `τ_seg` | 188,188,188,188,292,595,652,447 | 188,188,188,188,292,596,667,597 | **1.00×** |
| ring lateral offsets | 0.000 m | 0.002–0.032 m | — |

Torque identical, twist 7× different, chord 1.6 % different, lateral motion
negligible. For `τ ≈ n·T·r²·sin(Δα)/chord`, a 6.5× tension ratio *is* a 7× twist
ratio. Nothing else is needed to explain it.

**This supersedes §2.16 of the workstream doc**, which attributed the gap to a
"~270× torsionally softer" frame whose rings move laterally to hold the chord
(0.49 m hub lateral). In the measured run here the lateral offsets are 0.01–0.03 m;
the ring motion that matters is **axial** — the shaft shortens as it winds up.

### 1.2 Why this produces the wind-up

The ODE starts from the over-tensioned state, immediately relieves the
twist-induced strain by shortening the shaft axially, tension falls to ~300 N,
and since the transmitted torque is fixed the twist must grow
(`τ = n·T·r²·sin Δα/chord`). That relaxation *is* the ~100 s wind-up, and the
honest 40 s window sits inside it.

### 1.3 Is `1.6e-3` a magic number from another design? No — and the new design would repeat the bug

Rod's question (2026-09-11): where did the 1.6e-3 strain come from, and would a
new design settle make the same mistake?

It is **not a stored constant and not inherited from another system.** It is
`2·r̄²·(1 − cos Δα) / chord0²` evaluated at whatever `Δα` the old bisection
converges to. The old bisection makes tension a *function of* twist
(`T = EA·(chord(Δα) − chord0)/chord0`), so twisting is **self-limiting**: more
twist → longer chord → more tension → more torque, and it stops early. The ODE
instead lets the axial gap shrink so the chord stays at `chord0` and `T` stays at
the preload — so it must twist much further for the same torque.

So the old initialiser is wrong exactly when

```
2·(r̄/chord0)²·(1 − cos Δα)   ≳   T / EA          (twist strain ≳ preload strain)
```

which, for a stiff line at a small design preload, is the **normal** regime — the
design preload here is 2.7e-4 (0.3 mm on a 1.17 m segment) against a twist term
`O((r̄/chord0)²)`. The magnitude of the error is design-dependent (it grows with
radial spread and required torque, and shrinks with `EA`), but the
**inconsistency is structural**: any design whose preload strain is small next to
its twist geometry will reproduce it exactly.

Two consequences for the fix:

1. It is removed **categorically**, not tuned, because the new solve *prescribes*
   the tension (`T_s = F_ax/n_lines`) and derives the geometry from it, instead of
   deriving tension from the twist.
2. It needs a **guard**, not just a fix: the fast test must assert
   `achieved T ≈ F_ax/n_lines` for **more than one geometry**, so a future design
   cannot silently re-enter the inconsistent regime.

## 2. The fix — solve twist and axial gap together, in closed form

Per segment, solve for the pair `(Δα, L_ax)` such that

```
(i)   chord = chord0 · (1 + T_s / EA_single)          [line tension = intended preload]
(ii)  n · T_s · r_a · r_b · sin(Δα) / chord = τ_s     [segment torque balance]
```

with `T_s = F_ax[s]/n_lines` (the preload the initialiser already computes) and
`chord = √(L_ax² + r_a² + r_b² − 2 r_a r_b cos Δα)`. Both equations are closed
form: `sin Δα` from (ii), then `L_ax` from (i). Ring centres accumulate by
`L_ax·shaft_dir`; rope nodes are re-interpolated along the chord; `α` accumulates.

**Cost:** arithmetic on `Nr − 1` segments. No Newton, no ODE calls, no per-eval
cost — exactly the property Rod asked for. It *replaces* the pinned
`preload_ring_pos` restore and the separate twist bisection rather than adding to
them, so it should be **faster** than today.

Worked example, segment 1: `T = 283 N`, `chord0 = 1.1708 → chord = 1.1711`,
`τ = τ_gen = 377.6 N·m` → `sin Δα = 0.788` → **`Δα = 52.0°`** (running: 48.85°),
and `L_ax = 1.1708 → 1.0570`. The predicted first-segment twist lands on the
running value directly.

### 2.1 Verification — PASSED (2026-09-11)

`scratch/r7_settle_chord_fix.jl` applies the matched-place initial state to the
seed and runs 60 s (`lin_damp = 0.05`, `dt = 2.04e-5`), reporting every 10 s:

| | today's settle | matched-place, t=0 | matched-place, 60 s |
|---|---|---|---|
| first-segment twist | 6.58° | **51.94°** | 56.91° |
| cumulative Δα | 42.5° | **283.6°** | 300.8° |
| per-segment tension (N) | 1947…601 | **283…265** (= the design preload) | 272…204 |

**The wind-up is gone.** Today the first ~100 s is a 6.6 → 48.9 → 55.5° climb
(cumulative 42.5 → 294°); with the fix the state starts at 51.9° / 283.6° and
drifts ~6 % over 60 s to 56.9° / 300.8°, then flat. The t=0 tension is exactly
the `F_ax/n_lines` the initialiser always intended.

Cost: `Nr − 1` segments of closed-form arithmetic — **cheaper than what it
replaces**, and no ODE calls, so no per-eval cost. The transmission **tube**
comes out **0.63 m shorter** (18.805 → 18.173 m over 8 segments). Rod's
correction (2026-09-11): this is *not* the tether line shortening — it is the
transmission axis shortening under torsional deformation, as the collection of
tethers wraps around the perimeter of the axis. The effective tube shortens with
the torque/tension balance, and that is accepted. (See open question 1.)

### 2.3 Implemented — and the one open limitation

Shipped in `src/initialization.jl`:

- `design_axial_preload(sys, p, lift_device)` — extracts the intended preload
  `F_ax` so it is testable (exported).
- `_matched_place_twist(...)` — the closed-form `(Δα, L_ax)` solve.
- `settle_to_operational_state` calls it in the lift path; the legacy
  torque-chain bisection is retained unchanged for the `lift_device === nothing`
  path (control-map / calibration scripts and several tests use that path).
- Rope-node interpolation moved out of the bisection so both paths share it.
- `test/test_settle_preload_consistency.jl` — fast guard: the settled line
  tension must equal `F_ax/n_lines` (within 15 %) and the first segment must be
  past 30°, checked on the campaign seed and a 3-rotor geometry.

**Known limitation (open).** `_matched_place_twist` uses the law of cosines for a
ring plane **perpendicular** to the shaft axis. The ODE's real attachment planes
are tilted by `_tilted_ring_basis` (driven by the bearing offset). The tilt shifts
the chord by ~0.1 mm, which is small absolutely but large next to the ~0.3 mm
intended preload strain — so where the settled tilt is significant the achieved
tension runs ~35 % high. A 14-segment constant-radius test geometry trips it; the
campaign seed and a 3-rotor geometry do not (both exact). **The twist, and
therefore the wind-up fix, is unaffected**, because `Δα` does not depend on `L_ax`.

Two attempted corrections both failed and are recorded so they are not retried:
a second pass after the operational settle using the settled tilt basis (produced
oscillating tensions, 2.3× error), and — for the same reason — a bisection on the
exact chord (the tilt makes the chord non-monotone in `L_ax`; a closed-form
quadratic solve showed the same bad result, so the error is elsewhere in that
approach and it needs a proper debug, not a patch). This is the next task.

### 2.4 OPEN — the axial preload FORMULA is not validated (Rod, 2026-09-11)

`design_axial_preload` was lifted **verbatim** out of the old initialiser, so the
fix inherited its formula. Rod flagged the reasoning, and the model confirms he is
right:

```julia
thrust   = 0.5*ρ*v_ref^2*π*R^2*0.8*cos(β)^2      # already the AXIAL thrust
F_aero_z = thrust*sin(β) - W                      # treats it as horizontal
F_top    = F_aero_z/sin(β) + T_cyan               # = thrust - W/sin(β) + T_cyan
```

- The ODE applies the thrust **along the shaft axis**:
  `ring_forces.jl:215` does `forces[hub_gid] .+= thrust_mag .* tether_dir` where
  `tether_dir = normalize(hub − ground)`. The disc plane is perpendicular to the
  shaft, so that is correct, and `cos²β` at `:208` is the normal-wind projection.
- So the `·sin(β)` then `/sin(β)` round-trip is **numerically neutral** (it returns
  `thrust`) but the *reasoning* is wrong.
- The weight term is **not** neutral: `−W/sin(β)` resolves a *vertical* load
  axially, where the true axial component of gravity is `−W·sin(β)`. At β = 30°
  that is −384 N vs −96 N; at β = 70°, −1.06 W vs −0.94 W. Mixing the two
  resolutions in one expression is what will break on a new design, and the sign
  (weight *reducing* shaft tension) silently assumes the lift kite carries the
  weight.

**The recent work does not invalidate this** — and the new guard does not cover it:
`test_settle_preload_consistency.jl` asserts `achieved tension == F_ax/n_lines`,
which is a **self-consistency** guard, not a correctness one. It would pass with a
wrong `F_ax`.

**The gap is already measurable.** Post-fix, the ODE settles to 301 → 208 N/line
(bottom → top) while the formula prescribes 283 → 265 N/line. The residual ~8 %
twist drift (277.4° → 299.7° over 60 s) is consistent with the ODE still relaxing
the part of the preload the formula gets wrong — so this is on the critical path,
not cosmetic. Unseparated: how much of the gap is the direction/resolution error
vs the crude constants (`0.8` instead of `ct_at_tsr(λ)`, `rotor.wind_factor`, and
`v_wind_ref` instead of hub-height wind).

**Proposed correction (Rod approved 2026-09-11: this is the next task).** Stop
hand-rolling `F_top`. Make it a property of the kernel by closing a scalar fixed
point on the ODE's own hub force balance. Spec:

```julia
# src/initialization.jl
function design_axial_preload(sys, p, lift_device)   # signature unchanged
    lift_device === nothing && return Float64[]
    n_seg = sys.n_ring - 1
    T_top = _preload_first_guess(sys, p, lift_device)   # the OLD formula, demoted to a start value
    sd    = design shaft unit vector [cos β, 0, sin β]
    hub   = sys.rotor.node_id ;  m_hub = (sys.nodes[hub]::RingNode).mass
    for _ in 1:20
        F_ax = _axial_profile(sys, p, T_top)            # F_ax[n_seg]=T_top, add ring weight downward
        u    = _place_for_preload(sys, p, F_ax, lift_device)   # _matched_place_twist + rope interpolation
        du   = ODE-residual at u with the running velocity field (ring ω = ω_eq, rope nodes orbital)
        a_ax = dot(du[3N + 3*(hub-1) + 1 : 3N + 3*hub], sd)
        # The rope hangs below the hub and pulls it DOWN-shaft.  A hub accelerating
        # UP-shaft (a_ax > 0) means that pull is too SMALL, so T_top is too LOW.
        T_top += 0.7 * m_hub * a_ax
        abs(m_hub * a_ax) < 1e-2 && break
    end
    return _axial_profile(sys, p, T_top)
end
```

Notes and traps:
- **Sign** (corrected 2026-09-12; the earlier version of this note was inverted and
  diverged): the rope hangs below the hub and its tension pulls the hub
  **down**-shaft. A hub accelerating **up**-shaft (`a_ax > 0`) therefore means that
  pull is too small, so `T_top` is too **low** and must **increase**:
  `T_top += 0.7 * m_hub * a_ax`.
- **Gain and convergence, measured** (`scratch/preload_kernel_probe.log`, ±1 N scan at
  `T₀ = 1588.735`): `f(1587.735) = −478.674`, `f(1588.735) = −479.747`,
  `f(1589.735) = −480.819`, so `df/dT = −1.073`. Newton is `T ← T − f/(df/dT)`, i.e.
  `T + 0.932·f`; the 0.7 is a deliberate under-relaxation. Per-iteration error
  contraction is `1 − 0.7·1.073 = 0.249`; measured 0.232 / 0.204 / 0.197.
- **The probe did not converge.** `preload_kernel_probe.jl` hard-codes `for it in 1:4`,
  so it stopped at `T_top = 1158.97 N` with residual `−4.47 N`, still above the `1e-2`
  tolerance. Extrapolating at 0.21 puts the fixed point near **1155 N** in ~8
  iterations. Do not treat 1158.97 as converged.
- `_place_for_preload` must reuse `_matched_place_twist` so the geometry stays
  consistent with the twist solve; the rope nodes only need interpolation good
  enough for a force estimate (the final settle re-interpolates them anyway).
- **This is not circular**: `T_top` is set by aero + gravity + lift/bridle, not by
  the twist, so evaluating the balance at a trial geometry is legitimate.
- **Fallback**: if the fixed point does not converge, *do not* silently return the
  old formula — return `nothing`/throw and record it, so a design that defeats the
  derivation is visible rather than papered over.
- `_preload_first_guess` keeps the old expression **only** as an initial value, so
  the two can be compared directly and the difference quantified (this is the
  measurement that says how wrong the old formula was, and by how much the loads
  move).
- Validate across a **β sweep (30 / 45 / 60 / 70°)** and at least two ring counts,
  and assert the kernel-derived `F_ax` reproduces the ODE's measured segment
  tensions at the settled state — a correctness guard, complementing the existing
  self-consistency guard in `test_settle_preload_consistency.jl`.

**Then, in this order** (Rod 2026-09-11): re-derive loads → re-check
`SIZING_FOS_MARGIN` and the seed's structural margin → re-check the window, and
only then re-baseline anything. The FoS shortfall (§5) is the real blocker, not a
test artefact.

#### 2.4.1 BLOCKER found before implementation (2026-09-12) — the derived preload is not realisable

The fixed point above was implemented as the scratch probe
`scratch/preload_equilibrium_exists.jl` before any change to `src/`, and it does
**not** solve. Two independent constraints have no overlap at the campaign seed:

1. **Axial equilibrium** (the fixed point's own target). The hub axial residual is
   monotone and near-linear in `T_top` (slope ≈ −1.1). The corrected-sign
   iteration `T_top += 0.7·m_hub·a_ax` converges to
   **`T_top = 1155.09 N`** (residual −0.0065 N, 8 iterations, per-iteration
   contraction 0.1949).
2. **Geometric realisability.** The closed form needs `sin(Δα) ≤ 1`, i.e. a
   **per-segment tension floor**

   ```
   T_s ≥ τ · chord / (n_lines · r_a · r_b).
   ```

   At the seed (τ = 377.598 N·m, n_lines = 6) segments 1–4 (the constant-radius
   lower transmission, r_a = r_b = 0.57511 m) each need `T_s ≥ 222.82 N/line`.
   Expressed as a top tension on the design profile
   `F_ax[s] = T_top + (n_seg − s)·15.613 N`, the **binding segment is 4**:
   **`T_top ≥ 1274.47 N`**. Segment 1 needs only 1227.63 N because it carries less
   accumulated ring weight above it. The design's own first guess, 1588.73 N,
   clears the floor (worst `sin(Δα)` = 0.8097).

The equilibrium demand (1155.1 N) is **119.9 N below** the realisability floor
(1274.5 N). At the floor the hub still carries **−135.9 N** of excess tension. So
the preload the hub wants cannot be built, and the preload that can be built leaves
the hub out of balance. At `T_top = 1274.5 N` segment 4 sits at `Δα = 90°` exactly
— the boundary of the torque the lower transmission can carry.

**Consequence: do not implement §2.4 as written.** It converges (item 1's
corrected sign is verified) but the converged value silently saturates segments
1–4 at the `asin` ceiling, because `_matched_place_twist` does
`asin(clamp(sinΔα, -1, 1))` and returns **90° with no error** when `sinΔα > 1`.
That is a second silent-truncation defect of exactly the class §5 item 1 targets —
and it is the more dangerous one, because it produces a plausible-looking
geometry whose twist is wrong.

**The open question is not the formula, it is the sizing.** The lower transmission
(six segments at r = 0.57511 m) cannot carry τ = 377.598 N·m at the tension the hub
equilibrium requires. A larger attachment radius helps directly
(`τ_max = n_lines·T_s·r_a·r_b/chord` at `sin Δα = 1`), as would more lines or lower
k_mppt. This is a closed-form sizing criterion that belongs alongside the
`SIZING_FOS_MARGIN` re-derivation, and it should be added to the R7 beam sizing as
a **torsional realisability** check.

Evidence: `scratch/preload_equilibrium_exists.jl` (the sweep),
`scratch/preload_fixedpoint_conv.jl` (corrected-sign convergence + asin audit),
`scratch/preload_alpha_reconcile.jl` (the three disagreeing twist numbers),
`scratch/preload_settle_chain.jl` (the airborne assembly's state).

### 2.5 Rejected approaches (tested, do not retry)

- **Full-state damped Newton on the ODE residual** (`scratch/r7_settle_newton.jl`).
  Force residual improved 2.6e3 → 32 N, but the ring torque residual got *worse*
  (87 → 225 N·m) and λ ran away to 1e11: the step walks the tension structure
  into a slack configuration (bottom-segment transmitted torque 188 → 64 N·m).
- **Staged positions-Newton + triangular twist bisection**
  (`scratch/r7_settle_staged.jl`). Diverges: per-segment twist reaches 751°, ring
  lateral offsets 0.89 m, tension 88 kN. The 1-D bisection has no reliable bracket
  once the rings move under it.
- **Just unpin the rings and run the existing dynamic loop** (round 5, 2026-09-10).
  Steady 74.2° with an unphysical distribution (0.4° on the loaded transmission
  rings, 35–37° on the lightly loaded top) — `dt²·(F/m)` drift, which is what the
  pin exists to prevent.

The lesson from all three: the coupling that matters here is *axial geometry ↔
twist within one segment*, not a global free-state equilibrium. Solving it
locally, in closed form, is both cheaper and more robust.

## 3. Scope and non-goals

- **In scope:** the start state of `settle_to_operational_state` (preload restore
  + twist initialisation), for both the pinned and unpinned paths.
- **Not in scope:** the wobble mode and its damping (Rod's directive: "removes the
  wind-up, not the wobble"); the `lin_damp` remediation; line resolution;
  `relax_s`; the tether-drag factor (separate change,
  `docs/plans/2026-09-11-tether-drag-validation.md`).
- The `τ_s` chain must keep the existing expansion-rotor torque-injection
  handling (`initialization.jl:1155-1180`); the new solve replaces only the
  geometry, not the chain propagation.

## 4. Acceptance criteria

5 kW / 18.8 m seed, `k = 2.24`, honest 40 s window at `dt = 2.04e-5`:

| # | Check | Today | Target | Prototype |
|---|---|---|---|---|
| **S1** | per-segment line tension at `t=0` | 1947…601 N | within 15 % of the intended `F_ax/n_lines` (283…265 N) | **PASS** |
| **S2** | first-segment twist at `t=0` | 6.58° | within 10 % of the running 48.9° | **PASS** (51.9°) |
| **S3** | **no wind-up**: cumulative Δα over 40 s | 42.5° → 287° | `|Δα(40 s) − Δα(0)| / Δα(0) < 0.10` | **PASS** (6.3 %) |
| **S4** | first-frame node force residual, `max‖F‖` | 3.05e3 N | **< 50 N** | 574 N (5.3× better, target not met) |
| **S5** | first-frame ring torque residual, `max|τ|` | 87.3 N·m | **< 5 N·m** | 73.8 N·m |
| **S6** | windowed `P_mean` preserved | 5.1 kW | within 5 % | not yet measured |
| **S7** | cost | 32.3 s settle | ≤ today | 34.1 s (≈ equal; ±run noise) |
| **S8** | regressions | green | fast suite (42 files) green; acceptance (8 files) green | fast suite green; acceptance not yet run |

S1–S5 are cheap and can gate a fast test; S3/S6 need the acceptance window.
`scratch/r7_settle_residual.jl` measures S4/S5 as a one-call probe.

## 5. Acceptance run (2026-09-11) — diagnosed: one stale pin, two real FoS findings

Full diagnosis: `docs/plans/2026-09-11-settle-fix-acceptance-reds.md`.
`test/acceptance_runtests.jl` with the fix in the tree: `PASS` evaluator_v13,
rope_break, rotor_power_realism, settle_drag_alignment, jtheta_no_reversal;
`FAIL` gate_v13, settle_lowk_honest, physics_path_ode. Verdicts:

| test | verdict | detail |
|---|---|---|
| `gate_v13` A5 | **stale trigger** | `ROPE_BREAK_STRAIN = 0.035` (`src/rope_forces.jl:31`, applied `:370-377`) is a material strain limit, tension-independent, so it is still physically sound at 283 N (healthy strain 2.7e-4). The fixture's thin line (`test/test_gate_v13.jl:82`, d = 0.00025 → scaled 0.000456) had a design preload strain of 1.73 %, which only crossed 3.5 % because of the twist-inflated preload. With the wind-up gone it no longer breaks. Re-baseline d → 0.00020 (verified: `line_broken=true`, `ok=false`, P 10.32 kW, ω 16.64, clearance 2.89 — all three A5 checks pass). Cleaner fixture: lower `e_modulus` instead, so the break does not happen during the settle. |
| `settle_lowk_honest` A3 | **stale test config hiding a REAL defect** | `seed_genome_x()` (`test/test_settle_lowk_honest.jl:53-54`) applies **legacy 14-D clamps `xr[8]`, `xr[10]` to the canonical 10-D genome**, so `bank_bottom` 0 → 3 and `blade_scale_bottom` 0.7 → 1.0. That over-loaded genome settles at twist ratios 1.06–1.16 → twist collapse → the sentinel at `src/objective_evaluator.jl:790-793` **zeroes `P_mean`/`P_end`/`FoS`**, which is why `P_end = 0.0` and why `FoS_min = Inf` made the `FoS > 2.5` check pass spuriously. Fix the indices to `xr[4]`/`xr[6]` (as in `test/test_settle_preload_consistency.jl`). Do **not** re-baseline `P_end`. |
| `physics_path_ode` P1 | **REAL regression (FoS)** | `status=reject`, `fitness=Inf`, `P_mean=P_end=5.1390 kW`, `FoS_min=2.3139`, `twist_crossed=false`. Reject is **purely FoS** (`objective_v12.jl:149` returns `Inf` for `FoS_min < fos_hard = 2.5`); power and twist are healthy. The recorded pre-change 2.78 (`:ok`, 5 s window) was **inflated by the under-twisted start state**. P1's `CFG` also omits `tether_diameter`, building 0.003 vs the campaign 0.003651 (rope self-weight feeds the beam load, `src/trpt_optimization.jl:443`). With the campaign tether: FoS 1.8332 (5 s) and 1.3112 (20 s). |

**Headline.** The corrected state does **not** stall — P1 makes 5.139 kW at
`twist_crossed=false`. What the old under-twisted start was hiding is a **real
structural shortfall**: FoS 1.31–2.31 against the 2.5 floor, in every window
measured. Since the R7 window they were calibrated on was itself an artefact,
`SIZING_FOS_MARGIN` and the seed's structural margin need re-checking — and they
need re-checking **after** the preload formula is corrected (§2.4), because that
formula sets the loads the margin is measured against. Do not re-baseline either
red to a passing status: that would pin a real safety signal.

Also not run: JuliaFormatter (not present in the project environment).

## 6. Why now — the campaign evidence

The R7 re-baseline campaign (`--tag r7rebase`, 3 islands × 20, `853d551`)
returned **zero valid genomes**. Statuses: 52 `reject`, 5 `reject_twist`,
3 `clearance_reject`, 0 `ok`. The seed itself produces 5.1 kW but **FoS 1.63** —
the wind-up/wobble trough. Best FoS seen 4.80 (3.7 kW, rejected on power).
Nothing in the design space clears the windowed FoS gate while the start state is
7× under-twisted.

## 6. Proposed commit sequence

1. `test: settle preload/twist consistency` — a fast test asserting S1 and S2 on
   the seed (fails today: tension 6.9× high, twist 7× low). No behaviour change.
2. `fix(init): solve twist and axial gap together in the settle` — the closed-form
   matched-place solve; S1–S5 + S7 green, fast suite green.
3. Acceptance run for S3/S6, then `--tag r7rebase` re-run and compare against §5.
4. **Separately**, `fix(physics): tether drag factor 0.5 → validated value`,
   with its own acceptance run.

## 7. Open questions for Rod

1. The corrected solve makes the settle's geometry **shorter** than today's
   (segment 1 `L_ax` 1.1708 → 1.0570; ≈0.9 m over 8 segments). That changes the
   hub/bearing/sky-anchor positions the operational settle finds. Accept the
   shaft-length change, or anchor it (e.g. keep the hub at its settled position
   and take the shortening out of the top segment)?
2. S1's 15 % tension tolerance — is that the right band, given the analytic
   preload and the measured run agree to ~15 %?
3. Should the drag-factor change stay a separate commit (I recommend yes; the
   settle fix will already move every FoS number)?
