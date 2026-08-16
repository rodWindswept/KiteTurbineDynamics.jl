# Handover — 2026-08-16 (anchor + reporting session)

**From:** Hermes (desktop, KTD.jl repo)
**To:** next agent session
**Repo:** /home/rod/Documents/GitHub/KiteTurbineDynamics.jl (HEAD pushed to
origin/master; laptop is authoritative for code changes — pull first).

## What this session accomplished

1. **Rope-break physics landed and verified** — SK99 3.5% strain, line-path
   criterion on the precomputed TRPT-chain map (`sub_seg_trpt_seg`), option B
   (break = immediate disqualification), `breaks_enabled` gating so settle
   transients can't break healthy machines. C1 torque saturation reworked
   onto the real ring→rope-node→ring chain topology with action-reaction.
   Acceptance suites R1–R3, P1–P4, B1–B7 green; main suite 1900/1900.
   Commits `1d0a38a` and following. See `DECISIONS.md` [2026-08-14] entry.
2. **5 kW rung proven** — three DE campaigns (18.0/21.2/25.0 m) all re-gate
   green: 7.68/8.24/8.32 kW at the ground ring, coherent chains.
   Verdicts in `scripts/results/v13_5kw_len*/regate_verdict.md`.
3. **Scalability ladder** — `scripts/results/ladder_v13.csv` (42 cells):
   viable 5–15 kW, denied ≥25 kW by swept area (Betz ceiling 19.3 kW vs
   40 m²), twist-walled at 40 m. Analysis in
   `docs/plans/retrospective-2026-08-17.md` §4.
4. **Retrospective held early with Rod** — decision 1 LOCKED: the
   model-admissibility checklist (`docs/validation/model-admissibility.md`,
   15 gates + pre-launch procedure + waiver log) is now the campaign launch
   gate. Q1 (lin_damp fling) RESOLVED: companion fix (c) is OUT
   (`scripts/results/q1_lindamp_verdict.md`).
5. **AWES report planned** — `docs/plans/2026-08-15-awes-report-plan.md`:
   8 sections, 8 figures (F1–F8), per-figure PRD folders, 3-round review
   (styling → data accuracy → formatting → human-in-the-loop). Extends the
   prior report infrastructure (`docs/community/ktd-community-report.tex`,
   `docs/outreach/ktd-technical-report.tex`). Title last; F8 = failures-and-
  -learnings table + prose; publish = PDF + AWES forum + windswept.energy.
   Vision tool NOT available in this session — Rod may provision one; the
   human-in-the-loop review rounds need it (or Rod's eyes).
6. **Daisy calibration anchor assembled** — the big piece. See
   `docs/validation/daisy-anchor-provenance.md` for the full fact chain.

## THE OPEN TASK — do this first

**April-29 (2020) mast-mount rig: the model build is wind-blind.**

Measured side is DONE and solid: `scripts/results/april29_anchor.csv`
(1,206 synced rows from the 2021 merged workbook via
`scripts/report/parse_april29.py`): the machine regulates at 212–227 W
across 5–8 m/s, 178–194 W at 3.25–3.75 m/s.

Model side (`scripts/build_april29_rig.jl` + `scripts/anchor_april29_compare.jl`):
after three parameter corrections (settle ceiling → 20; bank → 0°; chain
elevation → 10° per Rod), the sweep still returns **13.5 W / 5.98 rad/s at
every wind 3.25–8.75 m/s** — the hub-rotor aero is decoupled.

Two clues for the diagnosis:
- ω frozen at the initial spin (5.98 ≈ 6.0) at all winds → no wind-dependent
  torque reaches the chain.
- Generator power 13.5 W at ω=5.98 implies k_eff ≈ 0.38 vs k_mppt = 0.1055
  (3.6× off) → the generator-torque path for this build differs from what
  the gate uses.

Diagnosis path: trace how `build_kite_turbine_system` couples the hub
rotor's aero (main `sys.rotor` BEM vs `ExpansionRotorParams` annulus) and
how `get_generator_torque` / the MPPT torque enters for this build. Read
`src/dynamics.jl`, `src/expansion_rotor.jl`, `src/ring_forces.jl`. Do NOT
keep sweeping builder parameters blind — read the source first.

## Anchor facts (corrected this session — do not re-derive)

- April-29 2020 mast rig = thesis TRPT-5: hex rings, central tether removed,
  6 outer tethers. Thesis: `Tulloch, PhD Thesis Final Submission.pdf` in
  `/media/rod/Stored/Windswept_Energy/03_Engineering/Academic Uni &
  Research/Strathclyde/` (text extract at /tmp/tulloch.txt on the desktop,
  may be gone after reboot — re-extract with pdftotext).
- Lines **2 mm UHMWPE** (Rod, builder). Thesis never says 4 mm — the
  "4 mm" in `scripts/daisy_builder.jl:42` and the daisy notebook is STRUCK;
  fix daisy_builder's comment when touching it.
- Rig: chain elevation **~10°** (rotor low, square-on to the wind), blade
  bank **0°** (video-visible), mast 4.3 m supports the bucket pulley,
  70 cm hex rings, 50 cm spacing PTO→ring 8 then graded up, 12 rings total,
  6 blades, R_rotor ≈ 1.95 m (derived from tip 9.43 m/s at 47 rpm),
  bucket 12 kg = 118 N constant lift.
- Logged tension (18–22 kg) = AXIAL AT THE PTO WHEEL, not the lift line —
  includes chain angle/pulley factors over the 12 kg bucket. It's a
  potential model-check channel, not an error.
- Open data question: merged workbook Power (~220 W plateau) vs raw SRM CSV
  (89–198 W) differ; reconcile against the model run.
- Unconfirmed assumption: chain length 5.5 m (inferred). Ask Rod.

## Other open items (priority order)

1. April-29 model diagnosis (above) → then the first power-vs-wind
   comparison = the opening move of (b) scale-aware static gates.
2. Dashboard session Tuesday: three winner configs for the GLMakie dashboard
   (`scripts/interactive_dashboard.jl`).
3. Report data figures F3/F4/F6/F7 from existing CSVs (no compute):
   `scripts/results/ladder_v13.csv`, `v13_5kw_len*/convergence.csv`,
   telemetry. Extraction scripts: `scripts/report/`.
4. (b) scale-aware static-gate threshold derivation — after the anchor
   comparison lands.
5. 7 kW campaign launch — after (b); ladder says the 7 kW seed is viable
   (5.9–6.6 kW). Lengths 18/21.2/25 m.
6. W3 rapid↔ODE calibration: PARKED by Rod (needs 50–100 ODE evals).
7. Root-folder tidy: `.superpowers/` → archive (recommendation), stray
   diag CSVs at root → scripts/results/_diagnostics/.

## Suggested skills

- `ktd-simulation-workflow` / `ktd-codebase-architecture` (relaod if pruned)
- `diagnosing-bugs` — for the wind-blind aero trace
- `ktd-chart-design`, `scientific-diagrams`, `diagram-patterns` — for the
  report figures
- `ktd-campaign-dev` — before any 7 kW launch
- `windswept-drive-cleanup` — if the root-tidy expands to the drives

## Verification before anything new

```bash
cd /home/rod/Documents/GitHub/KiteTurbineDynamics.jl && git pull --rebase
julia --project=. test/runtests.jl            # expect 1900/1900
julia --project=. test/test_rope_break.jl     # R1-R3 green
julia --project=. test/test_rotor_power_realism.jl  # P1-P4 green
```

Multi-writer repo: laptop is authoritative; stash -u → pull --rebase →
stash pop. No campaigns running. Monitor cron removed.
