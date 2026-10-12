#!/usr/bin/env julia
# scratch/fig1_decode_winner.jl — figures seat, 2026-10-12.
#
# F1 system-anatomy re-cut support: decode the island-3 winner genome and print
# the drawn geometry, using the exact decode/build path of
# docs/reporting/figures/machine-evolution-strip/machine-evolution-strip.jl
# (build_panel): design_from_vector_v10 -> size_beams_closed_form ->
# build_system_from_v10, no ODE.  Prints (rho, s) pairs in the same side
# projection (proj2) the strip drew, so the anatomy figure can map them into
# the deployment frame at a declared scale.
#
# Run: scripts/ktd-julia scratch/fig1_decode_winner.jl

using KiteTurbineDynamics, Printf, LinearAlgebra
const KTD = KiteTurbineDynamics

const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const BF = BLOCKING_WIND_FACTOR_5KW
const FOS_HARD = 2.5

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max,
        p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x,
        p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const P_BASE = params_at_length(LENGTH)

tandeg(x) = tan(deg2rad(x))

function main()
    x = [4.57997905482005, 0.8036829846088207, 2.720554022272866, 3.0,
        -0.8, 1.0370201857788965, 7.088131460323565, 22.0,
        0.8213255027884769, 0.19999999999999996]
    xesc = copy(x)
    xesc[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    xesc[6] = Float64(round(Int, clamp(x[6], 1, 3)))

    println("== F1 winner decode (island 3, gen 26, i3-g26-i9) ==")
    println("elevation_angle rad=", P_BASE.elevation_angle,
        " deg=", rad2deg(P_BASE.elevation_angle))
    println("lifter_elevation rad=", P_BASE.lifter_elevation,
        " deg=", rad2deg(P_BASE.lifter_elevation))
    println("back_anchor_fwd_x = ", P_BASE.back_anchor_fwd_x)

    dec = KTD.design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BF,
        v_rated=V_RATED)
    cfg = KTD.ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED, p_floor_kw=KW, fos_target=FOS_HARD,
        fos_hard=FOS_HARD, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BF,
    )
    sizing = KTD.size_beams_closed_form(dec, P_BASE, cfg)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=P_BASE.tether_diameter, base_params=P_BASE,
        min_wall_m=2e-3, beam_sizing=sizing)

    Nn = sys.n_total
    pos(id) = u0[3 * (id - 1) + 1:3 * id]
    centers = [pos(id) for id in sys.ring_ids]
    radii = [(sys.nodes[id]::KTD.RingNode).radius for id in sys.ring_ids]
    shaft = normalize(centers[end] .- centers[1])
    svec = [dot(c .- centers[1], shaft) for c in centers]

    println("\n-- rings (R1 ground -> R6 hub) --")
    for k in eachindex(radii)
        println(@sprintf("ring R%d: r = %.6f  s = %.6f", k, radii[k], svec[k]))
    end

    t_start = dec.taper_start_z
    t_harv = dec.design.tether_length - dec.harvest_length
    println("\ntaper_start_z = ", t_start)
    println("tether_length = ", dec.design.tether_length)
    println("harvest_length = ", dec.harvest_length)
    println("t_harv = ", t_harv)
    sections = map(svec) do si
        si <= t_start + 1e-6 ? :transmission :
        (si >= t_harv - 1e-6 ? :harvest : :cone)
    end
    println("ring sections: ", sections)

    rt = sys.rotor
    println("\n-- main rotor --")
    println("ring_idx = ", length(sys.ring_ids))
    println(@sprintf("r_out = %.6f  r_in = %.6f  bank_deg = %.6f",
        rt.radius, rt.blade_hub_radius, rt.bank_angle_deg))
    r_ring = radii[end]
    Δout = max(rt.radius - r_ring, 0.0) * tandeg(abs(rt.bank_angle_deg))
    Δin = max(r_ring - rt.blade_hub_radius, 0.0) * tandeg(abs(rt.bank_angle_deg))
    s_r = svec[end]
    println(@sprintf("quad: r_in %.6f at y_in %.6f | r_out %.6f at y_out %.6f",
        rt.blade_hub_radius, s_r + Δin, rt.radius, s_r - Δout))

    c1 = centers[1]
    side = normalize(cross([0.0, 1.0, 0.0], shaft))
    proj2(p) = (dot(p .- c1, side), dot(p .- c1, shaft))
    alpha0 = u0[6 * Nn + length(sys.ring_ids)]
    e2 = normalize(cross(shaft, side))
    n_blades = dec.design.n_lines
    println("\n-- blades (j: in -> out, (rho, s)) --")
    for j in 1:n_blades
        θ = alpha0 + 2π * (j - 1) / n_blades
        d = cos(θ) .* side .+ sin(θ) .* e2
        a = proj2(centers[end] .+ d .* rt.blade_hub_radius .+ shaft .* Δin)
        b = proj2(centers[end] .+ d .* rt.radius .- shaft .* Δout)
        println(@sprintf("blade %d: in (%.6f, %.6f) -> out (%.6f, %.6f)",
            j, a[1], a[2], b[1], b[2]))
    end

    println("\n-- TRPT ropes (seg, line: points (rho, s)) --")
    for seg in 1:(sys.n_ring - 1), j in 1:pc.n_lines
        xs, ys, zs = KTD._rope_line_pts(u0, sys, pc, seg, j)
        pts = [proj2([xs[i], ys[i], zs[i]]) for i in eachindex(xs)]
        s0 = join([@sprintf("(%.4f, %.4f)", p[1], p[2]) for p in pts], " ")
        println("rope seg $seg line $j: $s0")
    end

    println("\n-- lift chain derived --")
    println(@sprintf("bearing_offset = %.6f",
        KTD.bridle_bearing_offset(radii[end])))
    println(@sprintf("bridle_3d_length = %.6f", radii[end] / sind(31.0)))
    println("n_lines = ", pc.n_lines, "  n_ring = ", sys.n_ring,
        "  n_active = ", dec.n_active)
    println("\n-- extents (strip frame) --")
    allx = Float64[]; ally = Float64[]
    for k in eachindex(radii)
        push!(allx, -radii[k], radii[k]); push!(ally, svec[k])
    end
    println(@sprintf("ring extent: rho +-%.6f  s %.6f .. %.6f",
        maximum(radii), minimum(svec), maximum(svec)))
    println("done")
end

main()
