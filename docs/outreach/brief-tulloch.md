# Collaboration Brief — Dr. Oliver Tulloch

**From**: Rod Read, Windswept & Interesting Ltd (rod@windswept.energy)
**To**: Dr. Oliver Tulloch
**Date**: July 2026 · **Ref**: KTD.jl Technical Report v0.2 (DOI pending)

## The proposal

An invitation, not a workload: review the model-lineage section of any resulting KTD.jl publication, and accept co-authorship if interested. Your spring-disc model is the ancestor of KTD.jl's multibody dynamics, and that should be documented by its originator.

## Where your work stands in KTD.jl

All of KTD.jl's physics traces to your thesis and the 2023 Energies paper:

- The **single-section moment-to-tension ratio** (MTR ≈ 0.05) is extended to per-section coupling derived from explicit ring geometry — the moment-to-tension relationship varies along a tapered ring profile.
- The **δα\* collapse criterion** is implemented dynamically as `collapse_margin = δα* − |Δα|`, currently verified healthy at 42–47° on the left-flank operating architecture.
- The **spring-disc formulation** underlies the 11-DoF multibody solver that now runs full dynamic verification on every optimised design.

Recent findings your model made possible: a large static–dynamic power gap (magnitude under re-baseline after a simulator audit), and a transmission loss that scales as ~ω³ with a design-independent coefficient — both discoverable only because the dynamic formulation you built exists to disagree with the statics.

## What we ask

Nothing beyond what interests you. Specifically on offer: review rights on the lineage section of any publication; co-authorship if you want it; and our citation of your work in every derived result, maintained as a standing commitment. We understand you now work in offshore wind and are no longer active in AWE — this brief exists so that the attribution is right regardless.

With gratitude and respect.
