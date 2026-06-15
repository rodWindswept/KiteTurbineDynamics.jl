#!/usr/bin/env julia
# scripts/test_multi_rotor.jl
#
# Test: distribute generating rotor power across ALL rings vs single hub rotor.
# Each ring i gets its own BEM rotor sized for P/n_rings, applying thrust
# at that ring and contributing torque to the shaft.
#
# Usage: julia --project=. scripts/test_multi_rotor.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using Printf

function evaluate_multi_rotor(
    design::TRPTDesignV4,
    stack::Vector{ExpansionRotorParams},
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π/6,
    v_peak::Float64=22.0,
    fos_req::Float64=1.8,
    max_ground_radius::Float64=5.0,
)
    n_rings_tot = length(ring_radii(design))
    zs, radii, L_seg = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr
    )
    n_lines = design.n_lines
    rho = p.rho

    # Per-ring rotor sizing
    P_per_ring = power_W / n_rings_tot
    r_rotors = Float64[]
    omegas = Float64[]
    for i in 1:n_rings_tot
        push!(r_rotors, BEM.rotor_radius_for_power(P_per_ring, v_rated, n_lines))
    end
    # All rings on common shaft — use the smallest ω (largest rotor) as shaft speed
    omega_shaft = minimum([4.1 * v_rated / r for r in r_rotors])

    # Total torque from all rings
    tau_total = 0.0
    for i in 1:n_rings_tot
        P_ring = 0.5 * rho * v_rated^3 * BEM.cp_bem(n_lines, 4.1) * π * r_rotors[i]^2
        tau_total += P_ring / omega_shaft
    end

    # Thrust at each ring
    T_total_rated = 0.0
    T_per_ring = Float64[]
    for i in 1:n_rings_tot
        Ti = peak_hub_thrust(r_rotors[i], elev_angle; v=v_rated, CT=KiteTurbineDynamics.OPT_CT_RATED)
        push!(T_per_ring, Ti)
        T_total_rated += Ti
    end
    T_line = T_total_rated / n_lines  # total tension in each line

    # Torsional stability (per-segment, using multi-rotor torque)
    min_torsional_fos = Inf
    for i in 1:length(L_seg)
        r_min = min(radii[i], radii[i + 1])
        L = L_seg[i]
        # Cumulative torque from rings above this segment
        tau_above = 0.0
        for j in 1:i
            Pj = 0.5 * rho * v_rated^3 * BEM.cp_bem(n_lines, 4.1) * π * r_rotors[j]^2
            tau_above += Pj / omega_shaft
        end
        τ_cap = T_total_rated * r_min^2 / sqrt(L^2 + 2 * r_min^2)
        tfos = τ_cap / max(tau_above, 1e-9)
        min_torsional_fos = min(min_torsional_fos, tfos)
    end

    # Peak load (for buckling)
    T_peak = 0.0
    for i in 1:n_rings_tot
        T_peak += peak_hub_thrust(r_rotors[i], elev_angle; v=v_peak, CT=KiteTurbineDynamics.OPT_CT_RATED)
    end
    T_line_peak = T_peak / n_lines

    # Mass estimate — use existing structural evaluator for beam sizing
    # (reuses the single-rotor evaluator with effective parameters)
    r_eff, F_radial_per_ring, _, _ = estimate_effective_radii(
        design, stack, p; v_wind=v_rated, elev_deg=rad2deg(elev_angle),
        omega=omega_shaft, r_rotor=maximum(r_rotors)
    )
    eval_result = evaluate_design(design;
        r_rotor=maximum(r_rotors), elev_angle=elev_angle, v_peak=v_peak,
        fos_req=fos_req, omega_rotor=omega_shaft, v_rated=v_rated,
        P_rated=power_W, max_ground_radius=max_ground_radius,
        r_eff_override=r_eff, F_radial_per_ring=F_radial_per_ring,
    )

    m_exp = sum(er -> er.mass, stack; init=0.0)
    m_tether = n_lines * design.tether_length * (970.0 * π * (p.tether_diameter / 2)^2)
    total_mass = eval_result.mass_total_kg + m_exp + m_tether

    return (
        feasible=eval_result.feasible,
        mass_total_kg=total_mass,
        mass_structural_kg=eval_result.mass_total_kg,
        min_fos=eval_result.min_fos,
        min_torsional_fos=min_torsional_fos,
        r_rotors=r_rotors,
        omega_shaft=omega_shaft,
        tau_total=tau_total,
        T_total_rated=T_total_rated,
        n_rings=n_rings_tot,
        P_per_ring=P_per_ring,
    )
end

function main()
    println("=== Multi-Rotor Generation Test ===")
    println()

    for (label, power_W, p, mgr, p_bounds) in [
        ("10kW", 10000.0, params_10kw(), 1.5, params_10kw()),
        ("50kW", 50000.0, params_v5_50kw(), 5.0,
         mass_scale(params_v5_10kw(), 10.0, 50.0 * (9.0 / 3.578)^2)),
    ]
        println("--- $label ---")
        lo, hi = search_bounds_v6(p_bounds, PROFILE_ELLIPTICAL; max_ground_radius=mgr)

        let best_single = Inf, best_multi = Inf,
            best_single_x = nothing, best_multi_x = nothing,
            n_single = 0, n_multi = 0

        for _ in 1:5000
            x = lo .+ rand(Float64, 11) .* (hi .- lo)
            x[9] = round(Int, clamp(x[9], 3, 8))
            x[10] = round(Int, clamp(x[10], 0, 6))

            result = design_from_vector_v6(x, PROFILE_ELLIPTICAL, p;
                max_ground_radius=mgr, power_W=power_W)
            design = result.design
            stack = result.stack

            # Single rotor (existing)
            r_rotor = BEM.rotor_radius_for_power(power_W, 11.0, design.n_lines)
            omega = 4.1 * 11.0 / r_rotor
            r_eff, F_radial, _, _ = estimate_effective_radii(
                design, stack, p; v_wind=11.0, elev_deg=rad2deg(π/6), omega=omega, r_rotor=r_rotor
            )
            ev = evaluate_design(design;
                r_rotor=r_rotor, elev_angle=π/6, v_peak=22.0, fos_req=1.8,
                omega_rotor=omega, v_rated=11.0, P_rated=power_W,
                max_ground_radius=mgr, r_eff_override=r_eff,
                F_radial_per_ring=F_radial,
            )
            m_exp = sum(er -> er.mass, stack; init=0.0)
            m_tether = design.n_lines * design.tether_length *
                (970.0 * π * (p.tether_diameter / 2)^2)
            cost_single = ev.feasible ? ev.mass_total_kg + m_exp + m_tether : Inf

            if cost_single < best_single
                best_single = cost_single
                best_single_x = copy(x)
                n_single += 1
            end

            # Multi rotor
            mr = evaluate_multi_rotor(design, stack, p; power_W=power_W,
                max_ground_radius=mgr)
            cost_multi = mr.feasible ? mr.mass_total_kg : Inf

            if cost_multi < best_multi
                best_multi = cost_multi
                best_multi_x = copy(x)
                n_multi += 1
            end
        end

        println("  Single-rotor best: ", isinf(best_single) ? "none feasible" : "$(round(best_single, digits=1)) kg")
        println("  Multi-rotor best:  ", isinf(best_multi) ? "none feasible" : "$(round(best_multi, digits=1)) kg")
        if !isinf(best_single) && !isinf(best_multi)
            delta = best_multi - best_single
            println("  Δ (multi - single): $(round(delta, digits=1)) kg ($(round(100*delta/best_single, digits=1))%)")
        end
        end  # let
        println()
    end
end

main()
