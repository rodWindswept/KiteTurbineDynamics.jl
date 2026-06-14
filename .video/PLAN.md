# .video/PLAN.md — AWEC 2026 Explainer Video

**Title:** Breaking the TRPT Scaling Wall — Aerodynamic Expansion Rotors
**Duration target:** 6–8 minutes
**Audience:** Airborne Wind Energy researchers and industry (AWEC 2026 attendees)
**Format:** 1920×1080, 60fps, voiceover + animation + screencast

---

## Narrative Arc

| # | Scene | Duration | Visual | Message |
|---|-------|----------|--------|---------|
| 1 | **The Problem** | 60s | TRPT mass/power curve, scaling cliff animation | TRPT hits a nonlinear scaling wall — mass grows faster than power |
| 2 | **Why It Happens** | 45s | Ring compression diagram, Euler buckling equation | Compression rings are heavy dead mass — the torsional constraint forces more rings = more weight |
| 3 | **The Concept** | 90s | 3D TRPT with expansion blades appearing, banking animation | Replace passive rings with aerodynamic blades — same mould as generating rotor, banked downward |
| 4 | **The Physics** | 90s | Force diagram: apparent wind, lift, radial/axial resolution | v_app² = v_wind² + (ω·r)² ; F_radial = L × sin(bank) ; force-first structural model |
| 5 | **The Model** | 60s | Screencast: Julia code, test output, verification script | 917 tests, force-first injection into structural solver, settle fix |
| 6 | **The Dashboard** | 45s | Screencast: GLMakie dashboard with expansion rotors | Cyan diamond markers at expansion rings, HUD readout — visual physics verification |
| 7 | **The Results** | 60s | Bar chart: v5 shaft mass vs v6 shaft mass, convergence plot | 4.4% shaft mass reduction; optimiser saturates n_expansion=6, bank_angle=45° — wants MORE |
| 8 | **What's Next** | 30s | Roadmap: 50 kW campaign, ODE integration of F_radial, multi-rotor scaling | Scaling to utility power, full dynamic simulation, paper submission |

---

## Visual Language

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

## Scene Details

### Scene 1 — The Problem (60s)
- Opening: single kite turbine diagram → zoom to TRPT shaft
- Animated mass/power curve: linear for ideal, curved for real TRPT
- v2→v5 campaign progression overlay (mass numbers dropping but still climbing with scale)
- VO: "Kite turbines transmit power mechanically through a tensile shaft. But the shaft itself hits a scaling wall..."

### Scene 2 — Why It Happens (45s)
- Cross-section of TRPT ring: tether lines pulling inward, ring beam in compression
- Euler buckling equation appears: P_crit = π²EI/L²
- Torsional collapse diagram: Tulloch-Wacker criterion
- VO: "Compression rings resist buckling. More power → more rings → more mass. The shaft becomes its own enemy."

### Scene 3 — The Concept (90s)
- 3D TRPT shaft rotating slowly
- Expansion blades fade in on rings near hub
- Banking animation: blades tilt ~20° toward next ring down
- Side-by-side: generating rotor blade vs expansion blade — SAME blade, different mounting
- VO: "What if the rings spread themselves? Same blade as the generating rotor — identical span, chord, count — but banked toward the next ring..."

### Scene 4 — The Physics (90s)
- Animated force diagram at a single ring
- Apparent wind vector: v_wind + ω×r
- Lift resolves through bank angle: sin(θ)→radial, cos(θ)→axial
- Force-first equation: F_v = F_in - F_centripetal - F_radial/n
- Numbers appear: 2,830 N/blade, F_radial = 4,840 N at hub ring
- VO: "The blade sees apparent wind from rotation PLUS free-stream..."

### Scene 5 — The Model (60s)
- Screencast: terminal running `julia --project=. test/runtests.jl` → 917/917 pass
- Code snippet: force-first injection in `_evaluate_trpt_design_impl`
- Screencast: `scripts/verify_expansion_forces.jl` output
- VO: "The model is open-source. 917 tests verify every equation..."

### Scene 6 — The Dashboard (45s)
- Screencast: `julia --project=. scripts/interactive_dashboard.jl --expansion 20`
- Mouse hover over cyan diamond markers on expansion rings
- HUD section: rings, bank angle, blade span, F_radial
- VO: "The dashboard lets us verify visually — are the expansion blades pulling where we expect?"

### Scene 7 — The Results (60s)
- Bar chart: v5 shaft 11.47 kg → v6 shaft 10.97 kg
- Convergence plot: mass dropping from 72 kg to 17.37 kg over 30k iterations
- Parameter saturation: n_expansion→6, bank_angle→45°, n_lines→8
- VO: "After 60 islands of differential evolution, the optimiser demands maximum expansion..."

### Scene 8 — What's Next (30s)
- Roadmap timeline: 50 kW campaign → ODE integration → multi-rotor → paper
- Call to action: GitHub link, windswept.energy
- VO: "This is early-stage research. The model is open. The data is public. Join us."

---

## Production Pipeline

1. **Script finalisation** → `script/voiceover.md`
2. **Diagram design** → `diagrams/` (SVG/PNG exports from GLMakie + Manim)
3. **Animation coding** → `script/scenes.py` (Manim CE)
4. **Screencast capture** → `screencasts/` (OBS or ffmpeg screen capture)
5. **Voiceover recording** → `audio/voiceover.wav`
6. **Assembly** → Manim render + ffmpeg stitch + audio sync
7. **Review** → watch full cut, note revisions

---

## File Map

```
.video/
├── PLAN.md                    ← this file
├── script/
│   ├── voiceover.md           ← full narration script
│   ├── scenes.py              ← Manim CE animation code
│   └── timing.csv             ← scene → duration → VO line mapping
├── diagrams/
│   ├── trpt_scaling.svg       ← mass/power curve
│   ├── ring_compression.svg   ← ring FBD with buckling eq
│   ├── expansion_concept.svg  ← 3D concept diagram
│   ├── force_diagram.svg      ← apparent wind + resolution
│   └── results_bars.svg       ← v5 vs v6 comparison
├── screencasts/
│   ├── test_suite.mp4         ← terminal recording
│   ├── dashboard.mp4          ← GLMakie dashboard
│   └── verify_forces.mp4      ← verification script
├── renders/
│   └── (manim output)
├── audio/
│   └── voiceover.wav
└── stills/
    └── (preview frames)
```
