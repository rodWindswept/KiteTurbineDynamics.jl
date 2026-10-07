#!/usr/bin/env julia --project=.
#=
bounds_audit.jl — Full bounds audit for each power rung (R7 canonical 10-D).
Prints every dimension with seed, bounds, physical interpretation, and the
relative derivation (spread % around the seed).  Read-only.

2026-10-05: fixed to the canonical 10-D genome — the previous version was
pre-R7 14-D and crashed at HEAD (BoundsError at index 11).  For the ≤5 kW rung
it prints the S2-class fold box: r_hub [0.7, 7.776] (lo pinned at the absolute
floor 0.7, decoupled; hi = 1.8·s₁ fold-re-centred).  See S2_FOLD_SEED and the
tight_bounds override block in compute_seeds.jl for provenance.

Usage: scripts/ktd-julia scripts/bounds_audit.jl
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const DIM_NAMES = [
    "r_hub (m)", "r_bottom (m)", "target_Lr", "n_lines",
    "density_profile", "rotor_count", "bank_top (°)", "bank_bottom (°)",
    "blade_scale_top", "blade_scale_bottom",
]

const DIM_NOTES = [
    "Hub ring radius. Daisy: 1.52m at 1.5kW. ≤5kW seed = S2 fold 4.32m; hi = 1.8·s₁ (7.776); lo pinned at the absolute 0.7 floor (decoupled).",
    "Ground ring radius. Must be ≤ r_hub. Daisy: 0.315m.",
    "Target ring spacing ratio L/r. lo = 1.0 (Tulloch minimum for stability).",
    "Number of TRPT lines [3, 9] (Rod 2026-09-02; n_lines=2 flown-unstable).",
    "Ring density bias along shaft. ±0.8 range.",
    "Rotor count {1,2,3} (rotor_count_mode; decoded by rounding).",
    "Bank angle at hub ring [0, 22] (Rod: >22° back-winds blades on slanted TRPT).",
    "Bank angle at ground ring [0, 22].",
    "Blade scale at hub. hi = 1.0 fixed (stall cap, not seed-relative); lo = max(0.05, 0.2·s₉).",
    "Blade scale at ground. Same law as hub.",
]

function audit()
    for kw in RUNGS
        seed = seed_genome(kw)
        lo, hi = tight_bounds(seed, kw)
        geom_scale = sqrt(kw / 50.0)

        println("═"^80)
        println("  $kw kW  —  geom_scale = $(round(geom_scale, digits=3))")
        println("═"^80)

        # Daisy cross-ref (reference only for rungs with their own seed scheme)
        daisy_r = DAISY.r_hub * sqrt(kw / 1.5)
        src = kw <= 5.0 ? "S2-class fold seed" : "Daisy-up scaled seed"
        println("  seed source: $src")
        println("  Daisy-scaled reference: r_hub≈$(round(daisy_r, digits=2))m, n_lines=$(Int(DAISY.n_lines))")
        println()

        for i in 1:length(DIM_NAMES)
            s = seed[i]; l = lo[i]; h = hi[i]
            span = h - l
            pct_lo = s > 1e-9 ? round(100*(s-l)/s, digits=1) : 0.0
            pct_hi = s > 1e-9 ? round(100*(h-s)/s, digits=1) : 0.0

            # Flag potential issues
            flags = String[]
            if l >= h
                push!(flags, "❌ lo≥hi")
            end
            if s < l || s > h
                push!(flags, "⚠️ seed OOB")
            end
            if i == 2 && l > seed[1]  # r_bottom lo > r_hub seed (taper inversion)
                push!(flags, "⚠️ r_bot lo > r_hub")
            end

            flag_str = isempty(flags) ? "" : "  " * join(flags, " ")

            @printf("  [%2d] %-18s  seed=%8.4f  [%8.4f, %8.4f]  span=%.4f  %+5.0f%%/%+5.0f%%%s\n",
                i, DIM_NAMES[i], s, l, h, span,
                -pct_lo, pct_hi, flag_str)
        end
        println()
    end

    println("═"^80)
    println("  Dimension notes")
    println("═"^80)
    for (i, note) in enumerate(DIM_NOTES)
        @printf("  [%2d] %-18s %s\n", i, DIM_NAMES[i], note)
    end
end

audit()
