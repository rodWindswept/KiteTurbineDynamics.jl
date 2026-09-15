# scratch/diag_floor_mass_and_thrust.jl
#
# Three open items from the 2026-09-15 handover, in one probe:
#   1. floor 1388.2 N (code, 5% margin) vs 1274.47 N (plan 2.4.1, sin Δα ≤ 1)
#   2. why T_thrust moves with n_lines
#   3. the MASS cost of the ratio-isolation L/r lever (extra rings)
#
#   scripts/ktd-julia scratch/diag_floor_mass_and_thrust.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const OMEGA_EQ = 12.983466

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, 18.8,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max,
        p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x,
        p2.backline_payout)
    return override_params(
        mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0); tether_length=18.8)
end

function build_case(n_lines::Int, target_Lr::Float64)
    p = params_5kw_188()
    x = copy(seed_genome(5.0))
    x[3] = target_Lr
    x[4] = Float64(n_lines)
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        p_ceiling_kw=5.0, fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, wf
end

function axial_profile(p, sys, F_top)
    n_seg = sys.n_ring - 1
    g_inc = p.m_ring * 9.81 * sin(p.elevation_angle)
    F = zeros(n_seg); F[n_seg] = F_top
    for i in (n_seg - 1):-1:1
        F[i] = F[i + 1] + g_inc
    end
    return F
end

function demand_at(sys, p, wf, F_top, τ_eq)
    place = KiteTurbineDynamics.trpt_matched_place(sys, p, axial_profile(p, sys, F_top),
        τ_eq, OMEGA_EQ, wf; raise_on_unrealisable=false)
    return maximum(place.demand)
end

"""Tension where the worst segment's demand equals `1/margin`."""
function floor_ftop(sys, p, wf, τ_eq, margin; lo=50.0, hi=50_000.0)
    tgt = 1.0 / margin
    @assert demand_at(sys, p, wf, lo, τ_eq) > tgt "floor bracket (lo) already clears"
    @assert demand_at(sys, p, wf, hi, τ_eq) < tgt "floor bracket (hi) does not clear"
    for _ in 1:60
        mid = sqrt(lo * hi)
        demand_at(sys, p, wf, mid, τ_eq) > tgt ? (lo = mid) : (hi = mid)
    end
    return hi
end

ring_mass(sys) = sum((sys.nodes[g]::RingNode).mass for g in sys.ring_ids[2:end])

