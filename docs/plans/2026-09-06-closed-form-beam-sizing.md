# Closed-form TRPT beam dimensioning (2026-09-06) — REV 2

Status: **proposal — do not implement yet.** Companion prototypes:
`scratch/verify_minwall.jl`, `scratch/beam_sizing_proto.jl`.

---

## Revision 2 note — what changed and why

REV 1 was reviewed externally. Eight findings, all **code-verified**, are
incorporated below. The ones that invalidate REV 1 claims:

| # | REV 1 said | Corrected |
|---|---|---|
| 1 | load = `DLF × T_line`, sizing case = "wind/CT" | DLF is a wind-dependent empirical ratio, not a load law; sizing state = **`(Q_max, T_min)`** (torque-helix physics) |
| 2 | §5 "`t = tube_wall_thickness` single authority" | closed form actually uses `strut_properties` with **0.5 mm wall + pin-pin**; FEA uses **2 mm + fixed-fixed** — two capacity models |
| 3 | §4 "FoS ≥ floor by construction" | false — Euler-only ignores bending; must use `beam_column_utilisation` |
| 4 | "Path A already multi-rotor aware" | orientation bug (`radii[1]` ground vs hub) inverts stacked-rotor tension |
| 5 | "tension fixed once rotors sized" | two paths use different thrust sources (freestream+CT=0.55 vs shear+BEM, lifter tension absent) |
| 6 | (missed) | **hub ring is checked by nobody** — both paths skip it |
| 7 | §5 taper `Do ∝ r^½` | circular (assumes `t∝Do`; with 2 mm wall pinned it's `r^(2/3)`, and the 0.49 came from the same DLF model) |
| 8 | (missed) | `segment_inward_force` is dead; impl uses unsigned `DLF×T`, losing signed kink (outward/tension) physics |

**Adopted architecture (from the review):** keep "rotor genes → derived beams →
one-time FEA", but (a) fix orientation, (b) define the load in `(Q_max, T_min)`
with the helix angle solved closed-form + signed kink terms + blade-centrifugal
relief, (c) feed those vertex forces into the **same** beam-column utilisation
the FEA uses with a **single K**, (d) add the hub ring at `(T_peak, ω=0)`.

**Verification status.** Items 2–6 and 8 are verified against source (citations
below). Item 1 is now **measured** (see §10): effective DLF ≈ 0.18, closed-form
DLF=1.2 over-counts ≈ 6.7×. Item 3 is **partially corrected**: settled-state
bending is ≈ 0 (100 % axial), so Euler-only sizing is adequate for the settled
state, but a gust/asymmetric case still needs a bending check. Item 7 and the
hub-ring numbers (§6 comment) remain to be re-derived.

---

## 1. Executive summary

The v13 campaign treats the beam cross-section (`Do_top`, `t_over_D`,
`beam_aspect`, `Do_scale_exp`) as **free DE genes**, and validates each
candidate with the full frame FEA inside a **50 s ODE window**. That is slow,
and it let the winner land on a **6.2 mm-OD transmission ring at true FoS ≈ 1.2**
(§3). The beam cross-section is **load-derived** — once the rotors are sized the
thrust/torque/tension are fixed, and the beam follows from a buckling/bending
requirement.

The proposal: **size beams closed-form from the rotor stack, and remove the free
beam genes + per-eval FEA from the v13 evaluator.** This must preserve the
rotor-count question as a live search axis — the beams are a *function* of the
stack, not an assumption about it.

---

## 2. Why we do it the way we do (two parallel paths that are really two machines)

### Path A — closed-form (`_evaluate_trpt_design_impl`, `evaluate_design`)
- Load: `F_in = DLF(1.2) × T_line`, tension from `peak_hub_thrust` at **peak
  25 m/s**, `CT = 1.0`.
- Capacity: `strut_properties(..., PinPinEnds)`, wall floored at
  `OPT_T_MIN_WALL = 0.5 mm` (`spacer_ring_design.jl:98,110,129`) — **not**
  `tube_wall_thickness`.
- Geometry: `ring_spacing_v4` full cone.
- Orientation: `ring_radii` is ground-first (`trpt_optimization.jl:219-224`),
  but the impl comment claims "`radii[1]=hub`" (`:403-406`) and
  `objective_v10.jl:479` places `thrust_per_ring[1]` at the ground ring —
  **inverted for stacked rotors**.

### Path B — v13 FEA (`evaluate_windowed` → `ring_element_analysis`)
- Load: actual ODE vertex forces (`extract_vertex_forces`), at **rated 11 m/s**,
  wind shear `(z/h_ref)^(1/7)`, BEM CT, blade_scale, and **lifter tension**.
- Capacity: `strut_properties(..., FixedFixedEnds)`, wall via
  `tube_wall_thickness` (**2 mm** floor after the alignment change).
- Geometry: `ring_spacing_v5` three-section.
- FoS: `beam_column_utilisation` = `1/(N/N_crit + √(M_ip²+M_oop²)/M_el)`
  (`ring_element_analysis.jl:294`) — **includes bending**.
- Skips ground **and hub** rings: `ring_ids[2:end-1]` (`:655`).

### The three (now four) disagreements

| axis | Path A | Path B |
|---|---|---|
| geometry | v4 full cone | v5 three-section |
| load case | peak 25 m/s, CT=1.0, DLF=1.2 | rated 11 m/s, BEM CT |
| load model | `DLF × T` (tension only, unsigned) | actual forces (torque + taper + lift) |
| capacity | pin-pin, 0.5 mm wall, Euler-only | fixed-fixed, 2 mm wall, bending-inclusive |

**Consequence:** the two paths size different machines against different winds
*and* different capacity models. The closed form's pin-pin/0.5 mm is ~4× weaker
per unit wall and ~4× weaker on K than the FEA's fixed-fixed/2 mm — a ~16×
capacity gap before the load is even considered. (Reviewer cited ~6.9×; our
spot-check puts the wall factor at ~4×, so the gap is at least as large.)

---

## 3. The finding that triggered this

Aligning the FoS wall floor to the mass model removed the old `5e-4/t_over_D`
OD floor, which had inflated the winner's 6.2 mm transmission rings to a
fictitious 18 mm and produced the "FoS 17.2" the 2026-09-02 plan cited as
"over-conservative".

Corrected (both at rated 11 m/s, single-K-normalised is §6):

| model | load | min ring FoS | transmission-ring OD |
|---|---|---|---|
| FEA (aligned) | rated | **≈ 1.2** | 6.2 mm |
| closed-form (own capacity) | rated | **≈ 0.02** | 6.2 mm |

(The 60× spread is ~7× load + 4× K + 4× wall.) **The winner is under-strength,
not over-strength.** "Shed structure" (2026-09-02 plan §2) is inverted.

---

## 4. The proposal (REV 2)

1. Keep **rotor** genes only: `r_hub`, `n_lines`, blade spans/`λ`, rotor count
   `x10`, banks.
2. After decoding the rotor stack, compute per-ring **vertex forces** closed-form
   (§5), on the **v5 geometry**, with **fixed orientation**.
3. **Solve each ring's `Do`** so the *same* beam-column utilisation the FEA uses
   meets the FoS floor (§6) — bisection, monotone in `Do`.
4. Mass = `ring_beam_mass` + knuckles from the solved sections.
5. Keep the FEA (`ring_element_analysis`) as a **one-time verification on the
   winner**, not a per-eval cost.

Net: ~10-D genome, no per-eval ODE structural loop, no OD floor, and the FoS
floor is met by the *same* utilisation criterion used for verification.

### Rotor count stays a live axis

`x10` (rotor count) and the rotor geometry stay in the genome. The per-ring
vertex forces are a function of the stack (per-rotor thrust → torque/tension →
kink+helix), so a 1-rotor vs 3-rotor machine of the same power gets **different**
beam sections. The proposal assumes no rotor count.

---

## 5. Load model (REV 2 — replaces "DLF × T")

Per ring, the net inward vertex force is the **signed** sum of three terms:

```
F_v = F_kink + F_helix − F_centrifugal
```

1. **Kink (taper transition), signed.** From the line changing radius between
   adjacent segments. Inward where the line above leans inward; **outward** at
   a cylinder→cone transition (the beam then sees tension, not compression).
   This is the signed physics of the currently-dead `segment_inward_force`
   (`trpt_optimization.jl:279`); it must be revived and used, not the unsigned
   `DLF × T` at `:486`.

2. **Torque helix.** Twist of the shaft by the transmitted torque `Q` leans the
   lines, giving (small-angle) an inward force that **falls with tension**:
   `F_helix ≈ Q²·ℓ/(n²·T·r³)`. **Sizing state is therefore `(Q_max, T_min)`** —
   rated/fault torque at minimum tension (lifter dropping, a lull, a generator
   load step) — not "peak wind". Peak wind (high T, capped Q) is the benign case
   for transmission rings. *(Coefficient to be re-derived; consistent with the
   code's `τ_cap = T·r²/√(L²+2r²)` torsional criterion.)*

3. **Blade centrifugal relief (outward).** `F_cf = m_vertex·ω²·r`, largest at the
   hub ring; zero in stall/haul-down (`ω→0`).

### 5.1 Finding `(Q_max, T_min)` — the method

`(Q_max, T_min)` is **not a steady MPPT operating point and not a free (Q, T)
choice**. Under the speed-derived law `τ_gen = k_mppt·ω²`, steady torque
`Q ∝ ω² ∝ v²` and steady line tension `T ∝ thrust ∝ v²·Ct` are **coupled through
the wind** — they move together, so no steady state has Q max while T is min.
The sizing state is a **transient (or feathered-steady) state**, found by
simulation, not by specifying (Q, T) analytically.

**Method (reuses the 2026-04-20 DLF calibration, but tracks (Q, T) directly):**

1. Enumerate candidate fault/transient scenarios (from `calibrate_dlf.jl` +
   the soft-ramp shutdown): wind lull (T drops, Q lags on rotor inertia),
   generator load step (Q spikes), coherent gust, lifter drop, and high-wind
   feather (steady `Q = Q_rated` at minimum thrust). The 3×k emergency brake is
   **excluded** (operational decision — no k_mppt steps reach the airframe).
2. **Settle first, then fault.** For each scenario:
   a. `settle_to_operational_state` to rated (11 m/s) with the mass-aware
      lifter, `ω_rated_max = 60`, `n_op = 30_000`, stable `dt` (the
      `ode_gate_v13.jl` recipe);
   b. **relax 2 × 5 s** to flush the settle→run transient (the 2026-09-04
      false-rope-break lesson) — this is a numerical artifact and is **excluded
      from the max**;
   c. record the settled baseline `(Q, T)`;
   d. **apply the fault** (wind step, k_mppt step, gust, lifter drop, or the
      feather ramp) and run the transient.

   Startup must not leak into the fault record: the load step is a step on
   `sys.k_mppt_ref[]` from the settled load, and the high-wind-feather scenario
   is a *ramp* to over-rated wind with pitch depower engaged (not a settle-then-
   step) — it cannot reuse the plain rated settle.
3. Track `(Q, T)` per step from `capture_extended`'s existing `segment_torque`
   and `segment_tension` exports.
4. Compute `F_helix(t) = 2·T·r·(1−cos φ)/ℓ` (`sin φ = Q·ℓ/(T_total·r²)`) and
   take the **max over all scenarios**; report the (Q, T) at that instant with
   the scenario that produced it.

**Tension floor.** `T_min` is not zero — the mass-aware constant-tension lifter
keeps the lines at `~T_lift/n_lines` at zero thrust (measured `T_line ≈ 710 N`
at rated). This bounds the "lull" case.

**Gap to close.** The v13 evaluator runs fixed 11 m/s with no feathering, and —
more fundamentally — the ODE aero (`ring_forces.jl`) computes thrust/power from
`ct_at_tsr(λ)`/`cp_at_tsr(λ)` with **no blade-pitch or feather term**, so
"feather above rated" is not representable without a model change (a feather
factor that reduces the rotor's effective wind/Cp/Ct above rated). Easing
`k_mppt` is the wrong substitute (it spins the rotor up, `scratch/scenario_sweep.jl`).
Until that factor exists, the high-wind structural case is un-modelled; the
defensible sizing case is the **generator load step**.

**Chicken-and-egg.** Beam mass feeds the dynamics. Resolve by one fixed-point
iteration (size → run scenarios → re-size), or for the first cut size with
`Q_max = Q_rated·(1 + load-step factor)` and `T_min = T_lifter/n_lines`, then
confirm with the sweep.

### The hub ring is a first-class load case

Both paths currently skip the hub ring (`ring_ids[2:end-1]`,
`is_buckling_ring = i>1 && i<n`). In the v5 three-section geometry the hub ring
is the cone's top kink. Add it at **`(T_peak, ω=0)`** — peak tension with no
centrifugal relief — the load case that removes the only thing holding the hub
ring up.

---

## 6. Capacity model (REV 2 — single physics)

- **One wall authority:** `tube_wall_thickness(Do, t_over_D; min_wall_m)` — the
  same rule the mass model and the aligned FEA already use. The closed form must
  stop using `OPT_T_MIN_WALL = 0.5 mm`.
- **One end condition, recorded.** Pin-pin (conservative) or fixed-fixed
  (matches the FEA) — pick one `K` and use it in both the solve and the
  verification. (REV 1 did not notice these differ.)
- **One utilisation.** Size against `beam_column_utilisation`
  (`N/N_crit + √(M_ip²+M_oop²)/M_el`), not Euler-only. The axial/bending split
  `util_a`/`util_b` is already computed but not surfaced — **export it for the
  winner first** to confirm how much is bending before committing to a sizing
  form (`objective_evaluator.jl:737-740,813-817`).

The solve (per ring, bisection on `Do`):

```
required:  N/N_crit + √(M_ip²+M_oop²)/M_el  ≤  1/FoS_req
with       N_crit, M_el from strut_properties(tube, L, K)   (single K, single wall)
```

---

## 7. Open decisions (REV 2 — re-ordered by leverage)

### 7.0 Deferred (separate work, not blocking this proposal)

- **Feather factor in the ODE aero.** Add a term that reduces the rotor's
  effective wind / Cp / Ct above rated (blade pitch or shaft-yaw stall), so the
  high-wind structural case can be sized. Blocked on: a model change in
  `ring_forces.jl`, and a decision on the control law (pitch vs backline-payout).
  Until then the high-wind case is un-modelled; the load step (§7.1) is the
  sizing case.
- **Lifter-drop scenario.** Needs a time-varying lift device in the sweep.

1. **Load state — RESOLVED (2026-09-06).** Sizing case = a bounded **generator
   load step** (nominal `k_mppt × 2`), measured `F_helix ≈ 1278 N/vertex` on the
   hub segment (`scratch/scenario_sweep.jl`). The lull is benign under MPPT; the
   high-wind feather is **deferred** (§7.0) because it needs a feather factor in
   the aero. The exact load-step magnitude (instant step vs soft-ramp) is a
   detail to pin down with the `RampController` before finalising the coefficient.
2. **End condition K.** Pin-pin or fixed-fixed — one value, recorded, both sides.
3. **Bending in the solve.** How much of the utilisation is bending
   (`util_b`)? If large, the closed-form solve must include a bending estimate,
   or fall back to the static frame solve (`assemble_ring_frame` → `solve` →
   `extract_beam_forces`) fed with closed-form forces.
4. **Geometry.** Solve on `ring_spacing_v5` (what the ODE builds), not v4.
5. **FoS floor.** 2.5 (campaign) vs 1.8 (Path A default) — one source.
6. **`t_over_D` pinned vs solved.** Start with `t_over_D` pinned, `min_wall_m`
   as the wall floor.

---

## 8. Implementation steps (REV 2 draft)

1. Fix orientation in `_evaluate_trpt_design_impl` / `objective_v10` load build;
   confirm single-rotor tension is unchanged (regression) and stacked-rotor
   tension is monotone ground→hub.
2. Export `util_a`/`util_b` for the winner; measure the axial vs bending split.
3. Re-derive the torque-helix `F_helix` and the signed kink force against
   `extract_vertex_forces` (one throwaway script, like the prototypes).
4. Implement `solve_ring_Do(N, M, L, n, t_over_D, min_wall_m, fos_req, K) → Do`
   (bisection on §6).
5. Wire a `size_beams_closed_form(dec, p_base, cfg)` on the v5 geometry with the
   fixed orientation, replacing x1–x4 in `evaluate_windowed`.
6. Write solved `Do` back into `sys` so the drag model and the verification FEA
   see the same tube.
7. Re-baseline: fast suite + acceptance + a short campaign.
8. One-time FEA verification on the winner (including the hub ring).

---

## 9. Risks

- **The load-state choice dominates the answer** (was the "10× swing" in REV 1;
  now explicitly the `(Q_max, T_min)` + coefficient choice). Resolve §7.1 first.
- **Orientation and capacity-model mismatches** silently corrupt any
  closed-form-vs-FEA comparison; fix and record before trusting numbers.
- **Removing 4 genes reshapes the DE landscape**; the "more rotors stack"
  comparison must be re-run from a clean seed on the new evaluator.
- **Acceptance re-baseline** required (`src/` physics + evaluator change).

---

## 10. Notes / provenance

- FoS-alignment (wall floor → `tube_wall_thickness`, single authority) already
  landed and is green (2026/2026 fast suite).
- `scratch/verify_minwall.jl`: min-wall knob + aligned FoS on the winner
  (ring FoS ≈ 1.2 at 2 mm, ≈ 1.1 at 1.5 mm).
- `scratch/beam_sizing_proto.jl`: closed-form evaluator + Do_top bisection —
  the "297 mm / 291 kg" output is the peak-25/CT=1.0/full-cone/0.5 mm-wall/pin-pin
  bound and is **not a real design**; it documents the four-way mismatch in §2.
- `scratch/verify_load_split.jl` — **measured 2026-09-06** (winner, settled @
  rated 11 m/s, 2 mm wall):
  - axial/bending split of the worst ring: **1.000 axial / 0.000 bending**
    (FoS 1.17, util_ax 0.858). Settled state is pure compression.
  - `N_comp/T_line` = 0.098–0.103 ⇒ **effective DLF ≈ 0.18** vs closed-form 1.2
    (**≈ 6.7× over-count**). Confirms the load is torque-helix driven.
  - segment twist 40.8° (matches the regate verdict's 41°).
- `scratch/scenario_sweep.jl` — **first-cut scenario sweep (measured 2026-09-06)**
  (rated settle ω_gnd 13.5 rad/s, T_line 710 N; lull/gust/load-step only — feather
  and lifter-drop still TODO):
  - **lull (11→3 m/s) is benign** — `F_helix` unchanged (≈103 N/vertex). Under
    MPPT (`τ = k·ω²`) a wind drop lowers ω so Q falls *with* T; "rated torque in
    a lull" does not exist. The `(Q_max, T_min)` driver is the **generator load
    step**, not the lull.
  - **gust (11→25 m/s, no feathering) is unrealistically catastrophic** — 69.9°
    twist (at the 78.8° limit), ~50 kW-equivalent. Confirms the feather gap.
  - **load step ×2** → `F_helix` 1278 N/vertex, twist 50.8° (under limit) — the
    defensible "certified fault" candidate.
  - **load step ×3** → twist 94.8° (> 78.8° crossing) — the excluded ebrake.
  - **the hub segment (seg 5) dominates every scenario** (`F_helix ∝ r`) —
    confirms the hub ring is the load case both paths currently skip.
  - **k_mppt-ease is NOT feather** (negative result): easing the generator at
    25 m/s spins the rotor up to twist 87.9° (> 78.8° collapse). Capping Q
    requires reducing Cp/Ct, which the ODE does **not** model (aero is
    `ct_at_tsr`/`cp_at_tsr` only, no pitch/feather term). High-wind feather is a
    **model gap**, not just a missing scenario — a feather factor must be added
    before the high-wind structural case can be sized.
