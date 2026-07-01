# Handover — Dashboard v2 Refactor

**Date:** 2026-06-30
**For:** Fresh session, clean start

---

## Design Intent — Why This Matters

### The Problem

The v1 dashboard (`src/visualization.jl`, 1,850 lines) is a monolithic HUD. It shows aggregate numbers (one FoS, one power, one tension) but can't show WHERE a problem is occurring. A TRPT engineer needs to see:

- **Which ring is buckling?** Is it the bottom ring (torque accumulation) or the hub ring (thrust)?
- **Which rotor is contributing power?** Are all expansion rotors working, or is one stalled?
- **How is twist propagating?** Can we see the torsional wave travel down the shaft?
- **Where in the tension chain is the weak point?** Is a tether segment going slack?

The v1 dashboard compresses all this into a single `FoS=1.36` number. The v2 dashboard **shows the system**.

### The Aesthetic Reference

The design draws from **aircraft instrument panels and automotive gauge clusters** — dark backgrounds, cyan/high-contrast accents, large readable KPIs, minimal text. The reference is the Kitemill dashboard aesthetic (clean, dark-themed, per-component diagnostics). The A1 Instrument palette (near-black #1a1a2e, cyan #00bcd4 accent) was selected in Phase 1.

The goal: an engineer looking at this dashboard should immediately understand the TRPT's state without reading numbers. Red ring bar = that ring is buckling. Rotor gauge spinning fast = that rotor is contributing. Twist view showing a spiral = torsional wave propagating. No hidden algorithms, no buried menus.

### The Panel Philosophy — TRPT-Specific Diagnostics

Each panel answers one question for the TRPT engineer:

| Panel | Question | Why TRPT-specific |
|-------|----------|-------------------|
| **Ring health bars** | Which ring is closest to buckling? | TRPT has 20+ rings — the failure is always at one specific ring. No conventional turbine has this. |
| **Rotor power gauges** | Which rotor is producing power? | Multi-rotor TRPT — hub + expansion rotors. A stalled expansion rotor is invisible in aggregate power. |
| **Tension chain** | Where is tension lowest in the shaft? | Tension propagates downward through the TRPT. A slack segment breaks the transmission. |
| **Torque chain** | How does torque accumulate per ring? | Torque accumulates from hub to ground. Bottom rings carry the full load. |
| **Twist view** | What's the twist profile down the shaft? | The TRPT's defining failure mode — torsional collapse. Visualised as a polar spiral. |
| **Config & Controls** | What am I running and can I change it? | Config name, wind speed, scenario buttons. |

### The Grilling — Architecture Decisions

The dashboard architecture was grilled using Matt Pocock's methodology (one question at a time, recommended answer, walk the decision tree). The key questions and answers:

**Q: Monolith vs thin-shell vs microkernel?**
→ Thin-shell. V1 stays untouched. V2 is a new function composing extracted modules.

**Q: What's the right seam between the runner and the panels?**
→ `build_rerun!` as a factory function. Both v1 and v2 call it identically. Change the ODE timestep once, both layouts pick it up.

**Q: Should panels know their grid position?**
→ No. Signature is `panel!(grid_cell, data_obs, palette)` — layout-agnostic. This enables configurable cell slots: swap torque_chain for rotor_gauges in the same cell.

**Q: Extract vs duplicate the 3D viewport?**
→ Both v1 and v2 share the same 3D scene. The viewport is rendered once, placed in different grid cells per layout.

**Q: Configurable cell slots — now or later?**
→ Deferred. Post-extraction. First make the panels work, then make them swappable.

**Q: Responsive sizing — now or later?**
→ `Fixed()` first (matching 1920×1080 laptop), `Relative()`/`Auto()` after panels are verified.

Full PRD at `docs/architecture/PRD-dashboard-refactor.md` (published as GitHub issue #5).

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

> Don't modify `build_dashboard()`. Write `build_dashboard_v2()` from scratch as a thin shell composing the extracted modules. V1 stays working. `scripts/interactive_dashboard.jl` gets a `--v2` flag.

**V2 layout (6-row responsive grid, 1920×1080):**
- Row 1: Cockpit strip (7 KPIs — POWER, RPM, FoS, RING%, WIND, ELEV, TIME)
- Row 2: Torque chain | Ring health bars | Rotor gauges (vertical stack) | Config & Controls
- Row 3: Twist view (polar) | Tension chain | 3D viewport
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
2. If it renders: write `build_dashboard_v2()` from scratch in `src/visualization.jl`. New function, clean grid, compose panels.
3. Add `--v2` flag to `interactive_dashboard.jl`.
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
| `docs/architecture/PRD-dashboard-refactor.md` | Full PRD (grilling output) |
| `docs/porto-2026/dashboard-redesign-plan.md` | Original redesign spec |
| `docs/porto-2026/dashboard-issues.md` | Bug tracker |
