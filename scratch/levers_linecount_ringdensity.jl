# scratch/levers_linecount_ringdensity.jl
#
# Two preload levers that do NOT touch the lift line (Rod 2026-09-15):
#
#   x[4] n_lines      — T_top is INDEPENDENT of n_lines (the bridle term cancels:
#                       n·T_bridle·cosθ = T_cyan_ax − W_bearing·sinβ) while
#                       demand = τ_carry/τ_max ∝ 1/n_lines.
#   x[3] target_Lr    — L/r per segment.  LOWER L/r ⇒ shorter segments and more
#                       rings ⇒ WANTED-RADIUS SPACING per segment and a smaller
#                       chord, so demand ∝ chord should fall.
#
# Measures, for each combination, the worst realisability demand at the design
# chain preload with a RIGID TAUT back line at el = 70°, against the 1/1.05
# target.  Also prints the back-line direction, to settle whether it is
# near-vertical.
#
#   scripts/ktd-julia scratch/levers_linecount_ringdensity.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const BRIDLE_EA = 500_000.0
const BEARING_MASS = 0.3
const SKY_MASS = 0.3
const CYAN_L0 = 5.0
const OMEGA_EQ = 12.983466
const MARGIN = KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
const TARGET = 1.0 / MARGIN

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, 18.8,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    return override_params(
        mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
        tether_length=18.8,
    )
end

function build_case(n_lines::Int, target_Lr::Float64)
    p = params_5kw_188()
    x = copy(seed_genome(5.0))
    x[3] = target_Lr                 # target_Lr (L/r per segment)
    x[4] = Float64(n_lines)          # n_lines
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    cfg = ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST,
    )
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function axial_profile(p, sys, F_top)
    n_seg = sys.n_ring - 1
    g_inc = p.m_ring * 9.81 * sin(p.elevation_angle)
    F = zeros(n_seg)
    F[n_seg] = F_top
    for i in (n_seg - 1):-1:1
        F[i] = F[i + 1] + g_inc
    end
    return F
end

function demand_at(sys, p, wf, F_top, τ_eq)
    place = KiteTurbineDynamics.trpt_matched_place(
        sys, p, axial_profile(p, sys, F_top), τ_eq, OMEGA_EQ, wf;
        raise_on_unrealisable=false,
    )
    return maximum(place.demand)
end

function floor_ftop(sys, p, wf, τ_eq; lo=50.0, hi=50_000.0)
    @assert demand_at(sys, p, wf, lo, τ_eq) > TARGET "floor bracket (lo) already clears"
    @assert demand_at(sys, p, wf, hi, τ_eq) < TARGET "floor bracket (hi) does not clear"
    for _ in 1:60
        mid = sqrt(lo * hi)
        if demand_at(sys, p, wf, mid, τ_eq) > TARGET
            lo = mid
        else
            hi = mid
        end
    end
    return hi
end

"""Taut sky-anchor chain at el = 70°: returns T_top and the back-line direction."""
function design_chain(sys, u0, p, wf)
    hub = sys.rotor.node_id
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(sh)
    R_hub = (sys.nodes[hub]::RingNode).radius
    hub_pos = pos(u0, hub)
    bo = KiteTurbineDynamics.bridle_bearing_offset(R_hub)

    v_hub = p.v_wind_ref * sys.rotor.wind_factor
    λ = OMEGA_EQ * sys.rotor.radius / v_hub
    A_sw = KiteTurbineDynamics.main_rotor_swept_area(sys)
    T_thrust = 0.5 * p.rho * v_hub^2 * A_sw * ct_at_tsr(λ) * cos(β)^2
    W_rotor = p.n_blades * p.m_blade * 9.81

    lift = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true,
                            elevation_deg=70.0)
    _, T_lift, _ = lift_force_steady(lift, p.rho, p.v_wind_ref, nothing)
    el = deg2rad(70.0)

    bearing_pos = hub_pos .+ bo .* sh
    sky_pos = bearing_pos .+ CYAN_L0 .* sh
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_dir = normalize([back_ax, 0.0, 0.0] .- sky_pos)
    cyan_dir = normalize(bearing_pos .- sky_pos)
    A = [back_dir[1] cyan_dir[1]; back_dir[3] cyan_dir[3]]
    rhs = [-T_lift * cos(el); -T_lift * sin(el) + SKY_MASS * 9.81]
    sol = A \ rhs
    T_back, T_cyan = sol[1], sol[2]

    T_cyan_ax = -T_cyan * dot(cyan_dir, sh)
    pa = attachment_point(hub_pos, R_hub, 0.0, 1, p.n_lines, perp1, perp2)
    gap = norm(bearing_pos .- pa)
    cosθ = bo / gap
    T_bridle = (T_cyan_ax - BEARING_MASS * 9.81 * sin(β)) / (p.n_lines * cosθ)
    T_top = T_thrust + p.n_lines * T_bridle * cosθ - W_rotor * sin(β)
    angle_off_vertical = rad2deg(atan(abs(back_dir[1]), abs(back_dir[3])))
    return (; T_top, T_back, T_cyan, T_thrust, back_dir, angle_off_vertical, R_hub, bo)
