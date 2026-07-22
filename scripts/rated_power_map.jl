#!/usr/bin/env julia
# rated_power_map.jl — find k_mppt that hits P≈50kW with best FoS at each wind
using KiteTurbineDynamics, Printf, CSV, DataFrames, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const BLADE = 0.90
const WINDS = [7.0, 9.0, 11.0, 13.0, 15.0]
const P_TARGET = 50.0  # kW
const FOS_MIN = 2.5
const SIM_S = 30.0
const DT = ControlMapHunt.DT
const K_VALS = vcat([2.0], exp10.(range(log10(3.0), log10(500.0); length=15)))

function test_k(blade, k, wind)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    sys.k_mppt_ref[] = k
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    n_steps = round(Int, SIM_S / DT)

    P_final, ω_final, fos_final, T_final = 0.0, 0.0, Inf, 0.0
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=false)
                P_final = ef.base.P_kw
                ω_final = ef.base.omega_hub * 60 / (2π)
                T_final = ef.base.T_max / 1000.0
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos_final = isempty(airborne) ? Inf : minimum(airborne)
            end
        end)
    return P_final, ω_final, fos_final, T_final
end

println("════════════════════════════════════════════════")
println("Rated-power hunt: λ=$(BLADE), target P=$(P_TARGET) kW, FoS≥$(FOS_MIN)")
println("════════════════════════════════════════════════")

for wind in WINDS
    println("\n── wind=$(wind) m/s ──")
    best = nothing
    best_score = -Inf
    
    for k in K_VALS
        try
            P, ω, fos, T = test_k(BLADE, k, wind)
            # Score: prefer FoS≥FOS_MIN, then closest to P_TARGET without going under
            if fos >= FOS_MIN && P >= P_TARGET * 0.9
                score = -abs(P - P_TARGET)  # closer to target = better
                if best === nothing || score > best_score
                    best = (k=k, P=P, ω=ω, fos=fos, T=T)
                    best_score = score
                end
            end
        catch
        end
        GC.gc()
    end
    
    if best !== nothing
        @printf("  BEST: k=%.0f  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  T=%.1f kN\n",
            best.k, best.P, best.ω, best.fos, best.T)
    else
        # Show best effort even if it fails constraints
        best_effort = nothing
        best_P = -Inf
        for k in K_VALS
            try
                P, ω, fos, T = test_k(BLADE, k, wind)
                if P > best_P
                    best_effort = (k=k, P=P, ω=ω, fos=fos, T=T)
                    best_P = P
                end
            catch; end
            GC.gc()
        end
        if best_effort !== nothing
            @printf("  BEST EFFORT: k=%.0f  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  T=%.1f kN  ← FAILS constraints\n",
                best_effort.k, best_effort.P, best_effort.ω, best_effort.fos, best_effort.T)
        else
            println("  NO VIABLE POINT")
        end
    end
end

println("\nDone.")
