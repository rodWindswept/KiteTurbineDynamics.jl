# Collaboration Brief — University of Strathclyde, Wind Energy & Control Centre

**From**: Rod Read, Windswept & Interesting Ltd (rod@windswept.energy)
**To**: Wind Energy & Control Centre (Yue, Chen, Amjad, Carroll)
**Date**: July 2026 · **Ref**: KTD.jl Technical Report v0.2 (DOI pending)

## The proposal

A joint paper cross-validating Strathclyde's QBlade LLFVW aerodynamics against KTD.jl's 11-DoF multibody ODE solver at matched power scales (12–50 kW) — **the first multi-fidelity TRPT validation in the literature**.

## Why you, why now

Your group holds the most complete published TRPT modelling framework. Two of your AWEC 2026 results connect directly to our open questions:

- **Chen's 86.33% transmission efficiency and 89% top-segment torque-loss concentration** — our dynamic simulator independently finds transmission loss scaling as ~ω³ with a design-independent coefficient (quadratic drag torque on the rotating shaft). Whether your steady-state loss distribution and our dynamic loss law describe the same mechanism is a well-posed, publishable question.
- **Amjad's "wide-and-short" geometric prescription** — our DE optimiser converges on the same geometry independently. Your parametric intuition, validated by our 14-variable optimisation, strengthens both.

The natural next question after your steady-state work: what happens to those configurations under full multibody dynamics? Our simulator's central (re-baseline-pending) finding is a large static–dynamic power gap; your models are the right benchmark to bound it.

## What each side brings

**Strathclyde**: QBlade aerodynamic analysis of KTD expansion rotor geometries; steady-state TRPT model for comparison.
**Windswept**: KTD.jl ODE solver (open-source, MIT), DE design vectors, multi-rotor campaign data, full decision log (`DECISIONS.md`).

**Target venue**: *Wind Energy Science* or AWEC 2027.
**Student option**: co-supervised MSc applying QBlade to KTD.jl expansion rotor configurations — we provide geometry, you provide aerodynamic analysis.

## Honesty note

Every KTD.jl result is currently confidence tier P (single model, unvalidated, zero hardware). Cross-validation with your toolchain is precisely what moves results to tier M. In-kind exchange only — no cash contribution requested. Funding pathways for dedicated researcher time exist (consortium formation window ~4 weeks); pipeline available on request.
