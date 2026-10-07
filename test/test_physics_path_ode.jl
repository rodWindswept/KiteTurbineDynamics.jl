#!/usr/bin/env julia --project=.
#= test_physics_path_ode.jl — acceptance guard for the ODE physics toggles.

Audit 2026-09-08, recommendation 2.  test_physics_path_guard.jl proves only that
the STATIC objective_v10 solver reads the expansion-physics toggles.  The v13
campaign never calls that solver: it scores through the ODE path of
`evaluate_windowed`.  A refactor that decoupled the ODE force kernel, or the
build, from `EXPANSION_PHYSICS` would leave the static guard green.

This test drives the live cold path twice — DEFAULT physics vs
`LEGACY_PHYSICS_PRE_2026_07_18` — on the 5 kW campaign seed, and since the
2026-10-07 leg follow-up it drives the same pair again on the frozen pre-fold
genome.  It runs ODE windows, so it is acceptance class (see
test/acceptance_runtests.jl).  The window is trimmed (relax 5 s, measure 5 s)
to keep the extra acceptance worker cheap; the settle is the dominant cost.
P2 now spends four windows per acceptance pass.

P1: the seed is healthy under DEFAULT physics (status :ok, finite fitness).
P2: the EXPANSION_PHYSICS toggles reach the live ODE path — GENOME-AWARE as of
the 2026-10-07 re-pin (work-division §7 row 11; fold ruling [2026-10-05],
DECISIONS.md — the 5 kW seed folds to the S2 class).  The toggles have live
consumers at expansion-rotor sites only, so the assertion follows the decoded
machine, and both sides are recorded here side by side:
  - machine carries expansion rotors (pre-fold): LEGACY must CHANGE the
    result.  Measured at f9f3182: 3.567 vs 6.773 kW; at a82cafd: 3.262 vs
    5.337 kW.
  - zero expansion rotors (the fold seed: 1 rotor / 9 rings): LEGACY must be
    an explicit no-op — every field of the result identical.  Measured at
    bd5114e: ok 5.394 kW / FoS 5.59; at a76c5e9: ok 6.187 kW / FoS 13.505,
    legacy coincident at both (logs sv_repin_solo_test_physics_path_ode_a76c5e9
    and sv_repin_premise_gate_a76c5e9 in the shared depot; attribution table in
    docs/validation/2026-10-07-acceptance-repoint-fold-tip.md).
The branch is chosen by the DECODED expansion-rotor count, so the check
re-arms by itself whenever a future seed proposes expansion rotors — never
deleted, never statically pinned.  The KEY itself is controlled on both sides
so a mis-key cannot pass by guarding nothing: the pre-fold genome (parsed from
SEED_LR15_FROZEN in test_gate_v13.jl — no hand-typed digits) must read > 0,
and the fold seed's digits (frozen below at the re-pin — never the live
seed_genome(5.0), which would red on re-arm day) must read 0.  Both controls
are static decodes pinning the branch's own contract, key > 0 / key == 0.
At the tip the live seed takes the no-op arm, so P2 also runs a PRE-FOLD LEG:
the same branch function on the frozen pre-fold genome, one default/legacy
pair, so the differ arm executes end to end on every acceptance pass
(reference: reject 4.292 kW / FoS 12.876 vs ok 8.762 kW / FoS 4.881, twelve
full-surface diffs — W5 rehearsal, same src).

NOTE: every evaluation lives in a FUNCTION.  A bare top-level `try` block
soft-scopes its assignments, so `default_result` would stay `nothing` while the
run silently succeeded (Julia soft-scope rule; same trap documented in
test/acceptance_runtests.jl).
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
# Single-authority campaign decode (its CLI is guarded and stays inert) — the
# P2 re-arm key below decodes the seed through the SAME knob set the evaluator
# uses (2026-10-07 re-pin; same include pattern as test_winner_decode_invariant.jl).
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const L18 = 18.8

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    return cond || push!(failures, name)
end

