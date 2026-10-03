# sv_probe_escalation.jl — software-validator, 2026-10-01
#
# DECIDES: did `design_axial_preload`'s TRPT realisability repair fire on a given
# winner genome, and by what factor did it escalate F_top above the design preload
# the campaign regime declares (`lift_for` → 1.5·m_airborne·g/sin70°, flat)?
#
# WHY a re-derivation and not a read: `log_telemetry` (run_v13_5kw_masslift.jl:187)
# writes `x`, fitness, status and `dec` fields only — NO preload column anywhere in
# telemetry.csv — and island_N_best.csv is the bare genome vector. The escalation is
# therefore not recorded anywhere; it is recomputable, which is what this does.
#
# EXACTNESS REQUIREMENTS (all three load-bearing; src/initialization.jl line refs):
#  1. Call design_axial_preload TWICE at the SAME hub_pos: default margin (1.05,
#     const at 1690 ⇒ loop at 1614 executes) and `realisability_margin=1.0` (the
#     `> 1.0` gate skips the loop by construction ⇒ bare profile). The returned
#     profile's TOP segment IS F_top (1560: `F_ax[n_seg] = F_top`), so the ratio of
#     the two top segments is the escalation factor.
#  2. hub_pos must be the CONTRACTED placement, and it must be derived from the
#     ESCALATED F_ax_rigid — reproduce the order at 2302-2318: place FIRST from the
#     default-margin F_ax_rigid, take `hub_placed = placement.ctrs[Nr]`, then size
#     the transmission at hub_placed. Placing from the bare profile lands on a
#     different hub (docstring 2295-2305 records 172/390 N at |hub| 18.80 m raw vs
#     223/364 N at 16.97 m contracted) and reports a FALSE ratio.
#  3. omega_eq must be the settle's own. The repair loop is not a separate phase:
#     `design_axial_preload` is called from INSIDE `settle_to_operational_state`
#     (fn starts 2177; the two calls at 2303/2311 are in its body) and ω_eq there
#     comes from that function's internal speed scan. ω_eq is not persisted in
#     telemetry either, so the only exact source is a settle. Hence: one settle,
#     one genome.
#
# Also note `F_top = max(d.T_top, 20.0)` (1541): if the winner's T_top is under the
# 20 N floor the "bare" figure is the floor, not the design tension — printed below.
#
# COST: one genome, one settle — ~1-2 min single core on top of package load, against
# 3 islands × hours. Negligible contention; safe to run during the campaign.
#
# USAGE: scripts/ktd-julia scratch/sv_probe_escalation.jl [path/to/best_vector.csv]
#   (plain `julia --project=.` does not work in this sandbox — AGENTS.md)
#   Default path is the pre-derate campaign root; pass the combine's output
#   (…_rotorcount_bankderate/best_vector.csv) once the combine has fired.

using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics

const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WIND_MS = 11.0            # mirrors src/objective_evaluator.jl:77

# Same regime object the campaign passes (run_v13_5kw_masslift.jl:90-91).
lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const LENGTH = 18.8
const CSV = isempty(ARGS) ? joinpath(ROOT, "scripts", "results",
        "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv") : ARGS[1]

x = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
p = params_at_length(LENGTH)
xr = copy(x)
# LENGTH-AWARE integer-gene rounding (2026-10-02, software-validator).
# `canonical_v10` (objective_v10.jl:142-149) branches on genome LENGTH, so the
# integer positions depend on which layout the file is:
#   length(x) >= 14  LEGACY 14-D  -> n_lines x[8],  rotor count x[10]
#   length(x) == 10  CANONICAL    -> n_lines x[4],  rotor count x[6]
# Clamping the canonical pair unconditionally (as first applied) BREAKS the 14-D
# path: on the 14-field pre-derate winner it writes x[4] (legacy Do_scale_exp,
# inert) and x[6] (legacy = canonical x[2] = r_bottom), silently taking r_bottom
# from 0.8627 m to 1.0000 m.  Measured: scratch/sv_probe_decode_guard.jl.
if length(xr) >= 14
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))    # legacy n_lines
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # legacy rotor mask/count
else
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))    # canonical n_lines
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))     # canonical rotor count
end
@printf("  decode gate: %d-field genome\n", length(xr))
let c = KTD.canonical_v10(xr)
    @printf("  canonical: n_lines=%.3f rotor_count=%.3f bank_top=%.4f bank_bottom=%.4f blade_top=%.4f blade_bottom=%.4f\n",
        c[4], c[6], c[7], c[8], c[9], c[10])
