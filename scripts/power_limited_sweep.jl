#!/usr/bin/env julia
# power_limited_sweep.jl — generator clamps at 50kW by reducing k dynamically
using KiteTurbineDynamics, Printf, CSV, DataFrames, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const BLADE = 0.85
const K_NOMINAL = 2.0    # base k — reduced when power exceeds limit
const P_LIMIT_W = 50000.0  # 50 kW
const WINDS = [9.0, 11.0, 13.0, 15.0]
const SIM_S = 60.0
const DT = ControlMapHunt.DT

function eval_power_limited(wind)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=BLADE)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Power-limited controller: adjust k each timestep
    function power_limiter(sys, u, p, t)
        ω_hub = u[2]  # hub angular velocity is u[2], not u[1]
        P_gen = sys.k_mppt_ref[] * ω_hub^3
        if P_gen > P_LIMIT_W && ω_hub > 1.0
            k_new = P_LIMIT_W / ω_hub^3
            sys.k_mppt_ref[] = max(k_new, 0.1)  # floor at 0.1
        end
    end

    sys.k_mppt_ref[] = K_NOMINAL
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
    sys.k_mppt_ref[] = K_NOMINAL  

    # MPPT with power limiter
    n_steps = round(Int, SIM_S / DT)
    k_log = Float64[]
    P_log = Float64[]
    P_final, ω_final, fos_final, T_final, k_final = 0.0, 0.0, Inf, 0.0, 0.0
    
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            # Run power limiter EVERY step (not just final)
            power_limiter(sys, u_curr, p, t_curr)
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                P_final = ef.base.P_kw; ω_final = ef.base.omega_hub * 60 / (2π)
                T_final = ef.base.T_max / 1000.0; k_final = sys.k_mppt_ref[]
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos_final = isempty(airborne) ? Inf : minimum(airborne)
            end
        end)

    return P_final, ω_final, fos_final, T_final, k_final
end

println("════════════════════════════════════════════════")
println("Power-limited sweep: λ=$(BLADE), k_nom=$(K_NOMINAL), P_limit=$(P_LIMIT_W/1000) kW")
println("════════════════════════════════════════════════")

for wind in WINDS
    @printf("wind=%.0f ... ", wind); flush(stdout)
    try
        P, ω, fos, T, k = eval_power_limited(wind)
        limited = (abs(P - P_LIMIT_W/1000) < 5.0) ? "✓ CLAMPED" : ""
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f  k_eff=%.2f  %s\n", P, ω, fos, k, limited)
    catch err
        println("ERROR: $(sprint(showerror, err))")
    end
    GC.gc()
end

println("\nDone.")
