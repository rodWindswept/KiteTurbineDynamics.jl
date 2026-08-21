#!/usr/bin/env julia --project=.
#=
diag_5kw_ode_gate.jl — ODE-based fitness for 5kW genomes.
Tests the seed + perturbed variants to check consistency.

Usage: julia --project=. scripts/diag_5kw_ode_gate.jl
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const DT = 4e-5
const N_STEPS = 125_000  # 5 s ODE window (fast diagnostic)

function ode_fitness(x::Vector{Float64})
    p = mass_scale(params_10kw(), 10.0, KW)
    xr = copy(x)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))
    
    dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW)
    if dec.n_active == 0
        return (status=:reject, P_kW=0.0, ω_final=0.0, mass_kg=Inf)
    end
    
    try
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
        wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
        lift = rotary_lifter_default()
        
        u = settle_to_operational_state(sys, copy(u0), pc, 9.5; lift_device=lift, wind_fn=wind_fn, n_op=30_000)
        sys.k_mppt_ref[] = p.k_mppt
        
        run_canonical_sim!(u, sys, pc, wind_fn, N_STEPS, DT; lift_device=lift, lin_damp=0.05)
        
        N = sys.n_total; Nr = sys.n_ring
        ω_final = u[6N + Nr + Nr]
        gnd_ri = (sys.nodes[sys.ring_ids[1]]::RingNode).ring_idx
        ω_gnd = u[6N + Nr + gnd_ri]
        tau_gen, _ = get_generator_torque(u, sys, p, 5.0, wind_fn; brake_engaged=sys.brake_engaged[])
        P_kW = tau_gen * max(ω_gnd, 0.0) / 1000.0   # generator-side power (ground ring)
        
        return (status = ω_final > 0.5 ? :ok : :reject,
                P_kW = P_kW, ω_final = ω_final, mass_kg = dec.design  |> d -> 0.0)  # mass not available here
    catch e
        return (status=:reject, P_kW=0.0, ω_final=0.0, mass_kg=Inf)
    end
end

# ── Test seed ────────────────────────────────────────────────────────────
println("=== 5kW ODE Gate — Seed Test ===")
seed = seed_genome(KW)
r = ode_fitness(seed)
println("Seed: status=", r.status, " P=", round(r.P_kW, digits=2), "kW ω=", round(r.ω_final, digits=2), "rad/s")

# ── Perturbation sweep ±10%, ±20% on each dimension ──────────────────
println("\n=== Consistency Check — ±10%, ±20% perturbations ===")
lo, hi = tight_bounds(seed, KW)
dims = ["Do_top","t/D","aspect","Do_exp","r_hub","r_bot","Lr","n_lines","density","mask","bank_t","bank_b","blade_scale_t","blade_scale_b"]
results = Float64[]
for i in 1:14
    for frac in [-0.2, -0.1, 0.1, 0.2]
        xp = copy(seed)
        delta = frac * seed[i]
        if i == 8  # n_lines: integer perturbation
            xp[i] = Float64(round(Int, clamp(seed[i] + round(Int, delta), 3, 16)))
        else
            xp[i] = clamp(seed[i] + delta, lo[i], hi[i])
        end
        rp = ode_fitness(xp)
        push!(results, rp.P_kW)
        mark = rp.status == :ok ? "✓" : "✗"
        dir = frac > 0 ? "+" : ""
        @printf("  %s %s %s%d%%  P=%.2fkW  ω=%.2f\n", mark, dims[i], dir, round(Int,frac*100), rp.P_kW, rp.ω_final)
    end
end

n_ok = count(r -> r > 0.5, results)
n_total = length(results)
println("\n$(n_ok)/$(n_total) variants produced power > 0.5kW")
println("P range: [$(round(minimum(results),digits=2)), $(round(maximum(results),digits=2))] kW")
println("P mean: $(round(mean(results),digits=2)) kW")
