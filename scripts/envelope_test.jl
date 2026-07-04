#!/usr/bin/env julia
# envelope_test.jl — λ=0.69 and λ=0.79 at 11, 13, 15 m/s
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const K0 = 15.6
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_point(blade_scale, v_wind, k_val, ω_max, T_settle, T_sim)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val
    wf(pos, t) = begin z = max(pos[3], 1.0); [v_wind*(z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), p, ω_max; lift_device=lift, wind_fn=wf)
    n = round(Int, T_sim/DT)
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

function test_design(blade_scale, label)
    k = K0 * blade_scale^2
    ω_max = 40.0
    println("\n═══════════════════════════════════════════════")
    println("$label  λ=$blade_scale  k=$(round(k, digits=1))")
    println("  Wind   P(kW)   ω(rpm)  FoS    P≥50?  FoS≥1.5?")
    println("  " * "─"^55)
    for v in [11.0, 13.0, 15.0]
        r = run_point(blade_scale, v, k, ω_max, 30.0, 10.0)
        p_ok = r.P >= 50.0 ? "✓" : "✗"
        fos_ok = r.FoS >= 1.5 ? "✓" : "✗"
        println("  $(Int(v)) m/s  $(round(r.P, digits=1))    $(round(r.ω, digits=1))     $(round(r.FoS, digits=2))    $p_ok      $fos_ok")
    end
end

test_design(0.69, "λ=0.69 (50 kW target)")
test_design(0.79, "λ=0.79 (96 kW at 11 m/s)")
