# Q1 verdict — orbital-damping operator vs the light-ring fling (2026-08-15)

**Test:** `scripts/diag_q1_lindamp.jl` — void 18 m winner (58 g hub ring,
t_over_D=0.005), 60 s post-settle MPPT, lin_damp=0.05 vs 0.00.

| lin_damp | break at | max\|ω\| | max tension |
|---|---|---|---|
| 0.05 (default) | 5.0 s | 17.87 rad/s | 1.05e5 N |
| 0.00 | 5.0 s | 35.92 rad/s | 5.56e5 N |

**Verdict: companion fix (c) is OUT.** The line break occurs at the same
time (5.0 s) with and without the orbital-damping operator. The fling is
driven by the physical mass/thrust mismatch (58 g ring vs ~5.7 kN rotor
thrust), not by the numerical operator. The operator does damp the pre-break
transient (without it ω doubles and elastic tension rises 5× before the
break), consistent with the R2 damper-spike annotation — but it neither
causes nor prevents the failure.

Gate 14 (model-admissibility checklist) moves PENDING → RESOLVED (out).
