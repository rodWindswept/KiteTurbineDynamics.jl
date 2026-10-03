# Axial length in the genome — decode & builder section (software-worker)

**Status:** section draft for the axial-length genome doc. **No code change.** Date: 2026-10-03.
**Builds on:** `docs/plans/2026-09-10-axial-length-wind-reference-study.md` (prerequisite) and the
mass/preload + shear/clearance sections written today. This section covers only the *mechanical*
cost of promoting L from a keyword to a gene: what the decoder, the dimension checks, and the
builder must change, and where the traps are. All sites below were read from source this morning,
file:line exact.

---

## 0. One correction to the framing

"Genome 10-D → 11-D" is **not a free slot.** The evaluator family already accepts an 11th field —
and it is **already claimed.** `evaluate_windowed` / `with_k_bracket` / `evaluate_ramp` all gate on
`length(x) in (TRPT_V10_DIM, TRPT_V10_DIM+1, TRPT_V10_DIM_LEGACY, TRPT_V10_DIM_LEGACY+1)`
(`objective_evaluator.jl:643-644`, `:1188-1189`, `objective_evaluator_ramp.jl:45`). That `+1` is
`k_mppt`, the sidecar field the campaign pins on the genome (`view_campaign_genomes.jl:11`
"k_mppt left the vector on"; re-clamped separately at `objective_evaluator.jl:678`).

Crucially, `canonical_v10` **strips it** — `x[1:TRPT_V10_DIM]` (`objective_v10.jl:146`) drops the
11th field before decode. So the naive change "append L as `x[11]`" is a **silent no-op**: the field
enters the length check, then is discarded by `canonical_v10`, and the machine builds at whatever
keyword L the caller passed. Nothing errors; nothing changes. Promoting L to a gene is therefore
**not** additive — it is a *re-layout* of the genome with an era bump, because the 11th position is
occupied and the strip point must move from 10 to 11.

---

## 1. Where L enters the decode/build chain today

`p.tether_length` → `design.tether_length` is threaded by `design_from_vector_v5`
(`objective_v10.jl:232`). The decode-and-build surface that touches L:

| site | what L does | line |
|---|---|---|
| `params_at_length(p2, L, KW)` | builds `GeometrySpec` at L, `mass_scale`s from the Daisy 1.5 kW anchor, then **restores L** after rung scaling | `scripts/ode_gate_v13.jl:39-53` |
| LENGTH FIX | `mass_scale` scales tether_length by `geom_scale` — without the restore, `params_at_length(18.8)` silently built a **34.3 m** machine | `ode_gate_v13.jl:50-53` |
| `decode_winner` | length-branching gene rounding — `if length(xv) >= 14` rounds `x[8]/x[10]`, else `x[4]/x[6]` | `ode_gate_v13.jl:110-116` |
| `design_from_vector_v10` | 10-D → 14-D normalisation, `rotor_count_mode`/`cylinder_cone` knobs | `objective_v10.jl:186-215` |
| cylinder+cone geometry | `harvest_length`, `cone_length`, `taper_start_z` all clamp against `design.tether_length` | `objective_v10.jl:253-269` |
| `ring_spacing_v5` | takes `tether_length` explicitly; `max_rings=20` hard cap | `ring_spacing.jl:149-157` |
| local `hub_altitude` | `hub_altitude = L · sind(30°)` and `= L · sin(elev_angle)` — **shadows the exported fn** | `objective_v10.jl:306`, `:509` |

---

## 2. Three decode hazards that make "add L" non-trivial

### 2.1 The `+1` slot is k_mppt, and `canonical_v10` strips it (§0)

Any L-as-`x[11]` change must, in one commit: bump the canonical width, change `canonical_v10`'s
slice, and change `_normalize_v10_14`'s expansion — otherwise the field is silently discarded.
`canonical_v10` slices `x[1:10]` (`:146`) and `_normalize_v10_14` prepends four beam genes to a
10-core (`:168-170`); both hardcode the width. This is exactly the class the repo's skill flags:
divergent copies drift on gene index. There are **three** dimension gates (`objective_evaluator.jl:644`,
`:1188`, `objective_evaluator_ramp.jl:45`) and **two** normalisers (`canonical_v10`,
`_normalize_v10_14`) to keep in lockstep.

### 2.2 `decode_winner`'s `length(xv) >= 14` is a blunt instrument

The rounding branch (`ode_gate_v13.jl:110`) treats the world as binary: ≥14 fields = 14-D, else
10-D. A **three-width** genome (10-D, 14-D, and each +1 for the L gene) breaks it. An 11-D vector
(10 + L) is `< 14`, so it rounds `x[4]/x[6]` — *correct for the 10-core* but L (`x[11]`) is never
read. A 15-D vector (14 + L) hits the `>= 14` branch and rounds `x[8]/x[10]`, again dropping L.
The guard must become width-aware (a dispatch on `length(xv)` with three cases), not a binary
threshold. This is the "length-branching decode guard" the repo landed yesterday — it is where the
11-D change lands *first*, before any physics.

### 2.3 `hub_altitude` locals shadow the exported helper

