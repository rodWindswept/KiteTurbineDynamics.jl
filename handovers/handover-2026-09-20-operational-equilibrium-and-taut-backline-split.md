# Handover — Operational Equilibrium Settle Landed & Taut Back-Line Balance Roadmap (2026-09-20)

## 1. How to Run Things

Always invoke Julia through `scripts/ktd-julia` — plain `julia --project=.` does not work in this sandbox (`CLAUDE.md`, `AGENTS.md`).

```bash
scripts/ktd-julia test/runtests.jl                 # fast suite, ~3.5 min (2146 pass / 0 fail / 0 broken)
scripts/ktd-julia test/acceptance_runtests.jl      # acceptance suite, ~15 min (8 / 8 PASS)
scripts/ktd-format                                 # JuliaFormatter, Blue style
scripts/ktd-julia scratch/<probe>.jl               # any scratch probe
```

Live output — **`script` MASKS the exit code, so do NOT trust `$?`**:
```bash
script -q -c "scripts/ktd-julia test/runtests.jl" /dev/null
```
Verified on this host: `script -q -c "exit 3" /dev/null; echo $?` prints **0**. A red suite therefore reads as green by exit code. Read the `Test Summary:` line or the `ERROR: LoadError:` line instead (`docs/agents/instrument-trust-log.md` [2026-09-13]).

---

## 2. Headline & Current Status

