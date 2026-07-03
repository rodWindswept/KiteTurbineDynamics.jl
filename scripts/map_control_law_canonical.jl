#!/usr/bin/env julia
# scripts/map_control_law_canonical.jl
# Control law map for canonical 10kW — validate the "work backwards" approach.
# Sweeps wind speeds 5-15 m/s, hunts k_mppt that hits 10kW, records FoS.

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf, CSV, DataFrames

OUT_DIR = joinpath(@__DIR__, "results", "control_maps")
mkpath(OUT_DIR)

function run_hunt(wind_speed, lift, P_rated)
    """Hunt the k_mppt that produces P_rated at the given wind speed."""
    wf(pos, t) = [wind_speed, 0.0, 0.0]
    k_min = 2.0; k_max = 5000.0

    # Coarse hunt: 12 points, 2s each — cover both flanks
    local best_k = 0.0; local best_err = Inf; local best_P = 0.0
    local best_ω = 0.0; local best_fos = 0.0
    DT = 4e-5; T_SIM = 2.0; n_steps = round(Int, T_SIM/DT)

    k_values = vcat(
        exp10.(range(log10(k_min), log10(300.0); length=8)),
        exp10.(range(log10(50.0), log10(k_max); length=25))
    ) |> unique |> sort

    for k_try in k_values
        sys2, u02, p2 = build_canonical_system()
        sys2.k_mppt_ref[] = k_try
        u = settle_to_operational_state(sys2, copy(u02), p2, 9.5; lift_device=lift, wind_fn=wf)

        local p_final = 0.0; local ω_final = 0.0; local fos_final = Inf
        N = sys2.n_total; Nr = sys2.n_ring
        run_canonical_sim!(u, sys2, p2, wf, n_steps, DT;
            lift_device=lift, lin_damp=0.05,
            callback=(u_curr, t_curr, step) -> begin
                if step == n_steps
                    sf = capture_frame(u_curr, sys2, p2, t_curr, wf, lift; brake_engaged=false)
                    p_final = sf.P_kw * 1000
                    ω_final = u_curr[6N+Nr+Nr]
                    fos_final = sf.fos_ring
                end
            end)

        err = abs(p_final - P_rated)
        # Strongly penalise overshoots: right-flank (stall-side) preferred
        if p_final > P_rated * 1.05
            err *= 5.0  # 5× penalty for producing >5% over target
        end
        if p_final > 0 && err < best_err
            best_err = err; best_k = k_try; best_P = p_final
            best_ω = ω_final; best_fos = fos_final
        end
    end

    # Fine verify: 30s at the best k
    sys3, u03, p3 = build_canonical_system()
    sys3.k_mppt_ref[] = best_k
    u = settle_to_operational_state(sys3, copy(u03), p3, 9.5; lift_device=lift, wind_fn=wf)
    N = sys3.n_total; Nr = sys3.n_ring
    n_steps2 = round(Int, 30.0/DT)

    local P_verify = 0.0; local ω_verify = 0.0; local fos_verify = 0.0
    local twist_verify = 0.0; local T_max_verify = 0.0

    run_canonical_sim!(u, sys3, p3, wf, n_steps2, DT;
        lift_device=lift, lin_damp=0.05,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_steps2
                sf = capture_frame(u_curr, sys3, p3, t_curr, wf, lift; brake_engaged=false)
                P_verify = sf.P_kw * 1000
                ω_verify = u_curr[6N+Nr+Nr]
                fos_verify = sf.fos_ring
                T_max_verify, _ = get_max_rope_tension(u_curr, sys3, p3)
                alpha = @view u_curr[(6N+1):(6N+Nr)]
                twist_verify = rad2deg(sum(mod(alpha[i+1]-alpha[i]+π,2π)-π for i in 1:(Nr-1)))
            end
        end)

    return (v_wind=wind_speed, k_mppt=best_k, P_W=P_verify, ω_rads=ω_verify,
            min_fos=fos_verify, T_max_N=T_max_verify, twist_deg=twist_verify)
end

function build_canonical_system()
    p = params_10kw()
    sys, u0 = build_kite_turbine_system(p)
    return sys, u0, p
end

println("Canonical 10 kW control law map")
println("═"^40)

wind_speeds = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
lift = rotary_lifter_default()
P_rated = params_10kw().p_rated_w
results = []

for v in wind_speeds
    println("\n── v_wind=$v m/s ──")
    r = run_hunt(v, lift, P_rated)
    push!(results, r)
    status = r.min_fos >= 1.5 ? "✓" : "✗ FAIL"
    @printf "  k=%.0f  P=%.0fW  ω=%.1frpm  FoS=%.2f  %s\n" r.k_mppt r.P_W r.ω_rads*60/(2π) r.min_fos status
end

df = DataFrame(results)
CSV.write(joinpath(OUT_DIR, "canonical_10kw_control_map.csv"), df)
println("\nDone. Saved to $(joinpath(OUT_DIR, "canonical_10kw_control_map.csv"))")
