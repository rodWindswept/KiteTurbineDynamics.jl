# tier-X-biased-geometry — DO NOT CITE

**Status: tier-X (biased). Superseded by the corrected CSVs one directory up.**

These three Gate 1 max-power summary CSVs were generated **before** the 70/30
blade-geometry fix (commit `13f304a`, 2026-07-05T21:07+0100). They contain the
blade-offset defect: `blade_hub_radius = 0.25·tip` placed the entire blade
annulus outboard of the ring, overstating the r_mean offset ~3.1×. Correct
geometry is a 70/30 split around the ring attachment (hub = −0.3·span).

| File | Run finished | Code state |
|------|--------------|------------|
| `gate1_v10_tight_maxpower_summary.csv` | 2026-07-05 14:58 | `d661dfc` (pre-fix) |
| `gate1_v10_reinforced_maxpower_summary.csv` | 2026-07-05 17:52 | `d661dfc` (pre-fix) |
| `gate1_blade_scaled_069_maxpower_summary.csv` | 2026-07-05 19:18 | `d661dfc` (pre-fix) |

**Why the stamped hash says `86ca0e5`:** `GIT_HASH` was a hardcoded constant in
`scripts/hunt_kmppt_bisect.jl` at run time. It has since been replaced with git
auto-detection (with `-dirty` flag). Line-1 stamps in each CSV were
retro-annotated with true `code_state` on 2026-07-06.

**Why these files are kept:** they are the "before" side of the PRD 0006 Phase 1
delta analysis (`docs/prd/0006-phase1-delta-analysis.md`), quantifying the bias
the defect introduced. They must not be used for any design verdict, published
claim, or campaign comparison.

Reference: `docs/prd/0006-blade-geometry-audit.md`,
`docs/prd/0006-phase1-verification-checklist.md`.
