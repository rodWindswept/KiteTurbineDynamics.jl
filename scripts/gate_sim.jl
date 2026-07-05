#!/usr/bin/env julia
# gate_sim.jl — Single-point gate verification: k=15.6, v=11 m/s, 60s
using KiteTurbineDynamics; using Printf
include("builders_util.jl")

const DT = 4e-5; const T_SIM = 60.0; const V_WIND = 11.0; const K_REF = 15.6
const STEP_15 = round(Int, 15.0 / DT)
const STEP_60 = round(Int, T_SIM / DT)

sys, u0, p, label = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=1.0)
sys.k_mppt_ref[] = K_REF

wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [V_WIND * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end

println("Builder: " * string(label))
println("Settling (with lift device, match sweep)...")
lift = KiteTurbineDynamics.rotary_lifter_default()
u = settle_to_operational_state(sys, copy(u0), p, 9.5; lift_device=lift, wind_fn=wf)
println("Settle done. Running 60s sim at k=15.6, v=11 m/s...")
println()

ctrl = RampController(P_target=p.p_rated_w)
init_geometry!(ctrl, sys, p)

results = []  # collect (t, P_kw, ω_rad, FoS, P_aero, P_loss, cons, n_fail)

run_canonical_sim!(u, sys, p, wf, STEP_60, DT;
    lift_device=lift, lin_damp=0.05,
    callback=(u_curr, t_curr, step) -> begin
        if step == STEP_15 || step == STEP_60
            ef = capture_extended(u_curr, sys, p, t_curr, wf, lift;
                brake_engaged=sys.brake_engaged[])
            P_kw = ef.base.P_kw
            ω_hub = ef.base.omega_hub

            ring_fos = ef.ring_fos
            airborne = Float64[]
            for i in 2:length(ring_fos)
                v = ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            min_fos = isempty(airborne) ? Inf : minimum(airborne)
            n_fail = count(x -> !isnan(x) && x < 1.0, ring_fos[2:end])

            P_aero = sum(x for x in ef.rotor_aero_power if !isnan(x))  # rotor_aero_power already in kW
            P_loss = P_aero - P_kw
            cons = ω_hub > 0.1 ? P_kw / (K_REF * ω_hub^3) : 0.0

            tag = step == STEP_15 ? "t=15s" : "t=60s"
            println("$tag: P=$(round(P_kw, digits=1)) kW  ω=$(round(ω_hub, digits=4)) rad/s  ω_rpm=$(round(ω_hub*60/(2π), digits=1))")
            println("$tag: FoS=$(round(min_fos, digits=2))  $n_fail/$(length(ring_fos)-1) failing")
            println("$tag: P_aero=$(round(P_aero, digits=1)) kW  P_loss=$(round(P_loss, digits=1)) kW")
            println("$tag: stamp P/kω³ = $(round(cons, digits=6))  closure = $(round((P_aero-P_loss-P_kw)/P_aero*100, digits=3))%")
            println()
            push!(results, (t_curr, P_kw, ω_hub, min_fos, n_fail, P_aero, P_loss, cons))
        end
    end)

# Print comparison
if length(results) >= 2
    _, P15, ω15, FoS15, _, a15, l15, c15 = results[1]
    _, P60, ω60, FoS60, _, a60, l60, c60 = results[2]
    println("="^60)
    println("COMPARISON: t=15s vs t=60s")
    println("  P15=$(round(P15, digits=1)) kW  P60=$(round(P60, digits=1)) kW  ΔP=$(round(P60-P15, digits=1)) kW")
    println("  ω15=$(round(ω15*60/(2π), digits=1)) rpm  ω60=$(round(ω60*60/(2π), digits=1)) rpm  Δω=$(round((ω60-ω15)*60/(2π), digits=1)) rpm")
    println("  FoS15=$(round(FoS15, digits=2))  FoS60=$(round(FoS60, digits=2))  ΔFoS=$(round(FoS60-FoS15, digits=2))")
    println("  stamp15=$(round(c15, digits=6))  stamp60=$(round(c60, digits=6))")
    println("  P_aero15=$(round(a15, digits=1)) kW  P_aero60=$(round(a60, digits=1)) kW")
    println("="^60)
    if abs(P60 - P15) > 0.5
        println("⚠ CONVERGENCE: partial — P drift $(round(P60-P15, digits=1)) > 0.5 kW threshold")
    else
        println("✓ CONVERGENCE: stable — P drift $(round(P60-P15, digits=1)) ≤ 0.5 kW threshold")
    end
end