end

function main()
    @printf("target demand = 1/%.2f = %.4f\n\n", MARGIN, TARGET)

    # ── Back-line direction, to settle the geometry question ─────────────────
    sys0, u00, p0, wf0 = build_case(6, 2.0)
    d0 = design_chain(sys0, u00, p0, wf0)
    @printf("back-line direction = [%.4f, %.4f, %.4f]  -> %.1f° off vertical\n",
        d0.back_dir[1], d0.back_dir[2], d0.back_dir[3], d0.angle_off_vertical)
    @assert abs(d0.angle_off_vertical) < 25.0 (
        "back line is NOT near-vertical ($(d0.angle_off_vertical)° off) — the vertical-only " *
        "assumption would be wrong"
    )
    @printf("✓ back line is near-vertical (%.1f° off) — it reacts vertical tension, not the downwind force\n\n",
        d0.angle_off_vertical)

    # ── Grid ─────────────────────────────────────────────────────────────────
    line_counts = [6, 8, 10]
    rls = [2.0, 1.5, 1.2]
    @printf("  %5s %8s %6s %10s %10s %10s %9s\n",
        "lines", "L/r", "n_seg", "T_top", "floor", "demand", "verdict")
    rows = NamedTuple[]
    for nl in line_counts, rl in rls
        sys, u0, p, wf = build_case(nl, rl)
        n_seg = sys.n_ring - 1
        τ_eq = sys.k_mppt_ref[] * OMEGA_EQ^2
        d = design_chain(sys, u0, p, wf)
        dem = demand_at(sys, p, wf, d.T_top, τ_eq)
        fl = floor_ftop(sys, p, wf, τ_eq)
        verdict = dem <= TARGET ? "CLEARS" : "short $(round(100 * (dem / TARGET - 1)))%"
        push!(rows, (; nl, rl, n_seg, T_top=d.T_top, floor=fl, demand=dem,
                     built_lines=p.n_lines))
        @printf("  %5d %8.2f %6d %10.1f %10.1f %10.4f  %s\n",
            nl, rl, n_seg, d.T_top, fl, dem, verdict)
        @printf("        [diag] pc.n_lines=%d R_hub=%.4f T_thrust=%.1f T_cyan=%.1f T_back=%.1f |hub|=%.4f\n",
            p.n_lines, d.R_hub, d.T_thrust, d.T_cyan, d.T_back,
            norm(pos(u0, sys.rotor.node_id)))
    end

    # ── Assertions: the effects must show, not be assumed ────────────────────
    for rl in rls
        sub = sort([r for r in rows if r.rl == rl], by=r -> r.nl)
        @assert all(diff([r.demand for r in sub]) .< 0) (
            "demand must fall as n_lines rises at L/r=$rl: $([r.demand for r in sub])"
        )
    end
    for nl in line_counts
        sub = sort([r for r in rows if r.nl == nl], by=r -> -r.rl)
        @assert all(diff([r.demand for r in sub]) .< 0) (
            "demand must fall as L/r falls at n_lines=$nl: $([r.demand for r in sub])"
        )
    end
    @printf("\n✓ demand falls with more lines, and falls with lower L/r (both asserted)\n")

    clearing = [r for r in rows if r.demand <= TARGET]
    if isempty(clearing)
        @printf("✗ no combination in the grid clears the target\n")
    else
        @printf("✓ clears at: %s\n",
            join(["$(r.nl) lines / L/r $(r.rl)" for r in clearing], ", "))
    end
    @printf("  T_top spread across the grid: %.1f–%.1f N (n_lines-independence check)\n",
        minimum(r.T_top for r in rows), maximum(r.T_top for r in rows))
    return nothing
end

main()
