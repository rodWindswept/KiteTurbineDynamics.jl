#!/usr/bin/env julia --project=.
#=
bounds_audit.jl — Full 14-dimension bounds audit for each power rung.
Prints every dimension with seed, bounds, physical interpretation, and
cross-reference against Daisy 1.5kW where applicable.

Usage: julia --project=. scripts/bounds_audit.jl
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const DIM_NAMES = [
    "Do_top (m)", "t_over_D", "beam_aspect", "Do_scale_exp",
    "r_hub (m)", "r_bottom (m)", "target_Lr", "n_lines",
    "density_profile", "rotor_mask", "bank_top (°)", "bank_bottom (°)",
    "blade_scale_top", "blade_scale_bottom"
]

const DIM_NOTES = [
    "Ring outer diameter at hub. Daisy: 4mm CF rods. V10 50kW: 60mm at 2.89m hub.",
    "Wall thickness / Do_top. 0.01 = 1% wall. CFRP tube: 0.005-0.03 typical.",
    "Ring beam aspect ratio. 0.88 = moderately slender. 0.3-2.0 covers stocky→slender.",
    "Taper exponent for Do(r). 1.0 = linear. 0.5 = √R law. 0.3-1.5 covers both.",
    "Hub ring radius. Daisy: 1.52m at 1.5kW. V10 50kW: 2.89m. Scales ~√P.",
    "Ground ring radius. Must be ≤ r_hub. Daisy: 0.315m. V10 50kW: 2.0m.",
    "Target ring spacing ratio L/r. 2.99 = rings spaced ~3× radius. 0.5-5.0 wide.",
    "Number of TRPT lines. Daisy: 6 at 1.5kW. v5 10kW: 8. V10 50kW: 13. [3,16].",
    "Ring density bias along shaft. -0.11 = slightly biased toward hub. ±0.8 range.",
    "Rotor placement mask. Encodes which rings get expansion rotors. 0-N_VALID_MASKS.",
    "Bank angle at hub ring. 32° from V10 50kW. 0-45° range. Scales with elevation?",
    "Bank angle at ground ring. 35° from V10 50kW. 0-45° range.",
    "Blade scale at hub. 0.519 = 52% of reference blade. 0.05-2.0. Aero scaling knob.",
    "Blade scale at ground. 0.1 = minimal blades at bottom. 0.05-2.0.",
]

function audit()
    for kw in RUNGS
        seed = seed_genome(kw)
        lo, hi = tight_bounds(seed, kw)
        geom_scale = sqrt(kw / 50.0)
        
        println("═"^80)
        println("  $kw kW  —  geom_scale = $(round(geom_scale, digits=3))")
        println("═"^80)
        
        # Daisy cross-ref
        daisy_r = DAISY.r_hub * sqrt(kw / 1.5)
        println("  Daisy-scaled: r_hub≈$(round(daisy_r, digits=2))m, n_lines=$(DAISY.n_lines)")
        println()
        
        for i in 1:14
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
            if i == 6 && l > seed[5]  # r_bottom lo > r_hub
                push!(flags, "⚠️ r_bot lo > r_hub")
            end
            if i == 5 && l < 0.1  # r_hub unreasonably small
                push!(flags, "⚠️ tiny r_hub")
            end
            if i == 1 && h < 0.005  # Do_top too small
                push!(flags, "⚠️ tiny Do_top")
            end
            
            flag_str = isempty(flags) ? "" : "  " * join(flags, " ")
            
            @printf("  [%2d] %-16s  seed=%8.4f  [%8.4f, %8.4f]  span=%.4f  %+5.0f%%/%+5.0f%%%s\n",
                i, DIM_NAMES[i], s, l, h, span,
                -pct_lo, pct_hi, flag_str)
        end
        println()
    end
end

audit()