The already-exported `hub_altitude(tether_length, elevation_angle)` (`wind_profile.jl:44`, exported
`KiteTurbineDynamics.jl:67`) is shadowed by **two** local assignments in the decoder
(`objective_v10.jl:306`, `:509`). Wiring `hub_altitude(L, elev)` in place — aero-validator's §6.1
proposal — **cannot be done** until both locals are renamed, or the call silently resolves to the
local binding. Independent of L, the ring-sizing loop calls
`wind_speed_at_ring(ring_altitude, hub_altitude, v_rated)` with **three** args
(`objective_v10.jl:349`), which runs on the function's **`h_ref = 50.0` default**
(`objective_v10.jl:94`) — the "two shear references live at once" split, logged Defect D. Whether L
is power-neutral or power-positive (§6.1) cannot be asserted from either number until this shadow +
default is untangled; the fix is a rename plus an explicit `h_ref` argument, not a physics change.

---

## 3. Builder & ring spacing: L is already a first-class argument, mostly

The good news: `ring_spacing_v5(r_top, r_bottom, tether_length, target_Lr, …)` already takes L
explicitly (`ring_spacing.jl:149-152`), so the *layout* path does not hardcode 18.8 — it follows
whatever `design.tether_length` the decoder produced. Three L-dependent properties to hold in view
when L becomes a gene:

- **Three-section geometry is L-clamped.** `taper_start_z`, `harvest_length`, `cone_length` all
  clamp against `tether_length` (`objective_v10.jl:253-269`, re-clamped in `ring_spacing_v5:159-160`).
  A longer L that does not move `r_hub`/`r_bottom` simply grows the transmission cylinder — the
  ring-count channel science-worker's §2.2 named — with no new geometry code.
- **`max_rings = 20` is the hard wall.** `ring_spacing_v5` (`:156`) caps ring count, and
  `ring_spacing_v4` degrades as `L → target_Lr·r_hub`. A continuous L gene hits this ceiling before
  it hits any physics failure; the search box for L must be cut at the ring-count ceiling, not
  "18.8 ± x" (shared with science-worker §4.2).
- **`harvest_length` is `(n_rotors − 1) · target_Lr · r_hub`** (`objective_v10.jl:262`), independent
  of L — so multi-rotor stacking does not scale with length. If longer L is meant to buy *more*
  concurrent-rotor headroom, that is a separate decoder change, not a side effect of L.

---

## 4. What promoting L to a gene touches (decode/builder subset)

1. **Era bump + width change, one commit.** New constant (e.g. `TRPT_V10_DIM = 11` or an explicit
   `TRPT_V11_DIM`), update `canonical_v10`'s slice, `_normalize_v10_14`'s expansion, and all three
   dimension gates in lockstep. The `+1` k_mppt sidecar convention either stays (now 12-D total) or
   moves — decide before touching any of the six sites (§2.1).
2. **`decode_winner` width dispatch** — three cases (10/14 core, each ± sidecar), not `>= 14`
   (§2.2). Read L from the genome here and pass it to `params_at_length` instead of the CLI default.
3. **Rename the two `hub_altitude` locals** and make the `wind_speed_at_ring` call pass `h_ref`
   explicitly, so §6.1 can be wired to `hub_altitude(L, elev)` without shadowing (§2.3).
4. **`params_at_length` stays the single authority for L.** The LENGTH FIX (`ode_gate_v13.jl:50-53`)
   is load-bearing: if the gene path bypasses `params_at_length` and calls `mass_scale` directly, the
   34.3 m bug comes back. The gene value must flow *through* `params_at_length`, never around it.
5. **Builder is already L-ready** (§3) — the work is the decoder and the search box, not
   `ring_spacing_v5` itself. The `max_rings = 20` ceiling and the discrete-vs-continuous question
   (science-worker §5.4) set the box, not the builder.

---

## 5. Rulings & open rulings (decode/builder-relevant; owners as marked)

1. **Wind reference (§6.1) — shared, RULED 2026-10-03 (Rod): keep the frozen anchor.** `h_ref` stays
   9.412 m for every L; the top rotor climbs with the shaft and sees ~11.0 → 12.98 m/s over
   L = 18.8 → 60 m, so **length buys power at the top rotor**. Hub-reference (`h_ref = L·sin(elev)`)
   is superseded. The decode-side fix already landed (D1): `wind_speed_at_ring` and its
   `h_ref = 50.0` / `shear_exp = 0.14` default are retired; the decoder reads
   `wind_at_altitude(v_rated, p.h_ref, z)` with `v_rated = p.v_wind_ref`. (Terminology: "hub" is a
   misnomer for the topmost rotor — the shaft carries many rings, the top ring carries the main rotor.)
2. **Era naming / sidecar position — owner software-worker.** Does L become `x[11]` (replacing
   k_mppt's sidecar) or does k_mppt stay and L becomes the *second* sidecar? This determines the
   width dispatch in §4.2 and whether old 11-D CSVs remain readable.
3. **Discrete vs continuous L — shared with science-worker §5.4.** `params_at_length` implies a
   small discrete set; a continuous gene changes the DE character and hits `max_rings=20` awkwardly.
   Decide before wiring the box.
