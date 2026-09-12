# Study — axial length (`tether_length`) as a genome gene, and the rated-wind reference

**Status:** scoped study — **no implementation, no campaign.** Date: 2026-09-10.
**Origin:** Rod's question in the R7–R10 remit handover
(`handovers/handover-2026-09-10-r7-r10-remit.md`, R11).
**Companion evidence:** `docs/validation/tulloch-thesis-extract.txt`,
`docs/validation/tulloch-prototype-configurations.md`,
`docs/validation/physics-validation-ledger.md` A3, `src/parameters.jl:338-372`.

---

## 1. The question

> Did we remove "axial length" from the genome for speed, and should we re-add it
> for future campaigns?

Short answer: **no — `tether_length` was never a free gene, and the v4 change
that removed the axial-profile family was a physics decision, not a speed one.**
Before re-adding *any* length axis, the rated-wind reference has to be pinned,
because as the model stands length buys no absolute power. Details below.

---

## 2. Findings (verified against source)

### 2.1 `tether_length` was never a free gene

It is a fixed, Daisy-anchored, power-class-scaled parameter. The 5 kW campaign
builds it with `params_at_length(L)` (`scripts/run_v13_5kw_masslift.jl:134-148`):
`mass_scale(params_daisy(), 1.5, KW)` scales the geometry, then `tether_length`
is restored to the requested `L` (18.8 m at 5 kW). No DE vector ever carried it.

