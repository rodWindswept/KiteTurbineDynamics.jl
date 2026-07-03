# PRD — KTD.jl Dashboard Architecture Refactor

## Problem Statement

The `build_dashboard()` function in `src/visualization.jl` is a 1,850-line monolith. The simulation runner (`_rerun!`), 6 panel types, scenario controls, and playback are all defined inline as closures capturing 15+ variables from the outer scope. This creates three concrete problems:

1. **V2 layout can't use the runner.** V2's cockpit strip at `fig[1,1:4]` collides with V1's controls at `fig[1,1]`. Adding a `--v2` flag required duplicating grid code.
2. **Panels can't be swapped.** A structural analysis workflow wants ring health + torque chain. A power optimisation workflow wants rotor gauges + tension chain. Both require different dashboard functions.
3. **No testability.** Every change to any panel or the runner risks breaking the entire dashboard. There's no way to test a panel or the runner in isolation.

## Solution

Extract the dashboard into composable **deep modules** (per the codebase-design vocabulary): small interfaces, large implementations behind them. Two seams:

1. **`build_rerun!(sys, p, u0, wind_fn, lift_device, obs_nt)`** — simulation runner returns a closure. Both v1 and v2 pass their own observable NamedTuple. Tested in isolation.
2. **`panel!(grid_cell, data_obs::Observable{ExtendedSimFrame})`** — 6 panel functions, each taking a grid cell and a live data observable. Tested by pushing data to the observable and verifying visual output.

## User Stories

1. As a KTD.jl developer, I want to add a third dashboard layout without touching the simulation runner, so that new layouts compose the same components.
2. As a KTD.jl developer, I want to test panel colours in a unit test by pushing an ExtendedSimFrame to an observable, so that visual regressions are caught early.
3. As a KTD.jl user, I want to run a scenario in the v2 dashboard and see live ring health bars update, so that I can use the new layout for structural analysis.
4. As a KTD.jl user, I want the v1 dashboard to continue working identically after the refactor, so that existing workflows are not disrupted.
5. As a KTD.jl user, I want to swap what panel appears in a grid cell (e.g., torque chain → rotor gauges), so that different workflows get different panel arrangements.
6. As a KTD.jl developer, I want the simulation runner to produce both `SimFrame` and `ExtendedSimFrame` arrays, so that panels choosing different detail levels both work.
7. As a grant reviewer viewing the dashboard, I want the cockpit strip integrated into the main window, so that the dashboard looks professional and self-contained.

## Implementation Decisions

- **Module: `src/sim_runner.jl` (new).** Contains `build_rerun!()` which takes system/parameters/initial-state/wind-function/lift-device and a NamedTuple of observables, and returns a closure that runs a simulation scenario. The closure writes `sim_frames_obs[]` and `ext_frames_obs[]` and updates `frame_slider.range[]`.
- **Module: `src/dashboard_panels.jl` (new).** Contains `torque_chain!`, `ring_health!`, `rotor_gauges!`, `twist_view!`, `tension_chain!`, `config_panel!`. Each takes `(grid_cell, data_obs::Observable{ExtendedSimFrame})` and mutates the grid by creating axes and plots. Returns nothing.
- **Module: `src/visualization.jl` (modified).** Becomes a thin shell. `build_dashboard()` defines the grid, calls `build_rerun!()`, calls panel functions. The `layout` parameter selects which grid and which panels. ~1,850 lines → ~600 lines.
- **Observable NamedTuple shape** (from prototype):

```julia
@NamedTuple begin
    sim_frames_obs::Observable{Vector{SimFrame}}
    ext_frames_obs::Observable{Vector{ExtendedSimFrame}}
    frame_slider::Slider
    speed_slider::Slider
    payout_slider::Slider
    scenario_obs::Observable{String}
    pause_obs::Observable{Bool}
    active_winch_obs::Observable{Bool}
    mppt_stall_obs::Observable{Bool}
    field_imu_obs::Observable{Bool}
    depower_seq_obs::Observable{Int}
    auto_ramp_obs::Observable{Bool}
    ramp_ctrl_obs::Observable{SoftRampController}
    ramp_state_obs::Observable{String}
    scenario_msg_obs::Observable{String}
    scenario_msg_color_obs::Observable{Symbol}
    force_ramp_obs::Observable{Bool}
    times_ref::Ref{Vector{Float64}}
    frames_obs::Observable{Vector{Vector{Float64}}}
end
```

## Testing Decisions

- **Test seam:** Both extracted modules expose clear interfaces. `build_rerun!` returns a closure — call it with mock observables, verify frames produced. Panel functions mutate a grid cell — push data to an observable, verify bar colours/values.
- **Prior art:** `test/test_metric_consistency.jl` already tests simulation output. `test/test_dashboard_smoke.jl` tests the dashboard build. Both pass after refactor.
- **Test strategy:** One integration test: build v1 dashboard, verify it doesn't crash. Per-module unit tests: verify `build_rerun!` produces expected frame counts for known scenarios. Verify `ring_health!` colours match FoS thresholds.

## Out of Scope

- Configurable cell dropdowns (Candidate 3) — unblocks after panels are extracted, but not required for v2 to work.
- Torque-per-ring data — requires `ring_forces.jl` refactor to expose internal torque array.
- Web/WGLMakie serving — desktop GLMakie only.
- Per-rotor power computation from BEM — `capture_extended()` already returns this data.

## Further Notes

- The `ExtendedSimFrame` struct and `capture_extended()` function are already in `src/sim_frame.jl`, exported, and verified against live simulation.
- The `--v2` flag is already wired in `scripts/interactive_dashboard.jl` and passes `layout=:v2` to `build_dashboard()`.
- Prototype panels exist in `scripts/dashboard_prototype_panels.jl` (CairoMakie). They need GLMakie adaptation.
- This refactor is blocked on display availability for visual verification of panel functions.
