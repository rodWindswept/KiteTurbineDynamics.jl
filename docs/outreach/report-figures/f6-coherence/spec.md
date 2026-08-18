# F6 — Coherence traces: corrected-era campaigns vs the voided pre-fix attempt

## Narrative

The first 5 kW campaign attempt (2026-08-14 22:42) ran on the evaluator
before the hub-sanity rejection landed (`7183f96`, 08-14 22:57: designs with
a diverged hub ring, ω ~ 1e66, could pass ground-side metrics). Those runs
were voided and the campaigns re-run on the corrected model (08-16). This
figure overlays the two eras' best-fitness traces per length: the voided
pre-fix attempt (dashed) and the corrected-era campaigns the report cites
(solid). The traces are NOT on the same metric — the pre-fix evaluator
scored without the hardening gates (hub sanity, tip-speed 100 m/s, cp
falloff, per-rotor Betz, rope-break SK99) — and the voided attempt's
island-1 best scored −6.66, better than anything the corrected campaign
found (−6.22). That is the trap the admissibility checklist exists for:
the old metric looked at least as good. The report stands on the corrected
era; the voided runs are retained as the audit trail (their island-1 best
still gates at 6.312 kW today — a sound design from a suspect era, kept as
evidence, not as a result).

## Data verification

- Winner: `scripts/results/v13_5kw_len{18.0,21.2,25.0}/convergence.csv`
  (corrected era, committed ec44148/ed284b7/28b7a57).
- Void: `scripts/results/void_v13_pre-fix_len{18.0,21.2,25.0}/convergence.csv`
  (untracked audit artifacts, 08-14 22:42, pre-7183f96).
- Endpoints: winner −6.2210/−6.6641/−7.3074; void −6.2240/−6.6724/−6.8827
  (island 3/3/1). Round-1 check: tails match the CSVs.
- Fitness minimised (argmin; rejects = 1e9 off-scale) — same convention as F4.

## Design spec

- 1×3 small multiples (18.0/21.2/25.0 m), shared y range (−8.6, −2.5).
- Solid lines = corrected era (3 islands, blue/orange/green); dashed lines =
  voided era (same island colours). Legend: "corrected era (report)" /
  "voided era (pre-fix)".
- Caption: era story + provenance boxes (convergence.csv @ commits).