# Campaign base params: Daisy 1.5 kW anchor scaled to 5 kW, final length restored.
function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = KiteTurbineDynamics.GeometrySpec(
        p2.elevation_angle,
        p2.lifter_elevation,
        p2.rotor_radius,
        L,
        p2.trpt_hub_radius,
        p2.trpt_rL_ratio,
        p2.n_lines,
        p2.n_rings,
        p2.n_blades,
    )
    mat = KiteTurbineDynamics.MaterialSpec(
        p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade
    )
    aero = KiteTurbineDynamics.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = KiteTurbineDynamics.BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

# Campaign mass-aware constant-tension lift — now taken from the ode_gate_v13.jl
# include above (single authority; this file used to mirror the definition,
# which would now collide with the include).

const X = seed_genome(KW)
const P = params_at_length(L18)

const CFG = ObjectiveConfig(;
    power_W=KW * 1000.0,
    p_floor_kw=KW,
    p_ceiling_kw=KW,
    fos_target=2.5,
    fos_hard=2.5,
    power_stat=:tail5,
    k_mppt=K_MPPT_5KW_HONEST,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    # Rod 2026-09-16: align the config's tether with the rung-scaled params.
    # `cfg.tether_diameter` drives BOTH the design MaterialSpec
    # (objective_evaluator.jl:429) and the ODE build (:559), while `P` carries
    # the scaled 0.003651 m.  Leaving this at the 0.003 default sized the beam
    # tube and the dynamic line for two DIFFERENT stiffnesses: the closed-form
    # FoS was computed against the thinner line.  This is the same alignment
    # the sizing-margin probe makes.
    tether_diameter=P.tether_diameter,
    relax_s=5.0,
    window_s=5.0,
)

function run_eval(genome)
    return KiteTurbineDynamics.evaluate_windowed(
        genome,
        PROFILE_ELLIPTICAL,
        P,
        CFG;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=KiteTurbineDynamics.appropriate_mass_fitness,
    )
end

"""Evaluate a genome under the CURRENT physics flags.  Returns (result, threw)."""
function evaluate_current(genome)
    try
        return run_eval(genome), false
    catch err
        println("  evaluation threw: ", sprint(showerror, err)[1:min(end, 200)])
        return nothing, true
    end
end

"""Evaluate a genome under LEGACY physics, restoring the previous flags afterwards."""
function evaluate_legacy(genome)
    prev = expansion_physics()
    try
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        return evaluate_current(genome)
    finally
        set_expansion_physics!(prev)   # never leak LEGACY into the process
    end
end

function report(tag::String, r)
    r === nothing && return nothing
    @printf(
        "  %s status=%s  fitness=%.3f  P_mean=%.3f kW  FoS_min=%.3f\n",
        tag,
        r.status,
        r.fitness,
        r.P_mean,
        r.FoS_min
    )
end

"""Every field of the evaluation result, compared field-by-field (re-pin
2026-10-07).  `isequal` per field: on a zero-expansion machine the LEGACY
toggles must be inert, so both results must agree on the FULL surface — all
`ObjectiveResult` fields, not just the four summary columns — the shape that
catches a hidden toggle consumer later."""
function surface_diffs(a, b)
    if a === nothing || b === nothing
        return ["missing result (default: $(a === nothing), legacy: $(b === nothing))"]
    end
    typeof(a) === typeof(b) || return ["result type differs: $(typeof(a)) vs $(typeof(b))"]
    diffs = String[]
    for f in fieldnames(typeof(a))
        va, vb = getfield(a, f), getfield(b, f)
        isequal(va, vb) || push!(diffs, string(f, ": ", va, " vs ", vb))
    end
    return diffs
end

