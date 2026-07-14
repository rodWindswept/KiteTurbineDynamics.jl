Rod — sharing this note with you to forward to the desktop Hermes in Stornoway. It's a summary of the codebase audit we just ran, what moved, and what's next.

---

Hermes — context for your next session in this repo. We just completed a codebase audit (13 of 19 items). Here's what changed and what you need to know before working.

## Pull first

```
git pull origin master
```

You should be at `d4820ba` or later.

## Files that moved

Don't look for these in their old locations:

| Was | Now |
|-----|-----|
| `PLAN.md` | `docs/archive/PLAN.md` (superseded V6 paper plan) |
| `TODO.md` | `docs/archive/TODO.md` (all done) |
| `RESTART_INSTRUCTIONS.md` | `docs/archive/RESTART_INSTRUCTIONS.md` (stale at v5) |
| `RECAP.md` | `docs/RECAP.md` (still active — 5 breakthrough narratives) |
| `NOTES_LIFT_KITE.md` | `docs/NOTES_LIFT_KITE.md` |
| `NOTES_MPPT_TWIST.md` | `docs/NOTES_MPPT_TWIST.md` |
| `01-04_*.md` | `docs/case-notes/` |
| `launch_v10*.sh`, `run_*.sh` | `scripts/launchers/` |
| `test/verify_*.jl` | `scripts/diagnostics/` |
| `test/test_pitch_depower_control_campaign.jl` | `scripts/diagnostics/` |
| `test/test_stall_control_campaign.jl` | `scripts/diagnostics/` |
| `handovers/HANDOFF_*.md` | `handovers/handover-YYYY-MM-DD-*.md` (renamed) |
| `docs/handover/` | Merged into `handovers/` |

## AGENTS.md is NOT deprecated

An earlier draft marked it as deprecated. That was wrong. AGENTS.md is the cross-tool entry point (used by Hermes, Codex, OpenCode). CLAUDE.md is Claude-specific. Both live.

## PROJECT_ROOM.md is the index

If you need to find anything, start there. It maps root documents, source layout, campaign history, and current work.

## build_v10_tight is now in src/

The builder functions moved from `scripts/builders_util.jl` into `src/builders_util.jl` and are exported from `KiteTurbineDynamics`. You can now do:

```julia
using KiteTurbineDynamics
sys, u0, p, label, design = build_v10_tight(blade_scale=0.95)
```

The old `include("scripts/builders_util.jl")` still works (it's a shim) but the functions precompile properly now. No more `Base.invokelatest` needed.

Same for `ControlMapHunt` — it's in `src/control_map_hunt.jl` with a shim in `scripts/`. The stale-`.ji` ritual in CLAUDE.md rule 6 should be fixable now.

## V10 naming convention

We had three different things all called "V10." Now disambiguated in CONTEXT.md:

- **V10-DE** — the 76.75 kg DE campaign winner (14-gon, hub+3 rotors, centre-constraint spokes)
- **V10-Spoke** — the current work: per-vertex Dyneema spring spokes, Phase D/E active, 13 viable designs
- **V10-Tight (retracted)** — the 49.2 kg centre-constraint design that was retracted July 13

All our Phase D/E design cards and charts use V10-Spoke. Never use unqualified "V10."

## What else changed

- `test/runtests.jl` now runs 25 test suites (added `test_blade_geometry.jl` and `test_golden_traces.jl`)
- `*.csv` in `.gitignore` no longer ignores `scripts/results/**/*.csv` — campaign CSVs are tracked
- CI is live at `.github/workflows/ci.yml` (runs structural golden traces on push/PR)
- `catalog_sweep.jl`, `wind_sweep.jl`, `crossover_sweep.jl` now print GIT_HASH provenance
- README.md trimmed from 795 to 210 lines

## When you resume

The design cards and Phase E charts are in `docs/outreach/figures/`. The power curve chart (`chart-power-curve.pdf`) uses real simulation data from `wind_sweep.csv`. The other four charts went through 3 review cycles and are final.
