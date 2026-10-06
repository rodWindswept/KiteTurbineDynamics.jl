#!/usr/bin/env julia
# scratch/sv_fourstick_branch.jl — @science-validator, 2026-10-06
#
# Branch extension + independent reproduction of aero-worker's four-stick
# acceptance forecast (scratch/aw_acceptance_fourstick_s2.jl @ 613f3de; doc
# docs/validation/2026-10-06-acceptance-fourstick-s2-forecast.md).
# Constructions copied VERBATIM from that probe and the three fold-line test
# files it mirrors. The CONTROL section must reproduce the aw log to the
# printed digit; the two new genomes then ride a verified instrument.
#
# GENOMES
#   CONTROL = S2_FOLD_SEED (n=3)      — parity check vs aw log
#   N9      = S2_FOLD_SEED, x[4]=9.0  — the Q1-B-ruled launcher candidate
#                                       (only n=8/9 clear a matched-charge floor)
#   R124    = seed-55c r×1.24         — hermes_probe_seed_55c.jl construction
#                                       verbatim: winner CSV, radii ×1.24,
#                                       blade 1.0, bank 0; flight-verified
#                                       5.266/5.268 kW (aw, cf574a0)
#
# Run from a worktree at 613f3de:
#   JULIA_DEPOT_PATH=<main>/.julia_depot:$HOME/.julia scripts/ktd-julia scratch/sv_fourstick_branch.jl
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
include(joinpath(dirname(@__DIR__), "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const BEAM = PROFILE_ELLIPTICAL
const L18 = 18.8

# ── verbatim from test_evaluator_v13.jl (fold line 613f3de) ─────────────────
function v13_cfg(window_s::Float64, k_mppt::Float64; tether_diameter::Float64=0.003)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=k_mppt,          # K_MPPT_5KW_HONEST (2.24), the campaign operating point
        power_W=PW, v_rated=V_RATED,
        p_floor_kw=5.0, p_ceiling_kw=5.0,   # campaign floor/ceiling (was 2.5/5.0)
        relax_s=5.0, window_s=window_s,
        fos_target=2.5, fos_hard=2.5,        # campaign FoS (was 1.5)
        power_stat=:tail5, penalize_ceiling=false,
        kickstart_s=0.0,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        tether_diameter=tether_diameter,
    )
end

function run_eval(x::Vector{Float64}, L::Float64, window_s::Float64)
    p = params_at_length(params_daisy(), L, KW)
    xr = copy(x)
    # Accept the legacy 14-D campaign CSVs AND the canonical 10-D genome (R7).
    if length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: {1,2,3}
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))    # n_lines
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))     # rotor count
    end
    return KiteTurbineDynamics.evaluate_windowed(
        xr, BEAM, p, v13_cfg(window_s, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter);
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
end

# ── verbatim from test_settle_drag_alignment.jl (fold line 613f3de) ─────────
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    # LENGTH FIX (2026-08-22): mass_scale also scales the tether length; L is
    # the FINAL machine length — restore it after rung scaling.
    return override_params(scaled; tether_length=L)
end

stable_dt(sys, p) = KiteTurbineDynamics.stable_dt_for_system(sys, p)
window_steps(sys, p, t_seconds) = round(Int, t_seconds / stable_dt(sys, p))

function hub_omega(u, sys)
    return u[6*sys.n_total + 2*sys.n_ring]
end

# D build — canonical 10-D-aware clamp (run_eval's shape, the repoint's
# intended shape) plus the legacy 14-D clamp the current file applies.
function build_from_genome(x::Vector{Float64}, p::SystemParams; legacy_14d_clamp::Bool=false)
    xr = copy(x)
    if legacy_14d_clamp
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    elseif length(xr) >= 14
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    else
        xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
        xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    end
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p)
    return sys, u0, pc, dec
end

# D leg — verbatim measurement body from testsets A/D.
function measure_d(x::Vector{Float64}; legacy::Bool=false)
    p = params_at_length(18.8)
    sys, u0, pc, dec = build_from_genome(x, p; legacy_14d_clamp=legacy)
    lift = lift_for(sys, pc)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    ω_settle = hub_omega(u, sys)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    dt = stable_dt(sys, pc)
    run_canonical_sim!(u, sys, pc, wind_fn, window_steps(sys, pc, 20.0), dt;
        lift_device=lift, lin_damp=0.05)
    ωf = hub_omega(u, sys)
    Pf = sys.k_mppt_ref[] * ωf^3 / 1000.0
    gap = abs(ω_settle - ωf) / ω_settle
    return (ω_settle=ω_settle, ωf=ωf, Pf=Pf, gap=gap)
end

