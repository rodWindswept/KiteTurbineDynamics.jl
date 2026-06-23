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

## Block 1 — CoaxialAutogyroStacking.jl: visuals + API

The coaxial package provides the lift-stacking story for the report. The API is
useful for integration, but the **priority for conference is visuals**: a clean
stack diagram showing rotors, tension profile, and force vectors.

### Task 1.0: Generate coaxial stack report visuals (PRIORITY)
**Goal:** Produce 2-3 publication-quality figures from the coaxial package:
1. **Stack schematic** — side view of N rotors on a kite line, annotated with
   force vectors (F_lift, F_drag, F_line) at each rotor, tension profile curve
2. **Tension profile plot** — free-end → anchor, showing monotonic increase,
   per-rotor contributions visible as step changes
3. **Optimal pitch sweep** — pitch angle vs rotor position for a representative
   wind speed, showing how downstream rotors need different pitch

**Sources:** `notebooks/dashboard.jl` (Pluto), `src/stack.jl`, `src/rotor.jl`

**Approach options (try in order):**
A. Export from existing Pluto dashboard if it renders on this machine
B. Generate with GLMakie in a standalone script (headless export via CairoMakie)
C. TikZ/PGF diagrams (matching the KTD.jl diagram style)

### Task 1.1: Implement `lift_force_steady` (Task 11 — secondary)
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

### Task 2.5a: Write §5a — Why three blades? Optimizer logic & scaling pathway
**Sources:** `src/objective_v6.jl`, `src/expansion_rotor.jl`, campaign convergence data,
`scripts/results/v6_2_campaign_50kw/best_design.json`

This is the section Rod specifically wants — the physics reasoning behind the
optimizer's choices, and what they imply for larger systems.

**Part A: Why the DE optimizer landed on three blades**
- **Parasitic drag penalty:** Each expansion blade produces profile drag ∝ N_blades.
  The optimizer trades blade count against radial force. Fewer blades = less drag
  but each blade must work harder (higher CL, larger chord).
- **Mass penalty:** Each blade adds knuckle mass at the ring attachment point.
  Three blades minimizes attachment hardware while maintaining enough solidity
  for the required F_radial.
- **Bridle angle sensitivity:** At the optimized bridle angle, three blades
  produce sufficient radial force without excessive axial lift loss. More blades
  would spread the same total force but add parasitic losses.
- **Shaft power budget:** Expansion rotors consume shaft power (τ_drag × ω).
  The optimizer found three blades strikes the balance: enough radial force to
  expand the ring, parasitic power fraction stays below some threshold.
- **DE search history:** Extract from campaign data — did the optimizer try
  2, 4, 5, 6 blades and converge to 3? Or was 3 blade count near the lower
  bound? This tells us whether 3 is a true optimum or a bound artefact.

**Part B: Where expansion rotors scale in larger systems**
- **More expansion stations:** At 100+ kW, the TRPT shaft is longer. More rings
  need spreading. The optimizer logic suggests adding expansion stations at
  strategic ring positions (not every ring — just where beam compression is
  highest in the buckling analysis).
- **Larger blades at higher power:** Blade chord and radius scale with rated
  power. Three blades remain optimal if the parasitic-to-radial force ratio
  stays favourable — but this ratio depends on Re, which changes with scale.
- **Dual-purpose rotors:** The long-term vision: rotors that both extract power
  AND provide expansion force. This eliminates the parasitic power penalty
  entirely — the "drag" becomes useful torque. PLAN.md post-publication
  strategy mentions this.
- **Network topologies:** Multiple expansion stations, concentric rings,
  asymmetric spreading for yaw control. The three-blade minimum-mass pattern
  may extend to these.
- **What the optimizer CAN'T tell us:** The DE optimizer evaluates steady-state
  structural mass only. It doesn't model dynamic bank angle transients, furling
  behaviour, or manufacturing constraints. The three-blade result is a structural
  optimum — dynamic validation pending (M4).

### Task 2.5b: Generate 5 New Analysis Diagrams (d6–d10) — V9/V10 Campaign Era

These 5 diagrams extend the conference report beyond the V6.2-era d1–d5 set, covering
the full design evolution through V10. They tell the honest story: the optimizer found
ever-lower mass (V6.5→V9.0), but those designs failed physical validation. V10 is the
first design that passes all 8 constraint gates. Each diagram is **data-derived from
real campaign CSVs**, rendered as publication-quality TikZ/PNG, and verified with the
3-layer pipeline (pdflatex→pixel>1.5%→pdftotext→vision).

