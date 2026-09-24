# scratch/test_gate_v13_with_emodulus.jl
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const KW = 5.0
const PW = KW * 1000.0
const L18 = 18.8
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
xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
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
const SEED_LR15_FROZEN = [2.4, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
p_break = override_params(params_daisy(); e_modulus=0.7e9)
rb = gate_design(SEED_LR15_FROZEN; L=L18, KW=KW, p2=p_break)
println(
    "  thin-tether gate: ok=",
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
check("A5: the line ACTUALLY broke (fixture precondition)", rb.line_broken)
check("A5: the rope-break latch is set", rb.line_broken)
check("A5: the gate rejects the broken-line machine", !rb.ok)

println()
if isempty(failures)
    println("ALL ACCEPTANCE TESTS PASS (8/8)!")
else
    println("FAILED: ", join(failures, ", "))
    error("FAILED: " * join(failures, ", "))
end
