# Plan — Genome Form Browser (3D structure reviewer)

Status: PROPOSED for implementation
Date: 2026-08-20
Owner: Hermes (lead) · Worker: software-worker · Gate: software-validator
Reference: `TODO_ADVANCED_VISUALS.md` items #2, #5

## Goal

An interactive GLMakie desktop app that decodes any genome from a V13 5 kW
campaign telemetry CSV and renders its 3D structure, with the genome's scores
beside it, and prev/next navigation across the campaign set. Purpose: review
the visual form a builder produced and compare it to that genome's scores.

## Reference input

`scripts/results/v13_5kw_len{18.0,21.2,25.0}/telemetry.csv`

Header comment line carries `length=`, `era=`, `git=`. Columns include:
`island,gen,idx,fitness,status,P_mean,P_end,FoS,twist_crossed,
clearance,n_lines,rings,n_active,r_hub,r_bot,bank_top,bank_bot,lam_top,
lam_bot,tether,x1..x14`

NOTE (2026-08-20): the v13_5kw_len* telemetry CSVs were produced by
`run_v13_5kw.jl`, which does NOT emit a `T_lift` column. `T_lift` exists only
in `run_v13_5kw_masslift.jl` output, and those `v13_5kw_masslift_len*`
directories do not exist yet. The browser must show `T_lift` when the column
is present and `n/a` otherwise.

The 14-dim genome is `x1..x14`. There is NO k in the genome (removed 2026-08-09).

## Decode / build API (ground truth)

From `scripts/run_v13_5kw_masslift.jl` and `src/objective_evaluator.jl`:

```julia
p_base = params_at_length(LENGTH)          # length-specific params
beam_profile = PROFILE_ELLIPTICAL
dec = design_from_vector_v10(x, beam_profile, p_base; power_W=5000.0)
# x[8] rounded to Int in 3:16; x[10] clamped to 0:N_VALID_MASKS (see eval_v13)
sys, u0, pc = build_system_from_v10(dec, 1.0, p_base.k_mppt)   # for Part B only
```

For Part A the form comes from `dec` alone: `dec.design` (n_lines, n_rings,
r_hub, r_bottom, target_Lr, density_profile), `dec.zs` (ring z positions),
`dec.rotors` (ring_idx, bank_angle_deg, blade_tip_radius, blade_hub_radius,
blade_chord). Ring radii come from `ring_spacing_v4(...)` exactly as
`build_system_from_v10` calls it.

## Existing code to reuse

- `scripts/render_winners_clean.jl` — the ring/tether/knuckle render pattern
  (polygon edges via `lines!`, tethers, knuckle `scatter!`, viridis Do-colour).
  Reuse the drawing pattern; do NOT reuse the V2 `TRPTDesignV2` design type.
- `scripts/view_genome.jl` — the intent (decode → build → show), but it is a
  stale stub (15-dim genome, k in x[15]) that only prints text. Replace, do not
  extend in place.
- `scripts/export_interactive_html.jl` — WGLMakie HTML export (out of scope,
  but shows the Axis3 pattern).

## Deliverable

One new script `scripts/view_campaign_genomes.jl` (name may vary) that:

1. Takes a telemetry CSV path (and optional genome-hash filter) as argv.
2. Loads rows with `CSV.read(..., comment="#")`.
3. On load (or nav), decodes the current row's `x1..x14` via
   `design_from_vector_v10`.
4. Renders the 3D form in a GLMakie `Figure` + `Axis3`:
   - ring polygons (n_lines-gon per ring, at ring radii + z)
   - vertical tethers (same vertex index across rings)
   - knuckle vertices
   - expansion rotors (blade discs at ring_idx, banked, blade tip radius)
5. Shows a score panel beside the viewport: P_mean, FoS, T_lift, fitness,
   status, clearance, twist_crossed, n_lines, n_active, n_rings, island/gen/idx.
6. Provides prev/next navigation across the CSV rows (keys or buttons).
7. Can save a headless PNG of the current genome (GKSwstype=nul fallback)
   for agent-side verification.

## Acceptance tests (validator gates these)

- AC1 — `julia --project=. -e 'using KiteTurbineDynamics'` compiles; the new
  script runs headless (PNG mode) without error.
- AC2 — decodes a 14-dim genome from a real v13_5kw telemetry.csv row. No
  reference to a 15th genome dim or `10.0^x[15]` anywhere in the new code.
- AC3 — geometry is numerically correct for the decoded row: ring count =
  `dec.n_rings`, vertices per ring = `dec.design.n_lines`, ring radii match
  `ring_spacing_v4` output, rotor count = `dec.n_active`.
- AC4 — saves a headless PNG of at least one genome; PNG file exists and is
  non-empty. This is the agent-side verifiable artifact (visual HITL is Rod's).
- AC5 — navigation works: stepping prev/next over the CSV yields distinct
  genome hashes / decoded geometries (log the loaded row per step).
- AC6 — the score panel values for a loaded row equal that row's CSV fields
  (P_mean, FoS, fitness, status, clearance, twist_crossed). T_lift is shown
  when the column exists and `n/a` otherwise (see NOTE above).
- AC7 — no physics change: does not touch `src/` physics files, does not alter
  decode/build behaviour, does not change campaign CSVs. Pure read + render.

## Constraints

- GLMakie desktop, not WGLMakie/Bonito (Part A decision).
- Do NOT reuse the V2 design type or the stale 15-dim genome path.
- SI units; angles in degrees at the API boundary.
- JuliaFormatter Blue style before commit.
- Out of scope: Part B (dashboard injection), WGLMakie HTML export, the
  feasibility-cloud / voxel render (TODO items #2/#5 broader work).

## Definition of done

AC1–AC7 pass, one PNG artifact produced, script committed with a clean
`julia --project=. test/runtests.jl` suite (no red suite introduced).
