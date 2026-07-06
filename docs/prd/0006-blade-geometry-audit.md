# PRD 0006 — Blade Geometry Audit & Recovery

**Status:** ACTIVE  
**Date:** 2026-07-05  
**Severity:** CRITICAL — systematic error in expansion rotor blade geometry  
**Root cause:** `blade_hub_radius = 0.25 * blade_tip_radius` (positive outboard offset)
placed the entire blade annulus outboard of the ring attachment point. Correct
geometry is 70% outboard, 30% inboard: `hub = -0.3·span`, `tip = +0.7·span`.

## Impact summary

The mean aerodynamic radius shifted from `r_nom + 0.625·s·cos(β)` to
`r_nom + 0.2·s·cos(β)`. The offset from ring was overstated by a factor of
**~3.1×**. This affects every simulation that used expansion rotors.

### What's affected

| System | Impact | Severity |
|--------|--------|----------|
| Expansion rotor aero power | r_mean position changes TSR, ω, k relationships | HIGH |
| Shaft torque | r_mean × lift — overstated by ~3× in offset component | HIGH |
| Blade centrifugal forces | r_mean × ω² × m_blade — wrong loading into ring FEA | HIGH |
| Ring structural FoS | Forces at wrong radius → wrong ring compression/buckling | HIGH |
| Loss model (c·ω³) | ω depends on r_mean — c fit invalid | HIGH |
| k_mppt values | k ∝ ω⁻³ ∝ r_mean⁻³ — k values ~5× too high | HIGH |
| Blade scaling laws (λ²/λ⁵) | r_mean ratio enters k_schedule; analysis invalid | HIGH |
| V6-V10 optimisation campaigns | Objective function evaluated on wrong physics | HIGH |
| Gate 1 control maps | All three builders used wrong geometry | HIGH (re-running) |
| Pitch depower campaigns | If expansion rotors used | MEDIUM |
| Technical report numbers | P, FoS, ω, k, loss — all provisional | HIGH |
| AWEC Porto poster claims | Any FoS/power numbers from expansion rotor sims | HIGH |
| Dashboard visualisation | Blades drawn outboard only | FIXED |
| Community outreach docs | Technical report, briefs | HIGH |

### What's NOT affected

| System | Why safe |
|--------|----------|
| Hub rotor (generating rotor) | Uses `sys.rotor.radius` from BEM, measured from shaft axis |
| Ring geometry (radii, spacing) | Independent of blade offsets |
| TRPT structural model (ring FEA) | Model correct; input forces were wrong, not the model |
| Tether dynamics, rope forces | Independent of blade offsets |
| Non-expansion-rotor simulations | Any sim without expansion rotors |

## Audit phases

### Phase 0 — Gate 1 re-run (COMPLETE ✅)
### Phase 1 — Impact quantification (COMPLETE ✅ — see 0006-phase1-delta-analysis.md)
### Phase 2 — Campaign re-evaluation (PENDING)
### Phase 3 — Document correction (PARTIAL)
### Phase 4 — Preventative measures (PENDING)

1. **V10 campaign**: was the "best" design an artefact of wrong geometry?
   - Re-evaluate top-N elite designs with corrected expansion rotor forces
   - Does the ranking change? Does a different design win?
2. **V6.x campaigns**: same audit, lower priority (superseded by V10)
3. **Blade scaling sweep** (λ = 0.54, 0.69, 0.79): re-run with corrected geometry

### Phase 3 — Document correction

1. **Technical report** (`docs/outreach/technical-report.md`):
   - Strip all ⟨RB⟩ markers
   - Replace with corrected Gate 1 numbers
   - Add errata note documenting the geometry defect and correction
2. **AWEC Porto materials**: audit claims, issue corrigendum if needed
3. **Community briefs**: update with corrected numbers
4. **DECISIONS.md**: add 2026-07-05 entry documenting the defect

### Phase 4 — Preventative measures

1. **Add geometry assertion test**: build system, verify `blade_hub_radius < 0`
   (negative = inboard) and `blade_tip_radius > 0` (positive = outboard)
2. **Add visual regression**: dashboard screenshot test showing blades crossing the ring
3. **Docstring enforcement**: every `ExpansionRotorParams` construction must cite the
   70/30 split
4. **CAD reference**: link to canonical CAD model showing blade attachment geometry

## Files changed (13 files, all instances of `0.25 * r_rotor`)

### Source (critical)
- `src/objective_v6.jl:95-98` — blade_tip_radius / blade_hub_radius computation
- `src/objective_v10.jl:195-196` — blade_tip / blade_hub computation

### Scripts
- `scripts/run_expansion_sweep.jl:77-78`
- `scripts/validate_v62_dynamic.jl:48-49`
- `scripts/test_campaign_builds.jl:42`
- `scripts/calibrate_kmppt_v62.jl:37-38`
- `scripts/interactive_dashboard.jl:374-375,452-453,483-484`

### Docs & visualisation
- `src/expansion_rotor.jl` — docstring + struct comments
- `src/expansion_stack.jl` — docstring
- `src/visualization.jl:361,377,658` — blade drawing + HUD span label
- `handovers/handover-2026-06-14.md` — hub radius description
- `CHANGELOG.md` — geometry description

## Decision log

- **2026-07-05**: Defect identified. Cause: BEM hub-root-cutout convention (25% of tip,
  measured from shaft axis) mistakenly adopted as a ring offset. In BEM, hub_radius
  is the distance from shaft to blade root. In TRPT, the blade attaches AT the ring,
  so ~30% sits inboard (toward shaft) and ~70% outboard. The coordinate systems differ.
- **2026-07-05**: Fix applied to all 13 files. Gate 1 re-run initiated.
- **2026-07-05**: All Gate 1 results prior to this fix are superseded. Old CSVs
  retained as tier-X reference.
