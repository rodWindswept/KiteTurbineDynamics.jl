#!/usr/bin/env julia
# λ=0.54 test: k = 15.6 × 0.54⁵ ≈ 0.72. Expect P≈50 kW, ω up ~1.85×, FoS > 2.53.
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT=4e-5; const T_SIM=10.0; const V_WIND=11.0
const LAMBDA=0.54; const K_VAL = 15.6 * LAMBDA^5

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=LAMBDA)
sys.k_mppt_ref[] = K_VAL

wf(pos, t) = [V_WIND * (max(pos[3],1.0) / p.h_ref)^(1.0/7.0), 0.0, 0.0]
lift = KiteTurbineDynamics.rotary_lifter_default()
u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
n_steps = round(Int, T_SIM/DT)
P_ref=Ref(0.0); w_ref=Ref(0.0); f_ref=Ref(Inf)

run_canonical_sim!(u, sys, p, wf, n_steps, DT; lift_device=lift, lin_damp=0.05,
    callback=(uc, tc, step) -> begin
        if step == n_steps
            ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
            P_ref[]=ef.base.P_kw; w_ref[]=ef.base.omega_hub*60/(2pi)
            fv=Float64[]
            for i in 2:length(ef.ring_fos)
                v=ef.ring_fos[i]; (!isnan(v)&&!isinf(v)&&v>0)&&push!(fv,v)
            end
            f_ref[]=isempty(fv) ? Inf : minimum(fv)
        end
    end)

P=P_ref[]; wr=w_ref[]; fs=f_ref[]
println("λ=0.54  k=$(round(K_VAL,digits=3))  P=$(round(P,digits=1)) kW ($(round(P/50*100))%%)  ω=$(round(wr,digits=0)) rpm  FoS=$(round(fs,digits=2))")
println("Expected: P≈50 kW  ω≈$(round(210/0.54, digits=0)) rpm (1.85×)  FoS > 2.53")
