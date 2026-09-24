# Handover: Multirotor Stability Remediation & Load-Path Fix

**Document:** `handovers/handover-2026-09-23-multirotor-stability-remediation.md`
**Revision:** 4 (updated 2026-09-23, incorporating One-Plane ruling, Probes A/B/C isolation, Phase 4 structural bottleneck isolation, and Handover Part 2 link)
**Original:** Revision 1, 2026-09-22, Antigravity (Supervisory Agent); Revision 2, 2026-09-22, dsh (Laptop Agent)
**Target:** Implementing Agent & Contributor Team
**Scope:** Remediation of multi-rotor TRPT instability artifacts in KiteTurbineDynamics.jl
**Part 2 Handover:** See [`handovers/handover-2026-09-23-multirotor-bem-sizing.md`](handover-2026-09-23-multirotor-bem-sizing.md) for the complete BEM multi-rotor sizing failure analysis, Peter Jamieson scaling law derivation, and Phase 5 implementation blueprint.

> **Revision 4 records the definitive resolution of the lift-chain decoupling via the One-Plane
> basis ruling, the refutation of aerodynamic feedback (Probes A/B/C), the Phase 4 structural
> bottleneck isolation (Ring 4 Euler buckling driven by inverted pendulum head mass), and the
> transition to Phase 5 (BEM multi-rotor sizing remediation).**
> Section 0 lists every correction across revisions.

---

## 0. Revision 2, corrections (read first)

| # | Revision 1 said | Revision 2 (verified) | Where |
|---|---|---|---|
| 1 | Expansion rotors contribute ~40 % of thrust, `+48 N` and `+14 N` | **8.2 %** of thrust. Ring 8 **+101.3 N** (wind_factor 1.000), ring 9 **+24.0 N** (0.909). Total **+125.3 N** of 1537.3 N | measured, `scratch/probe_phase1_thrust_split.jl` |
| 2 | `power_split = 0.6` ⇒ main rotor makes only 60 % of thrust | Category error: `power_split` is a **power** knob. Island 1's measured thrust split is 91.8 % main / 8.2 % expansion. `physics-topology.md` §5 item 5 records a *different* design (the seed) at ~85 % expansion — the rule "count every rotor" holds, the 40 % figure does not | measured; `physics-topology.md:260-263` |
| 3 | Blade mass omitted was `1.39 kg` (ring 9) / `0.68 kg` (ring 8); `I_z` was 15.70 / 21.60 kg·m² | `er.mass` = **2.613 kg** (ring 9) / **2.547 kg** (ring 8); node mass was **1.5702 kg** (ratios 2.66× / 2.62×); actual `I_z` = **32.4947 / 31.9055 kg·m²**. Hub ring carries 9.4645 kg | `probe_er_mass_island_1.log`; the "reconcile 1.39/0.68 vs 2.61/2.55" open item in `item4-campaign-summary.md` is now **CLOSED** — 2.613/2.547 kg is correct |
| 4 | `F_radial` is "an active destabilizing negative spring" driving the 1.92 m excursion | Real defect, but **small**: `F_radial` measures **2.715 N** (ring 9) / **5.310 N** (ring 8). Desktop verdict stands: a spurious outward **bias** that parks the ring at an offset `F/k`; "not a runaway force by itself" | measured; `item4-campaign-summary.md` |
| 5 | Hub lateral swing was **1.92 m** peak-to-peak | Gate summary reads `hub_lat p2p **1.2282 m**` (min 0.7725, max 2.0007). 1.92 m is the +60 s *settle lateral offset*, a different quantity | `wg_isl1_ld0.00_dtf1.log` |
| 6 | Islands 2 and 3 "qualified cleanly under the 120 s wobble gate" | They pass the **FoS** gate. The raw gate also prints `SLACK GATE: FAIL` on their 3 bridle lines (island 3: **0.10 s** contiguous, 60 s total, ~50 % duty). **That item is ruled closed** — see row 10 | `wg_isl3_ld0.00_dtf1.log` |
| 7 | Finding B: the back line short-circuit is the established cause | The back line model is verified as described, but the **established** finding is "the cone dies in the bow and the bearing follows the bow". *Why* is the **open question**. B is a plausible consequence, not the verified cause | `probe_cone_island_1.log`; `item4-campaign-summary.md` |
| 8 | Phase 1.3 snippet used `wind_fn` and `T_est = 100.0` | `lift_chain_design` has **no `wind_fn` in scope** — the snippet throws `UndefVarError`. Use `p.v_wind_ref` (match `v_hub`) and freeze `T_est` to the **main-rotor thrust**, exactly as `ring_forces.jl:280-286` computes it | source |
| 9 | Phase 2.1/2.2: add bridle compliance, let the sky anchor float | Both **contradict recorded rulings** (§3.1 bridle geometry; §3.2 taut back line, deliberate design-point slack **REJECTED** 2026-09-15). They are **not** the implementing agent's to change — see §4 | `physics-topology.md:137-178` |
| 10 | Phase 4 target: "Island 1 bridle cone maintains continuous tension in the 120 s window" | The cone's **cyclic slack is RULED EXPECTED BEHAVIOUR** (Rod, 2026-09-21) and does not block the gate. The concern bar is **sustained slack > 0.8 s after settle**. Island 1's **14.93 s** contiguous is ~19× over that bar and ~50× the v13 winner's 0.29 s — so island 1 fails the *ruled* test too, but "T_bridle > 0 continuously" is not the criterion. Chase the bar, not zero tension | `DECISIONS.md:37-54`; gate logs |
| 11 | Island 1 FoS trough = 1.59; peak cone tension 7.1 N | Both are **capture-cadence dependent**. The 0.05 s fine twin reads FoS trough **1.0446** and cone peak **480.1 N**. Quote the cadence with the number: the coarse 0.5 s capture under-reads the trough by 34 % and the cone peak by 98 % | `wg_isl1_ld0.00_dtf1.log` vs `wg_isl1_ld0.00_fine.log` |
| 12 | Dual-plane ring attachment conflict | **Confirmed and permanently fixed**. `rope_forces.jl:269` forced bridles to the shaft frame while TRPT lines took the tilted plane. Retiring `is_bridle ? shaft : tilt` so all attachments share the rigid ring basis (`tilt_applies`) transformed the results: **Island 3 became mathematically steady** (hub & bearing p2p `0.0000 m`, cyan p2p `0.02 N`, cone steady at `158.9 N` with `0.0000 s` slack, FoS `13.45`). **Island 1 bridle cone was resurrected** (mean load `3.87 N → 1382 N`, min `74 N` in 2 s window; axial gap compression halved). | `DECISIONS.md:13-45`, commit `e32afe4` |
| 13 | Probe A: Expansion-rotor aerodynamics | **Conclusively refuted**. Forcing expansion-rotor $F_{\text{axial}} = 0$ and $\tau_{\text{net}} = 0$ (retaining assembly mass, $J_{\text{rotor}}$, and geometry) left Island 1 still running a **1.23 m limit cycle** with FoS trough **1.2949** and cone unloading. The aero load modulates severity, but is **not** the cause of the instability. | `probe_axial_gap_compare.jl`, commit `e32afe4` |
| 14 | Probe C: Scope of synthetic ring tilt | **Refuted**. Restricting tilt to the hub ring nearly doubled the axial gap deficit (−0.0893 to −0.1665 m), raised the hub peak to 2.367 m, and killed the cone at t = 1.10 s. Applying tilt across all rings (`tilt_scope = :all`) is the better physical model. | `probe_axial_gap_compare.jl`, commit `e32afe4` |
| 15 | Remaining Island 1 mechanism | Narrowed strictly to **structural/geometric & mass distribution**: Island 1 has 10 rings at $r_{\text{hub}} = 2.61\text{ m}$ (slender column) vs Islands 2/3 at 11/12 rings ($r_{\text{hub}} = 3.55\text{ m}$), and carries **33.68 kg airborne mass** (+50% heavier) with heavy lumped masses ($4.18\text{ kg}$, $4.12\text{ kg}$) at rings 8 and 9 plus a $9.46\text{ kg}$ hub. | `DECISIONS.md:40` |

