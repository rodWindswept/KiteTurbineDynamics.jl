# Axial length in the genome — wind shear & ground clearance section (aero-worker)

**Status:** section draft for the axial-length genome doc. **No code change.** Date: 2026-10-03. **Rulings recorded 2026-10-03 (§6).**
**Builds on:** `docs/plans/2026-09-10-axial-length-wind-reference-study.md` (prerequisite — read first)
and `docs/plans/2026-10-03-axial-length-mass-preload.md` (science-worker, §2 mass, §3 preload).
This section owns the **shear** and **clearance** half of the onshore/continental case Rod named —
"ours is sitting very close to the ground, fine offshore, not so in the continent."

---

## 0. Scope — what this section does and does not re-derive

Not re-derived here: `tether_length` was never a free gene (study §2.1). **Corrected since the
2026-09-10 study — and this correction is load-bearing for the whole report:** length is *not*
power-neutral by the `h_ref` argument. `h_ref` is frozen at 9.412 m for every L (only `tether_length`
is overridden in `params_at_length`), so the hub is **not** pinned at 11 m/s and the top rotor's wind
*rises* with L under 1/7 shear (§2.3). Whether L buys power is exactly what the wind-reference ruling
(§6.1) decides — not a settled fact. This section treats it as open and asks the *layout* question:
**what does L do to how close the rotors sit to the ground, and to how much wind each rotor sees —
and what has to change for a continental onshore machine.**

One framing correction to carry forward, agreed with @science-worker: clearance is **`L · sin(elev)`,
not `L` alone**, and elevation is hardcoded 30°. That single fact dominates everything below.

---

## 1. Ground clearance today — already computed, already gated, but only in the harness

### 1.1 There is a single clearance authority

`lowest_rotor_clearance(dec; ground_offset=1.0, elevation_deg=30.0)` — `src/objective_v10.jl:386-426`,
wired as the single authority by DECISIONS [2026-08-26] "Ground-clearance authority" (it replaced four
duplicated offset-only copies). It returns the minimum tip altitude over all active rotors:

```
alt_tip = ground_offset + (z − tip·sin(bank))·sin(elev) − (r_ring + tip·cos(bank))·cos(elev)
```

Three couplings are visible in that one line, and all three matter for the length question:

| term | what it does | length relevance |
|---|---|---|
| `(z − tip·sin(bank))·sin(elev)` | raises the tip with shaft distance × elevation | **L enters only through `z` and `elev`** |
| `− (r_ring + tip·cos(bank))·cos(elev)` | the rotor disc is ⊥ the inclined shaft, so its **radial extent dips the outer tip below the ring's shaft-line altitude** | the tip drops by the *absolute* radius, not the offset |
| `+ ground_offset` | a flat 1.0 m "above deck" offset | see §1.3 — this is a scalar, not a site spec |

The docstring's own trap-warning: the tip is the **absolute** `r_ring + tip`, never `tip` alone — the
offset-only form over-counted clearance by the ring radius (the 08-24 settle-ω-scan class). That is
exactly why "close to the ground" is a *model-computed* property, not a rough feeling.

### 1.2 The live numbers

From the 5 kW campaign runner `scripts/run_v13_5kw_masslift.jl:73-76` (also `ode_gate_v13.jl:23-27`,
`run_v12_5kw_v3.jl:33-36`):

```
ELEV          = π/6            # 30°, frozen in SystemParams
GROUND_OFFSET = 1.0   m        # bearing/ground-station offset above deck
MIN_CLEARANCE = 1.5   m        # HARD GATE on lowest active rotor tip
```

Hub altitude = `L·sin(30°)` = 18.8 · 0.5 = **9.4 m** at 5 kW (`objective_v10.jl:306`). That is the
**top** of the shaft. The lowest active rotor sits far below it — its outer tip is pulled down by the
`− (r_ring + tip·cos(bank))·cos(30°)` term, so the machine's actual ground clearance is the 1.5 m
gate, not 9.4 m. The transmission cylinder runs at `r_bottom ≈ 0.797 m` and the hub at `r_hub ≈ 3.835 m`;
even the lowest ring's radial extent alone is a metre-class subtraction. **A machine whose hub is
9.4 m up is, by construction, flying its bottom rotor a rotor-radius-plus above the deck.** That is
the property Rod is seeing.