"""Count the expansion rotors the campaign decode + build give a genome — the
P2 re-arm key (re-pin 2026-10-07; genome-argument since the both-controls pin,
so ONE copy drives the branch read and both controls).  `decode_winner`
mirrors the campaign evaluator; the build call is the same shape as
test_winner_decode_invariant.jl."""
function decoded_expansion_rotor_count(X)
    d = decode_winner(X; L=L18, KW=KW)
    sys, _u0, _pc = KiteTurbineDynamics.build_system_from_v10(
        d.dec, 1.0, d.k_mp; tether_diameter=d.p.tether_diameter, base_params=d.p
    )
    return length(sys.expansion_rotors)
end

"""Positive-control genome for the P2 re-arm key: the pre-fold genome, parsed
from the committed constant `SEED_LR15_FROZEN` in test/test_gate_v13.jl — no
hand-typed digits (the same parse the W5 rehearsal uses).  It decodes to
3 rotors / 2 expansion rotors / 13 rings and the key must read > 0."""
function pre_fold_genome()
    src = read(joinpath(@__DIR__, "test_gate_v13.jl"), String)
    m = match(r"const SEED_LR15_FROZEN = \[([^\]]+)\]", src)
    m === nothing && error("SEED_LR15_FROZEN not found in test/test_gate_v13.jl")
    X = parse.(Float64, strip.(split(m.captures[1], ",")))
    length(X) == 10 || error("SEED_LR15_FROZEN must be 10-D")
    return X
end

const X_PRE_FOLD = pre_fold_genome()

# Negative-control genome for the P2 re-arm key: the fold seed's digits frozen
# at the re-pin (2026-10-07).  Source: `seed_genome(5.0)` — byte-identical to
# S2_FOLD_SEED (scripts/compute_seeds.jl, added in bd5114e).  Frozen ON
# PURPOSE; do NOT replace with the live seed_genome(5.0): on the day a future
# seed carries expansion rotors the key reads > 0 on it *correctly*, and a
# live-seed control would then red a working machine.  The frozen digits
# cannot move (placement facts), so this arm survives the reversal recipe too.
const SEED_5KW_FOLD_FROZEN = [
    4.32,                  # r_hub — pinned to the old box ceiling (the fold point)
    0.7968682519739593,    # r_bottom
    2.0999999999999996,    # target_Lr
    3.0,                   # n_lines
    0.22525551607801375,   # density_profile
    1.26727299084247,      # rotor-count gene (decodes to 1 active rotor)
    10.739909223435728,    # bank_top (°)
    7.182981922129365,     # bank_bottom (°)
    1.0,                   # blade_scale_top — pinned to the 1.0 hard cap
    1.0,                   # blade_scale_bottom
]

"""The P2 branch — ONE copy, called by the live path and by the pre-fold leg
(leg follow-up, 2026-10-07).  It decodes the genome's expansion-rotor count and
asserts the arm's contract: expansion rotors present → LEGACY must CHANGE the
ODE result; zero expansion rotors → LEGACY must be an explicit no-op across
the FULL result surface.  `tag` names the caller in every check line, so a red
names its run."""
function assert_p2_branch(
    tag::String, genome, default_result, default_threw, legacy_result, legacy_threw
)
    n_expansion = decoded_expansion_rotor_count(genome)
    println("  [", tag, "] re-arm key: decoded expansion rotors = ", n_expansion)
    if n_expansion > 0
        # Pre-fold branch (re-arms with the machine): expansion rotors give the
        # toggles live consumers, so LEGACY must change the result.
        differ =
            legacy_threw || (
                legacy_result !== nothing &&
                default_result !== nothing &&
                (
                    legacy_result.status !== default_result.status ||
                    legacy_result.fitness != default_result.fitness ||
                    # R7 (2026-09-10): under LEGACY physics both paths may reject, so
                    # status+fitness alone are not discriminating.  The measured window
                    # statistics are — LEGACY gives P_mean = 0 while DEFAULT sustains.
                    legacy_result.P_mean != default_result.P_mean ||
                    legacy_result.FoS_min != default_result.FoS_min
                )
            )
        # Evidence line for the leg: the W5 rehearsal measured twelve moving
        # fields on the pre-fold machine, so the count stays comparable here.
        diffs = surface_diffs(default_result, legacy_result)
        println(
            "  [",
            tag,
            "] full-surface diffs: ",
            isempty(diffs) ? "none" : string(length(diffs), " fields move"),
        )
        check(
            "P2 [$tag]: LEGACY physics changes the ODE result (toggles reach the live path)",
            differ,
        )
    else
        # Fold branch: zero expansion rotors — the toggles are provably inert, so
        # assert the explicit no-op across the FULL result surface instead of
        # deleting the check.
        diffs = String[]
        default_threw && push!(diffs, "default evaluation threw")
        legacy_threw && push!(diffs, "legacy evaluation threw")
        append!(diffs, surface_diffs(default_result, legacy_result))
        isempty(diffs) || println("  [", tag, "] no-op diffs: ", join(diffs, "; "))
        check(
            "P2 [$tag]: zero-expansion machine — LEGACY physics is an explicit no-op (every result field identical)",
            isempty(diffs),
        )
    end
    return nothing
