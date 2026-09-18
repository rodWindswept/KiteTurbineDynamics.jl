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
    #
    # R7 (2026-09-10): CANONICAL 10-D genome.  The four free beam genes
    # (Do_top, t_over_D, beam_aspect, Do_scale_exp) are gone — the beam is
    # load-derived by size_beams_closed_form.
    geom_scale = sqrt(kw / 1.5)

    g = zeros(10)
    # r_hub — RE-SEED 2026-08-26: 2.4 m (was DAISY.r_hub·geom_scale = 2.775 m).
    # A 3-rotor co-axial stack needs a SMALLER per-rotor annulus than the
    # single-rotor Daisy scaling once the downstream wake de-rate is real
    # (hub + middle at 0.75× power): the 2.775 m seed makes only 4.37 kW under
    # blocking (reject).  Measured on the fixed evaluator (cold start, k=2.24,
    # honest window): r_hub 2.4 → P 5.12 kW, FoS 10.6, fitness 53.7 kg, and it
    # clears the geometrically-correct ground clearance with margin.
    g[1] = 2.4                          # r_hub
    g[2] = DAISY.r_bottom * geom_scale    # r_bottom
    g[3] = 1.5                            # target_Lr: ring spacing ratio (Tulloch L/r ≥ 1)
                                          # RE-SEED 2026-09-16 (Rod): 2.0 -> 1.5.  At 2.0 the
                                          # seed sits exactly ON the torsional realisability floor
                                          # (measured demand 0.9524 against the 1/1.05 = 0.9524
                                          # target, zero headroom), so the taut back line's tension
                                          # drop at design tips it past the cliff and the evaluator
                                          # reports twist_crossed = true.  L/r scales the floor
                                          # exactly with the chord: measured demand 1.147 -> 0.871
                                          # at 6 lines, for -0.3 % airborne mass (29.31 -> 29.22 kg),
                                          # because the closed-form ring sizing makes each ring
                                          # lighter as spans shorten.  Cost: 8 -> 12 rings.  See
                                          # docs/plans/ACTIVE.md item 2 and DECISIONS.md [2026-09-15].
    g[4] = seed_n_lines(kw)               # 6 at ≤5 kW (Daisy-proven)
    g[5] = 0.0                            # density_profile: uniform
    g[6] = 3.0                           # rotor count (rotor_count_mode): 3 co-axial top rotors.
                                          # The 08-25 "37.7 vs 59.4 kg single" rationale is void
                                          # (measured pre-FoS-fix); keep 3 for a multi-rotor seed
                                          # so the DE explores 1/2/3 from a safe start.
    g[7] = 0.0                           # bank_top
    g[8] = 0.0                           # bank_bottom
    g[9] = 0.7                           # blade_scale_top: 0.7 clears 5 kW on the 3-rotor stack
    g[10] = 0.7                          # blade_scale_bottom: same as top
    # RE-SEED PROPOSAL 2026-09-14 — NOT LANDED.  See
    # handovers/handover-2026-09-14-verified-state-reseed-boundary-and-priority-correction.md
    # section 6, and scratch/spec_seed_candidate.jl / scratch/diag_lift_line_switch.jl.
    #
    # A viable, mid-range, 3-rotor/6-line replacement was found and measured
    # through the campaign evaluator at the full 30 s window:
    #   [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]
    #   :ok, P_end 5.07 kW, P_mean 5.04 kW, FoS_min 3.59, no twist crossing,
    #   no line break, twist demand 0.789.  9 of its 10 genes are mid-range; only
    #   rotor_count sits at a bound, which is unavoidable ([1,3] and 3 is the
    #   deliberate architecture).  BANK = 11 degrees is DECIDED (Rod 2026-09-14);
    #   0 / 11 / 22 degrees were all measured viable, so it is not a trade-off.
    #
    # WHY IT CANNOT LAND YET.  With it the operational settle's bridle tension
    # collapses to 0.000 N.  Two explanations were tested and both are WRONG:
    #   * the lift-chain design constants are NOT radius-dependent — measured
    #     settled bearing offset 3.9898 m (r_hub 2.4) vs 3.9897 m (r_hub 2.6);
    #     the bearing hangs one cyan-length below the sky anchor, so r_hub does
    #     not enter.  Do not re-derive them per genome.
    #   * the lift line's hard on/off switch is NOT engaged either way — measured
    #     kite-to-sky distance ~8.99 m against a 24.75 m threshold, for BOTH this
    #     seed and the current one, and the current one's chain is taut anyway.
    # MEASURED CAUSE: the candidate's chain is healthy at 1000 relaxation steps
    # (bridle 646 N) and collapses between 1000 and 2000 steps (sky anchor drops
    # 0.25 m, bridle -> 0).  It is a LATE DIVERGENCE OF THE RELAXATION — i.e. the
    # settle places the machine and relaxes, it does not solve for equilibrium.
    # That is open item 1 of handover-2026-09-12 section 9.  The seed must wait
    # for the static equilibrium solver; do not land it before then.
    return g
