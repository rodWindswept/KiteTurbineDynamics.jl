#!/usr/bin/env julia --project=.
#= ode_gate_v13.jl — re-instrumented ODE gate (generator-side power + per-segment
twist collapse detector). Replaces the hub-power gate logic in
gate_length_winners.jl / ode_gate_5kw_winner.jl.

Instruments (both read the ODE's own state):
  1. P_gen = τ_gen·ω_gnd, τ_gen from get_generator_torque — the exact function
     the ODE uses (Mode 0 MPPT extracts at the GROUND ring, src/ring_forces.jl:70).
     NOT k·ω_hub³ (which read freewheel power during collapse).
  2. Per-segment twist Δα_i = |α[i+1]−α[i]| vs the geometric crossing limit
     δα*_i = 2·asin(L_seg/√(2(L_seg²+2r²))), r = max(r_i, r_{i+1}) (conservative).
     Any segment past its limit ⇒ torsional collapse ⇒ fail regardless of power.

Window: 30 s in 5 s chunks after settle (ceiling 60, 30k ops). Also kept:
clearance ≥ 1.5 m, P_gen ≥ 2.5 kW, ω_gnd > 0.5 rad/s.

Usage: julia --project=. scripts/ode_gate_v13.jl [csv_path] [--length L] [--kw P]
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const DT = 4e-5
const ELEV = π / 6
const GROUND_OFFSET = 1.0
const MIN_CLEARANCE = 1.5
const MIN_P_GEN_KW = 2.5
const MIN_W_GND = 0.5

"""Canonical mass-aware constant-tension lift (AC-LIFT, 2026-08-20, Rod's ruling).

One lift concept+values across build, settle, ODE, gate, evaluator, runner and
tests.  `lift_for(sys, p)` is passed as the `lift_device` FUNCTION to
`evaluate_windowed` (which calls it as `lift_for(sys, pc)`), and called directly
as `lift_for(sys, pc)` by the gate and its tests."""
lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=11.0, const_tension=true)

function params_at_length(p2, L::Float64, KW::Float64)
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

"""Per-segment twist vs geometric crossing limit. Returns (crossed, max_ratio,
worst_seg, per-segment rows). α states are free-integrated (no wrap) per
src/dynamics.jl twist layout u[6N+1:6N+Nr]. Conservative r = max(r_i, r_{i+1})
gives the smallest δα* (tightest limit)."""
function twist_report(u, sys, N, Nr)
    alpha = u[(6N + 1):(6N + Nr)]
    crossed = false
    max_ratio = 0.0
    worst_seg = 0
    rows = Vector{NamedTuple{(:seg, :da_deg, :dastar_deg, :ratio),Tuple{Int,Float64,Float64,Float64}}}()
    for ri in 1:(Nr - 1)
        r_i = (sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        r_ip1 = (sys.nodes[sys.ring_ids[ri+1]]::RingNode).radius
        r_seg = max(r_i, r_ip1)
        p_i = u[(3 * (sys.ring_ids[ri] - 1) + 1):(3 * sys.ring_ids[ri])]
        p_ip1 = u[(3 * (sys.ring_ids[ri+1] - 1) + 1):(3 * sys.ring_ids[ri+1])]
        L_seg = norm(p_ip1 - p_i)
        dastar = rad2deg(2 * asin(min(L_seg / sqrt(2 * (L_seg^2 + 2 * r_seg^2)), 1.0)))
        da = abs(rad2deg(alpha[ri+1] - alpha[ri]))
        ratio = da / max(dastar, 1e-9)
        if ratio > max_ratio
            max_ratio = ratio
            worst_seg = ri
        end
        crossed |= da > dastar
        push!(rows, (seg=ri, da_deg=da, dastar_deg=dastar, ratio=ratio))
    end
    return (crossed=crossed, max_ratio=max_ratio, worst_seg=worst_seg, rows=rows)
end

function gate_design(x::Vector{Float64}; L::Float64, KW::Float64=5.0,
        window_s::Float64=30.0, p2=params_10kw())
    p = params_at_length(p2, L, KW)
    xv = copy(x)
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = clamp(xv[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p; power_W=KW * 1000.0)

    # Pre-flight clearance
    zs = dec.zs
    z_low = Inf
    r_tip_low = 0.0
    for rotor in dec.rotors
        zr = zs[clamp(rotor.ring_idx, 1, length(zs))]
        if zr < z_low
            z_low = zr
            r_tip_low = rotor.blade_tip_radius
        end
    end
    clearance = GROUND_OFFSET + z_low * sin(ELEV) - r_tip_low

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    # Canonical mass-aware constant-tension lift (AC-LIFT, 2026-08-20).
    lift = lift_for(sys, pc)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    N = sys.n_total
    Nr = sys.n_ring
    sys.k_mppt_ref[] = p.k_mppt

    hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx

    trace = Vector{NamedTuple{(:t, :w_hub, :w_gnd, :P_gen, :tau_gen, :crossed, :max_ratio),
        Tuple{Float64,Float64,Float64,Float64,Float64,Bool,Float64}}}()
    nchunks = round(Int, window_s / 5.0)
    for chunk in 1:nchunks
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0 / DT), DT; lift_device=lift, lin_damp=0.05)
        t = chunk * 5.0
        w_hub = u[6N + Nr + hub_ri]
        w_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, p, t, wind_fn; brake_engaged=sys.brake_engaged[])
        P_gen = tau_gen * w_gnd / 1000.0   # signed (2026-08-20): reversed ring reads negative
        tr = twist_report(u, sys, N, Nr)
        push!(trace, (t=t, w_hub=w_hub, w_gnd=w_gnd, P_gen=P_gen, tau_gen=tau_gen,
            crossed=tr.crossed, max_ratio=tr.max_ratio))
    end

    fin = trace[end]
    ok = (fin.P_gen >= MIN_P_GEN_KW) && (fin.w_gnd > MIN_W_GND) && (!fin.crossed) &&
         (clearance >= MIN_CLEARANCE)
    return (ok=ok, trace=trace, clearance=clearance, P_gen_final=fin.P_gen,
        w_gnd_final=fin.w_gnd, w_hub_final=fin.w_hub, crossed=fin.crossed,
        max_twist_ratio=fin.max_ratio, n_lines=dec.design.n_lines, rings=dec.n_rings,
        n_active=dec.n_active, r_hub=dec.design.r_hub, x=xv, sys=sys, u=u, N=N, Nr=Nr)
