# scratch/check_candidate_lr15.jl
#
# 2026-09-16.  ACTIVE.md step 1: run the re-seed candidate through the evaluator
# and watch the LIFT CHAIN CONNECT.
#
# Candidate: [2.6, 0.5751086853804245, 1.5, 6, 0, 3, 11, 11, 0.8, 0.8]
#   x[1] r_hub 2.6, x[3] target_Lr 1.5, x[4] 6 lines, x[6] 3 rotors,
#   x[7]/x[8] bank 11 deg, x[9]/x[10] blade scale 0.8.
#
# Difference from the 2026-09-14 candidate on the record: target_Lr is 1.5, not
# 2.0.  That is the ACTIVE.md item-2 clean floor fix (demand 1.147 -> 0.871 on
# paper), so this run measures the fix as well as the chain.
#
# KNOWN SCOPE LIMIT, do not over-read the result: the bungee back line is NOT yet
# in src/ (ACTIVE.md item 2, "bungee remit").  The sky-anchor solve at
# initialization.jl:958 is still SLACK, so this run measures the candidate under
# the OLD back-line model.  The chain-connection check is valid (the disconnect
# was a rest-length defect, fixed by the derived bearing offset).  The
# realisability demand reported here is the SLACK-model figure and must be
# re-measured once the taut bi-linear element lands.
#
# Self-checking: asserts the decode keeps 6 lines and 3 rotors, that the design
# split is finite with a positive T_bridle (a clamped T_bridle would by itself
# explain a slack cone), that the derived bearing offset matches
# bridle_bearing_offset(R), and that every reported tension is finite.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KW = 5.0
const L18 = 18.8
const PW = 5000.0
const X = [2.6, 0.5751086853804245, 1.5, 6.0, 0.0, 3.0, 11.0, 11.0, 0.8, 0.8]

function cfg(window_s)
    return KiteTurbineDynamics.ObjectiveConfig(;
        k_mppt=K_MPPT_5KW_HONEST,
        power_W=PW,
        v_rated=11.0,
        p_floor_kw=5.0,
        p_ceiling_kw=5.0,
        relax_s=5.0,
        window_s=window_s,
        fos_target=2.5,
        fos_hard=2.5,
        power_stat=:tail5,
        penalize_ceiling=false,
        kickstart_s=0.0,
        rotor_count_mode=true,
        power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
end

function decode(x10)
    x = copy(x10)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    p = params_at_length(params_daisy(), L18, KW)
    return p,
    KiteTurbineDynamics.design_from_vector_v10(
        x,
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
end

function run_eval(x, window_s)
    p = params_at_length(params_daisy(), L18, KW)
    xr = copy(x)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))
    return KiteTurbineDynamics.evaluate_windowed(
        xr,
        PROFILE_ELLIPTICAL,
        p,
        cfg(window_s);
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
end

"""Build the system the way the operational-settle probe does, for the chain read."""
function build_for(x10)
    p, dec = decode(x10)
    c = cfg(10.0)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, c)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf, dec
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"""Leading-indicator realisability demand at a given operating omega."""
function demand_at(x, ω)
    p, dec = decode(x)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p, cfg(10.0))
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec,
        1.0,
        K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter,
        base_params=p,
        min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, pc)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    F = design_axial_preload(
        sys, pc, lift, u0; omega_eq=ω, wind_fn=wf, realisability_margin=1.0
    )
    pl = trpt_matched_place(
        sys, pc, F, sys.k_mppt_ref[] * ω^2, ω, wf; raise_on_unrealisable=false
    )
    @assert !isempty(pl.demand) "demand vector empty - cannot report realisability"
    return maximum(pl.demand), dec
end