end

function tight_bounds(seed, kw; do_min::Float64=0.03)
    # R7 (2026-09-10): canonical 10-D bounds.  `do_min` is retained for CLI
    # backward compatibility but is now inert (no Do_top gene).
    # Spread: ± fraction around seed for each dimension
    #   r_hub: wider spread (+80%) — Daisy 1.5kW has 1.52m, our 0.91m seed needs headroom
    #   target_Lr: lo=1.0 (Tulloch: L/r can be as high as 6; minimum ~1.0 for stability)
    #   bank angles: lo=0° (blades exactly in rotor plane)
    #   blade_scale: hi=1.0 (not 2.0) — too many weak-aero stalling turbines at scale>1
    sp = [0.80, 0.50, 0.40, 0.00,    # r_hub, r_bot, Lr, n_lines (handled below)
          1.0,                        # density: full range
          0.80, 0.80, 0.80, 0.80, 0.80]  # count, bank_t, bank_b, blade_t, blade_b

    lo = zeros(10); hi = zeros(10)
    for i in 1:10
        if i == 4
            # n_lines: [3, 9] (Rod 2026-09-02).  n_lines = 2 is flown-unstable;
            # the floor stays at 3 — a triangle is a valid polygon.  Ceiling 9
            # (was 16): no design need more than 9 lines at this scale.
            lo[i] = 3.0
            hi[i] = 9.0
        elseif i == 5
            lo[i] = -0.8; hi[i] = 0.8
        elseif i == 6
            # rotor count (rotor_count_mode): {1,2,3}
            lo[i] = 1.0; hi[i] = 3.0
        elseif i in (7, 8)
            # bank angles: 0° minimum, 22° maximum (Rod: >22° back-winds blades on slanted TRPT)
            lo[i] = 0.0
            hi[i] = 22.0
        elseif i in (9, 10)
            # blade scale: hi=1.0 (Rod: too many weak-aero stalling turbines above 1.0)
            lo[i] = max(0.05, seed[i] * (1.0 - sp[i]))
            hi[i] = 1.0
        elseif i == 3
            # target_Lr: lo=1.0 (Tulloch: L/r minimum for stable torque transmission)
            lo[i] = 1.0
            hi[i] = seed[i] * (1.0 + sp[i])
        else
            lo[i] = max(1e-6, seed[i] * (1.0 - sp[i]))
            hi[i] = seed[i] * (1.0 + sp[i])
        end
    end

    # Physical minima & overrides
    # r_hub lo=0.7 (Rod 2026-08-14): the DE repeatedly exploited tiny hubs
    # (0.47/0.67m winners diverged the hub ring to ω~1e66-1e86). τ_cap ∝ r_min²;
    # Daisy 1.5kW had r_hub=1.52m. Seed is 0.914m. hi ≥ 2.2 unchanged.
    lo[1] = max(lo[1], 0.7); hi[1] = max(hi[1], 2.2)
    lo[2] = max(lo[2], 0.1)

    for i in 1:10
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
    n_bad = count(i -> seed[i] < lo[i] || seed[i] > hi[i], 1:10)
    
    # Compute Daisy-scaled r_hub for comparison
    daisy_r_hub_scaled = DAISY.r_hub * sqrt(kw / 1.5)
    
    println("── $kw kW  (geom_scale=$(round(sqrt(kw/50), digits=3)), Daisy-scaled r_hub=$(round(daisy_r_hub_scaled, digits=2))m) ──")
    println("  n_lines seed = $(Int(seed[4]))  (bounds [$(Int(lo[4])), $(Int(hi[4]))])")
    println("  r_hub   seed = $(round(seed[1], digits=3)) m")
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