**Diagram criteria (from conversation):**
- Must NOT be a "smudge" — every axis labeled, every callout readable
- All data from real CSVs in `scripts/results/v9_0_campaign_50kw/` and `v10_campaign_50kw/`
- TikZ `article`+`geometry` pattern; compiled with `pdflatex`; verified with `vision_analyze`
- Space budgets computed before drawing; font sizes specified at every level
- Dark theme (`black!95` background, white labels) matching existing V9/V10 diagram style
- Output: `docs/awes-forum-diagrams/diagram-v10-*.tex` + `.png`

---

#### Diagram d6 — Cross-Version Mass Honesty Timeline

**Story (1-3 sentences):** The optimizer found progressively lower mass across V6.2→V6.5→V6.8→V9.0
(74→17.7→58→44.5 kg), but every sub-50 kg design was physically impossible. V9.0 failed
dashboard verification (8× over-power, FoS 0.3). V10 rises to 76.75 kg because it's the
first design that passes all 8 physical constraint gates. The honest mass is higher —
and that's the point.

**Layout:** Horizontal grouped bar chart, 5 version groups (V6.2, V6.5, V6.8, V9.0, V10).
Each bar annotated with mass + key parameters (n, n_rotors, λ). Physical validity marker
overlay: green checkmark = dashboard-verified feasible, red X = physically impossible,
yellow triangle = counterfactual (static TSR=4.1). V10 bar gets a special "8/8 gates"
badge. Connecting line showing that V10 is the first honest design.

**Data provenance:**
| Version | Mass (kg) | Source | Valid? |
|---------|-----------|--------|--------|
| V6.2 corrected | 74.17 | `v6_2_campaign_50kw/best_design.json` | Static only |
| V6.5 (tan error) | 17.7 | `v6_5_campaign_50kw/best_design.json` | ✗ IMPOSSIBLE (14,277× drag) |
| V6.8 (static TSR=4.1) | 58.4 | `v6_8_campaign_50kw/best_design.json` | ⚠ Counterfactual |
| V9.0 (dynamic eq.) | 44.52 | `v9_0_campaign_50kw/best_design.json` | ✗ Dashboard FAIL |
| V10 (8 gates) | 76.75 | `v10_campaign_50kw/best_design.json` | ✓ 8/8 gates |

**Space budget:** 32cm × 18cm paper; 5 bar groups × 4cm each = 20cm horizontal.
Left margin 3cm for y-axis labels. Right margin 4cm for validity markers.
Vertical: mass range 0–150 kg scaled to 14cm. Font: `\large` titles, `\small` bar labels,
`\footnotesize` callouts, `\tiny` parameter text.

**Generation pipeline:**
```bash
# 1. Extract winner data (Julia)
julia --project=. -e '
using JSON, DataFrames
for (ver, path) in [
    ("v62", "scripts/results/v6_2_campaign_50kw/best_design.json"),
    ("v65", "scripts/results/v6_5_campaign_50kw/best_design.json"),
    ("v68", "scripts/results/v6_8_campaign_50kw/best_design.json"),
    ("v90", "scripts/results/v9_0_campaign_50kw/best_design.json"),
    ("v10", "scripts/results/v10_campaign_50kw/best_design.json"),
]
    d = JSON.parsefile(path)
    println("$ver: $(d["best_mass_kg"]) kg, n=$(get(d,"n_lines","?")), n_rotors=$(get(d,"n_active_rotors",get(d,"n_expansion","?")))")
end
'

# 2. Write TikZ (manual) → diagram-v10-mass-timeline.tex
# 3. Compile + verify
pdflatex -interaction=nonstopmode diagram-v10-mass-timeline.tex
python3 ~/.local/bin/tikz_lint.py diagram-v10-mass-timeline.tex --fix
pdftoppm -png -r 300 diagram-v10-mass-timeline.pdf diagram-v10-mass-timeline
mv diagram-v10-mass-timeline-1.png diagram-v10-mass-timeline.png
```

---

#### Diagram d7 — Parasitic Drag Power Budget

