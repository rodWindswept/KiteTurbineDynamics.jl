# Dashboard UX redesign — dispatch note

**Date:** 2026-06-13
**For:** Rod (AFK — reply on Dispatch with your picks)
**Applies to:** `src/visualization.jl` (`build_dashboard`) + `scripts/interactive_dashboard.jl`
**Companion:** `docs/dashboard-redesign-options.html` (open in a browser — same options, clickable)

---

## Repo / sync state (your "is this the latest pull?" question)

- On branch `master` at `b05e17cc` — "Phase 2.5: add rich figure generation script + all 12 figures".
- Local `master`, `origin/master` tracking ref, and `HEAD` all point to the same commit, so nothing local is divergent **as of the last sync (~14 h ago)**.
- I could **not** run a live `git fetch` to confirm GitHub hasn't moved since — the sandbox shell wouldn't start this session. Run `git fetch && git status` when you're back to be 100% sure.
- Clutter worth clearing: stale worktree `.claude/worktrees/goofy-goldberg-e2f27d` and ~6 old `claude/*` local branches. (Decision F below.)

## The core problem

The entire HUD is one ~350 px column of ~40 stacked monospace `Label`s across six sections (Live Telemetry, Lift Device, Torque & Power, Structural Loads, Run Peaks, Scenarios). Meaning is encoded by inline text colour. The most important number on screen — **tether FoS 0.5, 6460 N vs 3500 N SWL, 100% slack events** — has the same size and weight as everything else. Safety signals are lost in a wall of text. Controls (left) are a flat stack of menus/sliders/toggles with tiny grey labels.

## Choices recorded so far

- **A — Theme:** A1 Instrument (near-black). _matches rec_
- **B — Layout:** B2 cockpit status strip on top, dominant viewport. _matches rec_
- **C — Number display:** C2 gauges + sparklines. _matches rec_
- **D — Safety:** D2 (dedicated loads panel with FoS gauge). _differs from rec (D1 banner) — D2 is more detailed, less glanceable. Could pair D1 banner + D2 panel if you want._
- **E — Controls:** E1 collapsible workflow groups. _matches rec_
- **Locked set: A1 · B2 · C2 · D2 · E1.** Full mockup built → `docs/dashboard-redesign-mockup.html`.
- Still open: F (repo hygiene — fetch/confirm latest + prune stale worktree & old `claude/*` branches).

## Decisions I need (recommendation in **bold**)

- **A — Theme:** A1 Instrument (near-black, one accent) **[rec]** · A2 Blueprint (navy/cyan) · A3 Slate (light, for daylight/projector)
- **B — Layout:** B1 tidy 3-column · B2 cockpit status strip on top, dominant viewport **[rec]** · B3 tabbed diagnostics (Flight/Loads/Run/Scenarios)
- **C — Number display:** C1 metric cards · C2 gauges + sparklines (trend without scrubbing) **[rec]** · C3 cleaned aligned rows
- **D — Safety:** D1 colour-flipping status banner at top **[rec]** · D2 dedicated loads panel with FoS gauge
- **E — Controls:** E1 collapsible workflow groups **[rec]** · E2 flat list with section headers
- **F — Repo hygiene:** fetch + confirm latest, prune stale worktree and old `claude/*` branches? (yes / leave it)

## Engineer needs this should serve

Quick read of operating point (power vs rated, rotor/PTO rpm, TSR vs Cp-λ optimum), structural margin (tether FoS, ring buckling util), and failure flags (slack/collapse) — plus clear separation of live-frame vs run-peak vs design-limit numbers, scenario testing, and export. The redesign should make "pick config → set wind/control → run → read power + safety → iterate" obvious.

## Fast paths

1. **Take all recommended** (A1 · B2 · C2 · D1 · E1) → I build a full before/after mockup, then implement in `visualization.jl`.
2. **Show one full before/after first**, then you decide.

**Reply on Dispatch with picks, e.g. `A1 B2 C2 D1 E1, F yes`** — or just "all recommended".
