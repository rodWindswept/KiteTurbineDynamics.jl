#!/usr/bin/env julia
# scripts/feasibility_sweep.jl — 50 kW viability-region hunt (mass ignored)
#
# Goal: find ANY builder-knob combination that passes BOTH gates with the
# corrected per-vertex tension-only spoke model:
#     Gate S:  min airborne ring FoS ≥ 1.5
#     Gate P:  P ≥ 50 kW
#
# Four auto-expanding rounds (stops at first pass unless --no-early-stop):
#   Round 1: 4.0mm @ r_bottom 1.30, blade ∈ {0.80,0.85,0.90,0.95,1.05,1.10}
#            3.5mm @ r_bottom 1.30, blade ∈ {1.00,1.05,1.10}
#   Round 2: 4.0mm @ r_bottom 1.15, blade ∈ {0.95,1.00,1.05,1.10,1.15}
#   Round 3: 4.0mm @ r_bottom 1.00, blade ∈ {1.05,1.10,1.15,1.20}
#   Round 4: 4.0mm @ r_bottom 1.40, blade ∈ {1.05,1.10,1.15,1.20,1.25,1.30}
#
# Protocol per design: settle → 30 s MPPT at each k ∈ {2,4,8}, endpoint capture.
# Progressive CSV: one row appended immediately after each (design, k) sim.
# Idempotent: re-running skips (tether, r_bottom, blade, k) rows already in CSV.
#
# Usage:
#   julia --project=. scripts/feasibility_sweep.jl
#   julia --project=. scripts/feasibility_sweep.jl --no-early-stop
#   julia --project=. scripts/feasibility_sweep.jl --rounds 4        # Round 4 only
#
# Clear the compiled cache first if src/ changed since last run:
#   rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji

using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

# ── Gates & protocol constants ────────────────────────────────────────────
const FOS_GATE   = 1.5
const P_GATE_KW  = 50.0
const WIND_MS    = 11.0
const SIM_S      = 30.0
const K_VALUES   = [2.0, 4.0, 8.0]
const OUT_CSV    = joinpath(@__DIR__, "results", "control_maps", "feasibility_sweep.csv")

# ── Round definitions: (round, tether_m, r_bottom_scale, blade_scales) ────
const ROUNDS = [
    (1, 0.004,  1.30, [0.80, 0.85, 0.90, 0.95, 1.05, 1.10]),
    (1, 0.0035, 1.30, [1.00, 1.05, 1.10]),
    (2, 0.004,  1.15, [0.95, 1.00, 1.05, 1.10, 1.15]),
    (3, 0.004,  1.00, [1.05, 1.10, 1.15, 1.20]),
    (4, 0.004,  1.40, [1.05, 1.10, 1.15, 1.20, 1.25, 1.30]),
]

# ── Arg parsing ───────────────────────────────────────────────────────────
early_stop = !("--no-early-stop" in ARGS)
only_rounds = Int[]
let i = findfirst(==("--rounds"), ARGS)
    if i !== nothing && i < length(ARGS)
        append!(only_rounds, parse.(Int, split(ARGS[i + 1], ",")))
    end
end

# ── Idempotent resume: load already-completed rows ───────────────────────
mkpath(dirname(OUT_CSV))
done_keys = Set{NTuple{4, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.tether_mm, r.r_bottom, r.blade_scale, r.k_mppt))
    end
    println("Resuming: $(length(done_keys)) (design, k) rows already in $(basename(OUT_CSV))")
end

