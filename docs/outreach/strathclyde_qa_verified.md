# Answers to Hong & Amjad's questions — code-verified 2026-07-17

> **⚠ PARTIALLY SUPERSEDED by commit `7d43455` (2026-07-17 12:13)** *(banner
> added 2026-07-18, doc-staleness audit)*. This doc was written the same
> morning but **before** the builder x-vector fix landed: Q5 describes the
> pre-fix scrambled builder as current, and the `builders_util.jl` line
> references throughout have drifted. Re-verified 2026-07-18: the physics,
> control, and FoS answers (Q1–Q4, Q6) still check TRUE against current code;
> the builder now loads `best_vector.csv` in v4 order (not `best_design.json`).
> Q5 remains accurate only as historical provenance of the pre-fix shared data.

Every answer below was checked against the current source. File/line references included.

## Q1 — Definition of λ (blade scale). Unit (m)?

λ is **dimensionless** — a multiplier on the blade *linear* dimensions relative to the V10 50 kW reference design, not a length in metres.

In `src/builders_util.jl` (lines 75–81), `blade_scale` multiplies each expansion rotor's `blade_tip_radius`, `blade_hub_radius`, and `blade_chord`, and blade mass is recomputed via `expansion_blade_mass(tip·λ, λ)`. The hub rotor's aero disk radius is also scaled: `5.0·λ` m (line 89). Ring radii, tether, and all other geometry are **fixed** ("blade-only scaling" — see `scripts/verify_k.jl` lines 50–52).

Consequences: blade planform area ∝ λ² (span × chord both scale), which is why k_mppt is scaled ∝ λ² across blade sizes. λ = 0.85 means blades at 85% of reference linear size (72% of reference area).

Reference blade dimensions come from `scripts/results/v10_campaign_50kw/best_design.json` via `design_from_vector_v10` (12-line pentagon→dodecagon, r_hub = 2.889 m, r_bottom = 2.0 m).

⚠️ **Symbol collision to flag in the reply:** the repo also uses λ for tip-speed ratio in a few scripts (`equilibrium_reconciliation.jl` line 100: `λ = ω·R/V`). Hong/Amjad, as wind-energy people, will read λ as TSR by default. Worth stating explicitly "λ here is blade geometric scale, not tip-speed ratio."

## Q2 — FoS definition and relation to generator k

FoS **is** the standard engineering definition: failure load / applied load, per structural member.

Implementation (`src/ring_element_analysis.jl` + `src/structural_safety.jl`):
- Each ring is modelled as a closed polygon frame of straight CFRP tube segments with fixed-fixed knuckle joints (effective length K = 0.5), NOT a continuous hoop (hoop Euler over-predicts capacity 5–10× at TRPT geometry — `structural_safety.jl` lines 4–7).
- Per-vertex tether forces are extracted from the ODE state and applied to a 6n×6n stiffness system; each beam gets axial force N, in-plane and out-of-plane bending moments.
- Combined beam-column utilisation: `util = N/N_crit + √(M_ip² + M_oop²)/M_el` (`ring_element_analysis.jl` line 291), where N_crit is the fixed-fixed Euler column buckling load.
- **FoS = 1/util** (`structural_safety.jl` line 89). Reported FoS = minimum over all beams of all *airborne* rings (ground ring excluded).

Relation to k: **none by definition — only through the load path.** k sets generator reaction torque τ_gen = k·ω² (`src/ring_forces.jl`, `get_generator_torque`). That torque is transmitted down the TRPT by twisting the tether lines into a helix; the tension's inward components at each ring vertex put the polygon segments into compression. Higher k → more torque at a given ω → more ring compression → lower FoS. So k and FoS are independent quantities linked only by the torque→tension→compression chain. Design target FOS_DESIGN = 3.0.

## Q3 — "k2" means k = 2?

