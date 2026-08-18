# Wayfinder — post-5kW-rung, pre-7kW (2026-08-15)

**Context:** the 5 kW rung is solved on the corrected model: three campaigns
(18.0/21.2/25.0 m), all winners re-gate green (7.68/8.24/8.32 kW at the
ground, coherent chains, all structural checks). Before transferring the
method to 7 kW, we analyze, validate, and tidy what we have.

## Workstreams (order = dependency order)

### W1. Winners into the interactive dashboard — quick, standalone
- Three new dashboard configs (18.0/21.2/25.0 m winners) so Rod can fly them.
- Check ktd-dashboard-config skill for the current config format; configs are
  geometry-only (no legacy physics modes — current model: polygon chain + BEM).
- **Need from Rod:** when he wants the dashboard session (GLMakie on desktop).

### W2. Genome-pool analysis — data-ready, no new runs needed
Telemetry CSVs carry the full genome + rejection reason per eval for all three
campaigns. Deliverables:
- **Distance-to-winner maps** in genome space (14-D): how far are the
  second-best designs, where do the losing families sit.
- **Failure census:** categorize every rejected eval — twist, line break,
  Betz, tip-speed, clearance, power-shortfall — per campaign.
- **Losing-family scaling hypothesis:** do multi-rotor / expansion-rotor
  designs fail for rung-dependent reasons (they may come into their own at
  larger scale, where more rotors share the Betz budget)? Answer with the
  failure margins, not vibes.
- **Deliverable:** `scripts/results/pool_analysis.md` + figures.

### W3. Rapid ↔ ODE evaluator calibration — the efficiency lever for 7 kW
- Map rapid-evaluator fitness onto ODE-gate verdicts over a sample of
  telemetry designs (all three campaigns).
- Identify outliers (rapid says good, ODE rejects / vice versa), classify
  their failure mode, and derive a correction (weight or gate).
- **Deliverable:** calibration report + the updated rapid objective module
  (ktd-objective-development skill).
- This is the single biggest speed-up available for the 7 kW campaign.

### W4. Validation & communication (the "report")
- 5 kW rung proof document: winners, verdicts, the design family (single
  rotor, r_hub at floor, n_lines ∝ length), ladder envelope, provenance.
- Feed into Monday's retrospective (already drafted, §4 has the ladder +
  campaign results).

### W5. Root-folder tidy — discussion item, low risk, needs Rod's calls
Inventory (facts):
- Stray artifacts at root: 6 × `diag_*.csv`, `run_all_sims.log`,
  `sweep_hub.log` — move to `scripts/results/_diagnostics/`.
- `.superpowers/` (156 K, contains one `brainstorm/` subfolder) — remnant of
  past tooling. **Question for Rod:** anything worth keeping? Else archive.
- Duplicates: `scratch/` and `.scratch/`; `charts/` vs `figures/` overlap.
- `TRPT_Results/` — older results folder; check against current
  `scripts/results/` layout before merging.
- House rule (root-file-hygiene skill): root = core docs + Project.toml +
  tooling only. Proposal: one tidy commit after Rod answers the questions.

### W6. 7 kW transfer — after Monday's (b) decision
- Ladder says the 7 kW seed is already viable (5.92–6.64 kW at 18–21.2 m) —
  no Betz-undersize problem at this rung (that starts at 25 kW).
- Campaign config: reuse the v13 runner with the 7 kW seed + bounds
  (compute_seeds), length set guided by the 5 kW findings (18–25 m band).
- Launch order: after W2/W3 land (calibration makes the rung cheaper), and
  after Monday's (b) verdict on the static gates.

### W7 (done) + W8. The anchor/calibration session (2026-08-16/17) — DONE
A full session calibrated the model against the 29-Apr-2020 mast test
(thesis config 9) — four stacked faults found and fixed (dt=4e-6,
measured τ(ω) table, const-tension bucket, no expansion rotor), the
measured envelope re-derived at 30-s means (Rod's windowing challenge),
and F9 built: model 234 W vs measured 223 ± 79 W at 6.25 m/s,
Cp_sys ≈ 0.16 both (Oliver's spring-disc 0.166). Full details in the
retrospective addendum. **Remaining from W8:**
- Commit decision: `GeneratorLoadMode` + `const_tension` src changes are
  staged (working tree, uncommitted) — laptop-authoritative sign-off.
- Gemini vision pass over the April-29 photos/video (elevation/bank/ring
  confirmation) — the vision system passed Rod's bucket-photo test; the
  full media pass is still open.
- Self-start/EXP_CD_STALL — the anchor's cold-start blocker, now known to
  be the SAME mechanism as the ladder's ≥25 kW stall (see retrospective
  §4 correction). One fix serves both.
- Rod's system-Cp point: no raw field Cp into the ODE (double-counts the
  generator/controller) — dropped as a calibration route, documented.

## Sequence

```
W1 (dashboard) ──┐
W2 (pool)        ├── W4 (report) ── Monday retrospective ── (b) decision
W3 (calibration)─┘                                        ── W6 (7 kW launch)
W5 (tidy)        — anytime, needs Rod's answers
W8 (anchor)      — DONE 2026-08-16/17; open: commit sign-off, media vision pass
```

## Status update (2026-08-16/17 session)

- W4 (report): in flight — F3/F4/F6/F7 + F9 built, prose'd, vision-passed,
  two Rod HITL rounds. report-v2 skeleton + metrics.csv still pending.
- W8 (anchor, new): DONE as above — the session that produced F9 and the
  DECISIONS.md 2026-08-16 entry.
- W6 (7 kW): unchanged — seed viable; still gated on Monday's (b) verdict
  and W3. The retrospective's ≥25 kW correction does NOT affect the 7 kW
  rung (the 7 kW seed spins up fine in the ladder).
- W1/W2/W3/W5: unchanged (dashboard Tuesday, pool data-ready, W3 parked,
  tidy awaiting Rod's answers).

## Open questions for Rod — RESOLVED (2026-08-15, evening)

1. `.superpowers/brainstorm` — scanned: three brainstorm sessions' outputs
   (research-ecosystem maps, approaches, evidence, deep analysis, ~59 KB
   HTML, ~May 2026). Recommendation: archive, don't delete.
2. Dashboard session — Tuesday at the earliest.
3. **W3 parked** — the telemetry holds rapid-evaluator results only; the
   calibration needs 50–100 fresh full-ODE evals. Big job, deliberately
   deferred.
4. **New priority (W7): reproducibility documentation** — done:
   `REPRODUCIBILITY.md` at the root (what/how/why/when, exact commands,
   expected outputs, recorded verdicts, ~11 h single-machine to reproduce).
   W2 (pool analysis) remains the data-only next item feeding the reporting.
