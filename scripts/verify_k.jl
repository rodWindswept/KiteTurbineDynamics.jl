#!/usr/bin/env julia
# verify_k.jl — test k ∝ λ² (correct for blade-only scaling) vs k ∝ λ⁵ (full geometric)
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.54
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(name, k_val, ω_max)
    sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
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
                    v = ef.ring_fos[i]
                    !isnan(v) && !isinf(v) && v > 0 && push!(fv, v)
                end
                fr[] = isempty(fv) ? Inf : minimum(fv)
            end
        end)
    println("  $name: P=$(round(Pr[], digits=1)) kW  ω=$(round(wr[], digits=1)) rpm  FoS=$(round(fr[], digits=2))")
    return (P=Pr[], ω=wr[], FoS=fr[])
end

println("Blade-only scaling (ring radii fixed) — correct law: k ∝ λ²")
println("─"^60)
k_l2 = 15.6 * BS^2
r2 = run_one("k ∝ λ² = $(round(k_l2, digits=3))  ω_max=42", k_l2, 42.0)

k_l5 = 15.6 * BS^5
println()
r5 = run_one("k ∝ λ⁵ = $(round(k_l5, digits=3))  ω_max=42  (retest)", k_l5, 42.0)

println()
println("─"^60)
println("Target: ~50 kW, ~389 rpm")
println("k ∝ λ² (blade-only):   P=$(round(r2.P, digits=1)) kW  ω=$(round(r2.ω, digits=1)) rpm")
println("k ∝ λ⁵ (full geom):    P=$(round(r5.P, digits=1)) kW  ω=$(round(r5.ω, digits=1)) rpm")

# Which scaling law?
# For full geometric scaling (all dims × λ): P ∝ λ², ω ∝ 1/λ, k ∝ λ⁵
# For blade-only scaling (ring radii fixed): P ∝ λ^(-1), ω ∝ 1/λ, k ∝ λ²
# Builder does blade-only → k should be ∝ λ²

if r2.P > 40.0
    println("\n✓  k ∝ λ² matches: P=$(round(r2.P, digits=1)) kW ≈ 50 kW target")
    println("   Fix: update builder line 70 from `le^5` to `le^2`")
else
    println("\n  Neither law reached 50 kW. Need to investigate further.")
end