Yes. k2 ≡ k_mppt = 2.0 in the MPPT torque law τ_gen = k_mppt·ω² (ω in rad/s, τ in N·m, so k has units N·m·s²). Set via `sys.k_mppt_ref[]`. Sweep values were k ∈ {2, 4, 6, 8, 10, 14} (`scripts/kickstart_sweep.jl` line 17).

## Q4 — The "30-second" spin: launching or transient?

It is a **launch/transient phase before equilibrium, with the generator fully unloaded (k = 0) — MPPT is OFF during it**, so "30-second MPPT" is a misnomer; it's a 30 s no-load spin-up.

Exact sequence as implemented (`scripts/kickstart_sweep.jl`, `retest_085_k2.jl`):
1. Settle to static equilibrium (positions only, no rotation).
2. Impulsive kick: all rings set to ω = 30 rad/s (≈287 rpm) with matching orbital velocities.
3. 30 s simulated with k_mppt = 0 (free-wheel) — the rotor sheds the excess and finds its aerodynamic no-load speed.
4. Generator engaged at target k; 30–60 s of MPPT; P, ω, FoS recorded at the final step.

In hardware this corresponds to a brief motoring phase from the ground station. The point: the high-RPM equilibria (300–480 rpm) are unreachable from rest — the standard settle scan sweeps ω downward from ~90 rpm and never sees them.

## Q5 — What does r mean in "tight ring"?

⚠️ **DO NOT ANSWER THIS YET.** r is *intended* to be `r_bottom_scale` (bottom-ring radius multiplier, reference r_bottom = 2.000 m; "tight" = the V10 tight-bounds DE campaign). But code verification on 2026-07-17 shows the as-built system does not match this intent at all — see "Scrambled-x decode" below. As-built, r never scales any ring radius; r≠1.0 flips the builder branch instead.

### Scrambled-x decode (verified 2026-07-17)

`_build_v10_tight` (`src/builders_util.jl:50–56`) packs x in JSON field order; `design_from_vector_v10` → `design_from_vector_v4` (`src/ring_spacing.jl:402–428`) decodes v4 layout:

| slot | builders_util packs | v4 decodes as | as-built value |
|---|---|---|---|
| x[1] | r_hub 2.889 | Do_top | 2.889 m (overwritten to 0.06 for FEA, builders_util:109) |
| x[2] | r_bottom·r_scale² | t_over_D | 2.0·r_scale² (overwritten to 0.01, builders_util:110) |
| x[3] | Do_top 0.06 | beam_aspect | 0.06 |
| x[4] | t_over_D 0.01 | Do_scale_exp | 0.01 |
| x[5] | target_Lr 2.988 | r_hub | **2.988 m** |
| x[6] | n_lines 12.0 | r_bottom | clamp(12→5.0), min(·, r_hub) = **2.988 m → NO taper** |
| x[7] | density −0.110 | target_Lr | clamp(−0.11→0.1) → dense stack → **22 rings** |
| x[8] | 0.519 | n_lines | round(0.519)=1 → clamp(3,12) = **3 → TRIANGLE frames** |
| x[9] | 0.10 | density_profile | 0.10 |
| x[10] | 32.0 | rotor mask proxy | decode_rotor_mask(32.0) |
| x[11] | 35.0 | bank_top | clamp → 25° |
| x[12] | n_active 4.0 | bank_bottom | 4° |
| x[13] | 1.0 | λ_top | 1.0 |
| x[14] | aspect 0.88 | λ_bottom | 0.88 |

