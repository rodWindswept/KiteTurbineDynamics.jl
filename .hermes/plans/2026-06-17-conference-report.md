# Conference Report Plan — AWES Forum / AWEC Ready

> **For Hermes:** Use `/goal` to track this autonomously. Work through each block, commit
> incrementally, report blockers immediately.

**Goal:** Produce a conference-ready report covering the full TRPT kite turbine suite
(KTD.jl + CoaxialAutogyroStacking.jl) by end-of-week. Single coherent narrative: the
scaling problem → expansion rotor solution → coaxial lift stacking → corrected physics
→ campaign results → known limitations.

**Deadline:** Sunday 21 June 2026 (4 days)

**Architecture:** Markdown master document in `docs/reports/` with embedded TikZ/PNG
diagrams, exportable to PDF or .docx for printing. All claims traceable to committed
code + reproducible campaign output.

---

## Block 0 — Resolve the information hazards (HIGHEST PRIORITY)

Nobody should walk away from this repo citing 58 kg at n=3. Fix before writing.

### Task 0.1: Mark superseded reports
**Files:** All old .docx in `archive/reports/`, old .md reports referencing pre-correction physics
**Action:** Add a `SUPERSEDED.md` notice in `archive/reports/` explaining that v1–v3
contain the tan-formula results (58 kg, n=3) and have been superseded by the corrected
v6.2 analysis (74.17 kg, n=12 dodecagon). Reference the canonical report location.

### Task 0.2: Resolve C3 (duplicate report location)
**Files:** `docs/awes-forum-v62-report.md` (stale copy) vs `docs/awes-forum-diagrams/awes-forum-v62-report.md` (canonical)
**Action:** Delete the stale copy at `docs/awes-forum-v62-report.md`. The diagrams folder
copy is canonical (co-located with figures).

### Task 0.3: Resolve C7 (cos³ legacy comment)
**File:** `src/visualization.jl` line ~1453
**Action:** Update comment from "cos³β" to "cos²·⁶⁵β" to match corrected code.

### Task 0.4: Verify test suite green
```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
julia --project=. test/runtests.jl
```
**Expected:** All 917 tests pass (or whatever the current count is). If any fail, fix
before proceeding — the conference report must reference a green suite.

---

## Block 1 — CoaxialAutogyroStacking.jl: close out Task 11

The coaxial package is the lift-stacking story. It needs its integration API before
it can be properly referenced in the report.

### Task 1.1: Implement `lift_force_steady` (Task 11)
**File:** `src/stack.jl` (or new `src/integration.jl`)
**What:** `lift_force_steady(stack::AutogyroStack, rho, v_wind) → (F_hub, T_anchor, elevation)`
Mirrors the dispatch pattern in KTD.jl's `lift_kite.jl`. Wraps `stack_tension_profile`
and `optimal_pitches`.
```julia
function lift_force_steady(stack::AutogyroStack, rho, v_wind)
    pitches = optimal_pitches(stack, rho, v_wind)
    pitched_stack = set_pitches(stack, pitches)
    profile = stack_tension_profile(pitched_stack, rho, v_wind)
    F_hub = profile[end]  # anchor tension = force at hub attachment
    T_anchor = profile[end]
    elevation = stack.line_angle_deg
    return (F_hub, T_anchor, elevation)
end
```

### Task 1.2: Run coaxial test suite
```bash
cd ~/Documents/GitHub/CoaxialAutogyroStacking.jl
julia --project=. test/runtests.jl
```
**Expected:** All tests pass including new integration test.

### Task 1.3: Phase 6 quality gates for coaxial package
Run the quality-gate checks documented in `PLAN.md`:
- Forces scale with v²
- Zero wind → tension from weight only
- More rotors → more lift (linear with N)
- Tension monotonic increasing downward
- Pitch=0 autogyro matches PCA-2 baseline

---

## Block 2 — Write the conference report

Master document: `docs/reports/CONFERENCE_REPORT_2026-06.md`

### Task 2.1: Report structure and front matter
**Sections:**
1. Abstract / Executive Summary (200 words)
2. Introduction: the TRPT scaling problem
3. The Expansion Rotor Solution (KTD.jl v6.2)
4. Coaxial Autogyro Lift Stacking (CoaxialAutogyroStacking.jl)
5. Corrected Physics & Campaign Results
6. Integration Pathway
7. Known Limitations & Next Steps
8. References

### Task 2.2: Write §1–2 (problem statement + context)
**Sources:** `PLAN.md` §Mission & Strategic Context, `RECAP.md` §1, `CONTEXT.md`
**Key points:**
- TRPT mass/power ratio worsens from 1.15 kg/kW at 10 kW → 1.59 kg/kW at 50 kW
- The scaling cliff kills the commercial case at utility scale
- Expansion rotors: replace passive compression rings with actively-lifted blades
- Five engineering breakthroughs (RECAP.md): torsional damping, viscoelastic tethers, PTO inertia matching, cascade lift stack, free 3D hub elevation

### Task 2.3: Write §3 (expansion rotor solution)
**Sources:** `docs/awes-forum-diagrams/awes-forum-v62-report.md`, PLAN.md §FR1–FR4
**Key points:**
- N expansion rotors at arbitrary ring positions
- Effective radius feedback into structural evaluation
- Parasitic power accounting (τ_drag × ω as fraction of rated power)
- N_expansion=0 ≡ v5 (backward compatibility)
- Force-first model: F_radial injected into structural solver

