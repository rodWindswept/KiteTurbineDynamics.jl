#!/usr/bin/env julia
# scripts/diagnose_tight_transient.jl
# Extended traces at k-refinement peaks to check V10 Tight t=57-59s instability.

using Printf, KiteTurbineDynamics
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt

const lift = KiteTurbineDynamics.rotary_lifter_default()

function trace(builder_fn, label, wind, k_val, T_sim)
    println("\n" * "="^75)
    println("$label @ $(wind) m/s, k=$k_val, T=$(T_sim)s  (T_VERIFY default: $(ControlMapHunt.T_VERIFY)s)")
    println("="^75)
    
    slices = ControlMapHunt.run_verify_timeseries(
        builder_fn, wind, k_val; verbose=false, lift_device=lift)
    
    if length(slices) >= 2
        println("  t(s)      P_kW     ω_rpm    min_FoS  n_fail")
        for s in slices
            @printf("  %5.1f  %8.1f  %7.0f  %8.2f  %5d\n",
                s.t_sim, s.P_kw, s.ω_rpm, s.min_fos, s.n_failing)
        end
        
        # Final 20s stability
        late = filter(s -> s.t_sim >= T_sim - 20.0, slices)
        if length(late) >= 2
            P_vals = [s.P_kw for s in late]
            ω_vals = [s.ω_rpm for s in late]
            P_mean = sum(P_vals)/length(P_vals)
            P_range = maximum(P_vals)-minimum(P_vals)
            ω_range = maximum(ω_vals)-minimum(ω_vals)
            P_norm_range = P_range / max(abs(P_mean), 0.1)
            @printf("\n  Final 20s: P_mean=%.0f kW  range/P=%.1f%%  ω_range=%.0f rpm\n", P_mean, P_norm_range*100, ω_range)
            if P_norm_range < 0.02 && ω_range < 5
                println("  ✓ STABLE")
            elseif P_norm_range > 0.15
                println("  ✗ UNSTABLE / OSCILLATING")
            else
                println("  ⚠ MARGINAL")
            end
        end
    end
end

# 1. V10 Tight @ 11 m/s — three k values around the spike region
builder_tight = ControlMapHunt.v10_tight_builder(blade_scale=1.0)
trace(builder_tight, "V10 Tight k=6.23 (spike)", 11.0, 6.23, 60.0)
trace(builder_tight, "V10 Tight k=12.94 (up)",   11.0, 12.94, 60.0)
trace(builder_tight, "V10 Tight k=3.0 (down)",   11.0, 3.0, 60.0)

# 2. Reinforced @ 15 — is its peak stable?
builder_reinf = ControlMapHunt.v10_tight_builder(
    r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)
trace(builder_reinf, "V10 Reinforced k=12.94", 15.0, 12.94, 60.0)

# 3. λ=0.69 @ 15 — is its peak stable?
builder_069 = ControlMapHunt.v10_tight_builder(blade_scale=0.69)
trace(builder_069, "λ=0.69 k=3.0", 15.0, 3.0, 60.0)

println("\n═══ Done ═══")
