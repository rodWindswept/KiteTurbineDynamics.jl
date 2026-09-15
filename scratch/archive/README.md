# scratch/archive — retired probes

Diagnostic probes that produced a wrong conclusion. Keep them for provenance.
Do not run them as guidance. A probe lands here when a corrected result replaces
its false measurement or premise. CI does not run archived files. A green run
here does not describe current behaviour.

| File | Why archived |
|---|---|
| `diag_lift_line_switch.jl` | It read `sys.kite.node_id` as the kite. That node is the hub ring. So it measured hub to sky anchor, not the lift line. It said the lift line switches off. That is false. The live kite position is `sys.kite_pos`. The code holds it at line length every step. The gate never opens. See `hermes_probe_lift_line.jl`. |
| `derive_lift_chain_constants.jl` | Its method is circular. It settled from a builder already at 3.99 m. So it read 3.99 for every radius. It said the offset does not change with radius. That is false. The code derives the offset. `bridle_bearing_offset(r_top)` gives 3.994 m at 2.4 m and 4.327 m at 2.6 m. |