The v4 change (`DECISIONS [2026-04-22]`, "v4 ring spacing: variable positions
targeting constant L/r per segment") replaced the `(n_rings, taper_ratio,
axial_profile)` triplet with `(r_bottom, target_Lr)`. Its rationale was
structural: uniform axial spacing with a taper gives thin bottom segments a high
L/r ratio (Euler danger zone) and pushes the optimiser to cylindrical. Constant
L/r makes the Euler FoS uniform across rings. **That is physics, not speed.**
Do not re-add the axial-profile family.

### 2.2 Wind shear: the ODE and the decoder disagree, and roughly cancel

- The ODE wind is Hellmann 1/7: `WIND_MS · (z / p.h_ref)^(1/7)`
  (`src/objective_evaluator.jl:559-562`).
- The decoder's per-rotor sizing uses a power law 0.14
  (`src/objective_v10.jl:81-95`, `wind_speed_at_ring`).
- Upper rotors see more wind than lower rotors; co-axial wake blocking
  (`BLOCKING_WIND_FACTOR_5KW = 0.75^(1/3) ≈ 0.9086`) opposes it. Over the 3–4 m
  rotor-stack span the two effects are of similar size and roughly cancel.

### 2.3 `h_ref` is the hub altitude and scales with L

`params_daisy()` sets `v_wind_ref = 11.0 m/s at h_ref = 5.155 m` (the Daisy hub
altitude, `10.31·sin 30°`; `src/parameters.jl:365-368`). `mass_scale` scales
`h_ref` by the rung `geom_scale`, so at 5 kW/L = 18.8 m it is
`h_ref = 9.41 m` — i.e. the hub, not the ground.

Consequence: the hub is pinned at rated 11 m/s no matter the length.
**Lengthening L does not buy absolute power**; it only moves the lower rotors
further below the reference, weakening them relative to the hub. That, not the
gene count, is why length is not a power axis today.

### 2.4 A second, unaddressed discrepancy: the decoder's `h_ref` default

`wind_speed_at_ring(ring_z, hub_altitude, v_ref; h_ref=50.0, shear_exp=0.14)`
(`src/objective_v10.jl:89-95`) is called from the decoder as
`wind_speed_at_ring(ring_altitude, hub_altitude, v_rated)` — with **three**
arguments, so `h_ref` falls back to its 50 m default rather than the rung's
`p.h_ref` (9.41 m at 5 kW). Measured on the 5 kW seed (R7 recon,
`scratch/r7_index_recon.jl`): the decoder reports a hub `v_wind = 7.91 m/s`
while the ODE's hub inflow is `11.0 · 0.909 ≈ 10.0 m/s`. The decoder therefore
BEM-sizes larger rotors than the machine it simulates. This is the same
reference-height question as §2.3 and must be fixed with it.

### 2.5 The published rating disagrees with the code

`docs/validation/tulloch-prototype-configurations.md:76-77` records the Daisy
published rating as **">1.5 kW @ 10 m/s"** (3-blade). The code uses **11 m/s at
`h_ref` = hub**. The rated reference itself (10 vs 11 m/s, and hub vs ground) is
the discrepancy to resolve.

### 2.6 What the thesis actually records

- The anemometer is a Vector Instruments A100L2 on a **4.8 m mast**, "similar to
  the height of the rotors centre" (`tulloch-thesis-extract.txt:6249-6251`).
  So the measured reference height is the rotor centre, not 10 m.
- `10 m/s` appears as "a representative value for the Daisy Kite wings" for the
  Reynolds-number calculation (`tulloch-thesis-extract.txt:8818`) — a design
  value, not necessarily the rated wind.
- **The handover's quote "wind speed 5.3 m/s measured at 5 m height" is NOT in
  the extract.** `5.3` only appears as a thesis section number. If that figure
  is load-bearing it must be re-sourced from the thesis body before use.

---

## 3. Study scope (in order)

1. **Adopt a standard ground reference.** 10 m is the normal meteorological
   reference. Pin the rated wind at ground level (e.g. `v_10`), and derive local
   rotor inflow from the shear profile — one profile, one reference, shared by
   the decoder and the ODE.
2. **Verify the Daisy anemometer height and rated wind** from the Tulloch thesis
   body (the 4.8 m mast is the only height in the extract). Reconcile the
   published ">1.5 kW @ 10 m/s" with the code's 11 m/s at the hub, and with the
   624 W / 146 rpm 6-blade operating point.
3. **Decide the reference convention.** Only if the reference is fixed at the
   ground does L become a real power axis, via
   `v_hub = v_ref · (L·sinβ / h_ref)^(1/7)`. If the reference stays at the hub,
   document that length is a *layout* variable (rotor stacking, clearance,
   structural mass), not a power variable, and do not add it as a gene.
4. **Fix the decoder `h_ref` default** (§2.4) as part of the same change: pass
   the rung's `p.h_ref` explicitly, and use the ODE's shear exponent (1/7) in
   the decoder, or document why the two differ.
5. **Only then design the L gene**, with the guards in §4.

---

## 4. Guards required before any L gene

Length interacts with the geometry in ways the existing bounds do not cover. Any
L gene must ship with:

- **Short-L guard.** `ring_spacing_v4`/`ring_spacing_v5` degrade as
  `L → target_Lr · r_hub`; below that the ring count collapses. Assert a
  minimum number of airborne rings.
- **`n_rings → 3` degenerate guard.** The rotor-count mode needs ring intervals
  for the harvest cylinder; too small an L (or too many rotors) leaves no valid
  placement. Reuse the existing min-rotor-spacing gate.
- **`target_Lr` exploit guard.** The confirmed `target_Lr` exploit (rings
  collapsing toward the ground) is the same class as the length-degenerate
  cases. A length gene that changes the ring count must be checked against it.
- **Mass/lift feedback.** Longer L adds tether mass and changes `h_ref`; the
  constant-tension lifter tension and the beam sizing both feed back. The
  fixed-point passes in `size_beams_closed_form` absorb this, but the guard must
  confirm convergence.

---

## 5. Open decisions for Rod

1. Ground reference at 10 m, or keep the hub reference and accept that L is not
   a power axis?
2. Rated wind: 10 m/s (published) or 11 m/s (current code)? At which height?
3. Should the decoder use the ODE's Hellmann 1/7 (currently 0.14, plus the 50 m
   `h_ref` bug of §2.4)?
4. If L becomes a gene: bounded continuous value, or a small discrete set of
   power-class lengths (as `params_at_length` already implies)?

No code changes are proposed by this study until (1)–(3) are decided.
