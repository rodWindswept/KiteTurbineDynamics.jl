# scratch/av_probe_thread_ab.jl — projection-threading A/B receipt (2026-10-07)
#
# Same construction as the two moved test fixtures:
#   A. the island-3 winner decode (test_betz_ceiling_projection.jl testset 4)
#   B. the TRPT realisability fixture SEED_LR20 (test_trpt_realisability.jl section A)
# Run in the PRE-CUT tree (7c9f4b9) and the CUT tree; the outputs must reproduce
# the old pins and the new pins to the digit, and the span ratios must equal the
# closed forms: full f = 0.6518052428788816 (1/sqrt = 1.238628519015731),
# elev-only f = 0.6830559343836802 (1/sqrt = 1.209962966766535).
#
# USAGE: scripts/ktd-julia scratch/av_probe_thread_ab.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
const ROOT = dirname(@__DIR__)
include(joinpath(ROOT, "scripts", "ode_gate_v13.jl"))
include(joinpath(ROOT, "test", "settle_case_builders.jl"))

println("tree: ", chomp(read(`git -C $ROOT rev-parse --short HEAD`, String)))

# ── A. island-3 (bank-derate) winner decode ──────────────────────────────────
const WINNER_CSV = joinpath(
    ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv",
)
x = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]
d = decode_winner(x; L=18.8, KW=5.0)
sys, _u0, _pc = KTD.build_system_from_v10(
    d.dec, 1.0, d.k_mp; tether_diameter=d.p.tether_diameter, base_params=d.p,
)
r = sys.rotor
spanA = r.radius - r.blade_hub_radius
rawA = KTD.main_rotor_swept_area(sys)
A_znA = KTD.betz_wind_normal_area(sys, d.p)
@printf("A radius=%.12f\n", r.radius)
@printf("A hub=%.12f\n", r.blade_hub_radius)
@printf("A span=%.12f\n", spanA)
@printf("A raw=%.12f\n", rawA)
@printf("A rawce=%.12f\n", rawA * cos(d.p.elevation_angle))
@printf("A A_zn=%.12f\n", A_znA)
@printf("A ceil_raw=%.12f\n", 0.593 * 0.5 * d.p.rho * rawA * 11.0^3 / 1000.0)
@printf("A ceil_zn=%.12f\n", 0.593 * 0.5 * d.p.rho * A_znA * 11.0^3 / 1000.0)
fA = cosd(r.bank_angle_deg)^2.65 * cos(d.p.elevation_angle)^2.65
if isdefined(KTD.BEM, :projection_factor)
    fh = KTD.BEM.projection_factor(r.bank_angle_deg, d.p.elevation_angle)
    @printf("A helper_minus_closedform=%.3e\n", fh - fA)
end
@printf("A f_full=%.15f 1/sqrt=%.15f\n", fA, 1 / sqrt(fA))
@printf("A span_ratio_vs_oldpin=%.15f (old pin span 1.043269008805236)\n",
    spanA / 1.043269008805236)

# ── B. TRPT realisability fixture (SEED_LR20) ────────────────────────────────
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const OMEGA_SEED = 12.983466
p_fixture = override_params(params_5kw_188(); back_anchor_fwd_x=6.901)
sys2, u02, pc2, lift2, wf2 = build_case(nothing, nothing; genome=SEED_LR20, p=p_fixture)
spanB = sys2.rotor.radius - sys2.rotor.blade_hub_radius
@printf("B radius=%.10f\n", sys2.rotor.radius)
@printf("B hub=%.10f\n", sys2.rotor.blade_hub_radius)
@printf("B span=%.12f\n", spanB)
@printf("B bank=%.6f\n", sys2.rotor.bank_angle_deg)
F_ax = design_axial_preload(
    sys2, pc2, lift2, u02; omega_eq=OMEGA_SEED, realisability_margin=1.0,
)
τ_eq = sys2.k_mppt_ref[] * OMEGA_SEED^2
r2 = trpt_matched_place(
    sys2, pc2, F_ax, τ_eq, OMEGA_SEED, wf2; raise_on_unrealisable=false,
)
@printf("B demand1=%.10f\n", r2.demand[1])
@printf("B demand4=%.10f\n", r2.demand[4])
@printf("B t7=%.10f\n", r2.τ_carry[7])
@printf("B t8=%.10f\n", r2.τ_carry[8])
@printf("B d7=%.10f\n", r2.demand[7])
@printf("B d8=%.10f\n", r2.demand[8])
@printf("B Fax=%.10f\n", F_ax[end])
@printf("B cross=%.10f\n", KTD.max_segment_cross_ratio(r2, sys2))
fB = cosd(0.0)^2.65 * cos(p_fixture.elevation_angle)^2.65
if isdefined(KTD.BEM, :projection_factor)
    fh2 = KTD.BEM.projection_factor(0.0, p_fixture.elevation_angle)
    @printf("B helper_minus_closedform=%.3e\n", fh2 - fB)
end
@printf("B f_elev=%.15f 1/sqrt=%.15f\n", fB, 1 / sqrt(fB))
println("done")