**Consequences:**
- `best_design.json`'s 12-gon / 10-ring / tapered 2.889→2.0 m geometry describes the DE campaign winner ONLY. Every result shared with Strathclyde (kickstart, catalog, wind_sweep, retest_085_k2) ran a **3-line triangle frame, 22 rings, untapered ~2.99 m radius cylinder, bank 25°(top)→4°(bottom), λ gradient 1.0→0.88** before the `blade_scale` kwarg is applied.
- The r_bottom_scale double-application (builders_util:51 and :57) lands in the t_over_D slot, which is then overwritten for the FEA — so as-built it is nearly inert.
- What r≠1.0 *actually* does: switches the builder branch (builders_util:101). r=1.30 → `build_kite_turbine_system_v5(pc, target_Lr≈0.1, r_bottom≈2.988)` (ring_spacing_v4 stack); r=1.00 → `build_kite_turbine_system(pc)` which derives r_bot from `trpt_rL_ratio` (initialization.jl:290). Two different ring stacks — **this is the code-level root cause of the catalog (r=1.30) vs wind_sweep (r=1.00) figure discrepancy.**

**Where the stray numbers go (verified):** the JSON's `n_lines: 12` lands in the r_bottom slot (metres), is clamped by `max_ground_radius=5.0` (a kwarg, not a pentagon), then flattened by `min(·, r_hub)` to 2.988 m. It never sets a polygon count. The only side/line/blade count as-built is 3 (`clamp(round(0.519), 3, 12)`), and `n_lines` feeds TRPT lines, frame sides, AND blades per rotor — hence the consistent triangles + 3 blades in the dashboard. The x vector is a raw `Float64[]` at packing time; the Int-typed struct only exists post-decode, so no type check could catch the scramble.

**Duplicate scrambled builder:** the dashboard has its own copy of `build_v10_tight_no_lowest` with identical wrong packing (`scripts/interactive_dashboard.jl:287–300`). Dashboard "V10 Tight" menu entries = same triangle/22-ring system as the headless scripts. Only "V10"/"V10 Island 51" (`build_from_campaign_v10`, lines 430/433, decoding best_vector.csv) build the true 12-gon. Any fix must patch BOTH copies. Correct v4 order: `[Do_top, t_over_D, beam_aspect, Do_scale_exp, r_hub, r_bottom, target_Lr, n_lines, density_profile, mask, bank_top, bank_bottom, λ_top, λ_bottom]`.

**Decision needed before replying to Hong:** either (a) describe the as-built triangle geometry honestly and re-label the charts, or (b) fix the x-vector packing to v4 order, re-run the kickstart/wind sweeps, and answer from the corrected system. Amjad is summarising parameters from the logs — the builder's *printed* line (`n_lines=3 rings=22`) is the ground truth for what was simulated.

## Q6 — Ring compression: axial or radial?

Neither along the turbine/tether axis nor a change of ring radius per se: it is **in-plane compression of the ring's own members** — the straight polygon segments between tether attachment vertices carry compressive axial force along their member axes (circumferential/hoop direction).

Load source: TRPT torque transfer twists the tether lines into a helix; each line's tension then has a radially-inward (and circumferentially opposing) component at the vertex it grips. Those inward vertex loads squeeze the polygon, putting the segments in compression. Failure mode is Euler column buckling of an individual segment (`structural_safety.jl` lines 2–7). So if forced into Hong's binary: the *loading* is in the ring-radius direction; the *compression and buckling* are in the ring members, in the plane of the ring — not axial along the system axis.

## Additional flags before replying

1. **λ vs TSR symbol clash** (Q1) — define explicitly.
2. **Scrambled-x decode confirmed** (Q5 table) — all shared results are triangle/22-ring/untapered, NOT the 12-gon JSON design. Decide fix-and-rerun vs describe-as-built before answering any geometry question.
3. **r_bottom_scale is inert as-built** — its real effect is the builder-branch switch, root cause of catalog vs wind_sweep discrepancy.
4. Kick is to 287 rpm, not 140 rpm — the email's "spin to 140+ rpm" describes where the rotor is after the no-load phase, which is fine, but Amjad may notice the initial condition in any shared traces.
5. Q1's λ answer survives the scramble (blade_scale kwarg is applied post-build to blade dims), but the *reference* blade dims belong to the scrambled triangle design, with a built-in λ gradient 1.0→0.88 top→bottom underneath the kwarg.
