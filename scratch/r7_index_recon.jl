# scratch/r7_index_recon.jl — R7 recon (evidence, not shipped).
# Resolve the rotor->ring index convention for the 5 kW 3-rotor seed: is the
# hub rotor's `ring_idx` the ground-first hub index, and do the expansion
# rotors land on the harvest-cylinder rings the decoder intended?
using KiteTurbineDynamics
using Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0

function params_at_length(L)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

p_base = params_at_length(18.8)
seed = seed_genome(KW)
lo, hi = tight_bounds(seed, KW; do_min=0.03)
x = clamp.(seed, lo, hi)
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = Float64(round(Int, clamp(x[10], 1, 3)))

dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p_base; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)

N = length(dec.radii)
println("=== DECODE ===")
@printf("length(radii)=%d  result.n_rings=%d  length(zs)=%d\n", N, dec.n_rings, length(dec.zs))
@printf("taper_start_z=%.4f  harvest_length=%.4f  tether=%.4f\n",
    dec.taper_start_z, dec.harvest_length, dec.design.tether_length)
println("ground-first rings (i, z, r):")
for i in 1:N
    @printf("  %2d  z=%7.4f  r=%7.4f%s\n", i, dec.zs[i], dec.radii[i],
        i == 1 ? "  <- ground" : (i == N ? "  <- hub" : ""))
end
println("rotors (from decode):")
for (k, rot) in enumerate(dec.rotors)
    @printf("  rotor %d: ring_idx=%d  v_wind=%.3f  wind_factor=%.3f  tip=%.3f hub=%.3f span=%.3f r_rotor=%.3f\n",
        k, rot.ring_idx, rot.v_wind, rot.wind_factor, rot.blade_tip_radius,
        rot.blade_hub_radius, rot.blade_tip_radius - rot.blade_hub_radius, rot.r_rotor)
end

sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p_base.tether_diameter, base_params=p_base, min_wall_m=2e-3)

println("=== BUILT SYSTEM ===")
@printf("sys.n_ring=%d  sys.n_total=%d\n", sys.n_ring, sys.n_total)
println("sys rings (k, gid, r):")
for k in 1:sys.n_ring
    gid = sys.ring_ids[k]
    r = (sys.nodes[gid]::RingNode).radius
    @printf("  %2d  gid=%2d  r=%7.4f%s\n", k, gid, r, k == sys.n_ring ? "  <- hub" : "")
end
println("expansion rotors in sys:")
for er in sys.expansion_rotors
    r = (sys.nodes[sys.ring_ids[er.ring_idx]]::RingNode).radius
    @printf("  ring_idx=%d  r=%.4f  tip=%.3f  mass=%.3f\n", er.ring_idx, r, er.blade_tip_radius, er.mass)
end
@printf("main rotor: node_id=%d radius=%.4f hub_r=%.4f\n",
    sys.rotor.node_id, sys.rotor.radius, sys.rotor.blade_hub_radius)

println("=== objective_v10 expansion-loop index check (gi = ri + 1) ===")
errs = KiteTurbineDynamics.expansion_params_from_rotors(dec.rotors, dec.n_rings, dec.design.n_lines)
for er in errs
    ri = er.ring_idx
    gi = ri + 1
    @printf("  rotor ring_idx=%d -> objective_v10 gi=%d %s\n", ri, gi,
        gi > N ? "(OUT OF RANGE -> skipped)" : @sprintf("(lands on r=%.4f, true r=%.4f)", dec.radii[gi], dec.radii[ri]))
end
@printf("p_base.h_ref=%.3f  design.tether_length=%.3f  hub_alt=%.3f\n",
    p_base.h_ref, dec.design.tether_length, dec.design.tether_length * sind(30.0))
@printf("decode v_wind[1]=%.3f (wind_speed_at_ring default h_ref=50)  ODE wf at hub uses p.h_ref=%.3f\n",
    dec.rotors[1].v_wind, p_base.h_ref)
