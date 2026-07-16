#!/usr/bin/env julia
# scripts/reverify_fos.jl — Task 2: dual-duration re-verify of anomalous FoS in wind_sweep.csv
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames, JSON3
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const DT = ControlMapHunt.DT
const SP = SpokeParams(enabled=true)

# Three anomalous rows from wind_sweep.csv
const TESTS = [
    (blade=0.95, k=4.0, wind=13.0, expect_FoS=30.7),
    (blade=1.10, k=4.0, wind=15.0, expect_FoS=27.4),
    (blade=1.00, k=4.0, wind=11.0, expect_FoS=14.0),
]

function run_and_capture(blade, k, wind, duration_s)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sys.k_mppt_ref[] = k

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    n_steps = round(Int, duration_s / DT)

    local result = (0.0, 0.0, Inf)
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=SP,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing;
                    brake_engaged=sys.brake_engaged[])
                ω = ef.base.omega_hub * 60 / (2π)
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos = isempty(airborne) ? Inf : minimum(airborne)
                result = (ef.base.P_kw, ω, fos)
            end
        end)
    return result
end

println("═══════════════════════════════════════════")
println("Task 2: FoS re-verification (dual-duration)")
println("═══════════════════════════════════════════")

for t in TESTS
    println("\n── blade=$(t.blade) k=$(t.k) wind=$(t.wind) m/s (wind_sweep FoS=$(t.expect_FoS)) ──")

    r15 = run_and_capture(t.blade, t.k, t.wind, 15.0)
    r60 = run_and_capture(t.blade, t.k, t.wind, 60.0)

    fos_ok = abs(r15[3] - r60[3]) / max(r60[3], 1.0) < 0.02
    p_ok  = abs(r15[1] - r60[1]) < 0.5
    converged = fos_ok && p_ok

    @printf("  15s: P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", r15[1], r15[2], r15[3])
    @printf("  60s: P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", r60[1], r60[2], r60[3])
    @printf("  Converged: %s (ΔFoS=%.2f%%, ΔP=%.1f kW)\n", 
        converged ? "✓" : "✗", 
        abs(r15[3]-r60[3])/max(r60[3],1.0)*100,
        abs(r15[1]-r60[1]))
end

println("\nDone.")