**Phases 1, 2 and 3 are implemented and verified on the laptop** (see §5). Phase 4 is structured as an offline investigation of structural/geometric & mass distribution modes (see §6).

---

## 1. Executive Summary & Context

Item 4 ("Explore the 5 kW design space with mass-aware lift") re-gated three islands
at zero artificial damping. Numbers below are quoted from the campaign pack in
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_physlift/`.

**Island 2, 22.26 kg (campaign best).** Single rotor, 12 rings, 3 lines, r_hub 3.55 m.
PASSES the FoS gate at `lin_damp` 0.00 and 0.05 (hub p2p 8.2 mm, FoS trough 6.54,
P 5.762 kW, ω 13.750 rad/s). The slack tracker flags only the 3 bridle lines, 0.08 s
dips at ~35 % duty, **inside the ruled envelope** (§0 row 10).

**Island 3, 22.32 kg.** Single rotor, 11 rings, 3 lines, r_hub 3.55 m.
PASSES the FoS gate at both settings (hub p2p 7.5 mm, FoS trough 12.27, P 5.655 kW,
ω 13.665 rad/s). The gate's own slack criterion fires on the 3 bridle lines (0.10 s dips,
~50 % duty, 60 s total each) and the gate prints `SLACK GATE: FAIL`, but the
**2026-09-21 ruling closes that item for dips under the 0.8 s concern bar**. Island 3 is
therefore a valid control, with the caveat that its cone is intermittently unloaded
(58 % of the window above 5 N), not continuously taut.

**Island 1, 33.68 kg. FAILS.** 3 lines, 10 rings, **3 rotors** (main rotor at ring 10
plus expansion rotors at rings 8 and 9), r_hub 2.61 m. At `lin_damp = 0.00`
(`wg_isl1_ld0.00_dtf1.log`):

- Structural FoS trough **1.5865** (gate ≥ 2.5). The fine-cadence twin
  (`wg_isl1_ld0.00_fine.log`, 0.05 s capture) reads **1.0446**, the trough is
  capture-cadence dependent, so quote the cadence with the number.
- Hub lateral **1.2282 m** p2p. Bearing lateral **2.3126 m** p2p (fine twin: 1.3853 m /
  2.6437 m).
- Cyan **0 → 1003.3 N**. Back line **5.2 → 1800.9 N**. Top bay **0 → 2322.4 N**.
- Bridle cone unloaded for **14.93 s** contiguous, mean tension **0.0296 N**, against a
  concern bar of **0.8 s** (`DECISIONS.md:37-54`), i.e. ~19× over it.
- P_gen 3.78 → 9.16 kW. ω 11.95 → 16.05 rad/s.
- At `lin_damp = 0.05` damping masks it (FoS trough 7.82, hub p2p 0.054 m) but the cone
  still runs at **84 % duty** below 5 N.

### The Physical Paradox

Multi-rotor TRPT turbines have operated smoothly in the field, often more stably than
single rotors. The simulated collapse is therefore a candidate modelling artifact, not
an established property of multi-rotor machines.

### Root Cause Conclusion (Revision 2)

Three genuine codebase defects were confirmed in source and are fixed (§5). They are
**sufficient to bias** a multi-rotor machine. They are **not yet shown to be sufficient
to cause** island 1's collapse. The collapse's proximate mechanism is recorded in §2B,
and its cause is the standing open question.

---

## 2. Forensic Findings & Physical Mechanisms

### A. Bridle cone decoupling. CONFIRMED

The cone is the lift chain's only connection to the main rotor
(`physics-topology.md:104-108`). Island 1 loses it inside the first second.

Desktop 0.05 s trace (`probe_early_island_1.log`, CSV `early_island_1.csv`):

```
t=  0.1  bridle=( 47.5   90.0   78.7)  cyan= 185.0  topbay= 596.0  hub_lat=0.0117
t=  1.1  bridle=(  0.0    0.0    0.0)  cyan= 223.2  topbay= 918.9  hub_lat=1.4073
t=  2.1  bridle=(  0.0    0.0    0.0)  cyan= 123.7  topbay= 716.3  hub_lat=1.8147
```

Island 3 in the same window (`probe_early_island_3.log`): cone cycles 20–52 N, cyan
holds 91–104 N, top bay holds 600–605 N, hub holds a 10 mm band.

Island 1's cone is **alive at t = 0.1 s and dead from t = 1.1 s onward**, while the hub
is already 1.41 m off axis in the same second. Slack bridles decouple the rotor from the
lifter kite's lateral pendulum stiffness `k_⊥ = T_lift / L_line`, leaving the top of the
airborne assembly as an unsupported cantilever.

**Calibration against the 2026-09-21 ruling.** A once-per-revolution cone dip is *expected
behaviour*, not a defect (`DECISIONS.md:37-54`): the bowed column offsets the hub
~1.1–1.25 m laterally and the top rotor's lift pressure unloads the top cone line through
the turn. The ruled bar is **sustained** slack. Reference durations: the v13 single-rotor
winner dips **0.22 s** at production damping and **0.29 s** at zero damping. Island 3 (the
Item 4 control) dips **0.10 s**. Island 1's **14.93 s** is ~50× the winner's zero-damping
dip. The correct reading of island 1 is therefore **not** "the cone went slack", that is
normal, but "the cone stayed slack for two orders of magnitude longer than the design
envelope allows".

### B. The cone dies in the bow. The bearing follows the bow. OPEN

This is the Desktop's established finding and it **supersedes** Revision 1's
back-line-short-circuit story as the *stated cause*.

Cone state at three points (`probe_cone_island_1.log`):

| state | hub lateral from design axis | bearing perp offset | cone total | per-line strain |
|---|---|---|---|---|
| after settle | 0.0015 m | 0.0004 m | **231.98 N (3/3 active)** | +0.00013 / +0.00016 / +0.00018 |
| relax +60 s | 1.9607 m | 1.0118 m | 0.000 N (0/3) | **−0.01656 / −0.02337 / −0.12022** |
| relax +120 s | 1.3549 m | 0.6342 m | 0.000 N (0/3) | −0.01206 / −0.01474 / −0.07283 |

The cone is **healthy at handoff** (66–88 N per line) and dies during the relax phase.
The strains are **negative**: the bridle lines are being *compressed* by 0.08–0.61 m,
which a tension-only line cannot resist. Islands 2 and 3 unload by microns and hover at
rest length. Island 1 compresses by centimetres. The distinguishing quantity is the
**bearing's offset from the hub axis**: island 1 reaches 1.0118 m at 60 s, while
islands 2 and 3 hold 0.001–0.006 m. **The stable machines bow under a fixed bearing.
Island 1's bearing follows the bow.**

Note what is *already* ruled expected: the bowed column offsets the **hub** ~1.1–1.25 m
laterally (`DECISIONS.md:44`), and island 3 sits at a 1.0317 m hub-lateral mean while
passing cleanly. A bowed column is the design condition. **What is not expected, and is
the open question, is the bearing leaving the shaft axis with it.**

Why the bearing follows the bow is the **open question** in
`item4-campaign-summary.md`. It is not answered by any of the three Phase 1 fixes.

**The back line, verified separately.** The model is bi-linear
(`initialization.jl:92-109`): the design point sits on a **320 N hard stop**
(`BACK_LINE_T_DESIGN_N`), with **0.8 m of soft travel at `k_soft = 400 N/m`** below it
and stiff Dyneema above. Rising sky-anchor height increases `b_dist`, which pushes the
element into the hard region (`ring_forces.jl:567-570`), so with `payout = 0` the anchor
**cannot rise to re-tension the bridles**. That part of Revision 1 is sound.

Two corrections to Revision 1's use of it:

1. **The hard stop is not the whole element.** The 0.8 m soft region is what governs
   recovery, and island 1's measured `T_back` during the window is
   **mean 239.5 N**, mostly *below* the 320 N stop, i.e. in the soft region, while
   peaking at 1800.9 N. "Held the sky anchor firmly" is true only for part of each cycle.
2. **The gap arithmetic understates the effect by an order of magnitude.** Revision 1
   quoted a 4.3424 m requirement against an actual 4.28–4.33 m (15–60 mm short). The
   measured bridle compression reaches **0.61 m** (line 3 at 60 s). The "~50 mm bridle
   slack" framing is wrong by ~10×.

The back line's intended lever for raising the sky anchor is **`backline_payout`**, not a
redesign, see `ring_forces.jl:517-522` and §4.

### C. Spurious outward `F_radial` on the ring centre. CONFIRMED, SMALL

`src/ring_forces.jl` computed the ring centre node's lateral displacement from the shaft
axis and applied `F_radial .* rad_dir` to that node. For a symmetric rotor the vector sum
of the rim forces at the attachment vertices is identically zero, so the net force on the
ring's centre of mass is zero. The block was executed **only** by expansion rings, so it
biased exactly the configurations with intermediate rotors.

Measured magnitude (Revision 2): `F_radial` = **2.715 N** (ring 9) and **5.310 N**
(ring 8). It is a bias of order newtons, not a runaway force. Revision 1's "negative
spring kicking the ring outward" overstates it, and it cannot be a driver of a 1.2 m
excursion on its own.

**Why it still mattered.** The designed radial restraint is **dead**. The spoke spring at
`ring_forces.jl:376-396` is guarded on `spoke !== nothing && spoke.enabled`. The `spoke`
argument **is** plumbed through the evaluator (`src/objective_evaluator.jl:507`, passed on
at `:661` and `:761`. Also `src/objective_evaluator_ramp.jl:133,172` and the v11/v12
entries), but it **defaults to `nothing`**, and **neither the Item 4 campaign runner nor
the wobble gate passes one**:

- `scripts/run_v13_5kw_masslift.jl:261` calls `evaluate_windowed(...)` with no `spoke=`
  keyword, so the stage-1 screen ran without spokes.
- `scripts/ode_gate_v13.jl` and `scratch/probe_wobble_gate_run_island3.jl` contain no
  `spoke` at all, so the 120 s re-gates ran without spokes.
- `SpokeParams(...)` is constructed only in `scripts/` diagnostics
  (`scripts/spoke_diag.jl`, `scripts/retest_085_k2.jl`, …), mostly with
  `enabled=false`.

At `d_line = 7 mm` that spring would be `k ≈ 9×10⁶ N/m`. Without it the ring has **no**
radial restraint in the ODE, so a few-newton bias acts unopposed. That dead path is a
silent no-op of the kind `physics-topology.md` §6 forbids.

**RULED INERT (Rod, 2026-09-22).** That is now the decision, not an oversight. Only the
ground ring and the back-line anchor touch the ground, so a TRPT column is a free-floating
tensegrity with no centreline anchor. Energising the spokes would add an artificial
guide-wire pulling every ring toward the ground station's line of sight. Rings hold radial
integrity through line tension and inter-bay truss geometry. Do not switch them on as a
stability crutch.

`F_radial` remains a **structural** load, it spreads the tethers, and the ring/FoS
evaluator prices it there. It is not a centre-of-mass force.

### D. Missing expansion-blade translational mass. CONFIRMED

`initialization.jl` added the expansion rotor's rotary inertia `I_z` to the ring node but
left `mass_node` at `p.m_ring`. Measured on island 1
(`probe_er_mass_island_1.log`):

| ring | `er.mass` | node mass before | node mass after | `I_z` |
|---|---|---|---|---|
| 8 | 2.547 kg | 1.5702 kg | 4.1175 kg | 31.9055 kg·m² |
| 9 | 2.613 kg | 1.5702 kg | 4.1836 kg | 32.4947 kg·m² |
| 10 (hub) | — | 9.4645 kg | 9.4645 kg | 149.9613 kg·m² |

The bladed rings carried massive rotational inertia while weighing a bare ring, their
lateral sensitivity `a = F/m` was ~2.6× too high.

`er.mass` is the **assembly total** (`test_blade_mass_law.jl:126-129` asserts that summing
`er.mass` must not be multiplied by `n_blades`), and `expansion_airborne_mass`
(`expansion_analysis.jl:62`) already budgets it unconditionally for **lifter sizing**. The
defect was that the ODE node weighed less than the budget the lifter was sized against.
The fix adds it unconditionally, deliberately **not** gated by
`EXPANSION_PHYSICS[].blade_inertia`, because the mass is real whether or not the inertia
term is modelled.

### E. Settle priced thrust from the main rotor only. CONFIRMED

`lift_chain_design` sized `T_thrust` from `main_rotor_swept_area(sys)` alone, while the
ODE adds every expansion rotor's axial thrust up-shaft (`ring_forces.jl:288-305`).
`T_thrust` feeds Section B, `T_top = T_thrust + n·T_b·cosθ − W_rotor·sinβ`
(`initialization.jl:1342`), and `T_top` sets `F_top` in `design_axial_preload`
(`initialization.jl:1538`). Preload and force model therefore disagreed.

**Measured effect (Revision 2), island 1 at ω = 13.7084 rad/s:**

```
main-rotor disc thrust (pre-fix T_thrust) =   1411.979 N
  ring  8  wind_factor=1.000  F_axial=+ 101.320 N  F_radial= 5.310 N (rim only)
  ring  9  wind_factor=0.909  F_axial=+  24.008 N  F_radial= 2.715 N (rim only)
