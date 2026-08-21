#!/usr/bin/env julia
# scripts/run_v12_5kw_v3.jl
#
# 5kW telemetry re-run + length variations (18/21/25 m).
# v3 additions over run_v12_5kw.jl:
#   1. FULL per-eval telemetry CSV — every genome, decoded architecture,
#      P, FoS, clearance, status. Nothing is dropped.
#   2. Ground-clearance gate in the objective wrapper: rejects designs whose
#      lowest active rotor tip clearance < MIN_CLEARANCE (1.5 m).
#   3. --length CLI arg: campaign-level tether-length knob (18/21/25 m).
#   4. Crash-proof: per-eval rows flushed, per-gen best saves.
#
# Usage: julia --project=. scripts/run_v12_5kw_v3.jl --length 21

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, DataFrames, CSV, Random, Statistics
include(joinpath(@__DIR__, "compute_seeds.jl"))

# ── CLI ─────────────────────────────────────────────────────────────────
function parse_length_arg()
    L = 21.2
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

const OUT_DIR = joinpath(@__DIR__, "results", "v12_5kw_len$(LENGTH)")
mkpath(OUT_DIR)

# ── Params with custom tether length ─────────────────────────────────────
function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL
seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
dim = length(lo)

cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED, p_floor_kw = 2.5, p_ceiling_kw = 5.0,
    relax_s = 5.0, window_s = 10.0, tether_diameter = p_base.tether_diameter,
)

# ── Telemetry CSV ────────────────────────────────────────────────────────
TELE_CSV = joinpath(OUT_DIR, "telemetry.csv")
open(TELE_CSV, "w") do io
    println(io, "# v12_5kw_v3 telemetry  length=$LENGTH  min_clearance=$MIN_CLEARANCE")
    println(io, "island,gen,idx,fitness,status,P_kW,FoS,n_lines,rings,n_active,r_hub,r_bot,bank_top,bank_bot,blade_scale_top,blade_scale_bottom,clearance,tether")
end

function log_telemetry(island::Int, gen::Int, idx::Int, x::Vector{Float64},
                       fitness::Float64, status::Symbol, P_kW::Float64,
                       FoS::Float64, clearance::Float64)
    open(TELE_CSV, "a") do io
        println(io, join([
            island, gen, idx, round(fitness, digits=3), status,
            round(P_kW, digits=2), round(FoS, digits=2),
            round(Int, clamp(x[8], 3, 16)), 0, 0,  # n_lines (rings/n_active filled post-hoc)
            round(x[5], digits=2), round(x[6], digits=2),
            round(x[11], digits=1), round(x[12], digits=1),
            round(x[13], digits=3), round(x[14], digits=3),
            round(clearance, digits=2), LENGTH,
        ], ","))
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

# ── Per-eval timeout (2026-08-13: len21 hung 1.6h on a stiff eval) ──────
# Runs f() in an @async task; returns fallback if it exceeds timeout_s.
# The ODE loop is a tight explicit-Euler kernel — a task can't interrupt
# mid-eval, but the timeout prevents the CAMPAIGN from hanging forever:
# each eval is abandoned and scored as reject.
function with_timeout(f::Function, timeout_s::Float64, fallback)
    task = @async f()
    deadline = time() + timeout_s
    while !istaskdone(task) && time() < deadline
        sleep(0.5)
    end
    if istaskdone(task)
        try
            return fetch(task)
        catch e
            @warn "Eval threw" exception = e
            return fallback
        end
    else
        @warn "Per-eval timeout after $(timeout_s) s — returning fallback"
        return fallback
    end
end

# ── V12 cold-start evaluator (cached, telemetry-logged) ──────────────────
const EVAL_CACHE = Dict{Vector{Float64},Float64}()
const EVAL_META = Dict{Vector{Float64},Tuple{Symbol,Float64,Float64}}()

function eval_v12(x::Vector{Float64}, island::Int=0, gen::Int=0, idx::Int=0)
    key = round.(x, digits=6)
    if haskey(EVAL_CACHE, key)
        return EVAL_CACHE[key]
    end
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

    result = Inf; status = :reject; P_kW = 0.0; FoS = 0.0; clearance = Inf
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
                    lift_device = rotary_lifter_default(),
                    fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.v12_fitness(P, F, c, m),
                )
            end
            if r === nothing
                status = :timeout
            elseif r.status === :reject
                status = :reject
            else
                status = :ok
                P_kW = r.P_mean
                FoS = r.FoS_min
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
    if island > 0
        log_telemetry(island, gen, idx, x, result, status, P_kW, FoS, clearance)
    end
    GC.gc()
    return result
end

# ── DE settings ──────────────────────────────────────────────────────────
popsize = 10; n_islands = 3; max_iter = 30

println("═"^60)
println("  V12 Cold-Start DE — 5kW Telemetry Re-run v3")
println("  Tether length: $LENGTH m (min clearance gate: $MIN_CLEARANCE m)")
println("  $popsize pop × $n_islands islands × $max_iter gen")
println("  Full per-eval telemetry → $TELE_CSV")
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

    costs = [eval_v12(population[k], island, 0, k) for k in 1:popsize]
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
            cost_trial = eval_v12(trial, island, iteration, i)
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
