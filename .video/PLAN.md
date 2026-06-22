# .video/PLAN.md — Windswept Explainer Video (UPDATED)

**Title:** How We Found the Lightest Kite Turbine
**Duration target:** 4 minutes
**Audience:** Potential collaborators, contributors, AWEC 2026 attendees, industry partners
**Format:** 1920×1080, 60fps, voiceover + animation + screencast
**Status:** Transcript updated 2026-06-22. Diagram/animation work pending.

---

## Narrative Arc (UPDATED)

| # | Scene | Duration | Visual | Message |
|---|-------|----------|--------|---------|
| 1 | **Why Light Matters** | 35s | Mass/power curve, TRPT shaft, scaling problem | Mass-to-power ratio gets WORSE with scale — existential for airborne wind |
| 2 | **The Search** | 20s | Campaign montage V2→V10, PCA landscape | 7 campaigns, 310K evaluations, 14D collapses to 2 orthogonal axes |
| 3 | **The Error** | 20s | tan→sin equation, triangle→dodecagon transition | Math error understated compression by 50%. Correcting it flipped the optimum. |
| 4 | **The Gates** | 25s | Slenderness gate, tension gate, island paths | Two hard physics gates: Lr/D>21 and every line in tension. |
| 5 | **The Trap** | 25s | 3D PCA elevation, Basin A vs B, λ gradient | Two-basin architecture. 6 islands trapped. λ gradient < 7 required. |
| 6 | **The Breakthrough** | 25s | V10 Tight result, k_mppt fix, ring-mapping fix | 49.2 kg, 4 rotors — 35% reduction. k_mppt λ² and ring-mapping corrections. |
| 7 | **The Honest Truth** | 25s | 5 params at bounds, static-vs-dynamic dashboard | Optimizer wants more. Static 50 kW → Dynamic 12 kW. The gap is real. |
| 8 | **The Engine** | 25s | 540 papers, K1 graph network, query animation | Agents-K1 scholar knowledge graph: every paper, method, failure mode. |
| 9 | **The Invitation** | 30s | V10 Tight turbine in sunset, GitHub URL, tagline | 49.2 kg @ 50 kW. Open code, public data. Come build it with us. |

---

## Key Numbers (Current)

| Metric | Value | Source |
|--------|-------|--------|
| Best airborne mass | 49.2 kg | V10 Tight campaign |
| Rotors | 4 | V10 Tight optimum |
| Tip-speed ratio | λ = 0.519 | V10 Tight |
| Static prediction | 50 kW | Equilibrium solver |
| Dynamic actual | 12 kW | Full multibody ODE |
| Parameters at bounds | 5 | bank_angle, n_exp, n_lines, λ_top, λ_bottom |
| Papers in KG | 540 | Agents-K1 ingest |
| Graph nodes | 7,401 | awes_unified.graph.json |
| Graph edges | 6,903 | awes_unified.graph.json |

---

## Visual Language (unchanged)

| Element | Specification |
|---------|---------------|
| Background | Near-black `#0A0C10` (matching dashboard Instrument theme) |
| Primary | Cyan `#39D0D8` |
| Secondary | White `#E8EEF6` |
| Warning | Amber `#F5B73D` |
| Alarm | Red `#FF4D4F` |
| Font | JetBrains Mono (code), Inter (narrative) |
| Math | LaTeX via Manim `MathTex` |

---

## Production Pipeline (unchanged)

1. **Script finalisation** → `script/voiceover.md` (SUPERSEDED → use `docs/awes-forum-diagrams/video-interpretation/SCRIPT_NARRATIVE.md`)
2. **Diagram design** → `diagrams/` (SVG/PNG exports from GLMakie + Manim)
3. **Animation coding** → `script/scenes.py` (Manim CE)
4. **Screencast capture** → `screencasts/` (OBS or ffmpeg screen capture)
5. **Voiceover recording** → `audio/voiceover.wav`
6. **Assembly** → Manim render + ffmpeg stitch + audio sync
7. **Review** → watch full cut, note revisions

---

## New Diagrams Needed

| Diagram | Source | Description |
|---------|--------|-------------|
| V10 Tight design render | KTD dashboard / FreeCAD | 4-rotor, 49.2 kg, heptagon rings |
| Static-vs-dynamic comparison | Dashboard screenshots | Side-by-side: 50 kW prediction vs 12 kW reality |
| 5-parameters-at-bounds | V10 Tight convergence | Five amber readouts pegged at max |
| Agents-K1 graph network | awes_unified.graph.json | 540 papers → 7,401 nodes network visualization |
| Tension gate visualization | KTD structural solver | Slack line detection, penalty barrier |
