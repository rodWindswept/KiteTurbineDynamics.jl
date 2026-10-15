#!/usr/bin/env julia --project=.
# av_rb_placement_check.jl — acceptance check for the rope-break gate placement
# fix (2026-09-16 ruling: detection on the measurement window only).
#
# PART 1  control: warm winner (island 3), breaks_enabled=true, default arm
#         (0.0) → the recorded latch must reproduce (step 98, t≈2.84 ms).
# PART 2  fixed: same build, breaks_arm_s = 10.0 (relax boundary) → no latch,
#         full 50 s run; window stats recorded for comparison with the
#         committed condition-run CSV (eval-timeline-extract, rulingmode).
# PART 3  live-after-arm: breaks_arm_s = 1e-6 → the latch fires again at the
#         same step (detection is live whenever armed).
#
# Read-only w.r.t. src/. Usage: scripts/ktd-julia scratch/av_rb_placement_check.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const RELAX_S = 10.0
const WINDOW_S = 40.0
const MIN_WALL_M = 2.0e-3
const LENGTH = 18.8
const RECORDED_TRIP_STEP = 98          # NR-013 / F3 probe, as-coded warm latch
const RECORDED_TRIP_T = 2.84e-3        # s

const REPO = dirname(@__DIR__)
const WINNER = joinpath(
    REPO, "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
    "island_3", "best_vector.csv",
)

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    cond || push!(failures, name)
end

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

