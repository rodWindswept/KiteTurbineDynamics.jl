# Situational awareness & handoff — 2026-06-13

**Author:** Claude (Cowork session, with Rod)
**Audience:** the next agent taking over this work (and Rod, for reference).
**Purpose:** Rod can't iterate live tonight. This document is a self-contained handoff so the next agent can pick up both workstreams without re-deriving context or pinging Rod for things already decided. Read this top-to-bottom before touching code.

---

## 0. TL;DR for the takeover agent

Two parallel workstreams, deliberately sequenced:

1. **Dashboard redesign (the active "main job").** All design decisions are locked (A1·B2·C2·D2·E1). An HTML mockup and a runnable GLMakie prototype exist. Nothing is wired into the live dashboard yet — that's the next big step, and it's **low risk** (presentation only, reuse existing data wiring). Blocking item: the GLMakie prototype is **unrun** (no Julia execution was available this session) and needs Rod's machine (GLMakie needs a display) to verify before porting.
2. **V6 expansion-rotor fix (parked, pending a physics decision from Rod).** The fix is committed and now backed up on GitHub. Do **not** merge it to master or re-run the campaign until Rod settles the force-vs-distance modelling question (§3). This is **higher risk** (changes physics / the funder story) — treat conservatively.

**Golden rules for the takeover agent:**
- Don't merge the expansion fix to `master` until tests are green *and* Rod has made the force-vs-distance call.
- Don't blind-edit `src/visualization.jl` without the ability to run GLMakie — prove changes in the isolated prototype first.
- Don't prune any `claude/*` worktree without first confirming it's merged (procedure in §4).
- The proven, funder-story model is **V5**. Protect it. FR4 (`N_expansion=0` ≡ v5) is the invariant that does so.

---

## 1. Environment constraints hit this session (so you don't repeat the diagnosis)

- **Sandbox shell (`mcp__workspace__bash`) would not start** — every call timed out (~45 s) on resume/create/re-resume, all session. Consequence: **no Julia execution, no `git` commands, no test runs.** All git state below was read directly from `.git/` internals; all code facts from the file tools (Read/Grep).
- **`mcp__cowork__present_files` failed** ("not accessible on the user's computer") — same underlying mount issue. Files written to the repo are fine and visible to Rod; the in-chat file cards just don't render.
- **GLMakie cannot be verified by an agent regardless of the shell** — it needs a display. The interactive dashboard must be run on Rod's machine. Plan around this: iterate via screenshots, not agent-side runs.

If your session has a working shell: run `git fetch && git status`, `julia --project=. test/runtests.jl`, and re-verify the worktree/branch state before acting.

---

## 2. Workstream A — Dashboard redesign

### 2.1 The problem being solved
The current HUD (`src/visualization.jl`, right column) is ~40 stacked monospace `Label`s across six sections. Meaning is encoded only by inline text colour, so the most safety-critical number (tether FoS, tension vs SWL, slack-line count) reads at the same weight as everything else. Controls (left) are a flat stack of menus/sliders with tiny grey labels. The redesign makes the operating point and structural margin glanceable.

### 2.2 Locked design decisions (do not relitigate)
- **A1 Instrument** theme — near-black, single cyan accent.
- **B2** — cockpit status strip on top, dominant viewport below.
- **C2** — radial gauges + sparklines for bounded metrics / trends.
- **D2** — dedicated structural-loads panel with an FoS gauge (Rod chose D2 over the recommended D1 banner; D2 is more detailed. A D1 banner could be *added* later but D2 is the decision).
- **E1** — collapsible workflow control groups (Config → Lift device → Control law → Scenario → Run & export).
- **Force-first expansion readout (Rod, 2026-06-13):** the dashboard should surface the expansion rotor's **radial force `F_radial`**, not the spread *distance* — consistent with the physics direction in §3.

