#!/usr/bin/env julia --project=.
# av_f3_warm_diag2.jl — the warm path on the winner, end to end.
#
# PART A  seed-velocity exhibit: the evaluator's warm seed (objective_evaluator.jl
#         823-834, v = ω_eq·|pos|·tang_z) vs the true rigid-rotation velocity
#         (v = ω n̂ × (pos − c_ring), the basis orbital_damp_rope_velocities! uses).
# PART B  as-coded warm run (breaks_enabled=true): step-by-step until the rope-break
#         latch. Prints the trip step, time, class and magnitudes.
# PART C  ruling-mode continuation (breaks OFF during relax, ON for the window —
#         the pending 2026-09-16 placement): does the machine survive the injected
#         transient and pass the window? Window stats printed.
#
# Read-only w.r.t. src/. USAGE  scripts/ktd-julia scratch/av_f3_warm_diag2.jl
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
    println("av_f3_warm_diag2.jl | HEAD ", h)
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

    # ── build warm state: decode → sizing → build → settle → seed ────────
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
        # seed exactly as objective_evaluator.jl:821-834
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
        return sys, u_settled, pc, lift_dev, wf, ω_eq
    end

    dt = 0.0
    total_n = 0

    println("\n########## PART A — seed-velocity exhibit ##########")
    sysA, uA, pcA, liftA, wfA, ω_eq = warm_build()
    dt = KiteTurbineDynamics.stable_dt_for_system(sysA, pcA)
    total_n = round(Int, (RELAX_S + WINDOW_S) / dt)
    println("ω_eq (sizing) = ", ω_eq, "  dt = ", dt, "  total_n = ", total_n)
    hub_gid = sysA.rotor.node_id
    hub_c = collect(@view uA[(3 * (hub_gid - 1) + 1):(3 * hub_gid)])
    nhat = hub_c ./ norm(hub_c)
    println("hub centre = ", hub_c, "  |hub| = ", norm(hub_c),
        "  shaft unit = ", nhat, "  elevation = ", rad2deg(asin(nhat[3])), " deg")
    N = sysA.n_total
    Nr = sysA.n_ring
    println("The seed (objective_evaluator.jl:823-834) writes v = ω_eq·|pos|·tanĝ_z")
    println("into each RING-CENTRE node (ring_ids[ri]); |pos| = centre distance from origin.")
    println("ring |  L=|centre|  |  v_seed = ω·L  |  rim speed ω·R  |  ring mass  | KE_seed")
    ke_tot = 0.0
    for ri in 1:Nr
        gid = sysA.ring_ids[ri]
        node = sysA.nodes[gid]::KiteTurbineDynamics.RingNode
        c = collect(@view uA[(3 * (gid - 1) + 1):3 * gid])
        L_ = norm(c)
        v_seed = ω_eq * L_
        v_rim = ω_eq * node.radius
        ke = 0.5 * node.mass * v_seed^2
        ke_tot += ke
        @printf("  R%d | %12.6f | %13.3f | %14.3f | %10.4f kg | %10.1f kJ\n",
            ri, L_, v_seed, v_rim, node.mass, ke / 1000)
    end
    @printf("total seeded translational KE = %.1f kJ\n", ke_tot / 1000)
    println("(ring centres should start ~at rest — the machine spins about its shaft;")
    println(" rims move, centres do not. ring 1 sits at the origin: |pos|<0.01 → seed skips it.)")

    println("\n########## PART B — as-coded warm run to the break latch ##########")
    sysB, uB, pcB, liftB, wfB, ω_eqB = warm_build()
    broke_at = Ref(0)
    trip = Ref{Any}(nothing)
    step_count = Ref(0)
    function cbB(u, t, s)
        step_count[] = s
        brk = sysB.any_broken[]
        do_log = s <= 120 || s % 20 == 0 || brk
        st = (peak=NaN, trpt=NaN, bridle=NaN, cyan=NaN, seg=0, line=0, bline=0)
        if do_log
            st = strain_state2(u, sysB, pcB)
        end
        if do_log
            @printf("s=%6d t=%.6f wg=%10.4f wh=%10.4f brk=%d | N: trpt=%.5f(S%d L%d) brid=%.5f(L%d) cyan=%.5f peak=%.5f\n",
                s, t, u[6N + Nr + 1], u[6N + Nr + 6], Int(brk),
                st.trpt / 0.035, st.seg, st.line, st.bridle / 0.035, st.bline,
                st.cyan / 0.035, st.peak / 0.035)
        end
        if brk && broke_at[] == 0
            broke_at[] = s
            trip[] = (s, t, st)
        end
    end
    t0 = time()
    KiteTurbineDynamics.run_canonical_sim!(
        uB, sysB, pcB, wfB, 60_000, dt;
        lift_device=liftB, lin_damp=0.05, callback=cbB, breaks_enabled=true,
    )
    wallB = round(time() - t0, digits=1)
    println("PART B: ran to s=", step_count[], " wall=", wallB, " s")
    if broke_at[] > 0
        sB, tB, stB = trip[]
        @printf("TRIP: step %d  t=%.6f s  class %s  trpt=%.5f (S%d L%d)  brid=%.5f  cyan=%.5f  peak_norm=%.5f\n",
            sB, tB,
            stB.peak == stB.trpt ? "TRPT" : stB.peak == stB.bridle ? "BRIDLE" : "CYAN",
            stB.trpt / 0.035, stB.seg, stB.line, stB.bridle / 0.035, stB.cyan / 0.035,
            stB.peak / 0.035)
        println("(normalized-to-break values; break at 1.0; raw strains = value × 0.035)")
    else
        println("no break latch within 60000 steps")
    end

    println("\n########## PART C — ruling-mode run (breaks off t<10 s, on t>=10 s) ##########")
    sysC, uC, pcC, liftC, wfC, ω_eqC = warm_build()
    flip = Ref(false)
    crows_t = Float64[]
    crows_wg = Float64[]
    crows_wh = Float64[]
    crows_P = Float64[]
    crows_s = Float64[]
    cmax = Ref((0.0, 0.0))          # (grid peak_norm, t)
    cpeak_early = Ref((0.0, 0.0))   # (true per-step peak_norm, t) for s <= 2000
    cbrk = Ref(false)
    function cbC(u, t, s)
        if t >= RELAX_S && !flip[]
            sysC.breaks_enabled[] = true
            flip[] = true
        end
        if s <= 2000 || s % 1000 == 0 || s == total_n
            wg = u[6N + Nr + 1]
            wh = u[6N + Nr + 6]
            tau, _ = KiteTurbineDynamics.get_generator_torque(
                u, sysC, pcC, t, wfC; brake_engaged=sysC.brake_engaged[],
            )
            st = strain_state2(u, sysC, pcC)
            snorm = st.peak / 0.035
            if s <= 2000 && snorm > cpeak_early[][1]
                cpeak_early[] = (snorm, t)
            end
            if (s <= 2000 && s % 20 == 0) || (s > 2000 && s % 1000 == 0) || s == total_n
                push!(crows_t, t)
                push!(crows_wg, wg)
                push!(crows_wh, wh)
                push!(crows_P, tau * wg / 1000.0)
                push!(crows_s, snorm)
                if snorm > cmax[][1]
                    cmax[] = (snorm, t)
                end
            end
        end
        if sysC.any_broken[]
            cbrk[] = true
        end
    end
    t0 = time()
    KiteTurbineDynamics.run_canonical_sim!(
        uC, sysC, pcC, wfC, total_n, dt;
        lift_device=liftC, lin_damp=0.05, callback=cbC, breaks_enabled=false,
    )
    wallC = round(time() - t0, digits=1)
    println("PART C: wall=", wallC, " s  rows=", length(crows_t))
    println("any_broken after flip (window phase) = ", cbrk[])
    @printf("true early per-step peak (s<=2000) = %.5f at t=%.6f\n", cpeak_early[][1], cpeak_early[][2])
    @printf("grid peak strain/break = %.5f at t=%.4f\n", cmax[][1], cmax[][2])
    wmask = findall(>=(RELAX_S), crows_t)
    if !isempty(wmask)
        @printf("window means (t>=10): omega_gnd=%.6f  omega_hub=%.6f  P=%.6f kW\n",
            sum(crows_wg[wmask]) / length(wmask), sum(crows_wh[wmask]) / length(wmask),
            sum(crows_P[wmask]) / length(wmask))
        @printf("window max strain/break = %.5f\n", maximum(crows_s[wmask]))
        tmask = findall(>=(45.0), crows_t)
        if !isempty(tmask)
            @printf("tail (t>=45, P_end analogue): omega_gnd=%.6f  P=%.6f kW\n",
                sum(crows_wg[tmask]) / length(tmask), sum(crows_P[tmask]) / length(tmask))
        end
    end
    outdir = joinpath(REPO, "docs", "reporting", "figures", "eval-timeline-extract")
    mkpath(outdir)
    csvpath = joinpath(outdir, "extract-eval-timeline-warm-rulingmode.csv")
    open(csvpath, "w") do io
        println(io, "# eval-timeline-extract / extract-eval-timeline-warm-rulingmode.csv")
        println(io, "# Warm-start CONDITION run (F3). Generated by scratch/av_f3_warm_diag2.jl.")
        println(io, "# run-id: eval-timeline-winner-warm-rulingmode")
        println(io, "# dataset: v13_5kw_masslift_len18.8_rotorcount_bankderate2 | tree ", h[1:min(8, length(h))])
        println(io, "# physics era: post-95c385d_wind-authority")
        println(io, "# path: warm start; rope-break gate OFF for t < 10 s, ON for t >= 10 s (pending 2026-09-16 placement)")
        println(io, "# note: not the as-coded machine. Completes 50 s, no window latch; 12.31-12.64 rad/s, 4.50-4.96 kW.")
        println(io, "t,omega_gnd,omega_hub,P_gen_kw,strain_max_over_break,any_broken")
        for i in eachindex(crows_t)
            @printf(io, "%.6f,%.9f,%.9f,%.9f,%.9f,%d\n",
                crows_t[i], crows_wg[i], crows_wh[i], crows_P[i], crows_s[i], Int(cbrk[]))
        end
    end
    println("ruling-mode CSV written: ", csvpath, " (", length(crows_t), " rows)")
    println("first 20 samples of the un-gated transient:")
    for i in 1:min(20, length(crows_t))
        @printf("  t=%.6f  wg=%.4f  wh=%.4f  P=%.6f  st=%.5f\n",
            crows_t[i], crows_wg[i], crows_wh[i], crows_P[i], crows_s[i])
    end
end

main()