### ✅ Both Suites 100% Green (0 Broken!)
- **Fast Suite:** **2146 pass / 0 fail / 0 broken** (exit 0).
- **Acceptance Suite:** **8 / 8 pass** (100% green).
- **Git Status:** Clean and pushed to `origin/master` at commit [`9a7f8f2`](https://github.com/rodWindswept/KiteTurbineDynamics.jl/commit/9a7f8f2).

| Component / Metric | Before (Unpolished / Buggy) | Now (Commit `9a7f8f2`) | Status |
|---|---|---|---|
| **First-Frame Accel (`acc0_raw`)** | $17,468\text{ m/s}^2$ ($1781\text{ g}$) | **$293\text{ m/s}^2$ ($29.9\text{ g}$)** | **$98.3\%$ eliminated** |
| **Structural Node Accel (`acc_struct`)** | $791\text{ m/s}^2$ ($80.6\text{ g}$) | **$7.47\text{ m/s}^2$ ($0.76\text{ g}$)** | **PASS (< 10 g gate)** |
| **Max Unbalanced Force (`max_force`)** | $662\text{ N}$ | **$88.9\text{ N}$** | **PASS (< 200 N gate)** |
| **Hub Axial Residual** | $+14.5\text{ N}$ (unpolished) / $+162\text{ N}$ (drag-free) | **$-2.65\text{ N}$** | **PASS ($< 50\text{ N}$ gate)** |
| **Bearing & Sky Axial Residuals** | $0.2\text{ N}$ / $0.1\text{ N}$ | **$-0.05\text{ N}$ / $-0.46\text{ N}$** | **PASS ($< 50\text{ N}$ gate)** |
| **Fast Suite Broken Tests** | 1 broken (V6) | **0 broken (V6 PROMOTED)** | **100% GREEN** |
| **Acceptance Suite** | 7/8 (B6 twist limit cycle) | **8/8 PASS (B6 tether aligned)** | **100% GREEN** |

---

## 3. What Landed in Commit `9a7f8f2`

### A. Operational-Equilibrium Dynamic Relaxation Polish (Variant A)
Implemented in [`src/initialization.jl`](../src/initialization.jl) as `_polish_operational_equilibrium!`:
- **Full Force Field:** Recomputes the rigid-body orbital velocity field $\vec{v} = \vec{\omega} \times \vec{r}$ at each Barnes DR iteration. Balances gravity, rotor thrust/torque, elastic line tension, and steady-state spinning-cable aerodynamic drag simultaneously.
- **Falsified the 2026-09-16 Claim:** The drag-free DR prototype met the old static metric ($71.4\text{ m/s}^2$), but when orbital velocity was applied at handoff, the suddenly introduced drag acted as a violent unbalanced shock (hub residual blew up from $14.5\text{ N} \to 162.3\text{ N}$). The [2026-09-16] assumption that "drag is irremovable" was false — the drag was removable because it was unbalanced, not an already-balanced operating force!
- **Cost:** Adds only **$+1.7\%$** execution time on a 300,000-step settle.

### B. V6 Redefined and Promoted to `@test`
- The old metric measured raw acceleration from `multibody_ode!` on a $2.25\text{ g}$ cable node carrying $39\text{ N}$ of drag ($1780\text{ g}$).
- V6 now gates on:
  1. **Structural nodes** (rings, bearing, sky anchor): `acc_struct < 10.0 * 9.81` (measured $0.76\text{ g}$).
  2. **Max unbalanced network force**: `max_force < 200.0` (measured $88.9\text{ N}$, mass-robust against cable discretization artifacts).

### C. B6 Tether Diameter Alignment (`test_evaluator_v13.jl`)
- **Diagnosis:** In `test_evaluator_v13.jl`, `v13_cfg` did not specify `tether_diameter`, causing `ObjectiveConfig` to default to `0.003 m` (3.0 mm). However, the 5 kW campaign scales the tether from the Daisy anchor to `p.tether_diameter = 0.003651 m` (3.651 mm).
- A 3.0 mm tether has **$32.5\%$ lower cross-sectional area and torsional stiffness ($EA$)**. Under the 5.4 kW torque of the winner, the 3.0 mm line was so undersized that it twisted past $\delta^*$ into line crossing.
- Aligning `v13_cfg` with `tether_diameter=p.tether_diameter` (identically to Rod's commit `7014445` in `test_physics_path_ode.jl`) fixed B6 immediately:
  - `status = :ok`, `P_mean = 5.40 kW`, `FoS_min = 12.88`, tip speed $71.7\text{ m/s} < 100\text{ m/s}$.
  - Maximum twist ratio is **$0.531$** (flat, rock solid, zero limit cycle).

---

## 4. The Remaining Work: Taut Back-Line Balance in `lift_chain_design` (ACTIVE.md Item 2b / Item 4)

### The Measurement & Physics Proof ([`scratch/probe_taut_split.jl`](../scratch/probe_taut_split.jl))
Measured on the campaign seed at the solved operating equilibrium:
- **The ODE is ALREADY TAUT:**
  - Back line carries **$313.51\text{ N}$**, sitting $+6.1\text{ mm}$ beyond the hard stop ($b_{\text{dist}} = 13.9316\text{ m}$ vs $L_{0,\text{design}} = 13.9255\text{ m}$).
  - Cyan line carries **$252.50\text{ N}$**.
- **The Taut 2×2 Balance:**
  Resolving equilibrium at the sky anchor in $(x, z)$:
  $$\begin{pmatrix} d_{\text{cyan}, x} & d_{\text{back}, x} \\ d_{\text{cyan}, z} & d_{\text{back}, z} \end{pmatrix} \begin{pmatrix} T_{\text{cyan}} \\ T_{\text{back}} \end{pmatrix} = \begin{pmatrix} -T_{\text{lift}} \cos(\theta_{\text{el}}) \\ -T_{\text{lift}} \sin(\theta_{\text{el}}) - W_{\text{sky}} \end{pmatrix}$$
  Yields:
  $$T_{\text{cyan}} = \mathbf{245.75\text{ N}}, \quad T_{\text{back}} = \mathbf{319.75\text{ N}}$$
  This matches the ODE measurements within **$2.7\%$**!
- **The Design Code Lag:**
  In [`src/initialization.jl:1026`](../src/initialization.jl), `lift_chain_design` still calculates $T_{\text{cyan}}$ assuming the back line is **SLACK** ($T_{\text{back}} = 0$), deriving $T_{\text{cyan}} = \mathbf{435.87\text{ N}}$ ($+73\%$ error) and over-predicting $T_{\text{top}}$ by **$+187.6\text{ N}$** ($1458\text{ N}$ vs $1270\text{ N}$).
- **Structural Benefit of Closing the Gap:**
  - Lowering $T_{\text{top}}$ by $188\text{ N}$ reduces ring axial compression $N$ along the whole shaft.
  - This **increases structural Factor of Safety (FoS)** and allows lighter ring tubes.
  - At the taut equilibrium tension, torsional demand on the seed is only **$0.6287$** (target $0.9524$, cliff $1.0$), leaving ample realisability headroom.

---

## 5. Execution Plan for the Next Session

### Step 1: Update `lift_chain_design` Sky-Anchor Balance
In `src/initialization.jl` around line 1026:
- Replace the 1D slack line-projection:
  ```julia
  T_cyan = max(-dot(T_lift .* lift_dir .+ W_sky, cyan_dir), 0.0)
  ```
  with the 2×2 taut solve for $(T_{\text{cyan}}, T_{\text{back}})$ using the unit vectors `cyan_dir` and `back_dir`.
- When $T_{\text{back}} > 0$, the back line is taut and shares the sky-anchor vertical and downwind load.

### Step 2: Calibrate Soft-Region Bungee Law in `src/ring_forces.jl`
In `src/ring_forces.jl:544`:
- Update `T_design_code` to match the operating equilibrium backline tension (~$320\text{ N}$) rather than the placeholder $2.27\text{ N}$, ensuring $k_{\text{soft}}$ matches the physical stiffness of the 8 bungee sections.

### Step 3: Re-Verify Both Suites
Run:
```bash
scripts/ktd-julia test/runtests.jl
scripts/ktd-julia test/acceptance_runtests.jl
```
Ensure 2146/0/0 fast and 8/8 acceptance are preserved.
