#!/usr/bin/env julia
# disc_test.jl — discriminating test: seed settle with correct ω_rated_max for λ=0.54
# If k=0.72 works when settle can FIND the MPPT point → purely a spin-up/controller problem
# If it decays even from the right ω → real physics issue

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BLADE_SCALE = 0.54
const K_XT = 15.6; const R_BASE = 1.425

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function run_test(name, k_mppt, ω_rated_max, T_settle, T_sim)
    sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BLADE_SCALE)
    sys.k_mppt_ref[] = k_mppt

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    lift = KiteTurbineDynamics.rotary_lifter_default()

    println("  settle(ω_max=$(ω_rated_max) rad/s, $(T_settle)s)...")
    u = settle_to_operational_state(sys, copy(u0), p, ω_rated_max; lift_device=lift, wind_fn=wf)
    n_steps = round(Int, T_sim / DT)

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

    return (name=name, P=P_ref[], ω=w_ref[], FoS=f_ref[])
end

# ── Test 1: Correct ω_rated_max for λ=0.54 (40.8 rad/s ≈ 390 rpm) ──
println("═"^70)
println("TEST 1: λ=0.54, k=0.716, ω_rated_max=42.0 rad/s  (correct seed)")
r1 = run_test("T1-correct-omega", 0.716, 42.0, 30.0, 10.0)
println("  → P=$(round(r1.P, digits=1)) kW  ω=$(round(r1.ω, digits=1)) rpm  FoS=$(round(r1.FoS, digits=2))\n")

# ── Test 2: Same k but ω_rated_max=9.5 (the bug; should reproduce 0.1 kW) ──
println("═"^70)
println("TEST 2: λ=0.54, k=0.716, ω_rated_max=9.5 rad/s  (wrong seed = stall trap)")
r2 = run_test("T2-wrong-omega", 0.716, 9.5, 30.0, 10.0)
println("  → P=$(round(r2.P, digits=1)) kW  ω=$(round(r2.ω, digits=1)) rpm  FoS=$(round(r2.FoS, digits=2))\n")

# ── Test 3: Gate (λ=1.0) with correct ω_rated_max=35 to show it still works ──
println("═"^70)
println("TEST 3: λ=1.0, k=15.6, ω_rated_max=35.0 rad/s  (control — gate still passes?)")
sys3, u03, p3, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
sys3.k_mppt_ref[] = 15.6
wf3(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p3.h_ref)^(1/7), 0.0, 0.0] end
lift3 = KiteTurbineDynamics.rotary_lifter_default()
u3 = settle_to_operational_state(sys3, copy(u03), p3, 35.0; lift_device=lift3, wind_fn=wf3)
n3 = round(Int, 10.0/DT)
P3r = Ref(0.0); w3r = Ref(0.0)
run_canonical_sim!(u3, sys3, p3, wf3, n3, DT; lift_device=lift3, lin_damp=0.05,
    callback=(u_curr, t_curr, step) -> begin
        if step == n3
            ef = capture_extended(u_curr, sys3, p3, t_curr, wf3, lift3; brake_engaged=sys3.brake_engaged[])
            P3r[] = ef.base.P_kw
            w3r[] = ef.base.omega_hub * 60 / (2 * pi)
        end
    end)
println("  → P=$(round(P3r[], digits=1)) kW  ω=$(round(w3r[], digits=1)) rpm  (gate target: 172.7 kW, 210 rpm)\n")

# ── Verdict ──
println("═"^70)
println("VERDICT:")
if r1.P > 30.0
    println("  ✓  λ=0.54 with correct ω_max runs at P≈$(round(r1.P, digits=0)) kW")
    println("  →  Physics is fine. 0.1 kW result was a stall basin trap from undershot ω_rated_max.")
    println("  →  The settle scan started at 9.5 rad/s, never reached the MPPT region at ~41 rad/s.")
    println("  →  Fix: pass ω_rated_max = rated_ω * (1/BLADE_SCALE) for blade-scaled systems.")
else
    println("  ✗  λ=0.54 decays even with correct ω_max → real physics problem to investigate.")
end
