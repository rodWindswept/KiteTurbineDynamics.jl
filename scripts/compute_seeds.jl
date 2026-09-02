#!/usr/bin/env julia --project=.
#=
compute_seeds.jl — Seeds and tight bounds for graduated DE ladder.
Bounds informed by Daisy 1.5kW (n_lines=6, r_hub=1.52m, tether=10.3m)
and V10 50kW campaign structural proportions.

Usage: julia --project=. scripts/compute_seeds.jl
=#

using KiteTurbineDynamics

# Daisy 1.5kW reference (Tulloch Config 8):
#   r_hub=1.52m, tether=10.31m, n_lines=6, n_rings=3, n_blades=3
#   trpt_rL=0.356, elevation=28°, peak~1.4kW@8m/s

const DAISY = (r_hub=1.52, tether=10.31, n_lines=6, r_bottom=0.315)

# V10 50kW campaign best genome (structural proportions only — aero eval was broken)
const V10_50KW = [
    0.060, 0.01, 0.880, 1.0,     # Do_top, t_over_D, beam_aspect, Do_scale_exp
    2.889, 2.0, 2.988, 13.0,     # r_hub, r_bottom, target_Lr, n_lines (rounded)
    -0.11,                        # density_profile
    18.56, 15.0, 15.0, 0.519, 0.1,  # mask, bank_t, bank_b, λ_t, λ_b (banks 0-22° per Rod)
]

const RUNGS = [5.0, 7.0, 10.0, 15.0, 25.0, 35.0, 50.0]

# Single source of truth for the 5 kW campaign operating point (2026-08-24).
# Honest-window k sweep 2026-08-22 (scripts/results/k_sweep_daisy_5kw.csv):
# 6-blade Daisy anchor scaled 0.175·(5/1.5)^2.5.  EVERY k_mppt consumer
# (runner, smoke, gate, analysis tools) MUST read this constant — local
# literals drifted twice (trust-log 2026-08-13 k=10.0 row; 2026-08-24
# stale-k=5.39 gate row).
const K_MPPT_5KW_HONEST = 2.24

# Single source of truth for co-axial wake blocking (2026-08-26, Rod).
# Downstream (upper) rotors produce 0.75× freestream power; P ∝ v³, so the
# inflow multiplier is 0.75^(1/3) ≈ 0.9086.  Threaded as the per-rotor
# wind_factor from the decode into the ODE (src/ring_forces.jl), so the
# de-rate is real, not a sizing-only placeholder.
const BLOCKING_WIND_FACTOR_5KW = 0.75^(1 / 3)

function seed_n_lines(kw::Float64)::Float64
    # Daisy: 6 lines at 1.5kW → extrapolate to target scale
    # Conservative: fewer lines at small scale (less load sharing needed)
    if kw <= 5.0
        return 6.0   # Daisy-proven at small scale
    elseif kw <= 7.0
        return 7.0
    elseif kw <= 10.0
        return 8.0   # v5 10kW optimum
    elseif kw <= 15.0
        return 10.0
    elseif kw <= 25.0
        return 12.0
    else
        return 13.0   # V10 50kW sweet spot
    end
end

