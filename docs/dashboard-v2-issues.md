# Dashboard v2 — Issues Inventory

**Compiled:** 2026-07-02 from Rod's feedback + code inspection  
**Files:** `src/dashboard_v2.jl`, `src/dashboard_panels.jl`, `scripts/launch_v2.jl`  
**Window:** 1780×1180 on 1920×1080 laptop

---

## 1. Rotor Power Dials Too Small

**Location:** `dashboard_panels.jl` lines 241-316, placed at `fig[3, 4]` in `dashboard_v2.jl` line 452

**Issue:** When stacked vertically (`horizontal=false`), the concentric-arc rotor power gauges are squeezed into a narrow column (~12% of window width ≈ 214px with 0.42 radius dials). Font sizes drop to 18pt (kW) / 8pt (sub-labels). On the 1920×1080 laptop, these dials are barely legible.

**Root cause:** `colsize!(fig.layout, 4, Relative(0.12))` — the rotor gauge column gets the same narrow allocation as a bar chart column, but dials need more visual space to be readable.

**Code reference:**
- `fs_kw = horizontal ? 24 : 18` — vertical mode → 18pt
- `fs_sub = horizontal ? 10 : 8` — vertical mode → 8pt (barely visible)
- `max_radius = 0.42` — dial fills ~84% of 0.5 axis range, but squeezed into narrow col

---

## 2. Controls/Config Panel Spread Inefficiently

**Location:** `dashboard_panels.jl` lines 329-370, placed at `fig[5, 2:3]` in `dashboard_v2.jl` line 465

**Issue:** The config panel uses 10 grid rows for what could be a compact 2-3 row panel. Each dropdown has a label row + menu row. Peak labels, FoS label, regen state each get their own row with separator labels. This pushes the panel to 340px height (`rowsize!(fig.layout, 5, Fixed(340))`).

**Layout:**
```
Row 1:  ⚙ CONFIG (title)
Row 2:  Design    [menu]
Row 3:  Scenario  [menu]
Row 4:  Generator [menu]
Row 5:  Payout    [menu]
Row 6:  ── Run Peaks ── (separator)
Row 7:  P/kW · ω/rpm · T/N
Row 8:  FoS · V · Slack
Row 9:  ── Regen State ── (separator)
Row 10: Brake/Buckle/Slack/State
```

**Could be:**
```
Row 1:  ⚙ CONFIG
Row 2:  [Design ▼] [Scenario ▼] [Generator ▼] [Payout ▼]
Row 3:  P/kW · ω/rpm · T/N  |  FoS · V · Slack  |  Brake:OFF Buckle:OK
```

---

## 3. Event Log Taking Disproportionate Space

**Location:** `dashboard_v2.jl` line 466 — `Label(fig[5, 4:6], event_log; ...)`  
**Grid allocation:** `fig[5, 4:6]` — 3 columns wide × 340px tall row

**Issue:** The event log is a 6-line text label occupying 3/6 columns and a 340px-tall row. That's ~50% of the horizontal space in the secondary row dedicated to a text log that shows at most 6 lines of transition warnings. 

The log shares row 5 with config panel. Both are in Fixed(340) row — they compete. The config panel needs height for its 10 rows; the event log wastes the extra height it doesn't need.

**Alternative:** Move event log to a thinner status bar, or share the playback row with a single-line status. 6 lines of historical event log isn't cockpit-critical — what the engineer needs is the CURRENT warning state, not the history.

---

## 4. Missing v1 Re-Run / Scenario Controls

**Location:** `launch_v2.jl` vs `interactive_dashboard.jl` (v1)

### What v1 has that v2 doesn't:

| Feature | v1 (`interactive_dashboard.jl`) | v2 (`launch_v2.jl`) |
|---------|-------------------------------|---------------------|
| Config flags | `--v10-tight`, `--v10-reinforced`, `--v5`, `--v6`, `--v62`, `--v63`, `--v64`, `--v65`, `--v9`, `--v9-10kw` | `--v10-tight`, `--v10-reinforced` only |
| Live re-run | `build_rerun!()` factory from `sim_runner.jl` — re-simulate with new params | Config menus say "(rerun pending)" — not wired |
| Headless mode | `--headless` flag for batch report generation | None |
| Duration control | `--duration=N` flag | `--duration=N` flag ✓ |
| Wind speed | `--wind=N` flag | Hardcoded to `v_wind = 11.0` |

### The `build_rerun!()` gap:

v1's `interactive_dashboard.jl` uses `sim_runner.jl`'s `build_rerun!()` factory to create a callback that:
1. Writes new params to immutable `SystemParams` via `modified_params()`
2. Re-runs the ODE simulation with the new config
3. Updates all panel observables with the new frame data

v2's config panel has selectable menus but says "(rerun pending)" — the handlers only log to the event log. No actual simulation restart is wired.

### Missing playback controls:

v1 has: Play/Pause, Stop, Speed selector  
v2 has: Same ✓ — Play, Stop, Speed menu, Frame slider, Frame counter  

---

## 5. Additional Issues (from code inspection)

### 5a. No `--wind` flag in v2
Wind speed is hardcoded at `v_wind = 11.0` in `launch_v2.jl` line 24. v1 allows `--wind=N` on command line.

### 5b. Config menu duplication
The config menus (`design_menu`, `scenario_m`, `gen_menu`, `payout_menu`) duplicate options already available as command-line flags. They should either trigger live re-runs or be removed in favor of CLI flags.

### 5c. Strip KPIs could be denser
The cockpit telemetry strip (row 1) uses Fixed(150) per KPI column × 7 KPIs = 1050px minimum. On a 1780px window that's fine, but there's unused horizontal space between KPIs. The labels (GEN ELEC kW, Ω HUB rpm, etc.) are 9pt — could be thinner columns with larger values.

---

## Priority Order (Rod's implicit ranking)

1. **Fix dial size** — rotor gauges are unreadable, the primary complaint
2. **Compact the config panel** — free up vertical space for the dials
3. **Wire live re-run** — config menus should actually restart the simulation
4. **Reduce event log footprint** — status bar instead of 6-line log
5. **Bring v2 CLI parity** — add missing config flags and `--wind` to launch_v2.jl
