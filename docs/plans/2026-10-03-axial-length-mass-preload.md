# Axial length in the genome — mass & preload section (science-worker)

**Status:** section draft for the axial-length genome doc. **No code change.** Date: 2026-10-03.
**Rulings landed 2026-10-03 — all four**: §5.1 wind reference → frozen anchor; §5.2 elevation →
rejected; §5.3 tether diameter → same line everywhere (with a FoS-flag watch); §5.4 L → discrete set.
**Builds on:** `docs/plans/2026-09-10-axial-length-wind-reference-study.md` — that study is the
prerequisite; read it first. This section deepens its §4 "mass/lift feedback" guard and its §2.3
"h_ref" finding into the full mass/preload picture. **Corrected 2026-10-03** on three points from
aero-validator and software-validator (§0, §1.1, §2.2).

---

## 0. One correction to the framing — and a correction to that correction

`tether_length` is **not** a "missing gene" — the 2026-09-10 study already answered that: it was
**never** a free gene, it is a Daisy-anchored, power-class-scaled parameter set by
`params_at_length(L)` (`scripts/run_v13_5kw_masslift.jl:134-148`, `L = 18.8` m at 5 kW).

**The "length buys no power" claim has the mechanism backwards.** The 2026-09-10 study's §2.3 reads
as if `h_ref` scales with L; it does not. `params_at_length(L)` overrides **only** `tether_length`
(`run_v13_5kw_masslift.jl:137`); `h_ref` falls out of `mass_scale` (the power-class geom_scale) and
is **frozen at 9.412 m for every L** — measured by aero-validator: 9.412 m at L = 18.8, 25, 30, 40,
60 m, while the actual hub altitude `L·sin30°` climbs 9.4 → 30 m. So the hub is **not** pinned at
11 m/s: under the frozen anchor the top rotor's wind *rises* with length (10.998 → 12.981 m/s from
18.8 → 60 m) via the Hellmann 1/7 shear. **Length buys power** — this is now the *recorded* convention,
not an open fork: §5.1 was ruled 2026-10-03 to the frozen anchor (Option A), and the hub-reference
convention (`h_ref = L·sin(elev)`, hub pinned at 11 m/s, length power-neutral) is **superseded**.
The two-pictures-at-once split (Defect D) is closed by the D1 merge. This section states the
mass/preload consequences under the frozen anchor; all four §5 rulings are now landed.

---

## 1. Where L enters the mass and preload models today

L lives in `p.tether_length` (SystemParams), threaded into `design.tether_length`
(`design_from_vector_v5` at `objective_v10.jl:232`, `design_from_vector_v4` at
`ring_spacing.jl:495`). The mass/preload models read it in exactly these places:

| consumer | site | what L does |
|---|---|---|
| tether mass / rope linear density | 8 sites, 6 files (§1.1) | `m_tether = n_lines · L · ρ·π(d/2)²` — linear in L |
| ring layout | `ring_spacing.jl` `ring_spacing_v4/v5` | n_rings is an **output** of (r_top, r_bot, L, target_Lr) |
| hub altitude / shear | `objective_v10.jl:306` | `hub_altitude = L · sind(30°)` (a *local*, shadowing the exported fn — §5.1) |
| shaft length / anchors | `initialization.jl:914-916, 1137, 1162` | bearing/sky/back positions |
| preload budget | `initialization.jl:1341` | `T_top = T_thrust + n_lines·T_bridle·cosθ − W_rotor·sinβ` |

### 1.1 Duplicate-representation hazard — the tether-mass expression is 8 sites, not 2

`m_tether = n_lines · L · ρ·π(d/2)²` is written **eight times** in `src` across **six** files
(verified by aero-validator and software-validator; my original "2" was wrong, and both my original
line numbers were off by one):