**Story:** The V10 winner's 50 kW rated power must overcome parasitic drag. This diagram
shows WHERE the parasitic power goes — tether line drag (dominant, ~4.2 kW), expansion
blade profile drag (~0.8 kW), and ring beam skin friction (negligible, ~0.05 kW).
The hub aero power must exceed parasitic + generator power for equilibrium to exist.
This explains why the parasitic drag model was the critical missing piece from V6.5.

**Layout:** Horizontal stacked bar (total parasitic power) broken into 3 colored segments:
tether lines (red-orange, ~83%), expansion blades (blue, ~16%), ring beams (green, ~1%).
Second bar showing hub aero power for comparison. Annotations: absolute kW + % of rated.
Small inset table: Cd values used (tether cylinder Cd=1.2, beam skin friction Cf=0.003,
blade profile Cd0=0.01 from NACA 4412). Formula reference: P_drag = F_drag × v_tang.

**Data provenance:**
- V10 winner parameters from `scripts/results/v10_campaign_50kw/best_design.json`
- Drag forces computed by `parasitic_drag_power()` in `src/objective_v10.jl`
- Verification: run the actual function on the winner vector, not hand-calculated

**Space budget:** 24cm × 14cm paper. Two horizontal bars stacked vertically (6cm each),
3cm left margin for labels, 8cm right panel for coefficient table. Font: `\large` title,
`\small` bar segment labels, `\footnotesize` table entries, `\tiny` formula references.

**Generation pipeline:**
```bash
# 1. Compute parasitic drag breakdown for V10 winner
julia --project=. -e '
using KiteTurbineDynamics, JSON
best = JSON.parsefile("scripts/results/v10_campaign_50kw/best_design.json")
x = best_to_vector_v10(best)
P_tether, P_beam, P_blade, P_total = parasitic_drag_power_v10(x)
println("tether=$(round(P_tether/1000,digits=1)) beam=$(round(P_beam/1000,digits=1)) blade=$(round(P_blade/1000,digits=1)) total=$(round(P_total/1000,digits=1))")
' > /tmp/v10_parasitic_drag.txt

# 2. Write TikZ → diagram-v10-parasitic-drag.tex
# 3. Compile + verify
```

---

#### Diagram d8 — Constraint Gate Panel (8-Gate Pass/Fail)

**Story:** The V10 winner passes all 8 validation gates — this is what makes it the
first physically-viable design. This 8-panel diagram shows each gate with its threshold
and the winner's actual value. Readers can see at a glance that the design is real:
no gate is marginal, no constraint is gamed. The juxtaposition with V9.0 (which fails
power, FoS, overtwist, and slack) makes the case that V10's higher mass buys physical validity.

**Layout:** 4×2 grid of small panels (8 total), each showing:
- Gate name + threshold (red dashed line)
- V10 winner value (green bar or dot)
- V9.0 value for comparison (red bar or dot, where it fails)
- Margin annotation (e.g., "FoS: 2.1× required")

**The 8 gates:**
| # | Gate | Threshold | V10 winner (verify from campaign) |
|---|------|-----------|-----------------------------------|
| 1 | Beam buckling FoS | ≥ 2.0 | Extract from `verification_log.csv` |
| 2 | Torsion FoS | ≥ 1.5 | Extract |
| 3 | Tether FoS | ≥ 3.0 | Extract |
| 4 | Overtwist guard | twist < 2π | Extract |
| 5 | Slack fraction | < 5% | Extract |
| 6 | Parasitic power | P_par < P_aero | Extract |
| 7 | Power accuracy | 0.75 ≤ P/P_rated ≤ 1.25 | Extract |
| 8 | Rotor usefulness | min(λ·cos(β)) ≥ 0.01 | Extract |

**Data provenance:** All gate values from `verification_log.csv` (V10 campaign checkpointing).
If `verification_log.csv` doesn't have per-gate breakdown, compute by running
`_validate_island()` on the winner vector and printing each gate result.

**Space budget:** 28cm × 18cm paper. 4 columns × 2 rows = 8 panels. Each panel ~6cm × 7cm.
Margins: 2cm left, 1cm between panels. Font: `\large` panel titles, `\footnotesize` gate
descriptions, `\tiny` threshold/margin annotations.

