#!/usr/bin/env julia --project=.
#=
diag_orbital_damping_Lz.jl — Direct measurement of Test 3 from the BEM/ODE gap handover.

Measures the angular-momentum change ΔL_z = L_z_after - L_z_before across
orbital_damp_rope_velocities! every ODE step.  Because the overwrite bypasses
the force path entirely, no force-level instrumentation can see it — only a
before/after L_z measurement catches it.

If ΔL_z is systematically negative, the orbital velocity overwrite is
destroying angular momentum that the BEM model assumes is conserved, and
that is the source of the reverse-torque bias.

Usage:
    julia --project=. scripts/diag_orbital_damping_Lz.jl

Output:
    CSV of (step, t, Lz_before, Lz_after, dLz, dLz_cumulative) and a histogram
    summary.
=#

using KiteTurbineDynamics
using LinearAlgebra

# ── helpers ───────────────────────────────────────────────────────────────────

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
        r = @view u[(3*(gid-1)+1):(3*gid)]
        v = @view u[(3N + 3*(gid-1)+1):(3N + 3*gid)]
        # L = m·(r × v); L_z = L · n
        Lx = node.mass * (r[2]*v[3] - r[3]*v[2])
        Ly = node.mass * (r[3]*v[1] - r[1]*v[3])
        Lz += node.mass * (r[1]*v[2] - r[2]*v[1])
        Lz += Lx*shaft_dir[1] + Ly*shaft_dir[2]  # wait, this is wrong — let me fix
    end
    return Lz
end

# Actually, compute full cross product properly:
function rope_angular_momentum_z(u, sys, shaft_dir)
    N = sys.n_total
    Lz = 0.0
    for node in sys.nodes
        node isa KiteTurbineDynamics.RopeNode || continue
        gid = node.id
        r1 = u[3*(gid-1)+1]; r2 = u[3*(gid-1)+2]; r3 = u[3*(gid-1)+3]
        v1 = u[3N + 3*(gid-1)+1]; v2 = u[3N + 3*(gid-1)+2]; v3 = u[3N + 3*(gid-1)+3]
        # L = m·(r × v)
        Lx = node.mass * (r2*v3 - r3*v2)
        Ly = node.mass * (r3*v1 - r1*v3)
        Lz_real = node.mass * (r1*v2 - r2*v1)
        Lz += Lx*shaft_dir[1] + Ly*shaft_dir[2] + Lz_real*shaft_dir[3]
    end
    return Lz
end

# ── main ──────────────────────────────────────────────────────────────────────

function main()
    p = params_10kw()
    sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p)
    lift_device = KiteTurbineDynamics.rotary_lifter_default()

    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    println("Settling to operational state (may take ~30s)...")
    u = KiteTurbineDynamics.settle_to_operational_state(
        sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    println("Settle complete. ω_hub = ", u[6*sys.n_total + sys.n_ring + sys.n_ring])

    N = sys.n_total
    Nr = sys.n_ring
    dt = 4e-5
    n_steps = 5000  # 0.2 s physical time — enough for a clear signal
    lin_damp = 0.05

    results = Vector{Tuple{Float64,Float64,Float64,Float64,Float64}}(undef, n_steps)
    cum_dLz = 0.0
    ode_params = (sys, p, wind_fn, lift_device)
    du = zeros(Float64, length(u))
    t = 0.0

    println("Running ", n_steps, " steps (", n_steps*dt, " s), measuring ΔL_z...")

    for step in 1:n_steps
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, ode_params, t)
        t += dt
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        # Ground ring stays fixed
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        # Advance α, ω (simplified — no braking for this diagnostic)
        omega_dot = @view du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* omega_dot
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        # ── THE MEASUREMENT ──────────────────────────────────────────────
        shaft_dir = shaft_direction(u, sys, p)
        Lz_before = rope_angular_momentum_z(u, sys, shaft_dir)

        # Apply orbital damping (same call as simulation loop)
        KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)

        Lz_after = rope_angular_momentum_z(u, sys, shaft_dir)
        dLz = Lz_after - Lz_before
        cum_dLz += dLz
        results[step] = (t, Lz_before, Lz_after, dLz, cum_dLz)

        # Advance kite position lag
        KiteTurbineDynamics.update_kite_pos!(sys, u, lift_device, p, dt)

        if step % 1000 == 0
            println("  step $step: t=$(round(t,digits=4))  dLz=$(round(dLz,digits=6))  cum_dLz=$(round(cum_dLz,digits=6))")
            ω_hub = u[6N + Nr + Nr]
            println("         ω_hub=$(round(ω_hub,digits=4)) rad/s")
        end
    end

    # ── summary ──────────────────────────────────────────────────────────
    println("\n" * "="^70)
    println("RESULTS — ΔL_z across orbital_damp_rope_velocities!")
    println("="^70)
    println("Steps:         ", n_steps)
    println("Physical time: ", n_steps * dt, " s")
    println("Final ω_hub:   ", u[6N + Nr + Nr], " rad/s")

    dLz_vals = [r[4] for r in results]
    cum_final = results[end][5]
    mean_dLz = sum(dLz_vals) / length(dLz_vals)
    pos_count = count(x -> x > 0, dLz_vals)
    neg_count = count(x -> x < 0, dLz_vals)
    zero_count = count(x -> x == 0, dLz_vals)

    println("Mean ΔLz:      ", mean_dLz)
    println("Cumulative:    ", cum_final)
    println("Positive:      ", pos_count, "  Negative: ", neg_count, "  Zero: ", zero_count)

    if cum_final < 0
        println("\n⚠️  SYSTEMATIC NEGATIVE ΔLz — the orbital velocity overwrite is")
        println("    destroying angular momentum. This is the source of the")
        println("    reverse-torque bias that no force-level instrumentation")
        println("    can see because the overwrite bypasses the force path.")
    elseif abs(cum_final) < 1e-10
        println("\n✅  ΔLz ~ 0 — orbital damping conserves angular momentum.")
    else
        println("\n⚠️  POSITIVE ΔLz — unexpected, worth investigating.")
    end

    # ── dump CSV ─────────────────────────────────────────────────────────
    open("diag_orbital_damping_Lz.csv", "w") do io
        println(io, "step,t,Lz_before,Lz_after,dLz,cum_dLz")
        for (i, r) in enumerate(results)
            println(io, join([i, r...], ","))
        end
    end
    println("\nCSV written to diag_orbital_damping_Lz.csv")
end

main()
