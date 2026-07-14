#!/usr/bin/env julia
# Quick low-wind kickstart fills for power curve chart
using KiteTurbineDynamics, Printf, CSV, DataFrames, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const WINDS = [5.0, 7.0]
const WINDS_FULL = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const SIM_S = 45.0
const DT    = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "wind_sweep.csv")

function eval_design_kickstart(blade, k, wind)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    sys.k_mppt_ref[] = k

    # Kickstart: no-load spin-up
    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
    omega_kick = 30.0
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
    end
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]
            tang ./= norm(tang)
            v_orb = omega_kick * r
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= v_orb .* tang
        end
    end
    sys.k_mppt_ref[] = 0.0
    n_spin = round(Int, 30.0 / DT)
    run_canonical_sim!(u, sys, p, wf, n_spin, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)
    # RE-ENGAGE generator after spin-up
    sys.k_mppt_ref[] = k

    n_mppt = round(Int, SIM_S / DT)
    local P_final = 0.0; local omega_final = 0.0; local fos_final = Inf; local T_final = 0.0
    run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_mppt
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                P_final = ef.base.P_kw
                omega_final = ef.base.omega_hub * 60 / (2π)
                T_final = ef.base.T_max / 1000.0
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos_final = isempty(airborne) ? Inf : minimum(airborne)
            end
        end)
    return P_final, omega_final, fos_final, T_final
end

println("════════════════════════════════════════════════")
println("Low-wind kickstart fills for power curve chart")
println("════════════════════════════════════════════════")

# Track existing rows to avoid duplicates
done_keys = Set{Tuple{Float64, Float64, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.blade_scale, r.k_mppt, r.wind_ms))
    end
    println("Existing: $(length(done_keys)) rows")
end

# 1. 0.90/k6 at 5,7 m/s
for wind in WINDS
    (0.90, 6.0, wind) in done_keys && continue
    @printf("0.90/k6  wind=%.0f (kickstart)... ", wind); flush(stdout)
    try
        P, ω, fos, T = eval_design_kickstart(0.90, 6.0, wind)
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
        row = (blade_scale=0.90, k_mppt=6.0, wind_ms=wind, label="0.90/k6 (safest)",
               P_kw=P, omega_rpm=ω, min_fos=fos, T_max_kN=T, status="ok")
        CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
    catch err
        println("ERROR: $(sprint(showerror, err))")
    end
    GC.gc()
end

# 2. 0.95/k4 at 5,7 m/s
for wind in WINDS
    (0.95, 4.0, wind) in done_keys && continue
    @printf("0.95/k4  wind=%.0f (kickstart)... ", wind); flush(stdout)
    try
        P, ω, fos, T = eval_design_kickstart(0.95, 4.0, wind)
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
        row = (blade_scale=0.95, k_mppt=4.0, wind_ms=wind, label="0.95/k4 (sweet spot)",
               P_kw=P, omega_rpm=ω, min_fos=fos, T_max_kN=T, status="ok")
        CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
    catch err
        println("ERROR: $(sprint(showerror, err))")
    end
    GC.gc()
end

# 3. 0.85/k4 full wind sweep
for wind in WINDS_FULL
    (0.85, 4.0, wind) in done_keys && continue
    @printf("0.85/k4  wind=%.0f (kickstart)... ", wind); flush(stdout)
    try
        P, ω, fos, T = eval_design_kickstart(0.85, 4.0, wind)
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
        row = (blade_scale=0.85, k_mppt=4.0, wind_ms=wind, label="0.85/k4 (light blade)",
               P_kw=P, omega_rpm=ω, min_fos=fos, T_max_kN=T, status="ok")
        CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
    catch err
        println("ERROR: $(sprint(showerror, err))")
    end
    GC.gc()
end

println("\nDone. Results appended to: $OUT_CSV")
