#!/usr/bin/env julia
# Single point: 0.85/k4 at 15 m/s with kickstart
using KiteTurbineDynamics, Printf, CSV, DataFrames, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const WIND = 15.0
const K = 4.0
const BLADE = 0.85
const SIM_S = 30.0  # shorter to avoid ODE stall
const DT = ControlMapHunt.DT
const OUT_CSV = joinpath(@__DIR__, "results", "control_maps", "wind_sweep.csv")

fn = ControlMapHunt.v10_tight_builder(blade_scale=BLADE)
sys, u0, p, _ = Base.invokelatest(fn)
sp = SpokeParams(enabled=true)
N = sys.n_total; Nr = sys.n_ring

wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [WIND * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
end

sys.k_mppt_ref[] = K

# Kickstart spin-up
u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
omega_kick = 30.0
for ri in 1:Nr
    u[6*N + Nr + ri] = omega_kick
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
run_canonical_sim!(u, sys, p, wf, n_spin, DT; lift_device=nothing, lin_damp=0.05, spoke=sp)
sys.k_mppt_ref[] = K  # re-engage!

n_mppt = round(Int, SIM_S / DT)
P_final, ω_final, fos_final, T_final = 0.0, 0.0, Inf, 0.0
run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
    lift_device=nothing, lin_damp=0.05, spoke=sp,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_mppt
            ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
            P_final = ef.base.P_kw
            ω_final = ef.base.omega_hub * 60 / (2π)
            T_final = ef.base.T_max / 1000.0
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            fos_final = isempty(airborne) ? Inf : minimum(airborne)
        end
    end)

@printf("0.85/k4 wind=15: P=%.1f kW ω=%.0f rpm FoS=%.2f\n", P_final, ω_final, fos_final)
row = (blade_scale=BLADE, k_mppt=K, wind_ms=WIND, label="0.85/k4 (light blade)",
       P_kw=P_final, omega_rpm=ω_final, min_fos=fos_final, T_max_kN=T_final, status="ok")
CSV.write(OUT_CSV, DataFrame([row]); append=true)
println("Done.")
