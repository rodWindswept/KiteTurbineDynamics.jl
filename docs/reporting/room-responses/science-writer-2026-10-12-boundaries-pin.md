# Room response: model-boundaries pins, launch-and-recovery scope and wind-model wording (2026-10-12, science-writer)

**Status** PREP. **Seat** science-writer. **Read at** `697cddb`.

This response changes no draft line, no register row and no glossary
row. It rules nothing.

Scope: the two text pins the author seat requested for the §4.3
boundaries expansion. The §4.3 and §5 fold rides the author pass. The
pins below are gate-simmed and ready to fold verbatim.

## 1. The pins

Pin 1, §4.3, after the bridling bullet (draft v0.18, line 491):

```text
- The model does not simulate launch or recovery.
  Each run starts with the machine already aloft at its operating point.
  The full launch sequence and the recovery are outside this report.

  The lift system must also carry the machine during hoisting, after a TRPT break and in high wind.
  The record does not quantify those cases.
```

Pin 2, §4.3, the next bullet:

```text
- The campaign wind is steady and sheared.
  Its speed rises with altitude on the site wind profile.
  The profile comes from wind measured at the Daisy machine.
  Gusts and turbulence do not occur in a scored run.
  The wind direction stays fixed.
```

## 2. Grounding: launch and recovery

- The run start. The cold path settles the machine to its operating
  state before the relax and window run.
  Sources: `src/objective_evaluator.jl` (cold branch),
  `src/initialization.jl` (the settle docstring), NR-025 (signed).

- The field sequence differs from the start state. The topmost kite
  launches first, per `docs/agents/physics-topology.md` §3.
  The draft §3.3 prints that sequence. Pin 1 states the model start.

- The lift-system duty cases. The back line must carry the machine
  through hoisting, a TRPT break and high wind
  (`docs/lift/README.md`). The record quantifies none of those cases.

## 3. Grounding: wind

- Steady. The evaluator wind closure takes a time argument and never
  uses it. Source: `src/objective_evaluator.jl`, the wind function
  above the start protocol.

- Sheared. Each element reads the wind at its own position, and the
  profile is the Hellmann power law. Sources: `src/dynamics.jl`
  (ring-beam mid-positions), `src/wind_profile.jl` (profile and site
  standard).

- The anchor. The measured Daisy pair sets the profile, per
  `src/wind_profile.jl` (the site standard block). The pin prints no
  value.

- No gust, no turbulence, no turn. The scenario constructors
  (`wind_ramp`, `gust_event`, `turbulent_wind`) sit in the same file.
  No campaign path calls them. The evaluator wind function holds one
  direction.

- The constants stay qualitative. That is the default route in
  `docs/reporting/glossary-candidates.md` until a constants row
  exists.

## 4. The gate (STE)

This seat ran the gate on a copy of the v0.18 draft with both pins
folded in: `scratch/sw_bp_sim.md`. The receipts:

- Baseline: `scratch/sw_bp_lint_baseline.txt`. Words 3447, total 4.
- Edited: `scratch/sw_bp_lint_sim.txt`. Words 3545, total 4.

No new offender line and no added count. The two offender sets match
entry for entry: one passive line (pre-existing) and the three
accepted table flags (pre-existing).

Keep the laid-out wrap. Every sentence ends at a line end. The same
wind text rewrapped as running prose trips one `long_paragraph` flag
(probe: `scratch/sw_bp_wrap_probe.md`). Rewrap only with a re-run.

## 5. Notes for the fold

- The extension pair inside Pin 1 is optional. Recommended: keep. It
  closes the launch-side gap the review names, and every clause is a
  source read.

- Term flags for Track D. "site wind profile" embeds the "site wind
  (wind standard)" candidate row. "scored run" is a new compound.
  Track D settles the display form.

- Pin 2 seats in §4.3. The author owns the seating and the §5 echo.

- No number rides either pin. Counter-reads on the model claims are
  welcome from the validators.

**Reproduction.** The sim file equals the v0.18 draft plus the two
pinned blocks. Greps for the absent forms: "does not simulate",
"campaign wind".

## Deltas

- v1 (2026-10-12): the pins land. Launch-and-recovery scope and
  wind-model wording, gate-simmed, handed to the author fold.

science-writer, 2026-10-12.
