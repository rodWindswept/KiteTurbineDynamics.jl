#!/usr/bin/env julia
# Minimal test: V10 Tight λ=0.54 — post-scale blade dimensions only, same geometry.
# Single 11 m/s sweep.  Expect P ≈ 50 kW.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf

const DT       = 4e-5
const T_SIM    = 5.0
const V_WIND   = 11.0
const LAMBDA   = 0.54

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=LAMBDA)

println("Hub radius: $(round(sys.rotor.radius, digits=2))m (not yet scaled)")
for (i, er) in enumerate(sys.expansion_rotors)
    println("  Exp[$i]: tip=$(round(er.blade_tip_radius, digits=2))m hub=$(round(er.blade_hub_radius, digits=2))m chord=$(round(er.blade_chord, digits=3))m")
end

wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end
lift = KiteTurbineDynamics.rotary_lifter_default()

println("\n── 11 m/s, post-scale λ=$LAMBDA ──")
for k in [2.0, 3.0, 5.0, 8.0, 12.0, 20.0, 35.0, 60.0, 100.0, 200.0, 500.0]
    sys.k_mppt_ref[] = k
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
    n_steps = round(Int, T_SIM / DT)
    local P_kw = 0.0; local ω_rpm = 0.0; local min_fos = Inf
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift; brake_engaged=sys.brake_engaged[])
                P_kw = ef.base.P_kw
                ω_rpm = ef.base.omega_hub * 60 / (2π)
                fos = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(fos, v)
                end
                min_fos = isempty(fos) ? Inf : minimum(fos)
            end
        end)
    ratio = P_kw / 50.0
    mark = abs(ratio - 1.0) < 0.05 ? " ★ ON TARGET" :
           abs(ratio - 1.0) < 0.20 ? " ~ close" : ""
    @printf("  k=%6.0f  P=%6.1f kW (%3.0f%%) ω=%4.0f rpm FoS=%5.2f%s\n",
        k, P_kw, ratio*100, ω_rpm, min_fos, mark)
    if P_kw > 70.0
        println("  → well above target")
        break
    end
end
