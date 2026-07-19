#!/usr/bin/env julia
# scripts/wind_sweep_triangle3.jl — triangle3 wind sweep at BOTH best kickstart points
# 0.85/k4 (187 kW max power, FoS 5.5) and 0.85/k8 (184 kW, FoS 26) — near-equal
# power but likely different ω branches; find which branch survives 15 m/s.
# Protocol = legacy retest_085_k2.jl (settle → kick 30 → 30s k=0 → 30s MPPT),
# builder = build_phantom_triangle (validated bit-for-bit vs legacy).
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))
# LEGACY PHYSICS PIN (2026-07-18): this script reproduces CSVs archived under
# the pre-induction model. Default flipped to induction=ON; pin OFF here so
# the committed results stay bit-reproducible. New work: use the default.
set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)


const BLADE   = 0.85
const KS      = [4.0, 8.0]
const WINDS   = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const SIM_S   = 30.0
const SPIN_S  = 30.0
const DT      = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "wind_sweep_triangle3.csv")

function eval_kickstart(k, wind)
    sys, u0, p, _, design = Base.invokelatest(build_phantom_triangle; blade_scale=BLADE)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring
    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [wind * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end
    sys.k_mppt_ref[] = k
    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
    omega_kick = 30.0
    for ri in 1:Nr
        u[6*N + Nr + ri] = omega_kick
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= (omega_kick * r) .* tang
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
                out[] = (ef.base.P_kw, ef.base.omega_hub*60/(2π), fos, ef.base.T_max/1000.0)
            end
        end)
    return out[]
end

mkpath(dirname(OUT_CSV))
git_hash = strip(read(`git -C $(dirname(@__DIR__)) rev-parse HEAD`, String))
if !isfile(OUT_CSV)
    open(OUT_CSV, "w") do io
        println(io, "# wind_sweep_triangle3.csv — deliberate triangle3 (build_phantom_triangle)")
        println(io, "# git=$(git_hash)  wind sweep at 0.85/k4 and 0.85/k8")
        println(io, "# protocol: settle(seed k) -> kick omega=30 rad/s -> $(SPIN_S)s k=0 -> $(SIM_S)s MPPT (legacy retest_085_k2 protocol)")
        sys_f, _, p_f, label_f, design_f = Base.invokelatest(build_phantom_triangle; blade_scale=BLADE)
        print(io, geometry_fingerprint(sys_f, p_f, design_f; blade_scale=BLADE))
        println(io, "blade_scale,k_mppt,wind_ms,P_kw,omega_rpm,min_fos,T_max_kN,git,status")
    end
end

done = Set{Tuple{Float64,Float64}}()
for line in eachline(OUT_CSV)
    startswith(line, "0.") || continue
    f = split(line, ",")
    push!(done, (parse(Float64, f[2]), parse(Float64, f[3])))
end
isempty(done) || println("Resuming: $(length(done)) rows done")

println("Triangle3 wind sweep — λ=$(BLADE), k ∈ $(KS), winds $(WINDS)")
for k in KS, wind in WINDS
    (k, wind) in done && continue
    @printf("k=%.0f wind=%.0f ... ", k, wind); flush(stdout)
    try
        P, ω, fos, T = eval_kickstart(k, wind)
        @printf("P=%.1f kW  ω=%.0f rpm  FoS=%.2f  T=%.1f kN\n", P, ω, fos, T)
        open(OUT_CSV, "a") do io
            println(io, "$(BLADE),$(k),$(wind),$(P),$(ω),$(fos),$(T),$(git_hash[1:8]),ok")
        end
    catch err
        println("ERROR: $(sprint(showerror, err))")
        open(OUT_CSV, "a") do io
            println(io, "$(BLADE),$(k),$(wind),NaN,NaN,NaN,NaN,$(git_hash[1:8]),error")
        end
    end
    GC.gc()
end
println("\nDone. Results: $OUT_CSV")