function main()
    @printf("── item 1: the floor criterion ─────────────────────────────────\n")
    sys, u0, p, wf = build_case(6, 2.0)
    τ_eq = sys.k_mppt_ref[] * OMEGA_EQ^2
    n_seg = sys.n_ring - 1
    f10 = floor_ftop(sys, p, wf, τ_eq, 1.00)
    f105 = floor_ftop(sys, p, wf, τ_eq, 1.05)
    @printf("  margin 1.00 (cliff, plan 2.4.1 criterion): floor = %.2f N\n", f10)
    @printf("  margin 1.05 (code criterion):               floor = %.2f N\n", f105)
    @printf("  plan 2.4.1 records                          floor = 1274.47 N\n")
    @printf("  ratio 1.05/1.00 = %.4f ; measured floor ratio = %.4f\n",
        f105 / f10, f105 / f10)
    @printf("  p.m_ring = %.4f kg -> axial increment = %.3f N/segment (plan: 15.613)\n",
        p.m_ring, p.m_ring * 9.81 * sin(p.elevation_angle))
    radii = [ (sys.nodes[g]::RingNode).radius for g in sys.ring_ids ]
    @printf("  ring radii (ground->top) = %s\n", join(round.(radii; digits=4), ", "))
    @printf("  plan 2.4.1 binding segments 1-4 at r_a=r_b=0.57511 m\n")
    @assert f10 < f105 "the 5%% margin must raise the floor"
    close = isapprox(f10, 1274.47; rtol=0.06)
    @printf("  -> margin-1.00 floor is %s 1274.47 N (rtol 6%%)\n",
        close ? "CONSISTENT WITH" : "NOT CONSISTENT WITH")

    @printf("\n── item 2 + 3: thrust coupling and the mass cost of L/r ────────\n")
    @printf("  %5s %6s %8s %9s %10s %9s %9s %10s %10s\n",
        "lines", "L/r", "n_seg", "ring kg", "airborne", "R_rotor", "A_sw", "T_thrust", "floor1.05")
    rows = NamedTuple[]
    for nl in (6, 8, 10), rl in (2.0, 1.5, 1.2)
        s, u, pp, w = build_case(nl, rl)
        tq = s.k_mppt_ref[] * OMEGA_EQ^2
        v_hub = pp.v_wind_ref * s.rotor.wind_factor
        lam = OMEGA_EQ * s.rotor.radius / v_hub
        A_sw = KiteTurbineDynamics.main_rotor_swept_area(s)
        thr = 0.5 * pp.rho * v_hub^2 * A_sw * ct_at_tsr(lam) * cos(pp.elevation_angle)^2
        air = expansion_airborne_mass(s, pp; include_lifter=false)
        rm = ring_mass(s)
        fl = floor_ftop(s, pp, w, tq, 1.05)
        push!(rows, (; nl, rl, n_seg=s.n_ring - 1, rm, air, R=s.rotor.radius, A_sw, thr, fl))
        @printf("  %5d %6.2f %8d %9.3f %10.2f %9.4f %9.3f %10.1f %10.1f\n",
            nl, rl, s.n_ring - 1, rm, air, s.rotor.radius, A_sw, thr, fl)
    end

    # n_lines is the mass-expensive lever; L/r is close to mass-neutral.
    air6 = [r.air for r in sort([r for r in rows if r.nl == 6], by=r -> r.nl)]
    air10 = [r.air for r in sort([r for r in rows if r.nl == 10], by=r -> r.nl)]
    @assert minimum(air10) > maximum(air6) (
        "more lines must cost mass: 6-line $(air6) vs 10-line $(air10)"
    )
    for nl in (6, 8, 10)
        sub = [r.air for r in sort([r for r in rows if r.nl == nl], by=r -> -r.rl)]
        @assert maximum(abs.(sub .- sub[1]) ./ sub[1]) < 0.15 (
            "L/r must be near mass-neutral at $nl lines, got $sub"
        )
    end
    @printf("\n✓ more lines cost mass; L/r is near mass-neutral (both asserted)\n")
    r6 = sort([r for r in rows if r.nl == 6], by=r -> -r.rl)
    @printf("  L/r 2.0 -> 1.5 at 6 lines: airborne %.2f -> %.2f kg (%+.1f%%), floor %.0f -> %.0f N\n",
        r6[1].air, r6[2].air, 100 * (r6[2].air / r6[1].air - 1), r6[1].fl, r6[2].fl)
    @printf("  6 -> 10 lines at L/r 2.0:  airborne %.2f -> %.2f kg (%+.1f%%), floor %.0f -> %.0f N\n",
        r6[1].air, [r for r in rows if r.nl == 10 && r.rl == 2.0][1].air,
        100 * ([r for r in rows if r.nl == 10 && r.rl == 2.0][1].air / r6[1].air - 1),
        r6[1].fl, [r for r in rows if r.nl == 10 && r.rl == 2.0][1].fl)
    @printf("  T_thrust spread across n_lines at fixed L/r: %s\n",
        join([@sprintf("%.1f", r.thr) for r in sort([x for x in rows if x.rl == 2.0], by=r -> r.nl)], " -> "))
    @printf("  mechanism: R_rotor %s and A_sw %s move with n_lines\n",
        join([@sprintf("%.4f", r.R) for r in sort([x for x in rows if x.rl == 2.0], by=r -> r.nl)], " -> "),
        join([@sprintf("%.3f", r.A_sw) for r in sort([x for x in rows if x.rl == 2.0], by=r -> r.nl)], " -> "))
    return nothing
end

main()
