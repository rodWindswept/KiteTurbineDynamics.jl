# scratch/diag_bow_shape.jl
#
# SELF-CHECKING diagnostic (2026-09-13): whole-assembly static relaxation of the
# 5 kW / 18.8 m campaign seed with the LIFT CHAIN AND BRIDLES FREE, then measure:
#
#   1. the bow profile — per-ring perpendicular offset from the design axis, where
#      the maximum is, and the local centreline tangent at each ring;
#   2. the RING-PLANE MODEL ERROR — the angle between the local centreline tangent
#      and the single global ring-plane normal the ODE actually uses
#      (dynamics.jl:29-52 -> _tilted_ring_basis, TILT_SCALE = 0.1, clamp 30 deg);
#   3. per-line TRPT tensions — the taut/slack partition, and whether the slack
#      lines sit on the belly (short) side or the back (long) side of the bow;
#   4. the chain: lift line, cyan, backline, bridle total;
#   5. the torsional-realisability ratio sin(dAlpha) = tau*chord/(n*T*r_a*r_b)
#      per segment (>1 = the segment cannot carry the torque at that tension).
#
# It ASSERTS its own sanity before reporting: the residual must respond to a
# position perturbation, and every reported tension must be finite.  A probe that
# cannot pass those refuses to print numbers (the 2026-09-12 lesson: the tools
# were wrong more often than the physics).
#
#   scripts/ktd-julia scratch/diag_bow_shape.jl --L0 6.4622 --budget 600

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: RopeSubSegment

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const OMEGA_EQ = 12.983466          # measured settle omega (handover 2026-09-12)
const BEARING_OFFSET = 6.0          # the placeholder used by the ODE's tilt law

# ── CLI ──────────────────────────────────────────────────────────────────
function argval(name, default)
    for (i, a) in enumerate(ARGS)
        a == name && i < length(ARGS) && return parse(Float64, ARGS[i + 1])
    end
    return default
end
const L0 = argval("--L0", 6.4622)
const BUDGET_S = argval("--budget", 600.0)
const DAMP = argval("--damp", 0.90)
const MAX_IT = argval("--maxit", 2_000_000.0)
const REPORT = 20_000

# ── Case builder (mirrors test_settle_validity.jl / test_settle_preload_consistency.jl) ──
function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

function build_case()
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function damp_translations!(u, N, rate)
    for gid in 2:N
        b = 3N + 3 * (gid - 1) + 1
        for k in 0:2
            u[b + k] *= rate
        end
    end
end

"Set the six bridle rest lengths in place (the builder uses the 6.462198 placeholder)."
function set_bridle_length!(sys, L0v)
    newsegs = RopeSubSegment[]
    h, b = sys.rotor.node_id, sys.bearing_id
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == h && nb == b) || (na == b && nb == h)
            push!(newsegs, RopeSubSegment(ss.end_a, ss.end_b, L0v, ss.EA, ss.c_damp, ss.diameter))
        else
            push!(newsegs, ss)
        end
    end
    sys.sub_segs[:] = newsegs
end

"""
The single global ring-plane normal the ODE actually uses, replicated exactly
from dynamics.jl:29-51 (shaft_dir = hub radial from the ORIGIN, then tilted by
min(TILT_SCALE * bearing offset perpendicular, 30 deg)).
"""
function model_tilted_normal(u, sys, hub_gid, bearing_gid)
    hub_pos = pos(u, hub_gid)
    shaft_dir = norm(hub_pos) > 0.1 ? hub_pos ./ norm(hub_pos) : [cos(0.5236), 0.0, sin(0.5236)]
    bearing_pos = pos(u, bearing_gid)
    bearing_design = hub_pos .+ BEARING_OFFSET .* shaft_dir
    bearing_error = bearing_pos .- bearing_design
    tilt_perp = bearing_error .- dot(bearing_error, shaft_dir) .* shaft_dir
    tilt_mag = norm(tilt_perp)
    tilt_angle = min(tilt_mag * 0.1, π / 6)
    tilt_dir_v = tilt_mag > 1e-9 ? tilt_perp ./ tilt_mag : zeros(3)
    tilted_normal = normalize(cos(tilt_angle) .* shaft_dir .+ sin(tilt_angle) .* tilt_dir_v .+
                              [1e-12, 1e-12, 1e-12])
    return tilted_normal, shaft_dir, tilt_angle
