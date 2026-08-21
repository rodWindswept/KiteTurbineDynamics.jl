#!/usr/bin/env julia
# scripts/run_v13_5kw_masslift.jl
#
# 5kW mass-aware lift REDO on the V13 evaluator (2026-08-19).
# Identical to run_v13_5kw.jl (first campaign, fixed-rotary regime) in every
# respect EXCEPT the lift device:
#   - lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED,
#                        const_tension=true)
#     → lift-line tension = 1.5 × m_airborne × g / sin(70°) PER GENOME,
#       flat at all wind speeds (modulated lifter, Rod 2026-08-18).
#   - Telemetry gains a T_lift column (the first runner dropped it).
#   - New output dirs (v13_5kw_masslift_lenX), physics-era tag + launch
#     provenance note naming this the mass-aware constant-tension regime.
#
# Baseline for comparison: v13_5kw_lenX (fixed-rotary regime) + its
# lift_tension_retrospective.csv.
#
# Plan:      docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md
# Proposal:  docs/plans/2026-08-13-evaluator-v13-realistic-ktd.md
# Acceptance: test/test_evaluator_v13.jl (B1-B5), test/test_lift_kite_stacked.jl
# Model era: post-428f491_mass-aware-const-tension_ON
#
# Usage: julia --project=. scripts/run_v13_5kw_masslift.jl --length 21.2

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, DataFrames, CSV, Random, Statistics
include(joinpath(@__DIR__, "compute_seeds.jl"))

# ── CLI ─────────────────────────────────────────────────────────────────
function parse_length_arg()
    L = 18.8   # Daisy-up 5 kW length: 10.31 m × √(5/1.5) (Rod 2026-08-20)
    for (i, a) in enumerate(ARGS)
        if a == "--length" && i < length(ARGS)
            L = parse(Float64, ARGS[i+1])
        end
    end
    return L
end
const LENGTH = parse_length_arg()

const KW = 5.0
const PW = KW * 1000.0
const ELEV = π / 6
const V_RATED = 11.0
const GROUND_OFFSET = 1.0
const MIN_CLEARANCE = 1.5   # m — hard gate on lowest active rotor tip
const WINDOW_S = 20.0       # measurement window (sustained power + twist detector)

# ── Provenance (Daisy-anchored, mass-aware constant-tension regime) ──────
const PHYSICS_ERA = "post-4ce9fd0_daisy-anchored-5kw"
const GIT_HASH = try
    read(chomp, `git rev-parse HEAD`)
catch
    "unknown"
end

# Mass-aware constant-tension lifter — THE regime change from the first campaign.
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

const OUT_DIR = joinpath(@__DIR__, "results", "v13_5kw_masslift_len$(LENGTH)")
mkpath(OUT_DIR)

# ── Launch provenance note ──────────────────────────────────────────────
open(joinpath(OUT_DIR, "PROVENANCE.md"), "w") do io
    println(io, "# PROVENANCE — v13_5kw_masslift_len$(LENGTH)")
    println(io)
    println(io, "- **Campaign:** 5 kW v13 DE, mass-aware constant-tension lift REDO")
    println(io, "- **Runner:** scripts/run_v13_5kw_masslift.jl")
    println(io, "- **Physics era:** $(PHYSICS_ERA)  (2026-08-21: Daisy-anchored base params, r_bottom clamp fix, lifter mass excluded from tension, annulus-aligned Betz gates)")
    println(io, "- **Launch git HEAD:** $(GIT_HASH)")
    println(io, "- **Regime:** `lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)`")
    println(io, "  — vertical lift = 1.5 × m_airborne × g, m_airborne = expansion_airborne_mass(sys, p;")
    println(io, "  include_lifter=false) per genome (lifter's own mass does NOT drive the tension,")
    println(io, "  Rod 2026-08-21); line tension = F_vert / sin(70°), FLAT at all wind speeds")
    println(io, "  (modulated lifter, no v² scaling).")
    println(io, "- **Base params:** params_daisy() (measured Tulloch anchor) scaled 1.5 → 5 kW via mass_scale.")
    println(io, "- **Baseline (fixed-rotary regime):** scripts/results/v13_5kw_len$(LENGTH)/")
    println(io, "  + lift_tension_retrospective.csv (rotary_lifter_default(), wind-dependent tension)")
    println(io, "- **Identical to first campaign:** seeds (seed_genome(5.0)), RNG (Random.seed!(42+island-1)),")
    println(io, "  tight bounds, v13 ObjectiveConfig (tail5, no ceiling penalty, FoS 1.5/1.5,")
    println(io, "  kickstart 0, k_mppt = p.k_mppt), length $(LENGTH) m, DE sizing 10×3×30.")
    println(io, "- **Gate alignment:** ode_gate_v13.jl uses lift_for; regate + ladder inherit via gate_design.")
    println(io, "- **Plan:** docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md")
