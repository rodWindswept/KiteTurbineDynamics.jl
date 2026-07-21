#!/usr/bin/env julia
# scripts/diag_fos_transient.jl
# Exact replica of objective_v11_warmstart path, with per-step FoS from t=0.
# Decaying FoS = initialization shock.  Flat FoS = genuine structural load.
# Uses full KTD. prefix for unexported symbols.

using KiteTurbineDynamics, Printf, Statistics

const X48 = [0.08102156521053411, 0.01, 1.0000000398274014, 0.9999999976225483,
    2.698271972848908, 0.3, 2.998592085871434, 8.186299404397625,
    -0.1202533933522536, 8.0, 15.0, 5.0, 0.5, 0.3, log10(307.0)]

function main()
    KTD = KiteTurbineDynamics
    p = params_v5_50kw()
    spoke = KTD.SpokeParams(enabled=false)
    elev_angle = π/6
    power_W = 50000.0; v_rated = 11.0

    # ── Step 1: Decode ──
    result = design_from_vector_v10(X48[1:14], PROFILE_ELLIPTICAL, p;
        power_W=power_W, v_rated=v_rated)
    result.n_active == 0 && error("No active rotors")
    k_mppt = clamp(10.0^X48[15], 0.01, 1000.0)
    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    # ── Step 2: Build ODE system ──
    sys, u0, pc = KTD.build_system_from_v10(result, 1.0, k_mppt)

    # ── Step 3: Static equilibrium ──
    expansion_params_v10 = KTD.ExpansionRotorParams[]
    for rotor in rotors
        er = KTD.ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
            rotor.blade_chord, KTD.EXP_CL_DESIGN, KTD.EXP_CD0_DESIGN, KTD.EXP_K_INDUCED,
            rotor.bank_angle_deg,
            KTD.expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
            rotor.ring_idx, 1.0,
        )
        push!(expansion_params_v10, er)
    end
    _, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )
    λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
    k_eff = p.k_mppt * λ_eff^2
    p_scaled = override_params(p; k_mppt=k_eff)
    ω_eq, r_ref = KTD.solve_equilibrium_self_consistent(
        design, expansion_params_v10, p_scaled, n_lines, radii, zs;
        P_per_rotor=power_W / max(result.n_active, 1),
        v_wind=v_rated, elev_rad=elev_angle,
    )
    @printf("ω_eq = %.2f rad/s\n", ω_eq)

    # ── Step 4: Settle ──
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [11.0 * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    u = settle_to_equilibrium(sys, u0, pc; wind_fn=wf)

    # ── Step 5: BROKEN init ──
    N = sys.n_total; Nr = sys.n_ring
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    # NO orbital velocities — this IS the bug

    # ── Step 6: Run with per-step FoS logging ──
    sys.k_mppt_ref[] = k_mppt
    total_s = 10.0 + 20.0  # shorter window for diagnostics
    total_n = round(Int, total_s / KTD.V11_DT)
    sample_every = max(round(Int, 0.05 / KTD.V11_DT), 1)

    fos_log = Tuple{Float64,Float64}[]

    function cb(uc, tc, s)
        s % sample_every != 0 && return
        try
            ef = capture_extended(uc, sys, pc, tc, wf, nothing;
                brake_engaged=sys.brake_engaged[])
            air = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(air, v)
            end
            push!(fos_log, (tc, isempty(air) ? Inf : minimum(air)))
        catch
        end
    end

    println("Running BROKEN warm-start (ω≠0, v=0) — logging FoS from t=0...")
    t0 = time()
    try
        run_canonical_sim!(u, sys, pc, wf, total_n, KTD.V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=cb)
    catch e
        @warn "Sim terminated" exception=e
    end
    dt = time() - t0

    # ── Report ──
    vals = [f for (_, f) in fos_log if !isinf(f)]
    isempty(vals) && (println("No valid FoS"); return)

    println("\n── FoS trace ($(length(vals)) samples, $(round(dt,digits=0))s) ──")
    for (i, (t, f)) in enumerate(fos_log)
        isinf(f) && continue
        if t <= 0.5 || t >= total_s - 1.0 || i % max(1, length(fos_log)÷15) == 0
            @printf("  t=%6.2fs  FoS=%.4f\n", t, f)
        end
    end

    mid = length(vals) ÷ 2
    early, late = mean(vals[1:mid]), mean(vals[mid+1:end])
    @printf("\n  Early-½:  %.4f\n", early)
    @printf("  Late-½:   %.4f\n", late)

    r = late / max(early, 0.001)
    if r > 2.0
        println("  → RECOVERING ($(round(r,digits=1))×): initialization shock")
    elseif r > 1.3
        println("  → PARTIAL ($(round(r,digits=1))×): shock + load")
    else
        println("  → FLAT ($(round(r,digits=1))×): genuine load")
    end
end

main()
