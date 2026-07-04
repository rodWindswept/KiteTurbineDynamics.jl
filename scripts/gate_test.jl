#!/usr/bin/env julia
# Gate test: λ=1.0 through new builder → must reproduce 172.7 kW / FoS 2.30 at 11 m/s
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf

const DT     = 4e-5
const T_SIM  = 3.0
const V      = 11.0
const K_REF  = 15.6    # from original V10 Tight control map

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

for λ in [1.0, 0.54]
    sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=λ)
    sys.k_mppt_ref[] = (λ == 1.0) ? K_REF : K_REF * λ^5  # λ^5 scaling per Rod
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [V * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    
    u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
    n_steps = round(Int, T_SIM / DT)
    local P=0.0; local ω=0.0; local fos=Inf
    run_canonical_sim!(u, sys, p, wf, n_steps, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps
                ef = capture_extended(u_curr, sys, p, t_curr, wf, lift; brake_engaged=sys.brake_engaged[])
                P = ef.base.P_kw
                ω = ef.base.omega_hub * 60 / (2π)
                fs = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(fs, v)
                end
                fos = isempty(fs) ? Inf : minimum(fs)
            end
        end)
    
    expected_P = λ == 1.0 ? 172.7 : 50.0
    expected_fos = λ == 1.0 ? 2.30 : NaN
    gate = λ == 1.0 ? (abs(P - 172.7) < 10.0 ? "✓ GATE PASS" : "✗ GATE FAIL") : ""
    @printf("λ=%.2f k=%.1f P=%.1f kW ω=%.0f rpm FoS=%.2f  %s\n", λ, sys.k_mppt_ref[], P, ω, fos, gate)
    if λ == 1.0
        @printf("  Expected: P=172.7±10 FoS=2.30  Got: P=%.1f FoS=%.2f\n", P, fos)
    end
end
