# F9 review log — "The anchor" (29-Apr-2020 vs calibrated model)

**Data provenance (pass-2 audit 2026-08-16)**
- Model curve: `scripts/results/april29_model_curve.csv` — final sweep
  (proc_bd60d4e170fc), dt=4e-6, no expansion rotor, const-tension bucket
  (118 N), MEASURED τ(ω) table REBUILT from 12 × 30-s steady blocks
  (22.65→13.11 N·m over 9.75→12.86 rad/s, flat ends, floor 2.5), shear
  α=0.14, warm start.
- Measured curve: 30-s wall-clock block means (12 blocks, wind 5.57-6.94,
  P 168-267 W) computed in the figure script from april29_anchor.csv
  (1,206 rows, now with con_time_days).
- Rod's day-0 chart (1-min means, 15:04-15:12): wind 5.9-7.2 m/s, P
  186-281 W — matches the 30-s envelope; the raw-row bins at 3.25/3.75/
  8.75 (n=4 each) were 2-4 s gust lulls with phase-lagged power
  (rotor ~110 rpm, P 120-400 W) — transients, NOT operating points; the
  earlier "100.2% of Betz" claim reframed as a phase-lag artifact, not
  wind mismeasurement.

**Vision rounds (rebuild):**
- R1-R6 (first build): legend/annotation fixes as logged earlier.
- R7 (30-s rebuild): pass — measured x+y error bars, lull-transient
  annotation, test-band marker, caption all clean.
- R8 (floor fix): pass — floor ends at 4.5 m/s, model cut-in at 4.75,
  annotation 234 W consistent everywhere.
- R9-R10 (Rod HITL: "overlapping text in several places — our standard"):
  strict-enumeration audit found real overlaps the lenient rounds accepted:
  red lull-transient text crossing the model rise + Betz line + y tick
  labels → DELETED (the story lives in the caption; redundancy was the
  bug); startup-block error bars (rpm 0-56) reaching the top annotation →
  measured series now filtered to STEADY blocks only (rpm>60, same filter
  as the τ-table knots); legend items colliding → shortened labels;
  caption overlapping legend (8 lines ≈ 0.19 of fig height vs legend at
  y 0.13) → taller figure (6.4 in), caption trimmed to 5 wider lines at
  7.5 pt, legend at 0.14; all annotations given opaque white bboxes
  (alpha 1.0). F7 value labels: opaque white bboxes (alpha 1.0) mask the
  gridlines — the audit's "no boxes" read is the invisible-box paradox
  (white on white); matplotlib's bbox contract guarantees the mask.
  F4/F6 legends: white frames (gridline-through-text killed).
- R11 (final strict audit): ZERO touches on F9. F7: zero text-text/bar
  touches. F3/F6 clean throughout.

**Status: PASS (R11) after Rod HITL round 1. Lesson logged in
ktd-chart-design skill: strict enumeration prompts + opaque bboxes +
legend/caption height math.**

**Key numbers the figure carries (final)**
- Model 234 W vs measured 223 ± 79 W at 6.25 m/s; Cp_sys ≈ 0.16 both;
  Oliver's spring-disc Cp_max = 0.166.
- Test genuinely covered 5.5-7.0 m/s (30-s means); power varied with the
  controller's ramping (186-281 W, 1-min means) more than with wind.
- Model cut-in ~4.75 m/s; at 5.25 m/s it holds ω=11.03, P=240.5 W —
  close to the field operating point (ω 11.3, P 216-228).
- Model parks at AeroDyn peak λ ≈ 7.6 (ω 16-28.6); field held ω
  9.8-12.9 rad/s (TSR set 5.5, actual 4.35) — thesis's flagged 6-blade gap.
- Table never observed past 12.9 rad/s — model's >6.5 m/s rise is
  extrapolation.

**Status: PASS (R8). Pending Rod's HITL vision pass.**