| file | site(s) | note |
|---|---|---|
| `expansion_analysis.jl` | `:49`, `:172` | the `expansion_airborne_mass` term + the telemetry field |
| `trpt_optimization.jl` | `:510` | inside the sizing fixed-point |
| `lift_kite.jl` | `:778` | |
| `initialization.jl` | `:211`, `:270` | sub-length (segment) variant |
| `objective_v10.jl` | `:674` | **the scored path** — the v10 objective's feasible return, i.e. the 19.45 kg scored mass; hardcodes `970.0` not `DYNEEMA_DENSITY` |
| `objective_v6.jl` | `:753` | same hardcoded `970.0` |

Two of the eight are the **scored path** and both hardcode `970.0` rather than `DYNEEMA_DENSITY`
(`parameters.jl:4`; itself declared a second time at `economics.jl:11` as a deliberate module-local
copy). When L becomes a gene, "collapse to one authority" must reach **all eight** — a literal-only
sweep keyed on the `DYNEEMA_DENSITY` symbol misses the two that matter most.

**The atom to collapse is rope linear density, not "tether mass".** Every one of the eight sites,
the `initialization.jl` sub-length variant, and ~20 EA/tension sites (`ring_forces.jl:457`,
`initialization.jl:170/199/2446`) recompute `ρ·π(d/2)²`. A single `rope_linear_density(p)` (or
`rope_area(p)`) picks up all of them, literals included; a `tether_mass(p)` helper does not. That is
the refactor that survives L becoming a gene.

---

## 2. Three mass channels, with their scaling laws

### 2.1 Tether mass — linear in L, minor

`m_tether = n_lines · L · ρ·π(d/2)²`. At the bank-derate winner (n_lines = 3, L = 18.8 m,
d = 3 mm default, ρ = 970 kg/m³):

    m_tether = 3 · 18.8 · 970 · π·(0.0015)² ≈ 0.39 kg  ≈  2.0 % of the 19.45 kg scored mass

Directly proportional to L — but it is the *smallest* channel. (If the campaign ran d = 2 mm it is
~0.17 kg, ~0.9 %; either way immaterial.) Tether diameter is itself a fixed SystemParams constant,
not a gene — a longer/heavier stack may need a thicker tether, which is an open item (§5.3).

### 2.2 Ring count and ring+knuckle mass — the dominant channel, ~linear but discrete

The ring layout enforces **L/r ≈ target_Lr** per segment (`ring_spacing.jl` header). `n_rings` is
derived, not chosen. The winner runs cylinder+cone (`cylinder_cone` on, `n_rotors = 1`, so
`harvest_length = 0`), giving a transmission cylinder at `r_bottom = 0.797 m` for
`L_trans = L − cone_length`, then a 22°-bounded cone to `r_hub = 3.835 m`:

- cylinder section segment length: `L_seg = target_Lr · r_bottom = 2.10 · 0.797 ≈ 1.67 m`
- `target_Lr` is **pinned at its 2.10 ceiling** this run — so this is the *tightest* ring packing the
  genome currently allows.

Consequence: **increasing L at fixed target_Lr adds a transmission-cylinder ring roughly every
~1.7 m** (`Δn_rings ≈ ΔL / 1.67`), each ring adding `ring_beam_mass(Do, t/D, n_lines, L_poly)`
(Euler-buckling sized via `size_beams_closed_form`) plus `n_lines · knuckle_mass_at_ring`.
Ring + knuckle mass is where the scored mass lives, so **this is the channel that moves the score**.

**Caveat (aero-validator):** the ~1.67 m/ring constant is the **cylindrical-section limit**. Inside
the cone the segment count is `n_segs = log(r_bot/r_top) / log(k_natural)`, responding to L through
`α = (r_top − r_bot)/L` (the taper slope) — *not* linearly. Ring count does rise ~linearly with L at
fixed section radius (measured 2 → 4 → 6 rings for 18.8 → 30 → 40 m), but a per-metre ring cost
quoted across the cone must be re-derived there, not extrapolated from the cylinder limit.

### 2.3 Taper-kink relief — L trades against ring mass, opposite sign

