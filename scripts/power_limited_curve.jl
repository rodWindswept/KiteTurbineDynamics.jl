#!/usr/bin/env julia
# power_limited_curve.jl — run 0.85 at k_target values, 15s sims to avoid ODE stalls
using KiteTurbineDynamics, Printf, CSV, DataFrames, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const BLADE = 0.85
const P_LIMIT = 50000.0
const SIM_S = 20.0  # shorter to avoid ODE stalls
const DT = ControlMapHunt.DT

# From 0.85/k2 data: compute k_target = P_LIMIT / ω³
const POINTS = [
    (wind=9.0,  k=1.82),
    (wind=11.0, k=0.63),
    (wind=13.0, k=0.66),
    (wind=15.0, k=0.51),
]

function eval_fixed_k(wind, k)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=BLADE)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    sys.k_mppt_ref[] = k
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)

    # Kickstart
    omega_kick = 30.0
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            v_orb = omega_kick * r
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= v_orb .* tang
        end
    end
    sys.k_mppt_ref[] = 0.0
    n_spin = round(Int, 30.0 / DT)
    run_canonical_sim!(u, sys, p, wf, n_spin, DT; lift_device=nothing, lin_damp=0.05, spoke=sp)
    sys.k_mppt_ref[] = k

    n_steps = round(Int, SIM_S / DT)
    P_final, ω_final, fos_final, T_final = 0.0, 0.0, Inf, 0.0
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                P_final = ef.base.P_kw; ω_final = ef.base.omega_hub * 60 / (2π)
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
println("Power-limited curve: λ=$(BLADE), cap=$(P_LIMIT/1000) kW, $(SIM_S)s sims")
println("════════════════════════════════════════════════")

for (wind, k) in POINTS
    @printf("wind=%.0f  k=%.2f ... ", wind, k); flush(stdout)
    try
        P, ω, fos, T = eval_fixed_k(wind, k)
        lim = abs(P - P_LIMIT/1000) < 10 ? "✓" : "~"
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f  %s\n", P, ω, fos, lim)
    catch err
        if isa(err, ProcessExitedException) || sprint(showerror, err) |> x -> occursin("timeout", x)
            println("STALLED (ODE)")
        else
            println("ERROR: $(sprint(showerror, err))")
        end
    end
    GC.gc()
end

println("\nDone.")
