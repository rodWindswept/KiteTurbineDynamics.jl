# scratch/hub_creep_check.jl
#
# READ-ONLY. The assembly relaxation stalls with ~124 N net on the main rotor ring.
# Two very different explanations:
#
#   (a) the ring is creeping toward equilibrium and 124 N is what is driving the
#       creep (long aeroelastic transient)          -> just need to converge longer
#   (b) the ring sits at a genuine non-zero force balance with nothing moving
#       (a real statics problem)                    -> the machine has no solution
#
# Distinguish by tracking the hub's position AND the residual together over a long
# run.  Under (a) the position must migrate and the force decay; under (b) both
# are flat.
#
#   scripts/ktd-julia scratch/hub_creep_check.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    iters = parse(Int, get(ENV, "KTD_ITERS", "1500000"))
    omega_eq = 12.983466
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    bear = sys.bearing_id
    sky = sys.sky_anchor_id

    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u[6N + Nr + k] = omega_eq
    end
    sys.kite_pos .= pos(u, sky) .+
                    lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]

    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    du = zeros(length(u))
    beta = 0.9
    prev_ke = Inf
    report = max(1, iters ÷ 15)

    global dperp0 = nothing
    @printf("  %9s %11s %11s %11s %11s %11s %11s\n",
        "iter", "hub_axial", "hub_perp", "F_hub_ax", "F_hub_perp", "|F|hub", "KE")
    for it in 1:iters
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

        if it == 1 || it % report == 0
            du2 = zeros(length(u))
            KiteTurbineDynamics.multibody_ode!(du2, u, (sys, p, wf, lift), 0.0)
            mh = (sys.nodes[hub]).mass
            F = mh .* du2[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)]
            # FIXED design axis, not the hub's own direction (which makes this
            # identically zero)
            axis = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
            sd = normalize(pos(u, hub))
            d = pos(u, hub)
            dperp = norm(d .- dot(d, axis) .* axis)
            # also report lateral DRIFT from the start
            global dperp0 = dperp0 === nothing ? dperp : dperp0
            @printf("  %9d %11.5f %11.5f %+11.4f %11.4f %11.4f %11.4e\n",
                it, dot(d, sd), dperp, dot(F, sd), norm(F .- dot(F, sd) .* sd),
                norm(F), ke)
        end
    end
end

main()
