# .video/screencasts/README.md — Screencast Capture Guide

Record at 1920×1080, 60fps. Use OBS Studio or ffmpeg screen capture.
Terminal font: JetBrains Mono 14pt. Background: #0A0C10.

---

## Capture 1: test_suite.mp4

```bash
# Record terminal running test suite
julia --project=. test/runtests.jl
# Stop recording after "917/917" appears (~3 min)
```

## Capture 2: dashboard.mp4

```bash
# Launch dashboard with expansion rotors
julia --project=. scripts/interactive_dashboard.jl --expansion 20 --n-expansion 3

# In recording:
# - Show the 3D viewport with cyan diamond markers
# - Scroll through HUD to show expansion section
# - Advance a few frames to show the system in motion
# - Show the control panel
# Duration: ~30s of screen time
```

## Capture 3: verify_forces.mp4

```bash
julia --project=. scripts/verify_expansion_forces.jl
# Record output scrolling through per-ring force breakdown
```
