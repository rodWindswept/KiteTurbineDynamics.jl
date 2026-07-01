# Handover — Dashboard v2 Refactor

**Date:** 2026-06-30
**For:** Fresh session, clean start

---

## State of Play

The dashboard v2 refactor has two working modules and one broken integration. The handover recommends starting a clean session with only this document as context — avoid the tangle of the previous mixed session.

### Working (Verified Standalone)

**`src/sim_runner.jl`** — `DashboardState` struct + `build_rerun!()` factory.
- Verified: produces 1,250 frames for steady-state cruise scenario.
- Uses `modified_params()` to handle immutable `SystemParams`.
- Exported from `KiteTurbineDynamics`.

**`src/dashboard_panels.jl`** — 6 panel functions:
- `ring_health!(grid_cell, ext_frames_obs, palette)` — per-ring FoS bars
- `tension_chain!(grid_cell, ext_frames_obs, palette)` — tether tension per segment
- `torque_chain!(grid_cell, ext_frames_obs, palette)` — torque per ring
- `rotor_gauges!(grid_cell, ext_frames_obs, palette)` — concentric rotor power gauges
- `twist_view!(grid_cell, ext_frames_obs, palette)` — polar twist view
- `config_panel!(grid_cell, ext_frames_obs, palette)` — config readout
- Each takes `(grid_cell, data_obs, palette)` — layout-agnostic.
- Compiled and exported. **NOT verified in GLMakie** (needs display).
- CairoMakie prototype exists at `scripts/dashboard_prototype_panels.jl`.

**`src/sim_frame.jl`** — `ExtendedSimFrame` + `capture_extended()`.
- Per-ring FoS, Ncomp, Pcrit.
- Per-segment twist and tension.
- Per-rotor power (hub + expansion).
- Wraps existing `SimFrame` — backward-compatible.

### Broken (5 Failed Integration Attempts)

`src/visualization.jl` — `build_dashboard()` is an 1,850-line monolith. Each integration attempt hit a new edge case:

| Attempt | Approach | Failure |
|---------|----------|---------|
| 1 | Early return for v2 before v1 code | V2 viewport empty (3D content never rendered) |
| 2 | `@goto` to skip v1 HUD | Julia `@goto` can't skip variable definitions |
| 3 | Guard v1 code with `if layout != :v2` | Grid conflict: v2 cockpit at `fig[1,1:4]` vs v1 controls at `fig[1,1]` |
| 4 | Duplicate 3D rendering in v2 | ~300 lines of deep nesting, impractical |
| 5 | Separate windows via `dashboard_v2_standalone.jl` | Compiles, but GLMakie panel rendering unverified |

**Root cause:** Grid positions, 3D rendering, controls, and scenarios are all coupled in one function. Every fix exposes a new coupling.

## The Plan (from PRD)

