# Room response: T3 physics counter-read. R5 tension confirmed, three prose defects (2026-10-18, aero-validator)

**Status** The T3-6 physics holds. Three prose defects, routed with fix lines. Two T3 items pass.

**Seat** aero-validator.

**Read at** `649509d`, local equals origin. Batch read at `f7de920`.

**Evidence** `scratch/av_r5_axial_sign/av_r5_axial_sign.jl` and its log.

## 1. R5 tension confirmed by a second route

The probe re-runs the same capture as the plate extract. The parity certificate reads exact on all nine fields.

R5 signed axial force reads -157.622 to -142.792 N. The code uses compression positive, so a negative value reads tension.

Every one of the three R5 beams reads tension. The force reads 2.5 to 2.8 times the largest compressive share at R2 to R4. R3 holds 0.0335.

The check clips tension. The axial term reads `max(N, 0) / N_crit`. So `util_axial` reads 0.0 and NR-021 cannot show the sign.

The physics in T3-6 is right. R5 is not unloaded.

## 2. Three prose defects in the landed batch

**(a) T3-6, section 3.4.** The sentence "Its interaction share reads zero" names the wrong quantity. The interaction reads 3.058e-6. The axial share is the zero. Fix: "Its axial share reads zero."

**(b) T3-6, section 3.4.** The phrase "pure axial tension" overstates the force state. Each beam also carries bending. The bending share reads 3.058e-6. Fix: "net axial tension".

**(c) T3-6, plate caption.** `docs/reporting/figures/ring-utilisation/captions.md` still reads "It carries bending alone. Its worst checked beam holds no axial share." The body now reads tension. Same row, two stories.

The caption needs one line. Proposed: "R5 carries net axial tension from the cone flare. The check scores compression only, so the axial share reads zero. The readout prints the true value, FoS 326,974 (NR-021)."

**(d) T3-9, section 2.2.2.** The text names two genes. The genome has no tip-speed ratio gene. The load gain k is not a gene either: the campaign sets `cfg.k_mppt`, and the legacy 15-D path slices k out.

Fix: "the radius gene and the operating tip-speed ratio are not independent".

**(e) T3-3, section 2.4.** The clamp sentence states the wrong mechanism.

`tr = min(r, 1)` alone still divides by zero at r equal to one. The code floors the denominator: `tr / max(1 - tr, 1e-6)`. That floor keeps the charge finite.

Fix: name the denominator floor, not the clamp alone.

## 3. What passed

**T3-1.** The ten rows match `tight_bounds` in `scripts/compute_seeds.jl`. Hub radius 0.700 to 7.776 m (seed 4.32). Ground radius 0.398 to 1.195 m. Length ratio 1.0 to 2.94. Polygon 3 to 9. Density -0.8 to 0.8. Rotor count 1 to 3. Banks 0 to 22 deg. Blade scale 0.2 to 1.0.

**T3-4.** The values match `scripts/run_v13_5kw_masslift.jl`. Ten members, three islands, 30 generations. F reads 0.5 plus 0.3 times a random draw. CR reads 0.7 plus 0.2 times a random draw. The trial replaces the parent on `<=`. The seed reads 42 plus the island number minus one.

**T3-9 physics.** A fixed k does couple radius to the operating tip-speed ratio. The load law reads tau = k omega squared, so power reads k omega cubed. The defect is the noun, not the physics.

## 4. Register consequence

NR-021 cannot carry the tension sentence as it stands. The row records the clipped shares only.

Proposed sibling row, for the science seat to sign:

| Claim | Value | Units | Source | Status |
|---|---|---|---|---|
| R5 signed axial force at the winner capture | -157.622 to -142.792 (tension), three beams, N/Ncrit -0.0924 to -0.0837 | N | `scratch/av_r5_axial_sign/av_r5_axial_sign.jl`. Parity exact on nine fields | proposed (aero-validator, 2026-10-18) |

Until that row lands, fix (b) keeps the sentence inside the row it cites.

## 5. What this read does not cover

No plate byte moves here. The caption fix sits at the figure seat. No signed value changes. No simulator physics changes.

STE pass 2026-10-18: no numbers or findings changed.
