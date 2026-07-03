# Handover — Dashboard v2 Cockpit Refinements

**Date:** 2026-07-01
**For:** Next session (fresh start OK)
**Precedes:** `handover-2026-06-30-dashboard.md` (read that for design intent + the panel philosophy; this doc assumes it)

---

## One-paragraph state

The `--v2` cockpit now renders. On 2026-07-01 Rod compiled and viewed it at
screen: play/scrub sweep, 3D viewport, and the rotor gauge all work with live
`ExtendedSimFrame` data. He gave five refinement requests; **all five are
written** into `src/dashboard_panels.jl` and `src/dashboard_v2.jl`, plus a V10
design-selection improvement in `scripts/interactive_dashboard.jl`. **None of
today's edits are compile-verified** — the sandbox was unauthenticated (401) all
session, so Rod runs it. Expect minor Makie fixes. Decisions recorded in
`DECISIONS.md` (2026-07-01 entry).

## What changed today (files + intent)

### `src/dashboard_panels.jl`
- **`ring_health!`** — removed fixed `xlims!(ax, 0, 1.5)` and `clamp(ratio,0,1.5)`;
  handler now autoscales `xlims!(ax, 0, max(mx*1.25, 0.05))`. Bars are visible
  under light load.
- **`tension_chain!`** — handler autoscales `xlims!(ax, 0, max(mx*1.25, swl*1.15))`
  so bars fill AND the SWL line stays on-screen.
- **`torque_chain!`** — unchanged (already autoscaled).
- **`rotor_gauges!`** — centre readout changed from efficiency-% to **delivered
  kW** (big) + `aero X.X · η YY%` sub-line. `eff_obs` → `kw_obs` + `sub_obs`.
  Outer cyan arc = aero power, inner green arc = delivered. Units confirmed kW.
- **`config_panel!`** — static dropdown `Label`s replaced with real interactive
  `Menu` widgets (design / scenario / generator / payout). **Signature now
  returns a NamedTuple**: `(design, scenario, generator, payout, peak_lbl,
  state_lbl)`. Live readout lines (peak/FoS/state) unchanged.

### `src/dashboard_v2.jl`
- Layout reflowed to **6 rows × 6 cols**. The three tall bar charts sit
  **beside each other**: `fig[3,1]` torque, `fig[3,2]` ring health, `fig[3,3]`
  tension; **3D viewport widened to `fig[3,4:6]`** (the only changed line in the
  verbatim-v1 3D block: `ax3d = Axis3(fig[3, 4:6]; …)`).
- Secondary row 5: `twist_view!` (1) | `rotor_gauges!` (2) | `config_panel!` (3:4)
  | event log (5:6). Controls moved to a **full-width** `fig[6,1:6]`.
- Figure 1600×1000 → **1780×1040**. Row 3 `Auto` (tall), row 5 `Fixed(250)`,
  cols 1–3 `Relative(0.13)` so the 3D viewport is wide. Less compressed.
- Config menus wired to the event log (`on(cfg.design.selection) …` etc.).
- Removed the duplicate scenario `Menu` that used to live in the control bar.

### `scripts/interactive_dashboard.jl`
- **`build_v10_tight_no_lowest`** gained kwargs `r_bottom_scale=1.0` (scales
  design-vector `x[2]` = r_bottom) and `tether_diameter=nothing` (swaps the
  `MaterialSpec` tether diameter). Backward compatible — no-arg call unchanged.
- New **`--v10-reinforced`** flag → `build_v10_tight_no_lowest(r_bottom_scale=1.30,
  tether_diameter=0.004)` → the viable V10 (~55 kW, FoS 2.30). Wired into the
  `current_config` selection and build branch.

## Run commands

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl

# v2 cockpit on the healthy LOADED design (recommended demo — bars fill & colour)
julia --project=. scripts/interactive_dashboard.jl --v2 --v10-reinforced

# v2 on canonical (light load — bars small but now autoscaled/visible)
julia --project=. scripts/interactive_dashboard.jl --v2

# v2 on the tight winner — WORKS but dynamically dead (FoS 0.43), may diverge
julia --project=. scripts/interactive_dashboard.jl --v2 --v10-tight

