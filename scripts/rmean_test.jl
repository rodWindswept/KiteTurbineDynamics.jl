#!/usr/bin/env julia
# rmean_test.jl — test k from r_mean-corrected law: k₀·λ²·(r_mean_ratio)³
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.54; const K0 = 15.6
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(k_val, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0/DT)
    Pr = Ref(0.0); wr = Ref(0.0); fr = Ref(Inf)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub*60/(2pi)
                fv = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]; !isnan(v) && !isinf(v) && v > 0 && push!(fv, v)
                end
                fr[] = isempty(fv) ? Inf : minimum(fv)
            end
        end)
    return (P=Pr[], ω=wr[], FoS=fr[])
end

println("r_mean-corrected k sweep — λ=0.54, ω_max=60")
println("k = K₀·λ²·(r_mean_ratio)³  with r_mean_ratio ≈ 0.84 → k ≈ 2.3–2.7")
println("Expected: ω ≈ 265 rpm, P ≈ 48 kW")
println("─"^60)

for k in [2.3, 2.5, 2.7, 2.0]
    r = run_one(k, 60.0)
    println("k=$(k)  P=$(round(r.P, digits=1)) kW  ω=$(round(r.ω, digits=1)) rpm  FoS=$(round(r.FoS, digits=2))")
end

# Also recheck gate one more time for consistency
println()
println("GATE recheck:")
sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
sys.k_mppt_ref[] = K0
wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
lift = KiteTurbineDynamics.rotary_lifter_default()
u = settle_to_operational_state(sys, copy(u0), p, 35.0; lift_device=lift, wind_fn=wf)
n = round(Int, 10.0/DT)
Pr = Ref(0.0); wr = Ref(0.0)
run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
    callback=(uc, tc, step) -> begin
        if step == n
            ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
            Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub*60/(2pi)
        end
    end)
println("Gate: P=$(round(Pr[], digits=1)) kW  ω=$(round(wr[], digits=1)) rpm  (target: 172.7 kW)")
