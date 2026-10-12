#!/usr/bin/env julia --project=.
# av_f3_warm_fixedseed.jl — warm path with the seed corrected to the rigid field.
#
# The as-coded seed (objective_evaluator.jl:823-834) writes v = ω·|pos|·tang_z into
# ring CENTRES. The corrected spec (@science-validator): ring centres near rest,
# rope nodes at ω×ρ — i.e. the rigid-body field v = ω·n̂ × pos about the shaft axis
# (through the settled hub centre), applied to every spinning part.
#
# Run: warm start, corrected seed, AS-CODED gates (breaks on throughout).
# Question: does the warm path fly the winner once the seed obeys the rigid field?
#
# Read-only w.r.t. src/. USAGE  scripts/ktd-julia scratch/av_f3_warm_fixedseed.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const RELAX_S = 10.0
const WINDOW_S = 40.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8

const REPO = dirname(@__DIR__)
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev,
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout,
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

function endpos!(
    out::Vector{Float64}, se, uc, sys, alpha, pp1_tilt, pp2_tilt,
    perp1_shaft, perp2_shaft, n_lines, hub_ri,
)
    if se.is_ring
        node = sys.nodes[se.node_id]::KiteTurbineDynamics.RingNode
        ri = node.ring_idx
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[ri]
        ctr = @view uc[(3 * (se.node_id - 1) + 1):(3 * se.node_id)]
        pp1, pp2 = KiteTurbineDynamics.tilt_applies(ri, hub_ri) ?
            (pp1_tilt, pp2_tilt) : (perp1_shaft, perp2_shaft)
        KiteTurbineDynamics.attachment_point!(
            out, ctr, R, alpha[ri], se.line_idx, n_lines, pp1, pp2,
        )
    else
        out[1] = uc[3 * (se.node_id - 1) + 1]
        out[2] = uc[3 * (se.node_id - 1) + 2]
        out[3] = uc[3 * (se.node_id - 1) + 3]
    end
    return out
end

