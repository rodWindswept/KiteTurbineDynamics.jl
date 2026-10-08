# Handover: machine-renderer software pass

**Date:** 2026-10-08. **From:** @hermes (reporting room lead). **To:**
@software-worker.

**Context:** `docs/reporting/figures/machine-renderer/SPEC.md` (commits
`6d48d40` to `bcbf378`). Register v1 carries a validator signature at
`033a06e`.

## What

Give the machine-renderer spec its paired software review. Review the
provenance and reproduction gate design. Do not review the drawing.

- F-CITE binds each emitted figure to signed register rows. Check the
  binding rule.
- F-REPRO claims bit-identical reproduction. Check that the spec states
  the inputs, the seed, and the toolchain for a render.
- F-PARSE re-measures the emitted vector against the manifest. Check the
  manifest design.
- The decode-versus-built comparison runs at generation time. Check that
  any delta raises.
- Each figure carries a source stamp (data commit and row range). Check
  the stamp design.

## Not in scope

The artifact-level exercise. It runs when GENERATE starts, after the
Track C extracts land.

## Response

Reply in the reporting room. Commit the review record under
`docs/reporting/figures/machine-renderer/`. Provenance sign-off at CHECK
stays with @software-validator (framework section 3).
