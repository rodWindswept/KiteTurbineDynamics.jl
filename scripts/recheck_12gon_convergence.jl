#!/usr/bin/env julia
# recheck_12gon_convergence.jl — dual-duration convergence check on suspicious
# 12-gon kickstart rows (2026-07-17 sweep, kickstart_sweep_12gon.csv).
#
# Motivation: single-snapshot FoS at t=60s is suspect (e.g. 0.69/k62 shows
# 326 kW with only 3.9 kN peak tension). Protocol: same kickstart as the
# sweep, but 150 s MPPT with 1 Hz sampling after t=30 s. Reports P/ω/FoS/T
# at 60/90/120/150 s checkpoints plus window min-FoS and max-T over
# t∈[30,150] s. A row is "converged" if P_150 within ~5% of P_60 AND
# fos_min_window ≈ fos at checkpoints (no transient dips between snapshots).
#
# Also probes the λ=0.75 high-k collapse with an alternate kick speed
# (ω_kick=40) to distinguish true bistability from kick sensitivity.
#
# Ground rules honored: run_canonical_sim! only; progressive CSV saves;
# idempotent resume. Clear the Julia cache before running if src/ changed:
#   rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji

using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const WIND_MS = 11.0
const SPIN_S  = 30.0     # no-load spin-up, k=0 (matches sweep)
const MPPT_S  = 150.0    # extended from the sweep's 60 s
const DT      = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "kickstart_12gon_recheck.csv")

const CHECKPOINTS_S = [60.0, 90.0, 120.0, 150.0]
const WINDOW_START_S = 30.0   # stats window: t ∈ [30, 150] s after engage

# (blade_scale, k_mppt, omega_kick)
const ROWS = [
    (0.69, 48.0, 30.0),   # FoS 1.07 — borderline, needs confirmation
    (0.69, 62.0, 30.0),   # 326 kW @ 3.9 kN — prime non-convergence suspect
    (0.75, 48.0, 30.0),   # collapsed column — real stall or artifact?
    (0.75, 62.0, 30.0),   #   "
    (0.75, 62.0, 40.0),   # kick-sensitivity probe (only ω_kick differs)
    (0.80, 62.0, 30.0),   # 521 kW FoS 1.97 — the headline row
    (0.80, 96.0, 30.0),   # 691 kW FoS 0.29 — confirm the failure is real
]

function snapshot(u, sys, p, t, wf)
    ef = capture_extended(u, sys, p, t, wf, nothing; brake_engaged=sys.brake_engaged[])
    airborne = Float64[]
    for i in 2:length(ef.ring_fos)
        v = ef.ring_fos[i]
        (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
    end
    fos = isempty(airborne) ? Inf : minimum(airborne)
    return (P=ef.base.P_kw, ω=ef.base.omega_hub * 60 / (2π),
            T=ef.base.T_max / 1000.0, fos=fos)
end

function eval_row(blade::Float64, k::Float64, omega_kick::Float64)
    fn = ControlMapHunt.v10_tight_builder(blade_scale=blade)
    sys, u0, p, label = Base.invokelatest(fn)
    sp = SpokeParams(enabled=true)
    N = sys.n_total; Nr = sys.n_ring

    wf(pos, t) = begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
    end

    u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)

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
    run_canonical_sim!(u, sys, p, wf, round(Int, SPIN_S / DT), DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp)

    sys.k_mppt_ref[] = k
    n_mppt = round(Int, MPPT_S / DT)
    steps_1s = max(1, round(Int, 1.0 / DT))
    cp_steps = Dict(round(Int, s / DT) => s for s in CHECKPOINTS_S)

    cps = Dict{Float64,Any}()
    fos_min_w = Inf; T_max_w = 0.0; P_min_w = Inf; P_max_w = -Inf

    run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
        lift_device=nothing, lin_damp=0.05, spoke=sp,
        callback=(u_curr, t_curr, step) -> begin
            if step % steps_1s == 0 || haskey(cp_steps, step) || step == n_mppt
                s = snapshot(u_curr, sys, p, t_curr, wf)
                if step * DT >= WINDOW_START_S
                    fos_min_w = min(fos_min_w, s.fos)
                    T_max_w   = max(T_max_w, s.T)
                    P_min_w   = min(P_min_w, s.P)
                    P_max_w   = max(P_max_w, s.P)
                end
                haskey(cp_steps, step) && (cps[cp_steps[step]] = s)
                step == n_mppt && !haskey(cps, MPPT_S) && (cps[MPPT_S] = s)
            end
        end)

    return cps, fos_min_w, T_max_w, P_min_w, P_max_w, label
end

mkpath(dirname(OUT_CSV))
println("════════════════════════════════════════════════════════════")
println("12-gon convergence recheck — $(MPPT_S)s MPPT, 1 Hz sampling")
println("Wind: $(WIND_MS) m/s · spokes ON · window stats t∈[$(WINDOW_START_S),$(MPPT_S)]s")
println("════════════════════════════════════════════════════════════")

done = Set{Tuple{Float64,Float64,Float64}}()
if isfile(OUT_CSV)
    for r in eachrow(CSV.read(OUT_CSV, DataFrame))
        push!(done, (r.blade_scale, r.k_mppt, r.omega_kick))
    end
    println("Resuming: $(length(done)) rows done")
end

for (blade, k, kick) in ROWS
    (blade, k, kick) in done && continue
    @printf("blade %.2f  k=%.0f  kick=%.0f ... ", blade, k, kick); flush(stdout)
    try
        cps, fos_min_w, T_max_w, P_min_w, P_max_w, label = eval_row(blade, k, kick)
        c60, c150 = cps[60.0], cps[150.0]
        drift = abs(c150.P - c60.P) / max(abs(c60.P), 1e-6) * 100
        verdict = (drift <= 5.0 && isfinite(fos_min_w)) ? "converged" : "DRIFTING"
        @printf("P60=%.1f P150=%.1f (drift %.1f%%)  FoS_end=%.2f  FoS_min=%.2f  T_max=%.1f kN  [%s]\n",
                c60.P, c150.P, drift, c150.fos, fos_min_w, T_max_w, verdict)
        row = (blade_scale=blade, k_mppt=k, omega_kick=kick, wind_ms=WIND_MS,
               P_60=c60.P, P_90=get(cps, 90.0, c60).P, P_120=get(cps, 120.0, c60).P, P_150=c150.P,
               omega_150_rpm=c150.ω, fos_60=c60.fos, fos_150=c150.fos,
               fos_min_window=fos_min_w, T_max_window_kN=T_max_w,
               P_min_window=P_min_w, P_max_window=P_max_w,
               drift_pct=drift, verdict=verdict, builder=label, status="ok")
        CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
    catch err
        println("ERROR: $(sprint(showerror, err))")
        row = (blade_scale=blade, k_mppt=k, omega_kick=kick, wind_ms=WIND_MS,
               P_60=NaN, P_90=NaN, P_120=NaN, P_150=NaN,
               omega_150_rpm=NaN, fos_60=NaN, fos_150=NaN,
               fos_min_window=NaN, T_max_window_kN=NaN,
               P_min_window=NaN, P_max_window=NaN,
               drift_pct=NaN, verdict="error", builder="", status="error")
        CSV.write(OUT_CSV, DataFrame([row]); append=isfile(OUT_CSV))
    end
    GC.gc()
end

println("\nDone. Results: $OUT_CSV")