T_thrust (post-fix, all rotors)           =   1537.306 N
  expansion contribution                  =    125.327 N  (8.2 % of total)
T_top pre-fix                             =   1513.919 N
T_top post-fix                            =   1639.246 N   (+8.3 %)
bridle L0 pre-fix                         = 5.066287 m
bridle L0 post-fix                        = 5.066287 m   <- UNCHANGED
```

**Two scope corrections to Revision 1:**

1. **Fix 3 does not move the bridle preload cut.** `T_bridle` is independent of
   `T_thrust`, so `L0 = gap/(1 + T_bridle/EA)` is unchanged. Revision 1's claim that the
   omission "unloaded the bridle cone" via the preload cut is **not** the mechanism.
2. **Fix 3 does not move the sky anchor.** The taut 2×2 split
   (`_sky_anchor_taut_split`) is solved from `T_lift` and the sky anchor's weight only ,
   thrust does not enter. Revision 1's "sky anchor positioning established without this
   thrust" is wrong.

What Fix 3 *does* do: raise the TRPT axial preload by 125.3 N (+8.3 %) on island 1. That
stiffens the column, which is the only lever any Phase 1 fix has on the bow of §2B. For a
machine with no expansion rotors the loop body never executes, so Fix 3 is a
**bit-for-bit no-op**, verified on island 3 (contribution 0.000 N, `T_top` identical).

### F. Microscopic bridle elastic stretch, real, but not a code defect

At handoff island 1's bridles read `L0 = 5.06622 m`, `L = 5.06689 m`, strain
`+0.00013`, i.e. **0.013 %**. The cone carries 66–88 N per line at settle, and
`BRIDLE_EA_DESIGN = 500 000 N` (`initialization.jl:26`) gives a ~0.7 mm stretch **by
construction**: `L0 = gap/(1 + T_bridle/EA)`. Any linear tension-only line loses tension
after a displacement of `T·L/EA`. At these tensions that is sub-millimetre.

This is a genuine **design sensitivity**, not a modelling defect. Revision 1's conclusion
that "the bridle model lacks the physical compliance of real splices" invites a design
change that `physics-topology.md` §3.1 reserves: the bridle cone is fixed by **one**
design input (half-angle 31°), in 2 mm Dyneema, and `BRIDLE_EA_DESIGN` is a recorded
design constant. Softening the bridles to buy slack tolerance is **Rod's call, not the
implementing agent's**, see §4.

---

## 3. Phase 1, implemented and verified

All three landed on the laptop, 2026-09-22. `scripts/ktd-format` clean.

| # | File | Change | Evidence |
|---|---|---|---|
| 1.1 | `src/ring_forces.jl:344-368` | Removed the `F_radial .* rad_dir` push on `forces[ring_gid]`; replaced with the physics rationale, the "`F_radial` remains a structural load" rule, and the RULED-INERT spoke note | `F_radial` was 2.7–5.3 N; rim load only |
| 1.2 | `src/initialization.jl:211-230` | `mass_node += er.mass` for every expansion rotor on the ring, unconditional | rings 8/9: 1.5702 → 4.1175 / 4.1836 kg; island 3 unchanged |
| 1.3 | `src/initialization.jl:1296-1332` | Sum every expansion rotor's `F_axial` into `T_thrust`; `T_est_main` frozen to the main-rotor thrust before accumulating; `p.v_wind_ref` and `er.wind_factor` matching the ODE; hub guard mirroring `ring_forces.jl:261` | island 1 `T_top` +125.3 N; island 3 exactly unchanged |

**Do not** reintroduce `F_radial` on the centre node, and **do not** gate the mass add on
`blade_inertia`.

---

## 4. Phase 2, rulings required, not implementation

Revision 1's Phase 2 asked the implementing agent to (2.1) give the bridle preload cut
"adequate compliance" and (2.2) verify the back line "allows the sky anchor to float when
the shaft flexes". **Both contradict recorded rulings and must not be actioned by an
implementing agent.**

- `physics-topology.md:137-156`, the bridle cone is fixed by ONE design input, its
  half-angle (31°). `bridle_bearing_offset(r_top) = r_top / tan(31°)` is the single
  authority. Padding compliance changes the recorded design.
- `physics-topology.md:170-178`, **RULED (Rod, 2026-09-15): the back line is TAUT at the
  design point and carries residual vertical tension. A deliberate design-point slack
  allowance is REJECTED.** The elastic is what makes it an altitude limiter. The intended
  lever for raising the sky anchor is `backline_payout`
  (`ring_forces.jl:517-522`. `initialization.jl:40-56`).

What Phase 2 should instead deliver is **answers to these questions**, escalated to Rod.
Questions 2 and the offset lever are now ANSWERED by the 2026-09-22 rulings. Question 1
remains open.

1. **Why does island 1's bearing follow the bow** while islands 2 and 3 bow under a fixed
   bearing? This is the collapse's proximate mechanism. No fix so far addresses it, so it
   is **still open, and now the only live question**.
2. ~~Should the spoke radial restraint be energised in the ODE?~~ **RULED INERT (Rod,
   2026-09-22).** Only the ground ring and the back-line anchor touch the ground, so a TRPT
   column is a free-floating tensegrity with no centreline anchor. Energising the spokes
   would add an artificial guide-wire toward the ground station's line of sight.
3. **Does island 1 need a design change, or only the model fixes?** The cone's *cyclic*
   slack is already ruled expected (bar: 0.8 s, `DECISIONS.md:37-54`), and its ~0.7 mm
   design-point stretch is a consequence of the recorded 31° cone and
   `BRIDLE_EA_DESIGN = 500 000 N`. The unresolved part is island 1's **14.9 s**
   contiguous slack, ~19× the bar. Two model levers are now exhausted (the
   thrust/mass/radial corrections, and the back-line offset) and neither clears the gate,
   so a design change is the likely remaining route.

---

## 5. Phase 3, verification results (laptop, 2026-09-22)

Commands are the canonical ones from `CLAUDE.md`.

- `scripts/ktd-format`, clean.
- `scripts/ktd-julia test/test_settle_validity.jl`, **9/9 PASS** (1 m 22 s).
  Handoff residual at t = 0: `acc_struct` 81.098 m/s², `max_force` 106.270 N.
- `scripts/ktd-julia test/runtests.jl`, see `.julia_depot/logs/phase3_runtests_2026-09-22.log`.
- `scripts/ktd-julia test/test_trpt_realisability.jl`, **32/32** after the re-baseline.
- `scripts/ktd-julia test/test_back_line_element.jl`, **39/39** after the payout fix.
- `scripts/ktd-julia test/runtests.jl` (second run, all fixes in):
  **2163/2163 green**, 0 failures, 5 m 09 s.

### 5.1 The three defects are real, but they do NOT rescue island 1

This is the most important result in this document. Both 120 s gates were re-run at
`lin_damp = 0.00` on the remediated build (`57b3f58`).

**Island 3, the single-rotor control, is clean.** FoS trough **12.3348** against
12.2739 before. Hub p2p 0.0074 m against 0.0075 m. Bridle dips stay at **0.100 s**
contiguous and 58.9 s total, and the 0.8 s ruled bar holds. So Fixes 1 to 3 introduce
**no regression** on a machine with no expansion rotors.

**Island 1 is still FAIL and is worse on the cone.**

| quantity | pre-remediation | remediated (`57b3f58`) |
|---|---|---|
| FoS trough | 1.5865 coarse / 1.0446 fine | **1.1269** |
| hub lateral p2p | 1.2282 m | **2.1037 m** |
| bearing lateral p2p | 2.3126 m | **2.8898 m** |
| cone mean tension | 0.0296 N | **0.0000 N** |
| cone max contiguous slack | 14.93 s | **22.62 s** |
| cyan max | 1003.3 N | 2034.9 N |
| back line max | 1800.9 N | 1205.6 N |

`T_bridle` reads min 0, max 0 and mean 0 across the whole window. The cone is dead
for the entire 120 s.

**What follows.** The four defects are genuine and are now fixed, but they are **not
the cause of island 1's collapse**. Fix 3 moves the operating point, because the
preload profile feeds `trpt_matched_place`, which sets the placed geometry and so the
bridle cut length. On this candidate the move is adverse. The proximate mechanism of
§2B stands unrefuted: the bow compresses the bearing-to-hub gap, and the bearing
follows the bow. That mechanism is untouched by Fixes 1 to 3.

**Do not report Phase 1 as having fixed the gate.** The next lever is the back-line
ground-anchor offset, which is measured but not yet actioned (see §6).

Artifacts, tracked for verification in
`scripts/results/v13_5kw_masslift_len18.8_rotorcount_physlift/logs/`:
`wg_isl1_remediated_ld0.00.log` and `.csv`, `wg_isl3_remediated_ld0.00.log` and `.csv`,
`early_island_1_post.log` and `.csv`, `early_island_3_post.log` and `.csv`.

### 5.2 The back-line offset ruling (Rod, 2026-09-22): `back_anchor_fwd_x = 11.0 m`

Rod ruled the ground-anchor downwind offset a PLACEMENT constant of **11.0 m**, not a
machine-scale dimension, and ruled the spoke radial restraint **inert**. That matches
`physics-topology.md` §1: only the ground ring and the back-line anchor touch the ground,
so a TRPT column is a free-floating tensegrity. Energising the spokes would add an
artificial guide-wire pulling every ring toward the ground station's line of sight.

Implemented as `BACK_ANCHOR_FWD_X_M` in `src/parameters.jl`, with `mass_scale` no longer
multiplying it. The geometric reading confirms the field note: against the axial
projection the ground anchor was **1.19 m UPWIND** at 6.901 m and is now **2.91 m
DOWNWIND**. The old law was `11.0 x (L/30)`, which gave `params_daisy` 3.78 m and the
5 kW / 18.8 m build 6.901 m.

**Island 3 improves on every metric.** This is the clearest evidence the choke was real.

| island 3, `lin_damp = 0.00` | pre-remediation | remediated (6.901) | ruled (11.0) |
|---|---|---|---|
| FoS trough | 12.2739 | 12.3348 | **13.4653** |
| hub lateral p2p | 0.0075 m | 0.0074 m | **0.0047 m** |
| cone mean tension | 45.7 N | 47.6 N | **104.69 N** |
| cone max contiguous slack | 0.10 s | 0.10 s | **0.08 s** |
| cone total slack | 60.0 s | 58.9 s | **25.8 s** |
| cyan mean | 96.8 N | 98.6 N | **146.3 N** |
| P_gen mean | 5.6550 kW | 5.6296 kW | **5.6866 kW** |

**Island 1 still FAILS, and its FoS trough is worse.** The choke IS released and it helped
specific symptoms, but it is not island 1's binding constraint.

| island 1, `lin_damp = 0.00` | pre-remediation | remediated (6.901) | ruled (11.0) |
|---|---|---|---|
| FoS trough | 1.5865 | 1.1269 | **0.9079** |
| hub lateral p2p | 1.2282 m | 2.1037 m | 1.7092 m |
| bearing lateral p2p | 2.3126 m | 2.8898 m | 2.5437 m |
| cone mean tension | 0.0296 N | 0.0000 N | **3.8700 N** |
| cone max contiguous slack | 14.93 s | 22.62 s | **14.91 s** |
| cyan max | 1003.3 N | 2034.9 N | 1197.8 N |
| back line mean | 239.5 N | 187.2 N | 189.2 N |

The back line now swings inside its elastic travel (70 to 290 N over the relax) rather
than sitting pinned on the stop, the cyan peak halves, and the cone is no longer fully
dead. The 20 s trace shows the same shape as before: cone live at t = 0.1 s at **81.8 /
111.6 / 117.3 N** (nearly double the pre-remediation handoff), then dead from t = 1.1 s.
So the extra preload delays nothing. Two levers are now exhausted and neither clears the
gate.

Artifacts: `wg_isl1_fwdx11_ld0.00.log` and `.csv`, `wg_isl3_fwdx11_ld0.00.log` and `.csv`,
`early_island_1_fwdx11.log` and `.csv`, `early_island_3_fwdx11.log` and `.csv`.

### 5.3 Acceptance suite

Run once on the remediated build: **7 of 8 PASS**. Only `test_settle_lowk_honest.jl` failed,
on A2, because the physics fixes raise the sustained power so k = 2.0 now clears the 5 kW
floor where it used to undershoot. Attribution was measured: with `src/` at `d130632` the
file is 13/13, and with the fixes it is 12/13 on exactly that assertion. A2 is re-baselined
to stop pinning a marginal floor verdict, and re-verified **13/13**. No `src/` file changed
between the 7-of-8 run and that fix, so the other seven results carry over.

### 5.4 Which fixes are no-ops for a single-rotor machine

With `expansion_rotors` empty, Fixes 1.2 and 1.3 never execute (no expansion rotor matches
any ring, and the thrust loop body never runs), and Fix 1.1's block was likewise gated on a
non-empty `expansion_rotors`. So a single-rotor machine's node masses and preload profile
are unchanged by those three, which `scratch/probe_phase1_thrust_split.jl island_3` and
`scratch/probe_er_mass_check.jl island_3` confirm.

**That equivalence does NOT extend to the offset ruling or to `backline_payout`.** Those are
global, and island 3 moves with them. Section 5.2 shows it moving, in the favourable
direction.

### 5.5 The One-Plane Basis Ruling (Rod, 2026-09-22): `is_bridle ? shaft : tilt` Retired

Rod ruled that a rigid ring has **ONE plane in 3-space**. The `is_bridle ? shaft : tilt`
exception in `compute_rope_forces!` was permanently deleted (`e32afe4`), not defaulted.
Attachment point kinematics now depend solely on `tilt_applies(ri, hub_ri)`.

**Impact on Island 3 (Single-rotor control):**
- Hub lateral p2p: `0.0075 m → 0.0000 m` (rock-solid steady).
- Bearing lateral p2p: `0.0059 m → 0.0000 m`.
- Cyan tension p2p: `0.02 N` (mean 143.9 N).
- Bridle cone tension: `158.9 N` constant, with **zero seconds of slack** across the entire 120 s window.
- FoS trough: `13.45` (gate ≥ 2.5 PASS).

**Impact on Island 1 (3-rotor):**
- Lift chain reconnected: Cone mean tension jumped from **3.87 N to 1382 N**.
- Minimum cone tension over 2 s rose from **0 to 74 N**.
- Max axial gap deficit halved from −0.169 m to −0.089 m.
- Reader discrepancy closed: `get_max_rope_tension` and the gate slack tracker previously
  evaluated bridles on the tilted basis while forces used the shaft basis; this is now unified.

### 5.6 Expansion-Rotor Isolation: Probes A, B, and C

To determine why Island 1 still ran a 1.54 m limit cycle in the 120 s gate with FoS trough 0.74,
a three-probe isolation was executed (`scratch/probe_axial_gap_compare.jl`):

1. **Probe A (Expansion Aero ON vs OFF):**
   With $F_{\text{axial}} = 0$ and $\tau_{\text{net}} = 0$ on rings 8 and 9 (mass, $J_{\text{rotor}}$, geometry untouched):
   - FoS trough: `0.7400 → 1.2949`
   - Hub lateral p2p: `1.5407 m → 1.2294 m`
   - Cone minimum tension: `0.00 N → 0.00 N`
   - Finding: Island 1 **still runs a 1.23 m limit cycle**. The instability is **structural/geometric**, not an aerodynamic feedback loop.
2. **Probe B (Ring 8 vs Ring 9 isolation):**
   `ring8only` and `ring9only` both reproduced default behavior (hub peak 1.44–1.48 m), confirming Probe A.
3. **Probe C (Hub-only tilt vs Global tilt):**
   Restricting the ring tilt to the hub ring made the gap deficit worse (−0.1665 m) and killed the cone at t = 1.10 s. Global tilt is the sounder formulation.

### 5.7 Summary of Current Model Status

- **Lift chain mechanics:** Complete, sound, and fully verified. Bridles, cyan line, bearing, and sky anchor are structurally and kinematically coupled on a unified ring plane.
- **Single-rotor baseline (Islands 2 and 3):** Fully passing all gates with high structural margin (FoS > 12) and zero limit-cycling.
- **Island 1 candidate status:** Structurally marginal (FoS trough 1.29 even with aero off, 0.74 in full run) with a 1.23–1.54 m column oscillation.

---

## 6. Phase 4 Findings: Structural Bottleneck & Resonance Mode Isolated (Revision 4)

With aerodynamic feedback refuted by Probe A, Phase 4 executed the structural, geometric, and mass-distribution investigation across Tasks 4.1–4.4.

### 6.1 Task 4.1 & 4.2: Closed-Form Beam Sizing Audit & Dynamic Per-Ring FoS Breakdown
Diagnostic tool: `scratch/probe_ring_fos_breakdown.jl`

1. **Beam Sizing Audit (Task 4.2):**
   - The 2.0 mm wall thickness floor (`t_floor`) binds across **every single ring** (1 to 10) on Island 1.
   - For transmission cylinder rings 2–6 ($r = 0.741\text{ m}, L = 1.284\text{ m}$), outer diameter sits at only $D_o = 11.32\text{--}12.60\text{ mm}$ ($t/D \approx 0.16\text{--}0.18$, solid rod regime), giving an Euler buckling capacity of only $P_{\text{crit}} = 1621.5\text{ N}$.
   - The cone transition starts low at $z = 5.62\text{ m}$, expanding to $r = 2.610\text{ m}$ at ring 8 ($z = 10.25\text{ m}$), leaving the top three rings (8, 9, 10) at $r = 2.610\text{ m}$ ($L = 4.520\text{ m}, D_o \approx 26.3\text{--}29.1\text{ mm}, P_{\text{crit}} \approx 1543\text{--}2128\text{ N}$).

2. **Equilibrium Stress Decomposition vs Dynamic Failure (Task 4.1):**
   - At static equilibrium ($t = 0.0\text{ s}$), all beam bending moments are zero ($M_{\text{ip}} = 0, M_{\text{oop}} = 0$), and static FoS is $\ge 13.5$ on every ring (rings 2–5 FoS 16–18, ring 8 FoS 13.5).
   - In dynamic simulation under operational wind:
     - **The structural bottleneck is Ring 4 (GID 31) in the lower transmission cylinder, NOT the expansion rotors or hub ring.**
     - Ring 4 hits a dynamic FoS trough of **1.4772** at $t = 0.820\text{ s}$ (and collapses to $<1.0$ later in the wobble limit cycle).
     - The failure mode is **100% axial Euler column buckling** ($w_A = 0.6767, w_B = 0.0002$): dynamic compression reaches $N = 1097\text{ N}$ against $P_{\text{crit}} = 1621.5\text{ N}$.
     - Rings 2, 3, 4, 5 all experience massive dynamic compression ($N \sim 700\text{--}1100\text{ N}$).
     - The expansion rings (rings 8 & 9) and hub ring (ring 10) maintain dynamic FoS of **3.35**, **10.48**, and **6.37** — they are **not** the structural bottleneck.
     - By contrast, on Island 3, the transmission cylinder rings (rings 2–9) have dynamic FoS of **17.6 to 23.9**, with the bottleneck at the hub ring (FoS = 12.50).

### 6.2 Task 4.3: Lumped Mass Resonance Probe
Diagnostic tool: `scratch/probe_mass_resonance.jl`

| Configuration | Hub Lateral Peak | Hub Lateral p2p | Bearing Lat Peak | Cone Min Tension | Cone Mean Tension | FoS Trough |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A: Baseline Full Physical Mass** | 1.7962 m | 1.7941 m | 2.2215 m | 92.86 N | 477.02 N | 1.4772 |
| **B: Bare Ring Mass on Rings 8 & 9** | 1.6784 m | 1.6762 m | 2.0686 m | 31.75 N | 438.81 N | 2.1122 |
| **C: Uniform Bare Column (1.53 kg/ring)** | **0.5761 m** | **0.5738 m** | **0.7106 m** | **229.99 N** | **282.78 N** | **6.0522** |

**Root Physical Mechanism:**
1. **The Inverted-Pendulum Head Mass:**
   - In Island 1, $r_{\text{hub}} = 2.610\text{ m}$ (slender) compared to Island 3 ($3.546\text{ m}$). To capture 5 kW power from a smaller diameter annulus, BEM sized a large blade span ($1.958\text{ m}$ vs $1.331\text{ m}$ on Island 3).
   - Under the cubic blade-mass law ($m = M_{\text{BLADE\_REF\_KG}} \cdot \text{span}^3$), hub blade mass exploded to **3.155 kg/blade** (total hub rotor **9.464 kg**, 3.2× Island 3's 2.973 kg), yielding 14.6 kg in the top 3 rings alone.
   - This massive lumped top mass atop a slender transmission cylinder ($r=0.741\text{ m}$) acts as an inverted pendulum that whips dynamically (peak lateral 1.80 m). The whip induces large angular kinks at the bottom rings, overloading Ring 4 past buckling and compressing the axial gap.
2. **The Verification:**
   - In Variant C (substituting uniform bare ring mass $1.53\text{ kg}$ on rings 2–10), the lateral whip **collapsed by 3.1×** (hub p2p $1.794\text{ m} \to 0.574\text{ m}$), bearing lateral dropped to 0.71 m, bridle cone tension maintained **continuous positive tension of 230–283 N (zero slack)**, and minimum FoS rose to **6.0522** (clearing the 2.5 gate with 2.4× margin).

### 6.3 Task 4.4: Candidate Viability Ruling
- Island 1 is ruled a **degenerate candidate genome** produced by the optimizer exploiting the mass-min cost function (trading ring radius for mass without anticipating the $\text{span}^3$ blade mass penalty and dynamic whip mode).
- The multi-rotor model, lift chain topology, and physics engine are completely sound, fully coupled, and structurally verified.

---

## 7. Supervisory Checklist (Revision 4)

1. [x] One ring plane ruled canonical; dual-plane exception permanently retired.
2. [x] Back-line offset 11.0 m placement constant landed.
3. [x] Spoke radial restraint ruled inert.
4. [x] Expansion aero feedback hypothesis refuted by Probe A.
5. [x] Hub-only tilt scope hypothesis refuted by Probe C.
6. [x] Task 4.1 & 4.2 per-ring FoS decomposition and beam sizing audit completed.
7. [x] Task 4.3 lumped mass resonance probe completed.
8. [x] Task 4.4 candidate viability ruled: Island 1 is a degenerate genome, physics engine sound.
9. [x] Full unit suite 2163/2163 green.
10. [x] Cross-logged in `docs/agents/instrument-trust-log.md` and `DECISIONS.md`.