### Task 2.4: Write §4 (coaxial autogyro lift stacking)
**Sources:** `CoaxialAutogyroStacking.jl/README.md`, `PLAN.md`
**Key points:**
- Multiple independently-pitched autogyro rotors on one kite line
- PCA-2 empirical rotor disk data
- Stack tension profile: free-end → anchor accumulation
- Optimal pitch per rotor
- Integration API mirroring KTD.jl dispatch

### Task 2.5: Write §5 (corrected physics + campaign results)
**Sources:** `docs/case-notes/`, campaign results CSVs, `handovers/handover-2026-06-17.md`
**Key points:**
- tan→sin correction: polygon beam compression was overestimated
- cos³→cos²·⁶⁵: elevation exponent corrected in all files
- Coupled knuckle mass model: geometry-derived, not hardcoded
- V6.2 campaign result: **74.17 kg at 50 kW** (n=12 dodecagon)
- Comparison to v5 baseline: 11.47 kg at 10 kW, 79.5 kg at 50 kW
- Include d1–d5 diagrams

### Task 2.6: Write §6 (integration pathway)
**Key points:**
- CoaxialAutogyroStacking.jl → KTD.jl lift_kite.jl integration
- `lift_force_steady` dispatch pattern
- Shared PCA-2 data (Phase 0.4 from PLAN.md: import from coaxial package)
- Future: multi-rotor power extraction + expansion (dual-purpose rotors)

### Task 2.7: Write §7 (known limitations — HONEST)
**Sources:** `03_missing_context.md`, `02_conflict_log.md`
**Key points — do not hide these:**
- M1: AeroDyn input files not in repo — cannot regenerate BEM tables
- M3: Solidity exponent k=0.7 is a placeholder — n=12 result is sensitive to this
- M6: Knuckle mass calibration ±5 kg uncertainty
- M4: Bank angle dynamic validation pending
- M5: Expansion rotor airfoil assumptions (CL=1.0, CD0=0.02, k_induced=0.05)
- Expansion rotor model is force-first, displacement channel is millimetric
- No wake interaction in coaxial model (v2 scope)

### Task 2.8: Generate/embed all figures
**Figures to include:**
- d1: Polygon comparison (n=8 vs n=12)
- d2: Density profile
- d3: Mass scaling (10 kW → 50 kW)
- d4: Optimization landscape
- d5: Bank angle expansion
- Coaxial stack schematic (TikZ or from Pluto dashboard export)
- System architecture comparison (Daisy / Pyramid / Expansion)

---

## Block 3 — Polish & export

### Task 3.1: Run all test suites one final time
```bash
# KTD.jl
cd ~/Documents/GitHub/KiteTurbineDynamics.jl && julia --project=. test/runtests.jl
# Coaxial
cd ~/Documents/GitHub/CoaxialAutogyroStacking.jl && julia --project=. test/runtests.jl
```
**Expected:** Both green. Record test counts in report.

### Task 3.2: Verify all diagram generation scripts work
Regenerate d1–d5 from committed scripts to confirm reproducibility.
```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams
# Recompile each .tex to .pdf/.png
for f in diagram1-polygon-v4 diagram2-density-v4 diagram3-mass-scaling-v4 diagram5-bank-angle-expansion; do
    pdflatex $f.tex && pdftoppm -png -r 300 $f.pdf $f
done
```

### Task 3.3: Convert report to .docx for printing
Use pandoc:
```bash
pandoc docs/reports/CONFERENCE_REPORT_2026-06.md -o docs/reports/CONFERENCE_REPORT_2026-06.docx \
  --from markdown --to docx --reference-doc=docs/reports/template.docx
```

### Task 3.4: Commit everything
```bash
git add -A
git commit -m "docs: conference report — full TRPT suite, corrected physics, campaign results"
git push origin master
```

---

## Block 4 — Deferred (not needed for conference, but note in plan)

### Task 4.1: Resolve C4 (knuckle mass values)
Unify `economics.jl`, `spacer_ring_design.jl`, and `trpt_optimization.jl` to use the same knuckle mass model.

### Task 4.2: Resolve C6 (campaign result directories)
Archive stale directories, add README to `scripts/results/`.

### Task 4.3: Dashboard Phase 3 (collapsible controls E1)
### Task 4.4: Dashboard Phase 4 (loads safety panel D2)

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Test suite not green | Fix before writing — foundation must be solid |
| AeroDyn files still missing (M1) | Document honestly in §7; don't hide it |
| Coaxial Task 11 breaks existing tests | Run suite before/after; rollback if needed |
| Diagram regeneration fails (LaTeX deps) | Use committed PNGs as fallback |
| Pandoc not installed | Install with apt or use Python python-docx instead |
| Time runs out before Block 3 (polish) | Prioritize Blocks 0→1→2 in order; §7 (limitations) is the most important section for credibility |

## Success criteria

- [ ] All old reports marked as superseded
- [ ] Test suites green in both repos
- [ ] Coaxial Task 11 implemented and tested
- [ ] Conference report covers both repos in coherent narrative
- [ ] All 5+ diagrams embedded
- [ ] Known limitations documented honestly in §7
- [ ] Report exportable as .docx
- [ ] Committed and pushed to GitHub
