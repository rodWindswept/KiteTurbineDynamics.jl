# Handover — 2026-06-27 — Soft-Ramp k_mppt Controller

**Session:** Hermes + Rod, ~2.5h
**Branch:** master (pushed)
**Commit:** `05ed8be`

## What we built

A closed-loop soft-ramp k_mppt controller for the TRPT kite turbine, implemented in
three phases (A–C). Phase D (data recording for paper) is scripted but not yet executed.

### Phase A — k_mppt made mutable

`KiteTurbineSystem` now carries `k_mppt_ref::Ref{Float64}`. The ODE's
`get_generator_torque()` reads `sys.k_mppt_ref[]` — no `SystemParams` reconstruction
needed. The dashboard slider and pitch-depower loop sync the ref automatically.
Zero measurable ODE overhead.

### Phase B — State machine

New module `src/soft_ramp_controller.jl`:

```
IDLE ──→ RAMPING ──→ HOLDING
  ↑                     │
  └──(sustained lull)───┘
```

- **IDLE:** waits for ω_hub ≥ ~5 rpm for 3s
- **RAMPING:** Δk = Kp × (P_target − P_actual) × dt, clamped [k_min, k_max]
- **HOLDING:** power stable within ±5% for 3s → freeze

Dashboard has an "Auto-Ramp k_mppt" toggle (cyan when active) and a state indicator
label. Controller runs at ~50 Hz inside the simulation callback.

### Phase C — Structural constraint guards

Two safeguards added to `update_ramp!()`:

1. **FoS linear taper:** `ramp_rate *= clamp((FoS − 1.5)/(2.5 − 1.5), 0, 1)`
   - Full rate at FoS ≥ 2.5, zero at FoS ≤ 1.5
   - Prevents control discontinuity that would excite TRPT torsional modes

2. **Tulloch collapse margin freeze:**
   - `init_geometry!(ctrl, sys, p)` pre-computes per-segment δα* from ring geometry
   - `min_collapse_margin(u, sys, ctrl)` computes `min(δα*_i − |Δα_i|)` each frame
   - If any segment's margin < 5° → ramp frozen (struct_mult = 0)

Dashboard has FoS soft-limit slider (default 2.5) and hard-floor slider (default 1.5).

### Tulloch documentation

The non-monotonic τ(δα) curve is now documented at three connected locations:
- `src/ring_forces.jl` — where k_sec is computed live
- `src/soft_ramp_controller.jl` — where the margin constraint is applied
- `scripts/torsional_collapse_check.jl` — authoritative reference, cross-linked

## What's ready but not run

### Phase D — Data recording for paper

Two scripts ready:

**Recording** (`scripts/record_ramp_traces.jl`):
```bash
julia --project=. scripts/record_ramp_traces.jl
```
Produces 6 CSVs in `scripts/results/ramp_traces/`:
- `canonical_10kw_instant.csv` / `canonical_10kw_softramp.csv`
- `v10_tight_50kw_instant.csv` / `v10_tight_50kw_softramp.csv`
- `wind_ramp_instant.csv` / `wind_ramp_softramp.csv`

V10 Tight scenarios skip gracefully if campaign data unavailable (`best_design.json` not found).
Estimated runtime: ~60-90 minutes for all 6 scenarios.

**Plotting** (`scripts/plot_ramp_traces.py`):
```bash
python3 scripts/plot_ramp_traces.py
```
Generates 6 figures + summary table in `scripts/results/ramp_traces/figures/`:
1. k_mppt(t) + P_gen(t) — instant vs soft-ramp
2. FoS(t) with intervention bands (2.5/1.5)
3. Collapse margin(t) — distance to Tulloch cliff
4. Phase portrait: P_gen vs Δω
5. Wind ramp comparison
6. Summary table (LaTeX-able)

**Known issue:** The recording script uses `include("interactive_dashboard.jl")` to
borrow `build_v10_tight_no_lowest()`. This may trigger GLMakie dependency loading in
headless mode. If it fails, either:
- Wrap the V10 builder in a `try/catch` (already done — it skips gracefully)
- Extract the builder into a shared utility module
- Run with `--canonical-only` flag (add this to the script if needed)

## Key files

| File | Role |
|---|---|
| `src/types.jl:109` | `k_mppt_ref::Ref{Float64}` in KiteTurbineSystem |
| `src/ring_forces.jl:50,57,62,65,71` | `get_generator_torque()` reads ref |
| `src/initialization.jl:226` | Ref initialised from `p.k_mppt` |
| `src/soft_ramp_controller.jl` | **New** — RampController, state machine, FoS taper, Tulloch margin |
| `src/visualization.jl` | Dashboard toggle, state label, FoS sliders, sim-loop integration |
| `scripts/record_ramp_traces.jl` | **New** — headless trace recording |
| `scripts/plot_ramp_traces.py` | **New** — paper figure generation |
| `docs/plans/2026-06-27-soft-ramp-kmppt-v2.md` | Full implementation plan |
| `DECISIONS.md` §2026-06-27 | 7 design decisions recorded |

## Test status

`julia --project=. test/runtests.jl` → **917/917 pass** (last run: 5m38s)

## Next steps

1. Run `julia --project=. scripts/record_ramp_traces.jl` (overnight, ~90 min)
2. Run `python3 scripts/plot_ramp_traces.py` (seconds)
3. Review figures — tune Kp, FoS thresholds, or T_sim if needed
4. Write paper section "Dynamic MPPT Control of TRPT Kite Turbines"
5. (Future) PID autotuning via relay feedback if state machine insufficient
