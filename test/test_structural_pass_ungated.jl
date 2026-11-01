# test_structural_pass_ungated.jl — the per-genome structural pass (RF-20)
# and the start_mode selector guard (2026-11-01 hygiene sweep).
#
# The pass is static: no ODE, no scoring. It exists so the two-point k
# re-evaluation can fold in min_torsional_fos as an UNGATED column.

using Test
using KiteTurbineDynamics

# The bankderate2 winner genome (10-D canonical, from
# scratch/sv_p0_winner_reeval.txt) and the campaign's 5 kW / 18.8 m base.
const WINNER_GENOME = [
    4.57997905482005,
    0.8036829846088207,
    2.720554022272866,
    3.0,
    -0.8,
    1.0,
    7.088131460323565,
    22.0,
    0.8213255027884769,
    0.19999999999999996,
]

function _campaign_base()
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, 18.8,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, 2.24, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0)
    return override_params(scaled; tether_length=18.8, k_mppt=2.24)
end

@testset "structural pass: torsional value is reported, never gated" begin
    p = _campaign_base()
    cfg = ObjectiveConfig(;
        power_W=5_000.0, v_rated=11.0,
        fos_target=2.5, fos_hard=2.5,
        k_mppt=2.24,
        tether_diameter=p.tether_diameter,
        rotor_count_mode=true,
        power_split=0.6,
        cone_slope_deg=22.0,
        rotor_spacing_frac=0.8,
        min_wall_m=0.002,
    )

    # The two k points carry their OWN measured speeds; the pass must not
    # re-solve equilibrium behind the re-evaluation's back.
    lo = structural_pass_v10(
        WINNER_GENOME, PROFILE_ELLIPTICAL, p, cfg; omega_rotor=8.60,
    )
    hi = structural_pass_v10(
        WINNER_GENOME, PROFILE_ELLIPTICAL, p, cfg; omega_rotor=10.169820334285198,
    )
    @test lo.valid && hi.valid
    @test lo.reason === :ok && hi.reason === :ok
    @test isfinite(lo.min_torsional_fos) && lo.min_torsional_fos > 0.0
    @test isfinite(hi.min_torsional_fos) && hi.min_torsional_fos > 0.0

    # Torsional capacity is fixed at a given design; demand is P/ω, so a higher
    # measured speed reports a HIGHER minimum torsional FoS.
    @test hi.min_torsional_fos > lo.min_torsional_fos

    # An ungated column never rejects: validity is decode-only, and the flag
    # stays true whatever the value reads.
    @test lo.torsion_ungated && hi.torsion_ungated
end

@testset "mode-selector guard: unknown start_mode is rejected" begin
    p = _campaign_base()
    cfg = ObjectiveConfig()
    @test_throws ArgumentError evaluate_windowed(
        [0.0],
        PROFILE_ELLIPTICAL,
        p,
        cfg;
        start_mode=:hot,
        fitness_fn=(P, F, c) -> 0.0,
    )
end
