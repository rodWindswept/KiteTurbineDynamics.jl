# scratch/preload_torque_dimension.jl
#
# READ-ONLY. The closed form in `_matched_place_twist` solves
#
#     sin(dA) = tau * chord / (n_lines * T_s * r_a * r_b)
#
# Dimensional check: tau [N.m] * chord [m] / (T [N] * r [m] * r [m]) = [1/m].
# That is NOT dimensionless, so `sin(dA)` cannot be a sine.  The code clamps it to
# [-1, 1] regardless, which is exactly the kind of silent truncation we are chasing.
#
# The natural capstan form is sin(dA) = tau * chord / (n_lines * T_s * r_a * r_b),
# i.e. tau = n_lines * T_s * r^2 * sin(dA) / chord, which for the first segment of
# the seed gives 770.6 N.m -- not the 377.6 N.m operating torque.
#
# This computes the TRUE axial torque of the placed geometry from the ring
# positions and the rope constitutive law, independently of the closed form, and
# compares.  If the closed form is off by a factor, every twist it produced is off
# by that factor (and the asin clamp has been hiding saturation).
#
#   scripts/ktd-julia scratch/preload_torque_dimension.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(u[(3 * (hub - 1) + 1):(3 * hub)])
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)

    @printf("operating torque k*omega^2 = %.6f N.m\n\n", sys.k_mppt_ref[] * u[6N + Nr + 1]^2)

    println("TRUE axial torque of each segment from the placed geometry:")
    @printf("  %4s %10s %10s %10s %10s %14s\n",
        "seg", "T_s_N", "r_a", "r_b", "dA_deg", "tau_true_Nm")
    for s in 1:(Nr - 1)
        ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
        na = sys.nodes[ga]::RingNode
        nb = sys.nodes[gb]::RingNode
        ra = isempty(sys.expansion_rotors) ? na.radius : sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? nb.radius : sys.effective_radii[s + 1]
        L_seg = ROPE_SUBSEGS *
                sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0
        EA = p.e_modulus * π * (p.tether_diameter / 2)^2
        αa = u[6N + s]
        αb = u[6N + s + 1]
        τ_tot = 0.0
        Tsum = 0.0
        for j in 1:p.n_lines
            pa = attachment_point(u[(3 * (ga - 1) + 1):(3 * ga)], ra, αa, j, p.n_lines, pp1, pp2)
            pb = attachment_point(u[(3 * (gb - 1) + 1):(3 * gb)], rb, αb, j, p.n_lines, pp1, pp2)
            d = pb .- pa
            L = norm(d)
            T = EA * max(0.0, (L - L_seg) / L_seg)
            Tsum += T
            # torque about the shaft axis at the LOWER ring: r x F, F = T*d/L on ring b
            # transmitted torque = T * axial projection of (r_a x d)/L
            τ_tot += T * dot(cross(pa .- u[(3 * (ga - 1) + 1):(3 * ga)], d ./ L), sd)
        end
        @printf("  %4d %10.3f %10.5f %10.5f %10.4f %14.6f\n",
            s, Tsum / p.n_lines, ra, rb, rad2deg(αb - αa), τ_tot)
    end

    # the closed form's implied torque
    println("\nclosed form  tau_implied = n_lines*T_s*r_a*r_b*sin(dA)/chord  (units N, not N.m):")
    F = design_axial_preload(sys, p, lift)
    sd_r = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    α, _ = KiteTurbineDynamics._matched_place_twist(
        sys, p, F, sys.k_mppt_ref[] * u[6N + Nr + 1]^2, u[6N + Nr + 1], wf, sd_r)
    EA = p.e_modulus * π * (p.tether_diameter / 2)^2
    for s in 1:min(3, Nr - 1)
        ga, gb = sys.ring_ids[s], sys.ring_ids[s + 1]
        ra = isempty(sys.expansion_rotors) ? (sys.nodes[ga]::RingNode).radius :
             sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? (sys.nodes[gb]::RingNode).radius :
             sys.effective_radii[s + 1]
        ch = ROPE_SUBSEGS * sys.sub_segs[(s - 1) * p.n_lines * ROPE_SUBSEGS + 1].length_0 *
             (1 + (F[s] / p.n_lines) / EA)
        Ts = F[s] / p.n_lines
        dA = α[s + 1] - α[s]
        @printf("  seg %d: T_s=%9.3f r_a=%.5f r_b=%.5f dA=%8.4f deg  implied=%.6f\n",
            s, Ts, ra, rb, rad2deg(dA), p.n_lines * Ts * ra * rb * sin(dA) / ch)
    end
    println()
end

main()
