#!/usr/bin/env julia
# diag_settle_gap.jl — settle-vs-ODE equilibrium gap on the Daisy-anchored 5 kW
# seed (Option-2 workstream, 2026-08-22).  The honest-window k sweep shows the
# corrected 18.8 m machine decays to ω ≈ −0.2 rad/s at EVERY k — the ODE's true
# equilibrium is not where the settle model parks it.
#
# Traces: settle ω_eq, then the ODE ω_gnd(t)/P_gen(t) over the first seconds,
# plus the ODE's own aero-power formula at the settle ω (vs the settle model).
#
# Usage: julia --project=. scripts/diag_settle_gap.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8
const K_MPPT = 5.39

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

p_base = params_at_length(LENGTH)
x = seed_genome(KW)
xr = copy(x)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
result = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW, v_rated=V_RATED)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    result, 1.0, K_MPPT; base_params=p_base)

function wf(pos, t)
    z = max(pos[3], 1.0)
    return [V_RATED * (z / p_base.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end

N = sys.n_total; Nr = sys.n_ring
ω_gnd_idx = 6N + Nr + 1

@printf("seed: R=%.3f r_in=%.3f A=%.2f m²  n_lines=%d n_ring=%d  m_rotor=%.2f kg\n",
    sys.rotor.radius, sys.rotor.blade_hub_radius,
    π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2),
    pc.n_lines, sys.n_ring, pc.n_blades * pc.m_blade)

# ── Settle to operational state; read the settle's ω ─────────────────────
lift_dev = lift_for(sys, pc)   # resolve the sized lifter for THIS genome
u_settled = KiteTurbineDynamics.settle_to_operational_state(
    sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev
)
ω_gnd_settle = u_settled[ω_gnd_idx]
@printf("settle: ω_gnd = %.2f rad/s (%.1f rpm)\n", ω_gnd_settle, ω_gnd_settle * 60 / 2π)

# Settle-model P_aero at the settle ω (same formula the scan uses)
v_hub = norm(wf(u_settled[(3*(sys.rotor.node_id-1)+1):(3*sys.rotor.node_id)], 0.0))
λ_settle = ω_gnd_settle * sys.rotor.radius / v_hub
P_aero_settle =
    0.5 * pc.rho * v_hub^3 * π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2) *
    KiteTurbineDynamics.cp_at_tsr(λ_settle) * cos(pc.elevation_angle)^2.65
P_gen_settle = K_MPPT * ω_gnd_settle^3
@printf("settle model: λ=%.2f  P_aero=%.2f kW  P_gen=%.2f kW  margin=%.2f kW\n",
    λ_settle, P_aero_settle / 1000, P_gen_settle / 1000, (P_aero_settle - P_gen_settle) / 1000)

# ── ODE trace from the settle state, 10 s ────────────────────────────────
sys.k_mppt_ref[] = K_MPPT
trace = Tuple{Float64,Float64,Float64}[]
function cb(u, t, s)
    if s % 2500 == 0
        # P_gen via the ODE's generator torque at the ground ring
        τg, _ = KiteTurbineDynamics.get_generator_torque(
            u, sys, pc, t, wf; brake_engaged=sys.brake_engaged[]
        )
        Pg = τg * u[ω_gnd_idx]
        push!(trace, (t, u[ω_gnd_idx], Pg))
    end
    return nothing
end
run_canonical_sim!(u_settled, sys, pc, wf, round(Int, 10.0 / 4e-5), 4e-5;
    lift_device=lift_dev, callback=cb)
@printf("ODE 10 s trace (t, ω_gnd, P_gen):\n")
for (t, w, Pg) in trace[1:min(end, 30)]
    @printf("  t=%5.2f  ω= %7.3f  P_gen= %7.3f kW\n", t, w, Pg / 1000)
end
last_row = trace[end]
@printf("ODE end (10 s): ω_gnd=%.3f rad/s  P_gen=%.3f kW\n", last_row[2], last_row[3] / 1000)
@printf("gap: settle ω %.2f → ODE ω %.2f (%+.1f%%)\n",
    ω_gnd_settle, last_row[2], 100 * (last_row[2] - ω_gnd_settle) / ω_gnd_settle)
