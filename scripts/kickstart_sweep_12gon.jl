#!/usr/bin/env julia
# scripts/kickstart_sweep_12gon.jl — Phase 3.1a (fix_xvector_rerun_sweeps.md)
# Kickstart sweep of the CORRECTED 12-gon campaign winner (build_v10_tight_no_lowest).
# Protocol unchanged from legacy kickstart_sweep.jl:
#   settle(seed k) → kick all rings to ω=30 rad/s → 30 s no-load (k=0) →
#   engage target k → 60 s MPPT → record P, ω(rpm), min airborne-ring FoS, T_max.
# K grid rebracketed for 12-gon scale (legacy triangle k∈{2..14} is meaningless here;
# honest current-code anchor: k=62 → 109.6 kW @ 119.5 rpm FoS 0.79, 2026-07-17).
# blade_scale=1.0 (campaign winner) added for the direct Strathclyde comparison row.
# Fingerprint mandate (Rod, 2026-07-17): geometry_fingerprint() embedded as CSV
# header comments so no cross-config table can hide a λ-reference shift.
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames, Dates
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
# LEGACY PHYSICS PIN (2026-07-18): reproduces CSVs archived under the
# pre-induction model. Default is now induction=ON; pinned OFF for archive
# reproducibility. New work: use the default.
set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)

import KiteTurbineDynamics: SpokeParams
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

const WIND_MS  = 11.0
const SIM_S    = 60.0    # 60 s MPPT after engage
const SPIN_S   = 30.0    # 30 s no-load spin-up
const DT       = ControlMapHunt.DT
const OUT_CSV  = joinpath(@__DIR__, "results", "control_maps", "kickstart_sweep_12gon.csv")

const BLADES   = [0.69, 0.75, 0.80, 0.85, 1.0]
const K_VALUES = [8.0, 16.0, 32.0, 48.0, 62.0, 96.0]

build_12gon(blade::Float64) = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade)

function write_header()
    githash = try
        strip(read(`git -C $(dirname(@__DIR__)) rev-parse --short HEAD`, String))
    catch
        "unknown"
    end
    open(OUT_CSV, "w") do io
        println(io, "# kickstart_sweep_12gon.csv — corrected 12-gon (build_v10_tight_no_lowest)")
        println(io, "# git=$githash  date=$(now())  wind=$(WIND_MS) m/s  spokes=ON")
        println(io, "# protocol: settle(seed k) -> kick omega=30 rad/s -> $(SPIN_S)s no-load (k=0) -> engage k -> $(SIM_S)s MPPT")
        println(io, "# NOTE: er.mass (expansion blades) is non-dynamic bookkeeping — zero inertia in ODE (Phase 2b trap 3)")
        for blade in BLADES
            sys, u0, p, label, design = build_12gon(blade)
            println(io, "# ── blade_scale=$(blade) · $(label) ──")
            print(io, Base.invokelatest(geometry_fingerprint, sys, p, design; blade_scale=blade))
        end
        println(io, "blade_scale,k_mppt,P_kw,omega_rpm,min_fos,T_max_kN,wind_ms,status")
    end
    println("Header + fingerprints written: $OUT_CSV")
end

function eval_kickstart(blade::Float64, k::Float64)
    sys, u0, p, label, design = build_12gon(blade)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    # Phase 1: settle to equilibrium (builder-seeded k — legacy protocol)
    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)

    # Kick: set all rings to high ω + orbital velocities
    omega_kick = 30.0  # 287 rpm
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]
            tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= (omega_kick * r) .* tang
        end
    end

    # Phase 2: no-load spin-up (k=0)
    sys.k_mppt_ref[] = 0.0
    run_canonical_sim!(u, sys, p, wf, round(Int, SPIN_S / DT), DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)

    # Phase 3: engage generator at target k (RESTORE before MPPT — critical)
    sys.k_mppt_ref[] = k
    n_mppt = round(Int, SIM_S / DT)
    out = Ref((0.0, 0.0, Inf, 0.0))
    run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step == n_mppt
                ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
                airborne = Float64[]
                for i in 2:length(ef.ring_fos)
                    v = ef.ring_fos[i]
                    (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
                end
                fos = isempty(airborne) ? Inf : minimum(airborne)
                out[] = (ef.base.P_kw, ef.base.omega_hub * 60 / (2π), fos, ef.base.T_max / 1000.0)
            end
        end)
    return out[]
end

function main()
    mkpath(dirname(OUT_CSV))
    println("════════════════════════════════════════════════════════")
    println("Kickstart sweep — corrected 12-gon")
    println("$(SPIN_S)s spin (k=0) → $(SIM_S)s MPPT · wind $(WIND_MS) m/s · spokes ON")
    println("BLADES=$(BLADES)  K=$(K_VALUES)")
    println("════════════════════════════════════════════════════════")

    isfile(OUT_CSV) || write_header()
    if "--header-only" in ARGS
        println("--header-only: exiting before sweep.")
        return
    end

    done_keys = Set{Tuple{Float64, Float64}}()
    old = CSV.read(OUT_CSV, DataFrame; comment="#")
    for r in eachrow(old)
        push!(done_keys, (r.blade_scale, r.k_mppt))
    end
    isempty(done_keys) || println("Resuming: $(length(done_keys)) rows done")

    for blade in BLADES
        for k in K_VALUES
            (blade, k) in done_keys && continue
            @printf("blade %.2f  k=%.0f ... ", blade, k); flush(stdout)
            local row_str
            try
                P, ω, fos, T = eval_kickstart(blade, k)
                @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f\n", P, ω, fos); flush(stdout)
                row_str = @sprintf("%.2f,%.1f,%.6f,%.4f,%.4f,%.4f,%.1f,ok", blade, k, P, ω, fos, T, WIND_MS)
            catch err
                println("ERROR: $(sprint(showerror, err))"); flush(stdout)
                row_str = @sprintf("%.2f,%.1f,NaN,NaN,NaN,NaN,%.1f,error", blade, k, WIND_MS)
            end
            open(OUT_CSV, "a") do io
                println(io, row_str)
            end
            GC.gc()
        end
    end
    println("\nDone. Results: $OUT_CSV")
end

main()