### 1.3 The gate lives in the harness, not the objective

`lowest_rotor_clearance` is a **post-hoc hard gate** in the campaign scripts
(`run_v13_5kw_masslift.jl:255-256`, `run_v12_5kw_v3.jl:144-145`, `ode_gate_v13.jl:135`, flagged in
`sweep_power_split.jl:73-75`). It is **not** a term in the objective the DE minimises. The optimiser
never *sees* clearance — it proposes, the harness rejects. Two consequences for a clearance-driven
length gene:

- the DE cannot trade clearance against mass/power *smoothly*; it can only collide with a wall;
- `GROUND_OFFSET = 1.0` and `MIN_CLEARANCE = 1.5` are scalars, not site parameters. A continental
  onshore machine over trees/buildings needs a real obstacle-clearance spec (metres, not 1.5 m), and
  nothing in the model knows the site.

---

## 2. Wind shear — one law after D1 (the pre-D1 two-profile split is retired), and a `h_ref` that is frozen at 9.412 m

### 2.1 One law, retired two-law split — D1 lands it, three closures lag

Pre-D1 the repo carried **two** shear laws, and they disagreed (study §2.2):

| path | law | site (pre-D1) | notes |
|---|---|---|---|
| ODE wind field | Hellmann **1/7** | `objective_evaluator_ramp.jl:79` + `objective_evaluator.jl` (`WIND_MS·(z/p.h_ref)^(1/7)`) | the machine actually simulated |
| decoder per-rotor sizing | power law **0.14** | `objective_v10.jl:92-98` (`wind_speed_at_ring`) | BEM-sizes the rotors |

**The D1 un-park land retires both halves of the split** (branch `d1-site-wind-landing`, merge
green-lit 2026-10-03, not yet merged): `WIND_MS` is retired and the ODE closure becomes
`wind_at_altitude(p.v_wind_ref, p.h_ref, z)`; `wind_speed_at_ring` (the 0.14 / 50 m profile) is
retired and the ring-sizing loop becomes `wind_at_altitude(v_rated, p.h_ref, ring_altitude)` — the
same function the ODE calls. One law, **1/7**, read from the named site standard
`SITE_DAISY = WindSiteSpec("Tulloch, Daisy (measured)", 10.0, 4.8, 1/7)` (`src/wind_profile.jl`).

**The gap D1 does not close** (aero-validator 2026-10-03, verified in source): three closures still
hardcode the bare literal `(z/p.h_ref)^(1/7)` and never read the site spec — `src/sim_runner.jl`
(6×, the dashboard rerun factories), `src/visualization.jl` (7×), `src/control_map_hunt.jl` (3×).
They thread the *speed* but not the *exponent*, so a non-anchor `at_site(...)` re-base would move the
ODE and decoder while these silently kept flying 1/7. After D1 it is therefore **one law in three
paths — read from the spec in two (ODE, decoder), hardcoded as a literal in the third (sim /
visualization / control closures)**. It does not touch the length sweep (ODE path only) and does not
block the merge; it rides with the sweep's code window.

### 2.2 The decoder `h_ref = 50 m` default bug — fixed by D1 (same slice as §2.1)

`wind_speed_at_ring(ring_z, hub_altitude, v_ref; h_ref=50.0, shear_exp=0.14)` was called with
**three** arguments from the genome's ring-sizing loop (`objective_v10.jl:349`), so `h_ref` fell back
to its 50 m default rather than `p.h_ref` = 9.412 m (study §2.4). The decoder therefore BEM-sized
rotors for a different hub wind than the ODE drove them with. That is the **Defect D split**: ring-
sizing ran on the `h_ref = 50.0` default while the ODE flew on `p.h_ref = 9.412` — two shear
references live at once, and report 2 must not quote either number as *the* shear reference without
naming the split. It was *silent at fixed L* and *amplified by any L gene*.

**D1 closes it** by retiring `wind_speed_at_ring` and routing the ring-sizing loop through
`wind_at_altitude(v_rated, p.h_ref, ring_altitude)` — one profile, one reference, one exponent. The
only residual after D1 is the three literal-hardcoding closures named in §2.1, not a second shear
law.

