# scratch/derive_lift_chain_constants.jl
#
# Purpose (2026-09-13, DSH session): the viable replacement seed found in
# scratch/spec_seed_candidate.jl CANNOT land, because with it the settle's bridle
# tension collapses to 0.000 N (lift chain disconnected).  Cause: the lift-chain
# design constants
#
#     BEARING_OFFSET_DESIGN = 3.99 m   (main rotor -> lift bearing, +shaft)
#     CYAN_L0_DESIGN        = 5.00 m   (sky anchor -> lift bearing)
#
# were MEASURED for the old seed's geometry (r_hub 2.4).  The bridle design gap is
# sqrt(BEARING_OFFSET^2 + R_hub^2), so a different r_hub invalidates them.
#
# The handover records HOW 3.99 was obtained: from "the chain's own equilibrium —
# the cyan is 5.0 m and the bearing hangs at its full length below the sky
# anchor".  So it is DERIVED from the equilibrium, not chosen.  This probe applies
# the same method to any genome: settle naturally with the lift device, then read
# the settled bearing offset and cyan length.
#
# Validation: run against the OLD seed first.  If the method is sound it must
# reproduce ~3.99 m.  Only then is the new seed's number trustworthy.
#
# Self-checking: asserts the settled assembly is finite and that the old seed's
# measured offset reproduces BEARING_OFFSET_DESIGN to within 0.5 m before the new
# seed's value is reported.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const OLD_SEED = [2.4, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const NEW_SEED = [2.6, 0.5751086853804245, 2.0, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

"Build the campaign system for an explicit 10-D genome (same knobs as build_case)."
function build_for(x10)
    p = params_5kw_188()
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        p_ceiling_kw=5.0, fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3,
        t_over_D=0.055, rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0,
        K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p,
        min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

bridle_total(u, sys, p, N, Nr) = begin
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    tot = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], ring_end.line_idx,
                              p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    tot
end

println("\n=== derived lift-chain design constants ===")
measured = Dict{String,Float64}()
for (name, x10) in (("OLD (control, r_hub 2.4)", OLD_SEED), ("NEW (candidate, r_hub 2.6)", NEW_SEED))
    sys, u0, pc, lift, wf = build_for(x10)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_equilibrium(sys, copy(u0), pc;
        lift_device=lift, wind_fn=wf)
    @assert all(isfinite, u) "settle_to_equilibrium produced non-finite state"

    hub_i, bear_i, sky_i = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    hub = pos(u, hub_i)
    off = dot(pos(u, bear_i) .- hub, sh)
    cyan = norm(pos(u, sky_i) .- pos(u, bear_i))
    sky_off = dot(pos(u, sky_i) .- hub, sh)
    br = bridle_total(u, sys, pc, N, Nr)
    measured[name] = off
    println("\n--- ", name)
    println("    decoded: n_lines=", pc.n_lines, " n_exp=", length(sys.expansion_rotors),
            " n_rings=", Nr)
    println("    settled bearing offset  = ", round(off; digits=4), " m")
    println("    settled cyan length     = ", round(cyan; digits=4), " m")
    println("    settled sky offset      = ", round(sky_off; digits=4), " m")
    println("    bridle total tension    = ", round(br; digits=2), " N")
end

old_off = measured["OLD (control, r_hub 2.4)"]
new_off = measured["NEW (candidate, r_hub 2.6)"]
println("\n=== validation ===")
# The bearing offset is DERIVED from the top-ring radius at the bridle-cone apex:
#     bearing_offset(r_top) = r_top / tan(31°)
# (2026-09-14, Rod: the offset must never be a prespecified number.)  The settle
# must sit AT that apex for each radius, and the two offsets must DIFFER.
exp_old = KiteTurbineDynamics.bridle_bearing_offset(2.4)
exp_new = KiteTurbineDynamics.bridle_bearing_offset(2.6)
println("  derived r_top=2.4 -> ", round(exp_old; digits=4), "   settled -> ", round(old_off; digits=4))
println("  derived r_top=2.6 -> ", round(exp_new; digits=4), "   settled -> ", round(new_off; digits=4))
@test isapprox(old_off, exp_old; atol=0.5)
@test isapprox(new_off, exp_new; atol=0.5)
@test !isapprox(old_off, new_off; atol=0.05)   # the offset MUST scale with radius
println("  (offset scales with radius: ", round(abs(old_off - new_off); digits=4), " m apart)")
println("\n=== done ===")
