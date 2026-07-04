## 2026-07-04: Settle k_mppt bug, five simulator-integrity findings, and blade-scaling energy balance

### Settle k_mppt bug (integrity #1)

**Context:** `settle_to_operational_state` (`initialization.jl:738,747`) used
`p.k_mppt` (fixed params, V10 Tight = 614.9) to find equilibrium ω/τ, while the
simulation reads `sys.k_mppt_ref[]` (mutable, gate override = 15.6).

| Variable | Value | Source |
|----------|-------|--------|
| `p.k_mppt` | 614.9 | `mass_scale(v5_10kw, 10→50)`: k ∝ P^2.5 → 11.0 × 55.9 |
| `k_mppt_ref` | 15.6 | Empirical gate value; set by test scripts |
| Ratio | 39× | V10 Tight DE geometry is far from geometric-scaling prediction |

The 39× gap meant every settle initialised at a very low ω where P_aero > 614.9·ω³,
then the simulation had to climb upstream to find the k_ref=15.6 equilibrium during
the sim. Short sims (≤10s) may not have converged fully.

**Fix:** Changed `:738` to `P_gen = sys.k_mppt_ref[] * w^3` and `:747` to
`τ_eq = sys.k_mppt_ref[] * ω_eq^2`.

**Gate retest:** P = 193.8 kW at ω = 221.2 rpm (was 166–172 kW at ~210 rpm).
+12–16% shift. All published V10 control-map and k-hunt numbers carry this asterisk
until re-run through the fixed settle.

### Integrity findings #2–5

1. **Gate drift:** Gate P shifted +16% with settle fix. The 2026-06-28
   static/dynamic k_mppt mismatch (3.3×) may be partially attributable to this
   bug. Published control maps are under re-verification.

2. **Hardcoded `rotor_radius = 5.0`:** Builder (`builders_util.jl:66`) overrides
   `params_v5_50kw().rotor_radius = 11.18` (mass-scaled from 10 kW) with a
   hardcoded 5.0. All V10 runs used a 78.5 m² hub disk unrelated to the DE
   design vector. If the DE campaign's objective function used a different
   hub radius, "V10 Tight winner" in reports may not be the design the optimizer
   selected.

3. **Builder–design pipeline mismatch:**
   - `p_base.k_mppt = 614.9` vs empirical K₀ = 15.6 for V10 Tight (39×).
   - `trpt_hub_radius = 2.988` at runtime ≠ `best_design.json.r_hub_m`.
   - The builder constructs a system that differs from the recorded DE winner in
     at least three independent parameters (rotor_radius, k_mppt, trpt_hub_radius).
     "V10 Tight" in reports and "V10 Tight" in the simulator are different
     machines.

4. **Silent catch in `capture_extended` (`sim_frame.jl:439`):** Any exception in
   `expansion_rotor_forces` was caught and silently zeroed per-rotor aero/ground
   power, making past dashboard per-rotor breakdowns unreliable. Fixed to
   `@warn` + `NaN` (zero is a plausible valid power value; NaN signals failure).

**Recommendation:** Write a `dump_design(sys, p)` diagnostic that prints every
geometry and control parameter of a built system and diffs it against the DE
campaign's own record of the winner. Until that diff is clean, the simulator
and the published V10 Tight are two different machines.

### Blade-only scaling energy balance

Post-design blade scaling (fixed ring geometry, r_mean-corrected k) with full
ODE simulation and static aero P(ω) sweep:

| | Gate (λ=1.0) | λ=0.54 |
|---|---|---|
| Expansion aero (static peak) | 253.2 kW @ 248 rpm | 73.5 kW @ 315 rpm |
| Static ratio | — | **0.290 = λ²** |
| Expansion aero (ODE op point) | 215.5 kW | 48.1 kW |
| Hub aero (ODE) | 6.0 kW | 3.9 kW |
| Σ Aero (ODE) | 221.5 kW | 52.0 kW |
| Generator (k·ω³) | 193.8 kW | 23.6 kW |
| Transmission loss | 27.8 kW (13%) | 28.4 kW (55%) |
| Shaft efficiency | 87% | 45% |
| Max segment twist | 11.6° | 11.0° |
| Min FoS | 2.53 | 8.8 |

**Key findings:**

1. **Static aero model obeys λ² at peak power** (0.290 vs λ² = 0.292). The
   constant-CL expansion rotor formulation follows blade-area scaling exactly at
   its optimal ω.

2. **Transmission loss is ~28 kW regardless of loading** — a near-constant
   overhead. Shaft efficiency collapses from 87% to 45% with blade shrinking.
   Suspects: `lin_damp=0.05` structural damping, numerical dissipation, or
   bearing-model terms. The overhead imposes a floor: you cannot right-size
   TRPT blades without also managing shaft loading.

3. **Max segment twist is near-identical** (11–12°) despite different loadings —
   the torque saturation mechanism is not twist-limited at these regimes.

4. **FoS margin is generous** (8.8 at λ=0.54) — structural headroom exists for
   larger blades.

5. **λ² prediction gap at the ODE operating point:** The ODE settles at 207 rpm
   (below the 315 rpm static optimum) because the generator load curve (k·ω³)
   crosses the static torque curve at a lower ω than the aero peak. This is a
   k-tuning consequence, not an aero or transmission limit.

**Status:** λ=0.79 blade-scale test in progress (predicted 50 kW ground
accounting for fixed losses). The counter-analysis defensible statement:
*"A blade-rescaled V10 Tight (λ=0.54) produced 48 kW expansion aero / 24 kW
ground at 11 m/s with FoS 8.8–12. Static aero follows λ² (73.5 kW peak vs
253 kW gate); the gap to ground power is a ~28 kW fixed transmission overhead
(87%→45% shaft efficiency with blade shrinking). λ≈0.79 projected for 50 kW
ground; untested. Blade-thrust and shaft torque capacity are coupled — TRPT
right-sizing must account for transmission overhead, a physics absent from
swept-area scaling models."*

### Files changed

- `src/initialization.jl:738,747` — settle now reads `sys.k_mppt_ref[]`
- `src/sim_frame.jl:439-442` — silent catch → `@warn` + NaN
- `scripts/builders_util.jl:63-71` — rotor_radius = 5.0 × blade_scale,
  trpt_hub unscaled, k ∝ λ² in params
- `DECISIONS.md` — 2026-07-04 entry with all findings
