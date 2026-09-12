# scratch/preload_thrust_budget.jl
#
# READ-ONLY. Rod's question (2026-09-12): "Did you also include rotor thrust in your
# line tension calculation? (or multi rotors thrusts...?)"
#
# Answer measured here.  The campaign seed has THREE rotors:
#   - the main/hub rotor on the topmost ring (ring 9)
#   - expansion rotors on ring 8 and ring 7
#
# This totals the axial thrust of every rotor, then closes the hub axial budget
# against the ODE's measured residual.  Earlier in this session the budget used the
# main rotor ONLY (309.4 N), which is why it failed to close by ~940 N.
#
#   scripts/ktd-julia scratch/preload_thrust_budget.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: main_rotor_swept_area, ct_at_tsr, expansion_rotor_forces
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))
    w = u[6N + Nr]

    v_wind = wf(pos(u, hub), 0.0)
    v_hub = norm(v_wind) * sys.rotor.wind_factor
    lam = abs(w) * sys.rotor.radius / v_hub
    A_hub = main_rotor_swept_area(sys)
    T_main = 0.5 * p.rho * v_hub^2 * A_hub * ct_at_tsr(lam) * cos(p.elevation_angle)^2.0

    @printf("omega = %.6f rad/s\n", w)
    @printf("MAIN rotor (hub ring %d):\n", Nr)
    @printf("  v_hub=%.4f m/s  lambda=%.4f  ct=%.5f  A=%.4f m2\n", v_hub, lam, ct_at_tsr(lam), A_hub)
    @printf("  axial thrust = %+10.4f N  (up-shaft)\n", T_main)

    tot_exp = 0.0
    for er in sys.expansion_rotors
        gid = sys.ring_ids[er.ring_idx]
        r_nom = (sys.nodes[gid]::RingNode).radius
        vwm = norm(wf(pos(u, gid), 0.0)) * er.wind_factor
        T_est = T_main
        Fr, Fa, tn, re, _ = expansion_rotor_forces(
            er, p.rho, vwm, w, rad2deg(p.elevation_angle), r_nom, T_est, p.n_lines)
        @printf("EXPANSION rotor (ring %d, r=%.4f, n_blades=%d):\n", er.ring_idx, r_nom, er.n_blades)
        @printf("  v_wind=%.4f m/s  bank=%.1f deg\n", vwm, er.bank_angle_deg)
        @printf("  F_radial/blade=%+10.4f N  F_axial/blade=%+10.4f N  -> axial total %+10.4f N\n",
            Fr, Fa, er.n_blades * Fa)
        tot_exp += er.n_blades * Fa
    end
    T_all = T_main + tot_exp
    G = (sys.nodes[hub]::RingNode).mass * 9.81

    # transmission top-segment axial from the placed geometry
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2
    ga = sys.ring_ids[Nr - 1]
    na = sys.nodes[ga]::RingNode
    L_seg = ROPE_SUBSEGS * sys.sub_segs[(Nr - 2) * p.n_lines * ROPE_SUBSEGS + 1].length_0
    axT = 0.0
    for j in 1:p.n_lines
        pa = attachment_point(pos(u, ga), na.radius, u[6N + Nr - 1], j, p.n_lines, pp1, pp2)
        pb = attachment_point(pos(u, hub), (sys.nodes[hub]::RingNode).radius, u[6N + Nr],
                              j, p.n_lines, pp1, pp2)
        d = pb .- pa
        L = norm(d)
        T = EA * max(0.0, (L - L_seg) / L_seg)
        axT += T * dot(d ./ L, sd)
    end

    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    m = (sys.nodes[hub]::RingNode).mass
    measured = m * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)

    @printf("\nHUB AXIAL BUDGET\n")
    @printf("  all-rotor thrust (up)          = %+10.4f N\n", T_all)
    @printf("  gravity on hub (down)          = %+10.4f N\n", -G)
    @printf("  transmission top (down)        = %+10.4f N\n", -axT)
    @printf("  bridles (slack)                = %+10.4f N\n", 0.0)
    @printf("  ------------------------------------------\n")
    @printf("  predicted                      = %+10.4f N\n", T_all - G - axT)
    @printf("  MEASURED (ODE)                 = %+10.4f N\n", measured)
    @printf("  discrepancy                    = %+10.4f N\n", measured - (T_all - G - axT))
    println()
end

main()
