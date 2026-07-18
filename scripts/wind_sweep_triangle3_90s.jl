#!/usr/bin/env julia
# scripts/wind_sweep_triangle3_90s.jl — triangle3 wind sweep RE-RUN at 90 s MPPT.
#
# Why: the 30 s sweep (wind_sweep_triangle3.csv) is not converged. Direct
# evidence at 11 m/s — same design, same wind, same k, only MPPT duration
# differs vs kickstart_sweep_triangle3.csv (60 s): 107 vs 187 kW (k4) and
# 86 vs 184 kW (k8). The 30 s rows are protocol artifacts until shown
# otherwise, so the whole 12-row triangle curve is re-run at 90 s.
#
# Protocol identical to wind_sweep_triangle3.jl (settle(seed k) → kick
# ω=30 rad/s → 30 s no-load k=0 → engage k), except:
#   • MPPT extended 30 s → 90 s
#   • checkpoints at 30/60/90 s: P, P_aero, ω  (30 s column reproduces the
#     old sweep protocol; 60 s column matches the kickstart protocol;
#     60→90 s drift is the convergence verdict)
#   • P_aero_kw recorded at each checkpoint (sum of ef.rotor_aero_power) —
#     energy-balance test: P_gen > P_aero at snapshot ⇒ the generator is
#     drawing down rotational kinetic energy, i.e. a transient masquerading
#     as an operating point (prime suspect: 431 kW @ 15 m/s from 444 rpm)
#   • 1 Hz window stats over t∈[30,90] s (min FoS, max T, P min/max) to
#     catch oscillating pseudo-equilibria (cf. 12-gon 0.69/k62: P_60≈P_150
#     "converged" but P swung 166–588 kW inside the window)
#   • swept-area audit in the CSV header: per-rotor annuli + hub disk +
#     Betz ceiling at 15 m/s — sanity bound on any high-wind headline
#
# CAVEAT carried by every row: no rated-power curtailment is modeled.
# Any externally quoted number above ~50 kW needs the "no power limiter
# modeled" caveat.
#
# Ground rules: run_canonical_sim! only; progressive CSV saves; idempotent
# resume. Clear the Julia cache first if src/ changed:
#   rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji
using KiteTurbineDynamics, Printf, LinearAlgebra, CSV, DataFrames
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

const BLADE   = 0.85
const KS      = [4.0, 8.0]
const WINDS   = [5.0, 7.0, 9.0, 11.0, 13.0, 15.0]
const MPPT_S  = 90.0
const SPIN_S  = 30.0
const DT      = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "wind_sweep_triangle3_90s.csv")

const CHECKPOINTS_S  = [30.0, 60.0, 90.0]
const WINDOW_START_S = 30.0    # window stats: t ∈ [30, 90] s after engage

