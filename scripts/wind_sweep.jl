#!/usr/bin/env julia
# scripts/wind_sweep.jl — power curves at multiple wind speeds for key designs
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
# LEGACY PHYSICS PIN (2026-07-18): reproduces CSVs archived under the
# pre-induction model. Default is now induction=ON; pinned OFF for archive
# reproducibility. New work: use the default.
set_expansion_induction!(false)

import KiteTurbineDynamics: SpokeParams

const WINDS = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const SIM_S = 60.0
const DT    = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "wind_sweep.csv")

# Key designs to test
const DESIGNS = [
    (blade=0.85, k=2.0,  label="0.85/k2 (high-RPM)"),
    (blade=0.90, k=6.0,  label="0.90/k6 (safest)"),
    (blade=0.95, k=4.0,  label="0.95/k4 (sweet spot)"),
    (blade=1.00, k=4.0,  label="1.00/k4"),
    (blade=1.10, k=4.0,  label="1.10/k4 (max power)"),
]

function eval_design(blade::Float64, k::Float64, wind::Float64)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    sys.k_mppt_ref[] = k  # SET BEFORE SETTLE (used by equilibrium scan)

    # For small blades (≤0.85): kickstart needed
    if blade <= 0.85
        u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
        omega_kick = 30.0
        for ri in 1:Nr
            u[6*N + Nr + ri] = omega_kick
        end
        for ri in 1:Nr
            gid = sys.ring_ids[ri]
            pos = u[(3*(gid-1)+1):(3*gid)]
            r = norm(pos)
            if r > 0.01
                tang = [-pos[2], pos[1], 0.0]
                tang ./= norm(tang)
                v_orb = omega_kick * r
                vx_idx = 3*N + 3*(gid-1) + 1
                u[vx_idx:(vx_idx+2)] .= v_orb .* tang
            end
        end
        sys.k_mppt_ref[] = 0.0
        n_spin = round(Int, 30.0 / DT)
        run_canonical_sim!(u, sys, p, wf, n_spin, DT;
            lift_device=nothing, lin_damp=0.05, spoke=sp)
        sys.k_mppt_ref[] = k  # re-engage generator after spin-up
    else
        # Standard settle for large blades
        u = settle_to_operational_state(sys, copy(u0), p, 9.5; wind_fn=wf)
    end

    n_mppt = round(Int, SIM_S / DT)

    local P_final = 0.0
    local omega_final = 0.0
    local fos_final = Inf
    local T_final = 0.0

    run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_mppt
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                P_final = ef.base.P_kw
                omega_final = ef.base.omega_hub * 60 / (2π)
                T_final = ef.base.T_max / 1000.0
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos_final = isempty(airborne) ? Inf : minimum(airborne)
            end
        end)

    return P_final, omega_final, fos_final, T_final
end

# ── Main ──
mkpath(dirname(OUT_CSV))
println("════════════════════════════════════════════════")
println("Wind speed sweep — power curves for key designs")
println("code: $(ControlMapHunt.GIT_HASH)")
println("$(SIM_S)s MPPT · spokes ON · DE ring")
println("════════════════════════════════════════════════")

done_keys = Set{Tuple{Float64, Float64, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.blade_scale, r.k_mppt, r.wind_ms))
    end
    println("Resuming: $(length(done_keys)) rows")
end

for (blade, k, label) in DESIGNS
    for wind in WINDS
        (blade, k, wind) in done_keys && continue
        @printf("%s  wind=%.0f ... ", label, wind); flush(stdout)
        try
            P, ω, fos, T = eval_design(blade, k, wind)
            @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
            row = (blade_scale=blade, k_mppt=k, wind_ms=wind, label=label,
                   P_kw=P, omega_rpm=ω, min_fos=fos, T_max_kN=T, status="ok")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        catch err
            println("ERROR: $(sprint(showerror, err))")
            row = (blade_scale=blade, k_mppt=k, wind_ms=wind, label=label,
                   P_kw=NaN, omega_rpm=NaN, min_fos=NaN, T_max_kN=NaN, status="error")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        end
        GC.gc()
    end
end

println("\nDone. Results: $OUT_CSV")
