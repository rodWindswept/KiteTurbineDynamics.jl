# test/test_trpt_reference.jl — the printed TRPT reference values
#
# Reference library: docs/validation/trpt-reference/.  Every assertion carries the printed
# page number of the value it checks.  Source: O. Tulloch, PhD thesis, University of
# Strathclyde, 2021.
#
# These tests compare our code with the printed value.  They do not restate our formula.
# Two oracles below come from the printed equations (5.3) and (5.4).  A third comes from a
# brute-force maximum on a grid.
using Test
using KiteTurbineDynamics

# (5.4) printed page 198:  cos δcrit = 1 − ϕ²/2 + (ϕ/2)·√(ϕ² − 4),  with ϕ = l_t/R (5.5)
oracle_dcrit_deg(phi) = rad2deg(
    acos(clamp(1 - phi^2 / 2 + (phi / 2) * sqrt(phi^2 - 4), -1.0, 1.0)),
)

# (5.3) printed page 198, in the equal-radius form:
#   Q = R²·F_x·sin δ / L_ax      with      L_ax² = l_t² − 2R²(1 − cos δ)
function oracle_torque(r, lt, fx, ddeg)
    d = deg2rad(ddeg)
    lax2 = lt^2 - 2 * r^2 * (1 - cos(d))
    lax2 <= 0 && return 0.0
    return r^2 * fx * sin(d) / sqrt(lax2)
end

# the maximum of that curve, on a grid fine enough for a tolerance of 0.2 percent
function oracle_peak(r, lt, fx)
    best = 0.0
    for i in 1:180_000
        v = oracle_torque(r, lt, fx, i * 0.001)
        v > best && (best = v)
    end
    return best
end

@testset "TRPT reference values — Tulloch (2021), printed pages 198-201" begin
    # R1, R2, R3, R12: the printed section.  R = 0.4 m, l_t = 1 m, F_x = 500 N, ϕ = 2.5
    let r = 0.4, lt = 1.0, fx = 500.0
        lim = trpt_twist_limit(r, r, lt)
        # printed page 199: "the maximum transmittable torque is 100Nm and δcrit is equal
        # to 104"
        @test rad2deg(lim.dcrit) ≈ 104.0 atol = 0.6
        # our limit must be the peak of the printed curve (5.3)
        @test rad2deg(lim.dcrit) ≈ oracle_dcrit_deg(2.5) rtol = 1e-9
        @test trpt_torque_capacity_axial(lim, fx) ≈ oracle_peak(r, lt, fx) rtol = 2e-3
        # printed page 199: 100 N·m at 500 N
        @test trpt_torque_capacity_axial(lim, fx) ≈ 100.0 atol = 0.05
        # printed page 199: "in the case shown in Figure 5.28 this value is 0.5"
        @test trpt_torque_capacity_axial(lim, fx) / (r * fx) ≈ 0.5 atol = 1e-4
        # Figure 5.25 printed page 199: the curve is zero at zero twist and at 180°
        @test oracle_torque(r, lt, fx, 0.0) == 0.0
        @test abs(oracle_torque(r, lt, fx, 180.0)) < 1e-9
    end

    # R4, R5, R6, R13: the stability map.  Use R = 1 m, so that ϕ is the tether length.
    function fratio(phi)
        lim = trpt_twist_limit(1.0, 1.0, phi)
        return trpt_torque_capacity_axial(lim, 1.0)
    end
    # R6 Figure 5.29 printed page 200: the stable boundary starts at force ratio 1.0 at
    # the left edge, which is ϕ = 2
    @test fratio(2.0) ≈ 1.0 atol = 0.02
    @test fratio(2.5) ≈ 0.5 atol = 1e-3
    # R4 printed page 201: a force ratio of 0.17 allows a length to radius ratio
    # "as high as 6"
    @test fratio(6.0) ≈ 0.17 atol = 5e-3
    # R5 printed page 201: a force ratio of 0.72 "corresponds to a maximum length to
    # radius ratio of 2.11"
    lo, hi = 2.0, 3.0
    for _ in 1:60
        mid = 0.5 * (lo + hi)
        fratio(mid) > 0.72 ? (lo = mid) : (hi = mid)
    end
    @test 0.5 * (lo + hi) ≈ 2.11 atol = 0.03
    # R13 Figure 5.29: the boundary falls as ϕ grows
    @test fratio(3.0) > fratio(5.0) > fratio(10.0)

    # R7 printed page 198: "the minimum value of delta_crit is 90°".  The value falls
    # towards 90° and never goes below it.
    d10 = rad2deg(trpt_twist_limit(1.0, 1.0, 10.0).dcrit)
    d20 = rad2deg(trpt_twist_limit(1.0, 1.0, 20.0).dcrit)
    @test d20 < d10
    @test d20 ≥ 90.0
    @test d20 ≈ 90.0 atol = 0.3

    # R8 printed page 198 with ϕ = 2: the tethers can cross at 180° only, with the rings
    # closed.  The force ratio is at its largest value there, 1.0.
    lim2 = trpt_twist_limit(1.0, 1.0, 2.0)
    @test lim2.has_limit
    @test rad2deg(lim2.dcrit) ≈ 180.0 atol = 0.01
    @test trpt_torque_capacity_axial(lim2, 1.0) ≈ 1.0 atol = 1e-9

    # R9 printed page 81: the laboratory rig.  "two 0.62m diameter wheels connected by 6
    # tethers ... The tethers have a length of 0.65m."
    let r = 0.62 / 2, lt = 0.65
        @test lt / r ≈ 2.10 atol = 0.01
        lim = trpt_twist_limit(r, r, lt)
        @test lim.has_limit                       # the rig sits just above the split
        @test 90.0 < rad2deg(lim.dcrit) < 180.0
    end

    # The repo's line-tension law must agree with the printed (5.3) when the axial force
    # is held.  τ = n·T·r_a·r_b·sin Δα / chord, with T = F_x·l_t / (n·L_ax).
    let r = 0.4, lt = 1.0, fx = 500.0, n = 6, ddeg = 104.4775
        d = deg2rad(ddeg)
        lax = sqrt(lt^2 - 2 * r^2 * (1 - cos(d)))
        t_per_line = fx * lt / (n * lax)
        tau_repo_law = n * t_per_line * r * r * sin(d) / lt     # chord = l_t, no stretch
        @test tau_repo_law ≈ 100.0 atol = 0.05
        @test tau_repo_law ≈
              trpt_torque_capacity_axial(trpt_twist_limit(r, r, lt), fx) rtol = 1e-6
    end
end