**Generation pipeline:**
```bash
# 1. Dump validation gate results for V10 winner + V9.0 winner
julia --project=. -e '
using KiteTurbineDynamics, JSON, CSV, DataFrames
vl = CSV.read("scripts/results/v10_campaign_50kw/verification_log.csv", DataFrame)
println(last(vl, 1))  # last entry should be V10 winner validation
' > /tmp/v10_gate_results.txt

# 2. Write TikZ (manual, 8 panels) → diagram-v10-constraint-gates.tex
# 3. Compile + verify
```

---

#### Diagram d9 — Rotor Configuration & Usefulness Map

**Story:** The V10 optimizer places rotors on specific rings with a λ gradient (larger
blades at top, smaller at bottom) and a bank gradient (shallower at top, steeper at
bottom). This diagram shows the rotor mask (which rings get rotors), the λ and bank
profiles, and the resulting λ·cos(bank) "usefulness" metric. It also shows why the
V9.0 winner's 9 expansion rotors were "decorative" — their λ·cos(bank) was below the
usefulness threshold, meaning they produced near-zero thrust while adding parasitic drag.

**Layout:** Three-panel horizontal:
1. **Rotor mask** — 3D schematic of TRPT shaft with rings, rotors shown as filled circles
   at their ring positions. Size proportional to λ. Color = usefulness (green = useful,
   red = decorative).
2. **λ and bank profiles** — line plots: λ vs ring index (decreasing downward), bank vs
   ring index (increasing downward). V10 winner as solid lines, V9.0 as dashed.
3. **Usefulness scatter** — λ·cos(bank) vs ring index. Horizontal threshold line at 0.01
   (validation gate). Points below = decorative rotors. V9.0 has many below; V10 has none.

**Data provenance:**
- Rotor mask from V10 winner's `rotor_mask_proxy` (decoded to ring positions)
- λ_top, λ_bottom, bank_top, bank_bottom from `best_design.json`
- λ and bank at each ring: linear interpolation between top and bottom
- V9.0 rotor positions from `v9_0_campaign_50kw/best_design.json` `n_expansion` + ring positions

**Space budget:** 30cm × 14cm paper. Three panels at 8cm, 10cm, 10cm width. 2cm gaps.
Font: `\large` panel titles, `\small` axis labels, `\footnotesize` point labels, `\tiny` annotations.

**Generation pipeline:**
```bash
# 1. Decode rotor mask + compute usefulness
julia --project=. -e '
using KiteTurbineDynamics, JSON
best = JSON.parsefile("scripts/results/v10_campaign_50kw/best_design.json")
mask = best["rotor_mask_proxy"]
ring_positions = decode_rotor_mask(mask, best["n_rings"])
λ_top, λ_bottom = best["lambda_top"], best["lambda_bottom"]
bank_top, bank_bottom = best["bank_top"], best["bank_bottom"]
for (i, r) in enumerate(ring_positions)
    frac = i / length(ring_positions)
    λ = λ_top + frac*(λ_bottom - λ_top)
    bank = bank_top + frac*(bank_bottom - bank_top)
    usefulness = λ * cosd(bank)
    println("ring=$r λ=$(round(λ,digits=3)) bank=$(round(bank,digits=1)) usefulness=$(round(usefulness,digits=4))")
end
' > /tmp/v10_rotor_usefulness.txt

# 2. Same for V9.0 winner
# 3. Write TikZ → diagram-v10-rotor-config.tex
# 4. Compile + verify
```

---

#### Diagram d10 — Per-Island Strategy Divergence Map

