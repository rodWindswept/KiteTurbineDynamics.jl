#!/usr/bin/env julia --project=.
#=
diag_zeta_005.jl — Confirmation test: zeta = 0.05 (physically defensible Dyneema).

Scales c_damp on all sub-segments from the built-in zeta=1.5 down to zeta=0.05
(a factor of 1/30), then runs the ODE from low ω to see if the reverse-torque
bias vanishes.

Also runs at rated ω with MPPT to check sustained power production.

Usage:
    julia --project=. scripts/diag_zeta_005.jl
=#

using KiteTurbineDynamics
using LinearAlgebra

function scale_cdamp!(sys::KiteTurbineSystem, factor::Float64)
    old_segs = sys.sub_segs
    new_segs = similar(old_segs, 0)
    for ss in old_segs
        push!(new_segs, KiteTurbineDynamics.RopeSubSegment(
            ss.end_a, ss.end_b, ss.length_0, ss.EA,
            ss.c_damp * factor, ss.diameter))
    end
    empty!(sys.sub_segs)
    append!(sys.sub_segs, new_segs)
    println("Scaled c_damp by ", factor, " on ", length(sys.sub_segs), " sub-segments")
    println("  c_damp: ", old_segs[1].c_damp, " → ", old_segs[1].c_damp * factor)
end

function run_diagnostic_loop!(u, sys, p, lift_device, wind_fn, n_steps, dt, lin_damp)
    N = sys.n_total; Nr = sys.n_ring
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
        u[1:3] .= 0.0; u[(3N + 1):(3N + 3)] .= 0.0
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
            println("  t=$(round(t,digits=2))  ω=$(round(u[6N+Nr+Nr],digits=4))")
        end
    end
    return t_history, ω_history, hist_idx
end

function main()
    p = params_10kw()
    sys, u0 = KiteTurbineDynamics.build_kite_turbine_system(p)
    lift_device = KiteTurbineDynamics.rotary_lifter_default()
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]

    # Scale c_damp: zeta 1.5 → 0.05
    scale_cdamp!(sys, 0.05 / 1.5)

    println("\n=== TEST 1: Low-ω start (2 rad/s), 10 s, lin_damp=0.05 ===")
    u = KiteTurbineDynamics.settle_to_operational_state(
        sys, copy(u0), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    println("Settle complete. ω = ", u[6*sys.n_total + sys.n_ring + sys.n_ring])

    # Set low ω
    N = sys.n_total; Nr = sys.n_ring
    @views u[(6N + Nr + 1):(6N + 2Nr)] .= 2.0
    KiteTurbineDynamics.set_orbital_velocities!(u, sys, p)

    dt = 4e-5
    t1, w1, n1 = run_diagnostic_loop!(u, sys, p, lift_device, wind_fn, 250_000, dt, 0.05)
    ω_f1 = u[6N + Nr + Nr]
    println("ω: 2.0 → ", round(ω_f1, digits=3), " rad/s  (min=", round(minimum(w1[1:n1]),digits=3), " max=", round(maximum(w1[1:n1]),digits=3), ")")

    println("\n=== TEST 2: Rated ω (9.5 rad/s), 10 s, lin_damp=0.05, MPPT active ===")
    sys2, u0_2 = KiteTurbineDynamics.build_kite_turbine_system(p)
    scale_cdamp!(sys2, 0.05 / 1.5)
    u2 = KiteTurbineDynamics.settle_to_operational_state(
        sys2, copy(u0_2), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    sys2.k_mppt_ref[] = p.k_mppt  # enable MPPT
    t2, w2, n2 = run_diagnostic_loop!(u2, sys2, p, lift_device, wind_fn, 250_000, dt, 0.05)
    ω_f2 = u2[6N + Nr + Nr]
    println("ω: 9.5 → ", round(ω_f2, digits=3), " rad/s  (min=", round(minimum(w2[1:n2]),digits=3), " max=", round(maximum(w2[1:n2]),digits=3), ")")

    println("\n=== TEST 3: Low ω, NO orbital damping (lin_damp=0) ===")
    sys3, u0_3 = KiteTurbineDynamics.build_kite_turbine_system(p)
    scale_cdamp!(sys3, 0.05 / 1.5)
    u3 = KiteTurbineDynamics.settle_to_operational_state(
        sys3, copy(u0_3), p, 9.5; lift_device=lift_device, wind_fn=wind_fn)
    @views u3[(6N + Nr + 1):(6N + 2Nr)] .= 2.0
    KiteTurbineDynamics.set_orbital_velocities!(u3, sys3, p)
    t3, w3, n3 = run_diagnostic_loop!(u3, sys3, p, lift_device, wind_fn, 250_000, dt, 0.0)
    ω_f3 = u3[6N + Nr + Nr]
    println("ω: 2.0 → ", round(ω_f3, digits=3), " rad/s  (min=", round(minimum(w3[1:n3]),digits=3), " max=", round(maximum(w3[1:n3]),digits=3), ")")

    # ── Summary ──────────────────────────────────────────────────────────
    println("\n" * "="^70)
    println("SUMMARY — zeta = 0.05")
    println("="^70)
    println("Test 1 (low ω,  lin_damp=0.05): ω₀=2.0  →  ω_final=", round(ω_f1, digits=3), "  ",
            ω_f1 > 8 ? "✅ SPINS UP" : ω_f1 < 0.5 ? "⚠️ STALLS" : "→ AMBIGUOUS")
    println("Test 2 (rated ω, lin_damp=0.05): ω₀=9.5  →  ω_final=", round(ω_f2, digits=3), "  ",
            ω_f2 > 8 ? "✅ SUSTAINS" : ω_f2 < 0.5 ? "⚠️ STALLS" : "→ AMBIGUOUS")
    println("Test 3 (low ω,  lin_damp=0):    ω₀=2.0  →  ω_final=", round(ω_f3, digits=3), "  ",
            ω_f3 > 8 ? "✅ SPINS UP" : ω_f3 < 0.5 ? "⚠️ STALLS" : "→ AMBIGUOUS")

    # Dump CSVs
    for (label, t_vec, w_vec, n) in [("test1_lowomega", t1, w1, n1),
                                       ("test2_rated", t2, w2, n2),
                                       ("test3_no_orbital", t3, w3, n3)]
        open("diag_zeta005_$(label).csv", "w") do io
            println(io, "t,omega")
            for i in 1:n
                println(io, t_vec[i], ",", w_vec[i])
            end
        end
    end
    println("\nCSVs written.")
end

main()
