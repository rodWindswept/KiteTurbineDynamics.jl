# PRD 0006 Phase 1 — Delta Analysis

**Status:** COMPLETE
**Generated:** 2026-07-06T09:11:23.859524
**Parent:** [PRD 0006 — Blade Geometry Audit & Recovery](0006-blade-geometry-audit.md)
**Generator:** `scripts/generate_phase1_delta.py` (idempotent, CSV→doc)

**V10 Tight λ=1.0:** `gate1_v10_tight_maxpower_summary.csv` — `# script:hunt_kmppt_bisect @ 86ca0e5 · builder:gate1_v10_tight_maxpower · date:2026-07-05T21:37:42 · max_power:true`

**V10 Reinforced:** `gate1_v10_reinforced_maxpower_summary.csv` — `# script:hunt_kmppt_bisect @ 86ca0e5 · builder:gate1_v10_reinforced_maxpower · date:2026-07-05T22:58:24 · max_power:true`

**λ=0.69:** `gate1_blade_scaled_069_maxpower_summary.csv` — `# script:hunt_kmppt_bisect @ 86ca0e5 · builder:gate1_blade_scaled_069_maxpower · date:2026-07-06T00:37:12 · max_power:true`

---

## 1. Gate 1 Delta Tables

### 1.x V10 Tight λ=1.0

| Wind | P_pre | P_post | ΔP% | ω_pre | ω_post | Δω% | k_pre | k_post | FoS_pre | FoS_post | Status_pre → Status_post |
|------|-------|--------|-----|-------|--------|-----|-------|--------|---------|----------|--------------------------|
| 5 | 1.2 | 16.9 | +1260.6% | 0.0 | 104.6 |     — | 500.0 | 12.9 | inf | 3.66 | underpowered → power_deficit |
| 7 | 8.0 | 46.6 | +482.5% | 0.0 | 146.5 |     — | 240.7 | 12.9 | inf | 3.11 | underpowered → ok |
| 9 | 28.5 | 100.7 | +252.9% | 0.0 | 189.5 |     — | 115.9 | 12.9 | inf | 2.19 | underpowered → ok |
| 11 | 172.7 | 118.8 |  -31.2% | 219.5 | 156.8 |  -28.5% | 15.6 | 26.9 | 2.30 | 1.15 | ok → FoS_fail |
| 13 | 185.1 | 196.6 |   +6.2% | 358.9 | 185.6 |  -48.3% | 3.5 | 26.9 | 1.64 | 0.60 | ok → FoS_fail |
| 15 | 178.6 | 492.8 | +176.0% | 427.0 | 321.6 |  -24.7% | 2.0 | 12.9 | 1.36 | 1.06 | FoS_fail → FoS_fail |

### 1.x V10 Reinforced

| Wind | P_pre | P_post | ΔP% | ω_pre | ω_post | Δω% | k_pre | k_post | FoS_pre | FoS_post | Status_pre → Status_post |
|------|-------|--------|-----|-------|--------|-----|-------|--------|---------|----------|--------------------------|
| 5 | 1.7 | 14.8 | +770.0% | 189.2 | 99.9 |  -47.2% | 240.7 | 12.9 | inf | 37.43 | underpowered → power_deficit |
| 7 | 8.2 | 38.3 | +365.5% | 392.3 | 137.3 |  -65.0% | 115.9 | 12.9 | inf | 14.30 | underpowered → power_deficit |
| 9 | 28.2 | 74.8 | +164.7% | 589.0 | 172.2 |  -70.8% | 115.9 | 12.9 | inf | 9.47 | underpowered → ok |
| 11 | 159.5 | 121.2 |  -24.0% | 204.0 | 158.3 |  -22.4% | 16.4 | 26.9 | 1.97 | 4.12 | ok → ok |
| 13 | 125.5 | 196.1 |  +56.2% | 290.2 | 185.7 |  -36.0% | 4.5 | 26.9 | 2.25 | 3.31 | ok → ok |
| 15 | 110.9 | 301.0 | +171.4% | 376.9 | 213.0 |  -43.5% | 2.0 | 26.9 | 7.18 | 2.26 | ok → ok |

### 1.x λ=0.69

No pre-fix data available for this builder.

| Wind | P (kW) | ω (rpm) | k | FoS | Status |
|------|--------|---------|----|-----|--------|
| 5 | 6.8 | 143.4 | 2.0 | 11.38 | power_deficit |
| 7 | 19.0 | 176.7 | 3.0 | 12.50 | power_deficit |
| 9 | 35.6 | 170.9 | 6.2 | 4.62 | power_deficit |
| 11 | 63.3 | 207.0 | 6.2 | 3.56 | ok |
| 13 | 102.7 | 243.2 | 6.2 | 2.85 | ok |
| 15 | 155.8 | 279.5 | 6.2 | 2.08 | ok |

## 2. Loss Model Re-fit (P_loss = c × ω³)

| Builder | c (kW/(rad/s)³) | R² |
|---------|-----------------|-----|
| V10 Tight λ=1.0 | 0.001342 | 0.9357 |
| V10 Reinforced | 0.009053 | 0.8649 |
| λ=0.69 | 0.001960 | 0.9869 |

## 3. Static–Dynamic Gap

**Basis:** P_ground(dynamic) / P_static(aero) — see §P3 for basis discussion.

| Wind | V10 Tight λ=1.0 (×) | V10 Reinforced (×) | λ=0.69 (×) |
|------|--------|--------|--------|
| 5 | 2.07× | 1.43× | 1.14× |
| 7 | 2.07× | 1.34× | 1.47× |
| 9 | 2.22× | 1.31× | 2.43× |
| 11 | 2.18× | 1.78× | 2.55× |
| 13 | 2.46× | 1.96× | 3.36× |
| 15 | 5.02× | 2.47× | 4.29× |

## 4. FoS Claim Audit

### V10 Tight λ=1.0

**Claims BROKEN by the 70/30 fix:**

- 11 m/s: FoS 2.30 → 1.15 (-50%) — 🔴 CLAIM BROKEN (was safe ≥1.5, now marginal)
- 13 m/s: FoS 1.64 → 0.60 (-63%) — 🔴 CLAIM BROKEN (was ok ≥1.0, now fail)

### V10 Reinforced

No claims broken.


## 5. Envelope Summary (post-fix)

| Builder | Rated | FoS≥1.5 all winds? | Max power (15 m/s) | Min FoS |
|---------|-------|---------------------|--------------------|---------|
| V10 Tight λ=1.0 | ≤9 m/s | ❌ NO | 493 kW | 0.60 |
| V10 Reinforced | ≤9 m/s | ✅ YES | 301 kW | 2.26 |
| λ=0.69 | ≤11 m/s | ✅ YES | 156 kW | 2.08 |

---

**Generated:** `scripts/generate_phase1_delta.py` at 2026-07-06T09:11:23.859945
**Rule:** All numbers read from CSVs at generation time. No hand-transcription.
