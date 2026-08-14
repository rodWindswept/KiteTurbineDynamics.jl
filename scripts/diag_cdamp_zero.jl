#!/usr/bin/env julia --project=.
#=
diag_cdamp_zero.jl — Tests c_damp=0 (Test 1 from the BEM/ODE gap handover).

Zeroes out the structural damping coefficient in all rope sub-segments,
then runs the full ODE simulation to see if the reverse-torque bias persists.

If ω still reverses with c_damp=0, the tension rectifier (max(0.0, ...)) is
exonerated — the rectifier only matters when the damper term is non-zero.

Usage:
    julia --project=. scripts/diag_cdamp_zero.jl
=#

using KiteTurbineDynamics
using LinearAlgebra

function zero_cdamp!(sys::KiteTurbineSystem)
    # RopeSubSegment is immutable, so we replace the vector entries
    old_segs = sys.sub_segs
    new_segs = similar(old_segs, 0)
    for ss in old_segs
        push!(new_segs, KiteTurbineDynamics.RopeSubSegment(
            ss.end_a, ss.end_b, ss.length_0, ss.EA, 0.0, ss.diameter))
    end
    # Replace in-place by emptying and re-filling
    empty!(sys.sub_segs)
    append!(sys.sub_segs, new_segs)
    println("Zeroed c_damp on ", length(sys.sub_segs), " sub-segments")
end

function main()
    p = params_10kw()
    sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p)
    lift_device = KiteTurbineDynamics.rotary_lifter_default()
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    # Zero the rope damping
    zero_cdamp!(sys)

    println("Settling with c_damp=0...")
    u = KiteTurbineDynamics.settle_to_operational_state(
        sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    ω_settled = u[6*sys.n_total + sys.n_ring + sys.n_ring]
    println("Settle complete. ω_hub = ", ω_settled)

    # Now manually set low ω and run the full simulation
    Nr = sys.n_ring
    N = sys.n_total
    omega_view = @view u[(6N + Nr + 1):(6N + 2Nr)]
    omega_view .= 2.0
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)
    println("Set ω → 2.0 rad/s, re-initialised rope velocities")

    # Run the canonical simulation to see the full dynamics
    dt = 4e-5
    n_steps = 125_000  # 5 seconds — enough to see stall or recovery
    lin_damp = 0.05  # keep orbital damping at default

    println("Running ", n_steps, " steps (", n_steps*dt, " s) with c_damp=0...")

    # We run our own loop to track ω at high resolution
    ode_params = (sys, p, wind_fn, lift_device)
    du = zeros(Float64, length(u))
    t = 0.0

    ω_history = Vector{Float64}(undef, n_steps ÷ 100)
    t_history = Vector{Float64}(undef, n_steps ÷ 100)
    hist_idx = 0

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

        if lin_damp > 0.0
            KiteTurbineDynamics.orbital_damp_rope_velocities!(u, sys, p, lin_damp, dt)
        end

        KiteTurbineDynamics.update_kite_pos!(sys, u, lift_device, p, dt)

        if step % 100 == 0
            hist_idx += 1
            ω_history[hist_idx] = u[6N + Nr + Nr]
            t_history[hist_idx] = t
        end

        if step % 25000 == 0
            ω_hub = u[6N + Nr + Nr]
            println("  step $step: t=$(round(t,digits=3))  ω=$(round(ω_hub,digits=4)) rad/s")
        end
    end

    ω_final = u[6N + Nr + Nr]
    println("\n" * "="^70)
    println("RESULTS — c_damp = 0")
    println("="^70)
    println("ω_start:  2.0  →  ω_final: ", round(ω_final, digits=4), " rad/s")
    println("ω_min:    ", round(minimum(ω_history), digits=4))
    println("ω_max:    ", round(maximum(ω_history), digits=4))

    if ω_final < 0.1
        println("\n⚠️  ω still reverses with c_damp=0 — tension rectifier is NOT the source.")
    elseif ω_final > 1.0
        println("\n✅  ω stays positive with c_damp=0 — the rope damper IS a contributor.")
    else
        println("\n→  ω near zero — inconclusive, run longer.")
    end

    # Dump CSV
    open("diag_cdamp_zero.csv", "w") do io
        println(io, "t,omega")
        for i in 1:hist_idx
            println(io, t_history[i], ",", ω_history[i])
        end
    end
    println("CSV → diag_cdamp_zero.csv")
end

main()
