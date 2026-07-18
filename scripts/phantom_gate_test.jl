#!/usr/bin/env julia
# scripts/phantom_gate_test.jl — Gate: phantom triangle must reproduce legacy
# wind_sweep 0.85/k2/11 m/s: 117.4 kW @ 411 rpm FoS 4.52 (retest_085_k2.jl protocol)
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "hunt_kmppt_bisect.jl"))
using .ControlMapHunt
import KiteTurbineDynamics: SpokeParams

const BLADE = 0.85
const K = 2.0
const WIND = 11.0
const SIM_S = 30.0
const DT = ControlMapHunt.DT

include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))
# LEGACY PHYSICS PIN (2026-07-18): this script reproduces CSVs archived under
# the pre-induction model. Default flipped to induction=ON; pin OFF here so
# the committed results stay bit-reproducible. New work: use the default.
set_expansion_induction!(false)


sys, u0, p, label, design = Base.invokelatest(build_phantom_triangle; blade_scale=BLADE)
print(geometry_fingerprint(sys, p, design; blade_scale=BLADE))

sp = SpokeParams(enabled=true)
N = sys.n_total; Nr = sys.n_ring

wf(pos, t) = begin
    z = max(pos[3], 1.0)
    [WIND * (z / p.h_ref)^(1.0/7.0), 0.0, 0.0]
end

sys.k_mppt_ref[] = K
u = settle_to_equilibrium(sys, copy(u0), p; wind_fn=wf)
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
n_spin = round(Int, 30.0 / DT)
run_canonical_sim!(u, sys, p, wf, n_spin, DT; lift_device=nothing, lin_damp=0.05, spoke=sp)
sys.k_mppt_ref[] = K

n_mppt = round(Int, SIM_S / DT)
out = Ref((0.0, 0.0, Inf, 0.0))
run_canonical_sim!(u, sys, p, wf, n_mppt, DT;
    lift_device=nothing, lin_damp=0.05, spoke=sp,
    callback=(u_curr, t_curr, step) -> begin
        if step == n_mppt
            ef = capture_extended(u_curr, sys, p, t_curr, wf, nothing; brake_engaged=sys.brake_engaged[])
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]; (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            fos = isempty(airborne) ? Inf : minimum(airborne)
            out[] = (ef.base.P_kw, ef.base.omega_hub * 60 / (2π), fos, ef.base.T_max / 1000.0)
        end
    end)

P, ω, fos, T = out[]
@printf("\nPhantom gate: P=%.1f kW  ω=%.0f rpm  FoS=%.2f  T=%.1f kN\n", P, ω, fos, T)
println("Legacy target: P=117.4 kW  ω=411 rpm  FoS=4.52  T=77.3 kN")
p_ok = abs(P - 117.37) < 6.0
ω_ok = abs(ω - 411.0) < 21.0
fos_ok = abs(fos - 4.52) < 0.45
println("GATE: P=", p_ok ? "✓" : "✗", "  ω=", ω_ok ? "✓" : "✗", "  FoS=", fos_ok ? "✓" : "✗", "  → ", (p_ok && ω_ok && fos_ok) ? "PASS" : "FAIL")