**`docs/architecture/PRD-dashboard-refactor.md`** (published as GitHub issue #5):

> Don't modify `build_dashboard()`. Write `build_dashboard_v2()` from scratch as a thin shell composing the extracted modules. V1 stays working throughout. `scripts/interactive_dashboard.jl` gets a `--v2` flag.

**V2 layout (6-row responsive grid):**
- Row 1: Cockpit strip (7 KPIs, integrated from separate window)
- Row 2: Torque chain | Ring health bars | Rotor gauges | Config & Controls
- Row 3: Twist view | Tension chain | 3D viewport
- Row 4: Event log + Playback controls

## Implementation Tracker

From `scripts/dashboard_v2_tracker.md`:

| Step | Status |
|------|--------|
| 1. `build_dashboard` layout=:v2 — new grid, 3D viewport at `fig[5,3:4]` | ✅ |
| 2. `ExtendedSimFrame` capture in pre-compute + `_rerun!` loops | ✅ |
| 3. Cockpit strip integrated into main window row 1 | ✅ |
| 4. Ring health bars wired via `@lift` from `ext_frames_obs` | ✅ |
| 5. Rotor power concentric gauge panel | ☐ |
| 6. Twist view panel (polar, shaft axis) | ☐ |
| 7. Config & Regen Controls live labels | ☐ |
| 8. Switch `Fixed()` → `Relative()` / `Auto()` sizing | ☐ |
| 9. `--v2` flag in `interactive_dashboard.jl` | ☐ |
| 10. Full test suite pass | ☐ |

## Julia/Makie Pitfalls

From the previous session:

1. **`Observable(nothing)` is type-locked** to `Nothing`. Use `Observable{Any}(nothing)` for multi-type fields.
2. **`SystemParams` is immutable.** Use `modified_params(base; field=value)` — exported from `parameters.jl`.
3. **Try/catch blocks create variable scopes.** Variables inside `try` are invisible to subsequent code.
4. **`@lift` on Makie Labels** must happen at construction time. Use `on()` for post-construction binding.
5. **Bar chart colours need `RGBAf`** not `RGBf` for GLMakie. Convert with `RGBAf.()`.
6. **Precompiled cache may not update on export changes.** Touch source files or use `--compiled-modules=no`.
7. **Makie label colours:** always wrap in `to_color()` — bare `:grey60` Symbols crash.
8. **Unicode `→` in strings** is Julia's `-->` operator — use ASCII `->` instead.

## Recommended Approach for Fresh Session

**Vertical TDD slices.** One panel, one window, verify, then integrate:

1. Run `scripts/dashboard_v2_standalone.jl --v10-tight` with Rod at screen. Does `ring_health!` render in GLMakie? This is the critical first step — all panel verification requires display.
2. If it renders: write `build_dashboard_v2()` from scratch in `src/visualization.jl`. New function, clean grid, compose panels via the same pattern as the standalone script.
3. Add `--v2` flag to `interactive_dashboard.jl` that calls `build_dashboard_v2()` instead of `build_dashboard()`.
4. One panel at a time: ring_health! → tension_chain! → torque_chain! → rotor_gauges! → twist_view! → config_panel!

**Do NOT:**
- Modify `build_dashboard()` (v1). It stays working.
- Try to fork v1 code into v2. Write fresh.
- Verify panels without the display. GLMakie rendering requires Rod at screen.

## Test Commands

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl

# V1 dashboard (working, the fallback)
julia --project=. scripts/interactive_dashboard.jl --v10-tight

# V2 standalone panel test (needs display verification)
julia --project=. scripts/dashboard_v2_standalone.jl --v10-tight

# Verify exports
julia --project=. -e 'using KiteTurbineDynamics; println(ring_health!)'

# CairoMakie prototype (headless, for reference)
julia --project=. scripts/dashboard_prototype_panels.jl
```

## Key Files

| File | Role |
|------|------|
| `src/sim_runner.jl` | `build_rerun!` + `DashboardState` |
| `src/dashboard_panels.jl` | 6 panel functions |
| `src/sim_frame.jl` | `ExtendedSimFrame` + `capture_extended()` |
| `src/parameters.jl` | `modified_params()` |
| `src/visualization.jl` | `build_dashboard()` — v1 only, DO NOT MODIFY |
| `scripts/interactive_dashboard.jl` | v1 entry point (working) |
| `scripts/dashboard_v2_standalone.jl` | v2 standalone test (needs display) |
| `scripts/dashboard_prototype_panels.jl` | CairoMakie reference |
| `scripts/dashboard_v2_tracker.md` | Implementation tracker |
| `docs/architecture/PRD-dashboard-refactor.md` | Full PRD |
| `SESSION_HANDOVER_2026-06-30.md` | Previous session record (Windswept drive) |

## Reference PRD

The full dashboard architecture PRD is at `docs/architecture/PRD-dashboard-refactor.md`. Two seams were identified:
1. `build_rerun!(sys, p, u0, wind_fn, lift_device, obs_nt)` → returns a scenario-runner closure
2. `panel!(grid_cell, data_obs::Observable{ExtendedSimFrame})` → 6 panel functions

Both are extracted and working. The integration layer (`build_dashboard_v2()`) is the remaining piece.