end

# ── Params with custom tether length — DAISY-ANCHORED (2026-08-21, Rod) ──
# All rung scaling anchors on the MEASURED 1.5 kW Daisy (params_daisy), never
# the 10 kW DRR theory or the 50 kW BOM.  mass_scale from 1.5 → KW.
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
end

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
dim = length(lo)

# V14 config (2026-08-20, Rod): hard-constraint MASS-minimisation on the
# Daisy-anchored base.  FoS floor 2.5 at all points; power floor = rung
# rating (5 kW); score = true physics mass.  Replaces the V13 power-scoring
# (v12_fitness) with mass_min_fitness — the DE finds the lightest machine
# that reliably makes rated power at FoS ≥ 2.5.
cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED,
    p_floor_kw = 5.0, p_ceiling_kw = 5.0,
    relax_s = 5.0, window_s = WINDOW_S,
    fos_target = 2.5, fos_hard = 2.5,   # FoS ≥ 2.5 at all points (until field data)
    power_stat = :tail5, penalize_ceiling = false,
    kickstart_s = 0.0,   # ζ=0.05: settle reaches the productive branch directly
    k_mppt = 5.39,   # k sweep 2026-08-21 (scripts/results/k_sweep_daisy_5kw.csv):
                     # knee at k≈4.0 (P_end 5.02); Daisy 3-blade anchor scaled
                     # 0.42·(5/1.5)^2.5 = 5.39 → P_end 6.09 kW, plateau through
                     # k=9 (6.46).  Below 4.0 the seed rejects at 0 kW.
                     # NOT p_base.k_mppt (3.55, sub-knee).
    tether_diameter = p_base.tether_diameter,
)

# ── Telemetry CSV — FULL genome + decoded values, flushed per row ────────
TELE_CSV = joinpath(OUT_DIR, "telemetry.csv")
open(TELE_CSV, "w") do io
    println(io, "# v13_5kw_masslift telemetry  length=$(LENGTH)  window=$(WINDOW_S)  min_clearance=$(MIN_CLEARANCE)  lift=mass-aware-const-tension  margin=1.5  era=$(PHYSICS_ERA)  git=$(GIT_HASH)")
    println(io, "island,gen,idx,fitness,status,P_mean,P_end,T_lift,FoS,twist_crossed,clearance," *
        "n_lines,rings,n_active,r_hub,r_bot,bank_top,bank_bot,blade_scale_top,blade_scale_bottom,tether," *
        join(["x$j" for j in 1:14], ","))
end

