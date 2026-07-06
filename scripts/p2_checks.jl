#!/usr/bin/env julia
# P2 checks: determinism, R1 timeseries flatness, Tight@13 refinement
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
using KiteTurbineDynamics
using Printf

const lift = KiteTurbineDynamics.rotary_lifter_default()

# ═══════════════════════════════════════════════════════════════════
# 1. Determinism check — R3 at k=6.23, run twice
# ═══════════════════════════════════════════════════════════════════
println("═══ 1. DETERMINISM CHECK: R3 λ=0.69 @ 15 m/s, k=6.23, 2× 60s verify ═══")
builder_r3 = ControlMapHunt.v10_tight_builder(blade_scale=0.69)

s1 = ControlMapHunt.run_verify_timeseries(builder_r3, 15.0, 6.23; verbose=false, lift_device=lift)
s2 = ControlMapHunt.run_verify_timeseries(builder_r3, 15.0, 6.23; verbose=false, lift_device=lift)

p1, p2 = s1[end].P_kw, s2[end].P_kw
ΔP_rel = abs(p1 - p2) / max(abs(p1), 0.01)
f1, f2 = s1[end].min_fos, s2[end].min_fos
ω1, ω2 = s1[end].ω_rpm, s2[end].ω_rpm

@printf("  Run 1: P=%.3f kW  ω=%.1f rpm  FoS=%.4f\n", p1, ω1, f1)
@printf("  Run 2: P=%.3f kW  ω=%.1f rpm  FoS=%.4f\n", p2, ω2, f2)
@printf("  ΔP_rel = %.4f%%  (spec: <0.1%%)\n", ΔP_rel * 100)
if ΔP_rel <= 0.001
    println("  ✓ DETERMINISM PASSED")
else
    println("  ✗ DETERMINISM FAILED — run-to-run noise is the problem, not grid coarseness")
end

# ═══════════════════════════════════════════════════════════════════
# 2. R1 timeseries flatness — Tight @ 11 m/s, k=6.23
# ═══════════════════════════════════════════════════════════════════
println("\n═══ 2. R1 TIMESERIES: V10 Tight @ 11 m/s, k=6.23, 60s verify ═══")
builder_r1 = ControlMapHunt.v10_tight_builder(blade_scale=1.0)
slices = ControlMapHunt.run_verify_timeseries(builder_r1, 11.0, 6.23; verbose=false, lift_device=lift)

println("  t(s)      P_kW     ω_rpm    FoS")
for s in slices
    @printf("  %5.1f  %8.1f  %7.0f  %6.2f\n", s.t_sim, s.P_kw, s.ω_rpm, s.min_fos)
end

# Check P(t) flatness over final 20s (t ≥ 40s)
late_slices = filter(s -> s.t_sim >= 40.0, slices)
if length(late_slices) >= 2
    P_late = [s.P_kw for s in late_slices]
    P_range = maximum(P_late) - minimum(P_late)
    P_drift = (P_late[end] - P_late[1]) / P_late[1] * 100
    @printf("\n  Final 20s: P ∈ [%.1f, %.1f] kW  range=%.2f kW  drift=%.2f%%\n",
        minimum(P_late), maximum(P_late), P_range, P_drift)
    if abs(P_drift) < 1.0 && P_range < 5.0
        println("  ✓ P(t) flat — steady state reached")
    else
        println("  ✗ P(t) still drifting — not at steady state")
    end
end

# Dual-duration check: last slice vs slice at ~15s (if available)
if length(slices) >= 2
    mid = argmin(abs.([s.t_sim - 15.0 for s in slices]))
    if mid > 1
        P_mid = slices[mid].P_kw
        P_end = slices[end].P_kw
        δ = abs(P_end - P_mid)
        @printf("  Dual-duration: P(%.0fs)=%.1f  P(%.0fs)=%.1f  Δ=%.1f kW (pass <0.5kW: %s)\n",
            slices[mid].t_sim, P_mid, slices[end].t_sim, P_end, δ, δ < 0.5 ? "✓" : "✗")
    end
end

# ═══════════════════════════════════════════════════════════════════
# 3. Tight @ 13 m/s — sample downward from current k=26.87
# ═══════════════════════════════════════════════════════════════════
println("\n═══ 3. TIGHT @ 13 m/s REFINEMENT ═══")
ks_13 = [3.0, 6.23, 12.94, 16.51, 21.06, 26.87]
println("  Sampling k ∈ [$(ks_13[1]), $(ks_13[end])]")

for k in ks_13
    t0 = time()
    slices_13 = ControlMapHunt.run_verify_timeseries(builder_r1, 13.0, k; verbose=false, lift_device=lift)
    s = slices_13[end]
    elapsed = round(time() - t0, digits=0)
    @printf("  k=%.2f  P=%.1f kW  ω=%.0f rpm  FoS=%.2f  fail=%d/21  (%ds)\n",
        k, s.P_kw, s.ω_rpm, s.min_fos, s.n_failing, elapsed)

    open(joinpath(@__DIR__, "results", "control_maps", "k_refine_tight_13.csv"), "a") do io
        write(io, @sprintf("%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%.14f,%d\n",
            k, s.P_kw, s.ω_rpm, s.min_fos, s.collapse_margin_deg,
            s.max_twist_deg, s.T_max_kN, s.P_aero_kw, s.n_failing))
    end
end

println("\n═══ ALL CHECKS COMPLETE ═══")
