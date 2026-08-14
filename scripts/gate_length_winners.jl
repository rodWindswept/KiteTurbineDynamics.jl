#!/usr/bin/env julia --project=.
#= gate_length_winners.jl — ODE-gate the 18m and 25m winners side by side.
Uses the same 20s MPPT gate as ode_gate_5kw_winner.jl, plus the
pre-flight clearance check. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5
const ELEV = π / 6
const GROUND_OFFSET = 1.0

function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

function gate_winner(label::String, csv_path::String, L::Float64)
    x = [parse(Float64, s) for s in split(strip(read(csv_path, String)), ",")]
    p = params_at_length(L)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)

    # Pre-flight clearance
    zs = dec.zs; z_low = Inf; r_tip_low = 0.0
    for rotor in dec.rotors
        zr = zs[clamp(rotor.ring_idx, 1, length(zs))]
        if zr < z_low; z_low = zr; r_tip_low = rotor.blade_tip_radius; end
    end
    clearance = GROUND_OFFSET + z_low * sin(ELEV) - r_tip_low

    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    lift = rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    N = sys.n_total; Nr = sys.n_ring
    ω0 = u[6N + Nr + Nr]
    sys.k_mppt_ref[] = p.k_mppt

    # 20s gate with 5s checkpoints
    println("\n=== $label (L=$L m) ===")
    println("  n_lines=", dec.design.n_lines, " rings=", dec.n_rings,
            " n_active=", dec.n_active, " r_hub=", round(dec.design.r_hub, digits=2),
            " clearance=", round(clearance, digits=2), "m")
    for chunk in 1:4
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
        ω = u[6N + Nr + Nr]
        gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
        ω_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, p, chunk * 5.0, wind_fn; brake_engaged=sys.brake_engaged[])
        P = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
        @printf("  t=%2ds: ω=%5.2f  P=%.2f kW\n", chunk*5, ω, P)
    end
    ωf = u[6N + Nr + Nr]
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    ω_gnd = u[6N + Nr + gnd_ri]
    tau_gen, _ = get_generator_torque(u, sys, p, 20.0, wind_fn; brake_engaged=sys.brake_engaged[])
    Pf = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
    ok = (Pf >= 2.5) && (ωf > 0.5) && (clearance >= 1.5)
    @printf("  %s P_final=%.2f kW\n", ok ? "✅ GATE PASSES" : "❌ GATE FAILS", Pf)
    return (label=label, L=L, Pf=Pf, clearance=clearance, ok=ok,
            n_lines=dec.design.n_lines, rings=dec.n_rings,
            n_active=dec.n_active, r_hub=dec.design.r_hub,
            lam_t=x[13], lam_b=x[14])
end

r18 = gate_winner("18m winner", joinpath(@__DIR__, "results", "v12_5kw_len18.0", "best_vector.csv"), 18.0)
r25 = gate_winner("25m winner", joinpath(@__DIR__, "results", "v12_5kw_len25.0", "best_vector.csv"), 25.0)

println("\n\n=== SUMMARY ===")
for r in [r18, r25]
    @printf("%s: P=%.2f kW  clearance=%.2f m  n_lines=%d  rings=%d  n_active=%d  r_hub=%.2f  λ_t=%.3f  λ_b=%.3f  %s\n",
        r.label, r.Pf, r.clearance, r.n_lines, r.rings, r.n_active, r.r_hub,
        r.lam_t, r.lam_b, r.ok ? "PASS" : "FAIL")
end
