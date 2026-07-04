#!/usr/bin/env julia
# per_rotor.jl — isolate hub vs expansion rotor power contributions at λ=0.54, k=2.3
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.54; const KVAL = 2.3
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
sys.k_mppt_ref[] = KVAL
wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
lift = KiteTurbineDynamics.rotary_lifter_default()
u = settle_to_operational_state(sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf)
n = round(Int, 10.0/DT)

ef_ref = Ref{Any}(nothing)
run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
    callback=(uc, tc, step) -> begin
        if step == n
            ef_ref[] = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
        end
    end)

ef = ef_ref[]
println("═══════════════════════════════════════════════")
println("Gate (λ=1.0): 193.2 kW, 221.7 rpm")
println("λ=0.54, k=$KVAL: P=$(round(ef.base.P_kw, digits=1)) kW, ω=$(round(ef.base.omega_hub*60/(2pi), digits=1)) rpm")
println()

# Per-rotor breakdown
n_rotors = length(ef.rotor_labels)
println("Per-rotor power (aero → ground):")
for i in 1:n_rotors
    println("  $(ef.rotor_labels[i]): aero=$(round(ef.rotor_aero_power[i]/1000, digits=1)) kW  ground=$(round(ef.rotor_ground_power[i]/1000, digits=1)) kW  ω=$(round(ef.rotor_omega[i]*60/(2pi), digits=1)) rpm")
end

println()
println("Sum rotor ground: $(round(sum(ef.rotor_ground_power)/1000, digits=1)) kW")
println("Total GEN ELEC:   $(round(ef.base.P_kw, digits=1)) kW")

# Expansion rotor geometry detail
println("Expansion rotor effective radii:")
for i in 1:length(sys.expansion_rotors)
    er = sys.expansion_rotors[i]
    ring_idx = er.ring_idx
    # ring_radii from sys.effective_radii
    r_nom = ring_idx <= length(sys.effective_radii) ? sys.effective_radii[ring_idx] : NaN
    r_mean_annulus = (er.blade_hub_radius + er.blade_tip_radius) / 2
    r_mean = r_nom + r_mean_annulus * cosd(er.bank_angle_deg)
    println("  Rotor $i: r_nom=$(round(r_nom, digits=3))m  blade_mean=$(round(r_mean_annulus, digits=3))m  r_mean=$(round(r_mean, digits=3))m  bank=$(er.bank_angle_deg)°")
end

# λ=1.0 comparison: what were the expansion rotor dimensions?
println()
println("λ=1.0 expansion rotor ref:")
# From V10 Tight best_design.json: blade_tip=1.425, blade_hub≈0.281
r_tip_1 = 1.425
r_hub_1 = 0.281
r_mean_annulus_1 = (r_tip_1 + r_hub_1) / 2
area_per_1 = π * (r_tip_1^2 - r_hub_1^2)
println("  r_tip=$(r_tip_1)m  r_hub=$(r_hub_1)m  annulus=$(round(r_mean_annulus_1, digits=3))m  area=$(round(area_per_1, digits=2))m²")

r_tip_054 = 1.425 * BS
r_hub_054 = 0.281 * BS
area_per_054 = π * (r_tip_054^2 - r_hub_054^2)
println("  r_tip(λ=0.54)=$(round(r_tip_054, digits=3))m  r_hub(λ=0.54)=$(round(r_hub_054, digits=3))m  area=$(round(area_per_054, digits=2))m²")
println("  Area ratio: $(round(area_per_054/area_per_1, digits=3))  (λ² = $(round(BS^2, digits=3)))")
