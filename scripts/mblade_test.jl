#!/usr/bin/env julia
# mblade_test.jl — re-run λ=0.69 with scaled m_blade
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const K0 = 15.6; const BS = 0.69
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(v_wind)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
    sys.k_mppt_ref[] = K0 * BS^2
    wf(pos, t) = begin z = max(pos[3], 1.0); [v_wind * (z / p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, 40.0; lift_device=lift, wind_fn=wf)
    n = round(Int, 10.0 / DT)
    Pr = Ref(0.0); wr = Ref(0.0); fr = Ref(Inf)
    run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                Pr[] = ef.base.P_kw; wr[] = ef.base.omega_hub * 60 / (2 * pi)
                fv = Float64[]
                for i in 2:length(ef.ring_fos)
                    val = ef.ring_fos[i]
                    if !isnan(val) && !isinf(val) && val > 0
                        push!(fv, val)
                    end
                end
                fr[] = isempty(fv) ? Inf : minimum(fv)
            end
        end)
    return (Pr[], wr[], fr[])
end

println("λ=0.69 with m_blade ∝ λ² (was unscaled)")
println("Wind   P(kW)   ω(rpm)  FoS")
println("─"^40)
for v in [11.0, 13.0, 15.0]
    r = run_one(v)
    println("$(Int(v)) m/s  $(round(r[1], digits=1))    $(round(r[2], digits=1))     $(round(r[3], digits=2))")
end