### 2.3 Artifacts produced (all in repo)
- `docs/dashboard-redesign-mockup.html` — full redesigned dashboard, HTML, sample data. Rod has seen and **approved** this look.
- `docs/dashboard-redesign-options.html` — the options board (themes/layouts/panels Rod chose from).
- `docs/dashboard-redesign-dispatch.md` — the decision log / running tally of picks.
- `scripts/dashboard_redesign_prototype.jl` — **GLMakie** prototype of the same layout with sample data. Isolated; touches nothing in `src/`. **v0, UNRUN.** Run: `julia --project=. scripts/dashboard_redesign_prototype.jl`.

### 2.4 Code map for the eventual port into the live dashboard
Target file: `src/visualization.jl`, function `build_dashboard` (starts ~line 128). The redesign is a **presentation-layer change**; the data layer already works — reuse it.
- **HUD construction** (the wall of labels to replace): ~lines 479–623. A row counter `hnr!()` + `hlbl()` helper stacks Labels in `hud = GridLayout(fig[1,3])` (`colsize!(hud,1,Fixed(350))`).
- **Per-frame update handler:** `on(frame_obs) do fi … end` at ~line 1036. This computes all telemetry each frame and pushes text into the named Labels (`t_lbl`, `v_lbl`, `omega_lbl`, `pto_lbl`, `p_lbl`, `tsr_lbl`, `twist_lbl`, `t_frame_lbl`, `c_frame_lbl`, `sag_lbl`, `warn_*`, …). **Keep these names / keep the handler working** — the redesign should re-home these into panels/gauges, not rip out the computation.
- **Controls (left column):** ~lines 1255–1600. Config menu+switch (1269/1279), lift-device menu + sliders `ld_sl_A`/`ld_sl_B` (1325–1392), gen-control menu, depower payout menu, three toggles `active_winch`/`mppt_stall`/`field_imu` (1460–1482), depower sequence menu, frame slider + play (1525–1569), export/reset/re-run buttons.
- **Colour ramps + helpers** already exist at top of file: `_tension_color` (l.14), `_ring_util_color` (l.30), plus `tension_cmap`/`ring_cmap` (l.159–164). Reuse for gauges/colourbars.
- **Theme:** currently `set_theme!(theme_dark())` at l.209; A1 is a darker, single-accent variant of this.