function log_telemetry(island::Int, gen::Int, idx::Int, x::Vector{Float64},
                       fitness::Float64, status::Symbol, r, clearance::Float64,
                       dec)
    open(TELE_CSV, "a") do io
        row = [
            island, gen, idx, round(fitness, digits=3), status,
            r === nothing ? "NaN" : round(r.P_mean, digits=2),
            r === nothing ? "NaN" : round(r.P_end, digits=2),
            r === nothing ? "NaN" : round(r.T_lift, digits=2),
            r === nothing ? "NaN" : round(r.FoS_min, digits=2),
            r === nothing ? "false" : string(r.twist_crossed),
            round(clearance, digits=2),
            dec.design.n_lines, dec.n_rings, dec.n_active,
            round(dec.design.r_hub, digits=3), round(dec.design.r_bottom, digits=3),
            round(x[11], digits=1), round(x[12], digits=1),
            round(x[13], digits=3), round(x[14], digits=3),
            LENGTH,
            [round(v, digits=6) for v in x]...,
        ]
        println(io, join(row, ","))
    end
end

# ── Clearance computation (pure geometry) ────────────────────────────────
function lowest_rotor_clearance(dec)
    zs = dec.zs
    z_low = Inf
    r_tip_low = 0.0
    for rotor in dec.rotors
        zr = zs[clamp(rotor.ring_idx, 1, length(zs))]
        if zr < z_low
            z_low = zr
            r_tip_low = rotor.blade_tip_radius
        end
    end
    z_low == Inf && return Inf
    return GROUND_OFFSET + z_low * sin(ELEV) - r_tip_low
end

# ── Per-eval timeout (2026-08-13: len21 hung 1.6h on a stiff eval) ───────
# NOTE: @async cannot interrupt a tight Euler loop — timed-out evals keep
# burning CPU. For very long campaigns use process-level isolation.
function with_timeout(f::Function, timeout_s::Float64, fallback)
    task = @async f()
    t0 = time()
    while !istaskdone(task) && time() - t0 < timeout_s
        sleep(0.5)
    end
    if istaskdone(task)
        return fetch(task)
    else
        return fallback
    end
end

# ── Eval cache ───────────────────────────────────────────────────────────
const EVAL_CACHE = Dict{Vector{Float64},Float64}()

function eval_v13(x::Vector{Float64}, island::Int=0, gen::Int=0, idx::Int=0)
    key = round.(x, digits=6)
    if haskey(EVAL_CACHE, key)
        return EVAL_CACHE[key]
    end
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

    result = Inf; status = :reject; clearance = Inf; r = nothing; dec = nothing
    try
        dec = design_from_vector_v10(xr, beam_profile, p_base; power_W=PW)
        clearance = lowest_rotor_clearance(dec)
        # ── HARD GATE: ground clearance ────────────────────────────────
        if clearance < MIN_CLEARANCE
            status = :clearance_reject
        elseif dec.n_active == 0
            status = :no_active
        else
            r = with_timeout(300.0, nothing) do
                KiteTurbineDynamics.evaluate_windowed(
                    xr, beam_profile, p_base, cfg;
                    start_mode = :cold,
                    lift_device = lift_for,
                    fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
                )
            end
            if r === nothing
                status = :timeout
            elseif r.status === :reject
                status = r.twist_crossed ? :reject_twist : :reject
            else
                status = :ok
                result = r.fitness
            end
        end
    catch e
        status = :error
    end
    if status !== :ok
        result = 1e9
    end
    EVAL_CACHE[key] = result
    if island > 0 && dec !== nothing
        log_telemetry(island, gen, idx, x, result, status, r, clearance, dec)
    end
    GC.gc()
    return result
end

# ── DE settings (identical to first campaign) ────────────────────────────
popsize = 10; n_islands = 3; max_iter = 30

println("═"^60)
println("  V13 Cold-Start DE — 5kW MASS-AWARE LIFT REDO (constant tension)")
println("  Tether length: $LENGTH m (min clearance gate: $MIN_CLEARANCE m)")
println("  Lift: 1.5 × m_airborne × g / sin(70°) per genome, flat (const_tension=true)")
println("  Era: $PHYSICS_ERA   git: $GIT_HASH")
println("  Window: $WINDOW_S s; power_stat=:tail5; penalize_ceiling=false; fos_target=1.5")
println("  $popsize pop × $n_islands islands × $max_iter gen")
println("  Full per-eval telemetry (genome + decoded + T_lift) → $TELE_CSV")
println("═"^60)
flush(stdout)

