#!/usr/bin/env julia
# final_test.jl — Correct blade-only scaling: trpt_hub fixed, rotor_radius scaled, settle reads k_mppt_ref
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0
const BS = 0.54; const K0 = 15.6  # Empirical V10 Tight k₀
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_one(name, blade_scale, k_val, ω_max)
    sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade_scale)
    sys.k_mppt_ref[] = k_val  # set BEFORE settle — settle now reads this ref
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

# ── GATE: λ=1.0, k=15.6 ── must be no-op ──
println("════════════════════════════════════════════════════")
println("GATE — λ=1.0, k=15.6, ω_max=35")
gate = run_one("Gate", 1.0, K0, 35.0)
println("  P=$(round(gate.P, digits=1)) kW  ω=$(round(gate.ω, digits=1)) rpm  FoS=$(round(gate.FoS, digits=2))")
println("  target: 172.7 kW, 210 rpm, FoS=2.53")

# ── λ=0.54, k ∝ λ² = 4.55, ω_max=60 ──
println()
println("════════════════════════════════════════════════════")
k_l2 = K0 * BS^2
println("λ=0.54 — k ∝ λ² = $(round(k_l2, digits=3)), ω_max=60")
r = run_one("λ=0.54", BS, k_l2, 60.0)
println("  P=$(round(r.P, digits=1)) kW  ω=$(round(r.ω, digits=1)) rpm  FoS=$(round(r.FoS, digits=2))")
println("  target: ~48 kW, ~210 rpm, FoS > 2.53")

# ── Verify P = k·ω³ consistency ──
ω_rad = r.ω * 2π / 60
P_check = k_l2 * ω_rad^3 / 1000
println("  P = k·ω³ check: $(round(P_check, digits=1)) kW (vs reported $(round(r.P, digits=1)) kW)")

# ── Summary ──
println()
println("════════════════════════════════════════════════════")
println("BUILDER FIXES APPLIED:")
println("  • trpt_hub_radius  = result.design.r_hub  (UNSCALED — ring geometry fixed)")
println("  • rotor_radius     = 5.0 × blade_scale   (hub aero disk scales)")
println("  • k_mppt (params)  = p_base.k_mppt × λ²  (blade-only law)")
println("  • settle uses k_mppt_ref[] (not p.k_mppt)")
println()
if gate.P > 160 && gate.P < 180 && gate.ω > 200 && gate.ω < 220
    println("✓ GATE PASSED — fixes are no-ops at λ=1.0")
else
    println("✗ GATE DRIFT — fix leaked into λ=1 path")
end
println("λ=0.54: P=$(round(r.P, digits=1)) kW  vs target ~48 kW  ω=$(round(r.ω, digits=1)) rpm vs ~210 rpm")
