#!/usr/bin/env julia
# scripts/k62_regression.jl
#
# Phase 2b Gate A: k=62 characterization of the corrected 12-gon.
# Protocol matches the campaign's own dynamic verification path
# (src/headless_verify.jl _build_verify_system + settle_to_operational_state):
#   - ALL rotors (no ground-adjacent drop) — the Jul 3 run tested all 4
#   - uniform wind [11, 0, 0] (no shear profile)
#   - no spokes, no lift device, blade_scale = 1.0
#   - sys.k_mppt_ref[] = 62.0 set BEFORE settle (current post-fix semantics)
#
# Historical anchor (scripts/results/v10_campaign_50kw/dynamic_verification.txt,
# Jul 3): P=12.1 kW, ω=55.6 rpm; FoS 0.43 (2026-06-28-control-first-design.md).
# NOTE: anchor predates the 70/30 blade-offset errata (Jul 5) and the
# settle/k_mppt-mismatch fix (Jul 4) → SOFT gate: same verdict & magnitude
# (P≈10–15 kW, ω≈50–60 rpm, FoS<1), not exact numbers.

using KiteTurbineDynamics, Printf, LinearAlgebra, Statistics
import KiteTurbineDynamics: SpokeParams

const WIND = 11.0
const K_TEST = 62.0
const OUT = joinpath(@__DIR__, "results", "control_maps", "k62_regression_12gon.txt")
mkpath(dirname(OUT))

log_lines = String[]
function logln(s::AbstractString)
    println(s)
    push!(log_lines, String(s))
    # progressive save — write everything so far on every line
    open(OUT, "w") do io
        foreach(l -> println(io, l), log_lines)
    end
end

githash = strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
logln("k=62 regression — corrected 12-gon (Gate A, soft)")
logln("git=$githash  date=$(string(Base.Libc.strftime(time())))")

# ── Build: fixed builder, keep ALL rotors (campaign verification had no drop) ──
sys, u0, p, label, design = build_v10_tight(keep_lowest=true)
sys.k_mppt_ref[] = K_TEST

logln("label: $label")
logln("── geometry fingerprint ──")
logln("n_lines=$(p.n_lines)  n_rings=$(p.n_rings)  n_blades_main=$(p.n_blades)  r_hub=$(round(design.r_hub,digits=3))  r_bot=$(round(design.r_bottom,digits=3))  hub_disk_R=$(round(sys.rotor.radius,digits=3))  tether=$(round(design.tether_length,digits=2))")
tot_area = 0.0
for (i, er) in enumerate(sys.expansion_rotors)
    span = er.blade_tip_radius - er.blade_hub_radius
    area = er.n_blades * er.blade_chord * span
    global tot_area += area
    logln(@sprintf("  rotor %d @sysring %d: %d blades  tip=%.3f hub=%.3f chord=%.3f span=%.3f area=%.2f m²  er.mass=%.3f kg (NON-DYNAMIC)",
        i, er.ring_id, er.n_blades, er.blade_tip_radius, er.blade_hub_radius,
        er.blade_chord, span, area, er.mass))
end
logln(@sprintf("  total expansion blade area = %.2f m²  main rotor mass = %.2f kg (n_blades·m_blade, dynamic)",
    tot_area, p.n_blades * p.m_blade))
logln("k_mppt_ref set to $(sys.k_mppt_ref[]) BEFORE settle (raw k, no λ² — post-fix semantics)")

# ── Campaign protocol: uniform wind, gravity settle, operational settle ──
wf(pos, t) = [WIND, 0.0, 0.0]

logln("gravity settle (20000 steps)...")
u_grav = settle_to_equilibrium(sys, copy(u0), p; wind_fn=nothing, n_steps=20000)
logln("gravity settle done. operational settle (ω_init=9.5)...")
u_op = settle_to_operational_state(sys, u_grav, p, 9.5; wind_fn=wf, lift_device=nothing)

N = sys.n_total
Nr = sys.n_ring
omega_idx = 3 * N + 1
ω_vals = abs.(u_op[omega_idx:(omega_idx + Nr - 1)])
ω_mean = mean(ω_vals)
P_settle = K_TEST * ω_mean^3

logln(@sprintf("settled: ω_mean=%.3f rad/s (%.1f rpm)  P=k·ω³=%.2f kW", ω_mean, ω_mean * 60 / (2π), P_settle / 1000))

# ── FoS via capture_extended at the settled state ──
ef = capture_extended(u_op, sys, p, 0.0, wf, nothing; brake_engaged=sys.brake_engaged[])
airborne = Float64[]
for i in 2:length(ef.ring_fos)
    v = ef.ring_fos[i]
    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
end
fos = isempty(airborne) ? Inf : minimum(airborne)
ω_hub_rpm = ef.base.omega_hub * 60 / (2π)

logln("── RESULT ──")
logln(@sprintf("P_capture=%.1f kW  ω_hub=%.1f rpm  min airborne FoS=%.2f  T_max=%.2f kN",
    ef.base.P_kw, ω_hub_rpm, fos, ef.base.T_max / 1000))
logln("anchor (Jul 3, pre-70/30 + pre-settle-fix): P=12.1 kW  ω=55.6 rpm  FoS=0.43")
va = 10.0 <= ef.base.P_kw <= 15.0
vb = 50.0 <= ω_hub_rpm <= 60.0
vc = fos < 1.0
logln("Gate A (soft): P in 10–15 kW → $(va ? "✓" : "✗")   ω in 50–60 rpm → $(vb ? "✓" : "✗")   FoS<1 → $(vc ? "✓" : "✗")")
logln(va && vb && vc ? "GATE A PASS (same verdict & magnitude)" : "GATE A DEVIATION — attribute deltas to Jul 4/5 physics fixes and record")