end

dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p; power_W=PW,
    cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW)
sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
    tether_diameter=p.tether_diameter, base_params=p)

println("=== escalation probe — ", CSV, " ===")
@printf("  genome: %s\n", string(round.(x, digits=4)))

# Design-aware lift device: hand it `pc`, NOT `p` (objective_evaluator.jl:716-717).
lift_dev = lift_for(sys, pc)

# Same wind function as the evaluator (objective_evaluator.jl:720-723).
wf = let p_ = p
    (pos, t) -> begin
        z = max(pos[3], 1.0)
        [WIND_MS * (z / p_.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end
end

# ── ONE settle: sources ω_eq exactly the way the evaluator does ──────────────
println("  settling (single genome; ~1-2 min)…")
u_settled = KTD.settle_to_operational_state(sys, copy(u0), pc, 60.0;
    wind_fn=wf, lift_device=lift_dev)
if u_settled === nothing
    error("settle returned nothing — this genome cannot be probed; it is a reject")
end
ω_eq = u_settled[6 * sys.n_total + sys.n_ring + 1]
τ_eq = sys.k_mppt_ref[] * ω_eq^2        # 2226: same mutable-ref form the settle uses
@printf("  ω_eq = %.6f rad/s   τ_eq = %.4f N·m\n", ω_eq, τ_eq)

# ── Reproduce the order at 2302-2318 ────────────────────────────────────────
# PARAMS OBJECT (fixed 2026-10-02, aero-validator): hand `pc`, NOT the base `p`.
# `pc` carries THIS genome's n_lines/n_rings/tether_length; `p` is the shared
# base (params_daisy, n_lines = 6 — topology "does not scale").  Passing `p`
# makes `trpt_matched_place` stride `sys.sub_segs` by p.n_lines: on the 3-line
# winner it asks for index 121 of a 112-element vector and dies with a
# BoundsError.  Same rule the evaluator documents at objective_evaluator.jl:714.
u_design = copy(u0)
KTD.apply_design_bridle_preload!(sys, u_design, pc, lift_dev; omega_eq=ω_eq)

F_ax_rigid = KTD.design_axial_preload(sys, pc, lift_dev, u_design;
    omega_eq=ω_eq, wind_fn=wf)                       # default margin ⇒ escalated
placement = KTD.trpt_matched_place(sys, pc, F_ax_rigid, τ_eq, ω_eq, wf)
hub_placed = placement.ctrs[sys.n_ring]

esc = KTD.design_axial_preload(sys, pc, lift_dev, u_design;
    omega_eq=ω_eq, wind_fn=wf, hub_pos=hub_placed)                  # default margin 1.05
bare = KTD.design_axial_preload(sys, pc, lift_dev, u_design;
    omega_eq=ω_eq, wind_fn=wf, hub_pos=hub_placed, realisability_margin=1.0)

F_top_esc = esc[end]
F_top_bare = bare[end]
ratio = F_top_esc / F_top_bare

# Regime the campaign DECLARES for this genome: 1.5·m_airborne·g / sin(70°).
m_air = KTD.expansion_airborne_mass(sys, pc; include_lifter=false)
F_regime = 1.5 * m_air * 9.81 / sind(70.0)

@printf("\n  bare  F_top = %.3f N   (design preload at hub_placed)\n", F_top_bare)
@printf("  esc   F_top = %.3f N   (default margin 1.05; loop at 1614)\n", F_top_esc)
@printf("  ratio       = %.6f      → repair %s\n", ratio,
    ratio > 1.0 + 1e-9 ? "FIRED" : "did NOT fire")
@printf("  1.5 cap     = %.3f N   (TRPT_REALISABILITY_MAX_PRELOAD_FACTOR)\n",
    1.5 * F_top_bare)
@printf("  declared regime F = %.3f N  → escalated/bare-of-regime = %.6f\n",
    F_regime, F_top_esc / F_regime)
@printf("  20 N floor active? %s  (bare top is %s)\n",
    F_top_bare <= 20.0 + 1e-9 ? "YES — figure is the floor, not design tension" : "no",
    F_top_bare <= 20.0 + 1e-9 ? "at/below 20 N" : "above 20 N")

println(ratio > 1.0 + 1e-9 ?
    "\nVERDICT: the winner flies a TRPT preload above what its own lift model says — the regime claim is false for this genome." :
    "\nVERDICT: no repair; the declared flat-tension regime holds for this genome.")
