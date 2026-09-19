# Handover — Acceptance 8/8 Restored & Dynamic Relaxation Static Solver (2026-09-19)

## 1. How to run things

Always invoke Julia through `scripts/ktd-julia` — plain `julia --project=.` does not work in this sandbox (`CLAUDE.md`, `AGENTS.md`).

```bash
scripts/ktd-julia test/runtests.jl                 # fast suite, ~3.2 min (2144 pass / 0 fail / 1 broken)
scripts/ktd-julia test/acceptance_runtests.jl      # acceptance suite, ~18 min, 8/8 PASS
scripts/ktd-format                                 # JuliaFormatter, Blue style
scripts/ktd-julia scratch/<probe>.jl               # any scratch probe
```

Live output with exit status:
```bash
script -q -c "scripts/ktd-julia test/runtests.jl" /dev/null
```

---

## 2. Headline

### ✅ Acceptance Suite: 8 of 8 GREEN (Unrebased)
The acceptance suite is fully green for the first time in weeks, resolving both `test_physics_path_ode.jl` (P1) and `test_settle_lowk_honest.jl` (A3) by fixing real physics defects:
- **Fast Suite:** **2144 pass / 0 fail / 1 broken** (exit 0).
- **Acceptance Suite:** **8 pass / 0 fail** (100% green).

### ✅ Dynamic Relaxation Static Solver Prototype (Target MET)
[`scratch/prototype_static_solver.jl`](../scratch/prototype_static_solver.jl) implements Barnes kinetic damping dynamic relaxation on the conservative force path:
- **Static `acc0`:** Dropped from **$284.5\text{ m/s}^2$ ($29.0\text{ g}$)** down to **$71.4\text{ m/s}^2$ ($7.27\text{ g}$)**, cleanly clearing the $10\text{ g}$ bar (`acc0 < 98.1 m/s²`).
- **Axial Force Residuals:** Hub residual dropped $88.7\text{ N} \to \mathbf{6.59\text{ N}}$, bearing to $0.17\text{ N}$, sky anchor to $0.10\text{ N}$.
- **Equilibrium Shape:** Displaced nodes up to $0.893\text{ m}$ into true catenary/bowed equilibrium while keeping $\omega$ and $\alpha$ bit-identical.

---

## 3. Key Commits Landed (This Sequence)

| Commit | Content |
|---|---|
| `7014445` | test: align P1's tether with campaign (`0.003651 m`); expose `sizing_fos_margin` keyword |
| `8471dd5` | fix: closed-form ring load model was 3.7× low (`HELIX_LOAD_FACTOR` 0.32 → 1.2 envelope, `MIN_RING_DO_M = 10 mm`); restores 8/8 |
| `8feeb23` | docs: record the ring load-model correction; acceptance 8/8 |
| `cfe67a9` | docs: ACTIVE — the bungee ELEMENT landed in `21cf73b`; only the load split remains |
| `a52cfd5` | fix: V6's `acc0` measured spinning cable drag (1780 g); corrected metric to static residual (29 g) |
| `208f43b` | probe: dynamic-relaxation static solver prototype reaches 7.27 g (target MET) |

---

## 4. The Two Critical Findings That Unblocked Physics

### Finding 1: The Ring Sizing Disconnect Was Load, Not Capacity
- Measurement on the failing seed showed $\text{cap ratio} = 1.000$ exact ($P_{\text{crit, sizing}} == P_{\text{crit, FEA}} = 374.6\text{ N}$).
- The entire defect was in the **load model**: the closed form fed $N_{\text{comp}} = 115.25\text{ N}$ flat across all cylinder rings, while the actual 3D multi-body ODE carries a large torque-helix reaction force accumulating near the fixed ground boundary ($427\text{ N}$ at ring 2, decaying to $241\text{ N}$ at ring 8).
- `HELIX_LOAD_FACTOR = 0.32` was a stale calibration from an earlier 8-ring seed. Restoring the codebase's legacy envelope `OPT_DESIGN_LOAD_FACTOR = 1.2` accurately enveloped the measured $1.186$ ratio at ring 2.
- Sizing for the honest $427\text{ N}$ load naturally grew the rings ($D_o \to 19\text{ mm}$ upper, $10\text{ mm}$ cylinder floor), yielding $FoS = 4.164$ in both 5 s and 20 s windows, with $+3.276\text{ kg}$ mass delta.

### Finding 2: V6 `acc0` Measured Cable Aerodynamic Drag
- In `test/test_settle_validity.jl:106`, `acc0 = maximum(norm(du[3N+1:6N]))` was evaluated directly on the rotating state.
- A $2.25\text{ g}$ discretized rope node spinning at $\omega \cdot r \approx 32\text{ m/s}$ experiences $\approx 39\text{ N}$ of normal aerodynamic cable drag in relative wind. That physical aerodynamic force produced $a = 39 / 0.00225 \approx 17,330\text{ m/s}^2 \approx 1,767\text{ g}$.
- This was an instrument artifact, not a handoff shock.
- In accordance with `ACTIVE.md:210`, zeroing translational velocities `u[(3N+1):6N] = 0` (while preserving $\omega$ for rotor thrust and torque) dropped `acc0` from $17,468 \to 284.5\text{ m/s}^2$ ($29.0\text{ g}$), unmasking the real structural imbalance: **$238\text{ N}$ on RingNode 11 ($0.836\text{ kg}$)**.

---

## 5. Next Unit of Work (Fresh Session Kickoff)

The next unit of work is cleanly isolated and ready to execute:

### Step 1: Wire the Barnes DR Solver into `src/initialization.jl`
Port the proven algorithm from [`scratch/prototype_static_solver.jl`](../scratch/prototype_static_solver.jl) into `src/initialization.jl`:
- Run it as the final polishing pass of `settle_to_operational_state`.
- Parameters: $\Delta t_{\text{dr}} = 2 \times 10^{-4}$, $m_f = \max(k \Delta t^2, m)$, kinetic energy reset on local maximum.
- Relax positions (3N) while holding $\omega$ and $\alpha$ pinned.

### Step 2: Promote V6 in `test/test_settle_validity.jl`
With the static solver active, `acc0` drops to $7.27\text{ g} < 10\text{ g}$.
Promote line 194 from `@test_broken` to `@test`:
```julia
@test acc0_static < 10.0 * 9.81   # < 10 g
```
This achieves **100% green with 0 broken** across the fast suite.

### Step 3: Close ACTIVE.md Item 2 (The Taut Load Split)
The bi-linear back-line element is already in `src/initialization.jl:79` (`back_line_tension`) from commit `21cf73b`.
With the true static equilibrium position of the sky anchor and shaft established by the static solver:
- Re-derive the taut load split in `design_axial_preload`.
- Close the self-consistent design tension $T_{\text{design}}$ iterate against the equilibrium geometry.

### Step 4: Re-Verify Both Suites
Run:
```bash
scripts/ktd-julia test/runtests.jl
scripts/ktd-julia test/acceptance_runtests.jl
```
Confirm all 50 fast tests and all 8 slow acceptance tests pass cleanly.