The signed kink compression `F_kink = T · Δr / line_len`, with
`line_len = √(L_seg² + Δr²)` (`trpt_optimization.jl:385-400`). Longer L → larger `L_seg` **and**
smaller per-segment `Δr` (same total radius step spread over more rings) → gentler taper → less
kink → **lighter rings per ring**. So L pulls ring mass two ways at once: more rings (2.2) but
lighter rings (2.3). The net sign is not analytically obvious — it is exactly the kind of
re-sorting the campaign exists to resolve, and it is why L as a gene will re-read the walls below.

---

## 3. Preload budget — L is nearly invisible at the shaft, but feeds the lifter floor

The TRPT shaft tension decomposes as (`initialization.jl:1341`, measured `scratch/sv_probe_preload_budget.jl`):

| term | winner value | L-dependence |
|---|---|---|
| `T_thrust` (main-rotor disc) | +1562.3 N (91.8 %) | **none** — rotor thrust is set by swept area, bank, wind |
| `n_lines · T_bridle · cosθ` | +154.9 N | none |
| `−W_rotor · sinβ` (β = 30°) | −15.2 N | **only** via `W_rotor`, which includes tether + ring mass |
| `F_top` (shaft) | **1702.1 N** | ≈ L-invariant |

`F_top` is thrust-dominated, so the shaft tension barely moves with L — the implied
`MTR = τ/(r_hub·F_top) = 0.0492 ≈ 0.05` is stable. **Length is not a shaft-tension lever.**

The real preload coupling is the **lifter tension floor**:

    T_lift_line = 1.5 · m_air · 9.81 / sin(70°) / n_lines

where `m_air` *includes* tether + rings + knuckles — i.e. everything in §2. Longer L → heavier
stack → higher lifter floor → higher per-ring preload → heavier rings (via the sizing FoS), which
loops back into `m_air`. This is the "mass feeds preload" loop. It is absorbed by the
`n_mass_passes = 3` fixed-point in `size_beams_closed_form` (`trpt_optimization.jl:375-477`), but
**3 passes is tuned at L = 18.8 with 10 rings**; a longer shaft means more rings and a larger
feedback, and convergence has not been checked there. That is the §4 guard from the 2026-09-10
study, now with a mechanism.

Elevation is hardcoded **30° = π/6** everywhere (`elev_rad = π/6` at `trpt_optimization.jl:306`,
`sind(30.0)` at `objective_v10.jl:306`, `β = 30°` in the budget). So hub altitude = `L · sin(30°)`
today — **clearance is a pure multiple of L only while elevation stays pinned.** The onshore case
Rod named (altitude without a tower) is, in the current model, `L · sin(elevation)`, not `L` alone.

---

## 4. What promoting L to a gene touches (mass/preload-relevant subset)

1. **Not a free slot, and not a 10-D → 11-D add.** The evaluator already accepts an 11th field —
   `k_mppt`'s sidecar (`objective_evaluator.jl:643-644, :1188`) — and `canonical_v10` strips it
   (`x[1:TRPT_V10_DIM]`, `objective_v10.jl:146`) before decode. A naive "append L as `x[11]`" is a
   silent no-op. Promoting L is a **re-layout with an era bump** (software-worker,
   `docs/plans/2026-10-03-axial-length-decode-builder.md`); from the mass/preload side the only
   requirement is that every tether-mass authority in §1.1 reads the gene value.
2. **Search box for L** needs a measured basis — same discipline as `MIN_RING_DO_M` /
   `SIZING_FOS_MARGIN` (both currently bind). `ring_spacing_v4` degrades as `L → target_Lr·r_hub`;
   there is a `max_rings = 20` hard cap the gene can hit. Bounds are not "18.8 ± x" — they must come
   from the short-L degenerate guard and the max_rings ceiling.
3. **Fixed-point convergence** (`n_mass_passes`) must be re-verified at longer L (more rings, larger
   mass→lifter feedback), not assumed from the 18.8 m tuning.
4. **Re-read the walls.** Today's four-harness floor reads: n_lines at 3 (floor), rotor count at 1
   (floor), ring spacing at 2.10 (ceiling), blade scale interior at 0.6994. All four re-sort when L
   is free — the ring-count channel (§2.2) moves the target_Lr ceiling, and the kink relief (§2.3)
   moves the n_lines floor.

