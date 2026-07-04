#!/usr/bin/env julia
# Gate test w/ longer sim: λ=1.0, k=15.6, T_SIM=10s
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT=4e-5; const T=10.0; const V=11.0; const K=15.6

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
sys.k_mppt_ref[] = K
wf(pos, t) = [V * (max(pos[3],1.0) / p.h_ref)^(1/7), 0.0, 0.0]
lift = KiteTurbineDynamics.rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
n = round(Int, T/DT)
local Pw=0.0; local wr=0.0; local fs=Inf
run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
    callback=(uc, tc, step) -> begin
        if step == n
            ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
            Pw=ef.base.P_kw; wr=ef.base.omega_hub*60/(2π)
            fv=Float64[]
            for i in 2:length(ef.ring_fos)
                v=ef.ring_fos[i]; (!isnan(v)&&!isinf(v)&&v>0)&&push!(fv,v)
            end
            fs=isempty(fv) ? Inf : minimum(fv)
        end
    end)
@printf("λ=1.0 k=%.1f T=%ds P=%.1f kW ω=%.0f rpm FoS=%.2f  %s\n", K, T, Pw, wr, fs, abs(Pw-172.7)<10 ? "✓ PASS":"✗ FAIL ($(round(Pw/172.7*100))%%)")
