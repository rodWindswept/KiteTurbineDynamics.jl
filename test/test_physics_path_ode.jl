#!/usr/bin/env julia --project=.
#= test_physics_path_ode.jl — acceptance guard for the ODE physics toggles.

Audit 2026-09-08, recommendation 2.  test_physics_path_guard.jl proves only that
the STATIC objective_v10 solver reads the expansion-physics toggles.  The v13
campaign never calls that solver: it scores through the ODE path of
`evaluate_windowed`.  A refactor that decoupled the ODE force kernel, or the
build, from `EXPANSION_PHYSICS` would leave the static guard green.

This test drives the live cold path twice — DEFAULT physics vs
`LEGACY_PHYSICS_PRE_2026_07_18` — on the 5 kW campaign seed, and asserts the two
results DIFFER.  It runs an ODE window, so it is acceptance class (see
test/acceptance_runtests.jl).  The window is trimmed (relax 5 s, measure 5 s) to
keep the extra acceptance worker cheap; the settle is the dominant cost.

P1: the seed is healthy under DEFAULT physics (status :ok, finite fitness).
P2: LEGACY physics changes the ODE result — the toggles reach the live path.

NOTE: every evaluation lives in a FUNCTION.  A bare top-level `try` block
soft-scopes its assignments, so `default_result` would stay `nothing` while the
run silently succeeded (Julia soft-scope rule; same trap documented in
test/acceptance_runtests.jl).
=#

using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

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

lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)

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
    relax_s=5.0,
    window_s=5.0,
)

const X = seed_genome(KW)
const P = params_at_length(L18)

function run_eval()
    return KiteTurbineDynamics.evaluate_windowed(
        X,
        PROFILE_ELLIPTICAL,
        P,
        CFG;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=KiteTurbineDynamics.appropriate_mass_fitness,
    )
end

"""Evaluate under the CURRENT physics flags.  Returns (result, threw)."""
function evaluate_current()
    try
        return run_eval(), false
    catch err
        println("  evaluation threw: ", sprint(showerror, err)[1:min(end, 200)])
        return nothing, true
    end
end

"""Evaluate under LEGACY physics, restoring the previous flags afterwards."""
function evaluate_legacy()
    prev = expansion_physics()
    try
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        return evaluate_current()
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

println("=== P1: DEFAULT physics — the seed is healthy on the live ODE path ===")
default_result, default_threw = evaluate_current()
report("default", default_result)
check(
    "P1: seed is healthy under DEFAULT physics (status :ok, finite fitness)",
    !default_threw &&
        default_result !== nothing &&
        default_result.status === :ok &&
        isfinite(default_result.fitness),
)

println("=== P2: LEGACY physics must change the live ODE result ===")
legacy_result, legacy_threw = evaluate_legacy()
report("legacy ", legacy_result)

differ =
    legacy_threw || (
        legacy_result !== nothing &&
        default_result !== nothing &&
        (
            legacy_result.status !== default_result.status ||
            legacy_result.fitness != default_result.fitness
        )
    )
check("P2: LEGACY physics changes the ODE result (toggles reach the live path)", differ)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
