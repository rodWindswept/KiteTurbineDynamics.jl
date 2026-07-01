# Control Map Findings — 2026-06-30

## The Inverted k_mppt Problem

Our bisection hunt is finding the **wrong solution**. Here's the evidence:

| v_wind | k_mppt | P_kW | ω_rpm | FoS |
|--------|--------|------|-------|-----|
| 11.0 | 15.6 | 172.7 | 219 | 2.30 |
| 13.0 | 3.5 | 185.1 | 359 | 1.64 |
| 15.0 | 2.0 | 178.6 | 427 | 1.36 |

We're braking **less** at higher wind. k=16 at 11 m/s, k=2.0 at 15 m/s. This is backwards — a proper MPPT controller should increase generator load as wind rises to cap power at rated.

### Why: The P(k) Hump and Two Solutions

The TRPT power curve P(k) is hump-shaped:

```
P ↑
  |           ╱‾‾‾╲
  |          ╱     ╲
  |  ←───  ╱       ╲ ───→
  |       ╱         ╲
  |──────╱───────────╲────── P_rated
  |     ╱             ╲
  |    ╱               ╲
  +───┴─────────────────┴──→ k
  k=2                    k=5000
  LEFT                   RIGHT
  FLANK                  FLANK
```

P_rated crosses the curve at **two** points:
- **Left flank** (low k, high ω): Barely any generator braking. Rotor overspeeds until ω is so high that P = k·ω² hits rated. High thrust → low FoS.
- **Right flank** (high k, low ω): Strong generator braking. Rotor runs slow. P still hits rated because k is large. Low thrust → better FoS, but more twist.

Our bisection finds the **left-flank crossing** because the bracket scan walks k from 2 upward and stops at the first P > P_rated. This is the overspeed solution — minimum braking, maximum speed, worst structural safety.

The **right-flank crossing** would give:
- Higher k (more generator braking)
- Lower ω (less thrust → better ring FoS)
- More twist (but collapse margin is currently 42-47° — plenty of headroom)

### Why the Right Flank is Better for TRPT

The TRPT's critical failure mode is **ring buckling from thrust** (low FoS), not torsional collapse (high collapse margin in all tests). The right-flank solution trades twist margin (abundant) for FoS margin (scarce). This is the correct trade for a tensile transmission.

### The Fix

After finding the left-flank solution, also search the **right flank** (k > k_peak, where P decreases toward zero). Bisect on the right flank to find the k where P drops to P_rated from above. Compare both solutions and select the one with better min(FoS).

The right-flank bracket: k_peak → K_MAX, where P_peak > P_rated and P(K_MAX) ≈ 0. Bisect to find P crossing P_rated on the way down.

---

## V10 Tight — Structural Failure Mode

The timeseries data shows:

| Wind | Solution found | FoS | Collapse margin | Failure |
|------|---------------|-----|-----------------|---------|
| 11 m/s | Left flank, k=16 | 2.30 | 45.5° | Passes |
| 13 m/s | Left flank, k=3.5 | 1.64 | 46.2° | Marginal |
| 15 m/s | Left flank, k=2.0 | 1.36 | 47.3° | **Fails** |

The design fails from **ring buckling at high thrust**, not from torsional collapse. Collapse margin is healthy (45-47°). The failure is driven by overspeed — the rotor runs at 427 rpm at 15 m/s, producing 179 kW of thrust load on rings designed for 50 kW.

The right-flank solution (if it exists) would run the rotor at lower speed with higher generator braking, reducing thrust and improving FoS. Whether a right-flank k exists that hits 50 kW with FoS ≥ 1.5 is the open question.

---

## Reinforced V10 — Structural Fix Confirmed

| Wind | k_mppt | P_kW | ω_rpm | FoS | Status |
|------|--------|------|-------|-----|--------|
| 11.0 | 16.4 | 159.5 | 204 | 1.97 | ok |
| 13.0 | 4.5 | 125.5 | 290 | 2.25 | ok |
| 15.0 | 2.0 | 110.9 | 377 | 7.18 | ok |

The +30% bottom ring radius (r_bottom_scale=1.30) using ring_spacing_v4 geometry dramatically improves FoS:
- 15 m/s: FoS 1.36 → 7.18 (5.3× improvement)
- Zero failing rings at all winds

But the design is still over-bladed — even at k→0 the minimum power exceeds 110 kW. The reinforcement fixes the structural problem but the rotor is too large for a 50 kW TRPT. This is a **rotor sizing problem**, not a structural problem.

---

## Collapse Margin vs FoS

Across all tests, collapse margin is 42-47° — well above any danger threshold. FoS is the limiting constraint. This confirms:

1. **Collapse margin is the better indicator for field operation** — it's directly measurable via IMU + distance-to-hub, and it stays healthy even when FoS is marginal.
2. **For the DE campaign, FoS is the binding constraint** — the optimizer needs to increase ring radii (as the reinforcement proves works) rather than worrying about torsional collapse.
3. **Raising the collapse margin soft-taper from 5° to 20° is safe** — there's 42° of headroom. The controller can be much more conservative without losing torque transmission.

---

## Next Steps

1. **Implement right-flank search** in the bisection hunt — find both solutions, pick the safer one.
2. **Re-run V10 Tight with right-flank search** — does a right-flank k exist with FoS ≥ 1.5?
3. **Blade scaling** — the rotor is over-bladed. The DE campaign should reduce blade scale (λ) until the left-flank minimum power at k→0 is ≤ P_rated.
4. **Phase 2 DE objective** — incorporate both flanks, FoS gate, and right-flank preference into the dynamic objective function.
