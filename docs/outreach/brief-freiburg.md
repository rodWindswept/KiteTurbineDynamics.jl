# Collaboration Brief — University of Freiburg, Systems Control & Optimization Laboratory

**From**: Rod Read, Windswept & Interesting Ltd (rod@windswept.energy)
**To**: Prof. Moritz Diehl's group (Diehl, Leuthold, Harzer, De Schutter)
**Date**: July 2026 · **Ref**: KTD.jl Technical Report v0.2 (DOI pending)

## The proposal

Apply Leuthold's rigidly-convected vortex wake model to KTD.jl's banked expansion rotor arrays. The TRPT wake is **geometrically fixed and axisymmetric** — a deterministic, simpler test case than free-flying multi-kite, ideal for validating the model before deploying it on harder trajectories.

## Why you, why now

- Leuthold's 2019 engineering wake induction model quantified 18–21% overprediction from neglected induction in conventional AWE. KTD.jl's dynamic simulator finds a substantially larger static–dynamic gap for TRPT (magnitude under re-baseline after a simulator audit; mechanism attribution in progress). Our configuration is a direct data point for her research question — "how difficult is it to fly the optimal trajectory found without a wake model, in a real momentum-conserving flow?"
- Your vertical AWE farm concept (99 dual-wing systems, 50 MW / 7 km²) and multi-rotor TRPT are solving the same problem — distributing aerodynamic load across vertically-stacked elements — under different mechanical constraints. Power density comparisons between the two architectures would interest both communities (and De Schutter's TransnetBW grid perspective).
- Our expansion rotor model currently has **no wake interaction at all** (downstream rotors see freestream) — disclosed limitation #2. Your model is the most direct fix in the literature.

## What each side brings

**Freiburg**: wake induction model, awebox optimal control framework.
**Windswept**: TRPT geometry, DE design vectors, multi-rotor campaign data, open-source 11-DoF simulator.

**Student option**: apply the multiple-wake vortex lattice method to KTD.jl's banked expansion rotor configurations; co-supervised by the Diehl group and Read.

## Honesty note

All KTD.jl results are confidence tier P (single model, zero hardware). Wake cross-validation moves the expansion rotor aerodynamics toward tier M. In-kind exchange only. Consortium funding pathways exist (formation window ~4 weeks); pipeline on request.
