# Dynamic Inflow Induction Model & Gust Load Comparison — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Quantify how Leuthold (2019) dynamic inflow induction lag amplifies blade loads during IEC coherent gusts, producing a comparison report that either confirms the effect is negligible or captures a citeable amplification factor for the paper.

**Architecture:** First-order dynamic inflow filter applied as a wind-function wrapper — no ODE state-vector changes needed for Phase 1. The wake time constant τ is derived from Leuthold's ĊT coefficient (c₄ ≈ −0.73) mapped through the first-order Taylor equivalence. Comparison runs the identical gust scenario twice (with/without induction lag) and diffs the per-ring force envelopes, blade apparent wind, and structural FoS.

**Tech Stack:** Julia (KTD.jl ODE), Python (matplotlib report), existing `calibrate_dlf.jl` gust wind function, Leuthold et al. 2019 J. Phys.: Conf. Ser. 1256 012009.

---

## Physics Derivation

### Leuthold engineering model

Equation (15) from Leuthold et al. (2019):

```
ã = a₀ + ḟ₀·c₁ + %̇₀·c₂ + %̇₀·ḟ₀·c₃ + ĊT₀·c₄ + ĊT₀·ḟ₀·c₅ + ĊT₀·%̇₀·c₆ + ĊT₀·%̇₀·ḟ₀·c₇
```

For TRPT: no reel-out (ḟ₀ ≈ 0), fixed ring radius (%̇₀ ≈ 0). Dominant dynamic term: **ĊT₀ · c₄**.

Coefficient from Table 1 (M = 100, θ = 1, CT₀ = 8/9, %₀ = 6, f₀ = 1/3):
- **c₄ ≈ −0.73** (negative sign → when CT rises, induction factor *drops* → rotor sees *more* wind)

### First-order dynamic inflow equivalence

Standard dynamic inflow: τ · da/dt + a = a_steady, with a_steady = (1 − √(1−CT))/2.

For slowly varying a_steady: a ≈ a_steady − τ · da_steady/dt = a_steady − τ · (da_steady/dCT) · dCT/dt

da_steady/dCT = 1 / (4√(1−CT))

At CT = 8/9: da_steady/dCT = 1/(4·1/3) = 0.75

Equating to Leuthold: −τ · 0.75 = c₄ · τ_ref → τ = −c₄ · τ_ref / 0.75 ≈ 0.73 · τ_ref / 0.75 ≈ 0.97 · τ_ref

Wake convection timescale (Øye 1990): τ_ref ≈ R_rotor / (2 · v_wind)

**For V10 tight (R_rotor ≈ 5 m, v_rated = 11 m/s): τ ≈ 5 / (2 × 11) × 0.97 ≈ 0.22 s**

### Physical meaning

During a 5-second gust ramp (11→25 m/s), the induction lags behind by ~0.2 s. For the first ~0.2 s of the ramp, the rotor sees wind speed closer to the instantaneous gust value than to the BEM-corrected steady-state value. This amplifies blade lift (∝ v_app²) and consequently ring compression and tether tension.

---

## Task Breakdown

### Task 1: Create `scripts/gust_induction_comparison.jl` — Julia comparison runner

**Objective:** Run the IEC coherent gust scenario twice (baseline + induction-corrected) and save both trajectory CSVs.

**Files:**
- Create: `scripts/gust_induction_comparison.jl`
- Create: `scripts/results/gust_induction/` (output directory)

**Implementation notes:**

The induction correction is a wind-function wrapper:

```julia
# First-order dynamic inflow filter
mutable struct InductionState
    a_lagged::Float64  # current lagged induction factor
    τ::Float64          # wake time constant (s)
    R_char::Float64     # characteristic rotor radius (m)
end

function induction_corrected_wind!(state::InductionState, v_wind::Float64, dt::Float64)
    # Steady-state BEM induction: a₀ = (1 − √(1−CT))/2
    # Use representative CT for the 10 kW canonical system (~0.8 at rated TSR)
    CT_rep = 0.8
    a_steady = (1.0 - sqrt(1.0 - CT_rep)) / 2.0  # ≈ 0.276
    
    # Update τ based on current wind speed
    state.τ = state.R_char / (2.0 * max(v_wind, 1.0))
    
    # First-order Euler integration of da/dt = (a_steady − a) / τ
    if state.τ > 0.0
        state.a_lagged += (a_steady - state.a_lagged) * dt / state.τ
    else
        state.a_lagged = a_steady
    end
    
    # Effective wind speed at rotor disc
    return v_wind * (1.0 - state.a_lagged)
end
```

The script:
1. Loads KTD and sets up the canonical 10 kW system
2. Defines the IEC gust wind function (11→25 m/s, 1−cos ramp over 3 s, from calibrate_dlf.jl)
3. Runs baseline: settle → gust → log per-ring forces
4. Runs corrected: same, but wraps wind function with induction filter
5. Saves `gust_baseline.csv` and `gust_corrected.csv` with columns:
   `t, v_wind, v_eff, a_lagged, ring_id, radius, N_comp, P_crit, fos, F_inward_per_vertex, omega_shaft`