end

"Mean tension over the n_lines chains of TRPT segment s (rings s -> s+1)."
segment_line_tensions(u, sys, p, s) =
    [KiteTurbineDynamics.get_segment_tension(u, sys, p, s, j) for j in 1:p.n_lines]

function chain_tensions(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    bridle = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        re = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], re.line_idx, p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        bridle += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    cyan = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == bear && nb == sky) || (na == sky && nb == bear)
            L = norm(pos(u, sky) .- pos(u, bear))
            cyan = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        end
    end
    return bridle, cyan
end

"Every sub-segment that touches the sky anchor, with type/length/tension."
function sky_links(u, sys, p, N, Nr)
    sky = sys.sky_anchor_id
    rows = Tuple{Int,String,Float64,Float64,Float64}[]
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (na == sky || nb == sky) || continue
        other = na == sky ? nb : na
        tone = ss.end_a.is_ring ? ss.end_a : ss.end_b
        isring = (na == sky ? ss.end_a.is_ring : ss.end_b.is_ring)
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, sys.rotor.node_id, Nr)
        pa = if isring
            node = sys.nodes[other]::RingNode
            R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
            attachment_point(pos(u, other), R, u[6N + node.ring_idx], tone.line_idx, p.n_lines, pp1, pp2)
        else
            pos(u, other)
        end
        pb = pos(u, sky)
        L = norm(pb .- pa)
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        push!(rows, (other, string(typeof(sys.nodes[other])), ss.length_0, L, T))
    end
    return rows
end

function max_node_accel(u, sys, p, wf, lift, N)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    return maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
end

