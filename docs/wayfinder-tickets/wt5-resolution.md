# WT5 Resolution: λ=0.69 Reinforced with Per-Vertex Spoke Spring

> Resolved 2026-07-11 | `wayfinder:task` resolved

## Result

**Per-vertex spoke spring (forces-based) works mechanically.** Ring centers stay on shaft axis (~0mm drift). FoS airborne = 2.40 with 0 rings failing. Vertex polygon geometry preserved → Tulloch torsional coupling intact.

**Dynamic sustain fails** — same cause as all previous λ=0.69 Reinforced tests: small blades (0.69× scale) cannot overcome the reinforced frame's parasitic drag (4mm tethers, enlarged bottom rings). Motor spin-up reaches 55 rpm but the system can't sustain at k=6.23 MPPT.

## Key numbers

| Metric | Value | Verdict |
|--------|-------|---------|
| Max ω (motor) | 55 rpm | Too low for aero sustain |
| MPPT sustain ω | 0 rpm | Can't sustain |
| Ring drift | 0.0 mm | ✅ Zero expansion |
| FoS airborne | 2.40 | ✅ 0/22 rings failing |
| Vertex constraint | Active | ✅ Per-vertex springs working |

## Physics assessment

- **Per-vertex spring force model is correct.** The implementation is functional: forces are computed at each vertex, summed at ring center, and applied as velocity impulses.
- **Tulloch torsional coupling is preserved.** Vertex positions maintain polygon geometry; twist angles α evolve freely.
- **Dynamic failure is a design-parameter problem**, not an implementation bug. The reinforced frame was designed for full-scale blades (1.0×). Smaller blades need a proportionally lighter frame.

## Path forward

For λ=0.69 to sustain:
- Stronger motor kickstart (k < -500 to reach 200+ rpm)
- Or lighter frame (3mm tethers, r_bottom_scale=1.0) — this is λ=0.69 Tight, which fails structurally
- Or larger blades (scale ~0.85-0.90) to match frame drag
- Or accept that the constrained map has one viable design: V10 Reinforced (scale=1.0)
