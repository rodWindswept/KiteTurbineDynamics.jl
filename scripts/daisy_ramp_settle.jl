#!/usr/bin/env julia
# Daisy ramp-by-settle test — uses settle_to_operational_state chunks
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "daisy_builder.jl"))

sys, u0, p, _, _ = build_daisy(blade_scale=1.0)
wf(pos,t) = [11.0, 0.0, 0.0]
DT = 4e-5

sys.k_mppt_ref[] = 0.001
u = copy(u0)

ctrl = RampController(; P_target=p.p_rated_w, ω_idle=0.1)
KiteTurbineDynamics.init_geometry!(ctrl, sys, p)

println("Ramp-by-settle (2s chunks)...")
for chunk in 1:120
    global u
    u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u), p, 2.0; wind_fn=wf)

    ef = KiteTurbineDynamics.capture_extended(u, sys, p, chunk*2.0, wf, nothing; brake_engaged=false)
    sf = KiteTurbineDynamics.capture_frame(u, sys, p, chunk*2.0, wf, nothing)
    mf = KiteTurbineDynamics.min_ring_fos(u, sys, p)
    cm = KiteTurbineDynamics.min_collapse_margin(u, sys, ctrl)
    KiteTurbineDynamics.update_ramp!(ctrl, sys, sf, DT; min_fos=mf, collapse_margin_deg=cm)

    if chunk % 10 == 0 || ctrl.state === KiteTurbineDynamics.HOLDING
        println(@sprintf("  t=%4ds  %-25s  P=%.0fW  ω=%.0frpm  k=%.4f  FoS=%.1f",
            chunk*2, KiteTurbineDynamics.state_label(ctrl), ef.base.P_kw*1000,
            ef.base.omega_hub*60/(2π), sys.k_mppt_ref[], mf))
    end

    if ctrl.state === KiteTurbineDynamics.HOLDING
        println("✓ HOLDING at t=$(chunk*2)s")
        break
    end
end

ef = KiteTurbineDynamics.capture_extended(u, sys, p, 240.0, wf, nothing; brake_engaged=false)
println()
@printf("P = %.0f W  ω = %.0f rpm  k = %.4f\n",
    ef.base.P_kw*1000, ef.base.omega_hub*60/(2π), sys.k_mppt_ref[])
@printf("vs Tulloch 1400 W: Δ = %.0f%%\n", (ef.base.P_kw*1000/1400 - 1)*100)
