# scratch/spec_seed_candidate.jl
#
# SUPERSEDED 2026-09-14: this probe's screening (the candidate is viable) and its
# bank-angle isolation (0/11/22° all viable) still hold, and the candidate is
# recorded in DECISIONS.md [2026-09-14] and scripts/compute_seeds.jl.  Its
# follow-on conclusion "the candidate disconnects the lift chain so cannot land"
# was WRONG-CAUSED: the disconnection came from the back-line rest length
# (bearing_offset 6.0 → 3.99 in ring_forces.jl), now fixed by deriving the offset
# from the top-ring radius.
#
# Purpose (2026-09-13, DSH session; Rod's request): the current 5 kW seed is not
# viable under the corrected physics — the evaluator rejects it with
# `twist_crossed=true`, which is what makes test_evaluator_v13 B3 and
# test_physics_path_ode P1/P2 red.  Re-seeding from the campaign winner is NOT
# acceptable: the winner is a 3-line/1-rotor machine and the 3-rotor/6-line seed
# exists deliberately so multi-rotor assessment is exercised.  Rod's spec:
#   * keep 3 rotors / 6 lines,
#   * keep genes AWAY FROM BOUNDS ("middle of the road"),
#   * must be viable.
#
# This script (a) prints the canonical 10-D spec — each gene's position within its
# `tight_bounds` range, flagging anything at a bound — and (b) screens a few
# candidates through the SAME evaluator the campaign and B3 use, then confirms the
# best at the full 30 s window.
#
# Screening uses a 10 s window for speed; the confirm step uses 30 s to match B3.
#
# Self-checking: asserts the seed is 10-D, that the candidate that claims to keep
# the architecture really decodes to n_lines=6 / 3 rotors, and that the reported
# per-segment demand is the max over a non-empty vector.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))  # params_at_length, lift_for

const KW = 5.0
const L18 = 18.8
const PW = 5000.0

const NAMES10 = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile",
    "rotor_count", "bank_top", "bank_bottom", "blade_scale_top", "blade_scale_bottom"]

seed0 = seed_genome(KW)
@assert length(seed0) == KiteTurbineDynamics.TRPT_V10_DIM
lo, hi = tight_bounds(seed0, KW)

println("=== canonical 10-D spec: current seed vs its tight bounds ===")
println(lpad("gene", 20), lpad("seed", 10), lpad("lo", 9), lpad("hi", 9), lpad("pos", 7), "  flag")
for i in 1:10
    pos = (seed0[i] - lo[i]) / (hi[i] - lo[i])
    flag = (pos <= 0.10 || pos >= 0.90) ? "<-- AT BOUND" :
           (pos <= 0.20 || pos >= 0.80) ? "<- near bound" : ""
    println(lpad(NAMES10[i], 20), lpad(round(seed0[i]; digits=4), 10),
        lpad(round(lo[i]; digits=3), 9), lpad(round(hi[i]; digits=3), 9),
        lpad(round(pos; digits=3), 7), "  ", flag)
end

cfg(window_s) = KiteTurbineDynamics.ObjectiveConfig(;
    k_mppt=K_MPPT_5KW_HONEST, power_W=PW, v_rated=11.0,
    p_floor_kw=5.0, p_ceiling_kw=5.0, relax_s=5.0, window_s=window_s,
    fos_target=2.5, fos_hard=2.5, power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0, rotor_count_mode=true, power_split=0.6,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)

function decode(x10)
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    p = params_at_length(params_daisy(), L18, KW)
    return p, KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=PW, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW)
end

function run_eval(x, window_s)
    p = params_at_length(params_daisy(), L18, KW)
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    return KiteTurbineDynamics.evaluate_windowed(xr, PROFILE_ELLIPTICAL, p, cfg(window_s);
        start_mode=:cold, lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m))
end

