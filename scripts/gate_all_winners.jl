#!/usr/bin/env julia --project=.
#= gate_all_winners.jl — ODE-gate island-1 winner, island-3 partial, and the
original seed side by side, with per-5s power trace to expose the decay. =#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5

function gate_genome(label::String, x::Vector{Float64})
    p = mass_scale(params_10kw(), 10.0, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
    lift = rotary_lifter_default()
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
    N = sys.n_total; Nr = sys.n_ring
    ω0 = u[6N + Nr + Nr]
    sys.k_mppt_ref[] = p.k_mppt

    # 20s window with 5s checkpoints
    println("\n--- $label ---")
    println("  n_lines=", dec.design.n_lines, " rings=", dec.n_rings,
            " n_active=", dec.n_active, " r_hub=", round(dec.design.r_hub, digits=2))
    for chunk in 1:4
        run_canonical_sim!(u, sys, pc, wind_fn, round(Int, 5.0/DT), DT; lift_device=lift, lin_damp=0.05)
        ω = u[6N + Nr + Nr]
        gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
        ω_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, p, chunk * 5.0, wind_fn; brake_engaged=sys.brake_engaged[])
        P = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
        @printf("  t=%2ds: ω=%5.2f  P=%.2f kW\n", chunk*5, ω, P)
    end
    ωf = u[6N + Nr + Nr]
    gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
    ω_gnd = u[6N + Nr + gnd_ri]
    tau_gen, _ = get_generator_torque(u, sys, p, 20.0, wind_fn; brake_engaged=sys.brake_engaged[])
    Pf = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
    ok = (Pf >= 2.5) && (ωf > 0.5)
    @printf("  %s P_final=%.2f kW\n", ok ? "✅" : "❌", Pf)
    return ok
end

# Island 1 winner (-3.58)
x1 = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_1_best.csv"), String)), ",")]
# Island 3 partial best (0.84)
x3 = [parse(Float64, s) for s in split(strip(read(joinpath(@__DIR__, "results", "v12_5kw_coldstart", "island_3_best.csv"), String)), ",")]
# Original seed
xs = seed_genome(KW)

gate_genome("Island 1 winner (f=-3.58)", x1)
gate_genome("Island 3 partial (f=0.84)", x3)
gate_genome("Original seed", xs)
