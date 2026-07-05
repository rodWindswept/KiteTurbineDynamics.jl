# Collaboration Brief — someAWE Labs, Alicante

**From**: Rod Read, Windswept & Interesting Ltd (rod@windswept.energy)
**To**: Christof Beaupoil
**Date**: July 2026 · **Ref**: KTD.jl Technical Report v0.2 (DOI pending)

## The proposal

Cross-validate `CoaxialAutogyroStacking.jl`'s lift predictions against someAWE's instrumented flight data. You fly the most advanced rotary AWE hardware in existence; we have a parametric model with zero hardware validation. That asymmetry is the collaboration.

## Why you, why now

- Your autogyro pumping-mode system — swashplate with active rotation compensation, Kaman-style servo flaps for cyclic pitch, no pitch links at the hub — is the closest flying analogue to our autogyro lift subsystem (stacked autogyro rotors on a Dyneema line, 45–55° elevation, holding the TRPT power shaft aloft).
- Your servo-flap approach may directly simplify our stacked configuration by removing mechanical linkages between units — a design question we can only answer with your hardware experience.
- Our current lift-stack numbers (best v1: 4 × 3.0 m rotors, 16.8 kg, 5.1 kN lift at 8 m/s, 302 N/kg) come from a PCA-2 disk model with a 3× solidity mismatch — a factor-of-2 error is possible. Flight data is the only honest calibration.

## What each side brings

**someAWE**: instrumented flight data, swashplate and servo-flap design experience, hardware reality check.
**Windswept**: scaling predictions to 50 kW, autogyro parameter sweep data, stacked configuration analysis.

**Planned**: Rod to visit someAWE Labs in Alicante, October 2026 — this brief is the agenda seed.

## Honesty note

Everything on our side is simulation-only, confidence tier P. Your flight data is the only tier-H input available to either lift-subsystem effort. In-kind exchange only — no cash contribution requested.