end

# Both-controls pin: the branch goes green on whichever arm the key
# picks, so a mis-keyed predicate would pass by guarding nothing.  Assert the
# predicate itself on two frozen machines — true on the pre-fold genome, false
# on the frozen fold seed.  Static decodes only (no ODE), so a mis-key reds
# early, at the predicate rather than downstream.
println("=== P2 controls: the re-arm key itself, both frozen machines (static; no ODE) ===")
k_pre = decoded_expansion_rotor_count(X_PRE_FOLD)
d_pre = decode_winner(X_PRE_FOLD; L=L18, KW=KW)
println(
    "  pre-fold genome (SEED_LR15_FROZEN, parsed):  key = ",
    k_pre,
    "   [rotors=",
    length(d_pre.dec.rotors),
    ", expansion=",
    k_pre,
    ", rings=",
    d_pre.dec.n_rings,
    "]",
)
check(
    "P2 control: pre-fold genome reads key > 0 (expansion rotors present — differ arm re-arms)",
    k_pre > 0,
)
k_fold = decoded_expansion_rotor_count(SEED_5KW_FOLD_FROZEN)
d_fold = decode_winner(SEED_5KW_FOLD_FROZEN; L=L18, KW=KW)
println(
    "  fold-seed digits (frozen 2026-10-07):          key = ",
    k_fold,
    "   [rotors=",
    length(d_fold.dec.rotors),
    ", expansion=",
    k_fold,
    ", rings=",
    d_fold.dec.n_rings,
    "]",
)
check(
    "P2 control: frozen fold-seed digits read key == 0 (zero expansion rotors — no-op arm)",
    k_fold == 0,
)

println("=== P1: DEFAULT physics — the seed is healthy on the live ODE path ===")
default_result, default_threw = evaluate_current(X)
report("default", default_result)
check(
    "P1: seed is healthy under DEFAULT physics (status :ok, finite fitness)",
    !default_threw &&
        default_result !== nothing &&
        default_result.status === :ok &&
        isfinite(default_result.fitness),
)

println("=== P2: LEGACY physics vs the live ODE path (genome-aware re-pin 2026-10-07) ===")
legacy_result, legacy_threw = evaluate_legacy(X)
report("legacy ", legacy_result)
assert_p2_branch("live", X, default_result, default_threw, legacy_result, legacy_threw)

println(
    "=== P2 leg: the differ arm executes — the frozen pre-fold genome through the same branch (2026-10-07) ===",
)
pre_default_result, pre_default_threw = evaluate_current(X_PRE_FOLD)
report("pre-fold default", pre_default_result)
pre_legacy_result, pre_legacy_threw = evaluate_legacy(X_PRE_FOLD)
report("pre-fold legacy ", pre_legacy_result)
assert_p2_branch(
    "pre-fold leg",
    X_PRE_FOLD,
    pre_default_result,
    pre_default_threw,
    pre_legacy_result,
    pre_legacy_threw,
)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