function seed_genome(kw)
    # Daisy-up scaling (Rod 2026-08-20): anchor on the MEASURED 1.5 kW Daisy
    # (config 8: r_hub 1.52 m, r_bottom 0.315 m, tether 10.31 m, 6 lines,
    # 3 blades, solidity 7.5%, NACA 4412, ~12 mm carbon rod ring) — NOT the
    # 50 kW V10 winner.  Scale UP by sqrt(kw/1.5).  blade_scale = 1.0 is the
    # Daisy's full-span reference (span ∝ blade_scale).
    geom_scale = sqrt(kw / 1.5)

    g = zeros(14)
    g[1] = 0.08                          # Do_top: RE-SEED 2026-09-02 (was 0.06).  Under the
                                          # corrected mass model the 0.06 seed's higher lift
                                          # tension drops FoS to 5.19; 0.08 restores a comfortable
                                          # FoS 7.2 (Rod: "less fit, more safe" seed — heavier
                                          # but safer).  The DE can tune Do back down from here.
    g[2] = 0.055                          # t_over_D: 0.5 mm wall on ~9 mm rod (Daisy blades)
    g[3] = 1.0                            # beam_aspect: circular
    g[4] = 1.0                            # Do_scale_exp: uniform tube
    # r_hub — RE-SEED 2026-08-26: 2.4 m (was DAISY.r_hub·geom_scale = 2.775 m).
    # A 3-rotor co-axial stack needs a SMALLER per-rotor annulus than the
    # single-rotor Daisy scaling once the downstream wake de-rate is real
    # (hub + middle at 0.75× power): the 2.775 m seed makes only 4.37 kW under
    # blocking (reject).  Measured on the fixed evaluator (cold start, k=2.24,
    # honest window): r_hub 2.4 → P 5.12 kW, FoS 10.6, fitness 53.7 kg, and it
    # clears the geometrically-correct ground clearance with margin.
    g[5] = 2.4                          # r_hub
    g[6] = DAISY.r_bottom * geom_scale    # r_bottom
    g[7] = 2.0                            # target_Lr: ring spacing ratio (Tulloch L/r ≥ 1)
    g[8] = seed_n_lines(kw)               # 6 at ≤5 kW (Daisy-proven)
    g[9] = 0.0                            # density_profile: uniform
    g[10] = 3.0                           # rotor count (rotor_count_mode): 3 co-axial top rotors.
                                          # The 08-25 "37.7 vs 59.4 kg single" rationale is void
                                          # (measured pre-FoS-fix); keep 3 for a multi-rotor seed
                                          # so the DE explores 1/2/3 from a safe start.
    g[11] = 0.0                           # bank_top
    g[12] = 0.0                           # bank_bottom
    g[13] = 0.7                           # blade_scale_top: 0.7 clears 5 kW on the 3-rotor stack
    g[14] = 0.7                           # blade_scale_bottom: same as top
    return g
end

function tight_bounds(seed, kw)
    # Spread: ± fraction around seed for each dimension
    # Corrections per Rod 2026-08-12:
    #   r_hub: wider spread (+80%) — Daisy 1.5kW has 1.52m, our 0.91m seed needs headroom
    #   target_Lr: lo=1.0 (Tulloch: L/r can be as high as 6; minimum ~1.0 for stability)
    #   bank angles: lo=0° (blades exactly in rotor plane)
    #   blade_scale: hi=1.0 (not 2.0) — too many weak-aero stalling turbines at scale>1
    #   blade_scale_bottom: same hi as blade_scale_top — no tight ceiling
    sp = [0.50, 0.50, 0.50, 0.60,    # Do_top, t/D, aspect, taper_exp
          0.80, 0.50, 0.40, 0.00,    # r_hub, r_bot, Lr, n_lines (handled below)
          1.0,                        # density: full range
          0.80, 0.80, 0.80, 0.80, 0.80]  # count, bank_t, bank_b, blade_t, blade_b
    
    lo = zeros(14); hi = zeros(14)
    for i in 1:14
        if i == 8
            # n_lines: canonical range, floored at 4 (2026-09-02, Rod).  A 3-line
            # "triangle" TRPT is a degenerate polygon (and 2 lines are flown-
            # unstable); the polygon-buckling model is only valid ≥ 4 sides.  The
            # 08-28 winner exploited n_lines = 3.  Floor 4, ceiling 16 unchanged.
            lo[i] = 4.0
            hi[i] = 16.0
        elseif i == 9
            lo[i] = -0.8; hi[i] = 0.8
        elseif i == 10
            # rotor count (rotor_count_mode): {1,2,3}
            lo[i] = 1.0; hi[i] = 3.0
        elseif i in (11, 12)
            # bank angles: 0° minimum, 22° maximum (Rod: >22° back-winds blades on slanted TRPT)
            lo[i] = 0.0
            hi[i] = 22.0
        elseif i in (13, 14)
            # blade scale: hi=1.0 (Rod: too many weak-aero stalling turbines above 1.0)
            lo[i] = max(0.05, seed[i] * (1.0 - sp[i]))
            hi[i] = 1.0
        elseif i == 7
            # target_Lr: lo=1.0 (Tulloch: L/r minimum for stable torque transmission)
            lo[i] = 1.0
            hi[i] = seed[i] * (1.0 + sp[i])
        else
            lo[i] = max(1e-6, seed[i] * (1.0 - sp[i]))
            hi[i] = seed[i] * (1.0 + sp[i])
        end
    end
    
    # Physical minima & overrides
    lo[1] = max(lo[1], 0.005)
    # t_over_D floor 0.010 (Rod 2026-08-14): the v13 18m winner parked at
    # 0.005 → 0.14 mm tube walls → 58 g rings flung by 5.7 kN rotor thrust.
    # The floor is the SEED's own value — no thinner than the starting design.
    lo[2] = max(lo[2], 0.010)
    # r_hub lo=0.7 (Rod 2026-08-14): the DE repeatedly exploited tiny hubs
    # (0.47/0.67m winners diverged the hub ring to ω~1e66-1e86). τ_cap ∝ r_min²;
    # Daisy 1.5kW had r_hub=1.52m. Seed is 0.914m. hi ≥ 2.2 unchanged.
    lo[5] = max(lo[5], 0.7); hi[5] = max(hi[5], 2.2)
    lo[6] = max(lo[6], 0.1)
    
    for i in 1:14
        if lo[i] >= hi[i]; lo[i] = hi[i] * 0.5; end
    end
    
    return lo, hi
