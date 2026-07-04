#!/usr/bin/env julia
# disc_test2.jl — after builder fixes: gate + λ=0.54 with correct ω_rated_max
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(name, blade_scale, ω_rated_max, k_override, T_settle=30.0, T_sim=10.0)
    sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    if k_override > 0
        sys.k_mppt_ref[] = k_override
    end
    wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND * (z/p.h_ref)^(1/7), 0.0, 0.0] end
    lift = KiteTurbineDynamics.rotary_lifter_default()
    
    u = settle_to_operational_state(sys, copy(u0), p, ω_rated_max; lift_device=lift, wind_fn=wf)
    n_steps = round(Int, T_sim / DT)
    
    P_ref = Ref(0.0); w_ref = Ref(0.0); f_ref = Ref(Inf)
    run_canonical_sim!(u, sys, p, wf, n_steps, DT; lift_device=lift, lin_damp=0.05,
        callback=(uc, tc, step) -> begin
            if step == n_steps
                ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
                P_ref[] = ef.base.P_kw; w_ref[] = ef.base.omega_hub * 60 / (2 * pi)
                fv = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    !isnan(v) && !isinf(v) && v > 0 && push!(fv, v)
                end
                f_ref[] = isempty(fv) ? Inf : minimum(fv)
            end
        end)
    
    println("  $name → P=$(round(P_ref[], digits=1)) kW  ω=$(round(w_ref[], digits=1)) rpm  FoS=$(round(f_ref[], digits=2))")
    return (P=P_ref[], ω=w_ref[], FoS=f_ref[])
end

# ── Gate: λ=1.0, k=15.6, ω_max sensible ──
println("═"^70)
println("GATE: λ=1.0, k=15.6  (should be ~172.7 kW, ~210 rpm, FoS~2.53)")
r1 = run_one("Gate", 1.0, 35.0, 15.6)

# ── λ=0.54: correct ω_max = 210/0.54*2π/60 ≈ 40.8 rad/s ──
println()
println("═"^70)
println("λ=0.54: k=$(round(15.6*0.54^5, digits=3)), ω_max=42 rad/s")
r2 = run_one("λ=0.54", 0.54, 42.0, 0.0)  # k_override=0 → use builder's k ∝ λ⁵

# ── Also try with a k-ramp approach: start with low k, let it spin up ──
println()
println("═"^70)
println("λ=0.54: k=2.0 (low k to help spin-up), ω_max=42")
r3 = run_one("λ=0.54 k-low", 0.54, 42.0, 2.0)

println()
println("═"^70)
println("SUMMARY:")
println("  Gate:  P=$(round(r1.P, digits=1)) kW  vs target 172.7 kW ($(round(r1.P/172.7*100, digits=1))%)")
println("  λ=0.54: P=$(round(r2.P, digits=1)) kW  vs target ~50 kW  ω=$(round(r2.ω, digits=1)) rpm vs ~389 rpm")
println("  λ=0.54 low-k: P=$(round(r3.P, digits=1)) kW  ω=$(round(r3.ω, digits=1)) rpm")
println()
println("Builder now: hub 0.54×, blades 0.54×, k ∝ λ⁵, settle uses correct ω_max")
