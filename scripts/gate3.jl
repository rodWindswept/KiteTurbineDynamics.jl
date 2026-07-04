#!/usr/bin/env julia
# Gate test: λ=1.0, k=15.6, T_SIM=10s — must reproduce 172.7 kW / FoS 2.30
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const T_SIM = 10.0; const V_WIND = 11.0; const K_REF = 15.6

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))
sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
sys.k_mppt_ref[] = K_REF

wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end
lift = KiteTurbineDynamics.rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
n_steps = round(Int, T_SIM / DT)

P_ref = Ref(0.0); w_ref = Ref(0.0); f_ref = Ref(Inf)

run_canonical_sim!(u, sys, p, wf, n_steps, DT;
    lift_device=lift, lin_damp=0.05,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_steps
            ef = capture_extended(u_curr, sys, p, t_curr, wf, lift; brake_engaged=sys.brake_engaged[])
            P_ref[] = ef.base.P_kw
            w_ref[] = ef.base.omega_hub * 60 / (2 * pi)
            fos_vals = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                if !isnan(v) && !isinf(v) && v > 0
                    push!(fos_vals, v)
                end
            end
            f_ref[] = isempty(fos_vals) ? Inf : minimum(fos_vals)
        end
    end)

P = P_ref[]; wr = w_ref[]; fs = f_ref[]
pct = round(P / 172.7 * 100, digits=1)
if abs(P - 172.7) < 10.0
    println("✓ GATE PASS: P=$(round(P, digits=1)) kW ($(pct)%)  ω=$(round(wr, digits=0)) rpm  FoS=$(round(fs, digits=2))")
else
    println("✗ GATE FAIL: P=$(round(P, digits=1)) kW ($(pct)%)  ω=$(round(wr, digits=0)) rpm  FoS=$(round(fs, digits=2))")
    println("  Expected: P=172.7±10 kW  FoS=2.30")
end