end

if abspath(PROGRAM_FILE) == @__FILE__
println("=== Seeds & Tight Bounds ===\n")
println("Reference: Daisy 1.5kW  r_hub=$(DAISY.r_hub)m  tether=$(DAISY.tether)m  n_lines=$(DAISY.n_lines)")
println("           V10 50kW     r_hub=$(V10_50KW[5])m  n_lines=$(Int(V10_50KW[8]))\n")

for kw in RUNGS
    seed = seed_genome(kw)
    lo, hi = tight_bounds(seed, kw)
    bad = findall(lo .>= hi)
    n_bad = count(i -> seed[i] < lo[i] || seed[i] > hi[i], 1:14)
    
    # Compute Daisy-scaled r_hub for comparison
    daisy_r_hub_scaled = DAISY.r_hub * sqrt(kw / 1.5)
    
    println("── $kw kW  (geom_scale=$(round(sqrt(kw/50), digits=3)), Daisy-scaled r_hub=$(round(daisy_r_hub_scaled, digits=2))m) ──")
    println("  n_lines seed = $(Int(seed[8]))  (bounds [$(Int(lo[8])), $(Int(hi[8]))])")
    println("  r_hub   seed = $(round(seed[5], digits=3)) m")
    println("  seed = [", join(round.(seed, digits=4), ", "), "]")
    println("  lo   = [", join(round.(lo, digits=4), ", "), "]")
    println("  hi   = [", join(round.(hi, digits=4), ", "), "]")
    isempty(bad) || println("  ❌ BAD BOUNDS: ", bad)
    n_bad > 0 ? println("  ⚠️  $n_bad seed vals out of bounds") : println("  ✅ all seed vals in bounds")
    println()
end

println("=== DE size per rung ===")
for kw in RUNGS
    s = kw <= 10 ? "30×5, 100 gen" : kw <= 25 ? "40×8, 200 gen" :
        kw <= 35 ? "60×12, 500 gen" : "80×20, 2000 gen"
    println("  $kw kW → $s")
end

println("\n=== ObjectiveConfig ===")
for kw in RUNGS
    println("  $kw kW: power_W=$(Int(kw*1000))  p_floor=$(kw*0.5)kW  p_ceiling=$(kw)kW")
end
end  # if abspath(PROGRAM_FILE) == @__FILE__