"Self-check R1/R2: the residual must respond to a perturbation, or we refuse to report."
function assert_residual_responds!(u, sys, p, wf, lift, N, hub_gid)
    du0 = zeros(length(u)); KiteTurbineDynamics.multibody_ode!(du0, u, (sys, p, wf, lift), 0.0)
    max_resp(gid, delta) = begin
        up = copy(u)
        up[3 * (gid - 1) + 3] += delta        # perturb z of the chosen node
        du1 = zeros(length(up))
        KiteTurbineDynamics.multibody_ode!(du1, up, (sys, p, wf, lift), 0.0)
        maximum(norm(du1[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
                     du0[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 2:N)
    end
    # Ground anchor is deliberately 1e30 kg (its own accel is ~0 by design), so
    # probe it for COUPLING and probe the hub for its own response.
    r_ground = max_resp(1, 1e-3)
    r_hub = max_resp(hub_gid, 1e-3)
    ok = all(isfinite, (r_ground, r_hub)) && r_ground > 1e-9 && r_hub > 1e-9
    @printf("  [self-check] residual responds: perturb ground -> max %.3e, perturb hub -> max %.3e  -> %s\n",
        r_ground, r_hub, ok ? "PASS" : "FAIL")
    ok || error("diagnostic harness is broken (residual does not respond); refusing to report")
    return nothing
end

function relax!(sys, p, u0, lift, wf, N, Nr; budget_s, damp, max_it, report_every)
    u = copy(u0)
    du = zeros(length(u))
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    hist = Tuple{Float64,Float64,Float64,Float64}[]
    t0 = time()
    it = 0
    done = false
    while it < max_it
        it += 1
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        @views u[(3N + 1):(6N)] .+= dt .* du[(3N + 1):(6N)]
        @views u[1:(3N)] .+= dt .* u[(3N + 1):(6N)]
        damp_translations!(u, N, damp)
        u[(6N + Nr + 1):(6N + 2Nr)] .= OMEGA_EQ
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        lift === nothing || KiteTurbineDynamics.update_kite_pos!(sys, u, lift, p, dt)

        if it == 1 || it % report_every == 0
            KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
            a = maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 2:N)
            hub_pos = pos(u, sys.rotor.node_id)
            sd = normalize(hub_pos)
            perp = norm(hub_pos .- dot(hub_pos, sd) .* sd)
            bridle, _ = chain_tensions(u, sys, p, N, Nr)
            push!(hist, (Float64(it), a, perp, bridle))
            @printf("  it=%9d  t=%6.1fs  max_accel(airborne)=%10.3f  hub_perp=%8.4f  bridle_T=%9.3f\n",
                it, time() - t0, a, perp, bridle)
        end
        if time() - t0 > budget_s
            done = true
            break
        end
    end
    return u, hist, it, time() - t0, done
end

function main()
    @printf("=== diag_bow_shape: L0(bridle rest)=%.6f m  budget=%.0f s  damp=%.3f ===\n",
        L0, BUDGET_S, DAMP)
    sys, u0, p, lift, wf = build_case()
    N, Nr = sys.n_total, sys.n_ring
    hub_gid = sys.rotor.node_id
    set_bridle_length!(sys, L0)

    W = expansion_airborne_mass(sys, p; include_lifter=false) * 9.81
    @printf("airborne mass = %.3f kg  W = %.2f N   n_lines=%d  n_rings=%d  n_segs=%d\n",
        expansion_airborne_mass(sys, p; include_lifter=false), W, p.n_lines, Nr, Nr - 1)
    @printf("backline payout=%.4f  EA=%.3e  lift T_ref=%.2f N\n",
        p.backline_payout, p.EA_back_line, lift.T_ref)

    # start from the equilibrium settle, then let the rings move freely
    # Start from the OPERATIONAL settle so the operating twist (and therefore the
    # transmitted torque) is present.  Its force balance is the known-bad one, so
    # it is only a starting geometry: the relaxation below is what seeks balance.
    u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    @printf("start: hub |r|=%.4f  bearing |r|=%.4f  sky |r|=%.4f\n",
        norm(pos(u, hub_gid)), norm(pos(u, sys.bearing_id)), norm(pos(u, sys.sky_anchor_id)))
    assert_residual_responds!(u, sys, p, wf, lift, N, hub_gid)

    uf, hist, iters, wall, capped = relax!(sys, p, u, lift, wf, N, Nr;
        budget_s=BUDGET_S, damp=DAMP, max_it=MAX_IT, report_every=REPORT)

    println("\n── relaxed state ────────────────────────────────────────────────────────────")
    @printf("iterations=%d  wall=%.1fs  %s\n", iters, wall, capped ? "(BUDGET CAPPED)" : "(converged/cap)")
    a_final = max_node_accel(uf, sys, p, wf, lift, N)

    # ── geometry: bow profile, local tangents, model ring plane ─────────────
    hub_pos = pos(uf, hub_gid)
    sd_design = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    tnormal, shaft_dir, tilt_angle = model_tilted_normal(uf, sys, hub_gid, sys.bearing_id)
    @printf("model ring-plane normal = %.6f %.6f %.6f   (tilt from hub-radius = %.4f deg, clamp 30)\n",
        tnormal..., rad2deg(tilt_angle))
    @printf("hub radius dir          = %.6f %.6f %.6f\n", shaft_dir...)
    @printf("design axis             = %.6f %.6f %.6f\n", sd_design...)

    ring_gids = [sys.ring_ids[ri] for ri in 1:Nr]
    centres = [pos(uf, g) for g in ring_gids]
    # local centreline tangent, one-sided at the ends
    tangents = Vector{Vector{Float64}}(undef, Nr)
    for ri in 1:Nr
        ta = ri > 1 ? centres[ri] .- centres[ri - 1] : centres[2] .- centres[1]
        tangents[ri] = ta ./ norm(ta)
    end

    @printf("\n  %3s %10s %10s %10s %12s %12s\n",
        "ring", "s_axial", "r_perp", "|pos|", "ang_to_model", "ang_to_design")
    for ri in 1:Nr
        c = centres[ri]
        s_ax = dot(c, sd_design)
        perp = norm(c .- s_ax .* sd_design)
        a_model = rad2deg(acos(clamp(abs(dot(tangents[ri], tnormal)), 0.0, 1.0)))
        a_design = rad2deg(acos(clamp(abs(dot(tangents[ri], sd_design)), 0.0, 1.0)))
        @printf("  %3d %10.4f %10.4f %10.4f %12.4f %12.4f%s\n",
            ri, s_ax, perp, norm(c), a_model, a_design, ri == Nr ? "   <- MAIN ROTOR" : "")
    end
    perps = [norm(centres[ri] .- dot(centres[ri], sd_design) .* sd_design) for ri in 1:Nr]
    imax = argmax(perps)
    @printf("  MAX bow = %.4f m at ring %d (s_axial=%.3f); hub perp = %.4f m\n",
        perps[imax], imax, dot(centres[imax], sd_design), perps[Nr])

    # ── chain + per-line TRPT tensions ──────────────────────────────────────
    bridle, cyan = chain_tensions(uf, sys, p, N, Nr)
    @printf("\n  chain: cyan=%.3f N  bridle_total=%.3f N (per bridle %.3f N)\n",
        cyan, bridle, bridle / p.n_lines)
    @printf("  lift requirement 1.5*W = %.2f N vertical\n", 1.5 * W)
    for (other, ty, L0v, Lcur, T) in sky_links(uf, sys, p, N, Nr)
        @printf("  sky-anchor link -> node %d (%s): L0=%.4f  L=%.4f  T=%.3f N\n",
            other, replace(ty, "KiteTurbineDynamics." => ""), L0v, Lcur, T)
    end

    println("\n  TRPT segment tensions (per line) and realisability sin(dAlpha):")
    @printf("  %4s %10s %10s %10s %8s %12s %12s\n",
        "seg", "T_min", "T_mean", "T_max", "n_slack", "tau_Nm", "sin(dAlpha)")
    ef = KiteTurbineDynamics.capture_extended(uf, sys, p, 0.0, wf, lift)
    unrealisable = 0
    for s in 1:(Nr - 1)
        ts = segment_line_tensions(uf, sys, p, s)
        nslack = count(<(5.0), ts)
        ri_a, ri_b = s, s + 1
        R_a = isempty(sys.expansion_rotors) ? (sys.nodes[ring_gids[ri_a]]::RingNode).radius :
              sys.effective_radii[ri_a]
        R_b = isempty(sys.expansion_rotors) ? (sys.nodes[ring_gids[ri_b]]::RingNode).radius :
              sys.effective_radii[ri_b]
        chord = norm(centres[ri_b] .- centres[ri_a])  # ~ line length between ring planes
        Tmean = ef.segment_tension[s]
        tau = ef.segment_torque[s]
        sin_da = tau * chord / max(p.n_lines * Tmean * R_a * R_b, 1e-12)
        sin_da > 1.0 && (unrealisable += 1)
        @printf("  %4d %10.3f %10.3f %10.3f %8d %12.3f %12.4f%s\n",
            s, minimum(ts), Tmean, maximum(ts), nslack, tau, sin_da,
            sin_da > 1.0 ? "  UNREALISABLE" : "")
    end

    # ── belly/back partition for the segment nearest the bow maximum ────────
    seg_probe = clamp(imax - 1, 1, Nr - 1)
    bow_dir = let c = centres[imax]
        pv = c .- dot(c, sd_design) .* sd_design
        norm(pv) > 1e-9 ? pv ./ norm(pv) : zeros(3)
    end
    @printf("\n  belly/back check, segment %d (bow direction is +):\n", seg_probe)
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(uf, sys, hub_gid, Nr)
    for j in 1:p.n_lines
        phi = uf[6N + seg_probe] + (j - 1) * (2π / p.n_lines)
        dirv = cos(phi) .* pp1 .+ sin(phi) .* pp2
        side = dot(dirv, bow_dir)
        @printf("    line %2d  cos(angle to bow) = % +.3f  %-9s T = %9.3f N\n",
            j, side, side > 0.25 ? "BACK(long)" : (side < -0.25 ? "BELLY(short)" : "side"),
            KiteTurbineDynamics.get_segment_tension(uf, sys, p, seg_probe, j))
    end

    @printf("\n  final max airborne node accel = %.3f m/s2\n", a_final)
    @printf("  hub axial residual = %.3f N\n",
        begin
            du = zeros(length(uf))
            KiteTurbineDynamics.multibody_ode!(du, uf, (sys, p, wf, lift), 0.0)
            m = (sys.nodes[hub_gid]).mass
            dot(m .* du[(3N + 3 * (hub_gid - 1) + 1):(3N + 3 * hub_gid)], shaft_dir)
        end)
    @printf("  unrealisable segments (sin(dAlpha) > 1): %d of %d\n", unrealisable, Nr - 1)
    any(!isfinite, perps) && error("non-finite geometry")
    return nothing
end

main()
