# scratch/hub_force_decomp.jl
#
# READ-ONLY. Decomposes the force on the main rotor ring at the relaxed state, to
# find the source of the ~124 N LATERAL (shaft-perpendicular) force.
#
# `forces[hub_gid]` is written in exactly one place (ring_forces.jl:215, thrust
# along tether_dir), so any lateral force must come from the rope chain, which is
# added field-by-field rather than stored.  This recomputes the hub's balance from
# first principles:
#   gravity + (thrust along tether_dir) + sum of rope-segment forces on the hub
# and splits each into axial and perpendicular components.
#
#   scripts/ktd-julia scratch/hub_force_decomp.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: main_rotor_swept_area, ct_at_tsr
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    omega_eq = 12.983466
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    sky = sys.sky_anchor_id

    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u[6N + Nr + k] = omega_eq
    end
    sys.kite_pos .= pos(u, sky) .+
                    lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]

    # relax (compact version)
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    du = zeros(length(u))
    beta = 0.9
    prev_ke = Inf
    for it in 1:800_000
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        ke = 0.0
        for gid in 2:N
            m = (sys.nodes[gid]).mass
            v = @view u[(3N + 3 * (gid - 1) + 1):(3N + 3 * (gid - 1) + 3)]
            ke += 0.5 * m * sum(abs2, v)
        end
        if it > 1
            beta = ke > prev_ke ? max(0.5, beta * 0.9) : min(0.9999, beta * 1.0005)
        end
        prev_ke = ke
        for gid in 2:N
            b = 3N + 3 * (gid - 1) + 1
            for k in 0:2
                u[b + k] *= beta
            end
        end
        u[(6N + Nr + 1):(6N + 2Nr)] .= omega_eq
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
    end

    sd = normalize(pos(u, hub))
    ax(F) = dot(F, sd)
    perp(F) = norm(F .- dot(F, sd) .* sd)

    mh = (sys.nodes[hub]).mass
    G = mh .* [0.0, 0.0, -9.81]

    # thrust exactly as the ODE computes it
    v_wind = wf(pos(u, hub), 0.0)
    v_hub = norm(v_wind) * sys.rotor.wind_factor
    w = u[6N + Nr]
    lam = abs(w) * sys.rotor.radius / v_hub
    thrust = 0.5 * p.rho * v_hub^2 * main_rotor_swept_area(sys) * ct_at_tsr(lam) *
             cos(p.elevation_angle)^2.0
    tdir = pos(u, hub) .- pos(u, 1)
    tdir = tdir ./ norm(tdir)
    F_thrust = thrust .* tdir

    # rope forces on the hub: every sub-segment with the hub as an end
    F_ropes = zeros(3)
    nrope = 0
    for ss in sys.sub_segs
        isa_hub_a = ss.end_a.node_id == hub
        isa_hub_b = ss.end_b.node_id == hub
        (isa_hub_a || isa_hub_b) || continue
        # get both endpoint positions (ring ends need the attachment point)
        pa = end_pos(u, sys, p, ss.end_a, N, Nr)
        pb = end_pos(u, sys, p, ss.end_b, N, Nr)
        d = pb .- pa
        L = norm(d)
        L < 1e-9 && continue
        T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        # force on the hub end
        F = isa_hub_b ? (-T .* d ./ L) : (T .* d ./ L)
        F_ropes .+= F
        nrope += 1
    end

    @printf("hub mass = %.4f kg ; |r| = %.4f\n\n", mh, norm(pos(u, hub)))
    @printf("  %-16s %12s %12s %12s\n", "contribution", "axial_N", "perp_N", "|F|_N")
    for (nm, F) in (("gravity", G), ("thrust", F_thrust), ("ropes", F_ropes))
        @printf("  %-16s %+12.4f %12.4f %12.4f\n", nm, ax(F), perp(F), norm(F))
    end
    tot = G .+ F_thrust .+ F_ropes
    @printf("  %-16s %+12.4f %12.4f %12.4f\n", "TOTAL", ax(tot), perp(tot), norm(tot))
    @printf("\n  rope sub-segments touching the hub: %d\n", nrope)

    du2 = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du2, u, (sys, p, wf, lift), 0.0)
    Fode = mh .* du2[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)]
    @printf("  ODE residual on hub: axial=%+.4f perp=%.4f |F|=%.4f\n",
        ax(Fode), perp(Fode), norm(Fode))
end

"Position of a sub-segment end, using the attachment point for ring ends."
function end_pos(u, sys, p, se, N, Nr)
    if se.is_ring
        node = sys.nodes[se.node_id]::RingNode
        R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
        pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, sys.rotor.node_id, Nr)
        return attachment_point(pos(u, se.node_id), R, u[6N + node.ring_idx],
                                se.line_idx, p.n_lines, pp1, pp2)
    else
        return pos(u, se.node_id)
    end
end

main()
