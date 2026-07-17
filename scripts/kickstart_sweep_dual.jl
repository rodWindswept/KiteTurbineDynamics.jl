#!/usr/bin/env julia
# scripts/kickstart_sweep_dual.jl — Phase 3 kickstart sweep, corrected builders
#
# Usage:  julia --project=. scripts/kickstart_sweep_dual.jl 12gon
#         julia --project=. scripts/kickstart_sweep_dual.jl triangle3
#
# 12gon:     corrected V10 builder (12 lines, 12 blades/rotor, 10 rings, tapered)
#            K rebracketed {4,8,16,32,62,128} — triangle k∈{2..14} is meaningless
#            here (k=62 datum: 109.6 kW @ 119.5 rpm FoS 0.79)
# triangle3: phantom rebuild (3 lines, 3 blades/rotor, 22 rings, untapered)
#            legacy K {2,4,6,8,10,14} — gate-validated vs legacy CSVs
#
# Protocol (unchanged from legacy kickstart_sweep.jl):
#   settle → kick all rings to ω=30 rad/s → 30 s k=0 spin → engage k → 60 s MPPT
# Output: results/control_maps/kickstart_sweep_<config>.csv (+ .meta sidecar)
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

const CONFIG = isempty(ARGS) ? error("pass config: 12gon | triangle3") : ARGS[1]
@assert CONFIG in ("12gon", "triangle3") "config must be 12gon or triangle3"

const WIND_MS = 11.0
const SIM_S   = 60.0
const SPIN_S  = 30.0
const DT      = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "kickstart_sweep_$(CONFIG).csv")
const META    = joinpath(@__DIR__, "results", "control_maps", "kickstart_sweep_$(CONFIG).meta")

const BLADES = [0.69, 0.75, 0.80, 0.85]
const K_VALUES = CONFIG == "12gon" ? [4.0, 8.0, 16.0, 32.0, 62.0, 128.0] :
                                     [2.0, 4.0, 6.0, 8.0, 10.0, 14.0]

build_cfg(blade) = CONFIG == "12gon" ?
    Base.invokelatest(build_v10_tight_no_lowest; blade_scale=blade) :
    Base.invokelatest(build_phantom_triangle;    blade_scale=blade)

function eval_kickstart(blade::Float64, k::Float64)
    sys, u0, p, _, design = build_cfg(blade)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)

    # ω_kick=30 rad/s (287 rpm) — kept for BOTH configs; 12-gon equilibrium
    # ≈120 rpm at k=62 so the kick is still supra-equilibrium. Documented per plan.
    omega_kick = 30.0
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            v_orb = omega_kick * r
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= v_orb .* tang
        end
    end

    sys.k_mppt_ref[] = 0.0
    run_canonical_sim!(u, sys, p, wf, round(Int, SPIN_S/DT), DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)

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
                out[] = (ef.base.P_kw, ef.base.omega_hub * 60/(2π), fos, ef.base.T_max/1000.0)
            end
        end)
    return out[]
end

# ── Meta sidecar: git hash + fingerprint at blade=1.0 and 0.85 ──
now_str() = Libc.strftime("%Y-%m-%d %H:%M:%S", time())
mkpath(dirname(OUT_CSV))
git_hash = strip(read(`git -C $(dirname(@__DIR__)) rev-parse HEAD`, String))
open(META, "w") do io
    println(io, "# kickstart_sweep_$(CONFIG) — generated $(now_str())")
    println(io, "# git=$(git_hash)")
    println(io, "# protocol: settle → kick ω=30 rad/s → $(SPIN_S)s k=0 → $(SIM_S)s MPPT @ $(WIND_MS) m/s, spokes ON")
    println(io, "# K_VALUES=$(K_VALUES)")
    println(io, "# BLADES=$(BLADES)")
    for bl in (1.0, 0.85)
        sys_f, _, p_f, label_f, design_f = build_cfg(bl)
        println(io, "# --- fingerprint at blade_scale=$(bl) ($(label_f)) ---")
        print(io, geometry_fingerprint(sys_f, p_f, design_f; blade_scale=bl))
    end
end
println("Meta written: $META")

println("════════════════════════════════════════════════════════")
println("Kickstart sweep [$(CONFIG)] — $(length(BLADES))λ × $(length(K_VALUES))k = $(length(BLADES)*length(K_VALUES)) evals")
println("git $(git_hash[1:8]) · wind $(WIND_MS) m/s · spokes ON")
println("════════════════════════════════════════════════════════")

done_keys = Set{Tuple{Float64, Float64}}()
if isfile(OUT_CSV)
    old = CSV.read(OUT_CSV, DataFrame)
    for r in eachrow(old)
        push!(done_keys, (r.blade_scale, r.k_mppt))
    end
    println("Resuming: $(length(done_keys)) rows already in $(basename(OUT_CSV))")
end

for blade in BLADES
    for k in K_VALUES
        (blade, k) in done_keys && continue
        @printf("λ=%.2f  k=%.0f ... ", blade, k); flush(stdout)
        try
            P, ω, fos, T = eval_kickstart(blade, k)
            @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f  T=%.1f kN\n", P, ω, fos, T)
            row = (blade_scale=blade, k_mppt=k, P_kw=P, omega_rpm=ω,
                   min_fos=fos, T_max_kN=T, wind_ms=WIND_MS, config=CONFIG,
                   git=git_hash[1:8], status="ok")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        catch err
            println("ERROR: $(sprint(showerror, err))")
            row = (blade_scale=blade, k_mppt=k, P_kw=NaN, omega_rpm=NaN,
                   min_fos=NaN, T_max_kN=NaN, wind_ms=WIND_MS, config=CONFIG,
                   git=git_hash[1:8], status="error")
            CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
        end
        GC.gc()
    end
end

println("\nDone. Results: $OUT_CSV")
