#!/usr/bin/env julia --project=.
# av_rb_ab_check.jl — why does the eval-path warm run differ from the direct warm_build?
# A: evaluate_windowed(:warm) — the eval path (raw genome)
# B: direct build from the RAW genome (no clamps)
# C: direct build from the CLAMPED genome (diag2/runner style)
# Compare build invariants + a trajectory checksum.
using KiteTurbineDynamics, Printf, LinearAlgebra, DelimitedFiles
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

function build_invariants(sys, pc)
    n_lines = pc.n_lines
    sink = 0.0
    for i in 1:sys.n_total
        node = sys.nodes[i]
        sink += node.mass
    end
    rsum = isempty(sys.effective_radii) ? 0.0 : sum(sys.effective_radii)
    return (n_lines=n_lines, n_ring=sys.n_ring, n_total=sys.n_total,
        mass=round(sink, digits=9), rsum=round(rsum, digits=9))
end

# trajectory checksum from a callback: last-10000-window omega_gnd sum + endpoint samples
function make_tap(sys)
    N = sys.n_total
    Nr = sys.n_ring
    acc = Ref(0.0)
    ntail = Ref(0)
    samples = Float64[]
    total = Ref(0)
    function tap(u, t, s)
        total[] = s
        wg = u[6N + Nr + 1]
        if t > (RELAX_S + WINDOW_S) - 0.145   # last ~5000 steps worth
            acc[] += wg
            ntail[] += 1
        end
        if s > 1_000_000 && length(samples) < 5 && t > 10
            push!(samples, wg)
        end
    end
    return (; tap, acc, ntail, samples, total)
end

function direct_run(xvec::Vector{Float64}, label::String, p_base, cfg)
    x_canon = KiteTurbineDynamics.canonical_v10(xvec)
    println(label, " canonical = ", x_canon)
    result = KiteTurbineDynamics.design_from_vector_v10(
        x_canon, PROFILE_ELLIPTICAL, p_base;
        power_W=cfg.power_W, v_rated=cfg.v_rated,
        cylinder_cone=true, rotor_count_mode=cfg.rotor_count_mode,
        power_split=cfg.power_split, cone_slope_deg=cfg.cone_slope_deg,
        rotor_spacing_frac=cfg.rotor_spacing_frac,
        blocking_factor=cfg.blocking_factor, beam_t_over_D=cfg.t_over_D,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(result, p_base, cfg)
    k_mppt = clamp(cfg.k_mppt, 0.01, KiteTurbineDynamics.K_MPPT_MAX)
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
    ω_eq = sizing.omega_eq
    N = sys.n_total
    Nr = sys.n_ring
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3 * (gid - 1) + 1):(3 * gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]
            tang ./= norm(tang)
            vx_idx = 3N + 3 * (gid - 1) + 1
            u[vx_idx:(vx_idx + 2)] .= (ω_eq * r) .* tang
        end
    end
    sys.k_mppt_ref[] = k_mppt
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    total_n = round(Int, (RELAX_S + WINDOW_S) / dt)
    tapset = make_tap(sys)
    KiteTurbineDynamics.run_canonical_sim!(
        u, sys, pc, wf, total_n, dt;
        lift_device=lift_dev, lin_damp=0.05, callback=tapset.tap,
        breaks_enabled=true, breaks_arm_s=RELAX_S,
    )
    inv = build_invariants(sys, pc)
    @printf("%s: dt=%.8f inv=(lines %d, rings %d, mass %.6f, rsum %.6f) tail_wg=%.9f n=%d\n",
        label, dt, inv.n_lines, inv.n_ring, inv.mass, inv.rsum,
        tapset.acc[] / max(tapset.ntail[], 1), tapset.ntail[])
    return u
end

function main()
    v = vec(readdlm(WINNER, ',', Float64))
    xr = copy(v)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    p_base = params_at_length(LENGTH)
    cfg = ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=RELAX_S, window_s=WINDOW_S,
        fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0, k_mppt=K_MPPT_5KW_HONEST,
        tether_diameter=p_base.tether_diameter,
        rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        min_wall_m=MIN_WALL_M,
    )

    println("raw     = ", v)
    println("clamped = ", xr, "  (slot6 ", v[6], " -> ", xr[6], ")")

    println("\n== A: evaluate_windowed(:warm), raw genome ==")
    acc = Ref(0.0); ntail = Ref(0); Nref = Ref(0); Nrref = Ref(0); hubref = Ref(0)
    function cbA(u, t, s, ctx)
        if Nref[] == 0
            Nref[] = ctx.sys.n_total
            Nrref[] = ctx.sys.n_ring
            hubref[] = (ctx.sys.nodes[ctx.sys.rotor.node_id]::KiteTurbineDynamics.RingNode).ring_idx
        end
        if t > (RELAX_S + WINDOW_S) - 0.145
            acc[] += u[6Nref[] + Nrref[] + 1]
            ntail[] += 1
        end
    end
    rA = KiteTurbineDynamics.evaluate_windowed(
        v, PROFILE_ELLIPTICAL, p_base, cfg;
        start_mode=:warm, lift_device=lift_for,
        trace_callback=cbA,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
    @printf("A: eval result status=%s broken=%s P_mean=%.6f P_end=%.6f wg_tail=%.9f n=%d\n",
        rA.status, rA.line_broken, rA.P_mean, rA.P_end, acc[] / max(ntail[], 1), ntail[])

    println("\n== B: direct, raw genome ==")
    _ = direct_run(v, "B", p_base, cfg)
    println("\n== C: direct, clamped genome ==")
    _ = direct_run(xr, "C", p_base, cfg)
end

main()
