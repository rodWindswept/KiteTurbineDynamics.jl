# Static residual probe for the approved preload derivation. No ODE window.
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

function place_trial(sys, p, base, F, wf)
    N, Nr = sys.n_total, sys.n_ring
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    omega = base[6N + Nr + 1]
    alpha, centers = KiteTurbineDynamics._matched_place_twist(
        sys, p, F, sys.k_mppt_ref[] * omega^2, omega, wf, sd)
    u = copy(base)
    for (ri, gid) in enumerate(sys.ring_ids)
        u[(3gid - 2):3gid] .= centers[ri]
        u[6N + ri] = alpha[ri]
    end
    hub = sys.rotor.node_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    for node in sys.nodes
        node isa RopeNode || continue
        s, j = node.seg_idx, node.line_idx
        ra = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s]].radius : sys.effective_radii[s]
        rb = isempty(sys.expansion_rotors) ? sys.nodes[sys.ring_ids[s + 1]].radius : sys.effective_radii[s + 1]
        pa = attachment_point(centers[s], ra, alpha[s], j, p.n_lines, pp1, pp2)
        pb = attachment_point(centers[s + 1], rb, alpha[s + 1], j, p.n_lines, pp1, pp2)
        u[(3node.id - 2):3node.id] .= pa .+ (node.sub_idx / ROPE_SUBSEGS) .* (pb .- pa)
    end
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)
    return u
end

function residuals(sys, p, u, wf, lift)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    N = sys.n_total
    return [sys.nodes[gid].mass * dot(du[(3N + 3gid - 2):(3N + 3gid)], sd)
            for gid in sys.ring_ids[2:end]]
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    base = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    F = design_axial_preload(sys, p, lift)
    @printf("BASE beta=%.1f rings=%d top_total=%.6f\n", rad2deg(p.elevation_angle), sys.n_ring, F[end])
    println("Returned-state axial ring residuals N = ", residuals(sys, p, base, wf, lift))
    for delta in (-1.0, 0.0, 1.0)
        u = place_trial(sys, p, base, F .+ delta, wf)
        @printf("dF_top=%+.1f hub_residual_N=%.6f\n", delta, residuals(sys, p, u, wf, lift)[end])
    end
    for sign in (-1.0, 1.0)
        Ft = copy(F)
        for it in 1:4
            u = place_trial(sys, p, base, Ft, wf)
            f = residuals(sys, p, u, wf, lift)[end]
            @printf("update_sign=%+.0f it=%d T_top=%.6f residual=%.6f\n", sign, it, Ft[end], f)
            Ft .+= sign * 0.7 * f
            all(isfinite, Ft) && minimum(Ft) > 0 || break
        end
    end
end
main()
