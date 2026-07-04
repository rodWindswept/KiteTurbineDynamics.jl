#!/usr/bin/env julia
# test_079.jl — λ=0.79 blade scale: projected 50 kW ground
using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics; using Printf

const DT = 4e-5; const V_WIND = 11.0; const BS = 0.79; const K0 = 15.6
include(joinpath(dirname(@__DIR__), "scripts", "builders_util.jl"))

# k: use λ² (blade-area scaling) — the static aero follows λ² at peak
k_val = K0 * BS^2

sys, u0, p, _ = Base.invokelatest(build_v10_tight_no_lowest; blade_scale=BS)
sys.k_mppt_ref[] = k_val
wf(pos, t) = begin z = max(pos[3], 1.0); [V_WIND*(z/p.h_ref)^(1/7), 0.0, 0.0] end
lift = KiteTurbineDynamics.rotary_lifter_default()

# Use settle to find equilibrium with ω_max generous enough
println("Settling λ=$BS, k=$(round(k_val, digits=1)), ω_max=40...")
u = settle_to_operational_state(sys, copy(u0), p, 40.0; lift_device=lift, wind_fn=wf)
n = round(Int, 10.0/DT)

P_ref = Ref(0.0); w_ref = Ref(0.0); f_ref = Ref(Inf)
run_canonical_sim!(u, sys, p, wf, n, DT; lift_device=lift, lin_damp=0.05,
    callback=(uc, tc, step) -> begin
        if step == n
            ef = capture_extended(uc, sys, p, tc, wf, lift; brake_engaged=sys.brake_engaged[])
            P_ref[] = ef.base.P_kw; w_ref[] = ef.base.omega_hub*60/(2pi)
            fv = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]; !isnan(v) && !isinf(v) && v > 0 && push!(fv, v)
            end
            f_ref[] = isempty(fv) ? Inf : minimum(fv)
        end
    end)

P = P_ref[]; ω = w_ref[]; fs = f_ref[]
println()
println("λ=$BS  k=$(round(k_val, digits=1)):")
println("  P = $(round(P, digits=1)) kW  (target: ≥50 kW)")
println("  ω = $(round(ω, digits=1)) rpm")
println("  FoS = $(round(fs, digits=2))  (target: ≥1.5)")

# Quick energy balance at converged state
N = sys.n_total; Nr = sys.n_ring
omega_shaft = abs(u[6N + Nr + 1])
hub_gid = sys.rotor.node_id; hub_ctr = u[(3*(hub_gid-1)+1):(3*hub_gid)]
v_vec = wf(hub_ctr, 0.0); V_hub = max(sqrt(v_vec[1]^2+v_vec[2]^2), 0.1)
elev_deg = rad2deg(p.elevation_angle)

lambda = clamp(omega_shaft*sys.rotor.radius/V_hub, 0.0, 12.0)
cp = cp_at_tsr(lambda)
P_hub = 0.5*p.rho*V_hub^3*π*sys.rotor.radius^2*cp*cos(p.elevation_angle)^2.65/1000

P_exp = 0.0
for er in sys.expansion_rotors
    ri = er.ring_idx
    ri < 1 || ri > Nr && continue
    rgid = sys.ring_ids[ri]; rpos = u[(3*(rgid-1)+1):(3*rgid)]
    rω = abs(u[6N+Nr+ri]); rnom = (sys.nodes[rgid]::RingNode).radius
    vw = wf(rpos, 0.0); vm = max(sqrt(vw[1]^2+vw[2]^2), 0.1)
    T_est = ri > 1 ? sum(KiteTurbineDynamics.get_segment_tension(u, sys, p, ri-1, j) for j in 1:p.n_lines)/p.n_lines : 100.0
    _, _, tn, _, _ = expansion_rotor_forces(er, p.rho, vm, rω, elev_deg, rnom, max(T_est, 100.0), p.n_lines)
    P_exp += tn * rω / 1000
end

P_aero = P_hub + P_exp
println("  Σ Aero = $(round(P_aero, digits=1)) kW (Hub=$(round(P_hub, digits=1)), Exp=$(round(P_exp, digits=1)))")
println("  Loss = $(round(P_aero - P, digits=1)) kW ($(round((P_aero-P)/P_aero*100, digits=0))%)")
println("  Shaft η = $(round(P/P_aero*100, digits=0))%")

if P >= 50.0 && fs >= 1.5
    println("\n✓  λ=$BS DESIGN MEETS P≥50 kW AND FoS≥1.5 AT RATED WIND")
elseif P >= 50.0
    println("\n  P≥50 ✓ but FoS=$(round(fs, digits=2)) < 1.5")
else
    println("\n  P=$(round(P, digits=1)) < 50 kW — undershoot")
end
