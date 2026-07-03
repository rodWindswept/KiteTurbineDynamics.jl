# Dashboard v2 Implementation Tracker
# Rewritten 2026-07-01 to reflect VERIFIED state (previous version claimed
# integration steps that were not actually in the code — they had been reverted).

## Verified state (read from code 2026-07-01)

- src/visualization.jl `build_dashboard()` is the UNMODIFIED v1 monolith.
  No `layout` arg, no `:v2`, no `build_dashboard_v2`. v1 is clean — keep it that way.
- Extracted modules exist, compile, and are exported:
  - src/sim_frame.jl   — ExtendedSimFrame + capture_extended()
  - src/sim_runner.jl  — DashboardState + build_rerun! (captures ext_frames per frame)
  - src/dashboard_panels.jl — 6 panels + DashboardPalette
- Panels + DashboardPalette + fos_str are now EXPORTED (was the blocker; fixed 2026-07-01).
- Panel data handlers: only ring_health! and tension_chain! have live on(ext_frames_obs)
  handlers. torque_chain! = placeholder zeros. twist_view!, rotor_gauges!, config_panel!
  = static scaffolds.

## PROVEN 2026-07-01 (scripts/dashboard_v2_standalone.jl, GLMakie, Rod at screen)

- Panels render in GLMakie. ✅
- Full data path works: settle_to_operational_state + run_canonical_sim! + capture_extended
  → ext_frames → panels + cockpit strip show real (non-NaN) data. ✅
- Fixes applied to the standalone: renamed local parse_args→parse_cli (ArgParse clash);
  replaced hand-rolled Euler loop (diverged to NaN) with the proven settle+run path;
  continuous panel playback.

## Known gaps / blockers

- Campaign design artifacts (scripts/results/**/best_design.json, best_vector.csv) are
  ABSENT from the checkout. So --v10-tight and all campaign configs fall back/err;
  only canonical 5-line runs. NOT gitignored (only logs/.jls are) — data source TBD.
- On canonical, ring/tension bars look near-empty because the design is lightly loaded
  (ring FoS ~21, util ~5%). Under a loaded design (v10-tight) they fill and colour.

## Remaining work

| Step | Status |
|------|--------|
| Export panels + fos_str | ✅ 2026-07-01 |
| Verify GLMakie render + live data (standalone) | ✅ 2026-07-01 |
| build_dashboard_v2(): single-window cockpit + 3D + panels bound to ONE frame obs | ✅ compiled+rendered 2026-07-01 (Rod at screen) |
| --v2 flag in interactive_dashboard.jl | ✅ compiled+ran 2026-07-01 |
| Wire torque_chain / rotor_gauges / twist_view / config_panel to live data | ✅ 2026-07-01 (dashboard_panels.jl on(ext_frames_obs) handlers) |
| Rebuild v2 layout to MOCKUP spec (scripts/dashboard_prototype_panels.jl) | ✅ 2026-07-01 — NOT yet recompiled |
| Event log + scenario/speed/Run-Stop controls | ✅ 2026-07-01 — NOT yet recompiled |
| Compile + run rebuilt `--v2` on canonical, fix any Makie errors | ☐ (Rod, sandbox 401) |
| Wire scenario menu to live rerun (build_rerun! from sim_runner.jl) | ☐ deferred |
| Extract v10-tight builder into shared/exported fn (needs results data) | ☐ blocked on best_design.json |
| torque_chain real per-ring data (currently tau_gen→tau_aero interp) | ☐ needs ring_forces.jl torque array |
| Auto column widths tuning (removed Fixed(380)) | ☐ |
| Full test suite pass | ☐ |

## MOCKUP-SPEC REBUILD (2026-07-01)
The v2 minimal 3-panel build was replaced with the full prototype layout.
SPEC SOURCE FOUND: scripts/dashboard_prototype_panels.jl (CairoMakie synthetic-data
mockup) == Rod's screenshot 3. 6 rows × 4 cols:
- ROW 1 cockpit strip (7 KPIs: POWER/ΩHUB/FoS/UTIL/WIND/TWIST/TIME), Fixed(150) cols
  → fixes the label-overlap bug (was tellwidth/no fixed widths).
- ROW 2 headers: TORQUE | RING HEALTH | ROTOR POWER | CONFIG & CONTROLS
- ROW 3 torque_chain! | ring_health! | rotor_gauges! | config_panel!
- ROW 4 headers: TWIST VIEW | TENSION CHAIN | 3D VIEWPORT
- ROW 5 twist_view! | tension_chain! | 3D viewport (ax3d moved from fig[1,1] → fig[5,3:4])
- ROW 6 event log (cols 1:2, rolling last-4 warning-transition messages) |
        controls (cols 3:4: slider + Play + Stop + counter + speed menu + Scenarios menu)
All 6 panels now live (on(ext_frames_obs)): torque=tau_gen→tau_aero linear interp;
twist=polar radial lines from segment_twist_deg; rotor=concentric aero/ground arcs from
rotor_aero_power/rotor_ground_power; config=live P/ω/T/FoS/state.
Empty-bars question: canonical is lightly loaded (ring util ~8%) so N/Pcr + tension bars
sit near zero — expected, not a bug; loads fill under v10-tight.

## build_dashboard_v2 as written (2026-07-01)
- New file src/dashboard_v2.jl, included after visualization.jl, exported.
- v1 build_dashboard UNCHANGED. 3D scene block copied verbatim (same observable names).
- Layout: [3D | ring_health!+tension_chain!+torque_chain!] / [cockpit strip] / [Slider+Play+speed].
- Single on(frame_obs): ext_obs[]=ext_frames[1:fi] (panels read efs[end]) + strip labels.
- Scope: play/scrub over precomputed frames only. NO live scenario-rerun yet (build_rerun! deferred).
- --v2 branch in interactive_dashboard.jl: one window, no in-window config switch.

## Notes for the build_dashboard_v2 step
- Write it FRESH; do not modify build_dashboard (v1). Panels are layout-agnostic:
  panel!(grid_cell, ext_frames_obs, palette).
- The hard part is the 3D viewport — it currently lives coupled inside build_dashboard.
  Prior attempt to duplicate it was ~300 lines. Decide: share the v1 scene vs. rebuild minimal.
- Bind all panels + cockpit to a single frame Observable driven by the Play/scrub control
  so they animate together (the standalone's separate-window one-shot is only a test harness).
