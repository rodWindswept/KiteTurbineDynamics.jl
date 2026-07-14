#!/usr/bin/env julia
# Quick power curve sweep — 3 hero designs × 3 wind speeds
using KiteTurbineDynamics, Printf, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const WINDS = [5.0, 11.0, 15.0]
const SIM_S = 45.0
const DT    = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "power_curve_quick.csv")

const DESIGNS = [
    (blade=0.90, k=6.0,  label="0.90/k6 (safest)"),
    (blade=0.95, k=4.0,  label="0.95/k4 (sweet spot)"),
    (blade=1.10, k=4.0,  label="1.10/k4 (max power)"),
]

function eval_design(blade, k, wind)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    sys.k_mppt_ref[] = k
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    n_mppt = round(Int, SIM_S / DT)

    local P_final = 0.0
    local omega_final = 0.0
    local fos_final = Inf
    run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_mppt
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                P_final = ef.base.P_kw
                omega_final = ef.base.omega_hub * 60 / (2π)
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos_final = isempty(airborne) ? Inf : minimum(airborne)
            end
        end)
    return P_final, omega_final, fos_final
end

mkpath(dirname(OUT_CSV))
println("════════════════════════════════════════════════")
println("Quick power curve — 3 designs × 3 wind speeds")
println("$(SIM_S)s MPPT · spokes ON · DE ring")
println("════════════════════════════════════════════════")

# Fresh file
open(OUT_CSV, "w") do f
    write(f, "blade_scale,k_mppt,label,wind_ms,P_kw,omega_rpm,min_fos,status\n")
end

for (blade, k, label) in DESIGNS
    for wind in WINDS
        @printf("%s  wind=%.0f ... ", label, wind); flush(stdout)
        try
            P, ω, fos = eval_design(blade, k, wind)
            @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
            row = (blade_scale=blade, k_mppt=k, label=label,
                   wind_ms=wind, P_kw=P, omega_rpm=ω, min_fos=fos, status="ok")
            CSV.write(OUT_CSV, DataFrame([row]); append=true)
        catch err
            println("ERROR: $(sprint(showerror, err))")
        end
        GC.gc()
    end
end

println("\nDone: $OUT_CSV")