function snapshot(u, sys, p, t, wf)
    ef = capture_extended(u, sys, p, t, wf, nothing; brake_engaged=sys.brake_engaged[])
    airborne = Float64[]
    for i in 2:length(ef.ring_fos)
        v = ef.ring_fos[i]
        (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
    end
    fos = isempty(airborne) ? Inf : minimum(airborne)
    P_aero = sum((x for x in ef.rotor_aero_power if !isnan(x)); init=0.0)
    return (P=ef.base.P_kw, P_aero=P_aero, ω=ef.base.omega_hub * 60 / (2π),
            T=ef.base.T_max / 1000.0, fos=fos)
end

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

    n_mppt   = round(Int, MPPT_S / DT)
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

    return cps, fos_min_w, T_max_w, P_min_w, P_max_w
end

mkpath(dirname(OUT_CSV))
git_hash = strip(read(`git -C $(dirname(@__DIR__)) rev-parse HEAD`, String))
if !isfile(OUT_CSV)
    open(OUT_CSV, "w") do io
        println(io, "# wind_sweep_triangle3_90s.csv — deliberate triangle3 (build_phantom_triangle), 90 s MPPT re-run")
        println(io, "# git=$(git_hash)  supersedes wind_sweep_triangle3.csv (30 s rows not converged at 11 m/s)")
        println(io, "# protocol: settle(seed k) -> kick omega=30 rad/s -> $(SPIN_S)s k=0 -> $(MPPT_S)s MPPT, checkpoints 30/60/90 s, 1 Hz window stats t in [$(WINDOW_START_S),$(MPPT_S)] s")
        println(io, "# CAVEAT: no rated-power curtailment modeled — quote nothing above ~50 kW without the 'no power limiter' caveat")
        sys_f, _, p_f, label_f, design_f = Base.invokelatest(build_phantom_triangle; blade_scale=BLADE)
        print(io, geometry_fingerprint(sys_f, p_f, design_f; blade_scale=BLADE))
        # ── swept-area audit (Betz sanity bound for high-wind rows) ──
        hub_area = π * sys_f.rotor.radius^2
        hub_eff  = hub_area * cos(p_f.elevation_angle)^2.65
        ann_lines = String[]; ann_sum = 0.0; ann_eff_sum = 0.0
        for (i, er) in enumerate(sys_f.expansion_rotors)
            a  = π * (er.blade_tip_radius^2 - er.blade_hub_radius^2)
            ae = a * cosd(er.bank_angle_deg)
            ann_sum += a; ann_eff_sum += ae
            push!(ann_lines, @sprintf("# swept_rotor%d: r_tip=%.3fm r_hub=%.3fm annulus=%.2fm2 bank=%.1fdeg eff=%.2fm2",
                                      i, er.blade_tip_radius, er.blade_hub_radius, a, er.bank_angle_deg, ae))
        end
        println(io, @sprintf("# swept_hub_disk: r=%.3fm area=%.2fm2 eff(cos^2.65 elev)=%.2fm2", sys_f.rotor.radius, hub_area, hub_eff))
        foreach(l -> println(io, l), ann_lines)
        A_eff = hub_eff + ann_eff_sum
        P_betz15 = 0.5 * p_f.rho * 15.0^3 * A_eff * 0.593 / 1000.0
        println(io, @sprintf("# swept_total: raw=%.2fm2 effective=%.2fm2  betz_ceiling@15m/s(hub-height,no shear)=%.1fkW",
                             hub_area + ann_sum, A_eff, P_betz15))
        println(io, "blade_scale,k_mppt,wind_ms,P_30,P_60,P_90,P_aero_30,P_aero_60,P_aero_90,omega_30_rpm,omega_60_rpm,omega_90_rpm,fos_90,fos_min_window,T_max_window_kN,P_min_window,P_max_window,drift_60_90_pct,verdict,git,status")
    end
end

done = Set{Tuple{Float64,Float64}}()
for line in eachline(OUT_CSV)
    startswith(line, "0.") || continue
    f = split(line, ",")
    push!(done, (parse(Float64, f[2]), parse(Float64, f[3])))
end
isempty(done) || println("Resuming: $(length(done)) rows done")

println("Triangle3 90s wind sweep — λ=$(BLADE), k ∈ $(KS), winds $(WINDS)")
for k in KS, wind in WINDS
    (k, wind) in done && continue
    @printf("k=%.0f wind=%.0f ... ", k, wind); flush(stdout)
    try
        cps, fos_min_w, T_max_w, P_min_w, P_max_w = eval_kickstart(k, wind)
        c30, c60, c90 = cps[30.0], cps[60.0], cps[90.0]
        drift = abs(c90.P - c60.P) / max(abs(c60.P), 1e-6) * 100
        verdict = (drift <= 5.0 && isfinite(fos_min_w)) ? "converged" : "DRIFTING"
        bal = c90.P_aero > 0.1 ? c90.P / c90.P_aero : NaN
        @printf("P30=%.1f P60=%.1f P90=%.1f kW (drift %.1f%%)  Paero90=%.1f (Pgen/Paero=%.2f)  ω90=%.0f rpm  FoS_min=%.2f  [%s]\n",
                c30.P, c60.P, c90.P, drift, c90.P_aero, bal, c90.ω, fos_min_w, verdict)
        open(OUT_CSV, "a") do io
            println(io, join([BLADE, k, wind, c30.P, c60.P, c90.P,
                              c30.P_aero, c60.P_aero, c90.P_aero,
                              c30.ω, c60.ω, c90.ω, c90.fos,
                              fos_min_w, T_max_w, P_min_w, P_max_w,
                              drift, verdict, git_hash[1:8], "ok"], ","))
        end
    catch err
        println("ERROR: $(sprint(showerror, err))")
        open(OUT_CSV, "a") do io
            println(io, join([BLADE, k, wind, fill(NaN, 15)..., "error", git_hash[1:8], "error"], ","))
        end
    end
    GC.gc()
end
println("\nDone. Results: $OUT_CSV")