# strain_state with location tracking (seg, line) for the TRPT maximum.
function strain_state2(uc, sys, pc)
    N = sys.n_total
    Nr = sys.n_ring
    n_lines = pc.n_lines
    hub_gid = sys.rotor.node_id
    hub_pos_r = @view uc[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
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
    println("av_rb_placement_check.jl | HEAD ", h)
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

    function warm_build()
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
        u_settled = KiteTurbineDynamics.settle_to_equilibrium(
            sys, u0, pc; wind_fn=wf, lift_device=lift_dev,
        )
        if any(isnan.(u_settled)) || any(isinf.(u_settled))
            error("settle produced NaN/Inf")
        end
        ω_eq = sizing.omega_eq
        N = sys.n_total
        Nr = sys.n_ring
        u_settled[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
        for ri in 1:Nr
            gid = sys.ring_ids[ri]
            pos = u_settled[(3 * (gid - 1) + 1):(3 * gid)]
            r = norm(pos)
            if r > 0.01
                tang = [-pos[2], pos[1], 0.0]
                tang ./= norm(tang)
                vx_idx = 3N + 3 * (gid - 1) + 1
                u_settled[vx_idx:(vx_idx + 2)] .= (ω_eq * r) .* tang
            end
        end
        sys.k_mppt_ref[] = k_mppt
        return sys, u_settled, pc, lift_dev, wf
    end

    sysA, uA, pcA, liftA, wfA = warm_build()
    dt = KiteTurbineDynamics.stable_dt_for_system(sysA, pcA)
    total_n = round(Int, (RELAX_S + WINDOW_S) / dt)
    N = sysA.n_total
    Nr = sysA.n_ring
    @printf("dt = %.8f | total_n = %d | arm boundary step t>=10 s at s = %d\n",
        dt, total_n, floor(Int, RELAX_S / dt) + 1)

    println("\n########## PART 1 — control: default arm (0.0), as-coded latch ##########")
    broke_at = Ref(0)
    trip = Ref{Any}(nothing)
    function cb1(u, t, s)
        if sysA.any_broken[] && broke_at[] == 0
            broke_at[] = s
            st = strain_state2(u, sysA, pcA)
            trip[] = (s, t, st)
        end
    end
    KiteTurbineDynamics.run_canonical_sim!(
        uA, sysA, pcA, wfA, 20_000, dt;
        lift_device=liftA, lin_damp=0.05, callback=cb1, breaks_enabled=true,
    )
    if broke_at[] > 0
        s1, t1, st1 = trip[]
        @printf("trip: step %d  t=%.6f s  trpt/break=%.5f (S%d L%d)  peak/break=%.5f\n",
            s1, t1, st1.trpt / 0.035, st1.seg, st1.line, st1.peak / 0.035)
    else
        println("no latch within 20000 steps")
    end
    check("control (arm 0.0) latches at the recorded trip step $RECORDED_TRIP_STEP", broke_at[] == RECORDED_TRIP_STEP)
    if broke_at[] > 0
        check("control trip time matches the recorded 2.84 ms (tol 0.05 ms)", abs(trip[][2] - RECORDED_TRIP_T) < 5e-5)
    end

    println("\n########## PART 2 — fixed: arm at the relax boundary (10.0 s) ##########")
    sysB, uB, pcB, liftB, wfB = warm_build()
    latchedB = Ref(false)
    crossed_arm = Ref(false)
    rows_t = Float64[]; rows_wg = Float64[]; rows_wh = Float64[]; rows_P = Float64[]; rows_s = Float64[]
    peak_early = Ref((0.0, 0.0))   # (peak_norm, t) for s <= 2000
    max_win = Ref((0.0, 0.0))
    function cb2(u, t, s)
        if t >= RELAX_S
            crossed_arm[] = true
        end
        if sysB.any_broken[]
            latchedB[] = true
        end
        if s <= 2000 || s % 1000 == 0 || s == total_n
            st = strain_state2(u, sysB, pcB)
            snorm = st.peak / 0.035
            if s <= 2000 && snorm > peak_early[][1]
                peak_early[] = (snorm, t)
            end
            if t >= RELAX_S && snorm > max_win[][1]
                max_win[] = (snorm, t)
            end
            if (s <= 2000 && s % 20 == 0) || (s > 2000 && s % 1000 == 0) || s == total_n
                push!(rows_t, t); push!(rows_wg, u[6N + Nr + 1]); push!(rows_wh, u[6N + Nr + 6])
                tau, _ = KiteTurbineDynamics.get_generator_torque(
                    u, sysB, pcB, t, wfB; brake_engaged=sysB.brake_engaged[],
                )
                push!(rows_P, tau * u[6N + Nr + 1] / 1000.0)
                push!(rows_s, snorm)
            end
        end
    end
    t0 = time()
    KiteTurbineDynamics.run_canonical_sim!(
        uB, sysB, pcB, wfB, total_n, dt;
        lift_device=liftB, lin_damp=0.05, callback=cb2,
        breaks_enabled=true, breaks_arm_s=RELAX_S,
    )
    wallB = round(time() - t0, digits=1)
    @printf("full run wall = %.1f s | rows = %d | crossed arm boundary = %s\n", wallB, length(rows_t), crossed_arm[])
    check("no rope-break latch through the whole 50 s run (false rejection gone)", !latchedB[])
    @printf("early peak (s<=2000) strain/break = %.5f at t=%.6f s\n", peak_early[][1], peak_early[][2])
    @printf("window max strain/break = %.5f at t=%.6f s\n", max_win[][1], max_win[][2])
    check("relax transient peak above the break limit is present (suppression is real)", peak_early[][1] > 1.0)
    wmask = findall(>=(RELAX_S), rows_t)
    wg_m = sum(rows_wg[wmask]) / length(wmask)
    wh_m = sum(rows_wh[wmask]) / length(wmask)
    P_m = sum(rows_P[wmask]) / length(wmask)
    @printf("window means (t>=10): omega_gnd=%.6f  omega_hub=%.6f  P=%.6f kW\n", wg_m, wh_m, P_m)
    tmask = findall(>=(45.0), rows_t)
    if !isempty(tmask)
        @printf("tail (t>=45): omega_gnd=%.6f  P=%.6f kW\n",
            sum(rows_wg[tmask]) / length(tmask), sum(rows_P[tmask]) / length(tmask))
    end
    open(joinpath(@__DIR__, "av_rb_placement_island3.csv"), "w") do io
        println(io, "# av_rb_placement_island3.csv — fixed-path warm run (arm at relax boundary)")
        println(io, "# tree ", h[1:min(8, length(h))], " | island 3 | arm_s = ", RELAX_S)
        println(io, "t,omega_gnd,omega_hub,P_gen_kw,strain_max_over_break,any_broken")
        for i in eachindex(rows_t)
            @printf(io, "%.6f,%.9f,%.9f,%.9f,%.9f,%d\n",
                rows_t[i], rows_wg[i], rows_wh[i], rows_P[i], rows_s[i], Int(latchedB[]))
        end
    end

    println("\n########## PART 3 — live after arming: arm 1e-6 s ##########")
    sysC, uC, pcC, liftC, wfC = warm_build()
    broke_at3 = Ref(0)
    function cb3(u, t, s)
        if sysC.any_broken[] && broke_at3[] == 0
            broke_at3[] = s
        end
    end
    KiteTurbineDynamics.run_canonical_sim!(
        uC, sysC, pcC, wfC, 20_000, dt;
        lift_device=liftC, lin_damp=0.05, callback=cb3,
        breaks_enabled=true, breaks_arm_s=1e-6,
    )
    @printf("armed-from-almost-start latch step = %d\n", broke_at3[])
    check("with arm 1e-6 the latch fires at the same trip step (detection live when armed)", broke_at3[] == RECORDED_TRIP_STEP)

    println("\n########## SUMMARY ##########")
    println("checks: ", 5, " | failures: ", length(failures))
    for f in failures
        println("  FAILED: ", f)
    end
end

main()
