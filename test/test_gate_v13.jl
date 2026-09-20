#!/usr/bin/env julia --project=.
#= test_gate_v13.jl — acceptance tests for the re-instrumented ODE gate
(scripts/ode_gate_v13.jl). RED on master (gate module does not exist yet),
GREEN after implementation.  Re-baselined 2026-09-04 to the corrected 5 kW
campaign: the campaign winner is VALID and must PASS the gate (the OLD
collapsing v12 winner is no longer the reference).  Standalone (not wired
into runtests.jl — it runs a 30s ODE window).

A1: the corrected 5 kW campaign winner PASSES the re-instrumented gate
    (P ≥ 5 kW, no twist crossing, clearance ≥ 1.5 m, tip sanity).
A2: the healthy winner's twist ratio stays BELOW the geometric crossing limit
    (max_twist_ratio < 1.0).  The detector's crossing logic itself is covered
    by the wound-state unit check in test_evaluator_v13.jl (B5).
A3: the detector does NOT flag the post-settle state (Δα≈0) — not always-on.
A4: reported P_gen equals τ_gen·ω_gnd recomputed via get_generator_torque.
=#

using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const PW = KW * 1000.0
const L18 = 18.8
# Corrected campaign winner (single rotor, r_hub 4.32 m, n_lines 3) — VALID.
const WINNER_CSV = joinpath(
    @__DIR__,
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount",
    "best_vector.csv",
)

failures = String[]
function check(name::String, cond::Bool)
    println((cond ? "  ✅ " : "  ❌ "), name)
    return cond || push!(failures, name)
end

println("=== A1/A2: gate the corrected campaign winner (healthy) ===")
x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
r = gate_design(x; L=L18, KW=KW)
println(
    "  verdict ok=",
    r.ok,
    "  P_gen_final=",
    round(r.P_gen_final; digits=2),
    " kW  ω_gnd_final=",
    round(r.w_gnd_final; digits=2),
    "  clearance=",
    round(r.clearance; digits=2),
    "  crossed=",
    r.crossed,
    "  max_twist_ratio=",
    round(r.max_twist_ratio; digits=2),
)
check("A1: campaign winner PASSES the re-instrumented gate", r.ok)
check(
    "A2: twist ratio stays below the crossing limit (healthy)",
    !r.crossed && r.max_twist_ratio < 1.0,
)

println("=== A3: detector must not flag the post-settle state ===")
p = params_at_length(params_daisy(), L18, KW)
xv = copy(x)
xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))   # rotor_count_mode: {1,2,3}
dec = design_from_vector_v10(
    xv,
    PROFILE_ELLIPTICAL,
    p;
    power_W=PW,
    cylinder_cone=true,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
)
sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
    dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p
)
wind_fn(r, t) = [p.v_wind_ref, 0.0, 0.0]
u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift_for(sys, pc), wind_fn=wind_fn, n_op=30_000
)
N = sys.n_total;
Nr = sys.n_ring
tr0 = twist_report(u, sys, N, Nr)
println(
    "  post-settle: crossed=", tr0.crossed, "  max_ratio=", round(tr0.max_ratio; digits=3)
)
check("A3: no flag at post-settle (Δα≈0)", !tr0.crossed && tr0.max_ratio < 1.0)

println("=== A4: P_gen == τ_gen·ω_gnd (signed) from the gate's own state ===")
# Recompute from the gate's returned final state — bit-identity regardless of
# lift device (AC-LIFT). Signed convention post-2026-08-20 (Item 2).
fin = r.trace[end]
gnd_ri = (r.sys.nodes[r.sys.ring_ids[1]]::RingNode).ring_idx
w_gnd = r.u[6 * r.N + r.Nr + gnd_ri]
tau_gen, _ = get_generator_torque(
    r.u, r.sys, p, fin.t, wind_fn; brake_engaged=r.sys.brake_engaged[]
)
P_direct = tau_gen * w_gnd / 1000.0
println(
    "  gate P_gen=",
    round(fin.P_gen; digits=3),
    " kW   direct P_gen=",
    round(P_direct; digits=3),
    " kW",
)
check(
    "A4: P_gen matches τ_gen·ω_gnd recomputation (bit-identical)",
    isapprox(fin.P_gen, P_direct; rtol=1e-9),
)

