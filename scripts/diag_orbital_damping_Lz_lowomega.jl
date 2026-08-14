#!/usr/bin/env julia --project=.
#=
diag_orbital_damping_Lz_lowomega.jl — Low-ω variant of the L_z diagnostic.

Same measurement as diag_orbital_damping_Lz.jl, but starts from a manually-set
low angular velocity (~2 rad/s) after settling, to test whether the orbital
damping bias only manifests when the system is far from its design equilibrium.

Usage:
    julia --project=. scripts/diag_orbital_damping_Lz_lowomega.jl
=#

using KiteTurbineDynamics
using LinearAlgebra

function shaft_direction(u, sys, p)
    hub_gid = sys.rotor.node_id
    hub_pos = @view u[(3*(hub_gid-1)+1):(3*hub_gid)]
    rmag = norm(hub_pos)
    if rmag > 0.1
        return hub_pos ./ rmag
    else
        return [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    end
end

function rope_angular_momentum_z(u, sys, shaft_dir)
    N = sys.n_total
    Lz = 0.0
    for node in sys.nodes
        node isa KiteTurbineDynamics.RopeNode || continue
        gid = node.id
        r1 = u[3*(gid-1)+1]; r2 = u[3*(gid-1)+2]; r3 = u[3*(gid-1)+3]
        v1 = u[3N + 3*(gid-1)+1]; v2 = u[3N + 3*(gid-1)+2]; v3 = u[3N + 3*(gid-1)+3]
        Lx = node.mass * (r2*v3 - r3*v2)
        Ly = node.mass * (r3*v1 - r1*v3)
        Lz_real = node.mass * (r1*v2 - r2*v1)
        Lz += Lx*shaft_dir[1] + Ly*shaft_dir[2] + Lz_real*shaft_dir[3]
    end
    return Lz
end

function main()
    p = params_10kw()
    sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p)
    lift_device = KiteTurbineDynamics.rotary_lifter_default()
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    println("Settling to operational state...")
    u = KiteTurbineDynamics.settle_to_operational_state(
        sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    ω_settled = u[6*sys.n_total + sys.n_ring + sys.n_ring]
    println("Settle complete. ω_hub = ", ω_settled)

    # ── Manually set low ω on all rings ──────────────────────────────────
    Nr = sys.n_ring
    ω_low = 2.0  # rad/s — well below rated, where stall manifests
    N = sys.n_total
    omega_view = @view u[(6N + Nr + 1):(6N + 2Nr)]
    omega_view .= ω_low
    println("Set all ring ω → ", ω_low, " rad/s")

    # Also need to set rope node velocities to match the new ω
    # (otherwise there's a velocity mismatch that creates a transient)
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)
    println("Re-initialised rope velocities to orbital field at ω=", ω_low)

    dt = 4e-5
    n_steps = 25000  # 1.0 s — enough to see stall dynamics
    lin_damp = 0.05

    results = Vector{Tuple{Float64,Float64,Float64,Float64,Float64}}(undef, n_steps)
    cum_dLz = 0.0
    ode_params = (sys, p, wind_fn, lift_device)
    du = zeros(Float64, length(u))
    t = 0.0

    println("Running ", n_steps, " steps (", n_steps*dt, " s) at ω₀=", ω_low, " rad/s...")

    for step in 1:n_steps
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, ode_params, t)
        t += dt
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        # ── MEASUREMENT ──────────────────────────────────────────────────
        shaft_dir = shaft_direction(u, sys, p)
        Lz_before = rope_angular_momentum_z(u, sys, shaft_dir)

        KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)

        Lz_after = rope_angular_momentum_z(u, sys, shaft_dir)
        dLz = Lz_after - Lz_before
        cum_dLz += dLz
        results[step] = (t, Lz_before, Lz_after, dLz, cum_dLz)

        KiteTurbineDynamics.update_kite_pos!(sys, u, lift_device, p, dt)

        if step % 5000 == 0
            ω_hub = u[6N + Nr + Nr]
            println("  step $step: t=$(round(t,digits=4))  ω=$(round(ω_hub,digits=4))  dLz=$(round(dLz,digits=6))  cum=$(round(cum_dLz,digits=6))")
        end
    end

    # ── summary ──────────────────────────────────────────────────────────
    println("\n" * "="^70)
    println("RESULTS — ΔL_z at low ω (ω₀ = ", ω_low, " rad/s)")
    println("="^70)
    ω_final = u[6N + Nr + Nr]
    println("Steps:         ", n_steps)
    println("Physical time: ", n_steps * dt, " s")
    println("ω_start:       ", ω_low, "  →  ω_final: ", ω_final, " rad/s")

    dLz_vals = [r[4] for r in results]
    cum_final = results[end][5]
    mean_dLz = sum(dLz_vals) / length(dLz_vals)
    pos_count = count(x -> x > 0, dLz_vals)
    neg_count = count(x -> x < 0, dLz_vals)

    println("Mean ΔLz:      ", mean_dLz)
    println("Cumulative:    ", cum_final)
    println("Positive:      ", pos_count, "  Negative: ", neg_count)

    if cum_final < 0
        println("\n⚠️  SYSTEMATIC NEGATIVE ΔLz — orbital damping destroys L_z at low ω.")
    elseif abs(cum_final) < 1e-10 || abs(mean_dLz) < 1e-6
        println("\n✅  ΔLz ~ 0 — orbital damping conserves L_z at all ω.")
    else
        println("\n→  Net ", cum_final > 0 ? "positive" : "negative", " bias (", round(cum_final, digits=3), "), but mean/sub-step magnitude ratio is tiny.")
    end

    open("diag_orbital_damping_Lz_lowomega.csv", "w") do io
        println(io, "step,t,Lz_before,Lz_after,dLz,cum_dLz")
        for (i, r) in enumerate(results)
            println(io, join([i, r...], ","))
        end
    end
    println("CSV → diag_orbital_damping_Lz_lowomega.csv")
end

main()
