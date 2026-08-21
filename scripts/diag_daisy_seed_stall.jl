#!/usr/bin/env julia --project=.
# diag_daisy_seed_stall.jl — reproduce the Daisy-seed stall with the EXACT
# runner path (run_v13_5kw_masslift.jl mass-min config) + instrumentation:
#   - p_base params that the runner would compute (k_mppt, i_pto, tether, mass)
#   - decoded seed geometry (hub ring, annulus radii, swept area)
#   - evaluate_windowed result (status, P_mean, P_end, FoS, T_lift)
# Usage: julia --project=. scripts/diag_daisy_seed_stall.jl [length]
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 20.0
const LENGTH = length(ARGS) > 0 ? parse(Float64, ARGS[1]) : 18.8

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

# ── runner's params_at_length, copied verbatim ───────────────────────────
function params_at_length(L::Float64)
    p2 = params_10kw()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return mass_scale(SystemParams(geo, mat, aero, ctrl, back), 10.0, KW)
end

p_base = params_at_length(LENGTH)
cfg = ObjectiveConfig(;
    power_W = PW, v_rated = V_RATED,
    p_floor_kw = 5.0, p_ceiling_kw = 5.0,
    relax_s = 5.0, window_s = WINDOW_S,
    fos_target = 2.5, fos_hard = 2.5,
    power_stat = :tail5, penalize_ceiling = false,
    kickstart_s = 0.0,
    k_mppt = p_base.k_mppt,
    tether_diameter = p_base.tether_diameter,
)

seed_v = seed_genome(KW)
lo, hi = tight_bounds(seed_v, KW)
xr = clamp.(copy(seed_v), lo, hi)
xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
xr[10] = clamp(xr[10], 0.0, Float64(N_VALID_MASKS))

println("═"^70)
println("  Daisy seed stall repro  L=$(LENGTH) m")
println("═"^70)
println("p_base (runner path):")
println("  k_mppt           = $(p_base.k_mppt)  N·m·s²   (Daisy op. pt k≈0.17–0.42)")
println("  i_pto            = $(p_base.i_pto)  kg·m²")
println("  tether_diameter  = $(p_base.tether_diameter)  m   (Daisy: 0.002)")
println("  m_blade          = $(p_base.m_blade)  kg   (per blade)")
println("  m_ring           = $(p_base.m_ring)  kg")
println("  n_lines          = $(p_base.n_lines)   (Daisy: 6)")
println("  n_blades         = $(p_base.n_blades)")
println("  rotor_radius     = $(p_base.rotor_radius)  m (BEM theory)")
println("  tether_length    = $(p_base.tether_length)  m")
flush(stdout)

dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW)
println("\ndecoded seed:")
println("  r_hub=$(round(dec.design.r_hub, digits=3))  r_bottom=$(round(dec.design.r_bottom, digits=3))  " *
        "n_lines=$(dec.design.n_lines)  n_rings=$(dec.n_rings)  n_active=$(dec.n_active)")
for (i, rotor) in enumerate(dec.rotors)
    r_out = rotor.blade_tip_radius
    r_in  = rotor.blade_hub_radius
    A = π * (r_out^2 - r_in^2)
    @printf("  rotor %d: ring_idx=%d  r_out=%.3f  r_in=%.3f  annulus A=%.2f m²\n",
        i, rotor.ring_idx, r_out, r_in, A)
end
flush(stdout)

println("\nevaluate_windowed (runner path, mass_min_fitness, cold start) + ω trace...")
flush(stdout)
N_trace = Ref(0)
ω_trace = Float64[]
trace_cb = (u, t, step, ctx) -> begin
    N_trace[] += 1
    if N_trace[] % 100 == 1 || length(ω_trace) < 5
        sysc = ctx.sys
        Nr = sysc.n_ring; N = sysc.n_total
        push!(ω_trace, u[6N + Nr + 1])   # ground ring twist rate
    end
