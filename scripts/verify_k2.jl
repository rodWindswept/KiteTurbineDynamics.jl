#!/usr/bin/env julia
# verify_k2.jl — print radius fields + test both k-scaling laws with ω_max=60
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.54
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(label, blade_scale, k_val, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
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
    return (label=label, P=Pr[], ω=wr[], FoS=fr[], 
            rotor_radius=p.rotor_radius, trpt_hub=p.trpt_hub_radius,
            k_mppt_param=p.k_mppt, blade_scale=blade_scale)
end

# ── 1. GATE: λ=1.0 — must reproduce, and reveal radius fields ──
println("════════════════════════════════════════════════════════════")
println("TEST 1 — GATE (λ=1.0, k=15.6, ω_max=35)")
gate = run_one("Gate", 1.0, 15.6, 35.0)
println("  P=$(round(gate.P, digits=1)) kW  ω=$(round(gate.ω, digits=1)) rpm  FoS=$(round(gate.FoS, digits=2))")
println("  p.rotor_radius    = $(gate.rotor_radius) m  (area = $(round(π*gate.rotor_radius^2, digits=1)) m²)")
println("  p.trpt_hub_radius = $(gate.trpt_hub) m  (area = $(round(π*gate.trpt_hub^2, digits=1)) m²)")
println("  p.k_mppt          = $(gate.k_mppt_param)")

# ── 2. λ=0.54, k ∝ λ² = 4.55, ω_max=60 ──
println()
println("════════════════════════════════════════════════════════════")
k_l2 = 15.6 * BS^2
println("TEST 2 — λ=0.54, k ∝ λ² = $(round(k_l2, digits=3)), ω_max=60")
r2 = run_one("k-λ²", BS, k_l2, 60.0)
println("  P=$(round(r2.P, digits=1)) kW  ω=$(round(r2.ω, digits=1)) rpm  FoS=$(round(r2.FoS, digits=2))")
println("  p.rotor_radius    = $(r2.rotor_radius) m")
println("  p.trpt_hub_radius = $(r2.trpt_hub) m")
println("  p.k_mppt          = $(r2.k_mppt_param)")

# ── 3. λ=0.54, k ∝ λ⁵ = 0.716, ω_max=60 (retest with headroom) ──
println()
println("════════════════════════════════════════════════════════════")
k_l5 = 15.6 * BS^5
println("TEST 3 — λ=0.54, k ∝ λ⁵ = $(round(k_l5, digits=3)), ω_max=60")
r3 = run_one("k-λ⁵", BS, k_l5, 60.0)
println("  P=$(round(r3.P, digits=1)) kW  ω=$(round(r3.ω, digits=1)) rpm  FoS=$(round(r3.FoS, digits=2))")

# ── Summary ──
println()
println("════════════════════════════════════════════════════════════")
println("SUMMARY (target: ~50 kW, ~389 rpm, FoS > 2.53)")
println("  Gate:   P=$(round(gate.P, digits=1)) kW  ω=$(round(gate.ω, digits=1)) rpm  (target 172.7 kW)")
println("  k ∝ λ²: P=$(round(r2.P, digits=1)) kW  ω=$(round(r2.ω, digits=1)) rpm")
println("  k ∝ λ⁵: P=$(round(r3.P, digits=1)) kW  ω=$(round(r3.ω, digits=1)) rpm")
println()
if r2.P > 40.0 && r2.FoS > 2.53
    println("✓  k ∝ λ² WORKS for blade-only scaling (ring radii unchanged)")
    println("   Fix: builder line 70 → le^2 (revert from my le^5 change)")
elseif r3.P > 40.0 && r3.FoS > 2.53
    println("✓  k ∝ λ⁵ works despite ring-fixed regime")
else
    println("  Neither law hits 50 kW. Physics or builder issue deeper than k-scaling.")
end
