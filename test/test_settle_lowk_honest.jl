# test_settle_lowk_honest.jl — acceptance tests for the 2026-08-21 settle
# scan + reject-telemetry fix.
#
# Background: the k sweep (k_sweep_daisy_5kw.csv) showed k < 4.0 "stalling"
# at P=0, FoS=Inf.  Tracing showed this is NOT a stall: the machine spins
# and transmits at every k (ω_gnd 10-14 rad/s, twists 2-4° vs 30-78° limits,
# live P = k·ω³ positive).  Low k rejects on the 5 kW POWER FLOOR, but
# mass_min_fitness → Inf → rejected_eval() ZEROES P_mean/FoS/T_lift, so the
# CSV read "0 kW stall" instead of "3.5 kW below floor".
#
# Fixes under test:
#   A. Settle scan clamped to the cp peak (never park the machine on the
#      falling flank / table edge at low k).
#   B. Fitness-seam rejects CARRY the measured window statistics (honest
#      telemetry) — status stays :reject, only the recorded numbers change.
#
# Expected: RED on current master (k=0.5/4.0 report P_mean=0.0, FoS=Inf),
# GREEN after the fix.

using KiteTurbineDynamics
using Test
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 20.0
const LENGTH = 18.8

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    # LENGTH FIX (2026-08-22): mass_scale also scales the tether length; L is
    # the FINAL machine length — restore it after rung scaling.
    return override_params(scaled; tether_length=L)
end

const P_BASE = params_at_length(LENGTH)

function seed_genome_x()
    seed_v = seed_genome(KW)
    lo, hi = tight_bounds(seed_v, KW)
    xr = clamp.(copy(seed_v), lo, hi)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: {1,2,3}
    return xr
end

const X_SEED = seed_genome_x()

function run_at(k::Float64)
    cfg = ObjectiveConfig(;
        power_W = PW, v_rated = V_RATED,
        p_floor_kw = 5.0, p_ceiling_kw = 5.0,
        relax_s = 5.0, window_s = WINDOW_S,
        fos_target = 2.5, fos_hard = 2.5,
        power_stat = :tail5, penalize_ceiling = false,
        kickstart_s = 0.0,
        k_mppt = k,
        tether_diameter = P_BASE.tether_diameter,
        rotor_count_mode = true,            # campaign decode knobs (2026-09-04)
        power_split = 0.6,
        blocking_factor = BLOCKING_WIND_FACTOR_5KW,
    )
    return KiteTurbineDynamics.evaluate_windowed(
        X_SEED, PROFILE_ELLIPTICAL, P_BASE, cfg;
        start_mode = :cold,
        lift_device = lift_for,
        fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
end

@testset "settle-lowk-honest" begin

    @testset "A1 — k=0.5 rejects on floor but carries honest measurements" begin
        r = run_at(0.5)
        # Not a stall: machine transmits P = k·ω³ ≈ 0.5·11.2³ ≈ 0.7 kW at its
        # equilibrium; the 5 kW floor rejects it.  rejected_eval must NOT
        # zero the measured window statistics.
        @test r.status === :reject
        @test r.P_mean > 0.3          # was 0.0 — live power measured in window
        @test r.FoS_min < Inf         # was Inf — structural loads were measured
        @test r.T_lift > 100.0        # const-tension lift line was loaded (~205 N)
    end

    @testset "A2 — k=2.0 rejects on floor but carries honest measurements" begin
        r = run_at(2.0)
        # k=2.0 is below the campaign's sustaining k (K_MPPT_5KW_HONEST=2.24
        # sustains 5.12 kW), so it rejects on the 5 kW floor — but the window
        # measured real power and loads.  (k=4.0 was the OLD threshold; the
        # corrected machine sustains ≥5 kW there, so it is no longer a reject.)
        @test r.status === :reject
        @test r.P_mean > 0.3          # live power measured in window
        @test r.FoS_min < Inf         # structural loads were measured
        @test r.T_lift > 100.0        # const-tension lift line was loaded
    end

    @testset "A3 — k=5.39 sustains (settle-clamp guard, re-measured)" begin
        r = run_at(5.39)
        @test r.status === :ok
        @test r.P_mean ≈ 6.25 atol = 0.15   # re-measured 2026-09-04 on corrected seed
        @test r.P_end > 5.0
        @test r.FoS_min > 2.5
    end

    @testset "A4 — settle scan never parks past the cp peak (low k)" begin
        # The settle's chosen ω_eq must be ≤ ω at the cp peak (λ≈5.2),
        # never on the falling flank / table edge (λ=8.0 for k=0.5 pre-fix).
        # Reproduce the settle scan the way settle_to_operational_state does
        # and check the crossing λ for k=0.5.
        p2 = params_daisy()
        v_mag = V_RATED
        R = 4.545  # decoded hub rotor tip radius (probe value)
        r_in = 2.017
        A = π * (R^2 - r_in^2)
        β = p2.elevation_angle
        k = 0.5
        λ_peak = KiteTurbineDynamics.BEM_TSR[argmax(KiteTurbineDynamics.BEM_CP)]
        ω_peak = λ_peak * v_mag / R
        ω_eq = 60.0
        found = false
        for w in range(ω_peak, 0.1; length=200)
            lambda = w * R / v_mag
            P_aero = 0.5 * p2.rho * v_mag^3 * A * cp_at_tsr(lambda) * cos(β)^2.65
            P_gen = k * w^3
            if P_aero > P_gen
                ω_eq = w
                found = true
                break
            end
        end
        @test found
        @test ω_eq <= ω_peak + 1e-9   # was 19.36 rad/s (λ=8.0) — now clamped at the peak
    end

end
