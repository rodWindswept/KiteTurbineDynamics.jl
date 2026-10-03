# scratch/hermes_probe_bank_blade_join.jl — @hermes, 2026-10-02
#
# DECIDES: does a smaller, bank-free rotor beat the banked winner in the
# campaign's score?  The winner keeps 10.74° of bank, which costs it 2–4.6% of
# power via the cos^2.65 derate, but trims it onto the 5.0 kW ceiling and dodges
# the ~0.45 kg over-power charge.  Substitute that trim physically: set
# bank_top = 0 and shrink blade_scale until the machine again sits near the
# ceiling.  Question: does that trade come out ahead of fitness 21.698287?
#
# CASES (one genome, two genes changed):
#   1. winner control            bank 10.7399°, blade 0.69945   (expect ~21.698)
#   2. bank=0, blade unchanged   bank  0.0°,    blade 0.69945   (cross-check vs
#                                aero-worker's bank-0 point — expect ~22.15)
#   3. bank=0, blade=0.69
#   4. bank=0, blade=0.68        (frontier: P ≈ 5.0 kW)
#
# INSTRUMENT: the campaign's own evaluator, copied from run_v13_5kw_masslift.jl
# and av_probe_bank_twist.jl (cold start, k = K_MPPT_5KW_HONEST, relax 10 +
# window 40 s, tail5, mass-aware constant-tension lift, FoS floor 2.5).
# twist_collapse tracked via the scoring-neutral trace_callback.
#
# USAGE: scripts/ktd-julia scratch/hermes_probe_bank_blade_join.jl

using Pkg; Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics, Printf
const KTD = KiteTurbineDynamics
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const ROOT = dirname(@__DIR__)
const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0
const LENGTH = 18.8

# ── Campaign regime, copied verbatim from run_v13_5kw_masslift.jl ────────────
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

p_base = params_at_length(LENGTH)
beam_profile = PROFILE_ELLIPTICAL
lift_for(sys, p) = KTD.sized_lifter_for(sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

cfg = KTD.ObjectiveConfig(;
    power_W=PW, v_rated=V_RATED,
    p_floor_kw=5.0, p_ceiling_kw=5.0,
    relax_s=10.0, window_s=WINDOW_S,
    fos_target=2.5, fos_hard=2.5,
    power_stat=:tail5, penalize_ceiling=false,
    kickstart_s=0.0,
    k_mppt=K_MPPT_5KW_HONEST,
    tether_diameter=p_base.tether_diameter,
    rotor_count_mode=true,
    power_split=0.6,
    cone_slope_deg=22.0,
    rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    min_wall_m=2e-3,
)

const WINNER_CSV = joinpath(ROOT, "scripts", "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate", "best_vector.csv")
const x0 = [parse(Float64, s) for s in split(strip(read(WINNER_CSV, String)), ",")]

println("=== bank-blade join probe — ", WINNER_CSV, " ===")
@printf("winner genome (10-field): n_lines=%g rotor=%g bank_top=%.4f blade_top=%.4f\n",
    x0[4], x0[6], x0[7], x0[9])

const CASES = [
    ("winner control      ", x0[7], x0[9]),
    ("bank=0, blade=0.699 ", 0.0,   x0[9]),
    ("bank=0, blade=0.69  ", 0.0,   0.69),
    ("bank=0, blade=0.68  ", 0.0,   0.68),
]

@printf("\n%-20s %-8s %-9s %-9s %-9s %-8s %-9s %-8s\n",
    "case", "status", "P_mean", "P_end", "fitness", "FoS", "twist?", "twist_r")
println("-"^92)

for (label, bank, blade) in CASES
    xr = copy(x0)
    xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))     # n_lines
    xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))      # rotor count
    xr[7] = bank                                          # bank_top ← case
    xr[9] = blade                                         # blade_scale_top ← case

    twist_ratio_max = Ref(0.0)
    ctx = Ref{NamedTuple}()

    function trace(uc, tc, s, c)
        ctx[] = c
        tr = KTD.twist_collapse_check(uc, c.sys)
        twist_ratio_max[] = max(twist_ratio_max[], tr.max_ratio)
        return nothing
    end

    r = KTD.evaluate_windowed(
        xr, beam_profile, p_base, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KTD.appropriate_mass_fitness(P, F, c, m),
        trace_callback=trace,
    )

    if r.status === :reject
        @printf("%-20s %-8s %-9s %-9s %-9s %-8s %-9s %-9.4f\n",
            label, "reject", "—", "—", "—", "—", "—", twist_ratio_max[])
    else
        @printf("%-20s %-8s %-9.3f %-9.3f %-9.4f %-8.2f %-9s %-9.4f\n",
            label, r.status, r.P_mean, r.P_end, r.fitness, r.FoS_min,
            r.twist_crossed ? "YES" : "no", twist_ratio_max[])
    end
    flush(stdout)
    GC.gc()
end

println("\ndone")