**Key design decisions:**
- Use representative CT = 0.8 (constant) rather than computing instantaneous CT from thrust. This is valid because CT varies slowly compared to τ (CT changes ~20% over 5 s; τ is 0.2 s).
- R_char = 5.0 m (matching the 10 kW canonical rotor radius in calibrate_dlf.jl)
- DT must match the ODE timestep (4e-5 s) for the induction filter

**Verification:** Script runs to completion, produces two CSVs with >100 rows each.

---

### Task 2: Create `scripts/analyze_gust_induction.py` — Python comparison report

**Objective:** Load the two CSVs, compute load amplification metrics, generate figures and a markdown report.

**Files:**
- Create: `scripts/analyze_gust_induction.py`

**Analysis sections:**

1. **Induction factor time series** — plot a_lagged vs a_steady across the gust ramp. Show the lag quantitatively (how many seconds behind, what the peak difference is).

2. **Effective wind speed comparison** — v_wind (nominal) vs v_eff (induction-corrected). Shade the difference region. The key metric: peak Δv during the gust ramp.

3. **Per-ring force amplification** — for each ring, compute F_inward_per_vertex peak ratio: corrected / baseline. Table and bar chart.

4. **FoS impact** — minimum FoS per ring, baseline vs corrected. Identify any ring that crosses FoS < 1.0 due to induction lag.

5. **Quantitative summary table:**

| Metric | Baseline | Corrected | Δ | Δ% |
|--------|----------|-----------|---|-----|
| Peak v_eff (m/s) | — | — | — | — |
| Peak a_lagged | — | — | — | — |
| Induction lag time (s) | — | — | — | — |
| Max ring F_inward (N) | — | — | — | — |
| Min FoS | — | — | — | — |
| Peak shaft ω (rad/s) | — | — | — | — |

6. **Scientific figure:** Two-panel dark-themed figure:
   - Left: v_wind, v_eff, and a_lagged vs time during the gust
   - Right: F_inward per ring, baseline vs corrected, at the gust peak (t = 4.5 s)

**Report path:** `scripts/results/gust_induction/gust_induction_report.md`

---

### Task 3: Run the comparison and verify

**Objective:** Execute the comparison pipeline end-to-end.

**Step 1: Run Julia script**

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
julia --project=. --threads=auto scripts/gust_induction_comparison.jl
```

Expected: ~2-5 minutes, two CSVs written.

**Step 2: Run Python analysis**

```bash
python3 scripts/analyze_gust_induction.py
```

Expected: report + figures generated.

**Step 3: Verify output quality**

Check:
- [ ] Report contains all 5 analysis sections
- [ ] Figures are dark-themed, publication-quality
- [ ] No NaN or inf in any metric
- [ ] The induction lag time is physically reasonable (~0.2-0.5 s, not 0 or >2 s)

**Step 4: Run full test suite**

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji
julia --project=. --threads=auto test/runtests.jl
```

Expected: 917/917. The new script is not in the test suite; this confirms no regressions.

---

### Task 4: Add DECISIONS.md entry

**Objective:** Document the dynamic inflow model choice and the comparison results.

**Content:** New entry summarizing:
- Model: first-order dynamic inflow with τ ≈ R/(2·v_wind), calibrated from Leuthold c₄
- Result: X% amplification of peak gust loads (to be filled after running)
- Status: Phase 1 — wind-function wrapper (research tool). Phase 2 deferred — ODE state-variable for fully coupled dynamics.

---

## Risks & Tradeoffs

| Risk | Mitigation |
|------|-----------|
| CT_rep = 0.8 is wrong for the 10 kW system | Verify from AeroDyn tables; the 10 kW rotor at TSR ~4 has CT ≈ 0.75-0.85 |
| Induction effect is negligible (<2%) | Still valuable — confirms BEM is sufficient for gust loading and closes this research question |
| DT = 4e-5 s is too coarse for the induction filter | τ = 0.22 s, DT = 4e-5 s → ~5,500 steps per time constant → fine |
| Expansion blades not present in 10 kW canonical config | This is intentional — Phase 1 validates the method on the simpler system. Phase 2 applies to V10 expansion stack. |
| Wind-function wrapper doesn't capture two-way coupling | Accepted for Phase 1. The perturbation is small (<5% v_eff change over <1 s) so trajectory deviation is minimal. Phase 2 adds full ODE coupling. |

## Open Questions

1. Should the report use the V10 tight winner (4 rotors, bank=25°) instead of the 10 kW canonical? More relevant to the AWEC paper but requires the full expansion rotor stack in the ODE.
2. Should we sweep τ (0.5×, 1×, 2× nominal) to bracket uncertainty in the c₄ calibration?
3. Should the Python report generate LaTeX-ready tables for direct inclusion in the paper?