end
t0 = time()
r = KiteTurbineDynamics.evaluate_windowed(
    xr, PROFILE_ELLIPTICAL, p_base, cfg;
    start_mode = :cold,
    lift_device = lift_for,
    trace_callback = trace_cb,
    fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
)
dt = time() - t0
println("\nresult ($(round(dt, digits=1))s wall, $(N_trace[]) trace steps):")
for f in fieldnames(typeof(r))
    v = getfield(r, f)
    println("  $f = $(v isa AbstractFloat ? round(v, digits=4) : v)")
end
if !isempty(ω_trace)
    println("  ω_gnd samples (first 8): ", [round(w, digits=2) for w in ω_trace[1:min(8, end)]])
    if length(ω_trace) > 8
        println("  ω_gnd samples (last 8):  ", [round(w, digits=2) for w in ω_trace[max(1, end-7):end]])
    end
    println("  ω_gnd max = $(round(maximum(ω_trace), digits=2))  min = $(round(minimum(ω_trace), digits=2))  n = $(length(ω_trace))")
end
# Mass via the evaluator's own build chain — CORRECT base (base_params=p)
dec2 = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec2, 1.0, cfg.k_mppt; tether_diameter=cfg.tether_diameter, base_params=p_base)
m_air = KiteTurbineDynamics.expansion_airborne_mass(sys, pc)
@printf("\n  m_airborne (EVALUATOR path, base_params=p) = %.3f kg   (φ = %.3f kg/kW at 5 kW)\n", m_air, m_air / KW)

println("\nmass decomposition (pc = genome's own params):")
println("  pc.n_lines=$(pc.n_lines)  n_rings=$(pc.n_rings)  n_blades=$(pc.n_blades)")
println("  pc.m_blade=$(pc.m_blade)  m_ring=$(pc.m_ring)  tether_d= $(pc.tether_diameter)  L=$(pc.tether_length)")
m_tether = pc.n_lines * pc.tether_length * (KiteTurbineDynamics.DYNEEMA_DENSITY * π * (pc.tether_diameter / 2)^2)
m_rings = pc.n_rings * pc.m_ring
m_blades = pc.n_blades * pc.m_blade
m_exp = sum(er -> er.mass, sys.expansion_rotors; init=0.0)
@printf("  m_tether   = %.3f kg\n", m_tether)
@printf("  m_rings    = %.3f kg  (n_rings=%d × m_ring=%.3f)\n", m_rings, pc.n_rings, pc.m_ring)
@printf("  m_blades   = %.3f kg  (n_blades=%d × m_blade=%.3f)\n", m_blades, pc.n_blades, pc.m_blade)
@printf("  m_expansion= %.3f kg  (%d rotors)\n", m_exp, length(sys.expansion_rotors))
println("  m_lifter   = 5.000 kg (fixed)")
flush(stdout)

# ── Settle probe: replicate the evaluator's cold start and catch the failure ──
println("\nsettle_to_operational_state probe (evaluator path, k_mppt=$(cfg.k_mppt))...")
flush(stdout)
wf_probe(pos, t) = begin
    z = max(pos[3], 1.0)
    return [11.0 * (z / p_base.h_ref)^(1.0 / 7.0), 0.0, 0.0]
end
lift_dev = lift_for(sys, pc)
try
    u_s = KiteTurbineDynamics.settle_to_operational_state(
        sys, copy(u0), pc, 60.0; wind_fn=wf_probe, lift_device=lift_dev)
    if u_s === nothing
        println("  settle returned NOTHING")
    else
        Nr = sys.n_ring
        N = sys.n_total
        ω_set = u_s[6N + Nr + 1]
        @printf("  settle OK, pinned ω = %.3f rad/s\n", ω_set)
    end
catch e
    println("  settle THREW: $(typeof(e)): $(sprint(showerror, e)[1:min(end, 300)])")
end
println("\nDONE")