function strain_state(uc, sys, pc)
    N = sys.n_total
    Nr = sys.n_ring
    n_lines = pc.n_lines
    hub_gid = sys.rotor.node_id
    hub_pos_r = @view uc[(3 * (hub_gid - 1) + 1):3 * hub_gid]
    hub_rmag = norm(hub_pos_r)
    shaft_dir = hub_rmag > 0.1 ? collect(hub_pos_r) ./ hub_rmag :
        [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
    perp1_shaft, perp2_shaft = KiteTurbineDynamics.shaft_perp_basis(shaft_dir)
    hub_ri = (sys.nodes[hub_gid]::KiteTurbineDynamics.RingNode).ring_idx
    pp1_tilt, pp2_tilt = KiteTurbineDynamics._tilted_ring_basis(uc, sys, hub_gid, hub_ri)
    alpha = @view uc[(6N + 1):(6N + Nr)]
    L = zeros(Nr, n_lines)
    L0 = zeros(Nr, n_lines)
    bl = zeros(n_lines)
    bl0 = zeros(n_lines)
    cyan = 0.0
    cyan0 = 0.0
    pa = zeros(3)
    pb = zeros(3)
    bearing_id = sys.bearing_id
    sky_id = sys.sky_anchor_id
    for (si, ss) in enumerate(sys.sub_segs)
        seg = sys.sub_seg_trpt_seg[si]
        endpos!(pa, ss.end_a, uc, sys, alpha, pp1_tilt, pp2_tilt,
            perp1_shaft, perp2_shaft, n_lines, hub_ri)
        endpos!(pb, ss.end_b, uc, sys, alpha, pp1_tilt, pp2_tilt,
            perp1_shaft, perp2_shaft, n_lines, hub_ri)
        cl = norm(pb .- pa)
        cl < 1e-9 && continue
        lj = ss.end_a.line_idx
        if seg > 0
            if 1 <= seg <= (Nr - 1) && 1 <= lj <= n_lines
                L[seg, lj] += cl
                L0[seg, lj] += ss.length_0
            end
        elseif ss.end_a.node_id == bearing_id
            if 1 <= lj <= n_lines
                bl[lj] += cl
                bl0[lj] += ss.length_0
            end
        elseif (ss.end_a.node_id == bearing_id && ss.end_b.node_id == sky_id) ||
            (ss.end_a.node_id == sky_id && ss.end_b.node_id == bearing_id)
            cyan += cl
            cyan0 += ss.length_0
        end
    end
    s_trpt = 0.0
    seg_i = 0
    line_i = 0
    for j in 1:n_lines, i in 1:(Nr - 1)
        L0[i, j] > 1e-9 || continue
        val = (L[i, j] - L0[i, j]) / L0[i, j]
        if val > s_trpt
            s_trpt = val
            seg_i = i
            line_i = j
        end
    end
    s_brid = 0.0
    line_b = 0
    for j in 1:n_lines
        bl0[j] > 1e-9 || continue
        val = (bl[j] - bl0[j]) / bl0[j]
        if val > s_brid
            s_brid = val
            line_b = j
        end
    end
    s_cyan = cyan0 > 1e-9 ? (cyan - cyan0) / cyan0 : 0.0
    return (
        peak=max(s_trpt, s_brid, s_cyan), trpt=s_trpt, bridle=s_brid, cyan=s_cyan,
        seg=seg_i, line=line_i, bline=line_b,
    )
end

function main()
    h = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    println("av_f3_warm_fixedseed.jl | HEAD ", h[1:min(8, length(h))])
    x = [parse(Float64, tok) for tok in split(strip(read(WINNER, String)), ",")]
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    p_base = params_at_length(LENGTH)
    cfg = ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=RELAX_S, window_s=WINDOW_S,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )

    x_canon = KiteTurbineDynamics.canonical_v10(xr)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true,
        rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split,
        cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor,
        beam_t_over_D=cfg.t_over_D,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    k_mppt = clamp(cfg.k_mppt, 0.01, 1e6)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        result, 1.0, k_mppt;
        tether_diameter=cfg.tether_diameter,
        base_params=p_base,
        min_wall_m=cfg.min_wall_m,
        beam_sizing=sizing,
    )
    wf = function (pos, t)
        z = max(pos[3], 1.0)
        return [KiteTurbineDynamics.wind_at_altitude(p_base.v_wind_ref, p_base.h_ref, z), 0.0, 0.0]
    end
    lift_dev = lift_for(sys, pc)
    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, pc; wind_fn=wf, lift_device=lift_dev)
    any(isnan.(u)) && error("settle produced NaN")

    ω_eq = sizing.omega_eq
    N = sys.n_total
    Nr = sys.n_ring
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq

    hub_gid = sys.rotor.node_id
    hub_c = collect(@view u[(3 * (hub_gid - 1) + 1):3 * hub_gid])
    nhat = hub_c ./ norm(hub_c)

    n_seeded = 0
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = collect(@view u[(3 * (gid - 1) + 1):3 * gid])
        v = ω_eq .* cross(nhat, pos)
        vx = 3N + 3 * (gid - 1) + 1
        u[vx:(vx + 2)] .= v
        n_seeded += 1
    end
    seen = Set{Int}()
    for (si, ss) in enumerate(sys.sub_segs)
        sys.sub_seg_trpt_seg[si] > 0 || continue
        for se in (ss.end_a, ss.end_b)
            se.is_ring && continue
            se.node_id in seen && continue
            push!(seen, se.node_id)
            pos = collect(@view u[(3 * (se.node_id - 1) + 1):3 * se.node_id])
            v = ω_eq .* cross(nhat, pos)
            vx = 3N + 3 * (se.node_id - 1) + 1
            u[vx:(vx + 2)] .= v
            n_seeded += 1
        end
    end
    println("fixed seed: omega_eq = ", ω_eq, "  nodes seeded = ", n_seeded,
        " (", Nr, " ring centres + ", n_seeded - Nr, " TRPT rope nodes)")
    vmax = 0.0
    for i in 1:N
        vv = norm(u[(3N + 3 * (i - 1) + 1):(3N + 3 * (i - 1) + 3)])
        vmax = max(vmax, vv)
    end
    @printf("max |v| after seed = %.4f m/s\n", vmax)

    sys.k_mppt_ref[] = k_mppt
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    total_n = round(Int, (RELAX_S + WINDOW_S) / dt)
    println("dt = ", dt, "  total_n = ", total_n)

    rows_t = Float64[]
    rows_wg = Float64[]
    rows_wh = Float64[]
    rows_P = Float64[]
    rows_s = Float64[]
    brk_step = Ref(0)
    brk_info = Ref("")
    step_last = Ref(0)
    s_peak = Ref((0.0, 0.0))
    function cb(u2, t, s)
        step_last[] = s
        st = nothing
        if s <= 2000 || s % 1000 == 0 || s == total_n || sys.any_broken[]
            st = strain_state(u2, sys, pc)
            if s <= 2000 && st.peak / 0.035 > s_peak[][1]
                s_peak[] = (st.peak / 0.035, t)
            end
        end
        if (s <= 2000 && s % 20 == 0) || (s > 2000 && s % 1000 == 0) ||
           s == total_n || sys.any_broken[]
            wg = u2[6N + Nr + 1]
            wh = u2[6N + Nr + 6]
            tau, _ = KiteTurbineDynamics.get_generator_torque(
                u2, sys, pc, t, wf; brake_engaged=sys.brake_engaged[],
            )
            push!(rows_t, t)
            push!(rows_wg, wg)
            push!(rows_wh, wh)
            push!(rows_P, tau * wg / 1000.0)
            push!(rows_s, st === nothing ? NaN : st.peak / 0.035)
        end
        if sys.any_broken[] && brk_step[] == 0
            brk_step[] = s
            stt = st === nothing ? strain_state(u2, sys, pc) : st
            brk_info[] = @sprintf(
                "break latch at s=%d t=%.6f | trpt=%.5f(S%d L%d) brid=%.5f peak=%.5f",
                s, t, stt.trpt / 0.035, stt.seg, stt.line, stt.bridle / 0.035, stt.peak / 0.035,
            )
        end
    end
    t0 = time()
    KiteTurbineDynamics.run_canonical_sim!(
        u, sys, pc, wf, total_n, dt;
        lift_device=lift_dev, lin_damp=0.05, callback=cb, breaks_enabled=true,
    )
    wall = round(time() - t0, digits=1)
    println("run: wall=", wall, " s  last step=", step_last[], " of ", total_n)
    println("any_broken = ", sys.any_broken[])
    brk_step[] > 0 && println(brk_info[])
    @printf("early peak (s<=2000) = %.5f at t=%.6f\n", s_peak[][1], s_peak[][2])

    wmask = findall(>=(RELAX_S), rows_t)
    if !isempty(wmask)
        mwg = sum(rows_wg[wmask]) / length(wmask)
        mwh = sum(rows_wh[wmask]) / length(wmask)
        mP = sum(rows_P[wmask]) / length(wmask)
        @printf("window means (t>=10): omega_gnd=%.6f  omega_hub=%.6f  P=%.6f kW\n", mwg, mwh, mP)
        @printf("window omega range: %.4f .. %.4f\n", minimum(rows_wg[wmask]), maximum(rows_wg[wmask]))
        @printf("window P range:     %.4f .. %.4f kW\n", minimum(rows_P[wmask]), maximum(rows_P[wmask]))
        @printf("window max strain/break = %.5f\n", maximum(rows_s[wmask]))
        tmask = findall(>=(45.0), rows_t)
        if !isempty(tmask)
            @printf("tail (t>=45): omega_gnd=%.6f  P=%.6f kW\n",
                sum(rows_wg[tmask]) / length(tmask), sum(rows_P[tmask]) / length(tmask))
        end
    end
    out = joinpath(REPO, "scratch", "av_f3_warm_fixedseed.csv")
    open(out, "w") do io
        println(io, "# av_f3_warm_fixedseed / warm path with the rigid-field seed, as-coded gates")
        println(io, "# tree ", h[1:min(8, length(h))], " | generated by scratch/av_f3_warm_fixedseed.jl")
        println(io, "t,omega_gnd,omega_hub,P_gen_kw,strain_max_over_break,any_broken")
        for i in eachindex(rows_t)
            @printf(io, "%.6f,%.9f,%.9f,%.9f,%.9f,%d\n",
                rows_t[i], rows_wg[i], rows_wh[i], rows_P[i], rows_s[i],
                Int(brk_step[] > 0 && i == length(rows_t)))
        end
    end
    println("wrote ", out, " (", length(rows_t), " rows)")
end

main()