println("=== A5: a broken-line machine must hard-reject (gate bug 1, 2026-09-04) ===")
# Bug 1: the gate verdict ignored the rope-break latch, so a machine whose line
# broke during the window could still read ok.  Drive a machine whose lines
# GENUINELY break — an under-strength tether (low EA ⇒ the const-tension lift
# over-strains it) — and assert the gate rejects on the latch.
# FROZEN FIXTURE (2026-09-16, Rod).  This case must NOT track the campaign seed:
# the diameter below is TUNED, so re-seeding silently detunes the test.  That is
# exactly what happened on the L/r 2.0 -> 1.5 re-seed (commit 04a31bf): at the
# old 0.00025 the built 0.456 mm line peaked at 0.0225 per-line strain, under the
# 3.5 % limit, so it stopped breaking and A5's premise evaporated — leaving the
# gate-bug guard silently unexercised.  Values are literal so a change in
# `params_daisy`/DAISY scaling cannot move them.
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
#
# Diameter re-calibrated on this fixture (measured sweep, 5 s window, break
# detection ON): 0.00025 -> line_broken=false, ok=true (premise fails);
# 0.00020 -> true/false; 0.00016 -> true/false; 0.00012 -> true/false.
# 0.00016 is chosen for margin inside that band.  mass_scale multiplies it by
# sqrt(5/1.5) ≈ 1.826, so the BUILT diameter is ~0.292 mm (EA ≈ 6.7 kN), at which
# the operational tension reaches 3.5 % strain and the line genuinely snaps.
#
# RE-BASELINED 2026-09-20 (taut load split + geometric crossing floor).  Thinning
# the line no longer works at all: a thin line resists less pretension, so the
# crossing floor demands a larger preload raise and the 1.5x
# TRPT_REALISABILITY_MAX_PRELOAD_FACTOR cap REFUSES the design (measured: every
# diameter 0.00016-0.00090 is refused, or settles without breaking).  Because the
# design tension scales with EA while ROPE_BREAK_STRAIN is a fixed geometric
# ratio, no diameter both clears the floor and snaps.
#
# Use the precedent recorded in `DECISIONS.md` [2026-09-11] §3 (line 734) instead:
# keep the STANDARD diameter and lower `e_modulus`.  The machine's mass, chord,
# tube wall and placement geometry stay physical; the line is merely more elastic,
# so it settles cleanly under the crossing floor and still strains past the 3.5 %
# SK99 limit once the 5 kW window loads it.
p_break = override_params(params_daisy(); e_modulus=0.7e9)
rb = gate_design(SEED_LR15_FROZEN; L=L18, KW=KW, p2=p_break)
println(
    "  break-fixture gate: ok=",
    rb.ok,
    "  line_broken=",
    rb.line_broken,
    "  P_gen_final=",
    round(rb.P_gen_final; digits=2),
    " kW",
    "  ω_gnd=",
    round(rb.w_gnd_final; digits=2),
    "  clearance=",
    round(rb.clearance; digits=2),
    " m",
)
check(
    "A5: the broken machine's power/ω/clearance alone would pass the gate",
    rb.P_gen_final >= MIN_P_GEN_KW &&
        rb.w_gnd_final > MIN_W_GND &&
        rb.clearance >= MIN_CLEARANCE,
)
# PRECONDITION FIRST.  If the fixture stops breaking, fail HERE with a clear
# message instead of letting the checks below pass vacuously against a machine
# that never broke — the silent detune that hid this guard before.
check("A5: the line ACTUALLY broke (fixture precondition)", rb.line_broken)
check("A5: the rope-break latch is set", rb.line_broken)
check("A5: the gate rejects the broken-line machine", !rb.ok)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
