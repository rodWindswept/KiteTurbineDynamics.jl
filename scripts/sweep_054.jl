#!/usr/bin/env julia
# sweep_054.jl — sweep k at blade_scale=0.54 to find the correct MPPT constant
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const T_SIM = 10.0; const V_WIND = 11.0; const BLADE_SCALE = 0.54
const K_XT = 15.6; const R_BASE = 1.425  # blade_tip_radius for V10 Tight
const T_SETTLE = 30.0  # settle time in seconds

include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

function sim_one(k_mppt)
    sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BLADE_SCALE)
    sys.k_mppt_ref[] = k_mppt

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
    lift = KiteTurbineDynamics.rotary_lifter_default()

    u = settle_to_operational_state(sys, copy(u0), p, T_SETTLE; lift_device=lift, wind_fn=wf)
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

    return (P=P_ref[], ω=w_ref[], FoS=f_ref[])
end

# k candidates — spanning λ^2 (4.55), λ^3 (2.45), λ^4 (1.33), λ^5 (0.72), and neighbors
k_candidates = [42.0, 35.0, 28.0, 21.0, 15.6, 12.0, 9.0, 7.0, 5.5, 4.55, 4.0, 3.5,
                 3.0, 2.45, 2.0, 1.6, 1.33, 1.1, 0.9, 0.72, 0.55, 0.4, 0.3, 0.2, 0.1]

println("Sweeping k at blade_scale=$BLADE_SCALE, wind=$V_WIND m/s, settle=$(T_SETTLE)s, sim=$(T_SIM)s")
println("k\tP (kW)\tω (rpm)\tFoS\tTSR\tNote")
println("─"^70)

results = []
for k_m in k_candidates
    r = sim_one(k_m)
    tip_speed = r.ω * (R_BASE * BLADE_SCALE) * (2π / 60)
    tsr = V_WIND > 0 ? tip_speed / V_WIND : 0.0
    
    note = if r.P > 50.0; "★★★"; elseif r.P > 40.0; "★★"; elseif r.P > 25.0; "★"; else "" end
    
    push!(results, (k=k_m, P=r.P, ω=r.ω, FoS=r.FoS, TSR=tsr, note=note))
    @printf("%.3f\t%.1f\t%.1f\t%.2f\t%.2f\t%s\n", k_m, r.P, r.ω, r.FoS, tsr, note)
end

# Find best
best_idx = argmax(r.P for r in results)
best = results[best_idx]
println("\n═════════════════════════════════════════════")
println("Best: k=$(round(best.k, digits=3)) → P=$(round(best.P, digits=1)) kW  ω=$(round(best.ω, digits=1)) rpm  FoS=$(round(best.FoS, digits=2))")
println("Baseline (λ=1.0): 172.7 kW  ω=210 rpm  FoS=2.53")

# Find closest to 50 kW
closest_50_idx = argmin(abs(r.P - 50.0) for r in results)
c50 = results[closest_50_idx]
ratio = c50.k / K_XT
exponent = log(ratio) / log(BLADE_SCALE)
println("\nClosest to 50 kW: k=$(round(c50.k, digits=3)) → P=$(round(c50.P, digits=1)) kW  ω=$(round(c50.ω, digits=1)) rpm")
println("k/k_xt = $(round(ratio, digits=4))  →  λ exponent ≈ $(round(exponent, digits=2))")

# Reference k values
println("\n--- Reference k values ---")
@printf("λ=1.0  k=%.1f   P=172.7 kW (gate)\n", K_XT)
@printf("λ²     k=%.3f\n", K_XT * BLADE_SCALE^2)
@printf("λ³     k=%.3f\n", K_XT * BLADE_SCALE^3)
@printf("λ⁵     k=%.3f\n", K_XT * BLADE_SCALE^5)
println("Target: P ≈ 50 kW (>30%) at ω ~389 rpm (1.85× baseline 210 rpm)")