**Story:** The 60-island DE optimizer explores different regions of parameter space in
parallel. This diagram uses PCA projection (from the V10 campaign's 14-D parameter trace)
to show where each island's search converged. Islands cluster into two basins:
Basin A (compact, few rotors, low structural scale) and Basin B (expansion-dominant,
more rotors, higher PC2). The winning island (41, 76.75 kg) sits in Basin A — the
compact strategy wins. Islands that got stuck in local minima are visible as outliers.
This shows the optimizer's exploration strategy and gives confidence the global basin
was found.

**Layout:** 
- **Main panel:** PCA scatter (PC1 vs PC2), each point = one island's final best position.
  Color = final mass (viridis inverted). Size = convergence iteration count.
- **Annotation callouts:** Winner island circled + labeled. Basin A vs B regions outlined
  with dashed ellipses. Outlier islands annotated with brief explanation (e.g., "n=19, stuck").
- **Sidebar:** PC1/PC2 interpretation guide (same as existing V10 landscape diagram).
- **Bottom:** Convergence iteration histogram (how many iterations each island took to converge).

**Data provenance:**
- PCA from `v10_campaign_50kw/parameter_trace.csv` (600K+ rows, 14 parameters)
- Final best per island from `island_bests.csv`
- PCA mean/std/V already computed in `/tmp/v10_pca_*.txt` (from prior V10 landscape run)
- Julia extraction script: `scripts/export_v10_landscape_data.jl` (exists, ran successfully)

**Space budget:** 28cm × 18cm paper. Main PCA panel 20cm × 14cm. Sidebar 6cm wide.
Histogram strip 26cm × 3cm at bottom. Font: `\large` title, `\small` axis labels,
`\footnotesize` annotation callouts, `\tiny` sidebar text.

**Generation pipeline:**
```bash
# 1. Extract per-island final best PCA coordinates + mass
julia --project=. scripts/export_v10_strategy_data.jl  # new script, similar to export_v10_landscape_data.jl
# Outputs: /tmp/v10_island_pc1.txt, pc2.txt, mass.txt, iters.txt

# 2. Write TikZ → diagram-v10-strategy-divergence.tex
# Julia prints TikZ \draw commands for each island point + annotations
# 3. Compile + verify
pdflatex -interaction=nonstopmode diagram-v10-strategy-divergence.tex
python3 ~/.local/bin/tikz_lint.py diagram-v10-strategy-divergence.tex --fix
pdftoppm -png -r 300 diagram-v10-strategy-divergence.pdf diagram-v10-strategy-divergence
mv diagram-v10-strategy-divergence-1.png diagram-v10-strategy-divergence.png
```

---

#### Diagram Generation Order & Dependencies

1. **d6 (Mass Timeline)** — depends only on `best_design.json` files from each campaign. Zero data extraction needed.
2. **d7 (Parasitic Drag)** — needs winner vector fed through `parasitic_drag_power_v10()`. Verify the function works first.
3. **d8 (Constraint Gates)** — needs `verification_log.csv` or re-run `_validate_island()` on winner.
4. **d9 (Rotor Config)** — needs rotor mask decoding + interpolation. Confirm `decode_rotor_mask()` exists.
5. **d10 (Strategy Map)** — needs PCA data (already computed in `/tmp/v10_pca_*.txt`) + per-island extraction script.

d6 and d9 can proceed in parallel. d7 and d8 share the V10 winner validation data.
d10 is independent once PCA data is confirmed.

#### Verification Checklist (per diagram)

- [ ] `tikz_lint.py --fix` passes (0 non-Unicode issues)
- [ ] `pdflatex` compiles with 0 errors in `.log`
- [ ] `pdfinfo` shows exactly 1 page
- [ ] `pdftoppm -r 300` produces PNG; pixel check > 1.5% non-white
- [ ] `pdftotext` grep confirms key narrative text present
- [ ] `vision_analyze` confirms: properly rendered diagram (not raw text, not blank)
- [ ] All numbers match CSV source data (±0.1 kg for mass, ±0.01 for λ)


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
**Figures to include (d1–d5: V6.2 era; d6–d10: V9/V10 era; coax: coaxial package):**
- d1: Polygon comparison (n=8 vs n=12)
- d2: Density profile
- d3: Mass scaling (10 kW → 50 kW)
- d4: Optimization landscape
- d5: Bank angle expansion
- **d6: Cross-version mass honesty timeline** (V6.2→V10, physical validity markers)
- **d7: Parasitic drag power budget** (tether/beam/blade breakdown)
- **d8: Constraint gate panel** (8-gate pass/fail for V10 winner vs V9.0)
- **d9: Rotor configuration & usefulness map** (rotor mask + λ/bank profiles + decorative rotor analysis)
- **d10: Per-island strategy divergence map** (PCA colored by basin, winner annotated)
- Coaxial stack schematic (TikZ or from Pluto dashboard export)
- System architecture comparison (Daisy / Pyramid / Expansion)

All d6–d10 diagrams: data-derived from real CSVs, TikZ `article`+`geometry` pattern,
3-layer verified. See Task 2.5b for full specs, generation pipelines, and verification
checklist.

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
