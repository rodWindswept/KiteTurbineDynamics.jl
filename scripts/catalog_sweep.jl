#!/usr/bin/env julia
# scripts/catalog_sweep.jl — design catalog with corrected ring geometry
# Post ring_element_analysis fix: uses DE-optimized Do/t_overD from JSON

using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const FOS_GATE   = 1.5
const P_GATE_KW  = 50.0
const WIND_MS    = 11.0
const SIM_S      = 30.0
const K_VALUES   = [2.0, 4.0, 6.0, 8.0, 10.0, 14.0]
const OUT_CSV    = joinpath(@__DIR__, "results", "control_maps", "catalog_corrected_geo.csv")

println("════════════════════════════════════════════════")
println("Design catalog sweep — corrected ring geometry")
println("code: $(ControlMapHunt.GIT_HASH)")
println("wind: $(WIND_MS) m/s · spokes: ON · settle+$(SIM_S)s MPPT")
println("════════════════════════════════════════════════")

const ROUNDS = [
    (1, 0.004,  1.30, [0.69, 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10]),
    (2, 0.004,  1.15, [0.90, 0.95, 1.00, 1.05, 1.10]),
    (3, 0.004,  1.00, [0.95, 1.00, 1.05, 1.10]),
    (4, 0.0035, 1.30, [0.95, 1.00, 1.05, 1.10]),
]

early_stop = !("--no-early-stop" in ARGS)

mkpath(dirname(OUT_CSV))
done_keys = Set{NTuple{4, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.tether_mm, r.r_bottom, r.blade_scale, r.k_mppt))
    end
    println("Resuming: $(length(done_keys)) rows from $(basename(OUT_CSV))")
end

function eval_point(tether_m::Float64, r_bot::Float64, blade::Float64, k::Float64)
    fn = ControlMapHunt.v10_tight_builder(
        r_bottom_scale=r_bot, tether_diameter=tether_m, blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sys.k_mppt_ref[] = k
    sp = SpokeParams(enabled=true)

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
    for i in 2:length(ring_fos)
        v = ring_fos[i]
        (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
    end
    min_fos = isempty(airborne) ? Inf : minimum(airborne)
    n_fail = count(<(1.0), airborne)
    return P_kw, ω_hub * 60 / (2π), min_fos, n_fail, length(airborne), T_max / 1000.0
end

function append_row!(row::NamedTuple)
    df = DataFrame([row])
    CSV.write(OUT_CSV, df; append=isfile(OUT_CSV))
end

println("═════════════════════════════════════════════════════════════════")
println("Design catalog — corrected ring geometry (DE-optimized)")
println("gates: FoS ≥ $(FOS_GATE), P ≥ $(P_GATE_KW) kW · $(SIM_S)s MPPT · spokes ON")
println("═════════════════════════════════════════════════════════════════")

found_viable = false
for (rnd, tether_m, r_bot, blades) in ROUNDS
    (found_viable && early_stop) && break
    tether_mm = round(tether_m * 1000, digits=2)
    @printf("\n── Round %d: %.1fmm tether, r_bottom %.2f ──\n", rnd, tether_mm, r_bot)
    for blade in blades
        (found_viable && early_stop) && break
        for k in K_VALUES
            key = (tether_mm, r_bot, blade, k)
            if key in done_keys
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
                P, rpm, fos, nf, nr, pass ? "← VIABLE ✅" : "")
            if pass
                found_viable = true
                early_stop && break
            end
            GC.gc()
        end
    end
end

println("\n═════════════════════ CATALOG SUMMARY ═════════════════════")
df = CSV.read(OUT_CSV, DataFrame)
ok = filter(r -> r.status == "ok", df)
if isempty(ok)
    println("No successful evaluations.")
else
    sort!(ok, :min_fos, rev=true)
    viable = filter(r -> r.pass, ok)
    println("Viable designs (FoS ≥ $(FOS_GATE), P ≥ $(P_GATE_KW) kW): $(nrow(viable))")
    if nrow(viable) > 0
        show(viable, allrows=true, allcols=true)
    else
        println("\nTop 10 by FoS:")
        show(first(ok, 10), allrows=true, allcols=true)
    end
end
println("\nDone.")
