#!/usr/bin/env julia
# scripts/kickstart_sweep.jl — kickstart small blades to find true operating points
# Uses: no-load spin-up (k=0, 30s) → engage k, run 60s MPPT → record P, ω, FoS
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const WIND_MS   = 11.0
const SIM_S     = 60.0    # 60s MPPT after engage
const SPIN_S    = 30.0    # 30s no-load spin-up
const DT        = ControlMapHunt.DT
const OUT_CSV   = joinpath(@__DIR__, "results", "control_maps", "kickstart_sweep.csv")

# Designs to test: small blades × k values
const BLADES = [0.69, 0.75, 0.80, 0.85]
const K_VALUES = [2.0, 4.0, 6.0, 8.0, 10.0, 14.0]

function eval_kickstart(blade::Float64, k::Float64)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, _ = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Phase 1: settle to equilibrium (positions only, no generator)
    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)

    # Kick: set all rings to high ω
    omega_kick = 30.0  # 287 rpm — well above expected equilibrium
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
    end
    # Set orbital velocities
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

    # Phase 2: no-load spin-up (k=0)
    sys.k_mppt_ref[] = 0.0
    n_spin = round(Int, SPIN_S / DT)

    run_canonical_sim!(u, sys, p, wf, n_spin, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)

    # Phase 3: engage generator at target k
    sys.k_mppt_ref[] = k
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
println("════════════════════════════════════════════════════════")
println("Kickstart sweep — small blades with no-load spin-up")
println("$(SPIN_S)s spin (k=0) → $(SIM_S)s MPPT at target k")
println("Wind: $(WIND_MS) m/s · spokes ON · DE ring")
println("════════════════════════════════════════════════════════")

done_keys = Set{Tuple{Float64, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.blade_scale, r.k_mppt))
    end
    println("Resuming: $(length(done_keys)) rows from $(basename(OUT_CSV))")
end

for blade in BLADES
    for k in K_VALUES
        (blade, k) in done_keys && continue
        @printf("blade %.2f  k=%.0f ... ", blade, k); flush(stdout)
        try
            P, ω, fos, T = eval_kickstart(blade, k)
            @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos)
            row = (blade_scale=blade, k_mppt=k, P_kw=P, omega_rpm=ω,
                   min_fos=fos, T_max_kN=T, wind_ms=WIND_MS, status="ok")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        catch err
            println("ERROR: $(sprint(showerror, err))")
            row = (blade_scale=blade, k_mppt=k, P_kw=NaN, omega_rpm=NaN,
                   min_fos=NaN, T_max_kN=NaN, wind_ms=WIND_MS, status="error")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        end
        GC.gc()
    end
end

println("\nDone. Results: $OUT_CSV")