# ── genomes ─────────────────────────────────────────────────────────────────
const X_CONTROL = copy(S2_FOLD_SEED)
const X_N9 = (x = copy(S2_FOLD_SEED); x[4] = 9.0; x)
const X_R124 = begin
    xr = [3.8346727372419207, 0.7968682519739593, 2.0999999999999996, 3.0,
          0.22525551607801375, 1.26727299084247, 10.739909223435728,
          7.182981922129365, 0.6994456787050004, 1.0]
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))   # 3
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))    # 1
    xr[9] = 1.00                                       # blade 1.00
    xr[1] = xr[1] * 1.24                               # rad_scale
    xr[2] = xr[2] * 1.24
    xr[7] = 0.0                                        # bank 0
    xr
end

function run_genome(label::String, x::Vector{Float64}; with_legacy::Bool=false)
    println()
    println("################################################################")
    println("### GENOME ", label)
    println("################################################################")

    println()
    println("=== A1 (test_gate_v13: settle 60 s/30k + 10 s relax + 30 s window) ===")
    r = gate_design(copy(x); L=L18, KW=KW)
    println("  ok=", r.ok, "  P_gen_final=", r.P_gen_final, " kW  w_gnd=", r.w_gnd_final,
        " rad/s  clearance=", r.clearance, " m  crossed=", r.crossed,
        "  max_twist_ratio=", r.max_twist_ratio, "  line_broken=", r.line_broken)
    println("  machine: n_lines=", r.n_lines, " rings=", r.rings, " n_active=", r.n_active,
        " r_hub=", r.r_hub)
    println("  A1 assert (ok == true): ", r.ok ? "PASS" : "FAIL")
    if r.ok
        hub_ri = (r.sys.nodes[r.sys.rotor.node_id]::RingNode).ring_idx
        w_hub = r.u[6*r.N + r.Nr + hub_ri]
        hub_tip = abs(w_hub) * r.sys.rotor.radius
        println("  B6b-style tip via gate state: hub_tip=", round(hub_tip, digits=2),
            " m/s  tip_ok=", KiteTurbineDynamics.tip_speed_sanity_ok(r.u, r.sys))
    end
    flush(stdout)

    println()
    println("=== B6 (test_evaluator_v13: cold + relax 5 s + window 20 s, tail5) ===")
    r6 = run_eval(copy(x), L18, 20.0)
    println("  status=", r6.status, "  P_mean=", r6.P_mean, " kW  FoS_min=", r6.FoS_min,
        "  fitness=", r6.fitness)
    println("  B6a assert (status :ok && FoS_min >= 2.5): ",
        (r6.status === :ok && r6.FoS_min >= 2.5) ? "PASS" : "FAIL")
    println("  B6c assert (P_mean >= 5.0): ", (r6.status !== :reject && r6.P_mean >= 5.0) ? "PASS" : "FAIL")
    flush(stdout)

    println()
    println("=== D (test_settle_drag_alignment: 30k settle + 20 s canonical, Pf = k·ωf³/1000) ===")
    d1 = measure_d(copy(x))
    println("  w_settle=", d1.ω_settle, " rad/s  wf=", d1.ωf, " rad/s  Pf=", d1.Pf,
        " kW  gap=", d1.gap)
    println("  D assert (Pf >= 5.0): ", d1.Pf >= 5.0 ? "PASS" : "FAIL")
    flush(stdout)

    if with_legacy
        println()
        println("=== D sensitivity — the current file's 14-D clamp applied to the 10-D seed ===")
        d2 = measure_d(copy(x); legacy=true)
        println("  w_settle=", d2.ω_settle, " rad/s  wf=", d2.ωf, " rad/s  Pf=", d2.Pf,
            " kW  gap=", d2.gap)
        println("  D assert (Pf >= 5.0): ", d2.Pf >= 5.0 ? "PASS" : "FAIL")
        flush(stdout)
    end
end

function main()
    root = dirname(@__DIR__)
    sha = strip(read(`git -C $root rev-parse HEAD`, String))
    println("# sv_fourstick_branch.jl — science-validator branch extension @ ", sha)
    println("# date=", strip(read(`date -u +%Y-%m-%dT%H:%MZ`, String)))
    println("# basis=fold line (s2-fold-seed), campaign k=2.24, cold start, L=18.8")
    @assert seed_genome(5.0) == S2_FOLD_SEED "seed_genome(5.0) != S2_FOLD_SEED at $sha"
    println("# genomes: CONTROL=S2_FOLD_SEED(n3), N9=S2_FOLD_SEED x[4]=9, R124=55c r×1.24")

    run_genome("CONTROL S2_FOLD_SEED (n=3)", X_CONTROL; with_legacy=true)
    run_genome("N9 S2_FOLD_SEED x[4]=9.0", X_N9)
    run_genome("R124 55c r×1.24 (winner CSV ×1.24 radii, blade 1.0, bank 0)", X_R124)

    println()
    println("SV_FOURSTICK_BRANCH DONE")
end

main()