# ── Single evaluation: build, settle, 30 s MPPT at fixed k, endpoint FEA ──
function eval_point(tether_m::Float64, r_bot::Float64, blade::Float64, k::Float64)
    fn = ControlMapHunt.v10_tight_builder(
        r_bottom_scale=r_bot, tether_diameter=tether_m, blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sys.k_mppt_ref[] = k
    sp = SpokeParams(enabled=true)   # corrected per-vertex tension-only spokes

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    n_steps = round(Int, SIM_S / ControlMapHunt.DT)

    local P_kw = 0.0; local ω_hub = 0.0; local T_max = 0.0
    local ring_fos = Float64[]
    run_canonical_sim!(u, sys, p, wf, n_steps, ControlMapHunt.DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing;
                    brake_engaged=sys.brake_engaged[])
                P_kw = ef.base.P_kw
                ω_hub = ef.base.omega_hub
                T_max = ef.base.T_max
                ring_fos = copy(ef.ring_fos)
            end
        end)

    airborne = Float64[]
    for i in 2:length(ring_fos)   # skip ground ring
        v = ring_fos[i]
        (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
    end
    min_fos = isempty(airborne) ? Inf : minimum(airborne)
    n_fail = count(<(1.0), airborne)
    return P_kw, ω_hub * 60 / (2π), min_fos, n_fail, length(airborne), T_max / 1000.0
end

# ── Progressive CSV append ────────────────────────────────────────────────
function append_row!(row::NamedTuple)
    df = DataFrame([row])
    CSV.write(OUT_CSV, df; append=isfile(OUT_CSV))
end

# ── Main sweep ────────────────────────────────────────────────────────────
println("═════════════════════════════════════════════════════════════════")
println("Feasibility sweep — gates: FoS ≥ $(FOS_GATE), P ≥ $(P_GATE_KW) kW")
println("wind $(WIND_MS) m/s · $(SIM_S) s MPPT · k ∈ $(K_VALUES) · spokes ON")
println("early stop: $(early_stop) · output: $(OUT_CSV)")
println("═════════════════════════════════════════════════════════════════")

function run_sweep(only_rounds::Vector{Int}, early_stop::Bool, done_keys)
    found_viable = false
    for (rnd, tether_m, r_bot, blades) in ROUNDS
        (!isempty(only_rounds) && rnd ∉ only_rounds) && continue
        (found_viable && early_stop) && break
        tether_mm = round(tether_m * 1000, digits=2)
        @printf("\n── Round %d: %.1fmm tether, r_bottom %.2f ──\n", rnd, tether_mm, r_bot)
        for blade in blades
            (found_viable && early_stop) && break
            for k in K_VALUES
                key = (tether_mm, r_bot, blade, k)
                if key in done_keys
                    @printf("  skip (done): blade %.2f  k=%.0f\n", blade, k)
                    continue
                end
                @printf("  blade %.2f  k=%.0f ... ", blade, k); flush(stdout)
                local P, rpm, fos, nf, nr, Tkn
                try
                    P, rpm, fos, nf, nr, Tkn = eval_point(tether_m, r_bot, blade, k)
                catch err
                    println("ERROR: $(sprint(showerror, err))")
                    append_row!((round=rnd, tether_mm=tether_mm, r_bottom=r_bot,
                        blade_scale=blade, k_mppt=k, P_kw=NaN, omega_rpm=NaN,
                        min_fos=NaN, rings_failing=-1, rings_airborne=-1,
                        T_max_kN=NaN, pass=false, status="error"))
                    continue
                end
                pass = (fos >= FOS_GATE) && (P >= P_GATE_KW)
                append_row!((round=rnd, tether_mm=tether_mm, r_bottom=r_bot,
                    blade_scale=blade, k_mppt=k, P_kw=P, omega_rpm=rpm,
                    min_fos=fos, rings_failing=nf, rings_airborne=nr,
                    T_max_kN=Tkn, pass=pass, status="ok"))
                @printf("P=%6.1f kW  ω=%5.0f rpm  FoS=%5.2f  fail %d/%d %s\n",
                    P, rpm, fos, nf, nr, pass ? " ← VIABLE ✓" : "")
                if pass
                    found_viable = true
                    early_stop && break
                end
                GC.gc()   # builder allocates heavily; keep memory bounded
            end
        end
    end
    return found_viable
end

run_sweep(only_rounds, early_stop, done_keys)

# ── Summary ───────────────────────────────────────────────────────────────
println("\n═════════════════════ SWEEP SUMMARY ═════════════════════")
df = CSV.read(OUT_CSV, DataFrame)
ok = filter(r -> r.status == "ok", df)
if isempty(ok)
    println("No successful evaluations.")
else
    sort!(ok, :min_fos, rev=true)
    println("Top 10 by min FoS:")
    show(first(ok, 10), allrows=true, allcols=true)
    viable = filter(r -> r.pass, ok)
    println("\n\nViable designs (FoS ≥ $(FOS_GATE), P ≥ $(P_GATE_KW) kW): $(nrow(viable))")
    isempty(viable) || show(viable, allrows=true, allcols=true)
end
println("\nDone.")