### 2.3 `h_ref` is **frozen** at 9.412 m — the hub is *not* pinned, and length's power effect is open

`params_at_length(L)` passes Daisy's `h_ref = 5.155 m` straight through into `mass_scale`
(`run_v13_5kw_masslift.jl:129`), which multiplies it by `geom_scale = (5/1.5)^(1/2) ≈ 1.826`
(`parameters.jl:601`) → **9.412 m**, then overrides *only* `tether_length = L` (`:137`). So `h_ref`
depends on the **power class** (5 kW → fixed geom_scale), **not on L** — it reads 9.412 m for
L = 18.8, 25, 30, 40, 60 m (measured `scratch/av_probe_href_vs_L.jl`). The 2026-09-10 study's claim
that "`h_ref` scales with L" is wrong, and with it the "hub is pinned at rated 11 m/s / length buys
no power" conclusion.

Consequence, opposite to the study: the hub is **not** pinned. Under Hellmann 1/7 the top rotor's wind
*rises* with length — `11.0·(L·sin30°/9.412)^(1/7)` climbs ≈ 10.998 → 12.981 m/s from L = 18.8 → 60 m —
so **as the model stands, length *does* buy power at the top rotor.** The power-neutral picture holds
only if the reference is re-anchored to the hub (`h_ref = L·sin(elev)`), which pins the hub at 11 m/s
and makes added length only add low-wind rotors below it. **The two conventions bracket the answer —
and that is precisely the §6.1 ruling**, which must be made before report 2 asserts anything about L
and power. The already-exported `hub_altitude(L, elev)` (`wind_profile.jl:44`) is the authority to wire
for the hub-reference branch, but it is currently shadowed by two local variables of the same name
(`objective_v10.jl:306`, `:509`) — rename those first.

---

## 3. The aero coupling nobody has flagged yet: **bank eats clearance**

The bank angle is a *gene* (`x[7]/x[8]`, later `x[11]/x[12]`, clamped 0–25°), and it appears in the
clearance formula in **two** signs that both reduce clearance:

- `− tip·sin(bank)` — bank swings the outer tip **down-shaft**, toward the ground station;
- `+ tip·cos(bank)` — this is inside `(r_ring + tip·cos(bank))·cos(elev)`, the radial-extent term, so
  bank *also* widens the radial extent that dips the tip down.

`test/test_wind_blocking.jl:111-112` asserts exactly this: a banked rotor has **lower** clearance than
an unbanked one at the same position. Consequence that matters for the current campaign: **the
bank-derate winner (bank up to 25°) is the worst case for clearance, not just for power.** The same
gene that costs 15–17 % on power (the Betz/derate gap the gate is currently closing) is also the gene
pushing the bottom rotor tip down toward the 1.5 m floor. Clearance and bank are not independent —
they are the *same* degree of freedom, and any L gene that re-sorts bank (it will — §4 of the
mass/preload section shows L moves the `target_Lr` ceiling and the `n_lines` floor) will move the
clearance gate in lockstep.

---

## 4. Onshore vs offshore — why "close to the ground" is fine in one and not the other

The model's site assumptions are hardcoded and all describe **offshore-like open terrain**:

| site knob | current value | offshore reality | continental reality |
|---|---|---|---|
| Hellmann exponent | 1/7 (open flat terrain) | smooth sea → even flatter (α ≈ 0.10) | trees/buildings/hills → α ≈ 0.20–0.30, steeper shear |
| turbulence intensity | 0.15, "typical onshore Class A" (`wind_profile.jl:99`) | lower over water | higher, plus gust/building-wake forcing |
| clearance spec | 1.5 m flat gate | wave-height clearance is the constraint, no obstacles | obstacle clearance (trees, fences, structures, people) is metres |

The cleanest statement of the tension: **offshore, a low hub costs you shear that is gentle and a
clearance floor that is a wave; continental, a low hub costs you shear that is steep (the lower rotors
sit in the roughness layer) and a clearance floor that is an obstacle.** The *same* 18.8 m / 30°
geometry that is acceptable offshore is, onshore, simultaneously in the steepest part of the shear
profile and below any plausible obstacle-clearance target. That is the concrete meaning of Rod's
observation, and it is why the fix is not "add L" but "add a *site*: shear exponent, TI, and a
clearance spec."

