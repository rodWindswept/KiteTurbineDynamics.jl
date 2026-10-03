#!/usr/bin/env julia
# scratch/sv_probe_b5_build.jl — software-validator, 2026-10-02
#
# WHY: test/test_evaluator_v13.jl's B5 builds its settled unit state with
#   build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p)
# i.e. WITHOUT `beam_sizing` and WITHOUT `min_wall_m`.  The evaluator builds the
# SAME genome at objective_evaluator.jl:692-700 WITH both:
#   sizing = size_beams_closed_form(result, p, cfg)
#   build_system_from_v10(...; min_wall_m=cfg.min_wall_m, beam_sizing=sizing)
# and `beam_sizing === nothing` selects the legacy uniform `design.t_over_D`
# ring tube instead of the R7 closed-form per-ring section (:459-463).
# Twist ratio is a torsional-stiffness quantity, so the two states need not
# agree.  This probe measures the structural difference directly — no ODE.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_b5_build.jl

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const PW = KW * 1000.0
const L18 = 18.8

p = params_at_length(params_daisy(), L18, KW)
x = seed_genome(5.0)
xr = copy(x)
if length(xr) >= 14
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
else
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
end

dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)

cfg = KTD.ObjectiveConfig(;
    k_mppt=K_MPPT_5KW_HONEST, power_W=PW, v_rated=11.0,
    p_floor_kw=5.0, p_ceiling_kw=5.0, relax_s=5.0, window_s=20.0,
    fos_target=2.5, fos_hard=2.5, power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0, rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW, tether_diameter=p.tether_diameter,
)
sizing = KTD.size_beams_closed_form(dec, p, cfg)

# A = B5's build (test side);  B = the evaluator's build (:692-700)
sysA, _, _ = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p)
sysB, _, _ = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p,
    min_wall_m=cfg.min_wall_m, beam_sizing=sizing)

println("─"^72)
@printf("cfg.min_wall_m = %.4f m   sizing.t_over_D = %.4f   design.t_over_D = %.4f\n",
    cfg.min_wall_m, sizing.t_over_D, dec.design.t_over_D)
@printf("rings: A=%d B=%d   nodes: A=%d B=%d\n", sysA.n_ring, sysB.n_ring, sysA.n_total, sysB.n_total)
@printf("ring_mass_total: A=%.4f kg   B=%.4f kg   (Δ %+.4f kg, %.2f%%)\n",
    sysA.ring_mass_total[], sysB.ring_mass_total[], sysB.ring_mass_total[] - sysA.ring_mass_total[],
    100 * (sysB.ring_mass_total[] - sysA.ring_mass_total[]) / sysA.ring_mass_total[])
@printf("ring_knuckle_mass: A=%.4f  B=%.4f\n", sysA.ring_knuckle_mass[], sysB.ring_knuckle_mass[])
println("per-ring Do (m):")
doa = sysA.ring_Do_per_ring[]
dob = sysB.ring_Do_per_ring[]
@printf("  A (B5 build)  : %s\n", join([@sprintf("%.4f", v) for v in doa], " "))
@printf("  B (evaluator) : %s\n", join([@sprintf("%.4f", v) for v in dob], " "))
ra = [(sysA.nodes[id]::RingNode).radius for id in sysA.ring_ids]
rb = [(sysB.nodes[id]::RingNode).radius for id in sysB.ring_ids]
@printf("  radii identical: %s   max|Δradius| = %.3e m\n", ra == rb, maximum(abs.(ra .- rb)))
@printf("  ring mass per ring A: %s\n", join([@sprintf("%.3f", (sysA.nodes[id]::RingNode).mass) for id in sysA.ring_ids], " "))
@printf("  ring mass per ring B: %s\n", join([@sprintf("%.3f", (sysB.nodes[id]::RingNode).mass) for id in sysB.ring_ids], " "))
println("─"^72)
