# scratch/probe_dr_variants.jl
#
# 2026-09-19.  V2 (drag-inclusive axial residual) and V6 (static residual) are in
# conflict after the drag-free DR: at the design position the ~170 N hub axial
# force is carried by the velocity-dependent path (V2 reads 14.5 N, V6 171.1 N);
# at the DR equilibrium it is carried statically (V2 162.4 N, V6 6.6 N).  Sum is
# ~185 N both ways, so a fixed axial load is being redistributed, not removed.
#
# This probe measures the three candidate relaxations on the SAME settled state:
#
#   B  drag-free, ALL nodes            (what was wired: prototype-faithful)
#   C  drag-free, ROPE nodes only      (rings/bearing/sky pinned to design preload)
#   A  drag-included, ALL nodes        (orbital velocity recomputed each iteration)
#
# Metrics: V6 static acc0 (translational velocities zeroed, omega kept), V2
# drag-inclusive axial residual on hub/bearing/sky, and the preload error
# (equilibrium segment tension vs the intended preload F_ax/n_lines).

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

function node_forces!(F, u_work, du_work, ode_params, p, sys, N; zero_vel)
    if zero_vel
        @views u_work[(3N + 1):(6N)] .= 0.0
    else
        set_orbital_velocities!(u_work, sys, p)
        @views u_work[(3N + 1):(3N + 3)] .= 0.0          # ground ring stays fixed
    end
    fill!(du_work, 0.0)
    multibody_ode!(du_work, u_work, ode_params, 0.0)
    for g in 1:N
        m = sys.nodes[g].mass
        @views F[(3 * (g - 1) + 1):(3 * g)] .=
            m .* du_work[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
    end
    return F
end

function dr!(u, sys, p, ode_params; zero_vel, frozen, dt=2e-4, iters=20_000)
    N = sys.n_total
    uw = copy(u)
    du = zeros(length(u))
    F = zeros(3N)
    mf = repeat(KiteTurbineDynamics._static_polish_fictitious_mass(sys, N, dt), inner=3)
    if frozen === :rings
        for g in 1:N
            (sys.nodes[g] isa RingNode || g == sys.bearing_id || g == sys.sky_anchor_id) || continue
            @views mf[(3 * (g - 1) + 1):(3 * g)] .= 1e30
        end
    end
    v = zeros(3N)
    ke_prev = 0.0
    for _ in 1:iters
        node_forces!(F, uw, du, ode_params, p, sys, N; zero_vel=zero_vel)
        @views v .+= (F ./ mf) .* dt
        @views uw[1:(3N)] .+= v .* dt
        ke = 0.5 * sum(mf .* v .^ 2)
        ke < ke_prev && (v .= 0.0)
        ke_prev = ke
    end
    @views u[1:(3N)] .= uw[1:(3N)]
    return u
end

"V6 metric: max node acceleration on the static path."
function static_acc0(u, sys, p, wf, lift, N)
    us = copy(u); @views us[(3N + 1):(6N)] .= 0.0
    du = zeros(length(us)); multibody_ode!(du, us, (sys, p, wf, lift), 0.0)
    return maximum(norm(@views du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
end

"V2 metric: drag-inclusive axial residual at hub/bearing/sky."
function axial_res(u, sys, p, wf, lift, N)
    sd = normalize(@views u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)])
    du = zeros(length(u)); multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    out = Dict{String,Float64}()
    for (nm, gid) in (("hub", sys.rotor.node_id), ("bearing", sys.bearing_id),
                      ("sky", sys.sky_anchor_id))
        m = sys.nodes[gid].mass
        out[nm] = dot(@views(m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)]), sd)
    end
    return out
end

function preload_err(u, sys, p, wf, lift, u0, ω)
    F_ax = design_axial_preload(sys, p, lift, u0; omega_eq=ω, wind_fn=wf)
    intended = F_ax ./ p.n_lines
    ef = capture_extended(u, sys, p, 0.0, wf, lift)
    return maximum(abs.(ef.segment_tension .- intended) ./ intended)
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== campaign seed: V2 vs V6 by relaxation variant ===")

    base = settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000, static_polish=false)
    ω = base[6N + Nr + 1]
    ode_params = (sys, p, wf, lift)

    function show(tag, u)
        a = static_acc0(u, sys, p, wf, lift, N)
        du = zeros(length(u)); multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        raw = maximum(norm(@views du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
        r = axial_res(u, sys, p, wf, lift, N)
        e = preload_err(u, sys, p, wf, lift, u0, ω)
        @printf("  %-28s V6 static %9.3f (%7.3f g) | acc0_raw %10.1f (%8.1f g) | V2 hub %8.3f bear %7.3f sky %7.3f N | preload err %.4f\n",
            tag, a, a / 9.81, raw, raw / 9.81, r["hub"], r["bearing"], r["sky"], e)
    end

    show("0 settled (no polish)", base)
    for (tag, zero_vel, frozen) in (("B drag-free, all nodes", true, :none),
                                    ("C drag-free, rope only", true, :rings),
                                    ("A drag-included, all nodes", false, :none))
        u = copy(base)
        dr!(u, sys, p, ode_params; zero_vel=zero_vel, frozen=frozen)
        update_kite_pos!(sys, u, lift, p, 0.0)
        show(tag, u)
    end
    println("=== done ===")
end

main()