"""Leading-indicator realisability demand at the evaluator's own operating ω."""
function demand_at(x, ω)
    p, dec = decode(x)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg(10.0))
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, pc)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    F = design_axial_preload(sys, pc, lift, u0;
        omega_eq=ω, wind_fn=wf, realisability_margin=1.0)
    pl = trpt_matched_place(sys, pc, F, sys.k_mppt_ref[] * ω^2, ω, wf;
        raise_on_unrealisable=false)
    @assert !isempty(pl.demand)
    return maximum(pl.demand), dec
end

# Candidates.  Indices: 1 r_hub, 2 r_bottom, 3 target_Lr, 4 n_lines,
# 5 density_profile, 6 rotor_count, 7 bank_top, 8 bank_bottom, 9/10 blade_scale.
mk(bank, bs, rhub; Lr=nothing) = begin
    x = copy(seed0)
    x[7] = bank
    x[8] = bank
    x[9] = bs
    x[10] = bs
    x[1] = rhub
    Lr === nothing || (x[3] = Lr)
    x
end

# ROUND 3 (Rod 2026-09-13): isolate the bank angle.  Round 2's viable candidate E
# has bank = 11 deg, which switches the banked-blade expansion behaviour back ON
# (radial spreading + expansion torque injection) — previously OFF at bank = 0.
# Question: is banking REQUIRED for viability, or incidental?  Same machine,
# three bank angles.
CANDS = [
    ("E0:  r_hub 2.6, blade 0.8, bank 0  (min bound)", mk(0.0, 0.80, 2.6)),
    ("E11: r_hub 2.6, blade 0.8, bank 11 (mid)", mk(11.0, 0.80, 2.6)),
    ("E22: r_hub 2.6, blade 0.8, bank 22 (max bound)", mk(22.0, 0.80, 2.6)),
]

println("\n=== screening (10 s window, campaign evaluator) ===")
results = Dict{String,Tuple}()
for (label, x) in CANDS
    p, dec = decode(x)
    @assert dec.design.n_lines == 6 "candidate must keep 6 lines"
    @assert dec.n_active == 3 "candidate must keep 3 rotors"
    r = run_eval(x, 10.0)
    dmax, _ = demand_at(x, max(r.ω_eq, 1.0))
    results[label] = (r, dmax)
    println("\n  ", label)
    println("    decoded: n_lines=", dec.design.n_lines, "  n_active=", dec.n_active,
            "  n_rings=", dec.n_rings, "  r_hub=", round(dec.design.r_hub; digits=2), " m")
    println("    status=", r.status, "  P_end=", round(r.P_end; digits=3), " kW",
            "  FoS_min=", round(r.FoS_min; digits=2),
            "  twist_crossed=", r.twist_crossed, "  line_broken=", r.line_broken,
            "  ω_eq=", round(r.ω_eq; digits=3))
    println("    realisability demand (unmargined) = ", round(dmax; digits=4),
            dmax < 1.0 ? "  (inside the cliff)" : "  (PAST the cliff)")
end

# Confirm the best-looking candidate at B3's full 30 s window.
viable = [(l, v) for (l, v) in results if v[1].status === :ok && v[1].P_end >= 5.0]
println("\n=== viable at 10 s: ", length(viable), " of ", length(CANDS), " ===")
if !isempty(viable)
    label, _ = viable[1]
    x = CANDS[findfirst(c -> c[1] == label, CANDS)][2]
    println("confirming at 30 s: ", label)
    r30 = run_eval(x, 30.0)
    println("  status=", r30.status, "  P_end=", round(r30.P_end; digits=3), " kW",
            "  P_mean=", round(r30.P_mean; digits=3), " kW",
            "  FoS_min=", round(r30.FoS_min; digits=2),
            "  twist_crossed=", r30.twist_crossed, "  line_broken=", r30.line_broken,
            "  fitness=", round(r30.fitness; digits=3))
    println("  canonical genome = ", x)
end
println("\n=== done ===")
