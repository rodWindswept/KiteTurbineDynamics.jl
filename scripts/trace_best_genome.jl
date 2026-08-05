#!/usr/bin/env julia
# scripts/trace_best_genome.jl — 60s full telemetry trace for best campaign genome
using KiteTurbineDynamics, CSV, DataFrames

x = [0.24579996596445525, 0.13779534336868596, 1.0, 0.8736405846402429,
     5.366563145999496, 1.7046874056953067, 2.861839598011067, 13.751676131368294,
     0.04569114201918076, 11.92582573087607, 13.525926853981108, 25.0,
     0.6124500700455991, 0.1, -2.0]
p = params_v5_50kw()
result = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
    max_ground_radius=5.0, power_W=50000.0)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, 10.0^x[15])
println("System: $(sys.n_total) nodes, $(sys.n_ring) rings, n_lines=$(result.design.n_lines)")

ld = RotaryLifterParams(1.3, 0.3, 3, 0.15, 1.0, 0.08, 33.0, 25.0, 200_000.0, 4.0)
wf(pos, t) = [11.0 * (max(pos[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]

println("Settling to operational state...")
u = settle_to_operational_state(sys, u0, p, 9.5; lift_device=ld, wind_fn=wf)
println("Settled. Starting 60s trace...")

DT = 4e-5
sample_every = round(Int, 1.0 / DT)
total_steps = round(Int, 60.0 / DT)

# Wider telemetry: aero, forces, per-ring FoS
R = DataFrame(
    t=Float64[], hub_z=Float64[], omega_hub=Float64[], P_kw=Float64[],
    FoS_min=Float64[], FoS_ring1=Float64[], FoS_ringN=Float64[],
    tau_aero_Nm=Float64[], tau_gen_Nm=Float64[], TSR=Float64[],
    wind_hub_ms=Float64[],
    tether_max_N=Float64[], T_lift_N=Float64[], lift_margin=Float64[],
)

function cb(uc, tc, s)
    if s % sample_every != 0
        return
    end
    ef = capture_extended(uc, sys, pc, tc, wf, ld; brake_engaged=sys.brake_engaged[])

    # FoS: min airborne + per-ring
    airborne_fos = Float64[]
    for i in 2:length(ef.ring_fos)
        v = ef.ring_fos[i]
        if !isnan(v) && !isinf(v) && v > 0
            push!(airborne_fos, v)
        end
    end
    fos_min = isempty(airborne_fos) ? Inf : minimum(airborne_fos)
    fos_r1 = length(ef.ring_fos) >= 2 ? ef.ring_fos[2] : NaN
    fos_rN = ef.ring_fos[end]

    # Aero
    tau_aero = ef.base.tau_aero
    tau_gen = ef.base.tau_gen
    tsr = ef.base.tsr
    wind_ms = ef.base.V_hub
    tether_tension = ef.base.T_max

    # Lift line
    lift_t = ef.base.T_lift
    lift_margin = ef.base.lift_margin

    push!(R, (tc, ef.base.hub_z, ef.base.omega_hub, ef.base.P_kw,
              fos_min, fos_r1, fos_rN,
              tau_aero, tau_gen, tsr, wind_ms,
              tether_tension, lift_t, lift_margin))
end

sys.k_mppt_ref[] = pc.k_mppt
run_canonical_sim!(u, sys, pc, wf, total_steps, DT;
    lift_device=ld, lin_damp=0.05, callback=cb)

out_path = "scripts/results/recampaign/best_genome_trace.csv"
CSV.write(out_path, R)
println("Done. $(nrow(R)) samples written to $out_path")

if nrow(R) > 0
    Pv = filter(isfinite, R.P_kw)
    fv = filter(v -> isfinite(v) && v > 0, R.FoS_min)
    println("P_kW:    mean=$(round(mean(Pv);digits=1)) max=$(round(maximum(Pv);digits=1))")
    println("FoS:     mean=$(round(mean(fv);digits=3)) min=$(round(minimum(fv);digits=3))")
    println("tau_aero: mean=$(round(mean(filter(isfinite,R.tau_aero_Nm));digits=1)) Nm")
    println("TSR:      mean=$(round(mean(filter(isfinite,R.TSR));digits=2))")
    println("T_lift:   mean=$(round(mean(filter(isfinite,R.T_lift_N));digits=0)) N")
    println("Hub Z:    $(round(R.hub_z[1];digits=1)) → $(round(R.hub_z[end];digits=1)) m")
end
