# Fix headless_verify to run wind-driven ODE

> **Goal:** Replace the gravity-only settle in `headless_verify` with a full wind-driven simulation so it catches dynamically-dead designs (V9.0: 403 kW overshoot; V10: 0 kW stall) at campaign-validation time, not hours later in the dashboard.

**Architecture:** Modify `headless_verify` to run a 5-second wind-driven explicit Euler sim after gravity-settle, extracting ω, P_gen, tether FoS. Add a 7th validation gate to `_validate_island` that rejects designs with P_gen < 0.8×P_rated or ω < 5 rpm.

**Tech Stack:** Julia, KiteTurbineDynamics.jl, `run_canonical_sim!`, `settle_to_equilibrium`

---

### Task 1: Rewrite `headless_verify` to run wind-driven ODE

**Objective:** Replace the gravity-only settle + static P_gen estimate (which always returns ω=0 for unstarted designs) with a full 5-second wind-driven simulation that spins the rotors up and measures actual power.

**Files:**
- Modify: `src/headless_verify.jl` (entire file)

**Step 1: Write the new implementation**

Replace the settle-and-estimate block (lines 85-108) with a gravity-settle followed by a 5-second wind-driven explicit Euler sim. Use `run_canonical_sim!` from `simulation.jl`. Extract ω_mean, P_gen_mean, peak tether tension, and compute FoS from the final state.

Key design decisions:
- Gravity settle first (as before) to establish the static TRPT shape
- Then run 5s at 11 m/s wind with the MPPT generator load
- Use explicit Euler with the same DT and LIN_DAMP as the dashboard
- Extract ω from the ground ring (last ring, where the generator connects)
- Compute P_gen = k_mppt × ω³
- Compute tether FoS from the last second of simulation
- Duration: 5 seconds (enough to spin up or stall, cheap at ~1s wall-clock)

**Step 2: Verify on V10 winner**

Run the new headless_verify on the V10 winner. Expected: returns feasible=false with P_gen ≈ 0 kW — confirming it catches the V10 stall.

### Task 2: Add dynamic verification gate to `_validate_island`

**Objective:** Add gate #7 that calls the fixed `headless_verify` and rejects designs that fail the dynamic check.

**Files:**
- Modify: `scripts/run_v10_campaign.jl:_validate_island` (add gate before the return on line 277)

**Step 1: Add the gate**

After the 6 existing gates (before `return (true, ...)`), call `headless_verify` and check:
- `vr.success == false` → fail with "dynamic verification failed: P_gen=X kW, ω=Y rpm"
- `P_gen_mean < 0.8 × power_W` → fail with "P_gen=X kW under 80% rated"
- `ω_mean < 5 rpm` → fail with "ω=Y rpm — rotor stalled"

**Step 2: Test**

Run the campaign on a single island to confirm gate #7 fires on the V10 winner design.

### Task 3: Clear cache and verify

**Objective:** Ensure stale compiled code doesn't poison the new verification.

**Files:** No source changes.

```bash
rm -v ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
julia --project=. -e 'using KiteTurbineDynamics; println("OK")'
```

### Task 4: Test on V10 winner

**Objective:** Confirm the new headless_verify correctly diagnoses the V10 winner as dynamically dead.

Write and run a quick test script that:
1. Loads V10 winner vector
2. Decodes via `design_from_vector_v10`
3. Calls `headless_verify` with the fixed implementation
4. Asserts `!vr.feasible` or `vr.P_gen_mean < 0.8*50000`

Expected: script exits 0 (the design IS dynamically dead, and we correctly detect it).

### Task 5: Commit

```bash
git add src/headless_verify.jl scripts/run_v10_campaign.jl docs/plans/2026-06-21-dynamic-verification-gate.md
git commit -m "fix: wind-driven headless ODE verification gate catches dynamically-dead designs

- headless_verify now runs 5s wind-driven sim after gravity settle
- Extracts actual P_gen, ω_rpm, tether FoS from ODE state
- Added gate #7 to _validate_island: rejects P_gen < 80% rated or ω < 5 rpm
- Catches V10 winner (0 kW stall) and V9.0 winner (403 kW overshoot)
  at campaign-validation time instead of hours later in dashboard"
```