# v1 dashboard (untouched fallback)
julia --project=. scripts/interactive_dashboard.jl --v10-reinforced
```

## Lessons learned this session

1. **`@lift` is a macro; `lift(...)` / `on(...)` are functions.** `@lift`
   resolves at macroexpand time (including via docstring `@doc` expansion).
   `src/dashboard_panels.jl` is `include()`d (line ~25) **before**
   `using GLMakie` in `visualization.jl` (line ~27), so a bare `@lift` there
   throws `UndefVarError: @lift not defined in KiteTurbineDynamics` at
   precompile. **Rule:** in `dashboard_panels.jl`, use only the function forms
   (`lift(f, obs)`, `on(obs)`). `dashboard_v2.jl` loads after GLMakie, so `@lift`
   is fine there. (This bit us at the first compile; fixed by converting both
   `@lift` uses in twist_view!/rotor_gauges! to `lift(...)`.)

2. **Autoscaling beats fixed limits for wildly-different load cases.** A dashboard
   that must show both the light canonical design (util ~8%) and a loaded V10
   can't use one fixed x-limit. Autoscale per frame; keep only a genuinely
   operative reference line pinned (SWL for tension), and let colour carry safety
   for the rest.

3. **"Missing artifact" was a stale assumption — verify before trusting a memory
   note.** `scripts/results/v10_campaign_50kw/best_design.json` was recorded as
   absent; it is present and valid. Cost: `--v10-tight` was wrongly treated as
   blocked for a while. Always `Read`/`isfile` the actual path before declaring a
   blocker.

4. **A "dynamically dead" design still renders — it just looks alarming.** V10
   Tight (FoS 0.43) fills the bars (good for a loaded demo) but shows red/warning
   states and can diverge. If the goal is a *healthy* loaded demo, reach for
   V10 Reinforced, not Tight. Don't confuse "bars are full" with "design is OK".

5. **Panels stay layout-agnostic — that paid off.** Because every panel is
   `panel!(grid_cell, ext_frames_obs, palette; …)`, reflowing the whole grid
   (stacked → side-by-side, 4 cols → 6 cols, moving the 3D cell) touched only the
   *placement* calls in `dashboard_v2.jl`, not the panel bodies. Keep this
   invariant.

6. **Returning widget handles is how a panel stays reusable AND wireable.**
   `config_panel!` builds the menus but doesn't know what they should do, so it
   returns them and lets `dashboard_v2.jl` wire `.selection`. Same pattern will
   apply when live rerun is added.

7. **Makie carry-overs still true** (from the 2026-06-30 pitfalls list, all still
   relevant): `RGBAf` not `RGBf` for bar colours; wrap label colours in
   `to_color()`; place `colsize!`/`rowsize!` only after every cell exists; ASCII
   `->` not unicode `→` in code; `SystemParams` immutable → `modified_params()`.

## Known gaps / deferred (unchanged intent)

- **Live scenario rerun** via `build_rerun!` (`src/sim_runner.jl`): menus log
  "rerun pending" but don't re-simulate. Deferred per PRD; the seam exists.
- **Torque per-ring real data:** `torque_chain!` still interpolates `tau_gen →
  tau_aero` linearly — no true per-ring torque array until `ring_forces.jl`
  exposes one (PRD "out of scope").
- **Column-width tuning:** `Relative(0.13)` on cols 1–3 is a first guess; may need
  nudging once Rod sees it.
- **Full test suite** not run against these edits.

## Next steps

1. Rod compiles/runs `--v2 --v10-reinforced`; report any Makie errors (likely:
   `Menu` `fontsize`/`width` kwargs, `Relative` sizing, `lblkw...` splat, new
   builder kwargs). Fix, iterate.
2. If layout still feels off, tune cols 1–3 relative widths and row 5 height.
3. When ready for "more operational elements" (Rod's words): wire the config
   menus to `build_rerun!` for live scenario switching.

## Key files (delta from 2026-06-30 handover)

| File | Role | Touched today |
|------|------|---------------|
| `src/dashboard_panels.jl` | 6 layout-agnostic panels | ✅ ring/tension autoscale, rotor kW, config menus |
| `src/dashboard_v2.jl` | `build_dashboard_v2()` cockpit | ✅ 6×6 reflow, side-by-side bars, wiring |
| `scripts/interactive_dashboard.jl` | entry point + `--v2`/`--v10-*` | ✅ `--v10-reinforced`, builder kwargs |
| `src/visualization.jl` | v1 `build_dashboard()` | ❌ untouched (DO NOT MODIFY) |
| `src/sim_frame.jl` | `ExtendedSimFrame` + `capture_extended` | ❌ (confirmed rotor powers are kW) |
| `scripts/dashboard_v2_tracker.md` | tracker | update if you touch v2 |
| `DECISIONS.md` | decision log | ✅ 2026-07-01 entry added |
| `docs/architecture/PRD-dashboard-refactor.md` | PRD | reference |

## Suggested skills for next session

- `anthropic-skills:awes-engineering-analysis` — for any physics/FoS questions on
  V10 Reinforced vs Tight.
- `engineering:code-review` — before merging the v2 changes.
- `engineering:debug` — if the compile throws Makie errors.
