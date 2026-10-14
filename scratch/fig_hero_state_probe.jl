#!/usr/bin/env julia
# scratch/fig_hero_state_probe.jl — figures seat, 2026-10-14.
#
# Purpose: before writing the machine-winner-hero capture script, measure the
# winner's built state (u0) and (optionally) its settled operational state:
# the per-ring azimuth states and the per-segment twist Δα, so the hero draws
# the same twist the record carries (NR-022).
#
# No figure output. Decode + build only, plus an optional settle pass.
#
# Run:
#   scripts/ktd-julia scratch/fig_hero_state_probe.jl            # u0 only
#   scripts/ktd-julia scratch/fig_hero_state_probe.jl --settle   # + settle

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

round_discrete!(x::Vector{Float64}) = begin
    xr = copy(x)
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    xr
end

function read_extract(path::AbstractString)
    lines = readlines(path)
    data = [l for l in lines if !startswith(l, "#") && !isempty(strip(l))]
    header = split(data[1], ",")
    return [Dict(String(k) => String(v) for (k, v) in zip(header, split(l, ",")))
            for l in data[2:end]]
end

function main()
    extract = joinpath(ROOT, "docs", "reporting", "figures",
        "machine-evolution-strip", "extract-best-so-far.csv")
    recs = read_extract(extract)
    rec = recs[end]  # island-3 winner, gen 26
    xraw = [parse(Float64, rec["x$j"]) for j in 1:10]
    xesc = round_discrete!(xraw)
    @printf("winner record: %s gen %s\n", rec["label"], rec["selected_gen"])

    dec = design_from_vector_v10(xesc, PROFILE_ELLIPTICAL, P_BASE; power_W=PW,
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
    nr = sys.n_ring
    @printf("n_total %d · n_ring %d · n_lines %d\n", Nn, nr, pc.n_lines)

    function report_state(tag, u)
        pos(id) = u[3 * (id - 1) + 1:3 * id]
        centers = [pos(id) for id in sys.ring_ids]
        radii = [(sys.nodes[id]::RingNode).radius for id in sys.ring_ids]
        shaft = normalize(centers[end] .- centers[1])
        svec = [dot(c .- centers[1], shaft) for c in centers]
        # ring azimuth states
        alphas = [u[6Nn + (sys.nodes[id]::RingNode).ring_idx] for id in sys.ring_ids]
        println("── $tag ──")
        for (k, rid) in enumerate(sys.ring_ids)
            @printf("  ring %d (id %d): r %.4f m · s %.4f m · alpha_state %.6f rad (%.3f deg)\n",
                k, rid, radii[k], svec[k], alphas[k], rad2deg(alphas[k]))
        end
        # per-segment twist from the state alphas
        for k in 1:(nr - 1)
            d = rad2deg(alphas[k + 1] - alphas[k])
            d = mod(d + 180, 360) - 180   # wrap to (-180, 180]
            @printf("  S%d (ring %d -> %d): dalpha_state %.3f deg\n", k, k, k + 1, d)
        end
        # independent geometric read: attachment points ring-to-ring
        for k in 1:(nr - 1)
            rid_a = sys.ring_ids[k]; rid_b = sys.ring_ids[k + 1]
            na = sys.nodes[rid_a]::RingNode; nb = sys.nodes[rid_b]::RingNode
            pp1, pp2 = KTD._tilted_ring_basis(u, sys, sys.rotor.node_id,
                (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx)
            ca = centers[k]; cb = centers[k + 1]
            ang_a = atan(dot(attachment_point(ca, na.radius, alphas[k], 1, pc.n_lines, pp1, pp2) .- ca, pp2),
                         dot(attachment_point(ca, na.radius, alphas[k], 1, pc.n_lines, pp1, pp2) .- ca, pp1))
            ang_b = atan(dot(attachment_point(cb, nb.radius, alphas[k + 1], 1, pc.n_lines, pp1, pp2) .- cb, pp2),
                         dot(attachment_point(cb, nb.radius, alphas[k + 1], 1, pc.n_lines, pp1, pp2) .- cb, pp1))
            d = rad2deg(ang_b - ang_a)
            d = mod(d + 180, 360) - 180
            @printf("  S%d geometric: dalpha_geo %.3f deg\n", k, d)
        end
        return nothing
    end

    report_state("built state u0 (no settle)", u0)

    if "--settle" in ARGS
        ld = rotary_lifter_default()
        wind_fn = (pos, t) -> begin
            z = max(pos[3], 1.0)
            sh = (z / P_BASE.h_ref)^(1.0 / 7.0)
            [P_BASE.v_wind_ref * sh, 0.0, 0.0]
        end
        @printf("settling to operational state (V=%.2f m/s, omega_rated=9.5)...\n", P_BASE.v_wind_ref)
        t0 = time()
        u_s = KTD.settle_to_operational_state(sys, u0, P_BASE, 9.5;
            lift_device=ld, wind_fn=wind_fn)
        @printf("settle done in %.1f s\n", time() - t0)
        report_state("settled state", u_s)
        upos(id) = u_s[3 * (id - 1) + 1:3 * id]
        hub = upos(sys.ring_ids[end])
        gnd = upos(sys.ring_ids[1])
        @printf("settled hub position: [%.3f, %.3f, %.3f]\n", hub...)
        @printf("settled ground position: [%.3f, %.3f, %.3f]\n", gnd...)
        shaft = normalize(hub .- gnd)
        @printf("settled shaft elevation: %.3f deg\n", rad2deg(asin(shaft[3])))
        @printf("settled hub altitude: %.3f m\n", hub[3])
    end
    return nothing
end

main()
