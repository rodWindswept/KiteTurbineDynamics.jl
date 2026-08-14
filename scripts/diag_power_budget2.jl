#!/usr/bin/env julia --project=.
#= diag_power_budget2.jl — clean power budget at 5kW steady state.
Components computed DIRECTLY from the same functions the ODE uses:
  P_aero_hub  = hub rotor τ×ω (cp_at_tsr model, ring_forces.jl:152-185)
  P_aero_exp  = Σ expansion τ_net×ω (expansion_rotor_forces)
  P_gen       = get_generator_torque × ω_ground
  P_rope_net  = Σ rope torques×ω (compute_rope_forces!, includes tether drag)
Compare P_aero_total against the settle scan's own estimate at the same ω. =#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0; const PW = 5000.0; const DT = 4e-5
p = mass_scale(params_10kw(), 10.0, KW)
x = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), String)), ",")]
x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
lift = rotary_lifter_default()

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
sys.k_mppt_ref[] = p.k_mppt

gnd_gid = sys.ring_ids[1]
gnd_ri = (sys.nodes[gnd_gid]::RingNode).ring_idx
hub_ri = (sys.nodes[sys.rotor.node_id]::RingNode).ring_idx

println("t(s)   ω_hub  ω_gnd  P_aero_hub P_aero_exp  P_gen    P_net_rope")
println("─"^72)
for chunk in 1:12
    run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
    t = chunk * 5.0

    N = sys.n_total; Nr = sys.n_ring
    omega = u[(6N + Nr + 1):(6N + 2Nr)]
    alpha = u[(6N + 1):(6N + Nr)]
    ω_hub = omega[hub_ri]
    ω_gnd = omega[gnd_ri]

    # ── Aero + gen torques (fresh accumulators) ────────────────────────
    forces_a = [zeros(3) for _ in 1:N]
    torques_a = zeros(Nr)
    compute_ring_forces!(forces_a, torques_a, u, omega, sys, p, wind_fn, t, lift, nothing)

    τ_gen, _ = get_generator_torque(u, sys, p, t, wind_fn; brake_engaged=sys.brake_engaged[])
    # compute_ring_forces! adds τ_gen negatively to the ground ring (verify sign):
    # τ_aero[ri] = torques_a[ri] − (−τ_gen at gnd)  → torques_a[gnd_ri] + τ_gen
    τ_aero = copy(torques_a)
    τ_aero[gnd_ri] += τ_gen

    P_aero_total = sum(τ_aero[ri] * omega[ri] for ri in 1:Nr)
    P_aero_exp = sum((ri == hub_ri ? 0.0 : τ_aero[ri] * omega[ri]) for ri in 1:Nr)
    P_aero_hub = τ_aero[hub_ri] * ω_hub
    P_gen = τ_gen * ω_gnd

    # ── Rope torques (includes tether drag) ─────────────────────────────
    forces_r = [zeros(3) for _ in 1:N]
    torques_r = zeros(Nr)
    compute_rope_forces!(forces_r, torques_r, u, alpha, sys, p, wind_fn, t, zeros(3), zeros(3))
    P_rope_net = sum(torques_r[ri] * omega[ri] for ri in 1:Nr)

    @printf("%4.1f  %6.2f  %6.2f  %8.0f  %8.0f  %7.0f  %9.0f\n",
        t, ω_hub, ω_gnd, P_aero_hub, P_aero_exp, P_gen, P_rope_net)
end
