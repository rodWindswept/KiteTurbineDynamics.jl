#!/usr/bin/env julia
# Stage 0 gate: warmstart regression vs full protocol
# One-off diagnostic on 12-gon reference at k=40 (known stable).
using KiteTurbineDynamics, Printf, Statistics, LinearAlgebra

const X12 = [0.075,0.01,1.0,0.5,3.7,2.0,2.5,12.0,0.0,8.0,15.0,5.0,0.5,0.3,log10(40.0)]

p = params_v5_50kw()
spoke = KiteTurbineDynamics.SpokeParams(enabled=false)
x_k40 = copy(X12)

# Warmstart path
f_ws, P_ws, FoS_ws, ω_ws, P_range_ws, drifted_ws, stationary_ws =
    objective_v11_warmstart(x_k40, PROFILE_ELLIPTICAL, p; spoke=spoke)

# Full protocol path
result = KiteTurbineDynamics.design_from_vector_v10(X12[1:14], PROFILE_ELLIPTICAL, p)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(result, 1.0, 40.0)

function wf(pos, t) z=max(pos[3],1.0); [11*(z/p.h_ref)^(1/7),0,0] end

u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf)
orig_k = sys.k_mppt_ref[]; sys.k_mppt_ref[] = -40.0
ks = round(Int, 2.0 / KiteTurbineDynamics.V11_DT)
KiteTurbineDynamics.run_canonical_sim!(u, sys, pc, wf, ks, KiteTurbineDynamics.V11_DT; lin_damp=0.05, spoke=spoke)
sys.k_mppt_ref[] = orig_k

total_n = round(Int, (10+30) / KiteTurbineDynamics.V11_DT)
sample_every = round(Int, 1.0 / KiteTurbineDynamics.V11_DT)
discard_n = round(Int, 10.0 / KiteTurbineDynamics.V11_DT)
Ps = Float64[]; FoSs = Float64[]
function cb(uc, tc, s)
    s<discard_n && return; s%sample_every!=0 && return
    ef = capture_extended(uc, sys, pc, tc, wf, nothing; brake_engaged=sys.brake_engaged[])
    push!(Ps, ef.base.P_kw)
    air=[v for v in ef.ring_fos[2:end] if isfinite(v)&&v>0]
    push!(FoSs, isempty(air)?Inf:minimum(air))
end
run_canonical_sim!(u, sys, pc, wf, total_n, V11_DT; lin_damp=0.05, spoke=spoke, callback=cb)

P_full = mean(Ps)
FoS_full = isempty(FoSs)||all(isinf.(FoSs)) ? Inf : minimum(FoSs)
P_range_full = length(Ps)>=2 ? maximum(Ps)-minimum(Ps) : 0
drift_full = length(Ps)>=2 ? abs(Ps[end]-Ps[1])/max(mean(Ps),0.01) : 0

println("=== Warmstart Regression: 12-gon, k=40 ===")
@printf("  Warmstart: P=%.1f kW  FoS=%.3f  P_range=%.0f  drift=%d\n", P_ws, FoS_ws, P_range_ws, drifted_ws)
@printf("  Full:      P=%.1f kW  FoS=%.3f  P_range=%.0f  drift=%.2f\n", P_full, FoS_full, P_range_full, drift_full)

dP = abs(P_ws - P_full) / max(abs(P_full), 0.01)
dF = isfinite(FoS_ws)&&isfinite(FoS_full) ? abs(FoS_ws-FoS_full)/max(FoS_full,0.001) : 99
println()
if dP < 0.30 && dF < 0.30
    println("PASS: warmstart agrees with full protocol (ΔP=$(round(dP*100,digits=1))%, ΔFoS=$(round(dF*100,digits=1))%)")
else
    println("FAIL: warmstart diverges from full protocol (ΔP=$(round(dP*100,digits=1))%, ΔFoS=$(round(dF*100,digits=1))%)")
end
println("Stage 0 regression gate: $(dP<0.30&&dF<0.30 ? "GREEN" : "RED")")