end

# ── CLI ─────────────────────────────────────────────────────────────────
function parse_args()
    csv = length(ARGS) > 0 && !startswith(ARGS[1], "--") ? ARGS[1] :
          joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv")
    L = 21.2
    KW = 5.0
    for (i, a) in enumerate(ARGS)
        if a == "--length" && i < length(ARGS)
            L = parse(Float64, ARGS[i+1])
        elseif a == "--kw" && i < length(ARGS)
            KW = parse(Float64, ARGS[i+1])
        end
    end
    return csv, L, KW
end

if abspath(PROGRAM_FILE) == @__FILE__
    csv, L, KW = parse_args()
    x = [parse(Float64, s) for s in split(strip(read(csv, String)), ",")]
    r = gate_design(x; L=L, KW=KW)
    println("=== ode_gate_v13: ", basename(csv), "  L=", L, " m  P=", KW, " kW ===")
    println("  n_lines=", r.n_lines, " rings=", r.rings, " n_active=", r.n_active,
            " r_hub=", round(r.r_hub, digits=2), " clearance=", round(r.clearance, digits=2), " m")
    println("    t(s)   ω_hub   ω_gnd   P_gen(kW)   τ_gen    crossed  twist_ratio")
    for row in r.trace
        @printf("  %5.1f  %6.2f  %6.2f  %9.2f  %8.1f  %7s  %10.1f\n",
            row.t, row.w_hub, row.w_gnd, row.P_gen, row.tau_gen,
            row.crossed ? "YES" : "no", row.max_ratio)
    end
    tr = twist_report(r.u, r.sys, r.N, r.Nr)
    if tr.worst_seg == 0
        println("  no segment wind-up (max ratio 0.0)")
    else
        println("  worst segment: ", tr.worst_seg, "  Δα=", round(tr.rows[tr.worst_seg].da_deg, digits=1),
                "° vs δα*=", round(tr.rows[tr.worst_seg].dastar_deg, digits=1), "°")
    end
    # Tip-speed sanity: every ring rim and every rotor tip must stay under
    # the ceiling (100 m/s — design point ~44 m/s at TSR 4, 11 m/s wind).
    # A diverged ring (ω ~ 1e66, NaN-frozen chain) is not "sustained power".
    hub_ok = tip_speed_sanity_ok(r.u, r.sys)
    ok = r.ok && hub_ok
    println(r.ok && !hub_ok ? "  ❌ TIP SPEED VIOLATION > " * string(TIP_SPEED_CEILING_MPS) * " m/s (diverged ring/rotor)" : "")
    println(ok ? "  ✅ GATE PASSES" : "  ❌ GATE FAILS",
            "  (P_gen_final=", round(r.P_gen_final, digits=2),
            " kW, ω_gnd=", round(r.w_gnd_final, digits=2), " rad/s, crossed=", r.crossed,
            ", tip_ok=", hub_ok, ")")
end