---

## 5. Complexity & planning — what a clearance-aware L gene actually touches

1. **Fix the decoder `h_ref = 50` bug first** (§2.2, study §2.4). Any L gene that leaves it in place
   will size rotors for the wrong hub wind, and the error grows with L.
2. **Promote clearance from harness to objective.** Move the gate from `scripts/…` into the objective
   as a continuous penalty/constraint so the DE can *trade* clearance against mass/power instead of
   colliding with a post-hoc wall. Without this, a freed L will repeatedly walk into the 1.5 m gate
   and the optimiser won't learn why. **RULED 2026-10-03: promote if it makes the search more
   efficient (§6.4).**
3. **Turn `GROUND_OFFSET` / `MIN_CLEARANCE` into site parameters.** Today they are scalars (1.0 m /
   1.5 m) describing an offshore deck. A continental machine needs a real obstacle-clearance target;
   that number is a *deployment* input, not a machine constant. **ON HOLD 2026-10-03: stay
   consistent, no continental site spec now (§6.3).**
4. **Elevation is the second lever, and it is frozen.** Clearance = `L·sin(elev)`. L alone raises the
   hub and *grows the stack*, but the lowest rotor stays low until either L is very long (ring-mass
   cost — science-worker §2.2) or `elev` rises. Altitude *without a tower* is `L·sin(elev)`, and the
   "without a tower" part is what elevation buys for free that L buys expensively. See ruling §6.2.
   **RULED 2026-10-03: the elevation lever is rejected — cos³ losses above ≈ 30° (§6.2).**
5. **Shear exponent + TI as site knobs.** §4's table is hardcoded. A continental machine needs `α` and
   `TI` set from the site, or the model will keep optimising for open-flat-terrain winds that the
   continent does not have. **ON HOLD 2026-10-03: stay consistent to the current site nature (§6.3).**

---

## 6. Rulings (owner: aero-worker; ruled by Rod 2026-10-03 — cross-ref science-worker §5)

1. **Wind reference — RULED: keep the frozen anchor.** (the master ruling, shared with
   science-worker §5.1 and software-worker §5.1.) Rod chose **Option A**: `h_ref` stays frozen at
   9.412 m, the top rotor climbs as the shaft grows and sees stronger wind — ≈ 11.0 → 12.98 m/s over
   L = 18.8 → 60 m — so **length buys power at the top rotor**. The hub-reference convention
   (`h_ref = L·sin(elev)`, power-neutral) is superseded. This is direction-independent of the Defect D
   fix: the 50 m decoder anchor still must die, and the ODE and ring-sizing halves must read one site
   standard — the D1 un-park land, merge green-lit 2026-10-03 separately. *(Terminology: Rod notes
   "hub" is a misnomer — it is the main/topmost rotor; stop calling the top rotor "hub".)*
2. **Which lever raises continental altitude — RULED: not elevation.** Raising elevation is not free:
   cos³ losses in rotor power seriously kick in above ≈ 30° elevation (Rod 2026-10-03). The frozen-30°
   `elev` lever is therefore **rejected** as the cheap altitude fix; the cheaper directions are more
   (skinny) rotors, or staying offshore. "Free the frozen `elev`" is closed.
3. **Continental clearance target — RULED: stay consistent.** Clearance stays the 1.5 m flat gate; we
   assume it stays consistent ("clearance is clearance"). Continental modelling would carry much weaker
   wind than the Stornoway/offshore site, so the model stays consistent to the current offshore-like
   nature for now — no new continental obstacle spec (§5.3, §5.5 on hold).
4. **Clearance as objective vs harness gate — RULED: promote if it helps the search.** Rod's test is
   efficiency: promote clearance from the post-hoc harness gate into the objective **if and only if**
   it makes the space search more efficient (the DE can then *trade* clearance against mass/power
   instead of colliding with a wall). aero-worker to confirm the efficiency case and implement.

Code changes stay queued behind the D1 merge pass and the fixture re-baseline (work-division §6);
this section now has its decisions, so its planning items (§5) are unblocked for when the sweep
launches.