### 2.5 Recommended porting strategy (low-risk)
1. Get the prototype (`scripts/dashboard_redesign_prototype.jl`) rendering correctly on Rod's machine; iterate look/feel from screenshots. Likely first fixes: `Box`+content overlap in a shared grid cell, and gauge `Axis` sizing (gauges are 270° arcs in a hidden-decoration Axis).
2. Once the look is approved, refactor **only** the HUD container layout in `build_dashboard`: replace the flat `hud` Label stack with (a) a top cockpit-strip GridLayout, (b) grouped panels, (c) gauge/sparkline sub-axes — but **keep the same named Label objects and the line-1036 update handler** so live data keeps flowing. Add new Observables only for the gauges/sparklines.
3. Reorganise controls into collapsible-style groups (E1). GLMakie has no native collapsible; emulate with grouped sub-GridLayouts under bold group headers (the prototype shows the pattern).
4. Run `test/runtests.jl` (the dashboard isn't unit-tested, but keep the suite green) and have Rod visually confirm.

### 2.6 Open question for Rod (non-blocking — pick a sensible default and note it)
Should the expansion rotor be a **card in the right diagnostics column** (current prototype choice) or a **metric in the top cockpit strip** (more prominent)? Default if Rod is silent: keep it as a diagnostics card, force-first.

---

## 3. Workstream B — V6 expansion-rotor fix (PARKED)

### 3.1 What the fix is
Friday's task ("fix the V6 campaign and re-run it"). Commit **`6fa32c9`** — *"fix: wire expansion rotor r_eff into v6 structural evaluation"* — on branch **`claude/stupefied-cohen-cf68bb`**. As of 2026-06-13 it is **one commit ahead of `master`** and has been **pushed to `origin`** (backed up — see §4). It is **not merged to master.**

### 3.2 The bug it addresses
`scripts/results/expansion_sweep.csv` showed **zero variance in φ** across all 1,800 rows; `mean_radius_spread_m` was always 0; each rotor added a flat ~0.5 kg dead weight regardless of blade geometry — so v6 looked *worse* than v5. Root cause is the **integration boundary, not the rotor module**:
- `src/expansion_rotor.jl` correctly computes both a radial force `F_radial` and an effective radius `r_eff` (and is unit-tested in `test/test_expansion_rotor.jl`).
- `src/objective_v6.jl::estimate_effective_radii` (~line 154) calls `expansion_rotor_forces(...)`, keeps only `r_new`→`r_eff`, and **discards `F_radial`**. So the structural eval was driven purely by the (weak) displacement channel.

### 3.3 The open physics decision (THIS IS THE BLOCKER — only Rod decides)
Even with `6fa32c9` wiring `r_eff` in, the **displacement channel is intrinsically weak**: the model's own `Δr = F_radial·L_seg/(T·geometry_factor)` is millimetric (the unit test pegs Δr ≈ 0.002 m on a 1 m ring; see `test/test_expansion_rotor.jl` l.22-25, 88-92). The real structural relief lives in **`F_radial`** (a radial pre-load that offloads ring compression / redistributes tether tension), which is currently thrown away.

**Decision Rod must make:** model the expansion benefit as **force (`F_radial`) injected into the structural solver** (let the solver compute the resulting relief), rather than prescribing a derived displacement (`r_eff`). Force-first is more physically honest and avoids the negligible-Δr / zero-variance failure mode.
- If **force-first**: the fix is a rewrite of how `objective_v6.jl` consumes the rotor output (use `F_radial` as a load term), not just wiring `r_eff`. `6fa32c9` becomes a stepping stone, not the final answer.
- If **distance (keep `6fa32c9` as-is)**: merge after verifying tests + a campaign re-run that shows φ actually responds. Expect a marginal benefit at best.

**Do not re-run the v6 campaign until this is decided** — re-running the distance-only model just reproduces a marginal result and wastes a long compute run.

### 3.4 Safety guard (why merging won't break V5)
`N_expansion = 0` must produce identical results to v5 (PLAN.md §FR4, CLAUDE.md). This is guarded in code by the early `return r_eff` (= copy of nominal radii) in `estimate_effective_radii` when there are no rotors. So the proven v5 funder-story model is **not** in the blast radius. Still: prove with `test/runtests.jl` before any promotion to master.

### 3.5 Context: why V5 matters (the funder story)
V5 is the breakthrough — the first version where specific mass φ *improves* with scale (φ crosses below 1.0 from 10→50 kW), breaking the scaling cliff that V3/V4 suffered. The 12 Phase-2.5 figures (committed on master, `b05e17c`) tell this story. V6 must not regress it and must be physically defensible to funders.

---

## 4. Worktrees & repo hygiene (Decision F)

### 4.1 Sync state
- On `master` at `b05e17c` ("Phase 2.5: add rich figure generation script + all 12 figures").
- `git fetch` (2026-06-13) reported **up to date with `origin/master`** — local repo *is* the latest; nothing divergent.

### 4.2 Worktree inventory — 6 × `claude/*`, all ahead of master. DO NOT BLIND-PRUNE.
| Worktree (branch) | Tip | Own commit(s) beyond base | Status |
|---|---|---|---|
| goofy-goldberg-e2f27d | befc31f | none (empty branch point) | likely safe to prune |
| intelligent-bose-150e9b | 798e044 | "feat: implement island model in v6 DE campaign, tighten convergence threshold" | check merge status |
| beautiful-nobel-b0f638 | 8788ae8 | "docs: add v6 campaign result and search bound analysis to DECISIONS.md" | check merge status |
| elegant-nash-346bc1 | 92db616 | "feat: Phase 2.5 figures from expansion sweep and v5 campaign data" | likely == master content (Phase 2.5) |
| competent-bardeen-598fbe | 888fc34 | none (empty branch point) | check merge status |
| **stupefied-cohen-cf68bb** | **6fa32c9** | **"fix: wire expansion rotor r_eff into v6 structural evaluation"** | **The V6 fix. PUSHED to origin (backed up). KEEP until §3 decided & merged.** |

### 4.3 Safe prune procedure (when ready)
```bash
# stupefied-cohen is already pushed (done 2026-06-13). For any others worth keeping:
# git push origin <branch>
git branch --merged master | grep claude/      # ONLY these are safe to delete
# delete only branches that line lists; KEEP stupefied-cohen until its fix is merged
git worktree remove .claude/worktrees/<name>   # add --force only if it refuses & you're sure
git worktree prune
```
Status: confirm-latest = **done**; prune = **pending** (needs a working shell + the §3 decision before stupefied-cohen can go).

---

## 5. Artifact index — where everything lives

**In the repo (visible to Rod and to you):**
- `STATUS-2026-06-13-worktrees-and-staging.md` — *this file.*
- `docs/dashboard-redesign-mockup.html` — approved HTML mockup of the new dashboard.
- `docs/dashboard-redesign-options.html` — the options/swatches board.
- `docs/dashboard-redesign-dispatch.md` — decision log.
- `scripts/dashboard_redesign_prototype.jl` — GLMakie prototype (unrun v0).
- `src/visualization.jl` — live dashboard (`build_dashboard`); port target.
- `src/objective_v6.jl` — where `F_radial` is discarded (~l.154); the force-first rewrite target.
- `src/expansion_rotor.jl` — the (correct, tested) rotor force model.
- `test/test_expansion_rotor.jl` — unit tests proving the rotor module + the millimetric-Δr scale.
- `PLAN.md` §FR4 / §Expansion rotor validation; `CLAUDE.md` (dev commands, physics conservatism, FR4).

**On GitHub:** branch `claude/stupefied-cohen-cf68bb` (the backed-up V6 fix). Open a PR from it if you want review before merging.

**Claude's cross-session memory** (not in repo; persists for the Cowork assistant): a project memory captures the unmerged-fix location, the force-vs-distance decision, and the dashboard decision set, so a future Cowork session reloads this context automatically.

---

## 6. Forward plan for the takeover agent (ordered)

**Safe to do without Rod:**
1. If you have a shell: `git fetch && git status`; `julia --project=. test/runtests.jl` (baseline green). Re-verify §4 worktree table with `git worktree list` / `git branch --merged master`.
2. Get `scripts/dashboard_redesign_prototype.jl` to render (it's unrun). Fix GLMakie issues in the *prototype only*. Iterate look/feel toward `docs/dashboard-redesign-mockup.html`. Capture screenshots for Rod.
3. Draft the `build_dashboard` port as a **non-destructive** change (e.g. a new layout path behind a flag, or a clearly-scoped refactor of lines 479–623 that preserves the line-1036 update handler and all named Labels). Do not remove the working code path until the new one is confirmed on Rod's machine.

**Needs Rod (don't proceed without his call):**
4. The **force-vs-distance** expansion decision (§3.3). This gates the whole v6 direction.
5. Final visual sign-off on the ported dashboard (GLMakie needs his display).
6. The worktree prune (needs shell + confirmation; keep stupefied-cohen regardless until its fix is merged).

**Sequencing recommendation:** finish the dashboard (steps 2–3, 5) first — it's decided, isolated, and low-risk. Keep the expansion fix parked until Rod answers §3.3; then do the force-first rewrite properly, validate against FR4 + tests, merge, push, re-run the campaign.

---

## 7. Minimal open questions for Rod (everything else is decided)
1. **Expansion modelling:** force-first (`F_radial` into the structural solver) or keep the distance model (`r_eff`, commit `6fa32c9`)? — §3.3. *Blocks the v6 direction.*
2. **Expansion in the dashboard:** diagnostics card (default) or top-strip metric? — §2.6. *Non-blocking.*
3. **Worktree prune:** go ahead once a shell is available, keeping stupefied-cohen? — §4. *Non-blocking.*
