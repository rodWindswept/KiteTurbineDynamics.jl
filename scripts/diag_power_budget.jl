#!/usr/bin/env julia --project=.
#= ⚠️ SUPERSEDED 2026-08-13 — do NOT re-run or trust output.
Two-call difference method is CONTAMINATED: compute_rope_forces! uses
wind_fn (src/rope_forces.jl:246), so "zero wind" does not zero rope drag
and the subtraction blows up (residuals 10⁷–10⁸ W observed).
Use scripts/diag_power_budget2.jl (direct calls to the same functions the
ODE uses) — that produced the authoritative ω_gnd decoupling finding.

Historical purpose below — find the missing ~3 kW in the ODE at 5kW steady
state. Two-call difference method:
  du_full   = multibody_ode! with real wind
  du_nowind = multibody_ode! with zero wind (aero→0, drag/rope≈same)
  τ_aero    = (du_full − du_nowind) × I_z  per ring
  P_aero    = Σ τ_aero·ω
Compare against P_gen (k·ω³), net KE change, and scalar drag estimate. =#

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
spoke = nothing

u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
N = sys.n_total; Nr = sys.n_ring
sys.k_mppt_ref[] = p.k_mppt

# Ring inertias + node ids
I_z = [sys.nodes[sys.ring_ids[i]].inertia_z for i in 1:Nr]

println("t(s)     ω_hub   P_gen   P_aero_ode  P_net   P_drag_est  residual")
println("─"^72)
for chunk in 1:12
    run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
    t = chunk * 5.0

    # Two-call difference
    du_full = zeros(length(u))
    multibody_ode!(du_full, u, (sys, p, wind_fn, lift, spoke), t)
    du_nowind = zeros(length(u))
    multibody_ode!(du_nowind, u, (sys, p, (r, tt) -> zeros(3), lift, spoke), t)

    omega = u[(6N + Nr + 1):(6N + 2Nr)]
    ω_hub = omega[Nr]

    P_aero = 0.0; P_net = 0.0
    for ri in 1:Nr
        τ_aero = (du_full[6N + Nr + ri] - du_nowind[6N + Nr + ri]) * I_z[ri]
        τ_full = du_full[6N + Nr + ri] * I_z[ri]
        P_aero += τ_aero * omega[ri]
        P_net  += τ_full * omega[ri]
    end
    P_gen = sys.k_mppt_ref[] * ω_hub^3 / 1.0   # W
    P_drag_est = KiteTurbineDynamics.settle_parasitic_drag_power(sys, p, ω_hub, u)
    residual = P_aero - P_gen - P_net - P_drag_est

    @printf("%4.1f  %7.2f  %6.0f  %8.0f  %7.0f  %8.0f  %8.0f\n",
        t, ω_hub, P_gen, P_aero, P_net, P_drag_est, residual)
end