const ALL_ROWS = Tuple{Int,Int,Float64}[]
function save_progress(force::Bool=false)
    if force || length(ALL_ROWS) % 5 == 0
        df = DataFrame(island=[r[1] for r in ALL_ROWS], iteration=[r[2] for r in ALL_ROWS], fitness=[r[3] for r in ALL_ROWS])
        CSV.write(joinpath(OUT_DIR, "convergence.csv"), df)
    end
end

campaign_start = time()
global_best_x = nothing
global_best_cost = Inf

for island in 1:n_islands
    global global_best_x, global_best_cost
    Random.seed!(42 + island - 1)
    println("\n  -- Island $island / $n_islands " * "-"^28)
    flush(stdout)
    island_start = time()

    population = Vector{Vector{Float64}}(undef, popsize)
    population[1] = clamp.(copy(seed_v), lo, hi)
    population[1][8] = Float64(round(Int, clamp(population[1][8], 3, 16)))
    for k in 2:popsize
        population[k] = lo .+ rand(Float64, dim) .* (hi .- lo)
    end

    costs = [eval_v13(population[k], island, 0, k) for k in 1:popsize]
    best_idx = argmin(costs)
    best_cost = costs[best_idx]
    best_x = copy(population[best_idx])
    @printf("  [gen 0] seeded best=%.2f\n", best_cost)
    open(joinpath(OUT_DIR, "island_$(island)_best.csv"), "w") do f
        write(f, join(string.(best_x), ","))
    end
    flush(stdout)

    for iteration in 1:max_iter
        new_costs = copy(costs)
        for i in 1:popsize
            a, b, c = rand(1:popsize, 3)
            while a == i || b == i || c == i || a == b || a == c || b == c
                a, b, c = rand(1:popsize, 3)
            end
            F = 0.5 + 0.3 * rand()
            mutant = clamp.(population[a] .+ F .* (population[b] .- population[c]), lo, hi)
            CR = 0.7 + 0.2 * rand()
            trial = similar(population[i])
            j_rand = rand(1:dim)
            for j in 1:dim
                trial[j] = (rand() <= CR || j == j_rand) ? mutant[j] : population[i][j]
            end
            trial[8] = Float64(round(Int, clamp(trial[8], 3, 16)))
            cost_trial = eval_v13(trial, island, iteration, i)
            if cost_trial <= costs[i]
                population[i] = trial
                new_costs[i] = cost_trial
                if cost_trial < best_cost
                    best_cost = cost_trial
                    best_x = copy(trial)
                end
            end
        end
        costs = new_costs

        push!(ALL_ROWS, (island, iteration, best_cost))
        save_progress()
        open(joinpath(OUT_DIR, "island_$(island)_best.csv"), "w") do f
            write(f, join(string.(best_x), ","))
        end
        open(joinpath(OUT_DIR, "island_$(island)_best_meta.txt"), "w") do f
            println(f, "island=$island gen=$iteration fitness=$best_cost length=$LENGTH")
        end
        elapsed = round(time() - island_start, digits=0)
        @printf("  [Island %d/%d | gen %3d] best=%.2f  elapsed=%ds\n", island, n_islands, iteration, best_cost, elapsed)
        flush(stdout)
    end

    if best_cost < global_best_cost
        global_best_cost = best_cost
        global_best_x = copy(best_x)
        println("  ** New global best: $(round(global_best_cost, digits=2)) **")
    end
    flush(stdout)
end

elapsed_total = round(time() - campaign_start, digits=0)
println("\n  Campaign complete in $(elapsed_total)s")
println("  Global best fitness: $(round(global_best_cost, digits=2))")
if global_best_x !== nothing
    open(joinpath(OUT_DIR, "best_vector.csv"), "w") do f
        write(f, join(string.(global_best_x), ","))
    end
end
save_progress(true)
println("  Results + telemetry in $OUT_DIR")