---

## 5. Rulings (owner: science-worker) — all four landed 2026-10-03

1. **Wind reference → RULED 2026-10-03: frozen anchor (Option A).** `h_ref` stays **9.412 m** for
   every L; the top rotor climbs with the shaft and sees **11.0 → 12.98 m/s over L = 18.8 → 60 m**,
   so **length buys power at the top rotor**. Hub-reference (`h_ref = L·sin(elev)`) is **superseded**.
   This is exactly the "length buys power" picture §0 already stated; it is now the recorded
   convention, not an open fork. *(Terminology, shared with aero-worker §6.1: "hub" is a misnomer
   for the topmost rotor.)*
   **Defect D is closed by the D1 merge** (`6f4cdbe`, landed as `f9f3182` on
   `origin/bank-derate-cos2p65`): the decoder's `h_ref = 50.0` default and the `0.14` shear exponent
   are retired, and both ODE and decoder now read the one site spec `SITE_DAISY` (10.0 m/s @ 4.8 m,
   α = 1/7). The split "sized at 50 m, flown at 9.412 m" no longer exists. Residual (not mine, not
   blocking the merge): `sim_runner.jl`, `visualization.jl`, `control_map_hunt.jl` and 8 sweep
   scripts still hardcode a bare `(z/p.h_ref)^(1/7)` literal instead of reading the spec — aero-validator
   owns the exponent-identity guard; it rides with the sweep's code window. *(The `hub_altitude`
   local-shadowing note at `objective_v10.jl:306`/`:509` still stands as a rename-before-wiring caveat
   for any L gene.)*
2. **Elevation as a second gene → RULED 2026-10-03: rejected as the altitude lever.** cos³ losses
   kick in hard above ~30° elevation, so "free the frozen `elev`" is closed. Clearance stays
   `L · sin(30°)` with elevation pinned; no second gene. Cheaper altitude directions Rod named:
   **more skinny rotors, or staying offshore.** *(The radians-not-degrees trap on `elevation_angle`
   remains worth a guard if anyone ever touches that constant.)*
3. **Tether diameter → RULED 2026-10-03: same line everywhere for this 5 kW run.** Fixed diameter
   (3 mm nominal / 3.65 mm at the 5 kW scale), not a gene, not scaled with L. Rationale: line tension
   is thrust-dominated and ~length-invariant (`F_top ≈ 1702 N`, §3), and tether mass is ~2 % of the
   scored machine. **Watch added (Rod):** instrument the sweep for any case where the *tether itself*
   becomes the weakest link — and flag those designs so the genomic area can be re-explored later with
   a reliable (thicker) tether. **Instrument, pinned (aero-validator):** the signal is
   `SimFrame.fos_tether = TETHER_SWL/T_max` (`sim_frame.jl:165`, SWL 3500 N, the ODE's actual max rope
   tension), compared against `fos_ring` — *not* Gate 4's `T_per_line` (`objective_v10.jl:622`, a
   thrust proxy, and shared with a `+1e6` sentinel that can't separate line-weak from ring-buckled).
   The evaluator path (`objective_evaluator.jl`) has **no** line-FoS at all — only ring buckling — so
   the flag must come from the frame, not the score. Expected: empty flag across L at fixed 3 mm
   (tension is thrust-dominated and length-invariant); an empty flag is the evidence that **diameter,
   not length**, is the axis to re-open as a gene. This keeps §1.1's
   collapse-to-one-authority (`rope_linear_density`) a *deferred* refactor, not a launch gate.
4. **Discrete vs continuous L → RULED 2026-10-03: discrete set.** A small set of power-class lengths
   (the 18.0 / 21.2 / 25.0 m precedent), not a continuous gene. Matches the "variants, not a whole new
   gene" steer; keeps the DE's character and cost. The ~1 h length sweep is exactly this shape. A
   continuous L gene (bounds from the short-L degenerate guard and `max_rings`) is **parked**.