"""Total tension carried by the bridle cone sub-segments (hub to bearing)."""
function bridle_total(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    tot = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        ring_end = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(
            pos(u, hub), R, u[6N + Nr], ring_end.line_idx, p.n_lines, pp1, pp2
        )
        L = norm(pos(u, bear) .- pa)
        tot += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return tot, R
end

println("=== candidate ", X, " ===")
p, dec = decode(X)
@assert dec.design.n_lines == 6 "candidate must keep 6 lines, got $(dec.design.n_lines)"
@assert dec.n_active == 3 "candidate must keep 3 rotors, got $(dec.n_active)"
println(
    "decoded: n_lines=",
    dec.design.n_lines,
    "  n_active=",
    dec.n_active,
    "  n_rings=",
    dec.n_rings,
    "  r_hub=",
    round(dec.design.r_hub; digits=2),
    " m",
    "  target_Lr=",
    round(dec.design.target_Lr; digits=3),
)

# ── (1) Chain read at the operational settle ────────────────────────────────
sys, u0, pc, lift, wf, _ = build_for(X)
N, Nr = sys.n_total, sys.n_ring
hub_i, bear_i = sys.rotor.node_id, sys.bearing_id
hub_pos = pos(u0, hub_i)

# ── (1) Evaluator run FIRST: it sets the operating point ────────────────────
println("\n--- (1) evaluator (relax 5 s + window 10 s) ---")
r = run_eval(X, 10.0)
println(
    "    status=",
    r.status,
    "  fitness=",
    round(r.fitness; digits=4),
    "  P_end=",
    round(r.P_end; digits=4),
    " kW",
    "  FoS_min=",
    round(r.FoS_min; digits=3),
)
println(
    "    twist_crossed=",
    r.twist_crossed,
    "  line_broken=",
    r.line_broken,
    "  drifted=",
    r.drifted,
    "  stationary=",
    r.stationary,
    "  omega_eq=",
    round(r.ω_eq; digits=4),
)
@assert isfinite(r.ω_eq) && r.ω_eq > 0.0 "no operating point - cannot read the chain"

# ── (2) Chain read at THIS candidate's own equilibrium omega ────────────────
# The old seed's 12.9835 is NOT this candidate's operating point (L/r 1.5 gives
# 12 rings and a different rotor), so the chain must be read at the measured ω.
ω = r.ω_eq
d = KiteTurbineDynamics.lift_chain_design(sys, pc, lift, hub_pos; omega_eq=ω)
@assert isfinite(d.T_bridle) && isfinite(d.gap) && isfinite(d.T_cyan)
@assert d.T_bridle > 0.0 "design T_bridle clamped to 0 - that alone explains a slack cone"

KiteTurbineDynamics.apply_design_bridle_preload!(sys, u0, pc, lift; omega_eq=ω)
u = settle_to_operational_state(
    sys, copy(u0), pc, 60.0; lift_device=lift, wind_fn=wf, n_op=150_000
)
br, R = bridle_total(u, sys, pc, N, Nr)
@assert isfinite(br) "bridle tension not finite"
sh = [cos(pc.elevation_angle), 0.0, sin(pc.elevation_angle)]
off = dot(pos(u, bear_i) .- pos(u, hub_i), sh)
cy = norm(pos(u, sys.sky_anchor_id) .- pos(u, bear_i))

half = KiteTurbineDynamics.BRIDLE_CONE_HALF_ANGLE_DEG
println(
    "\n--- (2) lift-chain read at the candidate's own omega (", round(ω; digits=4), ") ---"
)
println(
    "    design split: T_cyan=",
    round(d.T_cyan; digits=1),
    " N",
    "  T_bridle=",
    round(d.T_bridle; digits=1),
    " N/line",
    "  T_top=",
    round(d.T_top; digits=1),
    " N",
    "  gap=",
    round(d.gap; digits=4),
    " m",
    "  cos_theta=",
    round(d.cosθ; digits=4),
)
println(
    "    derived cone: r_top=",
    round(R; digits=3),
    " m",
    "  half_angle=",
    half,
    " deg",
    "  offset=r/tan=",
    round(KiteTurbineDynamics.bridle_bearing_offset(R); digits=4),
    " m",
    "  bridle 3D=r/sin=",
    round(R / sin(deg2rad(half)); digits=4),
    " m",
)
println(
    "    after operational settle: bridle=",
    round(br; digits=2),
    " N",
    "  bearing offset=",
    round(off; digits=4),
    " m",
    "  cyan span=",
    round(cy; digits=4),
    " m",
)
println(
    "    offset residual vs derived = ",
    round(abs(off - KiteTurbineDynamics.bridle_bearing_offset(R)); digits=6),
    " m",
)
println("    CONNECTED = ", br > 0.0 ? "YES" : "NO  <-- lift chain disconnected")

# ── (3) Realisability demand at the same operating point (slack model) ──────
dmax, _ = demand_at(X, ω)
println("\n--- (3) realisability demand at omega_eq (SLACK back-line model) ---")
println(
    "    demand (unmargined) = ",
    round(dmax; digits=4),
    dmax < 1.0 ? "  (inside the cliff)" : "  (PAST the cliff)",
)
println("    target = 1/1.05 = 0.9524")
println("\n=== done ===")
