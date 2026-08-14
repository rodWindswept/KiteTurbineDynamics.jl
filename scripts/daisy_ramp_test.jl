#!/usr/bin/env julia
# Daisy ramp test V4 — matching dashboard settle protocol
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "daisy_builder.jl"))

const V_WIND = 11.0
const DT = 4e-5

println("══════════════════════════════════════════════════════")
println("Daisy Ramp Test V4 — Dashboard Protocol, 11 m/s")
println("══════════════════════════════════════════════════════")
println()

sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
wf(pos, t) = [V_WIND, 0.0, 0.0]
lift_dev = KiteTurbineDynamics.rotary_lifter_default()

# ── Dashboard-style settle (matching interactive_dashboard.jl:472) ────
println("Settle with lift device (matching dashboard)...")
u = KiteTurbineDynamics.settle_to_operational_state(
    sys, copy(u0), p, 9.5; lift_device=lift_dev, wind_fn=wf
)

ef0 = KiteTurbineDynamics.capture_extended(u, sys, p, 0.0, wf, lift_dev; brake_engaged=false)
println(@sprintf("  Post-settle: P=%.0f W  ω=%.0f rpm  k=%.4f",
    ef0.base.P_kw*1000, ef0.base.omega_hub*60/(2π), sys.k_mppt_ref[]))
println()

# ── Quick ODE stability check (2s) ──────────────────────────────────
println("ODE stability check (2s)...")
run_canonical_sim!(u, sys, p, wf, round(Int, 2.0/DT), DT; lin_damp=0.05, lift_device=lift_dev)
ef1 = KiteTurbineDynamics.capture_extended(u, sys, p, 2.0, wf, lift_dev; brake_engaged=false)
println(@sprintf("  Post-ODE 2s: P=%.0f W  ω=%.0f rpm",
    ef1.base.P_kw*1000, ef1.base.omega_hub*60/(2π)))
if ef1.base.omega_hub*60/(2π) > 100
    println("  ✓ System holds!")
else
    println("  ✗ Still collapsing — ω=$(round(ef1.base.omega_hub*60/(2π))) rpm")
end
println()

# ── Ramp Controller ──────────────────────────────────────────────────
println("Starting RampController...")
ctrl = RampController(; P_target=p.p_rated_w, ω_idle=0.1)
KiteTurbineDynamics.init_geometry!(ctrl, sys, p)

const CHUNK_S = 2.0
const CHUNK_STEPS = round(Int, CHUNK_S / DT)
const MAX_CHUNKS = 80

t_cum = 0.0
chunks_used = 0
holding_reached = false

for chunk in 1:MAX_CHUNKS
    global t_cum, chunks_used, holding_reached
    run_canonical_sim!(u, sys, p, wf, CHUNK_STEPS, DT; lin_damp=0.05, lift_device=lift_dev)
    t_cum += CHUNK_S
    chunks_used += 1

    sf = KiteTurbineDynamics.capture_frame(u, sys, p, t_cum, wf, lift_dev)
    mf = KiteTurbineDynamics.min_ring_fos(u, sys, p)
    cm = KiteTurbineDynamics.min_collapse_margin(u, sys, ctrl)
    KiteTurbineDynamics.update_ramp!(ctrl, sys, sf, DT; min_fos=mf, collapse_margin_deg=cm)

    if chunk % 5 == 0 || ctrl.state === KiteTurbineDynamics.HOLDING
        ef = KiteTurbineDynamics.capture_extended(u, sys, p, t_cum, wf, lift_dev; brake_engaged=false)
        println(@sprintf("  t=%5.1fs  %-25s  P=%.0fW  ω=%.0frpm  k=%.4f  FoS=%.1f",
            t_cum, KiteTurbineDynamics.state_label(ctrl), ef.base.P_kw*1000,
            ef.base.omega_hub*60/(2π), sys.k_mppt_ref[], mf))
    end

    if ctrl.state === KiteTurbineDynamics.HOLDING
        holding_reached = true
        break
    end
end

if !holding_reached
    println("⚠ Ramp did not reach HOLDING after $chunks_used chunks ($(t_cum)s)")
end
println()

# ── Scoring window ────────────────────────────────────────────────────
println("Scoring window (60s)...")
const WINDOW_S = 60.0
const WINDOW_N = round(Int, WINDOW_S / DT)
const SAMPLE_EVERY = round(Int, 1.0 / DT)

P_samples = Float64[]
fos_samples = Float64[]
ω_samples = Float64[]
k_samples = Float64[]

run_canonical_sim!(u, sys, p, wf, WINDOW_N, DT;
    lin_damp=0.05, lift_device=lift_dev,
    callback=(uc, tc, s) -> begin
        if s % SAMPLE_EVERY == 0
            ef = KiteTurbineDynamics.capture_extended(uc, sys, p, tc, wf, lift_dev; brake_engaged=false)
            push!(P_samples, ef.base.P_kw * 1000)
            push!(ω_samples, ef.base.omega_hub * 60 / (2π))
            push!(k_samples, sys.k_mppt_ref[])
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            push!(fos_samples, isempty(airborne) ? Inf : minimum(airborne))
            sf = KiteTurbineDynamics.capture_frame(uc, sys, p, tc, wf, lift_dev)
            mf2 = KiteTurbineDynamics.min_ring_fos(uc, sys, p)
            cm2 = KiteTurbineDynamics.min_collapse_margin(uc, sys, ctrl)
            KiteTurbineDynamics.update_ramp!(ctrl, sys, sf, DT; min_fos=mf2, collapse_margin_deg=cm2)
        end
    end)

# ── Results ────────────────────────────────────────────────────────────
if isempty(P_samples)
    println("⚠ No samples — system stalled")
    exit(1)
end

P_mean = mean(P_samples)
P_min  = minimum(P_samples)
P_max  = maximum(P_samples)
P_swing = P_mean > 0.1 ? (P_max - P_min) / P_mean : 0.0
FoS_min = minimum(fos_samples)
ω_mean = mean(ω_samples)
k_mean = mean(k_samples)

println()
println("═══ RESULTS ═══")
@printf("  P_mean = %.0f W  (%.0f–%.0f, swing=%.0f%%)\n", P_mean, P_min, P_max, P_swing*100)
@printf("  FoS    = %.1f\n", FoS_min)
@printf("  ω_mean = %.0f rpm  λ = %.1f\n", ω_mean, ω_mean*(2π/60)*p.rotor_radius/V_WIND)
@printf("  k_mean = %.4f\n", k_mean)
@printf("  P/Avg  = %.2f\n", P_max/P_mean)
println()
println("═══ vs TULLOCH ═══")
@printf("  Tulloch 11 m/s: 1400 W\n")
@printf("  Daisy sweep:    1062 W (−24%%)\n")
@printf("  Ramp:           %.0f W (%.0f%%)\n", P_mean, (P_mean/1400 - 1)*100)
