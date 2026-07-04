#!/usr/bin/env julia
# tsr_check.jl — try very low k to see if system can spin up to 210 rpm
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.54
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(k_val, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT)
    Pr = Ref(0.0); wr = Ref(0.0)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub*60/(2pi)
            end
        end)
    return (P=Pr[], ω=wr[])
end

println("TSR check — λ=0.54, very low k, ω_max=60")
println("─"^50)
for k in [4.55, 2.0, 1.0, 0.5, 0.2, 0.1]
    r = run_one(k, 60.0)
    tsr_est = r.ω * 0.77 / 11.0 * (2π/60)  # approximate
    println("k=$(round(k,digits=3))  P=$(round(r.P, digits=1)) kW  ω=$(round(r.ω, digits=1)) rpm  TSR≈$(round(tsr_est, digits=2))")
end
println()
println("Target: ω ≈ 210 rpm. If even k=0.1 can't reach 210 rpm, it's a TSR/aero limit, not a k problem.")
